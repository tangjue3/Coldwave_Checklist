"""VIDEO-FINALIZE-001：把三段 512×704 高清动画正式登记进素材库。

幂等、可复现。做四件事：

1. 台账补一列 `已知限制`（结构化记录未修复问题，避免「认可」标签掩盖事实）。
2. upsert 三行正式条目：ART_CHAR_001 r10 / r11 / r12。
3. 把 assets/characters/ 的 58 张帧**原样复制**到
   `素材库/美术设定集/01-角色/动画帧/{r10,r11,r12}/`，
   逐文件校验 SHA-256 一致（不缩放、不调色、不重新生成任何素材）。
4. 更新 `素材库/ID登记表.csv` 中 ART_CHAR_001 的备注。

版本号从 r10 起：r01–r09 已在 ART-RESET-001 全部删除，跳过以免与废弃版本混淆。
**已知限制按事实填写，不因转正而清空。**

    python tools/artlib_finalize_001.py           # 执行登记
    python tools/artlib_finalize_001.py --check   # 只校验，不写文件
"""
from __future__ import annotations

import csv
import hashlib
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = ROOT / "素材库" / "素材台账.csv"
REGISTRY = ROOT / "素材库" / "ID登记表.csv"
CHAR_DIR = ROOT / "assets" / "characters"
FRAME_ROOT = ROOT / "素材库" / "美术设定集" / "01-角色" / "动画帧"

MOVIE = "转存库/Generating_pixel_art_walking_ani…_0afbba1d.mp4"
SOURCE_NOTE = (f"用户亲自生成并提供的 AI 视频（{MOVIE}）→ tools/video/ 管线"
               "拆帧 / 绿幕抠像 / 对齐 → quality_002.py 输出 512×704；未重新生成视频、未重绘角色")
LICENSE = "用户生成并提供的 AI 视频；仅本工程使用；未重新设计角色形象"

LIMITS = {
    "r10": "脚底滑动约 1.89 px/帧（源视频为原地跟拍、人物画面质心 std 4.3px，"
           "接入 100 px/s 平移后支撑脚无法锁地；未修复）；朝左仅 flip_h 镜像、无独立绘制帧",
    "r11": "视频只提供一次减速过程；仅 7/36 个 walk 相位（约 19%）能自然接上过渡，"
           "其余相位松手直接切站姿；未修复，未强行拼接",
    "r12": "源视频后段完全冻结（相邻帧差 0.00048），故为单帧待机、无呼吸循环；"
           "非缺陷但属已知表现限制",
}

COMMON_RELATED = [
    "docs/VIDEO-INTEGRATE-001_交付报告.md",
    "docs/VIDEO-QUALITY-002_交付报告.md",
    "docs/AI视频转Godot动画接入规范.md",
    "assets/characters/player_sprite_frames.tres",
    "素材库/美术设定集/01-角色/参考图/README.md",
]

