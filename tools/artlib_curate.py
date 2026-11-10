"""TASK-ARTLIB-CLEAN-001 · 台账整理数据同步器（幂等）。

职责：把「人做的判断」写进 `素材库/素材台账.csv` 的 6 个新增列，不碰任何既有列。

新增列（追加在原有 21 列之后）：
  动作分组      角色动作门类，供预览页左侧二级导航；非角色填「不适用」
  视觉评价      认可 / 待优化 / 未评价 / 不适用 —— 美术质量判断，与「能否上机」无关
  使用状态      正式使用 / 回退保留 / 未使用 —— 以 scripts/ 与 scenarios 的实际引用为准
  归档标记      是 / 空 —— 仅作历史追溯，不再参与后续制作
  动画帧序列    帧文件的 glob（相对 素材库/），多帧条目的帧不单独登记 ID
  参考用途      AI 视频参考图归属动作，多个用 | 分隔

用法（工程根目录）：python tools/artlib_curate.py [--check]
  --check  只比对不写入，有差异时以 1 退出（CI / 验收用）
"""
from __future__ import annotations

import csv
import sys
from pathlib import Path

# VIDEO-FINALIZE-001：三段正式动画的「已知限制」正文以
# artlib_finalize_001.py 的 LIMITS 为唯一来源，避免两个工具各写一份简写而漂移。
from artlib_finalize_001 import LIMITS as FINAL_LIMITS

ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = ROOT / "素材库" / "素材台账.csv"

# VIDEO-FINALIZE-001 新增「已知限制」列：结构化记录未修复问题，
# 避免「视觉认可 / 正式使用」把遗留缺陷一并盖成「已解决」。
NEW_COLUMNS = ["动作分组", "视觉评价", "使用状态", "归档标记", "动画帧序列",
               "参考用途", "已知限制"]

# 键 = (素材ID, 当前版本)。未列出的行由 DEFAULTS 补齐；
# 三条正式动画行的「制作与修改说明」不在本脚本追加注记（由 finalize 维护）。
CURATION: dict[tuple[str, str], dict[str, str]] = {
    # ---------------------------------------------------------------- 主角外观设定（唯一基准）
    ("ART_CHAR_001", "v02"): dict(动作分组="外观设定", 视觉评价="不适用",
                                  使用状态="未使用", 参考用途="普通行走|推购物车|搬箱|搬水",
                                  说明="ART-RESET-001：第一季唯一外观基准。"
                                       "r01–r09 旧运行时动画已全部删除，本条同时作为 AI 视频参考图来源"),
    # ---------------------------------------------------------------- 主角运行时动作（正式登记）
    # VIDEO-FINALIZE-001：三段 512×704 高清动画已由用户确认画质并正式登记。
    # 整行完整字段（含 制作与修改说明 / 已知限制 的正文）由
    # tools/artlib_finalize_001.py 维护；这里只同步整理列，且**不写「说明」**，
    # 否则会把 CLEAN-001 注记追加进那三行的说明里、与 finalize 的数据源打架。
    ("ART_CHAR_001", "r10"): dict(动作分组="普通行走", 视觉评价="认可",
                                  使用状态="正式使用",
                                  动画帧序列="美术设定集/01-角色/动画帧/r10/*.png",
                                  已知限制=FINAL_LIMITS["r10"]),
    ("ART_CHAR_001", "r11"): dict(动作分组="其他动作", 视觉评价="认可",
                                  使用状态="正式使用",
                                  动画帧序列="美术设定集/01-角色/动画帧/r11/*.png",
                                  已知限制=FINAL_LIMITS["r11"]),
    ("ART_CHAR_001", "r12"): dict(动作分组="待机", 视觉评价="认可",
                                  使用状态="正式使用",
                                  动画帧序列="美术设定集/01-角色/动画帧/r12/*.png",
                                  已知限制=FINAL_LIMITS["r12"]),
    # ---------------------------------------------------------------- NPC / 风格参考
    ("ART_CHAR_002", "v01"): dict(动作分组="外观设定", 视觉评价="不适用",
                                  使用状态="未使用", 归档标记="是",
                                  说明="CLEAN-001：四人五视图已另立 104–107，本群像仅作早期配色追溯"),
    ("ART_CHAR_003", "v01"): dict(动作分组="外观设定", 视觉评价="不适用",
                                  使用状态="未使用", 归档标记="是",
                                  说明="CLEAN-001：外部画风参考，永不参与运行时与视频参考"),
    ("ART_CHAR_104", "v01"): dict(动作分组="外观设定", 视觉评价="不适用"),
    ("ART_CHAR_105", "v01"): dict(动作分组="外观设定", 视觉评价="不适用"),
    ("ART_CHAR_106", "v01"): dict(动作分组="外观设定", 视觉评价="不适用"),
    ("ART_CHAR_107", "v01"): dict(动作分组="外观设定", 视觉评价="不适用"),
    # ---------------------------------------------------------------- 场景
    ("ART_SCENE_001", "v01"): dict(动作分组="不适用", 归档标记="是",
                                   说明="CLEAN-001：拆分为 101/102 后的历史合集，仅作追溯"),
    ("ART_SCENE_101", "v01"): dict(动作分组="不适用"),
    ("ART_SCENE_102", "v01-base"): dict(动作分组="不适用"),
    ("ART_SCENE_102", "v01-upgraded"): dict(动作分组="不适用"),
    ("ART_SCENE_103", "v01"): dict(动作分组="不适用"),
    # ---------------------------------------------------------------- 物资（含 AI 视频参考图）
    ("ART_ITEM_001", "v01"): dict(动作分组="不适用", 归档标记="是",
                                  说明="CLEAN-001：早期十二物资合集，个体条目已另立，合集仅作追溯"),
    ("ART_ITEM_101", "v01"): dict(动作分组="不适用", 参考用途="搬水",
                                  说明="CLEAN-001：饮用水最大最清晰的一张，作为「搬水」视频参考图"),
    ("ART_ITEM_101", "r02"): dict(动作分组="不适用", 使用状态="正式使用",
                                  说明="CLEAN-001：当前游戏唯一在用的饮用水落地图"),
    ("ART_ITEM_101", "r02-shelf"): dict(动作分组="不适用", 使用状态="正式使用",
                                        说明="CLEAN-001：当前游戏唯一在用的饮用水货架图"),
    ("ART_ITEM_102", "v01"): dict(动作分组="不适用", 参考用途="搬箱",
                                  说明="CLEAN-001：食品纸箱最大最清晰的一张，作为「搬箱」视频参考图"),
    ("ART_ITEM_102", "r02"): dict(动作分组="不适用", 使用状态="正式使用",
                                  说明="CLEAN-001：当前游戏唯一在用的纸箱落地图"),
    ("ART_ITEM_102", "r02-shelf"): dict(动作分组="不适用", 使用状态="正式使用",
                                        说明="CLEAN-001：当前游戏唯一在用的纸箱货架图"),
    # ---------------------------------------------------------------- 家具与设施
    ("ART_FURN_101", "v01-empty"): dict(动作分组="不适用"),
    ("ART_FURN_101", "v01-stages"): dict(动作分组="不适用"),
    ("ART_FURN_101", "r01"): dict(动作分组="不适用", 使用状态="正式使用"),
    ("ART_FURN_102", "v01"): dict(动作分组="不适用"),
    ("ART_FURN_103", "r01"): dict(动作分组="不适用", 使用状态="回退保留",
                                  说明="CLEAN-001：旧购物车整图，r03 分件已转正，本条仅回退用"),
    ("ART_FURN_103", "r02"): dict(动作分组="不适用", 使用状态="回退保留", 参考用途="推购物车",
                                  说明="CLEAN-001：加高车把整图，作为「推购物车」视频参考里的车体参考（r03 为分件，不适合整体出图）"),
    ("ART_FURN_103", "r03-back"): dict(动作分组="不适用", 使用状态="正式使用"),
    ("ART_FURN_103", "r03-front"): dict(动作分组="不适用", 使用状态="正式使用"),
    ("ART_FURN_103", "r03-half"): dict(动作分组="不适用", 使用状态="正式使用"),
    ("ART_FURN_103", "r03-full"): dict(动作分组="不适用", 使用状态="正式使用"),
}

