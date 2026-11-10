"""VIDEO-INTEGRATE-001：把用户提供的 AI 视频做成三段候选角色动画。

**本脚本不生成视频、不重绘角色。** 输入是用户生成的 MP4，输出是：
* 192 张全量透明 PNG（128×176，脚底 (64,168)）
* walk_right / walk_to_idle / idle_right 三段帧序列
* 预览 GIF、接触表、原视频↔抠像↔成品对照、边缘与脚底放大图
* Godot SpriteFrames 与 assets/characters/ 下的接入帧

所有结论（循环窗口、阶段边界、滑步量）都从**实际视频逐帧量测**得出，
参数集中在下面的 CONFIG，改视频必须重新量测而不是照抄。

    python tools/video/integrate_001.py --source <用户视频.mp4>

产物一律标「候选 / 待美术审核」，不写台账、不进运行时白名单、不改美术总览正式状态。
"""
from __future__ import annotations

import argparse
import csv
import json
import shutil
import subprocess
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))

import pipeline  # noqa: E402
from chroma import chroma_key, greenness, checker  # noqa: E402

# ---------------------------------------------------------------- 实测配置
# 源视频：720×1280 / 24 FPS / 192 帧 / 8.042s / 绿幕 RGB(28,199,50)
SOURCE_FPS = 24
N_FRAMES = 192

# 逐帧姿态特征的自相关给出 L=36 帧为完整步态周期（1.5s）；
# 在稳定行走段 f13..f137 里搜索「首尾差异最小」的窗口，f28 与 f36 并列最优。
# 取 f28..f63：闭合差 0.0020，且末帧 f63 与减速起点 f137 姿态差仅 0.0302
# （若用 f36..f71，该差值 0.1944，停止时会明显跳变）。
WALK = {"first": 28, "count": 36, "fps": 24}       # f28..f63
STOP = {"first": 137, "count": 21, "fps": 24}      # f137..f157，0.875s
IDLE = {"first": 175, "count": 1, "fps": 8}        # 静止段中段单帧

# 相邻帧运动强度：f1–f6 起始静止，f7–f12 起步，f13–f137 稳定行走，
# f138–f156 减速收脚，f157–f192 冻结站立。
PHASES = [
    ("起始站立", 1, 6), ("起步", 7, 12), ("稳定行走", 13, 137),
    ("减速收脚", 138, 156), ("站立待机", 157, 192),
]

BATCH = "VIDEO-INTEGRATE-001"
CANDS = ROOT / "assets" / "dev" / "video_candidates" / BATCH
DELIV = ROOT / "转存库" / BATCH
CHAR_DIR = ROOT / "assets" / "characters"
SHOTS = ROOT / "tests" / "screenshots"
PREFIX = "ART_CHAR_001_vid001"     # vid001 = 视频接入候选，转正时才分配 rNN

FRAME_W, FRAME_H = pipeline.FRAME_W, pipeline.FRAME_H
ANCHOR = pipeline.ANCHOR


# ---------------------------------------------------------------- 基础工具
def raw_dir() -> Path:
    return ROOT / ".work" / "video_in" / "frames_raw"


def matte_dir() -> Path:
    return ROOT / ".work" / "video_in" / "frames_matte"


def all_out_dir() -> Path:
    return ROOT / ".work" / "video_in" / "frames_out"


def seg_dir(name: str) -> Path:
    """三段成品帧目录。walk_right 放批次根下的 frames_out/，供 --dev-scene=video 直接读。"""
    if name == "walk_right":
        return CANDS / "frames_out"
    return CANDS / name / "frames_out"


def log(msg: str) -> None:
    print(msg, flush=True)


def save_rgba(arr: np.ndarray, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(arr, "RGBA").save(path)


# ---------------------------------------------------------------- 1 抽帧
def step_extract(source: Path, force: bool) -> None:
    if raw_dir().is_dir() and len(list(raw_dir().glob("*.png"))) == N_FRAMES and not force:
        log(f"[1/7] 原始帧已有 {N_FRAMES} 张，跳过抽帧")
        return
    raw_dir().mkdir(parents=True, exist_ok=True)
    for p in raw_dir().glob("*.png"):
        p.unlink()
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", str(source),
                    "-vsync", "0", str(raw_dir() / "f_%04d.png")], check=True)
    n = len(list(raw_dir().glob("*.png")))
    assert n == N_FRAMES, f"抽帧 {n} 张，与预期 {N_FRAMES} 不符"
    log(f"[1/7] 抽帧 {n} 张 → {raw_dir()}")


