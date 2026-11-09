"""ART-APPROVE-005E · r09 正式验收后的台账状态同步（幂等，可重复运行）。

用法：python tools/approve_art005e.py

只做一件事：把 素材台账.csv 里 ART_CHAR_001 / r09 这一行从
「待审核 / 引擎试用」升为「运行时可用 / 扶车十六帧可用」，并写入批准记录。
白名单与断言的同步在 tools/check_artlib_page.mjs（人工显式加一行），不在本脚本里，
以便「谁批准了什么」始终能在版本库里逐行审查。

不触碰任何游戏逻辑、物理参数、动画资源或素材图片。
"""
from __future__ import annotations

import csv
import io
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LEDGER = ROOT / "素材库" / "素材台账.csv"

OLD_STATUS = "待审核"
NEW_STATUS = "运行时可用"
NEW_MAKE_STATUS = "扶车十六帧可用"

OLD_NOTE = "**状态：待审核（引擎试用）。全部实机用例通过也不升「运行时可用」，等美术总监裁定。**"
NEW_NOTE = (
    "**状态：运行时可用（ART-APPROVE-005E，2026-11-09 美术总监裁定，用户转达）。** "
    "批准依据：实机 GIF / 100ms 正常播放 GIF / r04-r09 对照图审查通过；"
    "维持 16 帧 / 10 FPS 作为正式默认扶车动画；承重段平均 1.29px/动画帧滑移残差与"
    "侧视双手合并为一个连续握把接触区均接受，无需重绘 r09；r03/r04 完整保留回退；"
    "冻结的碰撞 / 速度 / 间距 / 锚点 / 图层参数一个未改。"
    "批准人：美术总监；任务编号 ART-APPROVE-005E；日期 2026-11-09。"
)


def main() -> int:
    raw = LEDGER.read_text(encoding="utf-8-sig")
    lines = raw.splitlines(keepends=True)
    columns = list(csv.DictReader(io.StringIO(lines[0] + lines[1])).fieldnames or [])

    hit = -1
    for i, line in enumerate(lines[1:], start=1):
        if line.startswith("ART_CHAR_001,r09,") or ("ART_CHAR_001" in line and ",r09," in line):
            hit = i
            break
    if hit < 0:
        print("[APPROVE][FAIL] 台账里找不到 ART_CHAR_001 / r09 行")
        return 1

    row = next(csv.DictReader(io.StringIO(lines[hit]), fieldnames=columns))
    if row["审核状态"] == NEW_STATUS and row["制作状态"] == NEW_MAKE_STATUS:
        print("[APPROVE] r09 已是「运行时可用」，跳过（幂等）")
        return 0
    if row["审核状态"] != OLD_STATUS:
        print(f"[APPROVE][FAIL] r09 当前状态异常：{row['审核状态']}")
        return 1

    row["审核状态"] = NEW_STATUS
    row["制作状态"] = NEW_MAKE_STATUS
    notes = row["制作与修改说明"]
    if OLD_NOTE not in notes:
        print("[APPROVE][FAIL] 找不到待审核声明，拒绝静默改写")
        return 1
    row["制作与修改说明"] = notes.replace(OLD_NOTE, NEW_NOTE)

    buf = io.StringIO(newline="")
    csv.DictWriter(buf, fieldnames=columns, lineterminator="\n").writerow(row)
    nl = "\r\n" if lines[hit].endswith("\r\n") else "\n"
    lines[hit] = buf.getvalue().rstrip("\n") + nl
    LEDGER.write_text("".join(lines), encoding="utf-8-sig")

    print("[APPROVE] ART_CHAR_001 / r09：待审核 → 运行时可用；引擎试用 → 扶车十六帧可用")
    print("[APPROVE] 已写入批准记录（美术总监 / ART-APPROVE-005E / 2026-11-09）")
    print("[APPROVE] 提醒：白名单需人工在 tools/check_artlib_page.mjs 显式加一行")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
