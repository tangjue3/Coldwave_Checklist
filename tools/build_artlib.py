"""ARTLIB-001 素材库索引生成器。

用法（在工程根目录）：python tools/build_artlib.py

做三件事：
1. 读 素材库/素材台账.csv，为有图片的行生成 .thumbs/ 下的缩略图；
2. 用同一份 ID 映射重新生成「美术资产台账_ARTLIB-001修订版.md」；
3. 把台账数据内嵌进 素材库/美术总览.html，生成完全离线、可 file:// 双击打开的预览页。

不依赖 Web 服务、不联网、不修改任何原始图片。可重复运行。
"""
from __future__ import annotations

import csv
import json
import re
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "素材库"
THUMBS = LIB / ".thumbs"
CSV_PATH = LIB / "素材台账.csv"
HTML_PATH = LIB / "美术总览.html"
REVISED_PATH = LIB / "美术设定集" / "00-美术总览" / "美术资产台账_ARTLIB-001修订版.md"
V11_LEDGER = ROOT / "docs" / "handover_v1.1" / "05_美术资产生产台账与风格规范_v1.1.md"

THUMB_BOX = (480, 360)
THUMB_BG = (27, 32, 38)

CATEGORIES = ["角色", "场景", "物品与家具", "界面", "特效与动画", "世界观与剧情"]
STATUSES = ["概念草案", "待审核", "已通过设定审核", "正式素材制作中", "运行时可用", "已弃用"]

# v1.1 美术台账旧 ID → 新 ART_* ID（唯一来源，同时用于生成修订版文档）
CHAR = {"01": "ART_CHAR_001", "02": "ART_CHAR_101", "03": "ART_CHAR_102",
        "04": "ART_CHAR_002", "05": "ART_CHAR_002", "06": "ART_CHAR_002",
        "07": "ART_CHAR_002", "08": "ART_CHAR_106", "09": "ART_CHAR_107",
        "10": "ART_CHAR_108"}
SCENE = {"01": "ART_SCENE_001", "02": "ART_SCENE_001", "03": "ART_SCENE_102",
         "04": "ART_SCENE_103", "05": "ART_SCENE_104", "06": "ART_SCENE_105",
         "07": "ART_SCENE_106", "08": "ART_SCENE_107", "09": "ART_SCENE_108",
         "10": "ART_SCENE_109", "11": "ART_SCENE_110"}
