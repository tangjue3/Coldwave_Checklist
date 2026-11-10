"""素材库索引生成器（ARTLIB-001 建立，TASK-ARTLIB-CLEAN-001 重构为 v2）。

用法（在工程根目录）：
    python tools/build_artlib.py

做四件事：
1. 读 素材库/素材台账.csv（27 列，含 CLEAN-001 新增的 6 个整理列）；
2. 为每个有条目的行生成 .thumbs/ 缩略图；为多帧动画生成 .thumbs/anim/ 预览 GIF；
3. 用同一份 ID 映射重新生成「美术资产台账_ARTLIB-001修订版.md」；
4. 把数据内嵌进 素材库/美术总览.html，生成完全离线、可 file:// 双击打开的预览页。

页面相对 ART-006 的增量：
  · 三条独立的状态轴（技术状态 / 美术评价 / 使用状态），不再用一个标签概括一切
  · 角色按动作分组导航：外观设定 / 待机 / 普通行走 / 推购物车 / 反向拉车 / 搬运 / 其他动作
  · 同 ID 多版本的「版本对照」面板，可在灯箱里直接横向比
  · 序列帧播放器（真 alpha，无调色板损失）＋ GIF 预览，两套都有
  · AI 视频参考图专区：按动作聚合已登记参考图，并列出该动作还缺什么
  · 原始文件 / 库内副本 / 运行时资源三个入口都在灯箱里可点

不依赖 Web 服务、不联网、不修改任何原始图片。可重复运行。
"""
from __future__ import annotations

import csv
import glob as globmod
import json
import re
from pathlib import Path

from PIL import Image, ImageOps, ImageSequence

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "素材库"
THUMBS = LIB / ".thumbs"
ANIM = THUMBS / "anim"
CSV_PATH = LIB / "素材台账.csv"
HTML_PATH = LIB / "美术总览.html"
REVISED_PATH = LIB / "美术设定集" / "00-美术总览" / "美术资产台账_ARTLIB-001修订版.md"
V11_LEDGER = ROOT / "docs" / "handover_v1.1" / "05_美术资产生产台账与风格规范_v1.1.md"

THUMB_BOX = (480, 360)
THUMB_BG = (27, 32, 38)

CATEGORIES = ["角色", "场景", "物品与家具", "界面", "特效与动画", "世界观与剧情"]
STATUSES = ["概念草案", "待审核", "已通过设定审核", "正式素材制作中", "运行时可用",
            "不予通过", "已弃用"]

# ---- 角色动作门类（页面左侧二级导航，顺序即业务优先级） ----
ACT_GROUPS = ["外观设定", "待机", "普通行走", "推购物车", "反向拉车", "搬运", "其他动作"]

# ---- 七种状态标记：同一行可以同时命中多个（技术通过 ≠ 美术满意 ≠ 在用） ----
MARK_TAGS = [
    ("已确定外观设定", "审核状态 = 已通过设定审核，外观方向锁定"),
    ("已通过技术验收", "审核状态 = 运行时可用，工程侧可用"),
    ("当前游戏使用中", "使用状态 = 正式使用，游戏里跑的就是它"),
    ("视觉质量待优化", "视觉评价 = 待优化，工程能跑但美术不满意"),
    ("待审核", "审核状态 = 待审核"),
    ("历史归档", "归档标记 = 是，仅作追溯"),
    ("不予通过", "审核状态 = 不予通过"),
]

# ---- AI 视频转游戏动画：目标动作与参考图归属 ----
REF_ACTIONS = [
    ("普通行走", "walk", "朝右行走循环，主角单人", ["ART_CHAR_001"]),
    ("推购物车", "push_walk", "朝右推行购物车，人物与车体同框", ["ART_CHAR_001", "ART_FURN_103"]),
    ("搬箱", "carry_box", "朝右双手搬食品纸箱，负重步态", ["ART_CHAR_001", "ART_ITEM_102"]),
    ("搬水", "carry_water", "朝右双手搬六瓶装饮用水", ["ART_CHAR_001", "ART_ITEM_101"]),
]

# 已确认尚未交付的动作（页面「动作缺口」页用，来源：README §四 + ART-RIG-001 报告）
ACTION_GAPS = [
    ("反向拉车", "拉车专用动作，与推车方向相反的受力姿态", "ART_CHAR_001", "未交付"),
    ("搬运", "双手抱持重物的行走循环，箱 / 水两种体积", "ART_CHAR_001", "未交付"),
    ("转身", "左右朝向切换的过渡帧（当前为瞬时镜像）", "ART_CHAR_001", "未交付"),
    ("朝左独立绘制", "朝左目前是水平镜像，未独立绘制", "ART_CHAR_001", "未交付"),
    ("车轮滚动", "购物车车轮滚动帧，当前车体静止滑行", "ART_FURN_103", "未交付"),
    ("正式 TileSet", "场景仍为概念整幅图，无可用 TileSet", "ART_SCENE_101", "未交付"),
]

# v1.1 美术台账旧 ID → 新 ART_* ID（唯一来源，同时用于生成修订版文档）
CHAR = {"01": "ART_CHAR_001", "02": "ART_CHAR_101", "03": "ART_CHAR_102",
        "04": "ART_CHAR_104", "05": "ART_CHAR_105", "06": "ART_CHAR_106",
        "07": "ART_CHAR_107", "08": "ART_CHAR_108", "09": "ART_CHAR_109",
        "10": "ART_CHAR_110"}
SCENE = {"01": "ART_SCENE_101", "02": "ART_SCENE_102", "03": "ART_SCENE_111",
         "04": "ART_SCENE_112", "05": "ART_SCENE_104", "06": "ART_SCENE_105",
         "07": "ART_SCENE_106", "08": "ART_SCENE_107", "09": "ART_SCENE_108",
         "10": "ART_SCENE_109", "11": "ART_SCENE_110"}
ID_TABLES = [("C", CHAR), ("S", SCENE), ("I", {"01": "ART_ITEM_001", "02": "ART_ITEM_103"}),
             ("F", {"01": "ART_FURN_001"}),
             ("UI", {"01": "ART_UI_001", "02": "ART_UI_002", "03": "ART_UI_003"}),
             ("FX", {"01": "ART_FX_001"})]

