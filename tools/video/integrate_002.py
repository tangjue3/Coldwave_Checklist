"""VIDEO-INTEGRATE-002：用户第二条 AI 视频（推购物车）→ 512×704 高清候选动画。

与 VIDEO-INTEGRATE-001 的关键差别：**人物与购物车必须分开**。
`segment_002.py` 已从视频里抠出纯人物（车体零残留），本脚本只处理人物；
游戏里的购物车仍由 `ART_FURN_103 r03` 四件分层资源渲染，两者在 Godot 场景里组合。

视频实测（1280×720 / 24FPS / 96 帧 / 4.032s）：
  起始站立 f1–6、起步 f7–12、稳定推车 f13–72、减速收脚 f73–88、冻结待机 f89–96
  步态周期 L=16（0.667s），取 L=32 两个完整周期做循环：f23–f54，闭合差 0.0094
  视频里人物+车整组右移 109px → 逐帧用平滑躯干轨迹补偿，避免游戏里横向漂移

    python tools/video/integrate_002.py            # 全量
    python tools/video/integrate_002.py --fix-imports
"""
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))

from chroma import bleed_rgb  # noqa: E402

# ---------------------------------------------------------------- 路径
W2 = ROOT / ".work" / "video2_in"
PERSON = W2 / "frames_person_matte"
HD_ALL = W2 / "frames_hd"
DELIV = ROOT / "转存库" / "VIDEO-INTEGRATE-002"
CANDS = ROOT / "assets" / "dev" / "video_candidates" / "VIDEO-INTEGRATE-002"
CHAR_DIR = ROOT / "assets" / "characters"
CART_DIR = ROOT / "assets" / "facilities"
REF_V02 = ROOT / "素材库" / "美术设定集" / "01-角色" / "参考图" / "ART_CHAR_001_v02_ref_right.png"

# ---------------------------------------------------------------- 几何
FRAME_W, FRAME_H = 512, 704
ANCHOR = (256, 672)
SCALE = 1.06                 # 视频人物可见高 ~606 → 与已验收 r10 一致（~642）
FOOT_SRC_Y = 670             # 全序列统一，不逐帧居中（避免上下抖动）
TORSO_DST_X = 268            # 让手落在游戏车把握杆左端（详见 align_probe）
FPS = 24

# 三段：名称 / 起始帧(1-based) / 帧数 / FPS / 循环
SEGMENTS = [
    ("push_walk_right", 23, 32, FPS, True),
    ("push_walk_to_idle", 73, 17, FPS, False),
    ("push_idle_right", 91, 1, 8, True),
]
PREFIX = "ART_CHAR_001_vid002_cand"


# ---------------------------------------------------------------- 手部/车把几何对齐
# 视频里用户推的是一辆「高把」购物车（握把在人物身高 65% 处），
# 而工程正式资源 ART_FURN_103 r03 是加高车把（握把在 56% 处），
# 两者相差约 15 世界 px。若直接套用，手会明显悬在车把上方。
# 这里用**连续位移场**把前臂平滑下压到正式车把握把高度：
#   - 不缩放、不重绘、不新增像素，人物形象/服装/脸型完全不变；
#   - 躯干、头、腿、脚零改动（位移场限定 x>286、y 170..352）；
#   - 肩部 smoothstep 过渡，避免断袖；恒定区覆盖整条手臂，避免锥形拉伸。
HAND_ALIGN = {"dx": 8.0, "dy": 58.0, "x0": 286.0, "x1": 344.0,
              "y0": 170.0, "y1": 352.0, "feather": 22.0}


