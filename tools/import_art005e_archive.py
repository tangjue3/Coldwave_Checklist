"""ART-INTEGRATE-005E · r09 修复成品归档与登记（可重复运行）。

用法（工程根目录）：
    python tools/import_art005e_archive.py            # 解包留档 + 复制 + 台账 / 登记表
    python tools/import_art005e_archive.py --fix-imports   # 修正 Godot 自动生成的 .import 参数

做五件事：
1. 从 转存库/ART-ANIM-005E_r09_修复成品.zip 解出普通文件到 转存库/ART_ANIM_005E_留档/
   （zip 被 .gitignore 忽略，留档的普通文件用于克隆后追溯与 SHA-256 核对）；
2. 把 17 张 runtime PNG 复制到 assets/characters/ 与 素材库/美术设定集/01-角色/；
3. 在 素材台账.csv 追加 ART_CHAR_001 / r09 一行，状态固定「待审核 / 引擎试用」；
4. 在 ID登记表.csv 的 ART_CHAR_001 备注里追加本轮版本记录（不新开号）；
5. 生成留档 README.md 与 QA_FRAME_SHA256.txt。

本脚本**不改**运行时白名单，**不删**任何既有版本，**不碰**任何游戏逻辑代码。
--fix-imports 只把新贴图的导入参数改回像素画专用值（Godot 默认会污染 alpha 边缘）。
"""
from __future__ import annotations

import csv
import hashlib
import io
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ZIP = ROOT / "转存库" / "ART-ANIM-005E_r09_修复成品.zip"
ARCHIVE = ROOT / "转存库" / "ART_ANIM_005E_留档"
ASSETS = ROOT / "assets" / "characters"
LIBDIR = ROOT / "素材库" / "美术设定集" / "01-角色"
LEDGER = ROOT / "素材库" / "素材台账.csv"
REG = ROOT / "素材库" / "ID登记表.csv"
PREFIX = "ART_CHAR_001_r09_"
TASK = "ART-INTEGRATE-005E"

IMPORT_FIXES = {
    "compress/mode": "0",
    "mipmaps/generate": "false",
    "process/fix_alpha_border": "false",
    "process/premult_alpha": "false",
    "detect_3d/compress_to": "0",
}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def unpack() -> list[Path]:
    ARCHIVE.mkdir(parents=True, exist_ok=True)
    out: list[Path] = []
    with zipfile.ZipFile(ZIP) as z:
        for info in z.infolist():
            if info.is_dir():
                continue
            name = info.filename
            if not (info.flag_bits & 0x800):
                try:
                    name = name.encode("cp437").decode("gbk")
                except UnicodeError:
                    pass
            parts = Path(name).parts
            if parts and parts[0].startswith("ART-ANIM-005E_r09_release"):
                parts = parts[1:]
            if not parts:
                continue
            dest = ARCHIVE.joinpath(*parts)
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(z.read(info))
            out.append(dest)
    return out


def copy_runtime() -> list[Path]:
    frames = sorted((ARCHIVE / "runtime").glob(PREFIX + "*.png"))
    if len(frames) != 17:
        raise RuntimeError(f"runtime 帧数应为 17，实际 {len(frames)}")
    ASSETS.mkdir(parents=True, exist_ok=True)
    LIBDIR.mkdir(parents=True, exist_ok=True)
    for src in frames:
        for dst_dir in (ASSETS, LIBDIR):
            dst = dst_dir / src.name
            if not dst.exists() or dst.read_bytes() != src.read_bytes():
                dst.write_bytes(src.read_bytes())
    return frames