# ---------------------------------------------------------------- 三行正式条目
ROWS: list[dict[str, str]] = [
    {
        "素材ID": "ART_CHAR_001", "名称": "许知夏 · 右向普通行走（walk_right）",
        "所属分类": "角色", "对应角色或场景": "许知夏（第一季主角）", "当前版本": "r10",
        "来源": SOURCE_NOTE,
        "用途": "PlayerController 普通行走循环；游戏内按 100 px/s 移动、24 FPS 播放",
        "制作状态": "运行时可用", "审核状态": "运行时可用",
        "版权或授权备注": LICENSE,
        "原始文件路径": MOVIE,
        "库内文件路径": "美术设定集/01-角色/动画帧/r10/ART_CHAR_001_r10_walk_right_00_512x704.png",
        "对应运行时资源路径": "assets/characters/ART_CHAR_001_vid001_hd_walk_right_00_512x704.png",
        "制作与修改说明": (
            "2026-11-10 VIDEO-INTEGRATE-001：从用户视频 f28–f63 取完整步态周期 36 帧 / 24 FPS；"
            "循环接缝姿态差 0.0239，小于循环内帧间均值 0.0358。 "
            "VIDEO-QUALITY-002：贴图升到 512×704（scale 0.25 / offset (-256,-672) / LINEAR），"
            "stretch/mode 改 canvas_items；用户已确认高清画质满意。 "
            "VIDEO-FINALIZE-001：正式登记为运行时可用 + 视觉认可 + 正式使用。"
            "注意「视觉认可」仅指画质，动作遗留问题见「已知限制」列，未标记为已修复。"
        ),
        "相关文件": "|".join(COMMON_RELATED),
        "动画帧数": "36", "帧率FPS": "24",
        "尺寸": "512×704（游戏内显示 128×176 @ scale 0.25）", "方向": "右",
        "预览文件": "转存库/VIDEO-QUALITY-002/contact_hd_walk.png", "精灵图文件": "",
        "动作分组": "普通行走", "视觉评价": "认可", "使用状态": "正式使用", "归档标记": "",
        "动画帧序列": "美术设定集/01-角色/动画帧/r10/*.png", "参考用途": "",
        "已知限制": LIMITS["r10"],
    },
    {
        "素材ID": "ART_CHAR_001", "名称": "许知夏 · 行走停止过渡（walk_to_idle）",
        "所属分类": "角色", "对应角色或场景": "许知夏（第一季主角）", "当前版本": "r11",
        "来源": SOURCE_NOTE,
        "用途": "玩家停止移动时从 walk_right 过渡到 idle_right；21 帧 / 24 FPS / 0.875 s，不循环",
        "制作状态": "运行时可用", "审核状态": "运行时可用",
        "版权或授权备注": LICENSE,
        "原始文件路径": MOVIE,
        "库内文件路径": "美术设定集/01-角色/动画帧/r11/ART_CHAR_001_r11_walk_to_idle_00_512x704.png",
        "对应运行时资源路径": "assets/characters/ART_CHAR_001_vid001_hd_walk_to_idle_00_512x704.png",
        "制作与修改说明": (
            "2026-11-10 VIDEO-INTEGRATE-001：从视频 f137–f157 的减速收脚段取 21 帧；"
            "逐帧检查无突变、无脚底漂移。接入时按实测相位集合 "
            "(0/1/15/16/17/34/35) 决定是否播放过渡，其余相位直接站稳，不硬拼。 "
            "VIDEO-FINALIZE-001：正式登记。**相位覆盖不全的问题仍然存在，未修复**，"
            "见「已知限制」列。"
        ),
        "相关文件": "|".join(COMMON_RELATED),
        "动画帧数": "21", "帧率FPS": "24",
        "尺寸": "512×704（游戏内显示 128×176 @ scale 0.25）", "方向": "右",
        "预览文件": "转存库/VIDEO-INTEGRATE-001/preview/walk_to_idle.gif", "精灵图文件": "",
        "动作分组": "其他动作", "视觉评价": "认可", "使用状态": "正式使用", "归档标记": "",
        "动画帧序列": "美术设定集/01-角色/动画帧/r11/*.png", "参考用途": "",
        "已知限制": LIMITS["r11"],
    },
    {
        "素材ID": "ART_CHAR_001", "名称": "许知夏 · 右向站立待机（idle_right）",
        "所属分类": "角色", "对应角色或场景": "许知夏（第一季主角）", "当前版本": "r12",
        "来源": SOURCE_NOTE,
        "用途": "PlayerController 站立待机；视频后段实测冻结，采用单帧，8 FPS 循环设置但画面恒定",
        "制作状态": "运行时可用", "审核状态": "运行时可用",
        "版权或授权备注": LICENSE,
        "原始文件路径": MOVIE,
        "库内文件路径": "美术设定集/01-角色/动画帧/r12/ART_CHAR_001_r12_idle_right_00_512x704.png",
        "对应运行时资源路径": "assets/characters/ART_CHAR_001_vid001_hd_idle_right_00_512x704.png",
        "制作与修改说明": (
            "2026-11-10 VIDEO-INTEGRATE-001：视频 f157–f192 相邻帧差仅 0.00048，"
            "基本完全静止，故取 f175 单帧，不硬凑呼吸循环（避免无故晃动 / 体型变化 / 脚底漂移）。 "
            "VIDEO-FINALIZE-001：正式登记。单帧待机属如实记录，见「已知限制」列。"
        ),
        "相关文件": "|".join(COMMON_RELATED),
        "动画帧数": "1", "帧率FPS": "8",
        "尺寸": "512×704（游戏内显示 128×176 @ scale 0.25）", "方向": "右",
        "预览文件": "转存库/VIDEO-INTEGRATE-001/preview/idle_right.gif", "精灵图文件": "",
        "动作分组": "待机", "视觉评价": "认可", "使用状态": "正式使用", "归档标记": "",
        "动画帧序列": "美术设定集/01-角色/动画帧/r12/*.png", "参考用途": "",
        "已知限制": LIMITS["r12"],
    },
]

SEGMENTS = [
    ("r10", "walk_right", 36),
    ("r11", "walk_to_idle", 21),
    ("r12", "idle_right", 1),
]


def sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def copy_frames(check_only: bool) -> tuple[int, list[str]]:
    """原样复制 58 张帧；逐文件校验 SHA-256，绝不改动像素。"""
    problems: list[str] = []
    n = 0
    for ver, slug, count in SEGMENTS:
        dst_dir = FRAME_ROOT / ver
        for i in range(count):
            src = CHAR_DIR / f"ART_CHAR_001_vid001_hd_{slug}_{i:02d}_512x704.png"
            dst = dst_dir / f"ART_CHAR_001_{ver}_{slug}_{i:02d}_512x704.png"
            if not src.is_file():
                problems.append(f"缺少源帧 {src.name}")
                continue
            if not check_only:
                dst_dir.mkdir(parents=True, exist_ok=True)
                if not dst.is_file() or sha(dst) != sha(src):
                    shutil.copy2(src, dst)
            if not dst.is_file():
                problems.append(f"缺帧{'(待生成)' if not check_only else ''} {dst.name}")
                continue
            if sha(dst) != sha(src):
                problems.append(f"像素不一致（不是纯复制）{dst.name}")
            n += 1
    return n, problems


def read_csv() -> tuple[list[str], list[dict]]:
    with CSV_PATH.open(encoding="utf-8-sig", newline="") as f:
        r = csv.DictReader(f)
        return list(r.fieldnames or []), list(r)


def write_csv(fields: list[str], rows: list[dict]) -> None:
    with CSV_PATH.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields, lineterminator="\r\n")
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k, "") for k in fields})


def main() -> int:
    check_only = "--check" in sys.argv
    fields, rows = read_csv()
    problems: list[str] = []

    if "已知限制" not in fields:
        fields = fields + ["已知限制"]
        rows = [{**r, "已知限制": ""} for r in rows]
        if not check_only:
            print("[1/4] 台账补列：已知限制")

    for spec in ROWS:
        key = (spec["素材ID"], spec["当前版本"])
        idx = next((i for i, r in enumerate(rows)
                    if r.get("素材ID") == key[0] and r.get("当前版本") == key[1]), None)
        if idx is None:
            rows.append({k: "" for k in fields} | spec)
            if not check_only:
                print(f"[2/4] 新增台账行 {key[0]}@{key[1]}")
        else:
            cur = rows[idx]
            diff = [k for k in spec if (cur.get(k) or "") != spec[k]]
            if diff:
                if not check_only:
                    print(f"[2/4] 更新台账行 {key[0]}@{key[1]}：{', '.join(diff)}")
                rows[idx] = {**cur, **spec}
            elif check_only:
                pass
    if check_only:
        for spec in ROWS:
            cur = next((r for r in rows if r.get("素材ID") == spec["素材ID"]
                        and r.get("当前版本") == spec["当前版本"]), None)
            if cur is None or any((cur.get(k) or "") != spec[k] for k in spec):
                problems.append(f"台账行未登记或不一致：{spec['素材ID']}@{spec['当前版本']}")
        if "已知限制" not in fields:
            problems.append("台账缺少「已知限制」列")

    n, cp = copy_frames(check_only)
    problems += cp
    if not check_only:
        print(f"[3/4] 帧序列 {n} 张已就位（SHA-256 逐文件校验）")

    # ID 登记表备注
    reg = REGISTRY.read_text(encoding="utf-8-sig")
    old = "新动画由 VIDEO-INTEGRATE 任务产出后在本号下新增 rNN 行"
    new = ("新动画由 VIDEO-INTEGRATE 任务产出后在本号下新增 rNN 行；"
           "VIDEO-FINALIZE-001（2026-11-10）已正式登记 r10=walk_right / "
           "r11=walk_to_idle / r12=idle_right（512×704 高清，用户确认画质满意；"
           "脚底滑动与停止过渡相位限制仍未修复）。r01–r09 已删除，故从 r10 起编号")
    if old in reg:
        if not check_only:
            REGISTRY.write_text(reg.replace(old, new), encoding="utf-8-sig", newline="")
            print("[4/4] ID 登记表备注已更新")
    elif new not in reg:
        problems.append("ID 登记表备注格式变化，需手工核对")

    if check_only:
        if problems:
            print("[CHECK] 登记未完成：")
            for p in problems:
                print("  -", p)
            return 1
        print(f"[CHECK] 已登记：3 行正式条目 + {n} 张帧 + 已知限制列")
        return 0

    if problems:
        print("[FAIL] 复制校验失败：")
        for p in problems:
            print("  -", p)
        return 1
    write_csv(fields, rows)
    print(f"[OK] 台账 {len(rows)} 行 / {len(fields)} 列；"
          f"角色运行时条目 3 条；已知限制 3 条均如实保留")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