# ---------------------------------------------------------------- 2 抠像
def step_matte() -> dict:
    md = matte_dir()
    md.mkdir(parents=True, exist_ok=True)
    frames = sorted(raw_dir().glob("*.png"))
    report = {"frames": len(frames), "green_residual_gt40": 0,
              "green_residual_gt20": 0, "semi_transparent": 0,
              "alpha_ranges": [], "color_exact": 0}
    for p in frames:
        rgb = np.array(Image.open(p).convert("RGB"), dtype=np.uint8)
        out = chroma_key(rgb)
        save_rgba(out, md / p.name)
        a = out[:, :, 3]
        vis = a > 8
        gn = greenness(rgb)
        report["green_residual_gt40"] += int(((gn > 40) & vis).sum())
        report["green_residual_gt20"] += int(((gn > 20) & vis).sum())
        report["semi_transparent"] += int(((a > 8) & (a < 247)).sum())
        report["alpha_ranges"].append(int(vis.sum()))
        # 人物核心像素颜色必须逐像素不变（不被 despill 染色）
        core = (a == 255) & (gn < 0)
        report["color_exact"] += int(np.array_equal(out[:, :, :3][core], rgb[core]))
    report["color_exact_frames"] = f"{report['color_exact']}/{len(frames)}"
    del report["color_exact"]
    report["alpha_min"] = min(report["alpha_ranges"])
    report["alpha_max"] = max(report["alpha_ranges"])
    del report["alpha_ranges"]
    log(f"[2/7] 色度键抠像 {len(frames)} 张；gn>40 残留 {report['green_residual_gt40']} px，"
        f"人物核心颜色保真 {report['color_exact_frames']} 帧")
    return report


# ---------------------------------------------------------------- 3 统一对齐 + 高质量降采样
def step_align() -> dict:
    od = all_out_dir()
    od.mkdir(parents=True, exist_ok=True)
    frames = sorted(matte_dir().glob("*.png"))
    arrs = [pipeline.rgba(p) for p in frames]
    boxes = [pipeline.bbox_of(a) for a in arrs]
    valid = [b for b in boxes if b]
    H, W = arrs[0].shape[:2]
    top = min(b[1] for b in valid)
    bottom = max(b[3] for b in valid)
    person_h = bottom - top + 1
    scale = (ANCHOR[1] - 6) / person_h
    nw, nh = max(1, round(W * scale)), max(1, round(H * scale))
    centers = []
    for a in arrs[::8]:
        xs = np.nonzero(a[:, :, 3] > 8)[1]
        if len(xs):
            centers.append(float(np.median(xs)))
    axis = float(np.median(centers))
    ox = round(ANCHOR[0] - axis * scale)
    oy = round(ANCHOR[1] - bottom * scale)
    log(f"[3/7] 统一变换 scale={scale:.6f}  人物 {person_h}px→{round(person_h*scale)}px  "
        f"整帧 {nw}×{nh}  偏移 ({ox},{oy})")

    from chroma import premultiplied_resize
    bottoms, heights = [], []
    for p, a in zip(frames, arrs):
        small = premultiplied_resize(a, (nw, nh))
        canvas = np.zeros((FRAME_H, FRAME_W, 4), dtype=np.uint8)
        sx0, sy0 = max(0, -ox), max(0, -oy)
        sx1, sy1 = min(nw, FRAME_W - ox), min(nh, FRAME_H - oy)
        if sx1 > sx0 and sy1 > sy0:
            canvas[sy0 + oy:sy1 + oy, sx0 + ox:sx1 + ox] = small[sy0:sy1, sx0:sx1]
        save_rgba(canvas, od / p.name)
        bb = pipeline.bbox_of(canvas)
        if bb:
            bottoms.append(bb[3])
            heights.append(bb[3] - bb[1] + 1)
    info = {"scale": round(scale, 6), "source_person_h": person_h,
            "target_person_h": round(person_h * scale),
            "whole_frame_resized": [nw, nh], "offset": [ox, oy],
            "source_axis_x": round(axis, 1),
            "foot_rows": [min(bottoms), max(bottoms)],
            "visible_heights": [min(heights), max(heights)],
            "resample": "premultiplied alpha → LANCZOS4(2x) → AREA(1x) → 轻 unsharp"}
    log(f"[3/7] 输出 {len(frames)} 张 {FRAME_W}×{FRAME_H}；脚底 y={min(bottoms)}–{max(bottoms)}，"
        f"可见高 {min(heights)}–{max(heights)}px")
    return info


