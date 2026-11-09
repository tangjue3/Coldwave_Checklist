# -*- coding: utf-8 -*-
"""ART-INTEGRATE-005 阶段2：把 ART_CHAR_001 r04（推车行走四帧）登记进素材台账。
状态固定「待审核」（引擎试用），**不升运行时可用**——升格必须等美术总监裁定。"""
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = ROOT / "素材库" / "素材台账.csv"

ROW = {
    "素材ID": "ART_CHAR_001",
    "名称": "许知夏 · 推车行走（r04，四帧循环）",
    "所属分类": "角色",
    "对应角色或场景": "许知夏（主角，推购物车时）",
    "当前版本": "r04",
    "来源": "用户提交的 ART-RUNTIME-005 交付包（Coldfront_ART_RUNTIME_005_push_walk_r04_v1.zip）",
    "用途": "推车时的行走循环：双臂不摆、迈步向前，替换「扶车静止单帧整段滑行」的过渡画面；"
            "上半身 88 行直接复用 r03 原像素，头发 / 脸 / 上身 / 双手零漂移",
    "制作状态": "引擎试用",
    "审核状态": "待审核",
    "版权或授权备注": "原创 AI 生成运行时帧，用户提交；128×176 RGBA、alpha 仅 0/255 两档、无缩放；"
                     "Nearest 采样；母图在转存库留档，不进 PCK。帧宽 70/61/55/55 是腿部张开幅度，不是缩放",
    "原始文件路径": "转存库/ART_RUNTIME_005_留档/ART_CHAR_001_r04_source_00_contact.png",
    "库内文件路径": "美术设定集/01-角色/ART_CHAR_001_r04_push_walk_right_00_contact.png",
    "对应运行时资源路径": "assets/characters/player_sprite_frames.tres",
    "制作与修改说明": "2026-11-09 ART-INTEGRATE-005 收录：四帧 00_contact → 01_transfer → 02_contact → "
                     "03_transfer，loop，画布 128×176、枢轴 (64,168)、顶 y=8、脚底 y=167（可见高 160）。"
                     "引擎实测：上身 88 行与 r03 差异 0 px、头部中轴漂移 0.00 px、四帧脚底误差 0.0 px、"
                     "手部行带 (77,83) 与 r03 一致、手部间隙 +2.0 px 逐帧不变。"
                     "**状态：待审核（引擎试用）。全部用例通过也不升运行时可用，等美术总监裁定。**",
    "相关文件": "转存库/ART_RUNTIME_005_留档/README.md|转存库/ART_RUNTIME_005_留档/QA_FRAME_SHA256.txt|"
               "美术设定集/01-角色/ART_CHAR_001_r03_push_idle_right_128x176.png",
    "动画帧数": "4",
    "帧率FPS": "6（另测 7 FPS 对照）",
    "尺寸": "128×176（可见高 160，顶 y=8，脚底 y=167）",
    "方向": "右（朝左为水平镜像）",
    "预览文件": "美术设定集/01-角色/ART_CHAR_001_r04_push_walk_right_00_contact.png",
    "精灵图文件": "assets/characters/player_sprite_frames.tres",
}


def main() -> int:
    with CSV_PATH.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        rows = list(reader)

    assert set(ROW.keys()) == set(fieldnames), "字段与表头不一致"
    replaced = False
    for i, r in enumerate(rows):
        if r["素材ID"] == "ART_CHAR_001" and r["当前版本"] == "r04":
            rows[i] = dict(ROW)   # upsert：用最新字段覆盖旧行
            replaced = True
    if not replaced:
        rows.append(dict(ROW))

    with CSV_PATH.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    print(f"[LEDGER] 已追加 ART_CHAR_001 r04 行（共 {len(rows)} 行），状态=待审核")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
