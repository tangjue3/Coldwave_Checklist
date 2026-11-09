"""ART-INTEGRATE-004 素材台账同步脚本（一次性，可重复执行）。

做三件事：
1. ART_ITEM_101 / ART_ITEM_102 的 r02 与 r02-shelf 四行 → 审核状态升「运行时可用」
   （总监最新裁定；ART-FIX-003C 已完成引擎验证，本轮只同步状态，不改任何图片）；
2. ART_FURN_103 新增 r03 四行（back / front / cargo_half / cargo_full），
   审核状态一律 **待审核**——本轮明确「不擅自把 r03 标记为运行时可用」；
3. 保留所有原有字段，其余列一字不动。

用法（在工程根目录）：
    python tools/sync_artlib_ledger_004.py
"""
from __future__ import annotations

import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LEDGER = ROOT / "素材库" / "素材台账.csv"
REGISTRY = ROOT / "素材库" / "ID登记表.csv"

HEADER = ["素材ID", "名称", "所属分类", "对应角色或场景", "当前版本", "来源", "用途",
          "制作状态", "审核状态", "版权或授权备注", "原始文件路径", "库内文件路径",
          "对应运行时资源路径", "制作与修改说明", "相关文件", "动画帧数", "帧率FPS",
          "尺寸", "方向", "预览文件", "精灵图文件"]

PKG = "用户提交的 ART-RUNTIME-004 交付包（Coldfront_ART_RUNTIME_004_v1.zip）"

# ---- 1) 商品 r02 四行：升「运行时可用」
PROMOTE = {
    ("ART_ITEM_101", "r02"),
    ("ART_ITEM_101", "r02-shelf"),
    ("ART_ITEM_102", "r02"),
    ("ART_ITEM_102", "r02-shelf"),
}
PROMOTE_NOTE = (
    "2026-11-09 ART-INTEGRATE-004：总监最新裁定，本件（连同同批 r02-shelf）"
    "批准为「运行时可用」。理由：ART-FIX-003C 已用引擎逐像素核对内容归属"
    "（101 = 蓝灰六瓶装饮用水，102 = 棕色红胶带食品纸箱），alpha 仅 0/255 两档、"
    "画布与锚点与合同一致，且本轮回归全部通过。"
    "**本轮只同步审核状态，未重新制作、未修改任何商品图**。"
)

# ---- 2) ART_FURN_103 r03 四行：新增，审核状态一律「待审核」
R03_COMMON_NOTE = (
    "2026-11-09 ART-INTEGRATE-004 收录：从 Coldfront_ART_RUNTIME_004_v1.zip 的 "
    "01_runtime_candidates/ 解出后复制归档，SHA256 与包内成员一致，原文件未移动未修改。"
    "画布统一 128×112、脚底锚点统一 (64,104)、Nearest、alpha 仅 0/255 两档，"
    "与 r02 同画布同锚点。**审核状态保持「待审核」**：本轮只做开发场景接入与实机验收，"
    "按任务要求不擅自升「运行时可用」，等总监复核本轮报告后另行裁定。"
    "旧 r02 仍是已批准的运行时版本并保留为回退路径（PushableCart.set_art_variant）。"
)
R03_ROWS = [
    {
        "name": "空购物车 · 分层后景（r03 back，侧视可推行）",
        "ver": "r03-back",
        "purpose": "ART-FURN-103 分层件之一：车把、后部框架、支撑与车轮。"
                   "与 front / cargo 同画布同锚点，三件按 Back→Cargo→Front 叠放",
        "make": "分层后景可用",
        "file": "ART_FURN_103_r03_back_128x112.png",
        "origin": "转存库/ART_RUNTIME_004_留档/ART_FURN_103_r02_full_sprite_reference_128x112.png",
        "size": "128×112（可见 82×90）",
        "extra": "可见范围实测 bbox(16,14,82,90)，可见底边 y=104 正好落在锚点上（误差 0px）。"
                 "**Back 与 Front 的不透明像素互不重叠**，两件按同一锚点重组后与 r02 原图"
                 "逐像素差异 AE=0（引擎内合成实测，差异像素 0）。",
    },
    {
        "name": "空购物车 · 分层近侧篮网（r03 front，侧视可推行）",
        "ver": "r03-front",
        "purpose": "ART-FURN_103 分层件之一：近侧购物篮网格与前景边缘。"
                   "**常驻显示**，永远压在人物之前，人物经过时正确遮挡腿部",
        "make": "分层前景可用",
        "file": "ART_FURN_103_r03_front_128x112.png",
        "origin": "转存库/ART_RUNTIME_004_留档/basket_front_region_mask.png",
        "size": "128×112（可见 71×45）",
        "extra": "可见范围实测 bbox(41,36,71,45)。本层由 r02 整图做像素级拆分而来，"
                 "不是重新画的近似篮体。r02 时代「同一张图做两层」的临时做法已由正式分件替换。",
    },
    {
        "name": "空购物车 · 分层半载物资（r03 cargo_half）",
        "ver": "r03-half",
        "purpose": "装载状态 HALF 的车内物资层（箱子、瓶装水、罐头、零食）。"
                   "**纯视觉层**，不涉及库存、容量、结算、载重与持久化",
        "make": "分层货物可用",
        "file": "ART_FURN_103_r03_cargo_half_128x112.png",
        "origin": "转存库/ART_RUNTIME_004_留档/half_load_master.png",
        "size": "128×112（可见 56×23）",
        "extra": "可见范围实测 bbox(49,51,56,23)，不透明像素 899。"
                 "与 front 区域相交（货物被网罩住），因此**必须画在 front 之前**，"
                 "否则会错误覆盖前景护栏。半载与满载是两个独立节点，代码层强制互斥显示。",
    },
    {
        "name": "空购物车 · 分层满载物资（r03 cargo_full）",
        "ver": "r03-full",
        "purpose": "装载状态 FULL 的车内物资层（毯子、箱子、饮水、罐头、粮食）。"
                   "**纯视觉层**，不涉及库存、容量、结算、载重与持久化",
        "make": "分层货物可用",
        "file": "ART_FURN_103_r03_cargo_full_128x112.png",
        "origin": "转存库/ART_RUNTIME_004_留档/full_load_master.png",
        "size": "128×112（可见 60×34）",
        "extra": "可见范围实测 bbox(47,40,60,34)，不透明像素 1698（比半载多 799，"
                 "两态在 960×540 正常视图下可区分）。同样必须画在 front 之前。",
    },
]
R03_RELATED = (
    "转存库/ART_RUNTIME_004_留档/README_接入与验收.md|"
    "转存库/Coldfront_ART_RUNTIME_004_v1.zip|"
    "转存库/ART_RUNTIME_004_留档/ART_FURN_103_r03_states_3x.png|"
    "转存库/ART_RUNTIME_004_留档/ART_FURN_103_r03_actor_occlusion_test_3x.png|"
    "美术设定集/03-物品与家具/ART_FURN_103_r02_tall_handle_128x112.png|ID对照表.md"
)


