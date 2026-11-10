"""绿幕色度键 + 高质量降采样（VIDEO-INTEGRATE-001 针对性改进）。

pipeline.py 原本的两处实现不适合高分辨率真人/赛璐璐素材：

* `cmd_matte` 用「RGB 到键色的最大通道差」——遇到绿幕溢色边缘会把绿色一起留下来，
  而且人物身上的深色区域离键色很远，过渡带不好控制。
* `cmd_align` 用「整数倍 NEAREST 直接抽样」——1094 px 高的人物抽到 164 px 会丢掉
  大量细节并产生锯齿，正是接入规范里禁止的「简单粗暴缩小」。

本模块提供两件事，都是**纯像素处理，不重绘、不改变形象**：

1. `chroma_key()`：基于 G − max(R,B) 的色度键 + 溢色抑制（despill）+
   连通域去杂点，输出干净的 RGBA。
2. `premultiplied_resize()`：预乘 alpha 后两阶段 Lanczos/AREA 降采样，
   避免透明像素 RGB=0 被插值成黑边，最后轻度 unsharp 找回轮廓。

依赖：numpy / OpenCV / Pillow。
"""
from __future__ import annotations

import cv2
import numpy as np
from PIL import Image, ImageFilter

# 绿度阈值：<= LOW 视为人物，>= HIGH 视为绿幕，中间做软过渡。
# 由 tools/video/integrate_001.py 对真实视频统计得出：人物核心 −38…5，绿幕 131…157。
GREEN_LOW = 8.0
GREEN_HIGH = 40.0
MIN_BLOB = 120          # 小于这个面积的孤立非绿团视为压缩噪点


def greenness(rgb: np.ndarray) -> np.ndarray:
    """G − max(R,B)：绿幕判定量，与亮度无关。"""
    a = rgb.astype(np.float32)
    return a[:, :, 1] - np.maximum(a[:, :, 0], a[:, :, 2])


def chroma_key(rgb: np.ndarray, *, low: float = GREEN_LOW,
               high: float = GREEN_HIGH, despill: float = 1.0,
               clean_blobs: bool = True) -> np.ndarray:
    """绿幕抠像 → RGBA(uint8)。

    despill 会把人物边缘被绿幕染绿的 G 通道压回 max(R,B)，
    只作用于有绿色优势的像素；衣服上正常的橄榄色 / 卡其色不受影响。
    """
    a = rgb.astype(np.float32)
    gn = greenness(rgb)

    # 软 alpha：绿度越高越透明
    alpha = np.clip((high - gn) / (high - low), 0.0, 1.0)
    alpha *= 255.0

    # 溢色抑制：spill = max(0, G - max(R,B))，按 (1-alpha) 加权
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    mx = np.maximum(r, b)
    spill = np.maximum(0.0, g - mx)
    if despill > 0:
        # 只减掉「绿色优势」那部分；不要动 g < max(R,B) 的正常棕色/肤色像素
        strength = despill * np.clip(gn / 60.0, 0.0, 1.0)
        a[:, :, 1] = g - spill * strength

    if clean_blobs:
        # 去掉绿幕压缩噪点形成的孤立「假人物」小块；人物是最大的连通域
        mask = (alpha > 8).astype(np.uint8)
        n, lab, stats, _ = cv2.connectedComponentsWithStats(mask, 8)
        if n > 1:
            keep = np.zeros(n, dtype=bool)
            big = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
            keep[big] = True
            # 面积够大的其他连通域也保留（例如手里的小道具）
            for k in range(1, n):
                if stats[k, cv2.CC_STAT_AREA] >= MIN_BLOB:
                    keep[k] = True
            good = keep[lab]
            alpha *= good
        # 轻微闭运算：补掉人物内部被误判的针孔，不扩大外轮廓
        core = (alpha > 128).astype(np.uint8)
        core = cv2.morphologyEx(core, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))
        alpha = np.maximum(alpha, core * 255.0)

    out = np.dstack([np.clip(a, 0, 255).astype(np.uint8),
                     np.clip(alpha, 0, 255).astype(np.uint8)])
    # 完全透明处 RGB 清零前先做「颜色外扩」，防止缩放时边缘发黑
    out[:, :, :3] = bleed_rgb(out)
    out[out[:, :, 3] == 0, :3] = 0
    return out


