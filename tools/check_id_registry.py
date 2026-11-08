"""素材 ID 登记表校验器（SCALE-001）。

用法（在工程根目录）：
    python tools/check_id_registry.py

做三件事：
1. 校验 `素材库/ID登记表.csv`（唯一登记源）与 `素材库/素材台账.csv`（实际条目）是否一致；
2. 校验磁盘上的文件名没有占用「预留 / 空置」号；
3. 用登记表重新生成可读的 `素材库/ID登记表.md`（含统计与下一可用号）。

设计要点：
- 登记表是**唯一来源**，台账和文件名都必须服从它；冲突时先改登记表再改文件；
- 只有 `已用` 的号可以在台账与文件名里出现，`预留 / 空置` 一律不得占用；
- 生成 md 而不是手写 md，避免两份文档各说各话。

退出码：0 全部通过；1 存在冲突。
"""
from __future__ import annotations

import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "素材库"
REG_CSV = LIB / "ID登记表.csv"
REG_MD = LIB / "ID登记表.md"
LEDGER = LIB / "素材台账.csv"
ART_DIR = LIB / "美术设定集"
INBOX = ROOT / "转存库"

ID_RE = re.compile(r"^ART_(CHAR|SCENE|ITEM|FURN|UI|FX)_(\d{3})$")
NAME_RE = re.compile(r"(ART_(?:CHAR|SCENE|ITEM|FURN|UI|FX)_\d{3})")
## 版本号两套序列：vNN = 设定/概念版本，rNN = 运行时候选/运行时版本；都可带状态后缀
VER_RE = re.compile(r"^[vr]\d{2}(-[a-z]+)?$")

PREFIX_CATEGORY = {
    "ART_CHAR": ("角色", "美术设定集/01-角色"),
    "ART_SCENE": ("场景", "美术设定集/02-场景"),
    "ART_ITEM": ("物品与家具", "美术设定集/03-物品与家具"),
    "ART_FURN": ("物品与家具", "美术设定集/03-物品与家具"),
    "ART_UI": ("界面", "美术设定集/04-界面"),
    "ART_FX": ("特效与动画", "美术设定集/05-特效与动画"),
}
PREFIX_ORDER = ["ART_CHAR", "ART_SCENE", "ART_ITEM", "ART_FURN", "ART_UI", "ART_FX"]

# 号段规则（写进生成的 md，也是本脚本的判据说明）
SEGMENT_RULE = [
    ("001–099", "首批归档与合集条目，不再扩号；合集不拆、不删、不覆盖"),
    ("101–199", "后续个体条目与规划预留；新条目从「下一可用号」起，不得回填空置位"),
]

failures: list[str] = []
warnings: list[str] = []


def fail(msg: str) -> None:
    failures.append(msg)


def warn(msg: str) -> None:
    warnings.append(msg)


