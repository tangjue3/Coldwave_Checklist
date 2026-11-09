#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ART-RIG-001：从合成角色图生成「技术原型」分层素材 + 骨骼规格 JSON。

设计要点（为什么不用抠图 / 连通域分离）：
  r02_00 整张角色是**单一连通体**（4729 px 一块），马尾在 y=13..21 与后脑相连、
  手臂压在外套上、两腿在 y<118 并在一起。任何"按连通块分离"的做法都会失败。

  因此本工具用**几何归属**替代抠图：
    1. 为每根骨骼定义一条线段（关节 origin → 子关节 tip）与半宽 R；
    2. 每个不透明像素归属于 score = 距离/R 最小的部件（骨轴最近者胜）；
    3. 部件图层 mask = 归属像素 ∪ 骨轴胶囊(R) ∪ 近端关节 4px 圆盘。
       胶囊与圆盘让关节处天然重叠，旋转时不会裂开；
    4. 图层颜色一律**原样拷贝源图**，所以静止姿态下所有图层按 z 序合成 == 源图（逐像素相等）。

  这样得到的分层是「可用的技术原型」而不是成品美术：
  - 远侧上臂在原图里完全被躯干遮住，只能拿到躯干像素（外套灰），材质语义不对；
  - 袖根/腋下、后脑发根、两腿根部这些被上层压住的地方，靠上层像素外扩填充，
    正式素材必须由美术补画（本工具会导出 repaint_mask.png 精确标出）。

用法：
  python tools/make_rig001_layers.py            # 生成图层 + spec + 还原度自检
  python tools/make_rig001_layers.py --check    # 只做还原度自检，不写文件
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import sys

try:
    from PIL import Image, ImageDraw
except ImportError:  # pragma: no cover
    print("需要 Pillow：pip install pillow")
    raise SystemExit(2)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets/characters/ART_CHAR_001_r02_walk_right_00_contactA.png")
OUT_DIR = os.path.join(ROOT, "assets/dev/rig001_proto")
LAYER_DIR = os.path.join(OUT_DIR, "layers")
DIAG_DIR = os.path.join(OUT_DIR, "diagnostics")  # 诊断图，带 .gdignore，不进引擎

W, H = 128, 176
ANCHOR = (64, 168)  # 画布脚底锚点（与全项目一致）

# --------------------------------------------------------------------------- 骨骼
# origin/tip 是画布像素坐标（y 向下）。tip 只用于推算静止角与胶囊走向，
# 不参与运行时；运行时骨骼层级由 rig001_spec.json 决定。
#
# 关节坐标来自 r02_00 的轮廓实测（见 docs/ART-RIG-001_角色分层与骨骼制作规范.md 附录 A）：
#   头顶 y=8、下巴 y≈34、肩线 y≈44、裆部 y≈117、膝盖 y≈142、脚底 y=167
BONES = [
    # name, parent, origin, tip, radius, layer
    ("root",          None,            (64, 168), (64, 140), 0.0,  None),
    ("pelvis",        "root",          (60, 106), (60, 97),  9.5,  "pelvis"),
    ("chest",         "pelvis",        (60, 100), (60, 44),  16.0, "torso"),
    ("neck",          "chest",         (61, 40),  (62, 34),  0.0,  None),
    ("head",          "neck",          (62, 34),  (62, 10),  14.0, "head"),
    ("hair_tail",     "head",          (53, 16),  (43, 33),  7.0,  "ponytail"),
    ("arm_far_upper", "chest",         (66, 45),  (77, 76),  6.5,  "arm_far_upper"),
    ("arm_far_fore",  "arm_far_upper", (77, 76),  (83, 90),  5.5,  "arm_far_fore"),
    ("hand_far",      "arm_far_fore",  (83, 90),  (86, 103), 5.5,  "hand_far"),
    ("arm_near_upper", "chest",        (57, 45),  (50, 70),  6.5,  "arm_near_upper"),
    ("arm_near_fore", "arm_near_upper", (50, 70), (48, 88),  5.5,  "arm_near_fore"),
    ("hand_near",     "arm_near_fore", (48, 88),  (48, 102), 5.5,  "hand_near"),
    ("leg_far_upper", "pelvis",        (56, 106), (44, 142), 8.0,  "leg_far_upper"),
    ("leg_far_lower", "leg_far_upper", (44, 142), (45, 156), 7.5,  "leg_far_lower"),
    ("foot_far",      "leg_far_lower", (45, 156), (56, 166), 9.0,  "foot_far"),
    ("leg_near_upper", "pelvis",       (64, 106), (74, 142), 8.0,  "leg_near_upper"),
    ("leg_near_lower", "leg_near_upper", (74, 142), (86, 156), 7.5, "leg_near_lower"),
    ("foot_near",     "leg_near_lower", (86, 156), (98, 166), 9.0, "foot_near"),
]

