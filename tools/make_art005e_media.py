"""ART-INTEGRATE-005E · 把真实 Godot 渲染帧组装成 GIF 与对照图。

用法（工程根目录，先跑完 art005e 的 tour / gif / compare 命令）：
    python tools/make_art005e_media.py

产物全部落在 tests/screenshots/：
    art005e_push_walk.gif          40 帧原生 960×540 实机连拍，20ms/帧（≈实机 50FPS）
    art005e_push_walk_slow.gif     同帧 100ms/帧，便于逐帧检查步态接缝
    art005e_r04_vs_r09.png         r09 / r04 同帧上下对照
    art005e_ground_checkpoints.png 固定地面 8 个检查点缩略拼图

所有输入都必须是 Godot 真实渲染的截图，脚本只做拼装，不绘制/补帧/合成人物。
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SHOT = ROOT / "tests" / "screenshots"


def load(name: str) -> Image.Image:
    return Image.open(SHOT / name).convert("RGB")


def build_gifs(frames: list[Image.Image]) -> None:
    real = SHOT / "art005e_push_walk.gif"
    frames[0].save(real, save_all=True, append_images=frames[1:],
                   duration=20, loop=0, optimize=False)
    print(f"[GIF] {real.name}  {len(frames)} 帧  {frames[0].size[0]}×{frames[0].size[1]}  20ms/帧  {real.stat().st_size:,} B")
    slow = SHOT / "art005e_push_walk_slow.gif"
    frames[0].save(slow, save_all=True, append_images=frames[1:],
                   duration=100, loop=0, optimize=False)
    print(f"[GIF] {slow.name}  {len(frames)} 帧  100ms/帧（5× 慢放，便于逐帧检查）")


def label(img: Image.Image, text: str) -> Image.Image:
    # 场景自带的中文 caption 在左上角，标签放右上角，避免互相遮挡
    out = img.copy()
    d = ImageDraw.Draw(out)
    d.rectangle((580, 4, 950, 28), fill=(24, 26, 29))
    d.text((590, 10), text, fill=(238, 240, 242))
    return out


def build_compare() -> None:
    a = label(load("art005e_compare_r09.png"), "r09 / 16 frames / 10 FPS / pending review")
    b = label(load("art005e_compare_r04.png"), "r04 / 4 frames / 6 FPS / fallback")
    out = Image.new("RGB", (960, 1080))
    out.paste(a, (0, 0))
    out.paste(b, (0, 540))
    p = SHOT / "art005e_r04_vs_r09.png"
    out.save(p)
    print(f"[CMP] {p.name}  960×1080  r09 上 / r04 下")


def build_ground_sheet() -> None:
    idx = [0, 5, 10, 15, 20, 25, 30, 35]
    files = [SHOT / f"art005e_ground_{i:02d}.png" for i in idx]
    if not all(f.is_file() for f in files):
        print("[GROUND] 检查点截图不全（需 --art005e-test 的截图版本），跳过拼图")
        return
    tile = (480, 270)
    out = Image.new("RGB", (960, 1080))
    for k, f in enumerate(files):
        im = Image.open(f).convert("RGB").resize(tile, Image.NEAREST)
        d = ImageDraw.Draw(im)
        d.rectangle((330, 0, 480, 20), fill=(24, 26, 29))
        d.text((336, 4), f"sample {idx[k]:02d}/40", fill=(238, 240, 242))
        out.paste(im, ((k % 2) * 480, (k // 2) * 270))
    p = SHOT / "art005e_ground_checkpoints.png"
    out.save(p)
    print(f"[GROUND] {p.name}  8 个固定地面检查点")


def main() -> int:
    files = sorted(SHOT.glob("art005e_gif_*.png"))
    if not files:
        print("[GIF] 缺少 art005e_gif_*.png，先运行：--dev-scene=art005e --art005e-gif --quit")
        return 1
    frames = [Image.open(f).convert("RGB") for f in files]
    sizes = {f.size for f in frames}
    if sizes != {(960, 540)}:
        raise RuntimeError(f"截图不是原生 960×540：{sizes}")
    build_gifs(frames)
    if (SHOT / "art005e_compare_r09.png").is_file() and (SHOT / "art005e_compare_r04.png").is_file():
        build_compare()
    build_ground_sheet()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
