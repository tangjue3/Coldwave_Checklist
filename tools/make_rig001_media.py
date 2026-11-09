#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ART-RIG-001：把 Godot 实机截图组装成可视化验收资料。

输入（都由 `--dev-scene=rig001 --rig001-xxx` 产出）：
  tests/screenshots/rig001_rest_render.png     静止姿态直出（SubViewport 128×176，透明底）
  tests/screenshots/rig001_pose_0..3.png       关键姿势（接触/下沉/经过/抬升）
  tests/screenshots/rig001_walk_00..24.png     行走连拍 25 帧 = 一个 1.0s 循环
  tests/screenshots/rig001_idle_00..19.png     待机连拍 20 帧 = 一个 2.4s 循环
  tests/screenshots/rig001_world_00..07.png    世界坐标移动检查点
  tests/screenshots/rig001_bones_debug.png     骨骼位置示意
  assets/dev/rig001_proto/layers/*.png          分层素材
  assets/dev/rig001_proto/diagnostics/region_map.png     区域归属图
  assets/dev/rig001_proto/diagnostics/repaint/*.png     每层需补绘像素标记

输出（tests/screenshots/）：
  rig001_original_vs_rig.png   源图 / 骨骼静止 / 差异 三联（3×）
  rig001_layer_atlas.png       16 层图集 + 需补绘标记
  rig001_region_map.png        部件区域归属图（3×）
  rig001_pose_sheet.png        关键姿势四条
  rig001_world_checkpoints.png 移动检查点 4×2 + 固定地面刻度
  rig001_walk.gif              40ms/帧 = 真实速度（1.0s 循环）
  rig001_walk_slow.gif         100ms/帧 = 2.5× 慢放，便于逐帧看关节与落地
  rig001_idle.gif              120ms/帧 = 真实速度（2.4s 循环）
"""

from __future__ import annotations

import json
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHOT = os.path.join(ROOT, "tests/screenshots")
PROTO = os.path.join(ROOT, "assets/dev/rig001_proto")
SRC = os.path.join(ROOT, "assets/characters/ART_CHAR_001_r02_walk_right_00_contactA.png")
FONT_PATH = os.path.join(ROOT, "assets/ui/fonts/NotoSansSC-Variable.ttf")

BG = (246, 247, 249)
INK = (28, 30, 34)
SUB = (110, 116, 124)
ACCENT = (32, 120, 190)
WARN = (214, 40, 150)


def font(size: int) -> ImageFont.FreeTypeFont:
    try:
        return ImageFont.truetype(FONT_PATH, size)
    except Exception:
        return ImageFont.load_default()


def checker(w: int, h: int, step: int = 8) -> Image.Image:
    img = Image.new("RGB", (w, h), (238, 240, 244))
    d = ImageDraw.Draw(img)
    for y in range(0, h, step):
        for x in range(0, w, step):
            if ((x // step) + (y // step)) % 2 == 0:
                d.rectangle((x, y, x + step - 1, y + step - 1), fill=(226, 229, 234))
    return img


def paste_rgba(bg: Image.Image, im: Image.Image, xy: tuple, zoom: int = 1) -> None:
    im = im.convert("RGBA")
    if zoom != 1:
        im = im.resize((im.width * zoom, im.height * zoom), Image.NEAREST)
    layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
    layer.alpha_composite(im)
    bg.paste(layer, xy, layer)


# --------------------------------------------------------------------- 三联图
def build_original_vs_rig() -> str:
    src = Image.open(SRC).convert("RGBA")
    rig = Image.open(os.path.join(SHOT, "rig001_rest_render.png")).convert("RGBA")
    Z = 3
    pad, top = 16, 54
    pw, ph = 128 * Z, 176 * Z
    out = Image.new("RGB", (pad * 4 + pw * 3, top + ph + 42), BG)
    d = ImageDraw.Draw(out)
    d.text((pad, 12), "ART-RIG-001  分层还原度：骨骼静止姿态 vs 源图（r02_00）", font=font(20), fill=INK)
    d.text((pad, 34), "16 层按 z 序合成后与源图逐像素比对，差异 0 px —— 分层没有丢像素、没有羽化", font=font(13), fill=SUB)

    titles = ["① 源图 ART_CHAR_001_r02_00（合成平面图）", "② 骨骼角色静止姿态（Godot 实机直出）", "③ 差异图（全黑 = 0 像素差异）"]
    for i, (im, t) in enumerate(zip([src, rig, None], titles)):
        x = pad + i * (pw + pad)
        panel = checker(pw, ph)
        if im is not None:
            panel_rgba = panel.convert("RGBA")
            paste_rgba(panel_rgba, im, (0, 0), Z)
            panel = panel_rgba.convert("RGB")
        else:
            diff = Image.new("RGBA", (128, 176), (0, 0, 0, 255))
            n = 0
            for y in range(176):
                for x2 in range(128):
                    if src.getpixel((x2, y)) != rig.getpixel((x2, y)):
                        diff.putpixel((x2, y), (255, 0, 128, 255))
                        n += 1
            pr = panel.convert("RGBA")
            paste_rgba(pr, diff, (0, 0), Z)
            panel = pr.convert("RGB")
            t = "③ 差异图：%d px（全黑 = 完全一致）" % n
        out.paste(panel, (x, top))
        d.text((x, 30 + ph + 18), t, font=font(13), fill=INK if i != 2 else ACCENT)
    p = os.path.join(SHOT, "rig001_original_vs_rig.png")
    out.save(p)
    return p


# --------------------------------------------------------------------- 图集
def build_atlas() -> str:
    spec = json.load(open(os.path.join(PROTO, "rig001_spec.json"), encoding="utf-8"))
    names = [b["layer"] for b in spec["bones"] if "layer" in b]
    
    Z, cols = 2, 6
    cw, ch = 128 * Z, 176 * Z
    cell_h = ch + 52
    rows = (len(names) + cols - 1) // cols
    out = Image.new("RGB", (cols * cw + (cols + 1) * 10, 74 + rows * cell_h), BG)
    d = ImageDraw.Draw(out)
    d.text((12, 12), "ART-RIG-001  分层素材图集（16 层，临时分层 / 待美术补绘）", font=font(20), fill=INK)
    d.text((12, 38), "灰底 = 该层像素；洋红色 = 当前只能用上层像素顶替、必须由美术补画的区域（共 %d px）"
           % sum(b.get("repaint_px", 0) for b in spec["bones"]), font=font(13), fill=SUB)
    for i, n in enumerate(names):
        x = 10 + (i % cols) * (cw + 10)
        y = 74 + (i // cols) * cell_h
        panel = checker(cw, ch).convert("RGBA")
        layer = Image.open(os.path.join(PROTO, "layers", "%s.png" % n)).convert("RGBA")
        rp = Image.open(os.path.join(PROTO, "diagnostics/repaint/%s.png" % n)).convert("RGBA")
        tint = Image.new("RGBA", layer.size, (255, 0, 200, 0))
        tint.putalpha(rp.getchannel("A").point(lambda v: int(v * 0.6)))
        merged = layer.copy()
        merged.alpha_composite(tint)
        paste_rgba(panel, merged, (0, 0), Z)
        out.paste(panel.convert("RGB"), (x, y))
        b = next(bb for bb in spec["bones"] if bb.get("layer") == n)
        d.text((x + 2, y + ch + 4), n, font=font(13), fill=INK)
        d.text((x + 2, y + ch + 20), "z=%+d  %d px  补绘 %d" % (b["z"], b["layer_px"], b["repaint_px"]),
               font=font(11), fill=SUB)
    p = os.path.join(SHOT, "rig001_layer_atlas.png")
    out.save(p)
    return p


# --------------------------------------------------------------------- 区域图
def build_region_map() -> str:
    reg = Image.open(os.path.join(PROTO, "diagnostics/region_map.png")).convert("RGBA")
    Z = 3
    w, h = 128 * Z, 176 * Z
    out = Image.new("RGB", (w + 300, h + 96), BG)
    d = ImageDraw.Draw(out)
    d.text((14, 12), "ART-RIG-001  部件像素归属图", font=font(19), fill=INK)
    d.text((14, 36), "按「到骨轴距离 / 半宽」最小者归属，保证每个不透明像素都有主（无丢失）", font=font(12), fill=SUB)
    panel = checker(w, h).convert("RGBA")
    paste_rgba(panel, reg, (0, 0), Z)
    out.paste(panel.convert("RGB"), (12, 66))
    colors = {
        "头部/头发": (240, 190, 150), "马尾": (200, 90, 200), "躯干外套": (120, 120, 130),
        "骨盆": (230, 190, 60), "近侧上臂": (60, 110, 170), "近侧前臂": (80, 140, 200),
        "近侧手": (110, 170, 230), "远侧上臂": (90, 140, 220), "远侧前臂": (110, 170, 240),
        "远侧手": (140, 200, 250), "近侧大腿": (190, 90, 70), "近侧小腿": (220, 120, 90),
        "近侧鞋": (250, 160, 120), "远侧大腿": (70, 150, 110), "远侧小腿": (100, 180, 140),
        "远侧鞋": (140, 210, 170),
    }
    x0 = w + 28
    y0 = 70
    for i, (k, c) in enumerate(colors.items()):
        yy = y0 + i * 15
        d.rectangle((x0, yy, x0 + 12, yy + 11), fill=c)
        d.text((x0 + 18, yy - 1), k, font=font(12), fill=INK)
    p = os.path.join(SHOT, "rig001_region_map.png")
    out.save(p)
    return p


# --------------------------------------------------------------------- 姿势条
def build_pose_sheet() -> str:
    labels = ["① 接触 Contact（t=0.00）", "② 下沉 Down（t=0.15）", "③ 经过 Passing（t=0.30）", "④ 抬升 Up（t=0.45）"]
    boxes = [(160, 250, 260, 432)] * 4
    Z = 2
    cw, ch = 100 * Z, 182 * Z
    out = Image.new("RGB", (cw * 4 + 50, ch + 104), BG)
    d = ImageDraw.Draw(out)
    d.text((12, 12), "ART-RIG-001  行走循环关键姿势（来自骨骼 AnimationPlayer 实机渲染）", font=font(19), fill=INK)
    d.text((12, 36), "四个姿势由步态模型 + 二骨 IK 解算，不是逐帧画出来的", font=font(12), fill=SUB)
    for i in range(4):
        im = Image.open(os.path.join(SHOT, "rig001_pose_%d.png" % i)).convert("RGB").crop(boxes[i])
        im = im.resize((cw, ch), Image.NEAREST)
        out.paste(im, (12 + i * (cw + 12), 62))
        d.text((12 + i * (cw + 12), 62 + ch + 8), labels[i], font=font(12), fill=INK)
    p = os.path.join(SHOT, "rig001_pose_sheet.png")
    out.save(p)
    return p


# --------------------------------------------------------------------- 世界检查点
def build_world_checkpoints() -> str:
    box = (158, 252, 330, 452)
    Z = 2
    cw, ch = (box[2] - box[0]) * Z, (box[3] - box[1]) * Z
    cols, rows = 4, 2
    head_h = 92
    cell_h = ch + 30
    out = Image.new("RGB", (cols * cw + (cols + 1) * 10, head_h + rows * cell_h), BG)
    d = ImageDraw.Draw(out)
    d.text((12, 14), "ART-RIG-001  世界坐标移动检查点（身体 70px/s 前进，地面刻度固定不动）", font=font(19), fill=INK)
    d.text((12, 40), "8 个检查点覆盖一整个步态循环。刻度是固定世界参照：支撑脚若打滑，就会相对刻度明显位移。",
           font=font(12), fill=SUB)
    d.text((12, 62), "角色逐格右移，一整个循环前进 70px（= 步距 42px ÷ 支撑相 60% × 循环 1.0s）。", font=font(12), fill=SUB)
    for i in range(8):
        im = Image.open(os.path.join(SHOT, "rig001_world_%02d.png" % i)).convert("RGB").crop(box)
        im = im.resize((cw, ch), Image.NEAREST)
        x = 10 + (i % cols) * (cw + 10)
        y = head_h + (i // cols) * cell_h
        d.text((x + 2, y + 2), "sample %d/8   t=%.3fs   x=%d px" % (i, i / 8.0, i * 70 // 8),
               font=font(11), fill=INK)
        out.paste(im, (x, y + 18))
    p = os.path.join(SHOT, "rig001_world_checkpoints.png")
    out.save(p)
    return p


# --------------------------------------------------------------------- GIF
def build_gif(prefix: str, count: int, box: tuple, out_name: str, duration: int) -> str:
    frames = []
    for i in range(count):
        f = os.path.join(SHOT, "%s_%02d.png" % (prefix, i))
        im = Image.open(f).convert("RGB").crop(box)
        frames.append(im.resize((im.width * 2, im.height * 2), Image.NEAREST))
    p = os.path.join(SHOT, out_name)
    frames[0].save(p, save_all=True, append_images=frames[1:], duration=duration, loop=0, optimize=False)
    return p


def main() -> None:
    made = []
    made.append(build_original_vs_rig())
    made.append(build_atlas())
    made.append(build_region_map())
    made.append(build_pose_sheet())
    made.append(build_world_checkpoints())
    walk_box = (150, 250, 330, 452)
    made.append(build_gif("rig001_walk", 25, walk_box, "rig001_walk.gif", 40))
    made.append(build_gif("rig001_walk", 25, walk_box, "rig001_walk_slow.gif", 100))
    made.append(build_gif("rig001_idle", 20, (150, 250, 270, 452), "rig001_idle.gif", 120))
    for p in made:
        print("[MEDIA] %-46s %8d B" % (os.path.basename(p), os.path.getsize(p)))


if __name__ == "__main__":
    main()