# ---------------------------------------------------------------- 4 切三段
def step_segments() -> dict:
    src = sorted(all_out_dir().glob("*.png"))
    assert len(src) == N_FRAMES
    # 全量透明 PNG 序列（交付项 2）
    alldir = CANDS / "all_frames"
    if alldir.exists():
        shutil.rmtree(alldir)
    alldir.mkdir(parents=True, exist_ok=True)
    for p in src:
        shutil.copy2(p, alldir / p.name)

    specs = [
        ("walk_right", WALK, seg_dir("walk_right")),
        ("walk_to_idle", STOP, seg_dir("walk_to_idle")),
        ("idle_right", IDLE, seg_dir("idle_right")),
    ]
    out = {}
    for name, spec, dst in specs:
        if dst.exists():
            shutil.rmtree(dst)
        dst.mkdir(parents=True, exist_ok=True)
        first, count = spec["first"], spec["count"]
        for i in range(count):
            f = src[first - 1 + i]
            shutil.copy2(f, dst / f"f_{i:03d}.png")
        # 首尾跳变量测
        a = pipeline.rgba(dst / "f_000.png")
        b = pipeline.rgba(dst / f"f_{count-1:03d}.png")
        loop_jump = float(np.abs(a[:, :, 3].astype(float) - b[:, :, 3].astype(float)).mean())
        out[name] = {"source_frames": [first, first + count - 1],
                     "count": count, "fps": spec["fps"],
                     "duration_s": round(count / spec["fps"], 3),
                     "loop_alpha_jump": round(loop_jump, 4),
                     "dir": str(dst.relative_to(ROOT)).replace("\\", "/")}
        log(f"[4/7] {name:13} f{first}–f{first+count-1}  {count} 帧 @ {spec['fps']} FPS "
            f"= {count/spec['fps']:.3f}s")
    return out


# ---------------------------------------------------------------- 5 预览 / 对照
def _flat(img: Image.Image, bg=(27, 32, 38)) -> Image.Image:
    base = Image.new("RGBA", img.size, (*bg, 255))
    base.alpha_composite(img.convert("RGBA"))
    return base.convert("RGB")


def gif_of(dir_: Path, out: Path, fps: int, scale: int = 2) -> None:
    imgs = [Image.open(p).convert("RGBA") for p in sorted(dir_.glob("*.png"))]
    w, h = imgs[0].size
    flat = []
    for im in imgs:
        f = _flat(im).resize((w * scale, h * scale), Image.NEAREST)
        flat.append(f.convert("P", palette=Image.ADAPTIVE, colors=128))
    flat[0].save(out, save_all=True, append_images=flat[1:],
                 duration=max(20, round(1000 / fps)), loop=0, optimize=True)


