"""ART-INTEGRATE-005E · Web 导出包（index.pck）体检。

用法：python tools/check_art005e_pck.py

判定两件事：
1. r09 的 17 张运行贴图**必须**在包内；
2. 留档母图 / GIF / 报告 / 预览 / 素材库 / 转存库**不得**进包。

注意：Godot 导出会把 .gd 源码文本（含注释）打进 PCK，所以不能拿
「任务编号字符串」当黑名单——上下文显示那只是脚本注释。这里一律按
**具体文件名 / 路径片段**判定，避免误报。

退出码：0 = PASS，1 = FAIL。
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PCK = ROOT / "builds" / "web" / "index.pck"

REQUIRED = ["ART_CHAR_001_r09_push_idle_right_128x176.png"] + [
    f"ART_CHAR_001_r09_push_walk_{i:02d}_128x176.png" for i in range(16)
]

FORBIDDEN = [
    "ART-ANIM-005E_r09_交付报告.md",
    "ART-INTEGRATE-005E_交接提示词.md",
    "ART_ANIM_005E_留档/",
    "ART_CHAR_001_r09_16frames_final_contact.png",
    "ART_CHAR_001_r09_before_after_contact.png",
    "ART_CHAR_001_r09_world_ground_8checkpoints.png",
    "ART_CHAR_001_r09_world_ground_80pxs_10fps.gif",
    "ART_CHAR_001_r09_ground_contact_enlarged.gif",
    "ART_CHAR_001_r09_push_walk_6fps.gif",
    "QA_FRAME_SHA256.txt",
    "03_source_only",
    "master_reference_only",
    "preview_4x",
    "素材库/",
    "转存库/",
]


def main() -> int:
    if not PCK.is_file():
        print(f"[PCK][FAIL] 缺少 {PCK}")
        return 1
    data = PCK.read_bytes()
    missing = [n for n in REQUIRED if n.encode("utf-8") not in data]
    leaked = [n for n in FORBIDDEN if n.encode("utf-8") in data]
    gif_count = data.count(b".gif")

    print(f"包体：{PCK.relative_to(ROOT)}  {len(data):,} B = {len(data) / 1048576:.2f} MiB")
    print(f"r09 运行贴图：{len(REQUIRED) - len(missing)}/{len(REQUIRED)} 在包内")
    if missing:
        print("  缺失：", missing)
    print(f"黑名单文件/路径命中：{leaked if leaked else '无（CLEAN）'}")
    print(f".gif 字节串出现次数：{gif_count}")
    ok = not missing and not leaked and gif_count == 0
    print("结果：", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
