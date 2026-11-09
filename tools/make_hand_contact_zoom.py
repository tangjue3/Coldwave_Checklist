"""ART-INTEGRATE-004 手部接触放大图生成器（纯辅助脚本，不参与游戏运行）。

用途：把 Godot 实机截图里的「手 / 车把」接触区裁出来，放大到 4×，
并用**同一张图上量到的像素**标出水平与垂直误差，方便美术总监肉眼复核。

原则：
  * 只处理**真实 Godot 运行产出的截图**（tests/screenshots/art004_*.png），
    不生成任何合成示意图；
  * 放大一律 Nearest，不做任何插值，避免"看起来更顺"的假象；
  * 误差数值来自 Godot 实测（同一套 _band_x 算法），这里只负责画标注。

用法（在工程根目录）：
    python tools/make_hand_contact_zoom.py
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SHOTS = ROOT / "tests" / "screenshots"
OUT = SHOTS / "art004_hand_contact_4x.png"
# 工程内随包分发的中文字体：PIL 默认字体没有中文字形，直接画会变成方块
FONT_PATH = ROOT / "assets" / "ui" / "fonts" / "NotoSansSC-Variable.ttf"

# 由 Godot 实机量测得到（见 ART-INTEGRATE-004 交付报告 §6）：
#   side=+1（玩家在车右、车镜像）：手与车把水平间隙 +1.0 px，垂直差 -1.0 px
#   side=-1（玩家在车左）：手与车把水平间隙 +2.0 px，垂直差 -1.0 px
CASES = [
    {"src": "art004_push.png", "label": "朝右推车 side=-1", "gap": "+2.0 px", "dy": "-1.0 px"},
    {"src": "art004_mirror.png", "label": "朝左镜像 side=+1", "gap": "+1.0 px", "dy": "-1.0 px"},
]

# 接触区裁剪框（960×540 原图坐标，4× 放大后画标注用）
CROP = (360, 300, 560, 400)
SCALE = 4


def _font(size: int) -> ImageFont.FreeTypeFont:
    """用工程自带的中文字体；找不到就退回 PIL 默认字体（中文会变方块，但不会崩）。"""
    if FONT_PATH.is_file():
        return ImageFont.truetype(str(FONT_PATH), size)
    return ImageFont.load_default()


def main() -> int:
    if not OUT.parent.is_dir():
        print(f"[HAND-ZOOM] 缺少截图目录 {OUT.parent}")
        return 1

    zoomed = []
    for case in CASES:
        src = SHOTS / case["src"]
        if not src.is_file():
            print(f"[HAND-ZOOM] 缺少实机截图 {src.name}，跳过")
            continue
        im = Image.open(src).convert("RGB")
        crop = im.crop(CROP).resize(
            ((CROP[2] - CROP[0]) * SCALE, (CROP[3] - CROP[1]) * SCALE), Image.NEAREST)
        zoomed.append((case, crop))

    if not zoomed:
        print("[HAND-ZOOM] 没有可用的实机截图")
        return 1

    w, h = zoomed[0][1].size
    pad = 16
    label_h = 46
    canvas = Image.new("RGB", (w, (h + label_h) * len(zoomed) + pad), (24, 22, 20))
    draw = ImageDraw.Draw(canvas)
    f_main = _font(15)
    f_sub = _font(13)

    y = pad
    for case, crop in zoomed:
        canvas.paste(crop, (0, y))
        draw.rectangle([0, y, w - 1, y + h - 1], outline=(90, 86, 80), width=1)
        text = (f"{case['label']}   水平间隙 {case['gap']}   垂直差 {case['dy']}"
                f"   |  4x Nearest 放大，仅供看接触，非运行分辨率")
        draw.text((10, y + h + 10), text, fill=(226, 222, 214), font=f_main)
        draw.text((10, y + h + 28),
                  f"来源：tests/screenshots/{case['src']}（Godot 4.7.2 实机运行原生 960x540 截图）",
                  fill=(150, 145, 138), font=f_sub)
        y += h + label_h

    canvas.save(OUT)
    print(f"[HAND-ZOOM] 已生成 {OUT.relative_to(ROOT)}（{canvas.size[0]}x{canvas.size[1]}）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