def read_rows() -> tuple[list[str], list[dict]]:
    with LEDGER.open(encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        return list(reader.fieldnames or []), list(reader)


def write_rows(fieldnames: list[str], rows: list[dict]) -> None:
    with LEDGER.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    fieldnames, rows = read_rows()
    if fieldnames != HEADER:
        print(f"[LEDGER-004] 表头与预期不一致，拒绝改写：{fieldnames}")
        return 1

    changed = 0

    # ---- 1) 商品 r02 四行升「运行时可用」
    for r in rows:
        key = (r["素材ID"], r["当前版本"])
        if key in PROMOTE and r["审核状态"] != "运行时可用":
            r["审核状态"] = "运行时可用"
            if r["制作状态"] in ("引擎验证通过", "待总监验收"):
                r["制作状态"] = "运行时可用"
            r["制作与修改说明"] = (r["制作与修改说明"].rstrip() + " " + PROMOTE_NOTE).strip()
            changed += 1
            print(f"[LEDGER-004] 升运行时可用：{key[0]} {key[1]}")

    # ---- 2) ART_FURN_103 r03 四行
    existing = {(r["素材ID"], r["当前版本"]) for r in rows}
    for spec in R03_ROWS:
        key = ("ART_FURN_103", spec["ver"])
        if key in existing:
            print(f"[LEDGER-004] 已存在，跳过：{key[0]} {key[1]}")
            continue
        row = {k: "" for k in HEADER}
        row.update({
            "素材ID": "ART_FURN_103",
            "名称": spec["name"],
            "所属分类": "物品与家具",
            "对应角色或场景": "超市 / 安全屋（可推行的道具）",
            "当前版本": spec["ver"],
            "来源": PKG,
            "用途": spec["purpose"],
            "制作状态": spec["make"],
            "审核状态": "待审核",
            "版权或授权备注": "原创 AI 生成运行时分件，用户提交；alpha 仅 0/255 两档、无半透明；"
                              "由 r02 整图做像素级拆分 + 母图手工整理，Nearest 精确落位，无运行时缩放；"
                              "母图与预览在转存库留档，不进 PCK",
            "原始文件路径": spec["origin"],
            "库内文件路径": "美术设定集/03-物品与家具/" + spec["file"],
            "对应运行时资源路径": "assets/facilities/" + spec["file"],
            "制作与修改说明": R03_COMMON_NOTE + spec["extra"],
            "相关文件": R03_RELATED,
            "动画帧数": "1",
            "尺寸": spec["size"],
            "方向": "右",
            "预览文件": "美术设定集/03-物品与家具/" + spec["file"],
        })
        rows.append(row)
        changed += 1
        print(f"[LEDGER-004] 新增行：ART_FURN_103 {spec['ver']}")

    write_rows(fieldnames, rows)
    print(f"[LEDGER-004] 台账共 {len(rows)} 行，本次改动 {changed} 处")

    # ---- 3) ID 登记表备注补一句（不新增号：r03 属于 ART_FURN_103 的新版本）
    with REGISTRY.open(encoding="utf-8-sig", newline="") as f:
        reg_fieldnames = list(csv.DictReader(f).fieldnames or [])
        reg_rows = list(csv.DictReader(REGISTRY.open(encoding="utf-8-sig", newline="")))
    for r in reg_rows:
        if r["素材ID"] == "ART_FURN_103":
            note = r["备注"]
            if "r03" not in note:
                r["备注"] = (note + "；2026-11-09 ART-INTEGRATE-004 新增 r03 分层四件"
                             "（back/front/cargo_half/cargo_full），仍属本号，不新建设施 ID；"
                             "r03 审核状态为待审核，r02 保留为已批准的运行时版本与回退路径").rstrip("；")
    with REGISTRY.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=reg_fieldnames)
        writer.writeheader()
        writer.writerows(reg_rows)
    print("[LEDGER-004] ID 登记表备注已同步（未新增编号）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
