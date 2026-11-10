"""视频管线的自检（不依赖任何真实视频，也不生成正式素材）。

生成一段**合成的**测试片（纯色底 + 一个会走的小方块人），跑完 probe → extract → matte
→ analyze → align → build，逐项断言产物，然后删掉临时批次目录。
用途：确认 ffmpeg / 抽帧 / 抠像 / 对齐 / 预览这条链路在本机真的能跑通，
而不是只有一份看起来很专业的文档。

    python tools/video/selftest.py

会主动使用 `assets/dev/video_candidates/_selftest/` 并在结束时删除；
如果该目录里已有别的东西，脚本会拒绝运行。
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT / "tools" / "video"))

import pipeline  # noqa: E402

BATCH = "_selftest"
SRC_W, SRC_H = 384, 256
BG = (36, 40, 46)
N = 12


def make_clip(tmp: Path) -> Path:
    for i in range(N):
        im = Image.new("RGB", (SRC_W, SRC_H), BG)
        d = ImageDraw.Draw(im)
        # 身体随帧左右摆动的「小人」：躯干 + 头 + 两条腿
        cx = 120 + i * 12
        d.rectangle([cx, 90, cx + 30, 170], fill=(92, 106, 128))
        d.ellipse([cx + 6, 60, cx + 26, 84], fill=(206, 178, 150))
        d.line([cx + 8, 170, cx - 4 + (i % 4) * 6, 205], fill=(70, 80, 96), width=6)
        d.line([cx + 22, 170, cx + 34 - (i % 4) * 6, 205], fill=(70, 80, 96), width=6)
        im.save(tmp / f"f_{i:04d}.png")
    mp4 = tmp / "synthetic_walk.mp4"
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-framerate", "10",
                    "-i", str(tmp / "f_%04d.png"),
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-r", "10", str(mp4)],
                   check=True)
    return mp4


def main() -> int:
    d = ROOT / "assets" / "dev" / "video_candidates" / BATCH
    if d.exists():
        raise SystemExit(f"[FAIL] {d} 已存在，先手动处理掉再跑自检")
    fails = 0

    def ok(cond: bool, msg: str) -> None:
        nonlocal fails
        print(f"  [{'PASS' if cond else 'FAIL'}] {msg}")
        if not cond:
            fails += 1

    with tempfile.TemporaryDirectory() as t:
        tmp = Path(t)
        print("[1/3] 合成测试片（384×256 / 12 帧 / 10 FPS）")
        mp4 = make_clip(tmp)
        ok(mp4.is_file() and mp4.stat().st_size > 0, "测试片已生成")

        print("[2/3] 跑管线 all")
        code = pipeline.main(["all", str(mp4), "--batch", BATCH, "--fps", "10",
                              "--speed", "100", "--action", "walk"])
        ok(code == 0, f"pipeline all 退出码 = {code}")

        print("[3/3] 校验产物")
        raw = d / "frames_raw"
        matte = d / "frames_matte"
        out = d / "frames_out"
        ok(len(list(raw.glob("*.png"))) == N, f"frames_raw = {len(list(raw.glob('*.png')))} 张")
        ok(len(list(matte.glob("*.png"))) == N, f"frames_matte = {len(list(matte.glob('*.png')))} 张")
        ok(len(list(out.glob("*.png"))) == N, f"frames_out = {len(list(out.glob('*.png')))} 张")
        ok((d / "preview" / "loop.gif").is_file(), "preview/loop.gif 已生成")
        ok((d / "preview" / "contact_sheet.png").is_file(), "preview/contact_sheet.png 已生成")
        meta = json.loads((d / "meta.json").read_text(encoding="utf-8"))
        ok(meta.get("fps") == 10 and meta.get("frames_final") == N, f"meta.json：fps={meta.get('fps')} 帧={meta.get('frames_final')}")

        sizes = {Image.open(p).size for p in out.glob("*.png")}
        ok(sizes == {(pipeline.FRAME_W, pipeline.FRAME_H)}, f"成品帧画布 = {sizes}")

        # 脚底必须落在 anchor.y：最下方不透明像素行
        bad = []
        for p in sorted(out.glob("*.png")):
            a = pipeline.rgba(p)
            b = pipeline.bbox_of(a)
            if not b or abs(b[3] - pipeline.ANCHOR[1]) > pipeline.FOOT_TOLERANCE:
                bad.append((p.name, b[3] if b else None))
        ok(not bad, f"全部帧脚底对齐 y={pipeline.ANCHOR[1]}（越界 {len(bad)} 帧）")

        # 抠像有效性：四角必须透明
        a = pipeline.rgba(sorted(matte.glob("*.png"))[0])
        corners = [a[0, 0, 3], a[0, -1, 3], a[-1, 0, 3], a[-1, -1, 3]]
        ok(all(c == 0 for c in corners), f"背景已抠净，四角 alpha = {corners}")

    print("[清理] 删除临时批次", d.relative_to(ROOT))
    shutil.rmtree(d, ignore_errors=True)
    ok(not d.exists(), "临时批次已删除")

    print(f"\n自检结果：{'通过' if fails == 0 else f'{fails} 项失败'}")
    print("注意：这只证明管线能跑通，不证明任何真实视频的质量。")
    return 0 if fails == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