DEFAULTS = {"动作分组": "不适用", "视觉评价": "未评价", "使用状态": "未使用",
            "归档标记": "", "动画帧序列": "", "参考用途": "", "已知限制": ""}

NOTE_TAG = "2026-11-10 TASK-ARTLIB-CLEAN-001"


def main() -> int:
    check_only = "--check" in sys.argv
    with CSV_PATH.open(encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        base_fields = list(reader.fieldnames or [])
        rows = list(reader)

    fields = base_fields + [c for c in NEW_COLUMNS if c not in base_fields]

    missing_key = []
    for r in rows:
        key = ((r.get("素材ID") or "").strip(), (r.get("当前版本") or "").strip())
        cur = CURATION.get(key)
        vals = dict(DEFAULTS)
        if cur:
            vals.update({k: v for k, v in cur.items() if k in NEW_COLUMNS})
        else:
            missing_key.append(key)
        for c in NEW_COLUMNS:
            r[c] = vals[c]

        # 证据留痕：把整理判断追加进「制作与修改说明」（幂等）
        note = (cur or {}).get("说明", "")
        notes = r.get("制作与修改说明") or ""
        if note and NOTE_TAG not in notes:
            add = f"{NOTE_TAG}（整理）：{note.split('：', 1)[-1]}"
            r["制作与修改说明"] = (notes.rstrip() + " " + add).strip()

    if missing_key:
        print("[WARN] 以下台账行没有整理结论，已按默认值填充：")
        for k in missing_key:
            print("   ", k)

    # 判断是否有实际变化
    with CSV_PATH.open(encoding="utf-8-sig", newline="") as f:
        old_rows = list(csv.DictReader(f))
    changed = fields != base_fields or any(
        any((o.get(c) or "") != (r.get(c) or "") for c in fields) for o, r in zip(old_rows, rows))

    if check_only:
        print("[CHECK] 台账" + ("有差异" if changed else "已同步"))
        return 1 if changed else 0

    if not changed:
        print("[SKIP] 台账已是最新")
        return 0

    with CSV_PATH.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields, lineterminator="\r\n")
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k, "") for k in fields})

    print(f"[OK] 已写入 {len(rows)} 行 / {len(fields)} 列 → {CSV_PATH.relative_to(ROOT)}")
    for k, v in CURATION.items():
        if "说明" in v:
            print(f"  · {k[0]}@{k[1]}：{v['说明']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