def write_qa(frames: list[Path]) -> None:
    lines = [
        f"# {TASK} · r09 运行时帧 SHA-256",
        "",
        f"来源：{ZIP.name}",
        f"包 SHA-256：{sha256(ZIP.read_bytes())}",
        f"帧数：{len(frames)}（扶车静止 1 + 推车行走 16）",
        "",
        "| 文件 | SHA-256 |",
        "|---|---|",
    ]
    for f in frames:
        lines.append(f"| `{f.name}` | `{sha256(f.read_bytes())}` |")
    (ARCHIVE / "QA_FRAME_SHA256.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")

    readme = f"""# {TASK} · r09 修复成品留档

- 来源包：`转存库/{ZIP.name}`（SHA-256 `{sha256(ZIP.read_bytes())}`）
- 解包日期：2026-11-09，由 `python tools/import_art005e_archive.py` 生成，**只复制不移动不删除**。
- 状态：**待审核 / 引擎试用**。工程侧已接入验证，但未经总监裁定，不进入「运行时可用」白名单。
- 本目录在 `转存库/` 下，受根目录 `.gdignore` 隔离，**不参与 Godot 导入、不进 PCK**。
- `previews/` 里的 GIF / 对照图仅供人眼复核，禁止当作运行时贴图或写进 `assets/`。

## 目录

```
runtime/    ART_CHAR_001_r09_push_idle_right_128x176.png
            ART_CHAR_001_r09_push_walk_00..15_128x176.png
previews/   固定地面 10FPS GIF、16 帧板、修复前后对照、8 检查点、接地放大
ART-ANIM-005E_r09_交付报告.md     美术侧自检结论
ART-INTEGRATE-005E_交接提示词.md  工程 Agent 任务书（用户确认美术后生效）
QA_FRAME_SHA256.txt               17 张成品逐文件哈希
```

## 冻结边界

960×540 / 角色画布 128×176 / 锚点 (64,168) / 碰撞 28×160 / 车 128×112 锚点 (64,104) /
车长 96 / `side_offset=80` / 推 80 / 拉 40 / `Back→Cargo→Player→Front` 分层 —— 一个都不改。
只交付朝右推车前进；朝左独立帧、反向拉车动作、车轮滚动不在本批。
"""
    (ARCHIVE / "README.md").write_text(readme, encoding="utf-8")


def append_ledger() -> None:
    with LEDGER.open(encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))
        columns = list(rows[0].keys())
    for r in rows:
        if r["素材ID"] == "ART_CHAR_001" and r["当前版本"] == "r09":
            print("[LEDGER] r09 台账行已存在，跳过")
            return

    related = [
        f"转存库/ART_ANIM_005E_留档/README.md",
        f"转存库/ART_ANIM_005E_留档/ART-ANIM-005E_r09_交付报告.md",
        f"转存库/ART_ANIM_005E_留档/ART-INTEGRATE-005E_交接提示词.md",
        f"转存库/ART_ANIM_005E_留档/QA_FRAME_SHA256.txt",
        f"转存库/ART_ANIM_005E_留档/previews/ART_CHAR_001_r09_16frames_final_contact.png",
        f"转存库/ART_ANIM_005E_留档/previews/ART_CHAR_001_r09_before_after_contact.png",
        f"转存库/ART_ANIM_005E_留档/previews/ART_CHAR_001_r09_world_ground_80pxs_10fps.gif",
    ]
    for i in range(16):
        related.append(
            f"转存库/ART_ANIM_005E_留档/runtime/{PREFIX}push_walk_{i:02d}_128x176.png")
    notes = (
        f"2026-11-09 {TASK} 收录：从修复成品包解出 17 张 128×176 透明帧，"
        "SHA-256 见留档 QA 表；库内副本、assets 副本与包内成员逐字节一致。"
        "美术侧以 r03 为原稿，y=0..60 与工程 r03 逐像素一致；两个拳头压上车把端帽；"
        "16 张独立腿部姿态按 80px/s ÷ 10FPS = 8px/帧 绑定步距。"
        "工程侧接入 SpriteFrames 的 r09_push_idle / r09_push_walk_right（16 帧、10 FPS、loop），"
        "r03/r04 动画与资源全部保留可回退；冻结物理参数一个未改。"
        "**状态：待审核（引擎试用）。全部实机用例通过也不升「运行时可用」，等美术总监裁定。**"
        "朝左仍是水平镜像，反向拉车动作与车轮滚动未交付。"
    )
    row = {
        "素材ID": "ART_CHAR_001",
        "名称": "许知夏 · 扶车动作返工（r09：扶车静止 1 帧 + 推车行走 16 帧）",
        "所属分类": "角色",
        "对应角色或场景": "许知夏（主角，推购物车时）",
        "当前版本": "r09",
        "来源": "用户提交的 ART-ANIM-005E 修复成品包（ART-ANIM-005E_r09_修复成品.zip）",
        "用途": "修复 r08 双手与车把脱节、步态与 80px/s 位移不匹配；替换 r04 四帧过渡画面，"
                "接入 r09_push_idle / r09_push_walk_right（10 FPS、16 帧循环）",
        "制作状态": "引擎试用",
        "审核状态": "待审核",
        "版权或授权备注": "原创 AI 生成运行时帧，用户提交；128×176 RGBA、alpha 仅 0/255 两档；"
                     "母图 / GIF / 报告 / 预览只在转存库留档，不进 PCK；仅朝右，朝左为临时镜像",
        "原始文件路径": f"转存库/ART_ANIM_005E_留档/runtime/{PREFIX}push_idle_right_128x176.png",
        "库内文件路径": f"美术设定集/01-角色/{PREFIX}push_idle_right_128x176.png",
        "对应运行时资源路径": "assets/characters/player_sprite_frames.tres",
        "制作与修改说明": notes,
        "相关文件": "|".join(related),
        "动画帧数": "16（另 1 张扶车静止帧）",
        "帧率FPS": "10",
        "尺寸": "128×176（顶 y=8，脚底 y=167，可见高 160）",
        "方向": "右（朝左为水平镜像）",
        "预览文件": f"转存库/ART_ANIM_005E_留档/previews/{PREFIX}16frames_final_contact.png",
        "精灵图文件": "assets/characters/player_sprite_frames.tres",
    }
    buf = io.StringIO(newline="")
    csv.DictWriter(buf, fieldnames=columns, lineterminator="\n").writerow(row)
    raw = LEDGER.read_bytes()
    sep = b"" if raw.endswith(b"\n") else b"\n"
    LEDGER.write_bytes(raw + sep + buf.getvalue().encode("utf-8"))
    print(f"[LEDGER] 追加 r09 一行（共 {len(rows) + 1} 行）")