def align_hand_to_handle(src: np.ndarray) -> np.ndarray:
    """把前臂+手平滑下压，贴合游戏正式 r03 车把握把（连续位移场，无洞无重影）。"""
    h, w = src.shape[:2]
    Y, X = np.indices((h, w))
    t = np.clip((X - HAND_ALIGN["x0"]) / (HAND_ALIGN["x1"] - HAND_ALIGN["x0"]), 0, 1)
    t = t * t * (3 - 2 * t)
    f = HAND_ALIGN["feather"]
    band = np.clip((Y - HAND_ALIGN["y0"]) / f, 0, 1) * \
           np.clip((HAND_ALIGN["y1"] - Y) / f, 0, 1)
    k = t * band
    ox = (HAND_ALIGN["dx"] * k).astype(np.float32)
    oy = (HAND_ALIGN["dy"] * k).astype(np.float32)
    return cv2.remap(src, (X - ox).astype(np.float32), (Y - oy).astype(np.float32),
                     cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT,
                     borderValue=(0, 0, 0, 0))


def log(m: str) -> None:
    print(m, flush=True)


def flat(im: Image.Image, bg=(38, 42, 50)) -> Image.Image:
    base = Image.new("RGBA", im.size, (*bg, 255))
    base.alpha_composite(im.convert("RGBA"))
    return base.convert("RGB")


# ---------------------------------------------------------------- 1. 高清帧
def build_hd_frames(seg_info: dict) -> dict:
    srcs = sorted(PERSON.glob("f_*.png"))
    assert len(srcs) == 96, f"纯人物帧 {len(srcs)} 张，预期 96；先跑 segment_002.py"
    HD_ALL.mkdir(parents=True, exist_ok=True)
    tors = np.array(seg_info["torsos"], dtype=float)
    sm = np.array([np.median(np.pad(tors, 4, mode="edge")[i:i + 9]) for i in range(len(tors))])
    tx_base = ANCHOR[0] - 0  # 目标水平基准在下面的仿射里直接用 TORSO_DST_X
    ty = ANCHOR[1] - FOOT_SRC_Y * SCALE
    feet, heights, green = [], [], 0
    for i, p in enumerate(srcs):
        a = np.array(Image.open(p).convert("RGBA"), dtype=np.uint8)
        # 透明区颜色外扩（LINEAR 缩小时不泛黑/绿边）
        a[:, :, :3] = bleed_rgb(a, iterations=8)
        f = a.astype(np.float32)
        al = f[:, :, 3:4] / 255.0
        pm = np.concatenate([f[:, :, :3] * al, f[:, :, 3:4]], axis=2)
        # 平移补偿 + 缩放，一次 LANCZOS4 完成（源人物 606px → 目标 642px，仅放大 6%）
        M = np.array([[SCALE, 0.0, TORSO_DST_X - sm[i] * SCALE],
                      [0.0, SCALE, ty]], dtype=np.float32)
        w = cv2.warpAffine(pm, M, (FRAME_W, FRAME_H), flags=cv2.INTER_LANCZOS4,
                           borderMode=cv2.BORDER_CONSTANT, borderValue=(0, 0, 0, 0))
        al2 = np.clip(w[:, :, 3:4], 0, 255)
        rgb = np.clip(w[:, :, :3] / np.maximum(al2 / 255.0, 1e-4), 0, 255)
        blur = cv2.GaussianBlur(rgb, (0, 0), 0.7)
        strength = np.clip(al2 / 255.0, 0, 1)
        rgb = np.clip(rgb + (rgb - blur) * 0.30 * strength, 0, 255)
        out = np.dstack([rgb.astype(np.uint8), np.clip(al2, 0, 255).astype(np.uint8)])
        out = align_hand_to_handle(out)
        # 位移后新露出的半透明边缘再做一次颜色外扩，避免 LINEAR 下泛黑边
        out[:, :, :3] = bleed_rgb(out, iterations=4)
        Image.fromarray(out, "RGBA").save(HD_ALL / p.name)
        ys, xs = np.nonzero(out[:, :, 3] > 8)
        if len(ys):
            feet.append(int(ys.max())); heights.append(int(ys.max() - ys.min() + 1))
        r, g, b = out[:, :, 0].astype(int), out[:, :, 1].astype(int), out[:, :, 2].astype(int)
        green += int(((g - np.maximum(r, b) > 50) & (out[:, :, 3] > 8)).sum())
    info = {
        "source_frames": len(srcs), "canvas": [FRAME_W, FRAME_H], "anchor": list(ANCHOR),
        "scale": SCALE, "foot_src_y": FOOT_SRC_Y, "torso_dst_x": TORSO_DST_X,
        "drift_compensation": "逐帧按 9 帧中值躯干轨迹平移，消除视频整组右移 109px，保留步态摆动",
        "foot_rows": [min(feet), max(feet)], "visible_heights": [min(heights), max(heights)],
        "green_residual_px": green,
        "rule": "从 1280×720 原始视频的纯人物抠像帧直接生成 512×704；"
                "未使用任何 128×176 低清帧，未生成新视频，未重绘人物",
    }
    log(f"[1/6] 高清人物帧 {len(srcs)} 张；脚底 y={min(feet)}–{max(feet)}（目标 {ANCHOR[1]}），"
        f"可见高 {min(heights)}–{max(heights)}px，绿色残留 {green}px")
    return info


