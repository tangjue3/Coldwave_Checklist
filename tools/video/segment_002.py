"""VIDEO-INTEGRATE-002：把用户推车视频里的**人物**与**视频购物车**分开。

视频是 1280×720 横版，人物在左、车在右、朝右推。两者通过「手握端盖」
连成一个连通域，且整组在画面里缓慢右移（躯干中心 386→495），所以：

1. 逐帧检测手部接触点 x_cut（亮桃色手 → 深灰圆形端盖 的边界）；
2. 在 x_cut 处切断连接，再用连通域取「包含躯干」的那块 = 纯人物；
3. 对人物做色度键抠像（去除绿幕）+ despill + 边缘清理；
4. 输出纯人物 RGBA 帧，不含任何视频购物车像素。

游戏里的购物车继续用 `ART_FURN_103 r03` 四件分层，两段资产只在
Godot 场景里组合，不在像素层面混合。

    python tools/video/segment_002.py            # 全量 + 报告
    python tools/video/segment_002.py --probe    # 只输出检测结果
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))

from chroma import bleed_rgb, chroma_key  # noqa: E402

RAW = ROOT / ".work" / "video2_in" / "frames_raw"
MATTE_DIR = ROOT / ".work" / "video2_in" / "frames_person_matte"
PROBE = ROOT / "转存库" / "VIDEO-INTEGRATE-002"

# 视频手部带（源像素）。端盖圆心约在 y=278。
HAND_Y0, HAND_Y1 = 262, 298
# 检测窗口：相对躯干中心
SEARCH_LO, SEARCH_HI = 55, 235


def foreground(rgb: np.ndarray) -> np.ndarray:
    r = rgb[:, :, 0].astype(np.int16)
    g = rgb[:, :, 1].astype(np.int16)
    b = rgb[:, :, 2].astype(np.int16)
    return ~((g > r + 45) & (g > b + 45) & (g > 90))


def torso_center(fg: np.ndarray) -> float:
    """y=180..240 这段只有躯干（无手臂、无车），取前景中点作人物水平基准。"""
    xs = np.nonzero(fg[180:240, :].any(axis=0))[0]
    return float(xs.mean()) if len(xs) else 400.0


def detect_cut(rgb: np.ndarray, fg: np.ndarray, torso: float) -> int:
    """找「亮桃色手」到「深灰端盖」的边界。

    端盖是车把左端的圆形握把，明显比手暗。从躯干右侧开始扫，
    取第一个连续 >=6px 的暗带（亮度 < 118）作为端盖左缘。
    """
    band = rgb[HAND_Y0:HAND_Y1, :, :].astype(np.float32)
    lum = band.mean(axis=(0, 2))                       # 列平均亮度
    solid = fg[HAND_Y0:HAND_Y1, :].mean(axis=0)        # 列前景占比

    lo = int(torso) + SEARCH_LO
    hi = min(int(torso) + SEARCH_HI, rgb.shape[1] - 1)
    # 只在前一段确实出现过「亮手」之后才允许判端盖，避免把深色袖子误判
    seen_hand = False
    for x in range(lo, hi):
        if solid[x] > 0.35 and lum[x] > 128:
            seen_hand = True
        if not seen_hand:
            continue
        if x + 6 >= rgb.shape[1]:
            break
        win_dark = (lum[x:x + 6] < 122).sum()
        win_solid = (solid[x:x + 6] > 0.35).sum()
        if win_dark >= 5 and win_solid >= 5:
            return x
    # 兜底：取前景带最右侧之前 45px（正常帧不会走到这里）
    return int(torso) + 120


def person_mask(rgb: np.ndarray, fg: np.ndarray, cut: int) -> np.ndarray:
    """取纯人物：手部带用**颜色**分离，其余用几何切线 + 连通域。

    视频里手握住车把的圆形端盖，两者紧贴，单靠垂直切线会把弯曲的手指
    削成平口。实测端盖/横杆 R−B≈20–30（灰褐），桃色手 R−B≈60（暖色），
    因此在 y∈[HAND_Y0,HAND_Y1] 内保留暖色皮肤像素 + 与手臂连通的人物像素，
    剔除低饱和车体像素；手右侧（>cut+hand_allow）再统一切掉。
    """
    r = rgb[:, :, 0].astype(np.int16)
    g = rgb[:, :, 1].astype(np.int16)
    b = rgb[:, :, 2].astype(np.int16)
    rb = r - b
    vmax = rgb.max(axis=2).astype(np.int16)
    # 暖色皮肤：R 明显高于 B，且够亮（实测 205/171/143 → R−B=62）
    skin = (rb > 42) & (vmax > 145)
    # 车体灰褐：R−B 小。端盖暗部/描边也在这里
    cartish = (rb <= 42) & (vmax > 40)

    xx = np.arange(rgb.shape[1])[None, :]
    # 基线：车体（端盖/横杆/竖杆/车篮/车轮）全部在 cut 右侧，x<cut 只有人物
    keep = fg & (xx < cut)
    # 接触区（手部带内、端盖附近）：**只保留暖色皮肤**，外加 1px 膨胀补回
    # 紧贴皮肤的深色描边。端盖的暗色 C 形弧、灰褐横杆都不满足 skin，
    # 且不与皮肤相邻，因此被彻底剔除。
    # 不能把颜色分离横扫整个手部带 —— 胸腰深色衣服会被误判成车体，
    # 把上下半身切断（f73 曾因此只剩上半身）。
    contact = np.zeros_like(fg)
    contact[HAND_Y0:HAND_Y1, :] = True
    contact &= (xx >= cut - 2) & (xx < cut + 26)
    skin_core = skin & contact & fg
    skin_dil = cv2.dilate(skin_core.astype(np.uint8),
                          np.ones((3, 3), np.uint8)) > 0
    keep &= ~contact
    keep |= skin_core | (skin_dil & contact & fg)
    # 车体竖杆/车篮/车轮全在 cut 右侧，已被砍掉；再取包含躯干的最大连通域
    m = cv2.morphologyEx(keep.astype(np.uint8) * 255, cv2.MORPH_CLOSE,
                         np.ones((3, 3), np.uint8))
    n, lab, stats, _ = cv2.connectedComponentsWithStats(m, 8)
    if n <= 1:
        return keep
    seed_y, seed_x = 210, int(torso_center(fg))
    label = int(lab[min(seed_y, lab.shape[0] - 1), min(seed_x, lab.shape[1] - 1)])
    if label == 0:
        label = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    out = lab == label
    # 补回人物内部的小孔洞（衣服纹理、发丝），不包含任何车体像素
    out |= (keep & (cv2.morphologyEx(out.astype(np.uint8), cv2.MORPH_CLOSE,
                                    np.ones((5, 5), np.uint8)) > 0))
    return out


def build_person_frame(rgb: np.ndarray, fg: np.ndarray, cut: int) -> np.ndarray:
    """返回纯人物 RGBA（源分辨率），带色度键软边。"""
    pm = person_mask(rgb, fg, cut)
    keyed = chroma_key(rgb)                     # 全图色度键，含 despill 与软 alpha
    alpha = keyed[:, :, 3].astype(np.float32)
    # 人物遮罩（略羽化 1px，避免硬边）
    soft = cv2.GaussianBlur(pm.astype(np.float32), (0, 0), 0.6)
    alpha = alpha * np.clip(soft, 0.0, 1.0)
    out = keyed.copy()
    out[:, :, 3] = np.clip(alpha, 0, 255).astype(np.uint8)
    # 透明区颜色外扩，供后续 LINEAR 缩小
    out[:, :, :3] = bleed_rgb(out, iterations=8)
    return out


def run(probe_only: bool = False) -> dict:
    files = sorted(RAW.glob("f_*.png"))
    assert files, f"没有原始帧：{RAW}"
    cuts, torsos = [], []
    for p in files:
        rgb = np.array(Image.open(p).convert("RGB"))
        fg = foreground(rgb)
        t = torso_center(fg)
        c = detect_cut(rgb, fg, t)
        torsos.append(t)
        cuts.append(c)

    # 平移轨迹：中位数滤波去掉步态摆动，只留缓慢漂移（用于后续统一对齐）
    cut_arr = np.array(cuts, dtype=float)
    # numpy 滑窗中值：cv2.medianBlur 只接受 8U，这里保留浮点以便后续平滑对齐
    pad = 4
    padded = np.pad(cut_arr, pad, mode="edge")
    med = np.array([np.median(padded[i:i + 9]) for i in range(len(cut_arr))])
    info = {
        "frames": len(files),
        "cut_range": [int(min(cuts)), int(max(cuts))],
        "torso_range": [round(float(min(torsos)), 1), round(float(max(torsos)), 1)],
        "cut_drift": int(max(cuts) - min(cuts)),
        "cuts": cuts,
        "cuts_smoothed": [round(float(v), 1) for v in med],
        "torsos": [round(float(v), 1) for v in torsos],
    }
    print(f"[SEG] {len(files)} 帧；接触点 x {min(cuts)}–{max(cuts)}（漂移 {max(cuts)-min(cuts)}px），"
          f"躯干 {min(torsos):.1f}–{max(torsos):.1f}")
    print("      每 8 帧 cut:", [cuts[i] for i in range(0, len(cuts), 8)])

    if probe_only:
        (ROOT / ".work" / "video2_in" / "segment.json").write_text(
            json.dumps(info, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        return info

    MATTE_DIR.mkdir(parents=True, exist_ok=True)
    PROBE.mkdir(parents=True, exist_ok=True)
    stats = []
    for i, p in enumerate(files):
        rgb = np.array(Image.open(p).convert("RGB"))
        fg = foreground(rgb)
        out = build_person_frame(rgb, fg, cuts[i])
        Image.fromarray(out, "RGBA").save(MATTE_DIR / p.name)
        al = out[:, :, 3]
        ys, xs = np.nonzero(al > 8)
        # 车体残留：只统计「手部带以外」的 cut 右侧像素。
        # 手部带内 cut+6..cut+26 是刻意保留的手指（暖色皮肤），不算车体。
        right = (al[:, cuts[i] + 6:] > 8).copy()
        right[HAND_Y0:HAND_Y1, :] = False
        stats.append({
            "f": i + 1, "cut": cuts[i],
            "bbox": [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())] if len(xs) else [],
            "px": int((al > 8).sum()),
            "cart_residue": int(right.sum()),
        })
    residue = sum(s["cart_residue"] for s in stats)
    widths = [s["bbox"][2] - s["bbox"][0] + 1 for s in stats if s["bbox"]]
    heights = [s["bbox"][3] - s["bbox"][1] + 1 for s in stats if s["bbox"]]
    print(f"[SEG] 纯人物帧 {len(files)} 张；车体残留 {residue}px；"
          f"人物 bbox 宽 {min(widths)}–{max(widths)} 高 {min(heights)}–{max(heights)}")
    info["matte_stats"] = stats
    info["cart_residue_total"] = residue
    (ROOT / ".work" / "video2_in" / "segment.json").write_text(
        json.dumps(info, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    # 可视化：原帧 / 纯人物抠像（棋盘格）/ 切线位置，取 5 帧
    sel = [1, 19, 43, 73, 91]
    panels = []
    for n in sel:
        src = Image.open(RAW / f"f_{n:04d}.png").convert("RGB")
        mat = Image.open(MATTE_DIR / f"f_{n:04d}.png").convert("RGBA")
        cut = cuts[n - 1]
        a = src.copy()
        d = ImageDraw.Draw(a)
        d.line([(cut, 0), (cut, 719)], fill=(255, 0, 0), width=2)
        d.text((cut + 4, 8), f"cut={cut}", fill=(255, 60, 60))
        a = a.crop((200, 30, 900, 700)).resize((350, 335))
        bg = Image.new("RGBA", mat.size, (46, 50, 56, 255))
        bg.alpha_composite(mat)
        b = bg.convert("RGB").crop((200, 30, 900, 700)).resize((350, 335))
        panels.append((n, a, b))
    sheet = Image.new("RGB", (350 * 2 + 30, 360 * len(panels) + 10), (245, 245, 245))
    ds = ImageDraw.Draw(sheet)
    for i, (n, a, b) in enumerate(panels):
        y = i * 360 + 22
        sheet.paste(a, (10, y)); sheet.paste(b, (370, y))
        ds.text((10, i * 360 + 4), f"f{n:04d}  原帧 + 切线", fill=(20, 20, 20))
        ds.text((370, i * 360 + 4), f"f{n:04d}  纯人物抠像（车已去除）", fill=(20, 20, 20))
    sheet.save(PROBE / "compare_person_cart_split.png")
    print(f"[SEG] 分割对照 → {PROBE / 'compare_person_cart_split.png'}")
    return info


if __name__ == "__main__":
    run(probe_only="--probe" in sys.argv)
