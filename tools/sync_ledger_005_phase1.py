# -*- coding: utf-8 -*-
"""ART-INTEGRATE-005 阶段1：按美术总监最终裁定，把 ART_FURN_103 r03 四件分件
从「待审核」升为「运行时可用」，并在制作与修改说明里追加裁定记录。
只改状态字段与说明，不动其它任何列。"""
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = ROOT / "素材库" / "素材台账.csv"

R03_ROWS = ["r03-back", "r03-front", "r03-half", "r03-full"]
NOTE = (
    "2026-11-09 ART-INTEGRATE-005 阶段1：美术总监最终裁定，本件批准为「运行时可用」"
    "（连同 back/front/half/full 四件一起），PushableCart 默认版本由 r02 切换为 r03；"
    "r02 完整保留为回退版本（set_art_variant 可随时切回）。"
)


def main() -> int:
    with CSV_PATH.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        rows = list(reader)

    changed = 0
    for r in rows:
        if r["素材ID"] == "ART_FURN_103" and r["当前版本"] in R03_ROWS:
            assert r["审核状态"] == "待审核", f"意外状态 {r['当前版本']}: {r['审核状态']}"
            r["审核状态"] = "运行时可用"
            desc = r["制作与修改说明"].rstrip()
            if "ART-INTEGRATE-005 阶段1" not in desc:
                r["制作与修改说明"] = (desc + "。" if desc and not desc.endswith("。") else desc) + NOTE
            changed += 1

    assert changed == 4, f"应改 4 行，实际 {changed}"

    with CSV_PATH.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"[LEDGER] 已更新 {changed} 行 r03 分件 → 运行时可用")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