def read_csv(path: Path) -> list[dict]:
    with path.open(encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def main() -> int:
    if not REG_CSV.exists():
        print(f"[ID][FAIL] 缺少登记表 {REG_CSV}")
        return 1

    reg = read_csv(REG_CSV)
    ledger = read_csv(LEDGER)

    # ---------------------------------------------------------- 1. 登记表自身
    reg_by_id: dict[str, dict] = {}
    for r in reg:
        sid = (r.get("素材ID") or "").strip()
        m = ID_RE.match(sid)
        if not m:
            fail(f"登记表 ID 格式不合规：{sid!r}（应为 ART_<类别>_<三位序号>）")
            continue
        if sid in reg_by_id:
            fail(f"登记表 ID 重复：{sid}")
            continue
        if "ART_" + m.group(1) != (r.get("前缀") or "").strip():
            fail(f"登记表前缀与 ID 不符：{sid} 标了 {r.get('前缀')}")
        status = (r.get("状态") or "").strip()
        if status not in ("已用", "预留", "空置"):
            fail(f"登记表状态非法：{sid} = {status!r}（只允许 已用 / 预留 / 空置）")
        reg_by_id[sid] = r

    # ---------------------------------------------------------- 2. 台账自检
    ledger_ids: dict[str, list[dict]] = {}
    seen_key: set[tuple[str, str]] = set()
    for r in ledger:
        sid = (r.get("素材ID") or "").strip()
        ver = (r.get("当前版本") or "").strip()
        key = (sid, ver)
        if key in seen_key:
            fail(f"台账唯一键重复：（{sid}, {ver}）—— 同一素材同一版本只能一行")
        seen_key.add(key)
        ledger_ids.setdefault(sid, []).append(r)

        if not VER_RE.match(ver):
            fail(f"台账版本号不合规：{sid} 的 {ver!r}（应为 v01 或 v01-base 形式）")

        if sid not in reg_by_id:
            fail(f"台账里有未登记的 ID：{sid}（先登记，再入库）")
            continue
        status = (reg_by_id[sid].get("状态") or "").strip()
        if status != "已用":
            fail(f"台账占用了「{status}」号：{sid} —— 预留/空置号不得有实际条目")

        # 类别 / 目录 / 文件名
        cat, folder = PREFIX_CATEGORY[sid.rsplit("_", 1)[0]]
        if (r.get("所属分类") or "").strip() != cat:
            fail(f"分类与 ID 前缀不符：{sid} 标了 {r.get('所属分类')}，应为 {cat}")
        rel = (r.get("库内文件路径") or "").strip()
        if rel:
            if not rel.startswith(folder + "/"):
                fail(f"库内路径不在约定目录：{sid} → {rel}（应为 {folder}/…）")
            base = Path(rel).name
            # 状态后缀（v01-base 等）不写进文件名，文件名只用基础版本号
            if not base.startswith(f"{sid}_{ver.split('-')[0]}"):
                fail(f"文件名与台账不符：{base} 应以 {sid}_{ver.split('-')[0]} 开头")
            if not (LIB / rel).is_file():
                fail(f"库内文件不存在：{rel}")

    # ---------------------------------------------------------- 3. 反向：已用但台账没有
    for sid, r in reg_by_id.items():
        if (r.get("状态") or "").strip() != "已用":
            continue
        if sid not in ledger_ids:
            # 备注里写明「无独立文件」的合集号（内容并入了别的 ID）不重复告警
            if "无独立文件" not in (r.get("备注") or ""):
                warn(f"登记表标「已用」但台账无条目：{sid}（{r.get('名称或用途')}）")

    # ---------------------------------------------------------- 4. 文件名不得占用预留号
    if ART_DIR.is_dir():
        for f in sorted(ART_DIR.rglob("*")):
            if not f.is_file():
                continue
            for sid in NAME_RE.findall(f.name):
                if sid not in reg_by_id:
                    fail(f"文件名含未登记 ID：{f.relative_to(ROOT)} → {sid}")
                elif (reg_by_id[sid].get("状态") or "").strip() != "已用":
                    fail(f"文件名占用了「{reg_by_id[sid].get('状态')}」号："
                         f"{f.relative_to(ROOT)} → {sid}")

    # ---------------------------------------------------------- 5. 转存库只提示
    if INBOX.is_dir():
        inbox_ids = set()
        for f in INBOX.rglob("*"):
            if f.is_file():
                inbox_ids.update(NAME_RE.findall(f.name))
        for sid in sorted(inbox_ids - set(reg_by_id)):
            warn(f"转存库出现未登记 ID（原始件，可暂不处理）：{sid}")

    # ---------------------------------------------------------- 6. 生成 md
    write_md(reg_by_id, ledger_ids)

    # ---------------------------------------------------------- 7. 汇总
    print("")
    print("========== 素材 ID 登记校验 ==========")
    for w in warnings:
        print("[ID][WARN] ", w)
    for f in failures:
        print("[ID][FAIL] ", f)
    used = sum(1 for r in reg_by_id.values() if (r.get("状态") or "").strip() == "已用")
    hold = sum(1 for r in reg_by_id.values() if (r.get("状态") or "").strip() == "预留")
    idle = sum(1 for r in reg_by_id.values() if (r.get("状态") or "").strip() == "空置")
    print(f"登记 {len(reg_by_id)} 个号：已用 {used} / 预留 {hold} / 空置 {idle}；"
          f"台账 {len(ledger)} 行（{len(ledger_ids)} 个 ID）")
    print(f"登记表已写出：{REG_MD.relative_to(ROOT)}")
    if failures:
        print(f"结果：失败 {len(failures)} 项，警告 {len(warnings)} 项")
        return 1
    print(f"结果：全部通过（警告 {len(warnings)} 项）")
    return 0


def next_number(reg_by_id: dict[str, dict], prefix: str) -> str:
    nums = [int(sid.rsplit("_", 1)[1]) for sid in reg_by_id if sid.startswith(prefix + "_")]
    if not nums:
        return "001"
    return f"{max(nums) + 1:03d}"


def write_md(reg_by_id: dict[str, dict], ledger_ids: dict[str, list[dict]]) -> None:
    out: list[str] = []
    out.append("# 素材 ID 登记表（正式登记）")
    out.append("")
    out.append("> 本文件由 `python tools/check_id_registry.py` 从 `素材库/ID登记表.csv` 生成，**不要手改**。")
    out.append("> CSV 是唯一来源；台账 `素材库/素材台账.csv` 与磁盘文件名都必须服从它。")
    out.append("> 命名与旧 ID 映射的历史理由见 `素材库/ID对照表.md`。")
    out.append("")
    out.append("## 1. 号段规则")
    out.append("")
    out.append("| 号段 | 规则 |")
    out.append("|---|---|")
    for seg, rule in SEGMENT_RULE:
        out.append(f"| `{seg}` | {rule} |")
    out.append("")
    out.append("文件与条目的命名：`ART_<类别>_<三位序号>_v<两位版本>_<中文短名>.<扩展名>`；")
    out.append("")
    out.append("- 版本序列：`v01` 起为**设定 / 概念版本**；`r01` 起为**运行时候选 / 运行时版本**（美术交付包使用 `r`）。")
    out.append("- 两者都可带状态后缀，例如 `v01-base`、`v01-upgraded`、`v01-empty`、`v01-stages`。")
    out.append("- 状态后缀不写进文件名，文件名只用基础版本号（`..._v01_...png`）。")
    out.append("")
    out.append("## 2. 号段总览")
    out.append("")
    out.append("| 前缀 | 类别 | 目标目录 | 已用 | 预留 | 空置 | 下一可用号 |")
    out.append("|---|---|---|---|---|---|---|")
    for p in PREFIX_ORDER:
        cat, folder = PREFIX_CATEGORY[p]
        ids = [s for s in reg_by_id if s.startswith(p + "_")]
        u = sum(1 for s in ids if reg_by_id[s]["状态"].strip() == "已用")
        h = sum(1 for s in ids if reg_by_id[s]["状态"].strip() == "预留")
        i = sum(1 for s in ids if reg_by_id[s]["状态"].strip() == "空置")
        out.append(f"| `{p}_` | {cat} | `{folder}/` | {u} | {h} | {i} | `{p}_{next_number(reg_by_id, p)}` |")
    out.append("")
    out.append("## 3. 已用（有实际条目的号）")
    out.append("")
    out.append("| 素材ID | 当前版本 | 名称 | 条目数 | 依据 |")
    out.append("|---|---|---|---|---|")
    for p in PREFIX_ORDER:
        for sid in sorted(s for s in reg_by_id if s.startswith(p + "_")):
            r = reg_by_id[sid]
            if r["状态"].strip() != "已用":
                continue
            rows = ledger_ids.get(sid, [])
            vers = " / ".join(x["当前版本"] for x in rows) if rows else "—"
            out.append(f"| `{sid}` | {vers} | {r['名称或用途']} | {len(rows)} | {r['依据']} |")
    out.append("")
    out.append("## 4. 预留（规划中，尚未制作）")
    out.append("")
    out.append("| 素材ID | 名称或用途 | 依据 | 备注 |")
    out.append("|---|---|---|---|")
    for p in PREFIX_ORDER:
        for sid in sorted(s for s in reg_by_id if s.startswith(p + "_")):
            r = reg_by_id[sid]
            if r["状态"].strip() != "预留":
                continue
            out.append(f"| `{sid}` | {r['名称或用途']} | {r['依据']} | {r['备注']} |")
    out.append("")
    out.append("## 5. 空置（保留不分配）")
    out.append("")
    out.append("| 素材ID | 说明 | 备注 |")
    out.append("|---|---|---|")
    idle_rows = [(s, reg_by_id[s]) for s in sorted(reg_by_id) if reg_by_id[s]["状态"].strip() == "空置"]
    if not idle_rows:
        out.append("| — | 无 | — |")
    for sid, r in idle_rows:
        out.append(f"| `{sid}` | {r['名称或用途']} | {r['备注']} |")
    out.append("")
    out.append("## 6. 入库前必须走的四步")
    out.append("")
    out.append("1. **查号**：在本表里搜素材内容，确认它是不是已有条目；已有就补版本，不再新开号。")
    out.append("2. **定号**：确实要新开条目时，用对应前缀的「下一可用号」，从高位顺延；")
    out.append("   **不得**回填空置位，**不得**占用预留位。")
    out.append("3. **登记**：先在 `素材库/ID登记表.csv` 增加一行（状态写 `已用`），再动文件与台账。")
    out.append("4. **校验**：运行 `python tools/check_id_registry.py`，必须全绿再提交。")
    out.append("")
    out.append("> 交付包（ART-DESIGN-00x）若自带编号，先按上述四步比对：")
    out.append("> 与预留号冲突时，以「不推翻既有裁定」为前提二选一——让位方顺延，或交付包改号，")
    out.append("> 两者都要在 `素材库/ID对照表.md` 的修订记录里写清理由。")
    out.append("")

    REG_MD.write_text("\n".join(out) + "\n", encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