def bleed_rgb(rgba: np.ndarray, iterations: int = 3) -> np.ndarray:
    """把不透明区域的颜色向外扩几像素，半透明边缘才有正确颜色可插值。"""
    rgb = rgba[:, :, :3].astype(np.float32)
    alpha = rgba[:, :, 3].astype(np.float32) / 255.0
    known = alpha > 0.98
    out = rgb.copy()
    for _ in range(iterations):
        expanded = cv2.dilate(known.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
        ring = expanded & ~known
        if not ring.any():
            break
        # 环上像素取邻域内已知颜色的加权均值
        blurred = cv2.GaussianBlur(out * known[..., None], (3, 3), 0)
        weight = cv2.GaussianBlur(known.astype(np.float32), (3, 3), 0)
        fill = blurred / np.maximum(weight, 1e-6)[:, :, None]
        out[ring] = np.clip(fill[ring], 0, 255)
        known = expanded
    return np.clip(out, 0, 255).astype(np.uint8)


def premultiplied_resize(rgba: np.ndarray, size: tuple[int, int],
                         sharpen: float = 0.35) -> np.ndarray:
    """预乘 alpha 的两阶段高质量降采样，避免透明黑边和粗暴抽样。

    阶段 1：Lanczos 缩到目标 2 倍（保细节）
    阶段 2：AREA 缩到目标（等价于按面积平均，抗锯齿最好）
    最后对 RGB 做极轻的 unsharp（只在不透明处生效），抵消缩小带来的柔化。
    """
    a = rgba.astype(np.float32)
    alpha = a[:, :, 3:4] / 255.0
    premult = np.concatenate([a[:, :, :3] * alpha, a[:, :, 3:4]], axis=2)

    tw, th = size
    mid = (tw * 2, th * 2)

    def _rs(src, dst, interp):
        return cv2.resize(src, dst, interpolation=interp)

    p1 = _rs(premult, mid, cv2.INTER_LANCZOS4)
    p2 = _rs(p1, (tw, th), cv2.INTER_AREA)

    al = np.clip(p2[:, :, 3:4], 0, 255)
    rgb = np.clip(p2[:, :, :3] / np.maximum(al / 255.0, 1e-4), 0, 255)

    if sharpen > 0:
        blur = cv2.GaussianBlur(rgb, (0, 0), 0.8)
        detail = rgb - blur
        # 只在确实有内容的像素上锐化，避免透明边缘出现亮环
        strength = np.clip(al / 255.0, 0, 1)
        rgb = np.clip(rgb + detail * sharpen * strength, 0, 255)

    out = np.dstack([rgb.astype(np.uint8), np.clip(al, 0, 255).astype(np.uint8)])
    out[out[:, :, 3] == 0, :3] = 0
    return out


def paste_on_canvas(rgba: np.ndarray, canvas: tuple[int, int],
                    anchor: tuple[int, int], *, center_x: int | None = None,
                    top_pad: int = 6) -> np.ndarray:
    """把缩放后的人物贴到固定画布。

    center_x 给定时使用**全序列统一**的水平基准（而不是逐帧 bbox 居中），
    否则走路时身体左右摆动会被误当成整体位移，画面会出现横向抖动。
    """
    cw, ch = canvas
    ax, ay = anchor
    h, w = rgba.shape[:2]
    out = np.zeros((ch, cw, 4), dtype=np.uint8)
    if center_x is None:
        ox = int(round(ax - w / 2))
    else:
        ox = int(round(center_x - w / 2))
    oy = int(round(ay - h))
    ox = max(0, min(cw - w, ox))
    oy = max(top_pad, min(ch - h, oy))
    out[oy:oy + h, ox:ox + w] = rgba
    return out


def checker(width: int, height: int, cell: int = 12) -> Image.Image:
    """透明通道检查用的棋盘格底。"""
    y, x = np.mgrid[0:height, 0:width]
    m = ((x // cell + y // cell) % 2).astype(np.uint8)
    base = np.where(m[..., None] == 0, np.array([210, 210, 210]),
                    np.array([150, 150, 150])).astype(np.uint8)
    return Image.fromarray(base, "RGB")
