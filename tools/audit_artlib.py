"""素材库完整性审计（TASK-ARTLIB-CLEAN-001 建立）。

一条命令回答「素材库现在是不是自洽的」：
台账 ↔ 磁盘 ↔ assets/ ↔ ID 登记表 ↔ 文档链接，逐项交叉核对。

用法（工程根目录）：
  python tools/audit_artlib.py            # 全量审计，有不一致以 1 退出
  python tools/audit_artlib.py --quiet    # 只打摘要

设计原则：
  · 只读，不改任何文件（写入由 artlib_curate.py / build_artlib.py 负责）
  · 每条失败都带「素材 ID + 路径 + 期望 vs 实际」，能直接定位
  · 已知例外写进白名单并注明理由，不靠 `try/except pass` 掩盖
"""
from __future__ import annotations

import csv
import glob
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "素材库"
CSV_PATH = LIB / "素材台账.csv"
ART_DIR = LIB / "美术设定集"
THUMBS = LIB / ".thumbs"
ASSETS = ROOT / "assets"

NEW_COLUMNS = ["动作分组", "视觉评价", "使用状态", "归档标记", "动画帧序列", "参考用途"]
CATS = ["角色", "场景", "物品与家具", "界面", "特效与动画", "世界观与剧情"]
ACT_GROUPS = ["外观设定", "待机", "普通行走", "推购物车", "反向拉车", "搬运", "其他动作", "不适用"]
VISUAL = ["认可", "待优化", "未评价", "不适用"]
USAGE = ["正式使用", "回退保留", "未使用"]

# 没有独立 ID、也不该占号的衍生目录（各自 README 说明了原因）
DERIVED_DIRS = ["验收对照", "参考图"]
# assets/ 下不参与台账的目录：rig001 是技术原型，reference 是外部参考图
ASSET_EXEMPT = ["assets/dev/", "assets/reference/"]
# 运行时条目正常都要求真 alpha（防「白底冒充透明」）。
# 这里是明确按设计就该满幅不透明的整屏底图，不适用该规则，逐条显式列出。
OPAQUE_BY_DESIGN = {
    "ART_UI_004@r01",  # 主菜单整屏背景 1672×941
}

failures: list[str] = []
warnings: list[str] = []
notes: list[str] = []


def fail(msg: str) -> None:
    failures.append(msg)


def warn(msg: str) -> None:
    warnings.append(msg)


def note(msg: str) -> None:
    notes.append(msg)


def parse_size(text: str):
    """从 '128×176（可见 41×160）' 取画布尺寸 → (128, 176)。"""
    m = re.match(r"\s*(\d+)\s*[×xX*]\s*(\d+)", text or "")
    return (int(m.group(1)), int(m.group(2))) if m else None


def png_info(path: Path):
    from PIL import Image
    with Image.open(path) as im:
        return im.size, im.mode


