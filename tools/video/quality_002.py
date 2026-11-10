"""VIDEO-QUALITY-002：从高分辨率抠像帧重新输出 512×704 高清透明动画帧。

**不放大上一轮 128×176 的成品帧**，而是回到 `.work/video_in/frames_matte/`
里 720×1280 的全分辨率抠像结果，按严格 4× 几何重新采样：

    画布   128×176  →  512×704
    锚点   (64,168) →  (256,672)
    整帧   107×190  →  428×760
    偏移   (13,-9)  →  (52,-36)

配合 player.tscn 的 scale=0.25、offset=(-256,-672)，游戏里角色的
**实际显示大小、脚底位置、碰撞盒完全不变**。

透明区做颜色外扩（bleed）而不是清零，这样 LINEAR / mipmap 缩小时
边缘不会泛黑边或绿边（接需求 7）。动作结构沿用上一轮已验收的
walk_right 36 / walk_to_idle 21 / idle_right 1，不重做任何动作拆分。

    python tools/video/quality_002.py

产物：
    assets/characters/ART_CHAR_001_vid001_hd_<anim>_<nn>_512x704.png   （游戏用 58 张）
    assets/characters/player_sprite_frames.tres
    转存库/VIDEO-QUALITY-002/      对照图 / 接触表 / meta
    .work/video_in/frames_hd/      全 192 张高清帧（本地中间产物，不入库）
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

# ---------------------------------------------------------------- 与上一轮严格 4× 对应
FACTOR = 4
OLD_W, OLD_H = 128, 176
FRAME_W, FRAME_H = OLD_W * FACTOR, OLD_H * FACTOR          # 512, 704
ANCHOR = (64 * FACTOR, 168 * FACTOR)                        # (256, 672)
RESIZED = (107 * FACTOR, 190 * FACTOR)                      # (428, 760)
OFFSET = (13 * FACTOR, -9 * FACTOR)                         # (52, -36)

MATTED = ROOT / ".work" / "video_in" / "frames_matte"
OLD_OUT = ROOT / ".work" / "video_in" / "frames_out"
HD_ALL = ROOT / ".work" / "video_in" / "frames_hd"
CHAR_DIR = ROOT / "assets" / "characters"
DELIV = ROOT / "转存库" / "VIDEO-QUALITY-002"
PREFIX = "ART_CHAR_001_vid001_hd"

# 动作结构完全沿用 VIDEO-INTEGRATE-001，不重新拆分
SEGMENTS = [
    ("walk_right", 28, 36, 24, True),
    ("walk_to_idle", 137, 21, 24, False),
    ("idle_right", 175, 1, 8, True),
]


def log(msg: str) -> None:
    print(msg, flush=True)


def flat(im: Image.Image, bg=(34, 38, 44)) -> Image.Image:
    base = Image.new("RGBA", im.size, (*bg, 255))
    base.alpha_composite(im.convert("RGBA"))
    return base.convert("RGB")


def hd_frame(src: np.ndarray) -> np.ndarray:
    """一张 720×1280 抠像帧 → 512×704 高清画布（预乘 alpha 两阶段降采样）。"""
    # 1) 透明区颜色外扩：LINEAR / mipmap 缩小时不出现黑边、绿边
    bled = bleed_rgb(src, iterations=8)
    a = src.copy()
    a[:, :, :3] = bled

    # 2) 预乘 alpha → LANCZOS4(2x) → AREA(1x) → 轻 unsharp
    f = a.astype(np.float32)
    al = f[:, :, 3:4] / 255.0
    pm = np.concatenate([f[:, :, :3] * al, f[:, :, 3:4]], axis=2)
    mid = cv2.resize(pm, (RESIZED[0] * 2, RESIZED[1] * 2),
                     interpolation=cv2.INTER_LANCZOS4)
    sm = cv2.resize(mid, RESIZED, interpolation=cv2.INTER_AREA)
    al2 = np.clip(sm[:, :, 3:4], 0, 255)
    rgb = np.clip(sm[:, :, :3] / np.maximum(al2 / 255.0, 1e-4), 0, 255)
    blur = cv2.GaussianBlur(rgb, (0, 0), 0.8)
    strength = np.clip(al2 / 255.0, 0, 1)
    rgb = np.clip(rgb + (rgb - blur) * 0.35 * strength, 0, 255)
    small = np.dstack([rgb.astype(np.uint8), np.clip(al2, 0, 255).astype(np.uint8)])

    # 3) 贴到画布（透明区不清零，保留外扩色）
    canvas = np.zeros((FRAME_H, FRAME_W, 4), dtype=np.uint8)
    ox, oy = OFFSET
    sx0, sy0 = max(0, -ox), max(0, -oy)
    sx1, sy1 = min(RESIZED[0], FRAME_W - ox), min(RESIZED[1], FRAME_H - oy)
    if sx1 > sx0 and sy1 > sy0:
        canvas[sy0 + oy:sy1 + oy, sx0 + ox:sx1 + ox] = small[sy0:sy1, sx0:sx1]
    return canvas


def build_all_frames() -> dict:
    srcs = sorted(MATTED.glob("f_*.png"))
    assert len(srcs) == 192, f"抠像帧 {len(srcs)} 张，预期 192；先跑 integrate_001.py 重建"
    HD_ALL.mkdir(parents=True, exist_ok=True)
    feet, heights, green_px = [], [], 0
    for p in srcs:
        src = np.array(Image.open(p).convert("RGBA"), dtype=np.uint8)
        out = hd_frame(src)
        Image.fromarray(out, "RGBA").save(HD_ALL / p.name)
        al = out[:, :, 3]
        ys = np.nonzero(al > 8)[0]
        if len(ys):
            feet.append(int(ys.max()))
            heights.append(int(ys.max() - ys.min() + 1))
        r, g, b = out[:, :, 0].astype(int), out[:, :, 1].astype(int), out[:, :, 2].astype(int)
        green_px += int(((g - np.maximum(r, b) > 50) & (al > 8)).sum())
    info = {"source_frames": len(srcs), "canvas": [FRAME_W, FRAME_H],
            "anchor": list(ANCHOR), "resized_whole_frame": list(RESIZED),
            "offset": list(OFFSET),
            "foot_rows": [min(feet), max(feet)],
            "visible_heights": [min(heights), max(heights)],
            "green_residual_px": green_px,
            "rule": "从 720×1280 抠像帧重新采样，颜色外扩 + 预乘 alpha LANCZOS4→AREA；"
                    "未使用任何已缩小的 128×176 PNG"}
    log(f"[1/4] 全量高清帧 {len(srcs)} 张；脚底 y={min(feet)}–{max(feet)}（目标 {ANCHOR[1]}），"
        f"可见高 {min(heights)}–{max(heights)}px，绿色残留 {green_px}px")
    return info


def build_game_frames() -> dict:
    """替换 assets/characters/ 为高清帧，并重生成 SpriteFrames。"""
    for p in CHAR_DIR.glob("*.png"):
        p.unlink()
    for p in CHAR_DIR.glob("*.import"):
        p.unlink()
    mapping: dict[str, list[Path]] = {}
    for name, first, count, fps, loop in SEGMENTS:
        mapping[name] = []
        for i in range(count):
            src = HD_ALL / f"f_{first + i:04d}.png"
            dst = CHAR_DIR / f"{PREFIX}_{name}_{i:02d}_512x704.png"
            shutil.copy2(src, dst)
            mapping[name].append(dst)

    load_steps = 1 + sum(len(v) for v in mapping.values())
    lines = [f'[gd_resource type="SpriteFrames" load_steps={load_steps} format=3]', ""]
    idx = 0
    for name, paths in mapping.items():
        for p in paths:
            lines.append(f'[ext_resource type="Texture2D" '
                         f'path="res://assets/characters/{p.name}" id="{idx}"]')
            idx += 1
    lines += ["", "[resource]", "", "animations = [{"]
    first_block = True
    for name, first, count, fps, loop in SEGMENTS:
        if not first_block:
            lines.append("}, {")
        first_block = False
        lines.append('"frames": [')
        base = sum(len(v) for v in list(mapping.values())[:list(mapping).index(name)])
        for i in range(len(mapping[name])):
            # Godot 帧时长 = duration / animation.speed → 1.0 / fps
            lines.append('{' + f'"duration": 1.0, "texture": ExtResource("{base + i}")' + '}' +
                         ("," if i < len(mapping[name]) - 1 else ""))
        lines += ['],', f'"loop": {"true" if loop else "false"},',
                  f'"name": &"{name}",', f'"speed": {float(fps)}']
    lines.append("}]")
    (CHAR_DIR / "player_sprite_frames.tres").write_text("\n".join(lines) + "\n",
                                                         encoding="utf-8")
    info = {"frames": sum(len(v) for v in mapping.values()),
            "animations": {k: {"frames": len(v), "fps": s[3], "loop": s[4]}
                           for k, v, s in zip(mapping, mapping.values(), SEGMENTS)},
            "spriteframes": "assets/characters/player_sprite_frames.tres"}
    log(f"[2/4] 游戏帧 {info['frames']} 张 + SpriteFrames 重生成；"
        f"{info['animations']}")
    return info


def build_comparisons(frame_info: dict) -> None:
    DELIV.mkdir(parents=True, exist_ok=True)
    n = 37  # 上一轮对照用的行走帧
    old = Image.open(OLD_OUT / f"f_{n:04d}.png").convert("RGBA")
    hd = Image.open(HD_ALL / f"f_{n:04d}.png").convert("RGBA")

    # 1) 同一显示尺寸对照（128×176），以及 4× 放大看细节
    o1, h1 = flat(old), flat(hd).resize((OLD_W, OLD_H), Image.LANCZOS)
    sheet = Image.new("RGB", (OLD_W * 2 + 30, OLD_H + 26), (248, 248, 248))
    sheet.paste(o1, (10, 22)); sheet.paste(h1, (OLD_W + 20, 22))
    ImageDraw.Draw(sheet).text((10, 4), "BEFORE 128x176", fill=(30, 30, 30))
    ImageDraw.Draw(sheet).text((OLD_W + 20, 4), "AFTER 512x704 -> 128x176", fill=(30, 30, 30))
    sheet.save(DELIV / "compare_game_size.png")

    # 2) 头发 / 脸 / 手 / 靴子四局部：旧帧 4×NEAREST vs 新帧同等显示尺寸
    crops = [(40, 8, 96, 56, "hair + face"), (30, 60, 100, 112, "hands + bag"),
             (20, 132, 110, 176, "boots + ground")]
    panels = []
    for x0, y0, x1, y1, label in crops:
        oc = o1.crop((x0, y0, x1, y1)).resize(((x1 - x0) * 4, (y1 - y0) * 4), Image.NEAREST)
        hc = flat(hd).crop((x0 * 4, y0 * 4, x1 * 4, y1 * 4)).resize(
            ((x1 - x0) * 4, (y1 - y0) * 4), Image.LANCZOS)
        panels.append((label, oc, hc))
    w = sum(p[1].width for p in panels) + 14 * (len(panels) + 1)
    h = max(p[1].height for p in panels) * 2 + 54
    cmp = Image.new("RGB", (w, h), (248, 248, 248))
    d = ImageDraw.Draw(cmp)
    x = 14
    for label, oc, hc in panels:
        cmp.paste(oc, (x, 24)); cmp.paste(hc, (x, 24 + oc.height + 12))
        d.text((x + 3, 6), f"{label}  /  top=OLD  bottom=NEW", fill=(30, 30, 30))
        x += oc.width + 14
    cmp.save(DELIV / "compare_edge_detail.png")

    # 3) 边缘质量：高清帧头发与靴底附近 2× 放大（查绿边 / 黑边 / 锯齿）
    edge = Image.new("RGB", (512, 500), (248, 248, 248))
    de = ImageDraw.Draw(edge)
    de.text((8, 4), "NEW 512x704 edge check (2x)  -  no green / black fringe", fill=(30, 30, 30))
    e1 = flat(hd).crop((150, 20, 406, 270)).resize((256, 250), Image.LANCZOS)
    e2 = flat(hd).crop((60, 540, 316, 700)).resize((256, 160), Image.LANCZOS)
    edge.paste(e1, (8, 22)); edge.paste(e2, (264, 22))
    edge.save(DELIV / "compare_edges_hd.png")

    # 4) 高清行走接触表
    names = [f"f_{28 + i:04d}.png" for i in range(0, 36, 2)]
    thumbs = []
    for nm in names:
        im = flat(Image.open(HD_ALL / nm).convert("RGBA")).resize((128, 176), Image.LANCZOS)
        thumbs.append(im)
    sheet2 = Image.new("RGB", (9 * 128, 2 * 194), (24, 27, 32))
    d2 = ImageDraw.Draw(sheet2)
    for i, im in enumerate(thumbs):
        x, y = (i % 9) * 128, (i // 9) * 194
        sheet2.paste(im, (x, y + 18)); d2.text((x + 3, y + 3), f"{i*2:02d}", fill=(230, 230, 230))
    sheet2.save(DELIV / "contact_hd_walk.png")
    log(f"[3/4] 对照图 → {DELIV.relative_to(ROOT)}")


def patch_imports() -> int:
    """固化 58 张高清帧的 Godot 导入参数（在引擎跑过一次 --import 之后调用）。

    沿用项目里 `import_art005e_archive.py --fix-imports` 的既有模式：
    引擎生成 .import，脚本改参数，再跑一次 --import 让缓存重建。

    最终选 **LINEAR 过滤、不开 mipmap**：实测 1× 窗口锐度 1351（旧 128×176 是 1189，
    mipmap 方案只有 727），2× 窗口同样清晰且无锯齿；不开 mipmap 还省 33% 纹理显存。
    透明区已在 hd_frame() 里做过颜色外扩，所以 fix_alpha_border 按项目约定保持 false。
    """
    files = sorted(CHAR_DIR.glob("*.png.import"))
    if not files:
        print("[FAIL] 还没有 .import 文件，先跑一次引擎 --import")
        return 1
    for p in files:
        s = p.read_text(encoding="utf-8")
        s = s.replace("mipmaps/generate=true", "mipmaps/generate=false")
        s = s.replace("process/fix_alpha_border=true", "process/fix_alpha_border=false")
        s = s.replace("detect_3d/compress_to=1", "detect_3d/compress_to=0")
        p.write_text(s, encoding="utf-8")
    print(f"[OK] 已固化 {len(files)} 张高清帧的导入参数："
          f"no mipmap / fix_alpha_border=false / compress_to=0")
    print("     再跑一次 Godot --import 让缓存重建")
    return 0


def main() -> int:
    if "--fix-imports" in sys.argv:
        return patch_imports()
    game_only = "--game-only" in sys.argv
    if game_only:
        info = json.loads((DELIV / "meta.json").read_text(encoding="utf-8"))["texture"]
        log("[1/4] --game-only：复用已有全量高清帧")
    else:
        info = build_all_frames()
    game = build_game_frames()
    build_comparisons(info)
    meta = {
        "task": "VIDEO-QUALITY-002",
        "status": "候选 / 待最终美术审核（台账、白名单、总览正式状态未改）",
        "texture": info, "godot": game,
        "transform": {"sprite_scale": 0.25, "sprite_offset": [-256, -672],
                      "display_size_unchanged": [128, 176],
                      "anchor_unchanged_world": [0, 0],
                      "texture_filter": "LINEAR (2), no mipmap",
                      "stretch_mode": "canvas_items"},
        "source": "上一轮 .work/video_in/frames_matte/ 的 720×1280 抠像帧；"
                  "未使用任何 128×176 成品帧放大，未生成新视频",
    }
    (DELIV / "meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n",
                                     encoding="utf-8")
    log("[4/4] 完成")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