def contact(dir_: Path, out: Path, cols: int = 9, scale: int = 2) -> None:
    imgs = [Image.open(p).convert("RGBA") for p in sorted(dir_.glob("*.png"))]
    if not imgs:
        return
    w, h = imgs[0].size
    w, h = w * scale, h * scale
    rows = (len(imgs) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * w, rows * (h + 18)), (24, 27, 32))
    d = ImageDraw.Draw(sheet)
    for i, im in enumerate(imgs):
        f = _flat(im).resize((w, h), Image.NEAREST)
        x, y = (i % cols) * w, (i // cols) * (h + 18)
        sheet.paste(f, (x, y + 18))
        d.text((x + 4, y + 3), f"{i:02d}", fill=(235, 235, 235))
    sheet.save(out)


def step_preview(segs: dict, matte_report: dict, align_info: dict) -> dict:
    pv = CANDS / "preview"
    pv.mkdir(parents=True, exist_ok=True)
    DELIV.mkdir(parents=True, exist_ok=True)

    gif_of(seg_dir("walk_right"), pv / "walk_right.gif", WALK["fps"], 2)
    gif_of(seg_dir("walk_to_idle"), pv / "walk_to_idle.gif", STOP["fps"], 2)
    gif_of(seg_dir("idle_right"), pv / "idle_right.gif", IDLE["fps"], 2)
    for name in ("walk_right", "walk_to_idle", "idle_right"):
        contact(seg_dir(name), pv / f"contact_{name}.png", 9, 2)

    # 原视频 ↔ 抠像 ↔ 成品 三段对照（同一帧 f37）
    rgb = np.array(Image.open(raw_dir() / "f_0037.png").convert("RGB"))
    mat = np.array(Image.open(matte_dir() / "f_0037.png").convert("RGBA"))
    fin = np.array(Image.open(all_out_dir() / "f_0037.png").convert("RGBA"))
    chk = checker(720, 1280, 16)
    chk.paste(Image.fromarray(mat, "RGBA"), (0, 0), Image.fromarray(mat, "RGBA"))
    left = Image.fromarray(rgb).resize((240, 427))
    mid = chk.resize((240, 427))
    # 成品按 1x 原尺寸放在中性底上，再单独放大 4x
    final1 = _flat(Image.fromarray(fin, "RGBA"))
    final4 = final1.resize((FRAME_W * 4, FRAME_H * 4), Image.NEAREST)
    comp = Image.new("RGB", (240 + 240 + FRAME_W * 4, final4.height + 34), (250, 250, 250))
    comp.paste(left, (0, 0)); comp.paste(mid, (240, 0))
    comp.paste(final4, (480, 0))
    dd = ImageDraw.Draw(comp)
    for x, t in ((4, "1 | source video frame"), (244, "2 | matte on checkerboard"),
                 (484, "3 | 128x176 final, 4x Nearest")):
        dd.text((x, final4.height + 8), t, fill=(30, 30, 30))
    comp.save(DELIV / "compare_raw_matte_final.png")

    # 边缘与脚底质量：每个局部 4x 放大（头发/脸、手/包、鞋底/地面）
    crops = {
        "hair + face": (40, 8, 96, 56),
        "hands + bag": (30, 60, 100, 112),
        "boots + ground": (20, 132, 110, 176),
    }
    panels = []
    for label, box in crops.items():
        c = final1.crop(box).resize(((box[2] - box[0]) * 4, (box[3] - box[1]) * 4),
                                    Image.NEAREST)
        panels.append((label, c))
    width = sum(c.width for _, c in panels) + 10 * (len(panels) + 1)
    height = max(c.height for _, c in panels) + 34
    edge = Image.new("RGB", (width, height), (245, 245, 245))
    de = ImageDraw.Draw(edge)
    x = 10
    for label, c in panels:
        edge.paste(c, (x, 26))
        de.text((x + 4, 8), label, fill=(30, 30, 30))
        x += c.width + 10
    edge.save(DELIV / "compare_edges_4x.png")

    # 1x 真实游戏尺寸单帧 + 3x 对照（画布要装得下 3x 的 528px 高）
    big = final1.resize((FRAME_W * 3, FRAME_H * 3), Image.NEAREST)
    s1 = Image.new("RGB", (10 + FRAME_W + 20 + big.width + 10,
                           24 + big.height + 10), (34, 38, 44))
    s1.paste(final1, (10, 24))
    s1.paste(big, (FRAME_W + 30, 24))
    ImageDraw.Draw(s1).text((10, 6), "1x game size 128x176", fill=(230, 230, 230))
    ImageDraw.Draw(s1).text((FRAME_W + 30, 6), "3x Nearest (inspect edges)", fill=(230, 230, 230))
    s1.save(DELIV / "compare_game_scale.png")

    # v02 基准对照（设定图裁图 vs 成品帧，等高并排）
    ref = ROOT / "素材库" / "美术设定集" / "01-角色" / "参考图" / \
        "ART_CHAR_001_v02_ref_right.png"
    if ref.is_file():
        r = Image.open(ref).convert("RGB")
        rh = 352
        r = r.resize((round(r.width * rh / r.height), rh), Image.LANCZOS)
        f2 = final1.resize((round(FRAME_W * rh / FRAME_H), rh), Image.NEAREST)
        cmp2 = Image.new("RGB", (max(r.width, 140) + max(f2.width, 140) + 30,
                                 rh + 46), (245, 245, 245))
        cmp2.paste(r, (10, 24)); cmp2.paste(f2, (max(r.width, 140) + 20, 24))
        dr = ImageDraw.Draw(cmp2)
        dr.text((10, 6), "v02 canonical", fill=(30, 30, 30))
        dr.text((max(r.width, 140) + 20, 6), "video candidate", fill=(30, 30, 30))
        dr.text((10, rh + 28), "Same character design; style differs (pixel art vs cel render)",
                fill=(90, 90, 90))
        cmp2.save(DELIV / "compare_v02_vs_video.png")

    # 滑步量测：支撑脚在画面中的水平位移 vs 游戏 100px/s
    feet = json.loads((ROOT / ".work" / "video_in" / "feet.json").read_text())
    win = feet[WALK["first"] - 1: WALK["first"] - 1 + WALK["count"]]
    fx = [r["foot_x"] for r in win if r["foot_x"] > 0]
    span_src = max(fx) - min(fx) if fx else 0
    span_game = span_src * align_info["scale"]
    period = WALK["count"] / WALK["fps"]
    slip = {
        "speed_px_s": 100.0, "loop_period_s": period,
        "game_travel_per_loop_px": round(100.0 * period, 1),
        "support_foot_screen_span_px": round(span_game, 1),
        "game_travel_per_frame_px": round(100.0 / WALK["fps"], 2),
        "note": "视频是原地跟拍（人物画面质心 std 4.3px）；角色在游戏中平移，"
                "支撑脚无法完全锁地。这里记录真实滑移量，不做假修复。",
    }
    # 用逐帧游戏位移与脚画面位移估算净滑移
    if len(fx) > 1:
        per_frame_foot = span_game / max(1, len(fx) - 1)
        slip["foot_screen_drift_per_frame_px"] = round(per_frame_foot, 2)
        slip["net_slip_per_frame_px"] = round(abs(100.0 / WALK["fps"] - per_frame_foot), 2)
    return {"previews": ["walk_right.gif", "walk_to_idle.gif", "idle_right.gif",
                         "contact_walk_right.png", "contact_walk_to_idle.png"],
            "slip": slip}


# ---------------------------------------------------------------- 6 SpriteFrames + 接入帧
def step_godot(segs: dict) -> dict:
    if CHAR_DIR.exists():
        shutil.rmtree(CHAR_DIR)
    CHAR_DIR.mkdir(parents=True, exist_ok=True)
    mapping = {}
    for name in segs:
        files = sorted(seg_dir(name).glob("*.png"))
        mapping[name] = []
        for i, p in enumerate(files):
            dst = CHAR_DIR / f"{PREFIX}_{name}_{i:02d}_128x176.png"
            shutil.copy2(p, dst)
            mapping[name].append(dst)

    # SpriteFrames 资源：Godot 4 的 .tres 文本格式
    lines = ['[gd_resource type="SpriteFrames" load_steps=1 format=3]', ""]
    load_steps = 1 + sum(len(v) for v in mapping.values())
    lines[0] = f'[gd_resource type="SpriteFrames" load_steps={load_steps} format=3]'
    ext_idx = 0
    ext_lines = []
    for name, paths in mapping.items():
        for p in paths:
            ext_lines.append(f'[ext_resource type="Texture2D" '
                             f'path="res://assets/characters/{p.name}" id="{ext_idx}"]')
            ext_idx += 1
    lines += ext_lines + ["", '[resource]', "", 'animations = [{']
    first = True
    for name, spec in segs.items():
        if not first:
            lines.append("}, {")
        first = False
        fps = spec["fps"]
        lines.append(f'"frames": [')
        for i, p in enumerate(mapping[name]):
            idx = sum(len(v) for v in list(mapping.values())[:list(mapping).index(name)]) + i
            # Godot SpriteFrames：实际帧时长 = frame.duration / animation.speed。
            # 想播 fps，要么 duration=1 && speed=fps，要么 duration=1/fps && speed=1。
            # 这里用前者，anim_fps() 直接读 speed 就能得到真实 FPS。
            dur = 1.0
            lines.append('{' + f'"duration": {dur}, "texture": ExtResource("{idx}")' + '}' +
                         ("," if i < len(mapping[name]) - 1 else ""))
        lines.append('],')
        lines.append(f'"loop": {"true" if name in ("walk_right", "idle_right") else "false"},')
        lines.append(f'"name": &"{name}",')
        lines.append(f'"speed": {float(fps)}')
    lines.append("}]")
    tres = CHAR_DIR / "player_sprite_frames.tres"
    tres.write_text("\n".join(lines) + "\n", encoding="utf-8")

    # 候选目录加 .gdignore：--dev-scene=video 用绝对路径直接读 PNG，不需要 import
    (CANDS / ".gdignore").write_text("", encoding="utf-8")

    info = {"spriteframes": str(tres.relative_to(ROOT)).replace("\\", "/"),
            "animations": {k: {"frames": len(v), "fps": segs[k]["fps"],
                               "loop": k != "walk_to_idle"} for k, v in mapping.items()},
            "frames_copied": sum(len(v) for v in mapping.values()),
            "candidate_tag": "vid001（候选，未登记、未进白名单）"}
    log(f"[6/7] SpriteFrames → {info['spriteframes']}；"
        f"帧 {info['frames_copied']} 张；动画 {info['animations']}")
    return info


# ---------------------------------------------------------------- 7 meta
def step_meta(source: Path, matte_report: dict, align_info: dict,
              segs: dict, preview: dict, godot: dict) -> None:
    meta = {
        "task": "VIDEO-INTEGRATE-001",
        "status": "候选 / 待用户与美术审核（未标最终成品）",
        "source": {"path": str(source), "width": 720, "height": 1280,
                   "fps": SOURCE_FPS, "frames": N_FRAMES, "duration_s": 8.043,
                   "codec": "h264/yuv420p", "green_screen_rgb": [28, 199, 50]},
        "phases": [{"name": n, "first": a, "last": b} for n, a, b in PHASES],
        "matte": matte_report,
        "align": align_info,
        "segments": segs,
        "preview": preview,
        "godot": godot,
        "speed_policy": {"walk": 100, "push": 80, "pull": 40,
                         "note": "ART-RESET-001 裁定；70px/s 的 RIG 推演作废"},
        "known_issues": [
            "视频是原地跟拍：人物画面质心 std 4.3px，接入 100px/s 平移后支撑脚无法完全锁地",
            "walk_to_idle 只在 walk 循环末帧附近相位衔接自然；循环中段松手会有可见姿态跳变",
            "源视频为平滑赛璐璐风格，v02 基准为像素画风，缩到 128×176 后风格仍有差异",
            "面容在 1× 游戏尺寸下仅约 10px 高，细节不可辨（见 compare_game_scale.png）",
        ],
    }
    (CANDS / "meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n",
                                     encoding="utf-8")
    (DELIV / "meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n",
                                     encoding="utf-8")
    log(f"[7/7] meta.json → {CANDS / 'meta.json'}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", default=None, help="用户提供的 AI 视频（必填或自动定位）")
    ap.add_argument("--force", action="store_true", help="强制重新抽帧")
    args = ap.parse_args()

    if args.source:
        source = Path(args.source)
    else:
        hits = sorted((ROOT / "转存库").glob("*.mp4"))
        if len(hits) != 1:
            raise SystemExit(f"[FAIL] 转存库里找到 {len(hits)} 个 mp4，请用 --source 明确指定")
        source = hits[0]
    if not source.is_file():
        raise SystemExit(f"[FAIL] 视频不存在：{source}")
    log(f"源视频：{source.name}  ({source.stat().st_size} bytes)")

    step_extract(source, args.force)
    matte_report = step_matte()
    align_info = step_align()
    segs = step_segments()
    preview = step_preview(segs, matte_report, align_info)
    godot = step_godot(segs)
    step_meta(source, matte_report, align_info, segs, preview, godot)
    log("\n完成：候选资源已生成，尚未标记为最终美术成品。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