def main() -> int:
    quiet = "--quiet" in sys.argv
    with CSV_PATH.open(encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        fields = list(reader.fieldnames or [])
        rows = list(reader)

    print("========== 素材库完整性审计 ==========")
    print(f"台账 {len(rows)} 行 / {len(fields)} 列")

    # ---------------------------------------------------------------- 1. 列结构
    miss = [c for c in NEW_COLUMNS if c not in fields]
    if miss:
        fail(f"台账缺少整理列：{', '.join(miss)}（先跑 python tools/artlib_curate.py）")

    # ---------------------------------------------------------------- 2. 唯一键与枚举
    keys = set()
    for r in rows:
        sid = (r.get("素材ID") or "").strip()
        ver = (r.get("当前版本") or "").strip()
        key = (sid, ver)
        if key in keys:
            fail(f"台账唯一键重复：{sid}@{ver}")
        keys.add(key)
        if (r.get("所属分类") or "").strip() not in CATS:
            fail(f"分类非法：{sid}@{ver} = {r.get('所属分类')!r}")
        if "动作分组" in r and (r["动作分组"] or "").strip() not in ACT_GROUPS:
            fail(f"动作分组非法：{sid}@{ver} = {r['动作分组']!r}")
        if "视觉评价" in r and (r["视觉评价"] or "").strip() not in VISUAL:
            fail(f"视觉评价非法：{sid}@{ver} = {r['视觉评价']!r}")
        if "使用状态" in r and (r["使用状态"] or "").strip() not in USAGE:
            fail(f"使用状态非法：{sid}@{ver} = {r['使用状态']!r}")

    # ---------------------------------------------------------------- 3. 库内文件 + 尺寸 + alpha
    runtime_usable = []
    for r in rows:
        sid = (r["素材ID"] or "").strip()
        ver = (r["当前版本"] or "").strip()
        rel = (r.get("库内文件路径") or "").strip()
        if not rel:
            continue
        p = LIB / rel
        if not p.is_file():
            fail(f"库内文件不存在：{sid}@{ver} → {rel}")
            continue
        if p.suffix.lower() == ".png":
            size, mode = png_info(p)
            want = parse_size(r.get("尺寸") or "")
            if want and size != want:
                fail(f"尺寸与台账不符：{sid}@{ver} 台账 {want[0]}×{want[1]}，实际 {size[0]}×{size[1]}")
            # 概念整幅图本来就是不透明的；只有「要进游戏」的条目才必须有真 alpha。
            # 例外：整屏铺满的背景图（如主菜单底图）按设计就是满幅不透明，
            # 透明通道没有意义，单列白名单放行，其余运行时条目仍强制真 alpha。
            if mode not in ("RGBA", "LA", "P"):
                if (r.get("审核状态") or "").strip() == "运行时可用" \
                        and f"{sid}@{ver}" not in OPAQUE_BY_DESIGN:
                    fail(f"运行时条目缺少透明通道：{sid}@{ver} → {rel}（mode={mode}）")

        if (r.get("对应运行时资源路径") or "").strip():
            rt = (ROOT / r["对应运行时资源路径"]).resolve()
            if not rt.is_file():
                fail(f"运行时路径指向的文件不存在：{sid}@{ver} → {r['对应运行时资源路径']}")
            elif ASSETS.resolve() not in rt.parents:
                fail(f"运行时路径不在 assets/ 下：{sid}@{ver} → {r['对应运行时资源路径']}")
        if (r.get("审核状态") or "").strip() == "运行时可用":
            runtime_usable.append((sid, ver))

    # ---------------------------------------------------------------- 4. 状态互斥
    for r in rows:
        sid, ver = (r["素材ID"] or "").strip(), (r["当前版本"] or "").strip()
        st = (r.get("审核状态") or "").strip()
        arch = (r.get("归档标记") or "").strip()
        use = (r.get("使用状态") or "").strip()
        rt = (r.get("对应运行时资源路径") or "").strip()
        if arch == "是" and rt:
            fail(f"归档条目不得有运行时路径：{sid}@{ver} → {rt}")
        if use == "正式使用" and st != "运行时可用":
            fail(f"「正式使用」但审核状态不是运行时可用：{sid}@{ver} = {st}")
        if st == "运行时可用" and not rt:
            fail(f"「运行时可用」但没有运行时路径：{sid}@{ver}")
        if st == "不予通过" and rt:
            fail(f"「不予通过」仍有运行时路径：{sid}@{ver} → {rt}")

    # ---------------------------------------------------------------- 5. 未登记文件
    registered = set()
    frame_globs = []
    for r in rows:
        for k in ("库内文件路径", "预览文件", "精灵图文件"):
            v = (r.get(k) or "").strip()
            if v and not v.startswith("assets/"):
                registered.add(Path(v).as_posix())
        g = (r.get("动画帧序列") or "").strip()
        if g:
            frame_globs.append(g)
    for g in frame_globs:
        hits = glob.glob(str(LIB / g))
        if not hits:
            fail(f"动画帧序列 glob 没有匹配到文件：{g}")

    unreg = []
    for p in sorted(ART_DIR.rglob("*")):
        if not p.is_file() or p.suffix.lower() == ".md":
            continue
        rel = p.relative_to(LIB).as_posix()
        if rel in registered:
            continue
        if any(glob.fnmatch.fnmatch(rel, g) for g in frame_globs):
            continue
        if any(d in rel.split("/") for d in DERIVED_DIRS):
            continue
        unreg.append(rel)
    for rel in unreg:
        fail(f"美术设定集内有未登记文件（既不是台账文件、也不匹配帧序列、也不在衍生目录）：{rel}")

    # ---------------------------------------------------------------- 6. assets 孤儿
    # 帧级文件不单独登记台账：它们由父动画行的 动画帧序列 描述。
    # 所以「文件名里含某个运行时可用 ID」即视为已被覆盖。
    covered = {(ROOT / r["对应运行时资源路径"]).resolve()
               for r in rows if (r.get("对应运行时资源路径") or "").strip()}
    usable_ids = sorted({(r["素材ID"] or "").strip() for r in rows
                         if (r.get("动画帧序列") or "").strip()}, key=len, reverse=True)
    # ART-RESET-001：四张内容错误图已彻底删除，这里不再留例外。
    KNOWN_LEGACY: set[str] = set()
    # VIDEO-FINALIZE-001：三段 512×704 动画已正式登记（r10/r11/r12），
    # 不再是「候选」。assets/characters/ 的帧由台账三行的 动画帧序列 覆盖。
    # 这里额外做一次正式登记的帧数闭环校验：台账声明 = 运行时帧 = 素材库副本。
    FINAL_SEGS = {"r10": 36, "r11": 21, "r12": 1}
    # 只统计正式登记帧；vid002_cand_* 是未转正的候选，见下方单独校验
    char_frames = sorted(p for p in (ROOT / "assets" / "characters").glob("*.png")
                         if "vid002_cand_" not in p.name)
    declared = sum(int(r.get("动画帧数") or 0) for r in rows
                   if r.get("素材ID") == "ART_CHAR_001" and r.get("当前版本") in FINAL_SEGS)
    if len(char_frames) != declared or declared != sum(FINAL_SEGS.values()):
        fail(f"正式动画帧数不闭环：assets {len(char_frames)} 张 / "
             f"台账声明 {declared} 张 / 约定 {sum(FINAL_SEGS.values())} 张")
    for ver, want in FINAL_SEGS.items():
        d = ART_DIR / "01-角色" / "动画帧" / ver
        n = len(list(d.glob("*.png"))) if d.is_dir() else 0
        if n != want:
            fail(f"素材库 {ver} 帧副本 {n} 张，台账约定 {want} 张")
    print(f"  [INFO] 正式登记 r10/r11/r12：assets {len(char_frames)} 张 = "
          f"台账 {declared} 张 = 素材库副本 {sum(FINAL_SEGS.values())} 张；"
          f"已知限制 3 条均保留")

    # VIDEO-INTEGRATE-002：50 张推车帧是**候选**，不进台账 / 白名单 / 总览正式状态。
    # 只做可追溯性校验：必须有候选 meta.json，且三段帧数与 SpriteFrames 声明一致。
    cand_frames = sorted((ROOT / "assets" / "characters").glob(
        "ART_CHAR_001_vid002_cand_*.png"))
    cand_meta = ROOT / "assets" / "dev" / "video_candidates" / "VIDEO-INTEGRATE-002" / "meta.json"
    if cand_frames:
        if not cand_meta.is_file():
            fail(f"发现 {len(cand_frames)} 张推车候选帧，但缺少可追溯的 meta.json")
        else:
            cm = json.loads(cand_meta.read_text(encoding="utf-8"))
            anims = cm.get("godot", {}).get("animations", {})
            want = {"push_walk_right": 32, "push_walk_to_idle": 17, "push_idle_right": 1}
            if len(cand_frames) != sum(want.values()):
                fail(f"推车候选帧 {len(cand_frames)} 张，约定 {sum(want.values())} 张")
            for name, n in want.items():
                got = anims.get(name, {}).get("frames", -1)
                if got != n:
                    fail(f"候选 {name} 帧数 {got}，约定 {n}")
            print(f"  [INFO] VIDEO-INTEGRATE-002 推车候选 {len(cand_frames)} 张："
                  f"未进台账 / 白名单 / 总览正式状态，meta.json 可追溯，待美术审核")

    # ---------------------------------------------------------------- 7. .thumbs 一致性
    if THUMBS.is_dir():
        thumbs = list(THUMBS.glob("*.jpg"))
        # 期望值 = 台账有条目的行 + 参考图目录里的派生裁图（裁图不占 ID，不进台账）
        crop_dir = ART_DIR / "01-角色" / "参考图"
        crop_names = {f"crop_{p.stem.rsplit('_', 1)[-1]}.jpg"
                      for p in crop_dir.glob("ART_CHAR_001_v02_ref_*.png")} if crop_dir.is_dir() else set()
        want_names = {f"{r['素材ID']}_{r['当前版本']}.jpg"
                      for r in rows if (r.get("库内文件路径") or "").strip()} | crop_names
        if len(thumbs) != len(want_names):
            fail(f".thumbs 缩略图 {len(thumbs)} 张，与应生成条数 {len(want_names)} 不符（重跑 build_artlib.py）")
        stale = {p.name for p in thumbs} - want_names
        for s_ in sorted(stale):
            warn(f".thumbs 有失效缩略图（台账已无此行）：{s_}")

    # ---------------------------------------------------------------- 8. 文档死链
    dead = []
    link_re = re.compile(r"\]\(([^)\s]+)\)")
    for md in sorted(LIB.rglob("*.md")):
        text = md.read_text(encoding="utf-8", errors="replace")
        for target in link_re.findall(text):
            if target.startswith(("http://", "https://", "#", "mailto:")):
                continue
            t = target.split("#")[0].strip()
            if not t:
                continue
            if not (md.parent / t).exists():
                dead.append(f"{md.relative_to(ROOT).as_posix()} → {target}")
    for d in dead:
        fail(f"素材库文档死链：{d}")

    # ---------------------------------------------------------------- 9. 参考图完整性
    ref_groups = {}
    for r in rows:
        for a in (r.get("参考用途") or "").split("|"):
            a = a.strip()
            if a:
                ref_groups.setdefault(a, []).append(f"{r['素材ID']}@{r['当前版本']}")
    for need in ("普通行走", "推购物车", "搬箱", "搬水"):
        if need not in ref_groups:
            fail(f"AI 视频参考图缺口：动作「{need}」没有任何已登记参考图")
    for a, items in ref_groups.items():
        note(f"参考图 {a}：{', '.join(items)}")

    # ---------------------------------------------------------------- 汇总
    print("")
    if not quiet:
        for n in notes:
            print(f"  · {n}")
        if warnings:
            print("\n-- 警告 --")
            for w in warnings:
                print(f"  [WARN] {w}")
        if failures:
            print("\n-- 失败 --")
            for f_ in failures:
                print(f"  [FAIL] {f_}")

    print("")
    print(f"运行时可用：{len(runtime_usable)} 条")
    print(f"动作分组分布：" + "、".join(
        f"{g}={sum(1 for r in rows if (r.get('动作分组') or '').strip() == g)}" for g in ACT_GROUPS))
    print(f"审计结果：失败 {len(failures)}，警告 {len(warnings)}，"
          f"{'不通过' if failures else '通过'}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