ID_TABLES = [("C", CHAR), ("S", SCENE), ("I", {"01": "ART_ITEM_001", "02": "ART_ITEM_101"}),
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


def build_revised_ledger() -> None:
    text = V11_LEDGER.read_text(encoding="utf-8")
    for prefix, table in ID_TABLES:
        pattern = re.compile(r"(?<![A-Za-z0-9_\-])" + prefix + r"(\d{2})(?![A-Za-z0-9_\-])")
        text = pattern.sub(lambda m: table.get(m.group(1), prefix + m.group(1)), text)
    REVISED_PATH.write_text(REVISED_HEADER + text, encoding="utf-8")


def read_rows() -> list[dict]:
    with CSV_PATH.open(encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def build_data() -> list[dict]:
    THUMBS.mkdir(parents=True, exist_ok=True)
    out = []
    for r in read_rows():
        rel = (r.get("库内文件路径") or "").strip()
        src = LIB / rel if rel else None
        thumb_file = f"{r['素材ID']}_{r['当前版本']}.jpg"
        has_thumb = make_thumb(src, THUMBS / thumb_file) if src else False
        related = []
        for item in (r.get("相关文件") or "").split("|"):
            item = item.strip()
            if item:
                related.append({"label": Path(item).name, "href": repo_link(item)})
        out.append({
            "id": r["素材ID"],
            "name": r["名称"],
            "cat": r["所属分类"],
            "subject": r["对应角色或场景"],
            "version": r["当前版本"],
            "source": r["来源"],
            "usage": r["用途"],
            "makeStatus": r["制作状态"],
            "status": r["审核状态"],
            "license": r["版权或授权备注"],
            "originPath": r["原始文件路径"],
            "originHref": repo_link(r["原始文件路径"]),
            "localPath": rel,
            "localHref": rel,
            "runtimePath": r["对应运行时资源路径"],
            "notes": r["制作与修改说明"],
            "related": related,
            "anim": {
                "frames": r["动画帧数"],
                "fps": r["帧率FPS"],
                "size": r["尺寸"],
                "facing": r["方向"],
                "preview": r["预览文件"],
                "sheet": r["精灵图文件"],
            },
            "thumb": f".thumbs/{thumb_file}" if has_thumb else "",
        })
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
}
*{box-sizing:border-box}
html,body{margin:0;padding:0}
body{background:var(--paper);color:var(--ink);
  font-family:"Segoe UI","Microsoft YaHei","PingFang SC","Noto Sans SC",sans-serif;
  font-size:14px;line-height:1.6;-webkit-font-smoothing:antialiased}
a{color:var(--accent);text-decoration:none}
a:hover{text-decoration:underline}
header{position:sticky;top:0;z-index:20;background:rgba(245,243,238,.96);
  backdrop-filter:blur(8px);border-bottom:1px solid var(--line);padding:18px 30px 14px}
.hrow{display:flex;align-items:flex-end;gap:18px;flex-wrap:wrap}
h1{font-size:21px;font-weight:600;margin:0;letter-spacing:.02em}
.sub{color:var(--muted);font-size:12.5px;margin-top:3px}
.search{margin-left:auto;min-width:230px}
.search input{width:100%;padding:9px 13px;border:1px solid var(--line);border-radius:7px;
  background:#fff;font-size:13px;color:var(--ink);outline:none}
.search input:focus{border-color:var(--accent);box-shadow:0 0 0 3px var(--accent-soft)}
.notice{margin-top:11px;font-size:12px;color:#7c6237;background:#fbf4e6;
  border:1px solid #ebdcbe;border-radius:6px;padding:7px 12px;display:inline-block}
.wrap{display:grid;grid-template-columns:216px 1fr;gap:28px;padding:26px 30px 60px;max-width:1680px;margin:0 auto}
aside{position:sticky;top:118px;align-self:start}
.sect{font-size:11px;letter-spacing:.14em;color:var(--muted);text-transform:uppercase;margin:0 0 9px}
.nav{list-style:none;margin:0 0 26px;padding:0}
.nav li{display:flex;justify-content:space-between;align-items:center;padding:7px 10px;
  border-radius:6px;cursor:pointer;color:#4c525a;font-size:13px}
.nav li:hover{background:#ece8df}
.nav li.on{background:var(--ink);color:#fff}
.nav li.on span{color:#cfc6b5}
.nav li span{color:var(--muted);font-size:11px;font-variant-numeric:tabular-nums}
.legend{display:flex;flex-direction:column;gap:6px;font-size:12px;color:#5c626a}
.legend div{display:flex;align-items:center;gap:8px}
.dot{width:8px;height:8px;border-radius:50%;flex:none}
.side-note{margin-top:26px;border-top:1px solid var(--line);padding-top:14px;
  font-size:11.5px;color:var(--muted);line-height:1.75}
.bar{display:flex;align-items:baseline;gap:12px;margin:0 0 16px}
.bar strong{font-size:16px;font-weight:600}
.bar em{font-style:normal;color:var(--muted);font-size:12px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(232px,1fr));gap:18px}
.card{background:var(--card);border:1px solid var(--line);border-radius:10px;overflow:hidden;
  box-shadow:var(--shadow);cursor:pointer;transition:transform .16s ease,box-shadow .16s ease}
.card:hover{transform:translateY(-3px);box-shadow:0 8px 24px rgba(30,32,36,.12)}
.stage{height:176px;background:var(--stage);display:flex;align-items:center;justify-content:center;overflow:hidden}
.stage img{width:100%;height:100%;object-fit:contain;display:block}
.stage .ph{color:#6c7480;font-size:12px}
.meta{padding:11px 13px 13px}
.idline{display:flex;align-items:center;gap:7px;flex-wrap:wrap;margin-bottom:6px}
.pid{font-family:Consolas,"Courier New",monospace;font-size:11px;color:var(--accent);
  background:var(--accent-soft);padding:2px 6px;border-radius:4px}
.ver{font-size:11px;color:var(--muted);font-family:Consolas,monospace}
.pill{margin-left:auto;font-size:10.5px;padding:2px 8px;border-radius:20px;white-space:nowrap}
.name{font-size:14px;font-weight:600;margin:0 0 3px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.small{font-size:11.5px;color:var(--muted);overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.empty{padding:60px 0;text-align:center;color:var(--muted);grid-column:1/-1}
#modal{position:fixed;inset:0;z-index:50;background:rgba(20,23,27,.86);display:none;
  align-items:center;justify-content:center;padding:26px}
#modal.show{display:flex}
.box{background:var(--card);border-radius:12px;max-width:1240px;width:100%;max-height:92vh;
  display:grid;grid-template-columns:minmax(0,1.45fr) minmax(300px,.85fr);overflow:hidden}
.viewer{background:var(--stage);display:flex;align-items:center;justify-content:center;min-height:420px;position:relative}
.viewer img{max-width:100%;max-height:88vh;object-fit:contain;display:block}
.navbtn{position:absolute;top:50%;transform:translateY(-50%);background:rgba(255,255,255,.14);
  color:#fff;border:0;width:36px;height:44px;cursor:pointer;font-size:20px;border-radius:6px}
.navbtn:hover{background:rgba(255,255,255,.28)}
#prev{left:12px} #next{right:12px}
.detail{padding:22px 24px;overflow:auto;max-height:92vh}
.detail h2{font-size:18px;margin:0 0 4px}
.detail .tagline{color:var(--muted);font-size:12px;margin-bottom:16px}
.close{float:right;background:none;border:0;font-size:22px;color:var(--muted);cursor:pointer;line-height:1}
.close:hover{color:var(--ink)}
dl{margin:0;display:grid;grid-template-columns:88px 1fr;gap:8px 12px;font-size:12.5px}
dt{color:var(--muted)}
dd{margin:0;word-break:break-word}
dd code{font-family:Consolas,monospace;font-size:11.5px;background:#f2efe8;padding:1px 5px;border-radius:4px}
.block{margin-top:18px;padding-top:14px;border-top:1px solid var(--line)}
.block h3{font-size:11px;letter-spacing:.12em;color:var(--muted);margin:0 0 8px;text-transform:uppercase}
.block p{margin:0 0 8px;font-size:12.5px;color:#454b52}
.filelist{list-style:none;margin:0;padding:0;font-size:12.5px}
.filelist li{margin-bottom:5px;word-break:break-all}
.warn{background:#fbf4e6;border:1px solid #ebdcbe;color:#7c6237;
  padding:8px 10px;border-radius:6px;font-size:12px;margin-top:14px}
footer{padding:0 30px 40px;color:var(--muted);font-size:11.5px;max-width:1680px;margin:0 auto}
@media(max-width:900px){.wrap{grid-template-columns:1fr}aside{position:static}.box{grid-template-columns:1fr}.viewer{min-height:260px}}
</style>
</head>
<body>
<header>
  <div class="hrow">
    <div><h1>寒潮清单 · 美术设定库</h1><div class="sub">ARTLIB-001　|　第一季　|　离线预览　|　数据内嵌，无需服务与网络</div></div>
    <div class="search"><input id="q" type="search" placeholder="搜索素材 ID / 名称 / 说明 / 角色…" autocomplete="off"></div>
  </div>
  <div class="notice">本库仅供浏览与审核，已被 <code>.gdignore</code> 隔离，不是 Godot 运行时资源。概念图未获批准不得进入游戏。</div>
</header>
<div class="wrap">
  <aside>
    <p class="sect">分类</p><ul class="nav" id="nav"></ul>
    <p class="sect">审核状态</p><div class="legend" id="legend"></div>
    <div class="side-note">台账：<a href="素材台账.csv">素材台账.csv</a><br>
      ID 对照：<a href="ID对照表.md">ID对照表.md</a><br>
      命名与规则：<a href="README.md">README.md</a><br>
      动画约定：<a href="美术设定集/05-特效与动画/动画素材记录规范.md">动画素材记录规范.md</a><br><br>
      用 <code>python tools/build_artlib.py</code> 可在新增素材后重建本页。</div>
  </aside>
  <main>
    <div class="bar"><strong id="title">全部素材</strong><em id="count"></em></div>
    <div class="grid" id="grid"></div>
  </main>
</div>
<footer>《寒潮清单》美术设定库 · 数据与缩略图均为本地相对路径 · 页面由 tools/build_artlib.py 生成，请勿直接手工编辑</footer>
<div id="modal" role="dialog" aria-modal="true"><div class="box">
  <div class="viewer"><button class="navbtn" id="prev" title="上一个">‹</button><img id="big" alt=""><button class="navbtn" id="next" title="下一个">›</button></div>
  <div class="detail"><button class="close" id="close" title="关闭">×</button><div id="detail"></div></div>
</div></div>
<script id="asset-data" type="application/json">__DATA__</script>
<script>
(function(){
  var DATA=JSON.parse(document.getElementById('asset-data').textContent);
  var CATS=__CATS__, STATES=__STATES__;
  var COLORS={'概念草案':'#9aa3ad','待审核':'#c99a45','已通过设定审核':'#5b8f77','正式素材制作中':'#5a83ad','运行时可用':'#3f8f5b','已弃用':'#b06a6a'};
  var state={cat:'全部',q:''}, shown=[], idx=0;
  var $=function(id){return document.getElementById(id)};
  function esc(s){return String(s==null?'':s).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]})}
  function pill(s){var c=COLORS[s]||'#8a8f96';return '<span class="pill" style="color:'+c+';background:'+c+'22">'+esc(s)+'</span>'}
  function nav(){
    var counts={}; DATA.forEach(function(d){counts[d.cat]=(counts[d.cat]||0)+1});
    var items=['全部'].concat(CATS);
    $('nav').innerHTML=items.map(function(c){var n=c==='全部'?DATA.length:(counts[c]||0);
      return '<li class="'+(state.cat===c?'on':'')+'" data-c="'+esc(c)+'">'+esc(c)+'<span>'+n+'</span></li>'}).join('');
    Array.prototype.forEach.call($('nav').children,function(li){li.onclick=function(){state.cat=li.dataset.c;nav();render()}});
  }
  function legend(){
    $('legend').innerHTML=STATES.map(function(s){var n=DATA.filter(function(d){return d.status===s}).length;
      return '<div><i class="dot" style="background:'+COLORS[s]+'"></i>'+esc(s)+' <span style="margin-left:auto;color:#9aa0a6">'+n+'</span></div>'}).join('');
  }
  function render(){
    var q=state.q.trim().toLowerCase();
    shown=DATA.filter(function(d){
      if(state.cat!=='全部'&&d.cat!==state.cat)return false;
      if(!q)return true;
      return [d.id,d.name,d.cat,d.subject,d.version,d.source,d.usage,d.status,d.notes].join(' ').toLowerCase().indexOf(q)>=0;
    });
    $('title').textContent=state.cat==='全部'?'全部素材':state.cat;
    $('count').textContent='共 '+shown.length+' 项'+(q?'（已筛选）':'')+'　·　素材库不参与游戏运行';
    $('grid').innerHTML=shown.length?shown.map(function(d,i){
      return '<article class="card" data-i="'+i+'"><div class="stage">'+
        (d.thumb?'<img src="'+esc(d.thumb)+'" alt="'+esc(d.name)+'" loading="lazy">':'<span class="ph">暂无预览图</span>')+
        '</div><div class="meta"><div class="idline"><span class="pid">'+esc(d.id)+'</span>'+
        '<span class="ver">'+esc(d.version)+'</span>'+pill(d.status)+'</div>'+
        '<p class="name" title="'+esc(d.name)+'">'+esc(d.name)+'</p>'+
        '<div class="small">'+esc(d.cat)+'　·　'+esc(d.subject)+'</div></div></article>';
    }).join(''):'<div class="empty">没有匹配的素材。换个关键词，或清空搜索。</div>';
    Array.prototype.forEach.call($('grid').children,function(el){if(el.dataset.i!==undefined)el.onclick=function(){open(+el.dataset.i)}});
  }
  function detail(d){
    var a=d.anim||{}, anim=[a.frames,a.fps,a.size,a.facing,a.preview,a.sheet].some(function(x){return x});
    var rows=[
      ['素材 ID','<code>'+esc(d.id)+'</code>'],['版本','<code>'+esc(d.version)+'</code>'],
      ['分类',esc(d.cat)],['对应角色/场景',esc(d.subject)],
      ['制作状态',esc(d.makeStatus)],['审核状态',pill(d.status)],
      ['来源',esc(d.source)],['用途',esc(d.usage)]
    ];
    var html='<h2>'+esc(d.name)+'</h2><div class="tagline">'+esc(d.id)+' · '+esc(d.version)+' · '+esc(d.cat)+'</div><dl>'+
      rows.map(function(r){return '<dt>'+r[0]+'</dt><dd>'+r[1]+'</dd>'}).join('')+'</dl>';
    html+='<div class="block"><h3>版权 / 授权</h3><p>'+esc(d.license)+'</p></div>';
    html+='<div class="block"><h3>制作与修改说明</h3><p>'+esc(d.notes)+'</p></div>';
    html+='<div class="block"><h3>文件</h3><ul class="filelist">'+
      '<li>库内副本：<a href="'+esc(d.localHref)+'" target="_blank">'+esc(d.localPath||'（无）')+'</a></li>'+
      '<li>原始来源：<a href="'+esc(d.originHref)+'" target="_blank">'+esc(d.originPath||'（无）')+'</a></li>'+
      '<li>运行时资源：<code>'+esc(d.runtimePath||'未登记')+'</code></li></ul></div>';
    if(d.related.length){
      html+='<div class="block"><h3>相关文件</h3><ul class="filelist">'+d.related.map(function(f){
        return '<li><a href="'+esc(f.href)+'" target="_blank">'+esc(f.label)+'</a></li>'}).join('')+'</ul></div>';
    }
    if(anim){
      html+='<div class="block"><h3>动画记录</h3><dl style="grid-template-columns:88px 1fr">'+
        [['帧数',a.frames],['帧率 FPS',a.fps],['尺寸',a.size],['方向',a.facing],['预览',a.preview],['精灵图',a.sheet]]
        .map(function(r){return '<dt>'+r[0]+'</dt><dd>'+esc(r[1]||'—')+'</dd>'}).join('')+'</dl></div>';
    }else{
      html+='<div class="block"><h3>动画记录</h3><p>未登记动画；本条目不是可运行角色动画。</p></div>';
    }
    if(d.status!=='运行时可用')html+='<div class="warn">当前状态「'+esc(d.status)+'」：不得作为正式运行时资源引用。</div>';
    return html;
  }
  function open(i){
    idx=i;var d=shown[idx];if(!d)return;
    $('big').src=d.localHref||d.thumb;$('big').alt=d.name;
    $('detail').innerHTML=detail(d);$('modal').classList.add('show');document.body.style.overflow='hidden';
  }
  function close(){$('modal').classList.remove('show');document.body.style.overflow='';$('big').src=''}
  function step(n){if(!shown.length)return;open((idx+n+shown.length)%shown.length)}
  $('close').onclick=close;$('prev').onclick=function(){step(-1)};$('next').onclick=function(){step(1)};
  $('modal').onclick=function(e){if(e.target===$('modal'))close()};
  $('q').oninput=function(e){state.q=e.target.value;render()};
  document.addEventListener('keydown',function(e){
    if(!$('modal').classList.contains('show'))return;
    if(e.key==='Escape')close();else if(e.key==='ArrowLeft')step(-1);else if(e.key==='ArrowRight')step(1);
  });
  nav();legend();render();
})();
</script>
</body></html>
"""


def main() -> None:
    data = build_data()
    build_revised_ledger()
    payload = json.dumps(data, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
    html = (HTML_TEMPLATE
            .replace("__DATA__", payload)
            .replace("__CATS__", json.dumps(CATEGORIES, ensure_ascii=False))
            .replace("__STATES__", json.dumps(STATUSES, ensure_ascii=False)))
    HTML_PATH.write_text(html, encoding="utf-8")
    print(f"资产 {len(data)} 条，缩略图 {sum(1 for d in data if d['thumb'])} 张")
    print(f"预览页：{HTML_PATH}  ({HTML_PATH.stat().st_size:,} 字节)")
    print(f"ID 修订版：{REVISED_PATH}")


if __name__ == "__main__":
    main()