REVISED_HEADER = """# 美术资产生产台账 · ARTLIB-001 ID 修订版

> **这是修订副本，不是原件。** 原文件 `docs/handover_v1.1/05_美术资产生产台账与风格规范_v1.1.md` 保持不动。
> 本副本只把**美术素材 ID** 换成 `ART_*` 命名，用于消除与剧情事件 ID 的撞名；
> 剧情事件 ID、角色名、数值、色板、美术要求全部保持原样。
>
> 完整映射与 S10 裁定见 `素材库/ID对照表.md`。
>
> ✅ **S10 命名已由总策划裁定（PREP-003）**：
> - 剧情 `S10` = 第一季支线《一个放错的箱子》，编号保持不变；
> - 美术「电台/手机特写背景」= `ART_SCENE_109`（本文件里的这一处）；
> - v1.1 `00_升级说明与执行顺序.md` 中「`S10` 必须保留门口通路」指的是**剧情 S10**，不是美术背景。
>
> 剧情文档（`docs/handover_v1.0/02`、`docs/handover_v1.1/00`、`docs/handover_v1.1/04`）**一个字未改**。
>
> 生成方式：`python tools/build_artlib.py`（ID 映射表是本脚本的唯一来源）。
> 本轮**没有**据此生产任何新美术资源。

---

"""


def repo_link(path: str) -> str:
    """台账里的路径是仓库相对路径；预览页在 素材库/ 下，需要退一层。"""
    p = (path or "").strip()
    if not p:
        return ""
    if p.startswith(("docs/", "assets/", "scenes/", "scripts/", "tests/", "tools/", "转存库/")):
        return "../" + p
    return p