def update_registry() -> None:
    raw = REG.read_text(encoding="utf-8-sig")
    marker = f"{TASK} 新增 r09"
    if marker in raw:
        print("[REG] 备注已含 r09，跳过")
        return
    lines = raw.splitlines(keepends=True)
    hit = False
    for i, line in enumerate(lines):
        if line.startswith("ART_CHAR_001,"):
            nl = "\r\n" if line.endswith("\r\n") else ("\n" if line.endswith("\n") else "")
            body = line.rstrip("\r\n")
            lines[i] = body + f"；2026-11-09 {marker}（扶车静止 1 帧 + 推车行走 16 帧，待审核，不新开号）" + nl
            hit = True
            break
    if not hit:
        raise RuntimeError("ID登记表.csv 里找不到 ART_CHAR_001 行")
    REG.write_text("".join(lines), encoding="utf-8-sig")
    print("[REG] ART_CHAR_001 备注追加 r09 版本记录（未新开编号）")


def fix_imports() -> None:
    changed = 0
    for p in sorted(ASSETS.glob(PREFIX + "*.png.import")):
        text = p.read_text(encoding="utf-8")
        out = []
        for line in text.splitlines(keepends=True):
            stripped = line.strip()
            if "=" in stripped and stripped.split("=", 1)[0] in IMPORT_FIXES:
                key = stripped.split("=", 1)[0]
                nl = "\r\n" if line.endswith("\r\n") else ("\n" if line.endswith("\n") else "")
                line = f"{key}={IMPORT_FIXES[key]}" + nl
            out.append(line)
        new = "".join(out)
        if new != text:
            p.write_text(new, encoding="utf-8")
            changed += 1
    print(f"[IMPORT] 修正 {changed} 个 .import（共 {len(list(ASSETS.glob(PREFIX + '*.png.import')))} 个）")


def main() -> int:
    if "--fix-imports" in sys.argv:
        fix_imports()
        return 0
    files = unpack()
    frames = copy_runtime()
    write_qa(frames)
    append_ledger()
    update_registry()
    print(f"[ARCHIVE] 留档 {len(files)} 个文件 → {ARCHIVE.relative_to(ROOT)}")
    print(f"[RUNTIME] 17 张帧已复制到 {ASSETS.relative_to(ROOT)} 与 {LIBDIR.relative_to(ROOT)}")
    print(f"[ZIP] SHA-256 {sha256(ZIP.read_bytes())}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
