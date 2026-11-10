"""AI 视频 → Godot 动画：处理管线（TASK-ARTLIB-CLEAN-001 建立）。

**本工具不生成视频，也不调用任何 AI 服务。** 用户自己用 ChatGPT 给的提示词生成视频，
把 mp4 交给开发 Agent；本工具负责从视频里做出可上机的帧序列。

六个子命令，可以单独跑，也可以 `all` 一次跑到底：

    python tools/video/pipeline.py probe   INPUT.mp4
    python tools/video/pipeline.py extract INPUT.mp4 --batch walk_right
    python tools/video/pipeline.py matte   --batch walk_right [--key auto]
    python tools/video/pipeline.py analyze --batch walk_right --speed 100
    python tools/video/pipeline.py align   --batch walk_right
    python tools/video/pipeline.py build   --batch walk_right --fps 10
    python tools/video/pipeline.py all     INPUT.mp4 --batch walk_right --speed 100

产物统一落在 `assets/dev/video_candidates/<batch>/`：
    frames_raw/   抽出来的原始帧（不透明，带背景）
    frames_matte/ 抠像后的 RGBA 帧
    frames_out/   对齐到 128×176、脚底 (64,168) 的成品帧（引擎直接读这个）
    preview/      预览 GIF / 接触表
    meta.json     全部量测参数与体检结论

**每一步都只在 candidates 目录里写，绝不碰 assets/characters/ 与正式动画。**
转正必须人工走 docs/AI视频转Godot动画接入规范.md §6 的流程。

依赖：ffmpeg / ffprobe（PATH 里）、Pillow、numpy、OpenCV。

VIDEO-INTEGRATE-001 针对性改进（默认行为保持不变，selftest 仍走旧路径）：
    matte --key-mode chroma   绿幕色度键 + despill + 去杂点（见 chroma.py）
    align --resample quality  预乘 alpha 两阶段降采样 + 全序列统一中轴（高分辨率素材必用）
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

try:
    from chroma import chroma_key, premultiplied_resize
except ImportError:  # 允许 `python -m tools.video.pipeline` 的调用方式
    from .chroma import chroma_key, premultiplied_resize

ROOT = Path(__file__).resolve().parent.parent.parent
CANDS = ROOT / "assets" / "dev" / "video_candidates"

# ---- 工程约束（与 docs 保持一致，改动必须同步改这里和文档，不许两处不一致） ----
FRAME_W, FRAME_H = 128, 176
ANCHOR = (64, 168)
VIEW = (960, 540)
SPEEDS = {"walk": 100.0, "push": 80.0, "pull": 40.0}
ALPHA_THRESHOLD = 8          # 0-255，低于它的像素视为背景
FOOT_TOLERANCE = 2           # 脚底行允许偏差
DUP_EPS = 0.0                # 相邻帧完全相同的判定阈值


# ---------------------------------------------------------------- 工具函数

def sh(cmd: list[str]) -> str:
    p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if p.returncode != 0:
        raise RuntimeError(f"命令失败：{' '.join(cmd)}\n{p.stderr.strip()}")
    return p.stdout


def need(tool: str) -> str:
    path = shutil.which(tool)
    if not path:
        raise SystemExit(f"[FAIL] 找不到 {tool}，请先安装 ffmpeg 并加入 PATH。")
    return path


def batch_dir(batch: str) -> Path:
    d = CANDS / batch
    d.mkdir(parents=True, exist_ok=True)
    return d


def load_meta(d: Path) -> dict:
    p = d / "meta.json"
    if p.is_file():
        return json.loads(p.read_text(encoding="utf-8"))
    return {}


def save_meta(d: Path, meta: dict) -> None:
    (d / "meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n",
                                 encoding="utf-8")


def png_list(d: Path) -> list[Path]:
    return sorted(p for p in d.glob("*.png"))


def rgba(path: Path) -> np.ndarray:
    return np.array(Image.open(path).convert("RGBA"), dtype=np.uint8)


# ---------------------------------------------------------------- 1. probe

def cmd_probe(args) -> int:
    need("ffprobe")
    src = Path(args.input)
    if not src.is_file():
        raise SystemExit(f"[FAIL] 视频不存在：{src}")
    out = sh(["ffprobe", "-v", "error", "-select_streams", "v:0",
              "-show_entries", "stream=width,height,r_frame_rate,avg_frame_rate,nb_frames,duration,codec_name,pix_fmt",
              "-show_entries", "format=duration,size,format_name",
              "-of", "json", str(src)])
    info = json.loads(out)
    st = (info.get("streams") or [{}])[0]
    fmt = info.get("format") or {}
    num, _, den = (st.get("avg_frame_rate") or st.get("r_frame_rate") or "0/1").partition("/")
    fps = float(num) / float(den or 1) if float(den or 1) else 0.0
    dur = float(fmt.get("duration") or st.get("duration") or 0)
    rep = {
        "file": str(src),
        "codec": st.get("codec_name"),
        "pix_fmt": st.get("pix_fmt"),
        "width": st.get("width"),
        "height": st.get("height"),
        "fps": round(fps, 3),
        "duration_s": round(dur, 3),
        "est_frames": int(round(fps * dur)) if fps and dur else 0,
        "size_bytes": int(fmt.get("size") or 0),
    }
    print("========== 视频探测 ==========")
    for k, v in rep.items():
        print(f"  {k:12} {v}")
    problems = []
    if not rep["width"] or int(rep["width"]) < FRAME_W:
        problems.append(f"宽度小于 {FRAME_W}，放大必然糊")
    if not rep["fps"]:
        problems.append("读不到帧率")
    if rep["duration_s"] and rep["duration_s"] < 0.4:
        problems.append("时长不足 0.4s，凑不出一个循环")
    if rep["est_frames"] and rep["est_frames"] > 900:
        problems.append(f"预估 {rep['est_frames']} 帧过多，先确认只含一个动作循环")
    for p in problems:
        print(f"  [WARN] {p}")
    print(f"  体检结论：{'需要退回重生成' if problems else '可以进入抽帧'}")
    return 0


# ---------------------------------------------------------------- 2. extract

def cmd_extract(args) -> int:
    need("ffmpeg")
    src = Path(args.input)
    d = batch_dir(args.batch)
    raw = d / "frames_raw"
    if raw.exists():
        shutil.rmtree(raw)
    raw.mkdir(parents=True, exist_ok=True)
    sh(["ffmpeg", "-y", "-v", "error", "-i", str(src),
        "-vsync", "0", str(raw / "f_%04d.png")])
    n = len(png_list(raw))
    if n == 0:
        raise SystemExit("[FAIL] 没抽出任何帧")
    meta = load_meta(d)
    meta.update({"batch": args.batch, "source": str(src), "raw_frames": n})
    save_meta(d, meta)
    print(f"[OK] 抽帧 {n} 张 → {raw.relative_to(ROOT)}")
    return 0


# ---------------------------------------------------------------- 3. matte

def estimate_bg(frames: list[Path]) -> tuple[int, int, int]:
    """用四角像素的中位数估计背景色（AI 视频多是纯色或渐变底）。"""
    samples = []
    for p in frames[:: max(1, len(frames) // 8)]:
        a = rgba(p)
        h, w = a.shape[:2]
        k = max(2, min(h, w) // 40)
        for ys, xs in ((slice(0, k), slice(0, k)), (slice(0, k), slice(w - k, w)),
                       (slice(h - k, h), slice(0, k)), (slice(h - k, h), slice(w - k, w))):
            block = a[ys, xs, :3].reshape(-1, 3)
            samples.append(np.median(block, axis=0))
    med = np.median(np.array(samples), axis=0)
    return int(med[0]), int(med[1]), int(med[2])


def cmd_matte(args) -> int:
    d = batch_dir(args.batch)
    src_dir = d / "frames_raw"
    frames = png_list(src_dir)
    if not frames:
        raise SystemExit("[FAIL] 没有原始帧，先跑 extract")
    out_dir = d / "frames_matte"
    if out_dir.exists():
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    bg = tuple(int(x) for x in args.key) if args.key and args.key != "auto" else estimate_bg(frames)
    tol = int(args.tolerance)
    soft = int(args.softness)
    chroma_mode = getattr(args, "key_mode", "color") == "chroma"
    print(f"[INFO] 背景键色 = RGB{bg}，容差 {tol}，羽化 {soft}，模式 = "
          f"{'色度键 chroma（绿幕）' if chroma_mode else 'RGB 距离键'}")
    if chroma_mode:
        print("[INFO] 色度键按 G-max(R,B) 判定，带溢色抑制与孤立噪点清理；"
              "人物核心颜色逐像素保持不变")

    kept = 0
    for i, p in enumerate(frames):
        if chroma_mode:
            rgb = np.array(Image.open(p).convert("RGB"), dtype=np.uint8)
            out = chroma_key(rgb)
        else:
            a = rgba(p).astype(np.int16)
            diff = np.abs(a[:, :, :3] - np.array(bg, dtype=np.int16)).max(axis=2)
            # 软阈值：diff<=tol 全透明，diff>=tol+soft 全不透明，中间线性过渡
            alpha = np.clip((diff - tol) / max(1, soft), 0.0, 1.0)
            alpha = (alpha * 255).astype(np.uint8)
            rgb = np.array(Image.open(p).convert("RGB"), dtype=np.uint8)
            out = np.dstack([rgb, alpha])
            # 去边缘残留：完全透明像素的 RGB 清零，避免缩放时出现色边
            out[alpha == 0, :3] = 0
        Image.fromarray(out, "RGBA").save(out_dir / p.name)
        kept += 1

    meta = load_meta(d)
    meta["matte"] = {"key_rgb": list(bg), "tolerance": tol, "softness": soft,
                     "mode": "chroma" if chroma_mode else "color", "frames": kept}
    save_meta(d, meta)
    print(f"[OK] 抠像 {kept} 张 → {out_dir.relative_to(ROOT)}")
    return 0


# ---------------------------------------------------------------- 4. analyze

def bbox_of(a: np.ndarray) -> tuple[int, int, int, int] | None:
    m = a[:, :, 3] > ALPHA_THRESHOLD
    ys, xs = np.nonzero(m)
    if len(xs) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def cmd_analyze(args) -> int:
    d = batch_dir(args.batch)
    src = d / "frames_matte" if (d / "frames_matte").is_dir() else d / "frames_raw"
    frames = png_list(src)
    if not frames:
        raise SystemExit("[FAIL] 没有可分析的帧")
    arrs = [rgba(p) for p in frames]
    boxes = [bbox_of(a) for a in arrs]
    valid = [b for b in boxes if b]
    if not valid:
        raise SystemExit("[FAIL] 每一帧都是全透明，抠像参数有问题")

    hs = [b[3] - b[1] + 1 for b in valid]
    ws = [b[2] - b[0] + 1 for b in valid]
    bottoms = [b[3] for b in valid]
    dup = sum(1 for i in range(1, len(arrs)) if np.array_equal(arrs[i], arrs[i - 1]))

    fails, warns = [], []
    if len(frames) < 2:
        fails.append("帧数 < 2")
    if max(bottoms) - min(bottoms) > FOOT_TOLERANCE:
        warns.append(f"脚底行波动 {min(bottoms)}–{max(bottoms)} 超过 ±{FOOT_TOLERANCE}，对齐时会被裁")
    h_var = (max(hs) - min(hs)) / max(1, max(hs))
    w_var = (max(ws) - min(ws)) / max(1, max(ws))
    if h_var > 0.12:
        fails.append(f"人物高度波动 {h_var:.1%} > 12%，比例漂移，退回重生成")
    if w_var > 0.35:
        warns.append(f"人物宽度波动 {w_var:.1%} 偏大（手脚摆动可能正常，也可能形变）")
    if dup:
        warns.append(f"相邻帧完全重复 {dup} 对，抽帧有冗余或视频某段静止")

    fps = args.fps or 10.0
    speed = args.speed or SPEEDS.get(args.action or "walk", 100.0)
    loop_s = len(frames) / fps
    print("========== 帧序列体检 ==========")
    print(f"  帧数        {len(frames)}")
    print(f"  分析源      {src.relative_to(ROOT)}")
    print(f"  包围盒高    {min(hs)}–{max(hs)} px（波动 {h_var:.1%}）")
    print(f"  包围盒宽    {min(ws)}–{max(ws)} px（波动 {w_var:.1%}）")
    print(f"  脚底行      {min(bottoms)}–{max(bottoms)}")
    print(f"  重复帧      {dup} 对")
    print(f"  循环时长    {len(frames)}/{fps:.0f} = {loop_s:.2f} s @ {speed:.0f} px/s")
    print(f"  逐帧位移应  {speed * loop_s / len(frames):.2f} px")
    for w in warns:
        print(f"  [WARN] {w}")
    for f in fails:
        print(f"  [FAIL] {f}")
    print(f"  结论：{'退回' if fails else ('可继续，但注意上面的警告' if warns else '通过')}")

    meta = load_meta(d)
    meta["analyze"] = {
        "frames": len(frames), "fps": fps, "speed": speed,
        "bbox_h": [min(hs), max(hs)], "bbox_w": [min(ws), max(ws)],
        "foot_rows": [min(bottoms), max(bottoms)],
        "dup_pairs": dup, "fails": fails, "warns": warns,
    }
    save_meta(d, meta)
    return 1 if fails else 0


# ---------------------------------------------------------------- 5. align

def cmd_align(args) -> int:
    d = batch_dir(args.batch)
    src = d / "frames_matte" if (d / "frames_matte").is_dir() else d / "frames_raw"
    frames = png_list(src)
    if not frames:
        raise SystemExit("[FAIL] 没有可对齐的帧")
    out_dir = d / "frames_out"
    if out_dir.exists():
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    quality = getattr(args, "resample", "nearest") == "quality"
    if quality:
        # ---- 高分辨率素材路径（VIDEO-INTEGRATE-001）----
        # 逐帧 bbox 居中会把「走路时身体摆动」误当成整体位移，造成画面左右抖动。
        # 这里对**整个序列共用同一个仿射变换**：统一缩放系数 + 统一偏移，
        # 脚底锁死在 anchor.y，身体中轴锁死在 anchor.x。
        arrs = [rgba(p) for p in frames]
        boxes = [bbox_of(a) for a in arrs]
        valid = [b for b in boxes if b]
        H, W = arrs[0].shape[:2]
        top = min(b[1] for b in valid)
        bottom = max(b[3] for b in valid)
        person_h = bottom - top + 1
        scale = (ANCHOR[1] - 6) / person_h          # 头顶留 6px
        nw, nh = max(1, round(W * scale)), max(1, round(H * scale))
        # 身体中轴：全序列不透明像素 x 的中位数（比逐帧 bbox 中心稳得多）
        centers = []
        for a in arrs[:: max(1, len(arrs) // 24)]:
            xs = np.nonzero(a[:, :, 3] > ALPHA_THRESHOLD)[1]
            if len(xs):
                centers.append(float(np.median(xs)))
        axis = float(np.median(centers)) if centers else W / 2
        ox = round(ANCHOR[0] - axis * scale)
        oy = round(ANCHOR[1] - bottom * scale)
        print(f"[INFO] quality 模式：统一 scale={scale:.5f}（人物 {person_h}px → "
              f"{round(person_h * scale)}px），整帧缩到 {nw}×{nh}，偏移 ({ox},{oy})，"
              f"身体中轴原图 x={axis:.0f}")

        for p, a in zip(frames, arrs):
            small = premultiplied_resize(a, (nw, nh))
            canvas = np.zeros((FRAME_H, FRAME_W, 4), dtype=np.uint8)
            # 统一贴：源 (sx,sy) → 画布 (sx+ox, sy+oy)
            sx0, sy0 = max(0, -ox), max(0, -oy)
            sx1 = min(nw, FRAME_W - ox)
            sy1 = min(nh, FRAME_H - oy)
            if sx1 > sx0 and sy1 > sy0:
                canvas[sy0 + oy:sy1 + oy, sx0 + ox:sx1 + ox] = small[sy0:sy1, sx0:sx1]
            Image.fromarray(canvas, "RGBA").save(out_dir / p.name)

        meta = load_meta(d)
        meta["align"] = {"canvas": [FRAME_W, FRAME_H], "anchor": list(ANCHOR),
                         "rule": "quality：预乘 alpha 两阶段降采样 + 全序列统一变换",
                         "scale": round(scale, 6), "source_axis_x": round(axis, 1),
                         "offset": [ox, oy], "resized_whole_frame": [nw, nh]}
        save_meta(d, meta)
        print(f"[OK] 对齐 {len(png_list(out_dir))} 张 → {out_dir.relative_to(ROOT)}")
        print(f"     画布 {FRAME_W}×{FRAME_H}，脚底锚点 {ANCHOR}（全序列同一变换）")
        return 0

    # ---- 原有路径：整数最近邻缩放 + 水平居中 + 脚底贴 anchor.y（selftest 用）----
    # 统一规则：整像素缩放（按最长边比例取整，不插值放大），水平居中到 anchor.x，
    # 脚底对齐到 anchor.y。**不做非整数缩放**，否则像素会糊。
    for p in frames:
        a = rgba(p)
        b = bbox_of(a)
        if not b:
            continue
        x0, y0, x1, y1 = b
        crop = a[y0:y1 + 1, x0:x1 + 1]
        ch, cw = crop.shape[:2]
        max_w = FRAME_W - 4
        max_h = ANCHOR[1] - 4
        scale = 1
        while (cw * (scale + 1) <= max_w) and (ch * (scale + 1) <= max_h):
            scale += 1
        if cw > max_w or ch > max_h:
            # 素材本身就比目标画布大：只允许整数缩小
            scale = max(1, min(max_w // cw, max_h // ch))
        if scale != 1:
            crop = np.array(Image.fromarray(crop, "RGBA").resize(
                (max(1, cw * scale), max(1, ch * scale)), Image.NEAREST), dtype=np.uint8)
        canvas = np.zeros((FRAME_H, FRAME_W, 4), dtype=np.uint8)
        nw, nh = crop.shape[1], crop.shape[0]
        ox = int(round(ANCHOR[0] - nw / 2))
        oy = int(ANCHOR[1] - nh)
        ox = max(0, min(FRAME_W - nw, ox))
        oy = max(0, min(FRAME_H - nh, oy))
        canvas[oy:oy + nh, ox:ox + nw] = crop
        Image.fromarray(canvas, "RGBA").save(out_dir / p.name)

    meta = load_meta(d)
    meta["align"] = {"canvas": [FRAME_W, FRAME_H], "anchor": list(ANCHOR),
                     "rule": "整数最近邻缩放 + 水平居中 + 脚底贴 anchor.y"}
    save_meta(d, meta)
    print(f"[OK] 对齐 {len(png_list(out_dir))} 张 → {out_dir.relative_to(ROOT)}")
    print(f"     画布 {FRAME_W}×{FRAME_H}，脚底锚点 {ANCHOR}")
    return 0


# ---------------------------------------------------------------- 6. build

def cmd_build(args) -> int:
    d = batch_dir(args.batch)
    src = d / "frames_out"
    frames = png_list(src)
    if not frames:
        raise SystemExit("[FAIL] 没有 frames_out，先跑 align")
    fps = args.fps or 10
    prev = d / "preview"
    prev.mkdir(exist_ok=True)

    imgs = [Image.open(p).convert("RGBA") for p in frames]
    w, h = imgs[0].size
    if any(im.size != (w, h) for im in imgs):
        raise SystemExit("[FAIL] 帧尺寸不一致，align 有问题")

    # 接触表：一行 8 帧，方便肉眼扫形变
    cols = min(8, len(imgs))
    rows = (len(imgs) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * w, rows * h), (27, 32, 38, 255))
    for i, im in enumerate(imgs):
        sheet.alpha_composite(im, ((i % cols) * w, (i // cols) * h))
    sheet.save(prev / "contact_sheet.png")

    # GIF：铺底色再量化，避免 1 位透明产生黑边
    flat = []
    for im in imgs:
        bg = Image.new("RGBA", (w, h), (27, 32, 38, 255))
        bg.alpha_composite(im)
        flat.append(bg.convert("RGB").convert("P", palette=Image.ADAPTIVE, colors=128))
    flat[0].save(prev / "loop.gif", save_all=True, append_images=flat[1:],
                 duration=max(20, round(1000 / fps)), loop=0, optimize=True)

    meta = load_meta(d)
    meta.update({"frames_final": len(frames), "fps": fps,
                 "out_dir": str(src.relative_to(ROOT)).replace("\\", "/")})
    save_meta(d, meta)
    print(f"[OK] 预览 → {prev.relative_to(ROOT)}（contact_sheet.png / loop.gif）")
    print(f"[OK] 成品帧 {len(frames)} 张 @ {fps} FPS，供 --dev-scene=video --video-dir={args.batch}")
    print("[NEXT] 引擎验收：")
    print(f"       .tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- "
          f"--dev-scene=video --video-dir={args.batch} --video-fps={fps} --video-test")
    return 0


# ---------------------------------------------------------------- all

def cmd_all(args) -> int:
    print("== 1/5 探测 ==")
    cmd_probe(args)
    print("\n== 2/5 抽帧 ==")
    cmd_extract(args)
    print("\n== 3/5 抠像 ==")
    cmd_matte(args)
    print("\n== 4/5 体检 ==")
    code = cmd_analyze(args)
    if code != 0:
        print("\n[STOP] 体检不通过，先退回让用户重生成，不要继续对齐。")
        return code
    print("\n== 5/5 对齐 + 预览 ==")
    cmd_align(args)
    cmd_build(args)
    print("\n完成。下一步是引擎验收，不是直接转正。")
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="AI 视频抽帧 → 对齐 → 引擎候选（不生成视频）")
    sub = ap.add_subparsers(dest="cmd", required=True)

    def common(p):
        p.add_argument("--batch", default="walk_right", help="候选目录名，落在 assets/dev/video_candidates/ 下")
        p.add_argument("--fps", type=float, default=None)
        p.add_argument("--speed", type=float, default=None, help="实际移动速度 px/s，用于算滑步")
        p.add_argument("--action", default="walk", choices=list(SPEEDS))

    p = sub.add_parser("probe"); p.add_argument("input"); p.set_defaults(func=cmd_probe)

    p = sub.add_parser("extract"); p.add_argument("input"); common(p); p.set_defaults(func=cmd_extract)

    p = sub.add_parser("matte"); common(p)
    p.add_argument("--key", default="auto", help="背景色 auto 或 r,g,b")
    p.add_argument("--key-mode", default="color", choices=["color", "chroma"],
                   help="chroma = 绿幕色度键 + despill（高分辨率绿幕视频必用）")
    p.add_argument("--tolerance", default=28)
    p.add_argument("--softness", default=24)
    p.set_defaults(func=cmd_matte)

    p = sub.add_parser("analyze"); common(p); p.set_defaults(func=cmd_analyze)
    p = sub.add_parser("align"); common(p)
    p.add_argument("--resample", default="nearest", choices=["nearest", "quality"],
                   help="quality = 预乘 alpha 两阶段降采样 + 全序列统一变换")
    p.set_defaults(func=cmd_align)
    p = sub.add_parser("build"); common(p); p.set_defaults(func=cmd_build)

    p = sub.add_parser("all"); p.add_argument("input"); common(p)
    p.add_argument("--key", default="auto")
    p.add_argument("--key-mode", default="color", choices=["color", "chroma"])
    p.add_argument("--resample", default="nearest", choices=["nearest", "quality"])
    p.add_argument("--tolerance", default=28)
    p.add_argument("--softness", default=24)
    p.set_defaults(func=cmd_all)

    args = ap.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