def make_thumb(src: Path, dest: Path) -> bool:
    if not src.is_file():
        return False
    try:
        with Image.open(src) as im:
            im = ImageOps.exif_transpose(im)
            if im.mode in ("RGBA", "LA", "P"):
                rgba = im.convert("RGBA")
                canvas = Image.new("RGBA", rgba.size, THUMB_BG + (255,))
                canvas.alpha_composite(rgba)
                im = canvas.convert("RGB")
            else:
                im = im.convert("RGB")
            thumb = ImageOps.contain(im, THUMB_BOX, Image.LANCZOS)
            tile = Image.new("RGB", THUMB_BOX, THUMB_BG)
            tile.paste(thumb, ((THUMB_BOX[0] - thumb.width) // 2,
                               (THUMB_BOX[1] - thumb.height) // 2))
            dest.parent.mkdir(parents=True, exist_ok=True)
            tile.save(dest, "JPEG", quality=82, optimize=True)
            return True
    except Exception as exc:  # 单张坏图不应阻断整份索引
        print(f"[WARN] 缩略图失败 {src.name}: {exc}")
        return False


def parse_fps(text: str, default: int = 10) -> int:
    m = re.search(r"\d+", text or "")
    return int(m.group(0)) if m else default


def make_anim_gif(frames: list[Path], dest: Path, fps: int) -> bool:
    """把帧序列合成 GIF 预览。最近邻、不缩放、不插值，只做调色板量化。"""
    imgs = []
    for f in frames:
        try:
            with Image.open(f) as im:
                imgs.append(im.convert("RGBA").copy())
        except Exception as exc:
            print(f"[WARN] GIF 帧读取失败 {f.name}: {exc}")
            return False
    if len(imgs) < 2:
        return False
    w, h = imgs[0].size
    if any(im.size != (w, h) for im in imgs):
        print(f"[WARN] 帧尺寸不一致，跳过 GIF：{dest.name}")
        return False
    # 统一铺同色底再量化：GIF 只支持 1 位透明，直接量化透明像素会变黑边
    flat = []
    for im in imgs:
        canvas = Image.new("RGBA", (w, h), THUMB_BG + (255,))
        canvas.alpha_composite(im)
        flat.append(canvas.convert("RGB").convert("P", palette=Image.ADAPTIVE, colors=128))
    dest.parent.mkdir(parents=True, exist_ok=True)
    flat[0].save(dest, save_all=True, append_images=flat[1:],
                 duration=max(20, round(1000 / max(1, fps))), loop=0, optimize=True)
    return True


def build_revised_ledger() -> None:
    text = V11_LEDGER.read_text(encoding="utf-8")
    for prefix, table in ID_TABLES:
        pattern = re.compile(r"(?<![A-Za-z0-9_\-])" + prefix + r"(\d{2})(?![A-Za-z0-9_\-])")
        text = pattern.sub(lambda m: table.get(m.group(1), prefix + m.group(1)), text)
    REVISED_PATH.write_text(REVISED_HEADER + text, encoding="utf-8")


def read_rows() -> list[dict]:
    with CSV_PATH.open(encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def tags_of(r: dict) -> list[str]:
    out = []
    st = (r.get("审核状态") or "").strip()
    if st == "已通过设定审核":
        out.append("已确定外观设定")
    if st == "运行时可用":
        out.append("已通过技术验收")
    if (r.get("使用状态") or "").strip() == "正式使用":
        out.append("当前游戏使用中")
    if (r.get("视觉评价") or "").strip() == "待优化":
        out.append("视觉质量待优化")
    if st == "待审核":
        out.append("待审核")
    if (r.get("归档标记") or "").strip() == "是":
        out.append("历史归档")
    if st == "不予通过":
        out.append("不予通过")
    return out


def build_data() -> list[dict]:
    THUMBS.mkdir(parents=True, exist_ok=True)
    ANIM.mkdir(parents=True, exist_ok=True)
    rows = read_rows()
    out = []
    ref_map: dict[str, list[str]] = {}

    for r in rows:
        rel = (r.get("库内文件路径") or "").strip()
        src = LIB / rel if rel else None
        thumb_file = f"{r['素材ID']}_{r['当前版本']}.jpg"
        has_thumb = make_thumb(src, THUMBS / thumb_file) if src else False

        related = []
        for item in (r.get("相关文件") or "").split("|"):
            item = item.strip()
            if item:
                related.append({"label": Path(item).name, "href": repo_link(item)})

        # 帧序列：glob 展开 → 用于序列帧播放器 / GIF / 帧数校验
        frame_glob = (r.get("动画帧序列") or "").strip()
        frames = sorted(globmod.glob(str(LIB / frame_glob))) if frame_glob else []
        frame_hrefs = [Path(p).relative_to(LIB).as_posix() for p in frames]

        fps = parse_fps(r.get("帧率FPS") or "", 10)
        gif_rel = ""
        if len(frame_hrefs) > 1:
            gif_name = f"{r['素材ID']}_{r['当前版本']}.gif"
            if make_anim_gif([Path(p) for p in frames], ANIM / gif_name, fps):
                gif_rel = f".thumbs/anim/{gif_name}"

        ref_for = [a.strip() for a in (r.get("参考用途") or "").split("|") if a.strip()]
        for a in ref_for:
            ref_map.setdefault(a, []).append(f"{r['素材ID']}@{r['当前版本']}")

        out.append({
            "id": r["素材ID"],
            "name": r["名称"],
            "cat": r["所属分类"],
            "subject": r["对应角色或场景"],
            "version": r["当前版本"],
            "source": r.get("来源", ""),
            "usage": r.get("用途", ""),
            "makeStatus": r["制作状态"],
            "status": r["审核状态"],
            "license": r.get("版权或授权备注", ""),
            "originPath": r.get("原始文件路径", ""),
            "originHref": repo_link(r.get("原始文件路径", "")),
            "localPath": rel,
            "localHref": rel,
            "runtimePath": r.get("对应运行时资源路径", ""),
            "runtimeHref": repo_link(r.get("对应运行时资源路径", "")),
            "notes": r.get("制作与修改说明", ""),
            "related": related,
            "anim": {
                "frames": r.get("动画帧数", ""),
                "fps": r.get("帧率FPS", ""),
                "size": r.get("尺寸", ""),
                "facing": r.get("方向", ""),
                "preview": r.get("预览文件", ""),
                "previewHref": repo_link(r.get("预览文件", "")),
                "sheet": r.get("精灵图文件", ""),
            },
            "act": (r.get("动作分组") or "").strip(),
            "visual": (r.get("视觉评价") or "").strip(),
            "useState": (r.get("使用状态") or "").strip(),
            "archived": (r.get("归档标记") or "").strip(),
            "refFor": ref_for,
            "tags": tags_of(r),
            "frameGlob": frame_glob,
            "frameHrefs": frame_hrefs,
            "fpsNum": fps,
            "gif": gif_rel,
            "thumb": f".thumbs/{thumb_file}" if has_thumb else "",
            "key": f"{r['素材ID']}@{r['当前版本']}",
        })

    # 同 ID 的版本链
    by_id: dict[str, list[dict]] = {}
    for d in out:
        by_id.setdefault(d["id"], []).append(d)
    for d in out:
        d["siblings"] = [{"key": s["key"], "version": s["version"], "status": s["status"],
                          "visual": s["visual"], "thumb": s["thumb"]}
                         for s in by_id[d["id"]]]
    return out


HTML_TEMPLATE = r"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>寒潮清单 · 美术设定库</title>
<style>
:root{
  --paper:#f5f3ee; --card:#ffffff; --ink:#252a30; --muted:#7a7f86;
  --line:#e3ded4; --accent:#8a6a3a; --accent-soft:#f0e7d7;
  --stage:#1b2026; --shadow:0 2px 14px rgba(30,32,36,.07);
  --ok:#3f8f5b; --warn:#c9882f; --bad:#b0553f; --info:#5a7f9e;
}
*{box-sizing:border-box}
html,body{margin:0;padding:0}
body{background:var(--paper);color:var(--ink);
  font-family:"Segoe UI","Microsoft YaHei","PingFang SC","Noto Sans SC",sans-serif;
  font-size:14px;line-height:1.6;-webkit-font-smoothing:antialiased}
a{color:var(--accent);text-decoration:none}
a:hover{text-decoration:underline}
header{position:sticky;top:0;z-index:20;background:rgba(245,243,238,.97);
  backdrop-filter:blur(8px);border-bottom:1px solid var(--line);padding:16px 30px 12px}
.hrow{display:flex;align-items:flex-end;gap:18px;flex-wrap:wrap}
h1{font-size:21px;font-weight:600;margin:0;letter-spacing:.02em}
.sub{color:var(--muted);font-size:12.5px;margin-top:3px}
.search{margin-left:auto;min-width:250px}
.search input{width:100%;padding:9px 13px;border:1px solid var(--line);border-radius:7px;
  background:#fff;font-size:13px;color:var(--ink);outline:none}
.search input:focus{border-color:var(--accent);box-shadow:0 0 0 3px var(--accent-soft)}
.notice{margin-top:10px;font-size:12px;color:#7c6237;background:#fbf4e6;
  border:1px solid #ebdcbe;border-radius:6px;padding:6px 11px;display:inline-block}
.tabs{display:flex;gap:6px;margin-top:12px;flex-wrap:wrap}
.tab{padding:6px 14px;border-radius:20px;border:1px solid var(--line);background:#fff;
  cursor:pointer;font-size:12.5px;color:#4c525a;user-select:none}
.tab:hover{border-color:#cfc6b5}
.tab.on{background:var(--ink);color:#fff;border-color:var(--ink)}
.wrap{display:grid;grid-template-columns:224px 1fr;gap:28px;padding:24px 30px 60px;max-width:1720px;margin:0 auto}
aside{position:sticky;top:170px;align-self:start;max-height:calc(100vh - 190px);overflow:auto}
.sect{font-size:11px;letter-spacing:.14em;color:var(--muted);text-transform:uppercase;margin:0 0 8px}
.nav{list-style:none;margin:0 0 22px;padding:0}
.nav li{display:flex;justify-content:space-between;align-items:center;padding:6px 10px;
  border-radius:6px;cursor:pointer;color:#4c525a;font-size:13px}
.nav li:hover{background:#ece8df}
.nav li.on{background:var(--ink);color:#fff}
.nav li.on span{color:#cfc6b5}
.nav li span{color:var(--muted);font-size:11px;font-variant-numeric:tabular-nums}
.nav li.zero{color:#b3b8bd}
.chips{display:flex;flex-wrap:wrap;gap:6px;margin:0 0 22px}
.chip{font-size:11.5px;padding:4px 9px;border-radius:14px;border:1px solid var(--line);
  background:#fff;cursor:pointer;color:#5c626a}
.chip:hover{border-color:#cfc6b5}
.chip.on{background:var(--accent-soft);border-color:#d8c9ad;color:#6d5227;font-weight:600}
.side-note{margin-top:8px;border-top:1px solid var(--line);padding-top:12px;
  font-size:11.5px;color:var(--muted);line-height:1.9}
.bar{display:flex;align-items:baseline;gap:12px;margin:0 0 6px;flex-wrap:wrap}
.bar strong{font-size:16px;font-weight:600}
.bar em{font-style:normal;color:var(--muted);font-size:12px}
.hint{color:var(--muted);font-size:12px;margin:0 0 16px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(232px,1fr));gap:18px}
.card{background:var(--card);border:1px solid var(--line);border-radius:10px;overflow:hidden;
  box-shadow:var(--shadow);cursor:pointer;transition:transform .16s ease,box-shadow .16s ease;
  display:flex;flex-direction:column;position:relative}
.card:hover{transform:translateY(-3px);box-shadow:0 8px 24px rgba(30,32,36,.12)}
.card.archived{opacity:.72}
.stage{height:170px;flex:none;background:var(--stage);display:flex;align-items:center;justify-content:center;overflow:hidden;position:relative}
.stage img{width:100%;height:100%;object-fit:contain;display:block}
.stage .ph{color:#6c7480;font-size:12px}
.badge{position:absolute;left:8px;top:8px;font-size:10.5px;padding:2px 7px;border-radius:4px;
  background:rgba(0,0,0,.55);color:#fff;letter-spacing:.02em}
.meta{padding:10px 12px 12px;flex:1;display:flex;flex-direction:column}
.idline{display:flex;align-items:center;gap:6px;flex-wrap:wrap;margin-bottom:5px}
.pid{font-family:Consolas,"Courier New",monospace;font-size:11px;color:var(--accent);
  background:var(--accent-soft);padding:2px 6px;border-radius:4px}
.ver{font-size:11px;color:var(--muted);font-family:Consolas,monospace}
.pill{font-size:10.5px;padding:1px 7px;border-radius:20px;white-space:nowrap}
.name{font-size:13.5px;font-weight:600;margin:auto 0 3px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.small{font-size:11.5px;color:var(--muted);overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.markrow{display:flex;gap:4px;flex-wrap:wrap;margin-top:6px}
.mark{font-size:10px;padding:1px 6px;border-radius:3px;background:#f0eee8;color:#6c7278}
.mark.tech{background:#e4f0e8;color:#3f7a56}
.mark.use{background:#e6eef6;color:#4a6f8c}
.mark.vis{background:#fbf0dd;color:#a1731f}
.mark.arch{background:#eeeae4;color:#8a8272}
.empty{padding:60px 0;text-align:center;color:var(--muted);grid-column:1/-1}
/* 参考图专区 */
.refgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:16px}
.refcard{background:var(--card);border:1px solid var(--line);border-radius:10px;
  box-shadow:var(--shadow);overflow:hidden;display:flex;flex-direction:column}
.refhead{padding:12px 14px 8px;border-bottom:1px solid var(--line)}
.refhead h3{margin:0;font-size:14px}
.refhead p{margin:3px 0 0;font-size:11.5px;color:var(--muted)}
.refbody{padding:10px 12px 14px;display:flex;flex-direction:column;gap:10px}
.refitem{display:flex;gap:10px;align-items:center;cursor:pointer}
.refitem img{width:74px;height:74px;object-fit:contain;background:var(--stage);border-radius:6px;flex:none}
.refitem .t{font-size:12.5px;font-weight:600}
.refitem .s{font-size:11px;color:var(--muted);font-family:Consolas,monospace}
.reflack{font-size:11.5px;color:#a1731f;background:#fbf4e6;border:1px solid #ebdcbe;
  border-radius:6px;padding:6px 9px}
/* 缺口表 */
table.gaps{width:100%;border-collapse:collapse;font-size:12.5px;background:var(--card);
  border:1px solid var(--line);border-radius:10px;overflow:hidden}
table.gaps th,table.gaps td{text-align:left;padding:9px 12px;border-bottom:1px solid var(--line)}
table.gaps th{background:#f0eee8;font-size:11.5px;letter-spacing:.06em;color:#5c626a}
table.gaps td:first-child{font-weight:600}
/* 灯箱 */
#modal{position:fixed;inset:0;z-index:50;background:rgba(20,23,27,.88);display:none;
  align-items:center;justify-content:center;padding:24px}
#modal.show{display:flex}
.box{background:var(--card);border-radius:12px;max-width:1320px;width:100%;max-height:93vh;
  display:grid;grid-template-columns:minmax(0,1.4fr) minmax(330px,.9fr);overflow:hidden}
.viewer{background:var(--stage);display:flex;align-items:center;justify-content:center;
  min-height:430px;position:relative;flex-direction:column}
.viewer img,.viewer video{max-width:100%;max-height:82vh;object-fit:contain;display:block}
.viewer .ctrls{position:absolute;left:0;right:0;bottom:0;display:flex;gap:8px;align-items:center;
  justify-content:center;padding:8px;background:linear-gradient(transparent,rgba(0,0,0,.55));color:#dfe3e7;font-size:11.5px}
.viewer .ctrls button{background:rgba(255,255,255,.16);color:#fff;border:0;border-radius:5px;
  padding:3px 9px;cursor:pointer;font-size:11.5px}
.viewer .ctrls button:hover{background:rgba(255,255,255,.3)}
.navbtn{position:absolute;top:50%;transform:translateY(-50%);background:rgba(255,255,255,.14);
  color:#fff;border:0;width:36px;height:44px;cursor:pointer;font-size:20px;border-radius:6px;z-index:2}
.navbtn:hover{background:rgba(255,255,255,.28)}
#previmg{left:12px} #nextimg{right:12px}
.detail{padding:20px 22px;overflow:auto;max-height:93vh}
.detail h2{font-size:17px;margin:0 0 4px;padding-right:26px}
.detail .tagline{color:var(--muted);font-size:12px;margin-bottom:14px}
.close{float:right;background:none;border:0;font-size:22px;color:var(--muted);cursor:pointer;line-height:1}
.close:hover{color:var(--ink)}
dl{margin:0;display:grid;grid-template-columns:88px 1fr;gap:7px 12px;font-size:12.5px}
dt{color:var(--muted)}
dd{margin:0;word-break:break-word}
dd code{font-family:Consolas,monospace;font-size:11.5px;background:#f2efe8;padding:1px 5px;border-radius:4px}
.block{margin-top:16px;padding-top:12px;border-top:1px solid var(--line)}
.block h3{font-size:11px;letter-spacing:.12em;color:var(--muted);margin:0 0 8px;text-transform:uppercase}
.block p{margin:0 0 8px;font-size:12.5px;color:#454b52}
.filelist{list-style:none;margin:0;padding:0;font-size:12.5px}
.filelist li{margin-bottom:5px;word-break:break-all}
.warn{background:#fbf4e6;border:1px solid #ebdcbe;color:#7c6237;
  padding:8px 10px;border-radius:6px;font-size:12px;margin-top:12px}
.vlist{display:flex;gap:8px;flex-wrap:wrap}
.vitem{border:1px solid var(--line);border-radius:7px;padding:4px;width:88px;cursor:pointer;background:#fff}
.vitem:hover{border-color:var(--accent)}
.vitem.cur{border-color:var(--accent);box-shadow:0 0 0 2px var(--accent-soft)}
.vitem img{width:100%;height:56px;object-fit:contain;background:var(--stage);border-radius:4px;display:block}
.vitem .v1{font-size:10.5px;font-family:Consolas,monospace;color:var(--accent);margin-top:3px;text-align:center}
.vitem .v2{font-size:9.5px;color:var(--muted);text-align:center;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
footer{padding:0 30px 40px;color:var(--muted);font-size:11.5px;max-width:1720px;margin:0 auto}
@media(max-width:980px){.wrap{grid-template-columns:1fr}aside{position:static;max-height:none}
  .box{grid-template-columns:1fr}.viewer{min-height:260px}}
</style>
</head>
<body>
<header>
  <div class="hrow">
    <div><h1>寒潮清单 · 美术设定库</h1>
      <div class="sub">ARTLIB-001 / CLEAN-001　|　第一季　|　离线预览　|　数据内嵌，无需服务与网络</div></div>
    <div class="search"><input id="q" type="search" placeholder="搜索素材 ID / 名称 / 动作 / 说明 / 角色…" autocomplete="off"></div>
  </div>
  <div class="notice">本库仅供浏览与审核，已被 <code>.gdignore</code> 隔离，不是 Godot 运行时资源。
    「技术通过」不等于「美术满意」——三条状态轴分开看。</div>
  <div class="tabs" id="tabs"></div>
</header>
<div class="wrap">
  <aside>
    <p class="sect">分类</p><ul class="nav" id="nav"></ul>
    <p class="sect">角色动作</p><ul class="nav" id="actnav"></ul>
    <p class="sect">状态标记（可多选）</p><div class="chips" id="chips"></div>
    <div class="side-note">台账：<a href="素材台账.csv">素材台账.csv</a><br>
      ID 登记：<a href="ID登记表.md">ID登记表.md</a><br>
      ID 对照：<a href="ID对照表.md">ID对照表.md</a><br>
      命名与规则：<a href="README.md">README.md</a><br>
      动画约定：<a href="美术设定集/05-特效与动画/动画素材记录规范.md">动画素材记录规范.md</a><br><br>
      重建本页：<code>python tools/build_artlib.py</code><br>
      完整性审计：<code>python tools/audit_artlib.py</code></div>
  </aside>
  <main>
    <div class="bar"><strong id="title">全部素材</strong><em id="count"></em></div>
    <p class="hint" id="hint"></p>
    <div id="view"></div>
  </main>
</div>
<footer>《寒潮清单》美术设定库 · 数据与缩略图均为本地相对路径 · 页面由 tools/build_artlib.py 生成，请勿直接手工编辑</footer>
<div id="modal" role="dialog" aria-modal="true"><div class="box">
  <div class="viewer">
    <button class="navbtn" id="previmg" title="上一个">‹</button>
    <img id="big" alt="">
    <video id="bigvid" controls style="display:none"></video>
    <div class="ctrls" id="ctrls" style="display:none">
      <button id="play">▶ 播放序列</button><span id="fpslab"></span><span id="flab"></span>
    </div>
    <button class="navbtn" id="nextimg" title="下一个">›</button>
  </div>
  <div class="detail"><button class="close" id="close" title="关闭">×</button><div id="detail"></div></div>
</div></div>
<script id="asset-data" type="application/json">__DATA__</script>
<script id="meta-data" type="application/json">__META__</script>
<script>
(function(){
  var DATA=JSON.parse(document.getElementById('asset-data').textContent);
  var META=JSON.parse(document.getElementById('meta-data').textContent);
  var CATS=META.cats, STATES=META.states, ACTS=META.acts, TAGS=META.tags, REPS=META.refs, GAPS=META.gaps;
  var COLORS={'概念草案':'#9aa3ad','待审核':'#c99a45','已通过设定审核':'#5b8f77',
    '正式素材制作中':'#5a83ad','运行时可用':'#3f8f5b','不予通过':'#b0553f','已弃用':'#b06a6a'};
  var VIS={'认可':'#3f8f5b','待优化':'#c9882f','未评价':'#8a8f96','不适用':'#b3b8bd'};
  var state={view:'assets',cat:'全部',act:'全部',tags:[],q:''};
  var shown=[], idx=0, timer=null, frameIdx=0;
  var $=function(id){return document.getElementById(id)};
  function esc(s){return String(s==null?'':s).replace(/[&<>"']/g,function(c){
    return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]})}
  function pill(s){var c=COLORS[s]||'#8a8f96';
    return '<span class="pill" style="color:'+c+';background:'+c+'22">'+esc(s)+'</span>'}
  function vpill(v){if(!v||v==='不适用')return '<span class="pill" style="color:#b3b8bd;background:#b3b8bd1a">'+esc(v||'—')+'</span>';
    var c=VIS[v]||'#8a8f96';
    return '<span class="pill" style="color:'+c+';background:'+c+'22">'+esc(v)+'</span>'}

  /* ------------------------------------------------ 顶部视图 tabs */
  function tabs(){
    var vs=[['assets','素材'],['refs','AI 视频参考图'],['gaps','动作缺口']];
    $('tabs').innerHTML=vs.map(function(v){
      return '<div class="tab '+(state.view===v[0]?'on':'')+'" data-v="'+v[0]+'">'+v[1]+'</div>'}).join('');
    Array.prototype.forEach.call($('tabs').children,function(el){
      el.onclick=function(){state.view=el.dataset.v;tabs();render()}});
  }
  /* ------------------------------------------------ 左侧导航 */
  function nav(){
    var counts={}; DATA.forEach(function(d){counts[d.cat]=(counts[d.cat]||0)+1});
    var items=['全部'].concat(CATS);
    $('nav').innerHTML=items.map(function(c){var n=c==='全部'?DATA.length:(counts[c]||0);
      return '<li class="'+(state.cat===c?'on':'')+(n?'':' zero')+'" data-c="'+esc(c)+'">'+
        esc(c)+'<span>'+n+'</span></li>'}).join('');
    Array.prototype.forEach.call($('nav').children,function(li){
      li.onclick=function(){state.cat=li.dataset.c;state.view='assets';tabs();nav();render()}});
  }
  function actnav(){
    var counts={}; DATA.forEach(function(d){if(d.act)counts[d.act]=(counts[d.act]||0)+1});
    var items=['全部'].concat(ACTS);
    $('actnav').innerHTML=items.map(function(a){var n=a==='全部'
        ? DATA.filter(function(d){return d.cat==='角色'}).length : (counts[a]||0);
      return '<li class="'+(state.act===a?'on':'')+(n?'':' zero')+'" data-a="'+esc(a)+'">'+
        esc(a)+'<span>'+n+'</span></li>'}).join('');
    Array.prototype.forEach.call($('actnav').children,function(li){
      li.onclick=function(){state.act=li.dataset.a;state.cat='角色';state.view='assets';tabs();nav();actnav();render()}});
  }
  function chips(){
    $('chips').innerHTML=TAGS.map(function(t){
      var n=DATA.filter(function(d){return d.tags.indexOf(t.name)>=0}).length;
      return '<span class="chip '+(state.tags.indexOf(t.name)>=0?'on':'')+'" data-t="'+esc(t.name)+
        '" title="'+esc(t.desc)+'">'+esc(t.name)+' '+n+'</span>'}).join('');
    Array.prototype.forEach.call($('chips').children,function(el){
      el.onclick=function(){var t=el.dataset.t,i=state.tags.indexOf(t);
        if(i>=0)state.tags.splice(i,1);else state.tags.push(t);chips();render()}});
  }

  /* ------------------------------------------------ 过滤 */
  function match(d){
    if(state.cat!=='全部'&&d.cat!==state.cat)return false;
    if(state.act!=='全部'&&d.act!==state.act)return false;
    for(var i=0;i<state.tags.length;i++){if(d.tags.indexOf(state.tags[i])<0)return false}
    var q=state.q.trim().toLowerCase();
    if(!q)return true;
    return [d.id,d.name,d.cat,d.subject,d.version,d.source,d.usage,d.status,d.notes,
      d.act,d.visual,d.useState].join(' ').toLowerCase().indexOf(q)>=0;
  }

  /* ------------------------------------------------ 卡片 */
  function cardHtml(d,i){
    var marks='';
    if(d.tags.indexOf('当前游戏使用中')>=0)marks+='<span class="mark use">在用</span>';
    if(d.tags.indexOf('已通过技术验收')>=0)marks+='<span class="mark tech">技术通过</span>';
    if(d.tags.indexOf('视觉质量待优化')>=0)marks+='<span class="mark vis">视觉待优化</span>';
    if(d.archived==='是')marks+='<span class="mark arch">归档</span>';
    var badge=d.frameHrefs.length>1?('<span class="badge">'+d.frameHrefs.length+' 帧</span>'):
      (d.act&&d.act!=='不适用'?'<span class="badge">'+esc(d.act)+'</span>':'');
    return '<article class="card'+(d.archived==='是'?' archived':'')+'" data-i="'+i+'">'+
      '<div class="stage">'+badge+
      (d.thumb?'<img src="'+esc(d.thumb)+'" alt="'+esc(d.name)+'" loading="lazy">'
              :'<span class="ph">暂无预览图</span>')+'</div>'+
      '<div class="meta"><div class="idline"><span class="pid">'+esc(d.id)+'</span>'+
      '<span class="ver">'+esc(d.version)+'</span>'+pill(d.status)+'</div>'+
      '<p class="name" title="'+esc(d.name)+'">'+esc(d.name)+'</p>'+
      '<div class="small">'+esc(d.cat)+'　·　'+esc(d.subject)+'</div>'+
      (marks?'<div class="markrow">'+marks+'</div>':'')+
      '</div></article>';
  }
  function renderAssets(){
    shown=DATA.filter(match);
    $('title').textContent=(state.cat==='全部'?'全部素材':state.cat)+
      (state.act!=='全部'?' · '+state.act:'');
    $('count').textContent='共 '+shown.length+' 项'+(state.q?'（已筛选）':'')+
      '　·　素材库不参与游戏运行';
    $('hint').textContent=state.tags.length
      ? '已叠加标记筛选：'+state.tags.join(' + ')+'（同一行可同时命中多个标记）'
      : '三条轴分开看：技术状态（能否上机）/ 视觉评价（美术满不满意）/ 使用状态（游戏里有没有在用）。';
    $('view').innerHTML='<div class="grid" id="grid">'+(shown.length?shown.map(cardHtml).join('')
      :'<div class="empty">没有匹配的素材。换个关键词，或清空筛选。</div>')+'</div>';
    Array.prototype.forEach.call(document.querySelectorAll('#grid .card'),function(el){
      el.onclick=function(){open(+el.dataset.i)}});
  }

  /* ------------------------------------------------ 参考图专区 */
  function renderRefs(){
    $('title').textContent='AI 视频参考图';
    $('count').textContent='按动作聚合已登记素材　·　本区只选图，不生成任何视频';
    $('hint').textContent='用户从 ChatGPT 拿到参考图与提示词，自己生成视频，再把视频交给开发 Agent。'
      +'这里列出的每一张都是已登记素材，不拿无关图凑数。';
    var html=REPS.map(function(r){
      var items=r.ids.map(function(id){return DATA.filter(function(d){return d.key===id})[0]})
        .filter(Boolean);
      var body=items.map(function(d,i){
        return '<div class="refitem" data-k="'+esc(d.key)+'"><img src="'+esc(d.thumb||'')+'" alt="'+
          esc(d.name)+'"><div><div class="t">'+esc(d.name)+'</div><div class="s">'+esc(d.id)+'@'+
          esc(d.version)+'</div></div></div>'}).join('');
      var lack=r.missing.length?'<div class="reflack">还缺参考图：'+r.missing.map(esc).join('、')+'</div>':'';
      return '<div class="refcard"><div class="refhead"><h3>'+esc(r.act)+'　<code>'+
        esc(r.slug)+'</code></h3><p>'+esc(r.desc)+'</p></div><div class="refbody">'+body+lack+'</div></div>';
    }).join('');
    $('view').innerHTML='<div class="refgrid">'+html+'</div>';
    Array.prototype.forEach.call(document.querySelectorAll('.refitem'),function(el){
      el.onclick=function(){var k=el.dataset.k;var i=DATA.findIndex(function(d){return d.key===k});
        if(i>=0){shown=DATA;idx=i;showModal(DATA[i])}}});
  }

  /* ------------------------------------------------ 动作缺口 */
  function renderGaps(){
    $('title').textContent='动作缺口';
    $('count').textContent='已确认但尚未交付的动作　·　'+GAPS.length+' 项';
    $('hint').textContent='这些是开发与美术双方都认账的缺口，不是遗漏。收到对应视频后再逐项消掉。';
    $('view').innerHTML='<table class="gaps"><thead><tr><th>动作</th><th>说明</th>'+
      '<th>归属素材</th><th>状态</th></tr></thead><tbody>'+
      GAPS.map(function(g){return '<tr><td>'+esc(g[0])+'</td><td>'+esc(g[1])+'</td><td><code>'+
        esc(g[2])+'</code></td><td>'+esc(g[3])+'</td></tr>'}).join('')+'</tbody></table>';
  }

  function render(){
    if(state.view==='refs'){renderRefs();return}
    if(state.view==='gaps'){renderGaps();return}
    renderAssets();
  }

  /* ------------------------------------------------ 灯箱 */
  function detail(d){
    var a=d.anim||{};
    var rows=[
      ['素材 ID','<code>'+esc(d.id)+'</code>'],['版本','<code>'+esc(d.version)+'</code>'],
      ['分类',esc(d.cat)],['对应角色/场景',esc(d.subject)],
      ['动作分组',esc(d.act||'—')],
      ['制作状态',esc(d.makeStatus)],['审核状态',pill(d.status)],
      ['视觉评价',vpill(d.visual)],['使用状态',esc(d.useState||'—')],
      ['来源',esc(d.source)],['用途',esc(d.usage)]
    ];
    var html='<h2>'+esc(d.name)+'</h2><div class="tagline">'+esc(d.id)+' · '+esc(d.version)+
      ' · '+esc(d.cat)+'</div><dl>'+
      rows.map(function(r){return '<dt>'+r[0]+'</dt><dd>'+r[1]+'</dd>'}).join('')+'</dl>';

    if(d.siblings&&d.siblings.length>1){
      html+='<div class="block"><h3>版本对照（同 ID 全部版本）</h3><div class="vlist">'+
        d.siblings.map(function(s){
          return '<div class="vitem'+(s.key===d.key?' cur':'')+'" data-k="'+esc(s.key)+'">'+
            (s.thumb?'<img src="'+esc(s.thumb)+'" alt="">':'<img alt="">')+
            '<div class="v1">'+esc(s.version)+'</div><div class="v2" title="'+esc(s.status)+'">'+
            esc(s.status)+'</div></div>'}).join('')+'</div></div>';
    }

    html+='<div class="block"><h3>版权 / 授权</h3><p>'+esc(d.license)+'</p></div>';
    html+='<div class="block"><h3>制作与修改说明</h3><p>'+esc(d.notes)+'</p></div>';

    var files='<li>库内副本：'+(d.localHref?'<a href="'+esc(d.localHref)+'" target="_blank">'+
        esc(d.localPath)+'</a>':'（无）')+'</li>'+
      '<li>原始来源：'+(d.originHref?'<a href="'+esc(d.originHref)+'" target="_blank">'+
        esc(d.originPath)+'</a>':esc(d.originPath||'（无）'))+'</li>'+
      '<li>运行时资源：'+(d.runtimePath?('<code>'+esc(d.runtimePath)+'</code>'+
        (d.runtimeHref?'　<a href="'+esc(d.runtimeHref)+'" target="_blank">打开</a>':'')):'未登记')+'</li>';
    if(a.preview)files+='<li>预览文件：'+(a.previewHref?'<a href="'+esc(a.previewHref)+
        '" target="_blank">'+esc(a.preview)+'</a>':esc(a.preview))+'</li>';
    if(d.gif)files+='<li>序列 GIF：<a href="'+esc(d.gif)+'" target="_blank">'+esc(d.gif)+'</a></li>';
    if(d.frameHrefs&&d.frameHrefs.length)files+='<li>帧序列：'+esc(d.frameGlob)+'（'+
      d.frameHrefs.length+' 帧，<a href="'+esc(d.frameHrefs[0])+'" target="_blank">打开第 1 帧</a>）</li>';
    html+='<div class="block"><h3>文件</h3><ul class="filelist">'+files+'</ul></div>';

    if(d.related.length){
      html+='<div class="block"><h3>相关文件</h3><ul class="filelist">'+d.related.map(function(f){
        return '<li><a href="'+esc(f.href)+'" target="_blank">'+esc(f.label)+'</a></li>'}).join('')+'</ul></div>';
    }
    var animRows=[['帧数',a.frames],['帧率 FPS',a.fps],['尺寸',a.size],['方向',a.facing],
      ['预览',a.preview],['精灵图',a.sheet]];
    var hasAnim=animRows.some(function(r){return r[1]});
    if(hasAnim){
      html+='<div class="block"><h3>动画记录</h3><dl style="grid-template-columns:88px 1fr">'+
        animRows.map(function(r){return '<dt>'+r[0]+'</dt><dd>'+esc(r[1]||'—')+'</dd>'}).join('')+'</dl></div>';
    }else{
      html+='<div class="block"><h3>动画记录</h3><p>未登记动画；本条目不是可运行角色动画。</p></div>';
    }
    if(d.tags.indexOf('视觉质量待优化')>=0)
      html+='<div class="warn">视觉质量待优化：技术验收已通过、游戏里也在用，但美术质量未获认可，'
        +'需要重新制作。不要因为「能跑」就当成完成。</div>';
    if(d.status!=='运行时可用')
      html+='<div class="warn">当前状态「'+esc(d.status)+'」：不得作为正式运行时资源引用。</div>';
    return html;
  }

  function stopPlay(){if(timer){clearInterval(timer);timer=null}$('play').textContent='▶ 播放序列'}

  function showModal(d){
    stopPlay();
    var vid=$('bigvid'), img=$('big');
    var prev=(d.anim&&d.anim.preview)||'';
    if(/\.(mp4|webm)$/i.test(prev)){
      img.style.display='none'; vid.style.display='block';
      vid.src=d.anim.previewHref; img.removeAttribute('src');
    }else{
      vid.style.display='none'; vid.removeAttribute('src');
      img.style.display='block';
      img.src=d.localHref||d.thumb; img.alt=d.name;
    }
    $('ctrls').style.display=(d.frameHrefs&&d.frameHrefs.length>1)?'flex':'none';
    $('fpslab').textContent=(d.anim&&d.anim.fps)?('· '+d.anim.fps+' FPS'):'';
    $('flab').textContent=(d.frameHrefs&&d.frameHrefs.length)?('· '+d.frameHrefs.length+' 帧'):'';
    frameIdx=0;
    if(d.frameHrefs&&d.frameHrefs.length>1){img.src=d.frameHrefs[0]}
    $('detail').innerHTML=detail(d);
    Array.prototype.forEach.call(document.querySelectorAll('.vitem'),function(el){
      el.onclick=function(){var k=el.dataset.k;var s=DATA.filter(function(x){return x.key===k})[0];
        if(s){idx=shown.indexOf(s)>=0?shown.indexOf(s):idx;showModal(s)}}});
    $('modal').classList.add('show');document.body.style.overflow='hidden';
  }
  function open(i){
    idx=i;var d=shown[idx];if(!d)return;showModal(d);
  }
  function close(){$('modal').classList.remove('show');document.body.style.overflow='';
    $('big').src='';stopPlay()}
  function step(n){if(!shown.length)return;open((idx+n+shown.length)%shown.length)}
  $('close').onclick=close;
  $('previmg').onclick=function(){step(-1)};
  $('nextimg').onclick=function(){step(1)};
  $('modal').onclick=function(e){if(e.target===$('modal'))close()};
  $('q').oninput=function(e){state.q=e.target.value;render()};
  $('play').onclick=function(){
    var d=shown[idx];if(!d||!d.frameHrefs||d.frameHrefs.length<2)return;
    if(timer){stopPlay();return}
    $('play').textContent='⏸ 暂停';
    var i=0, fps=(d.fpsNum||10);
    timer=setInterval(function(){i=(i+1)%d.frameHrefs.length;$('big').src=d.frameHrefs[i]},
      Math.max(40,Math.round(1000/fps)));
  };
  document.addEventListener('keydown',function(e){
    if(!$('modal').classList.contains('show'))return;
    if(e.key==='Escape')close();else if(e.key==='ArrowLeft')step(-1);else if(e.key==='ArrowRight')step(1);
  });
  tabs();nav();actnav();chips();render();
})();
</script>
</body></html>
"""


def build_ref_panels(data: list[dict]) -> list[dict]:
    """把 REF_ACTIONS 与台账里的 参考用途 对齐，顺带报出缺哪些图。"""
    out = []
    for act, slug, desc, want_ids in REF_ACTIONS:
        keys = [d["key"] for d in data if act in d["refFor"]]
        missing = [wid for wid in want_ids
                   if not any(k.startswith(wid + "@") for k in keys)]
        out.append({"act": act, "slug": slug, "desc": desc, "ids": keys, "missing": missing})
    return out


def main() -> None:
    data = build_data()
    build_revised_ledger()
    meta = {
        "cats": CATEGORIES,
        "states": STATUSES,
        "acts": ACT_GROUPS,
        "tags": [{"name": n, "desc": d} for n, d in MARK_TAGS],
        "refs": build_ref_panels(data),
        "gaps": ACTION_GAPS,
    }
    payload = json.dumps(data, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
    meta_payload = json.dumps(meta, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
    html = (HTML_TEMPLATE
            .replace("__DATA__", payload)
            .replace("__META__", meta_payload)
            .replace("__CATS__", json.dumps(CATEGORIES, ensure_ascii=False))
            .replace("__STATES__", json.dumps(STATUSES, ensure_ascii=False)))
    HTML_PATH.write_text(html, encoding="utf-8")

    n_gif = sum(1 for d in data if d["gif"])
    n_frames = sum(len(d["frameHrefs"]) for d in data)
    print(f"资产 {len(data)} 条，缩略图 {sum(1 for d in data if d['thumb'])} 张，"
          f"序列帧 {n_frames} 张 / GIF {n_gif} 个")
    for r in meta["refs"]:
        flag = f"（缺 {', '.join(r['missing'])}）" if r["missing"] else ""
        print(f"  参考图 {r['act']}：{len(r['ids'])} 张 {flag}")
    print(f"预览页：{HTML_PATH}  ({HTML_PATH.stat().st_size:,} 字节)")
    print(f"ID 修订版：{REVISED_PATH}")


if __name__ == "__main__":
    main()