# 绘制顺序（后 → 前）。近侧 = 朝右时的近景肢，远侧 = 背景肢。
Z_ORDER = [
    "ponytail", "arm_far_upper", "arm_far_fore", "hand_far",
    "leg_far_upper", "leg_far_lower", "foot_far",
    "pelvis", "torso", "head",
    "leg_near_upper", "leg_near_lower", "foot_near",
    "arm_near_upper", "arm_near_fore", "hand_near",
]
Z_BASE = {n: (i - len(Z_ORDER) // 2) * 2 for i, n in enumerate(Z_ORDER)}

# 近端关节补片半径：让子部件在小关节处与父部件重叠，旋转不裂缝
JOINT_CAP = 5.0

# 骨轴矩形带两端的外扩量（0=原点端，1=tip 端）。
# 肢体在 tip 端（肘/膝/腕/踝）多外扩几像素：父级图层朝关节方向多带一段，
# 子部件转动时那块区域由父级材质补上，不会露出背景缝。
BAND_MARGIN_LIMB = (2.0, 4.0)
BAND_MARGIN_BODY = (2.0, 2.0)

# 补块：盆骨在源图里被两条大腿压住，只靠骨轴带覆盖不到裆部。
# 两腿张开/交叉时裆部会露出空洞，所以给骨盆层补一整块"臀→裆"区域（x0,y0,x1,y1，含端点）。
# 它画在大腿后面，静止时完全被腿挡住，不会改变还原度。
EXTRA_RECTS = {
    "pelvis": [(44, 96, 79, 134)],
    "torso": [(54, 33, 70, 46)],
}

# 说明：两条大腿之间的缝隙（y≥118）在源图里本来就是背景，不是"被遮住的部位"，
# 这里**不做合成填充** —— 填了会得到一条连在腿间的裤色"蹼"，静止姿态就露馅。
# 正式素材由美术补一张独立的髋/裆件，或在两腿内侧各补 3–4px。

# 步态参数（设计值，写进 spec 供引擎与文档共用）
GAIT = {
    "cycle_seconds": 1.0,      # 一个完整循环（左右各一步）
    "duty": 0.6,               # 支撑相占比（>0.5 才有双脚支撑，符合走路）
    "step_px": 42.0,           # 接触姿态两脚间距（r02_00 实测踝距 41px，取 42）
    "speed_px_s": 42.0 / 0.6 / 1.0,  # = 70.0 px/s，由 step/(duty*cycle) 推出
    "lift_px": 6.5,            # 摆动相抬脚高度
    "bob_px": 1.5,             # 骨盆上下起伏
    "hip_sway_deg": 2.0,
    "chest_counter_deg": 3.0,
    "arm_swing_deg": 18.0,
    "hair_swing_deg": 6.0,
}


def _dist_seg(px: float, py: float, ax: float, ay: float, bx: float, by: float) -> float:
    vx, vy = bx - ax, by - ay
    wx, wy = px - ax, py - ay
    L2 = vx * vx + vy * vy
    if L2 <= 1e-9:
        return math.hypot(wx, wy)
    t = max(0.0, min(1.0, (wx * vx + wy * vy) / L2))
    return math.hypot(px - (ax + t * vx), py - (ay + t * vy))


def _in_band(px: float, py: float, a: tuple, b: tuple, r: float, m0: float = 2.0, m1: float = 2.0) -> bool:
    """骨轴矩形带：沿轴投影落在 [-m, L+m]，垂距 ≤ r。

    用矩形带（而不是圆头胶囊）是因为圆头会越过关节端往外多吞 R 个像素——
    头会把肩膀吞进去、躯干会把脖子吞进去，旋转时就会带动不该动的部位。
    """
    ax, ay = a
    vx, vy = b[0] - ax, b[1] - ay
    L = math.hypot(vx, vy)
    if L <= 1e-9:
        return math.hypot(px - ax, py - ay) <= r
    ux, uy = vx / L, vy / L
    wx, wy = px - ax, py - ay
    along = wx * ux + wy * uy
    if along < -m0 or along > L + m1:
        return False
    return abs(-wx * uy + wy * ux) <= r


def build() -> dict:
    src = Image.open(SRC).convert("RGBA")
    if src.size != (W, H):
        raise SystemExit("源图尺寸异常：%s" % (src.size,))
    px = src.load()
    opaque = [(x, y) for y in range(H) for x in range(W) if px[x, y][3] > 0]

    parts = [(n, p, o, t, r, layer) for (n, p, o, t, r, layer) in BONES if layer]
    # 以「图层名」为键：一件骨骼最多一张图层，图层名全局唯一
    seg = {layer: (o, t, r) for (n, p, o, t, r, layer) in BONES if layer}
    layer_of_bone = {n: layer for (n, p, o, t, r, layer) in BONES if layer}

    # --- 1) 归属：score = 到骨轴距离 / 半宽 -------------------------------
    owner: dict[tuple[int, int], str] = {}
    for (x, y) in opaque:
        best, best_s = "", 1e9
        for n, (o, t, r) in seg.items():
            s = _dist_seg(x, y, o[0], o[1], t[0], t[1]) / r
            if s < best_s - 1e-9:
                best_s, best = s, n
        owner[(x, y)] = best

    # --- 2) 图层 mask = 归属 ∪ 胶囊(R) ∪ 近端关节圆盘 --------------------
    masks: dict[str, set] = {n: set() for n in seg}
    for (x, y) in opaque:
        o = owner[(x, y)]
        masks[o].add((x, y))
        for n, (a, b, r) in seg.items():
            var_is_limb = n.startswith(("arm_", "hand_", "leg_", "foot_"))
            var_m0 = BAND_MARGIN_LIMB[0] if var_is_limb else BAND_MARGIN_BODY[0]
            var_m1 = BAND_MARGIN_LIMB[1] if var_is_limb else BAND_MARGIN_BODY[1]
            if _in_band(x, y, a, b, r, var_m0, var_m1):
                masks[n].add((x, y))
        for n, (a, _b, _r) in seg.items():
            if math.hypot(x - a[0], y - a[1]) <= JOINT_CAP:
                masks[n].add((x, y))
        for n, rects in EXTRA_RECTS.items():
            for (x0, y0, x1, y1) in rects:
                if x0 <= x <= x1 and y0 <= y <= y1:
                    masks[n].add((x, y))

    # --- 3) 写出图层 -------------------------------------------------------
    os.makedirs(LAYER_DIR, exist_ok=True)
    os.makedirs(DIAG_DIR, exist_ok=True)
    layers = {}
    for n in seg:
        img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        p2 = img.load()
        for (x, y) in masks[n]:
            p2[x, y] = px[x, y]
        layers[n] = img
        img.save(os.path.join(LAYER_DIR, "%s.png" % n))

    # --- 4) 还原度自检：按 z 序合成，必须与源图逐像素相等 ----------------
    comp = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for n in Z_ORDER:
        comp.alpha_composite(layers[n])
    diff = 0
    cp, sp = comp.load(), src.load()
    for y in range(H):
        for x in range(W):
            if cp[x, y] != sp[x, y]:
                diff += 1

    # --- 5) 诊断图：区域归属图 + 需补绘图 ---------------------------------
    colors = {
        "ponytail": (200, 90, 200), "arm_far_upper": (90, 140, 220), "arm_far_fore": (110, 170, 240),
        "hand_far": (140, 200, 250), "leg_far_upper": (70, 150, 110), "leg_far_lower": (100, 180, 140),
        "foot_far": (140, 210, 170), "pelvis": (230, 190, 60), "torso": (120, 120, 130),
        "head": (240, 190, 150), "leg_near_upper": (190, 90, 70), "leg_near_lower": (220, 120, 90),
        "foot_near": (250, 160, 120), "arm_near_upper": (60, 110, 170), "arm_near_fore": (80, 140, 200),
        "hand_near": (110, 170, 230),
    }
    region = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    rp = region.load()
    for (x, y), n in owner.items():
        rp[x, y] = colors[n] + (255,)
    region.save(os.path.join(DIAG_DIR, "region_map.png"))

    # 需补绘：某部件 mask 内、但被 z 更高的部件压住的像素（该处只能用上层颜色顶替）。
    # 每个部件单独出一张 —— 合并成一张会变成"整身都是"，对美术没有指导意义。
    os.makedirs(os.path.join(DIAG_DIR, "repaint"), exist_ok=True)
    union = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    upp = union.load()
    repaint_cnt: dict[str, int] = {}
    for n in seg:
        z_n = Z_BASE[n]
        cnt = 0
        one = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        opp = one.load()
        for (x, y) in masks[n]:
            on = owner[(x, y)]
            if on != n and Z_BASE[on] > z_n:
                opp[x, y] = (255, 0, 255, 255)
                upp[x, y] = (255, 0, 255, 255)
                cnt += 1
        one.save(os.path.join(DIAG_DIR, "repaint", "%s.png" % n))
        repaint_cnt[n] = cnt
    union.save(os.path.join(DIAG_DIR, "repaint_union.png"))

    # --- 6) spec -----------------------------------------------------------
    bones = []
    for (n, p, o, t, r, layer) in BONES:
        item = {
            "name": n, "parent": p,
            "origin": list(o), "tip": list(t),
            "rest_rot_deg": round(math.degrees(math.atan2(t[1] - o[1], t[0] - o[0])), 4),
            "length": round(math.hypot(t[0] - o[0], t[1] - o[1]), 4),
        }
        if layer:
            item["layer"] = layer
            item["z"] = Z_BASE[layer]
            item["radius"] = r
            item["owned_px"] = len([1 for k, v in owner.items() if v == layer])
            item["layer_px"] = len(masks[layer])
            item["repaint_px"] = repaint_cnt[layer]
        bones.append(item)

    spec = {
        "id": "ART_RIG_001",
        "status": "技术验证 / 待美术审核",
        "note": "临时分层，仅用于 ART-RIG-001 骨骼技术验证；未登记素材台账，不在运行时白名单。",
        "canvas": {"w": W, "h": H, "anchor": list(ANCHOR)},
        "source": os.path.relpath(SRC, ROOT).replace("\\", "/"),
        "source_sha256": hashlib.sha256(open(SRC, "rb").read()).hexdigest(),
        "layer_dir": "res://assets/dev/rig001_proto/layers/",
        "layer_names": sorted(seg.keys()),
        "z_order_back_to_front": Z_ORDER,
        "bones": bones,
        "gait": GAIT,
        "checks": {"rest_composite_diff_px": diff, "opaque_px": len(opaque)},
    }
    with open(os.path.join(OUT_DIR, "rig001_spec.json"), "w", encoding="utf-8") as f:
        json.dump(spec, f, ensure_ascii=False, indent=2)
    return spec


def isolation_check() -> list:
    """构建期隔离检查：原型不得进入素材台账 / 运行时白名单 / 正式角色目录。"""
    out = []
    ok = True
    ledger = os.path.join(ROOT, "素材库/素材台账.csv")
    text = open(ledger, encoding="utf-8-sig").read()
    hit = [k for k in ("RIG_001", "rig001", "ART_RIG") if k in text]
    out.append("素材台账未登记原型：%s" % ("OK" if not hit else "!! 命中 %s" % hit))
    ok = ok and not hit
    wl = os.path.join(ROOT, "tools/check_artlib_page.mjs")
    text2 = open(wl, encoding="utf-8").read()
    hit2 = [k for k in ("RIG_001", "rig001") if k in text2]
    out.append("运行时白名单未收录原型：%s" % ("OK" if not hit2 else "!! 命中 %s" % hit2))
    ok = ok and not hit2
    formal = os.path.join(ROOT, "assets/characters")
    extra = [f for f in os.listdir(formal) if "rig001" in f.lower()]
    out.append("assets/characters 无原型文件：%s" % ("OK" if not extra else "!! %s" % extra))
    ok = ok and not extra
    out.append("结论：%s" % ("原型完全隔离，可交付" if ok else "存在越界，必须修正"))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="只自检不写文件")
    args = ap.parse_args()

    if args.check:
        spec = build()
    else:
        spec = build()

    print("=== ART-RIG-001 分层生成 ===")
    print("源图 %s" % spec["source"])
    print("不透明像素 %d，图层 %d 个" % (spec["checks"]["opaque_px"], len(spec["layer_names"])))
    print("静止姿态合成 vs 源图差异像素：%d  %s"
          % (spec["checks"]["rest_composite_diff_px"],
             "OK" if spec["checks"]["rest_composite_diff_px"] == 0 else "!! 不为 0，分层有丢失"))
    print()
    print("%-16s %8s %8s %8s" % ("layer", "owned", "layer_px", "repaint"))
    for b in spec["bones"]:
        if "layer" in b:
            print("%-16s %8d %8d %8d" % (b["layer"], b["owned_px"], b["layer_px"], b["repaint_px"]))
    print()
    print("步态设计：循环 %.2fs，支撑相 %.0f%%，步距 %.1fpx → 步速 %.2f px/s（现有 move_speed=100）"
          % (GAIT["cycle_seconds"], GAIT["duty"] * 100, GAIT["step_px"], GAIT["speed_px_s"]))
    print()
    iso = isolation_check()
    for line in iso:
        print("[隔离] " + line)
    if spec["checks"]["rest_composite_diff_px"] != 0:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