# ---------------------------------------------------------------- 2. 游戏内组合预览
def game_composite(frame_no: int, load: str = "half") -> Image.Image:
    """按 Godot 真实变换，把人物帧 + r03 四件分层车合成到 960×540 画面。

    player.tscn: scale 0.25, offset (-256,-672), centered=false → 贴图 (px,py)
                 → 世界 ((px-256)*0.25, (py-672)*0.25) 相对玩家脚底
    cart: 128×112, offset (-64,-104), scale 1 → 贴图 (cx,cy)
                 → 世界 (cx-64, cy-104) 相对车心
    side=-1：玩家脚底在 cart.x-80，车把在贴图 x16..40 → 世界 cart.x-48..-24
    图层顺序：Back(z0) → Cargo(z0) → Player → Front(z1)
    """
    px0, py0 = 400.0, 420.0                      # 玩家脚底世界坐标
    cx0 = px0 + 80.0                             # 车心（side=-1）
    canvas = Image.new("RGBA", (960, 540), (44, 48, 56, 255))
    d = ImageDraw.Draw(canvas)
    d.line([(0, py0 + 1), (960, py0 + 1)], fill=(120, 128, 140, 255), width=1)

    def paste_tex(tex: Image.Image, left: float, top: float, factor: int = 1) -> None:
        t = tex if factor == 1 else tex.resize((tex.width * factor, tex.height * factor),
                                               Image.NEAREST)
        layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        layer.alpha_composite(t, (int(round(left)), int(round(top))))
        canvas.alpha_composite(layer)

    # 人物贴图缩小 4 倍到 128×176（= Godot scale 0.25）
    person = Image.open(HD_ALL / f"f_{frame_no:04d}.png").convert("RGBA")
    psmall = person.resize((FRAME_W // 4, FRAME_H // 4), Image.LANCZOS)
    p_left, p_top = px0 - ANCHOR[0] * 0.25, py0 - ANCHOR[1] * 0.25

    back = Image.open(CART_DIR / "ART_FURN_103_r03_back_128x112.png").convert("RGBA")
    front = Image.open(CART_DIR / "ART_FURN_103_r03_front_128x112.png").convert("RGBA")
    c_left, c_top = cx0 - 64.0, py0 - 104.0
    paste_tex(back, c_left, c_top)
    if load in ("half", "full"):
        nm = "cargo_half" if load == "half" else "cargo_full"
        cargo = Image.open(CART_DIR / f"ART_FURN_103_r03_{nm}_128x112.png").convert("RGBA")
        paste_tex(cargo, c_left, c_top)
    # 人物贴图 512×704 → 128×176，左上角 = 世界 (px0-64, py0-168)
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    layer.alpha_composite(psmall, (int(round(p_left)), int(round(p_top))))
    canvas.alpha_composite(layer)
    paste_tex(front, c_left, c_top)
    return canvas.convert("RGB")


def build_previews(texture: dict, phases: dict) -> dict:
    DELIV.mkdir(parents=True, exist_ok=True)
    CANDS.mkdir(parents=True, exist_ok=True)
    prev = CANDS / "preview"
    prev.mkdir(parents=True, exist_ok=True)

    # --- 三段透明 PNG 序列（候选资源） ---
    names = {}
    for name, first, count, fps, loop in SEGMENTS:
        seg_dir = CANDS / name / "frames_out"
        if seg_dir.exists():
            shutil.rmtree(seg_dir)
        seg_dir.mkdir(parents=True, exist_ok=True)
        arr = []
        for i in range(count):
            src = HD_ALL / f"f_{first + i:04d}.png"
            dst = seg_dir / f"{name}_{i:02d}.png"
            shutil.copy2(src, dst)
            arr.append(dst)
        names[name] = arr

    # --- GIF 预览 ---
    gifs = {}
    for name, first, count, fps, loop in SEGMENTS:
        if count == 1:
            continue
        ims = [flat(Image.open(names[name][i]).convert("RGBA")).resize(
            (192, 264), Image.LANCZOS) for i in range(count)]
        out = DELIV / f"{name}.gif"
        ims[0].save(out, save_all=True, append_images=ims[1:], duration=1000 / fps,
                    loop=0 if loop else 1, disposal=2, optimize=False)
        gifs[name] = str(out.relative_to(ROOT))
        log(f"      GIF {name}: {count} 帧 {out.stat().st_size // 1024} KB")

    # --- 接触表 ---
    for name, first, count, fps, loop in SEGMENTS:
        if count < 4:
            continue
        sel = list(range(0, count, 2))
        thumbs = [flat(Image.open(names[name][i]).convert("RGBA")).resize((128, 176), Image.LANCZOS)
                  for i in sel]
        cols = 8
        sheet = Image.new("RGB", (cols * 128, ((len(sel) + cols - 1) // cols) * 194), (26, 29, 34))
        ds = ImageDraw.Draw(sheet)
        for i, (idx, im) in enumerate(zip(sel, thumbs)):
            x, y = (i % cols) * 128, (i // cols) * 194
            sheet.paste(im, (x, y + 18)); ds.text((x + 3, y + 3), f"{idx:02d}", fill=(230, 230, 230))
        sheet.save(prev / f"contact_{name}.png")

    # --- 游戏内组合预览（空载 / 半载 / 满载 + 关键帧） ---
    for nm, load, fr in [("combo_walk_half", "half", 31), ("combo_walk_full", "full", 31),
                         ("combo_idle_half", "half", 91), ("combo_walk_empty", "empty", 39)]:
        game_composite(fr, load).save(DELIV / f"{nm}.png")

    # --- 手部与车把接触放大（真实游戏坐标，Nearest 4x） ---
    boxes = [(430, 300, 560, 380)]
    probes = []
    for fr in [23, 31, 47, 73, 91]:
        im = game_composite(fr, "half")
        x0, y0, x1, y1 = boxes[0]
        probes.append(im.crop((x0, y0, x1, y1)).resize(((x1 - x0) * 3, (y1 - y0) * 3),
                                                       Image.NEAREST))
    sheet = Image.new("RGB", (probes[0].width, sum(p.height for p in probes) + 24 * len(probes)),
                      (248, 248, 248))
    ds = ImageDraw.Draw(sheet)
    y = 0
    for fr, p in zip([23, 31, 47, 73, 91], probes):
        ds.text((6, y + 3), f"f{fr:03d}  hand / handle contact 3x (true game geometry)", fill=(20, 20, 20))
        sheet.paste(p, (0, y + 22)); y += p.height + 24
    sheet.save(DELIV / "compare_hand_handle_contact.png")

    # --- 分割前后对照（原视频帧 vs 纯人物 vs 游戏组合） ---
    raw = Image.open(W2 / "frames_raw" / "f_0031.png").convert("RGB")
    person = flat(Image.open(HD_ALL / "f_0031.png").convert("RGBA")).resize((256, 352), Image.LANCZOS)
    combo = game_composite(31, "half").crop((300, 220, 700, 460))
    cmp = Image.new("RGB", (640 + 256 + 20, 400), (248, 248, 248))
    dc = ImageDraw.Draw(cmp)
    cmp.paste(raw.crop((200, 30, 900, 690)).resize((640, 384)), (0, 16))
    cmp.paste(combo.resize((400, 240), Image.LANCZOS), (660, 60))
    dc.text((4, 2), "① 用户原始视频帧（含视频购物车）", fill=(20, 20, 20))
    dc.text((660, 2), "③ 游戏内组合（正式 r03 购物车）", fill=(20, 20, 20))
    cmp.save(DELIV / "compare_source_person_combo.png")
    return {"gifs": gifs, "segments": {k: len(v) for k, v in names.items()}}


# ---------------------------------------------------------------- 3. SpriteFrames
def build_spriteframes() -> dict:
    """保留 r10/r11/r12 三段，追加三段推车候选动画。"""
    existing = sorted(CHAR_DIR.glob("ART_CHAR_001_vid001_hd_*.png"))
    assert len(existing) == 58, f"已验收帧 {len(existing)} 张，预期 58"
    # 幂等：不解析旧 tres（重复运行时旧文件已含 6 段），用固定定义重建。
    # 已验收 r10/r11/r12 的帧文件与参数一律不改，只在末尾追加三段推车候选。
    old_defs = [("walk_right", 36, 24, True),
                ("walk_to_idle", 21, 24, False),
                ("idle_right", 1, 8, True)]

    defs = list(old_defs) + [(n, c, f, lp) for n, _, c, f, lp in SEGMENTS]
    mapping: dict[str, list[Path]] = {}
    for n, count, fps, loop in old_defs:
        mapping[n] = sorted(CHAR_DIR.glob(f"ART_CHAR_001_vid001_hd_{n}_*_512x704.png"))
        assert len(mapping[n]) == count, (n, len(mapping[n]), count)
    for n, first, count, fps, loop in SEGMENTS:
        d = CANDS / n / "frames_out"
        arr = []
        for i in range(count):
            dst = CHAR_DIR / f"{PREFIX}_{n}_{i:02d}_512x704.png"
            shutil.copy2(d / f"{n}_{i:02d}.png", dst)
            arr.append(dst)
        mapping[n] = arr

    total = sum(len(v) for v in mapping.values())
    lines = [f'[gd_resource type="SpriteFrames" load_steps={total + 1} format=3]', ""]
    idx = 0
    for n, count, fps, loop in defs:
        for p in mapping[n]:
            lines.append(f'[ext_resource type="Texture2D" path="res://assets/characters/{p.name}" '
                         f'id="{idx}"]')
            idx += 1
    lines += ["", "[resource]", "", "animations = [{"]
    for si, (n, count, fps, loop) in enumerate(defs):
        if si:
            lines.append("}, {")
        lines.append('"frames": [')
        base = sum(len(mapping[x[0]]) for x in defs[:si])
        for i in range(count):
            lines.append('{' + f'"duration": 1.0, "texture": ExtResource("{base + i}")' + '}' +
                         ("," if i < count - 1 else ""))
        lines += ['],', f'"loop": {"true" if loop else "false"},',
                  f'"name": &"{n}",', f'"speed": {float(fps)}']
    lines.append("}]")
    (CHAR_DIR / "player_sprite_frames.tres").write_text("\n".join(lines) + "\n", encoding="utf-8")
    info = {"animations": {n: {"frames": c, "fps": f, "loop": lp} for n, c, f, lp in defs},
            "total_frames": total, "existing_preserved": 58,
            "new_frames": total - 58,
            "spriteframes": "assets/characters/player_sprite_frames.tres"}
    log(f"[4/6] SpriteFrames：保留 {info['existing_preserved']} 张 + 新增 {info['new_frames']} 张，"
        f"共 {total} 张 / {len(defs)} 个动画")
    return info


def patch_imports() -> int:
    files = sorted(CHAR_DIR.glob(f"{PREFIX}_*.png.import"))
    if not files:
        log("[FAIL] 还没有 .import 文件，先跑一次引擎 --import")
        return 1
    for p in files:
        s = p.read_text(encoding="utf-8")
        s = s.replace("mipmaps/generate=true", "mipmaps/generate=false")
        s = s.replace("process/fix_alpha_border=true", "process/fix_alpha_border=false")
        s = s.replace("detect_3d/compress_to=1", "detect_3d/compress_to=0")
        p.write_text(s, encoding="utf-8")
    log(f"[OK] 已固化 {len(files)} 张推车帧导入参数：no mipmap / fix_alpha_border=false / compress_to=0")
    return 0


def main() -> int:
    if "--fix-imports" in sys.argv:
        return patch_imports()
    seg = json.loads((W2 / "segment.json").read_text(encoding="utf-8"))
    texture = build_hd_frames(seg)

    # 相位分析：walk 循环 32 帧里，哪些相位能自然接上减速段首帧 f73
    F = np.load(W2 / "feats_aligned.npy"); X = F.reshape(len(F), -1)
    d = lambda i, j: float(np.abs(X[i] - X[j]).mean())
    inner = float(np.mean([d(i, i + 1) for i in range(12, 72)]))
    ok = [p for p in range(32) if d(22 + p, 72) <= inner * 1.5]
    phases = {"loop_first": 23, "loop_len": 32, "loop_closure": round(d(22, 54), 5),
              "inner_mean": round(inner, 5), "stop_ok_phases": ok,
              "stop_phase_ratio": round(len(ok) / 32, 3),
              "period_frames": 16, "period_s": round(16 / FPS, 3),
              "video_phases": {"start_idle": "f1-6", "start_walk": "f7-12",
                               "steady_push": "f13-72", "decelerate": "f73-88",
                               "frozen_idle": "f89-96"}}
    log(f"[2/6] 步态周期 {phases['period_frames']} 帧；循环 f23–f54（32 帧 / 1.333s），"
        f"闭合差 {phases['loop_closure']}；停止过渡可接相位 {len(ok)}/32")

    previews = build_previews(texture, phases)
    godot = build_spriteframes()

    meta = {
        "task": "VIDEO-INTEGRATE-002",
        "status": "候选 / 待用户视觉审核（台账、白名单、美术总览正式状态未改）",
        "source_video": "转存库/Character_pushing_shopping_cart_…_e2be2167.mp4",
        "source_params": {"size": [1280, 720], "fps": FPS, "frames": 96,
                          "duration_s": 4.032, "greenscreen": "RGB(37,198,62)"},
        "separation": {
            "method": "逐帧检测手-端盖接触点；手部带按颜色分离保留完整手指，其余用切线+连通域",
            "cart_residue_px": seg["cart_residue_total"],
            "person_bbox_height": [min(x["bbox"][3] - x["bbox"][1] + 1 for x in seg["matte_stats"]),
                                   max(x["bbox"][3] - x["bbox"][1] + 1 for x in seg["matte_stats"])],
            "cut_drift_px": seg["cut_drift"],
            "note": "游戏购物车继续使用 ART_FURN_103 r03 四件分层；视频购物车完全不进入游戏",
        },
        "texture": texture, "phases": phases, "godot": godot, "previews": previews,
        "godot_geometry": {
            "sprite_scale": 0.25, "sprite_offset": [-256, -672],
            "side_offset": 80, "cart_anchor": [64, 104],
            "handle_world_rel_player": [32, 56], "handle_world_y": [-90, -84],
            "layer_order": ["Back z0", "Cargo z0", "Player", "Front z1"],
            "texture_filter": "LINEAR (2), no mipmap", "stretch_mode": "canvas_items",
        },
        "speed_policy": {"walk": 100, "push": 80, "pull": 40, "unchanged": True},
    }
    for p in (CANDS / "meta.json", DELIV / "meta.json"):
        p.write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    log(f"[6/6] 完成；meta → {CANDS / 'meta.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
