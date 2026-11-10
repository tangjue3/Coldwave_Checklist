// 离线预览页自动验收：分类筛选、搜索、点击放大、详情字段。
//
// 前置：先用带 --remote-debugging-port=9444 --allow-file-access-from-files 的 Chrome 打开
//       素材库/美术总览.html（file:// 即可），再运行：
//   node tools/check_artlib_page.mjs
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';
import path from 'node:path';

const PORT = process.env.CDP_PORT || '9444';
const ROOT = process.cwd().replace(/\\/g, '/');
const PAGE = pathToFileURL(path.join(process.cwd(), '素材库', '美术总览.html')).href;
const SHOT = `${ROOT}/tests/screenshots/artlib_modal.png`;

const targets = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json();
const page = targets.find((t) => t.type === 'page');
if (!page) throw new Error('no page target');
const ws = new WebSocket(page.webSocketDebuggerUrl);
const pending = new Map();
let seq = 0;
ws.onmessage = (e) => {
  const m = JSON.parse(e.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
};
await new Promise((r) => { ws.onopen = r; });
const send = (method, params = {}) => new Promise((resolve) => {
  const id = ++seq; pending.set(id, resolve);
  ws.send(JSON.stringify({ id, method, params }));
});
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const evalJs = async (expression) => {
  const r = await send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
  return r.result?.result?.value;
};

await send('Page.enable');
await send('Runtime.enable');
await send('Network.enable');
await send('Network.setCacheDisabled', { cacheDisabled: true });
await send('Page.navigate', { url: PAGE });
await sleep(1200);

const results = [];
const check = (name, ok, extra = '') => { results.push({ name, ok, extra }); console.log(`${ok ? 'OK  ' : 'FAIL'} ${name} ${extra}`); };

// 期望值从页面内嵌数据推导，新增素材后无需改测试脚本
const DATA = JSON.parse(await evalJs("document.getElementById('asset-data').textContent"));
const charCount = DATA.filter((d) => d.cat === '角色').length;
const sceneCount = DATA.filter((d) => d.id.startsWith('ART_SCENE_')).length;

check(`卡片渲染 = ${DATA.length}`, await evalJs("document.querySelectorAll('.card').length") === DATA.length);
// 卡片是 loading="lazy"：条目多到超出一屏时，视口外的图根本不会开始加载。
// 先整页滚一遍把懒加载全部触发，再断言，否则是断言自己假失败（与资产无关）。
await evalJs(`(async () => {
  const step = 400;
  for (let y = 0; y < document.body.scrollHeight; y += step) {
    window.scrollTo(0, y);
    await new Promise((r) => setTimeout(r, 40));
  }
  window.scrollTo(0, 0);
  await new Promise((r) => setTimeout(r, 250));
  return true;
})()`);
const brokenImgs = await evalJs(
  "[...document.querySelectorAll('.stage img')].filter(i=>!(i.complete&&i.naturalWidth>0)).map(i=>i.getAttribute('src'))");
check('缩略图全部加载', brokenImgs.length === 0, brokenImgs.join(',') || '全部 complete');
check('分类列表 = 7 项（全部 + 6 类）', await evalJs("document.querySelectorAll('#nav li').length") === 7);
check('v02 状态为「已通过设定审核」', DATA.some((d) => d.id === 'ART_CHAR_001' && d.version === 'v02' && d.status === '已通过设定审核'));
check('v01 历史备选仍保留', DATA.some((d) => d.id === 'ART_CHAR_001' && d.version === 'v01'));
check('安全屋双状态并存（v01-base / v01-upgraded）',
  ['v01-base', 'v01-upgraded'].every((v) => DATA.some((d) => d.id === 'ART_SCENE_102' && d.version === v)));
check('场景 101 / 102 / 103 已归档',
  ['101', '102', '103'].every((n) => DATA.some((d) => d.id === `ART_SCENE_${n}`)));
check('货架双状态共用 ART_FURN_101（v01-empty / v01-stages）',
  ['v01-empty', 'v01-stages'].every((v) => DATA.some((d) => d.id === 'ART_FURN_101' && d.version === v)));
check('物资与家具样本已归档',
  ['ART_ITEM_101', 'ART_ITEM_102', 'ART_FURN_102'].every((id) => DATA.some((d) => d.id === id)));
// 「运行时可用」不是随手可写的标签，而是结论：必须同时满足
//   ① 对应运行时资源路径非空；② 该路径下的文件真实存在；③ 不是概念绘制阶段。
// 三条缺一，条目必须保持非运行时状态（SCALE-001 起生效）。
const resolveRuntime = (p) => {
  const t = (p || '').trim();
  if (!t) return '';
  const rel = t.startsWith('res://') ? t.slice(6) : t;
  return path.join(ROOT, rel);
};
const runtimeFileExists = (p) => {
  const f = resolveRuntime(p);
  return !!f && fs.existsSync(f);
};

const withPath = DATA.filter((d) => (d.runtimePath || '').trim());
const brokenPath = withPath.filter((d) => !runtimeFileExists(d.runtimePath));
check('填写了运行时路径的条目，文件必须真实存在',
  brokenPath.length === 0,
  withPath.length ? `共 ${withPath.length} 条，缺失 ${brokenPath.map((d) => d.id).join(',') || '无'}` : '（暂无条目填写）');

const usable = DATA.filter((d) => d.status === '运行时可用');
const unqualified = usable.filter((d) =>
  !(d.runtimePath || '').trim() || !runtimeFileExists(d.runtimePath) || d.makeStatus === '概念绘制');
check('「运行时可用」资质：路径有效 + 文件存在 + 非概念阶段',
  unqualified.length === 0,
  usable.length ? `${usable.length} 条，不合格 ${unqualified.map((d) => d.id).join(',') || '无'}` : '0 条');
// CORE-001B 起允许极少数条目进入「运行时可用」。白名单写死在这里，
// 任何新增都必须在代码里显式加一条，防止概念图被误标成可运行资源。
const APPROVED_RUNTIME = [
  { id: 'ART_CHAR_001', version: 'r01' },   // 朝右静止单帧（CORE-001B 批准）
  { id: 'ART_CHAR_001', version: 'r02' },   // 朝右行走四帧（ART-INTEGRATE-003 批准）
  { id: 'ART_CHAR_001', version: 'r03' },   // 扶车待机单帧（ART-FIX-003C 批准，仅扶车待机）
  { id: 'ART_FURN_103', version: 'r01' },   // 旧购物车，保留为回滚版本（ART-INTEGRATE-003 批准）
  { id: 'ART_FURN_103', version: 'r02' },   // 加高车把购物车（ART-FIX-003C 批准）
  { id: 'ART_FURN_101', version: 'r01' },   // 四层空货架（ART-FIX-003C 批准）
  // ART-INTEGRATE-004：商品四张 r02 / r02-shelf 经总监裁定升运行时可用
  { id: 'ART_ITEM_101', version: 'r02' },
  { id: 'ART_ITEM_101', version: 'r02-shelf' },
  { id: 'ART_ITEM_102', version: 'r02' },
  { id: 'ART_ITEM_102', version: 'r02-shelf' },
  // ART-INTEGRATE-005 阶段1：r03 购物车四件分件经总监最终裁定升运行时可用，
  // 且 PushableCart 默认版本切换为 r03（r02 保留为回退版本）
  { id: 'ART_FURN_103', version: 'r03-back' },
  { id: 'ART_FURN_103', version: 'r03-front' },
  { id: 'ART_FURN_103', version: 'r03-half' },
  { id: 'ART_FURN_103', version: 'r03-full' },
  // ART-APPROVE-005E：美术总监正式批准 r09 升「运行时可用」，并作为正式默认扶车动画（16 帧 / 10 FPS）
  { id: 'ART_CHAR_001', version: 'r09' },
];
// ART-INTEGRATE-005 阶段1：r03 四件已获批，断言从「必须待审核」改为
// 「四件都必须是运行时可用且已进白名单」，保留质量保护但不拦批准结果。
const R03_PARTS = ['r03-back', 'r03-front', 'r03-half', 'r03-full'];
const r03Parts = DATA.filter((d) => d.id === 'ART_FURN_103' && R03_PARTS.includes(d.version));
check('r03 购物车四件分件全部为「运行时可用」（ART-INTEGRATE-005 阶段1 裁定）',
  r03Parts.length === 4 && r03Parts.every((d) => d.status === '运行时可用'),
  `实际 ${r03Parts.length} 条，状态 ${r03Parts.map((d) => d.version + ':' + d.status).join(',') || '无'}`);
check('r03 四件分件全部在运行时白名单内',
  R03_PARTS.every((v) => APPROVED_RUNTIME.some((a) => a.id === 'ART_FURN_103' && a.version === v)));
const unexpectedRuntime = usable.filter((d) =>
  !APPROVED_RUNTIME.some((a) => a.id === d.id && a.version === d.version));
check('「运行时可用」仅限已批准白名单（角色 r01–r03 / r09 + 车 r01–r03 + 货架 r01 + 商品 r02/r02-shelf）',
  unexpectedRuntime.length === 0,
  `${usable.length} 条，越权 ${unexpectedRuntime.map((d) => d.id + '@' + d.version).join(',') || '无'}`);
check('概念素材仍全部保持非运行时状态',
  DATA.filter((d) => d.status !== '运行时可用').length === DATA.length - APPROVED_RUNTIME.length);
// ART-APPROVE-005E：美术总监已审查实机 GIF / 对照图，正式批准 r09 升「运行时可用」
// 并作为正式默认扶车动画。断言从「必须待审核」翻转为「必须已批准且已进白名单」，
// 质量保护保留、不删任何断言；r03 / r04 的回退能力单独断言。
const r09 = DATA.filter((d) => d.id === 'ART_CHAR_001' && d.version === 'r09');
check('r09 返工动作只有一条记录且已升「运行时可用 / 扶车十六帧可用」',
  r09.length === 1 && r09[0].status === '运行时可用' && r09[0].makeStatus === '扶车十六帧可用',
  `实际 ${r09.length} 条 ${r09.map((d) => d.status + '/' + d.makeStatus).join(',') || '无'}`);
check('r09 已显式登记进运行时可用白名单',
  APPROVED_RUNTIME.some((a) => a.id === 'ART_CHAR_001' && a.version === 'r09'));
check('r09 批准记录含任务编号 / 批准人 / 日期',
  r09.length === 1 && r09[0].notes.includes('ART-APPROVE-005E')
    && r09[0].notes.includes('美术总监') && r09[0].notes.includes('2026-11-09'));
check('r09 登记 16 帧 / 10 FPS，且 r03 / r04 原状态未被改动',
  r09.length === 1 && String(r09[0].anim.frames).includes('16')
    && String(r09[0].anim.fps) === '10'
    && DATA.some((d) => d.id === 'ART_CHAR_001' && d.version === 'r03' && d.status === '运行时可用')
    && DATA.some((d) => d.id === 'ART_CHAR_001' && d.version === 'r04' && d.status === '待审核'));
const r03Fallback = DATA.filter((d) => d.id === 'ART_CHAR_001' && d.version === 'r03');
const r04Fallback = DATA.filter((d) => d.id === 'ART_CHAR_001' && d.version === 'r04');
check('r03 / r04 回退版本仍完整保留（台账行 + 运行时路径 + 原审核状态）',
  r03Fallback.length === 1 && r04Fallback.length === 1
    && r03Fallback[0].status === '运行时可用' && r04Fallback[0].status === '待审核'
    && !!(r03Fallback[0].runtimePath || '').trim()
    && !!(r04Fallback[0].runtimePath || '').trim());
// ART-FIX-003C：商品图的内容归属必须与 ID 一致。
// 上一批四张图尺寸/alpha/锚点全对，只有"画的是什么"错了，纯结构断言抓不住。
// 这里按 thumbnail 文件名的版本号硬绑：水的可用版本只能是 r02 / r02-shelf。
const goodWater = DATA.filter((d) => d.id === 'ART_ITEM_101' && d.status === '运行时可用');
const goodFood = DATA.filter((d) => d.id === 'ART_ITEM_102' && d.status === '运行时可用');
check('101 / 102 的旧错误版（r01、r01-shelf）均为「不予通过」且无运行时路径',
  DATA.filter((d) => (d.id === 'ART_ITEM_101' || d.id === 'ART_ITEM_102')
      && (d.version === 'r01' || d.version === 'r01-shelf'))
    .every((d) => d.status === '不予通过' && !(d.runtimePath || '').trim()));
// 用 localPath 判定（缩略图名是 ID_版本，不含物品英文名）
const nameOf = (d) => d.localPath || d.thumb || '';
// 只管运行时序列（rNN / rNN-shelf）：概念版 v01 用中文短名，不在本断言范围内
const badNamed = DATA.filter((d) => (d.id === 'ART_ITEM_101' || d.id === 'ART_ITEM_102')
    && /^r\d{2}/.test(d.version) && d.status !== '不予通过')
  .filter((d) => d.id === 'ART_ITEM_101' ? !/water/i.test(nameOf(d)) : !/food/i.test(nameOf(d)));
check('101 只允许挂 water 文件、102 只允许挂 food 文件（防再互换）',
  badNamed.length === 0,
  badNamed.map((d) => d.id + '@' + d.version + ':' + nameOf(d)).join(',')
    || `水可用 ${goodWater.length} 条、纸箱可用 ${goodFood.length} 条`);

check('缩略图路径无重复（同 ID 多状态不撞名）',
  new Set(DATA.map((d) => d.thumb).filter(Boolean)).size === DATA.filter((d) => d.thumb).length);
check('场景条目制作状态均为概念绘制',
  DATA.filter((d) => d.cat === '场景').every((d) => d.makeStatus === '概念绘制'));
// 运行时路径必须落在 assets/ 里：不得直接引用素材库或转存库（那里 .gdignore，克隆后也不该被打包）
const assetsDir = path.join(ROOT, 'assets');
const rtOutsideAssets = withPath.filter((d) => {
  const rel = path.relative(assetsDir, resolveRuntime(d.runtimePath));
  return rel.startsWith('..') || path.isAbsolute(rel);
});
check('运行时路径只允许指向 assets/（不得直接引用素材库或转存库）',
  rtOutsideAssets.length === 0,
  rtOutsideAssets.length
    ? rtOutsideAssets.map((d) => d.id + ':' + d.runtimePath).join(',')
    : withPath.length + ' 条运行时路径，全部在 assets/');


await evalJs("document.querySelector('#q').value='ART_SCENE';document.querySelector('#q').dispatchEvent(new Event('input'))");
check(`搜索 ART_SCENE → ${sceneCount} 项`, await evalJs("document.querySelectorAll('.card').length") === sceneCount);
await evalJs("document.querySelector('#q').value='';document.querySelector('#q').dispatchEvent(new Event('input'))");

await evalJs("[...document.querySelectorAll('#nav li')].find(li=>li.dataset.c==='角色').click()");
check(`分类「角色」→ ${charCount} 项`, await evalJs("document.querySelectorAll('.card').length") === charCount);
await evalJs("document.querySelector('#nav li').click()");

// 灯箱截图固定打开 v02（第一季外观基准），便于人工核对审核状态
const v02Index = DATA.findIndex((d) => d.id === 'ART_CHAR_001' && d.version === 'v02');
await evalJs(`document.querySelectorAll('.card')[${v02Index}].click()`);
const modal = await evalJs("JSON.stringify({open:document.querySelector('#modal').classList.contains('show'),src:document.querySelector('#big').getAttribute('src'),detail:document.querySelector('#detail').innerText.includes('运行时资源'),warn:document.querySelector('#detail').innerText.includes('不得作为正式运行时资源')})");
const m = JSON.parse(modal);
check('点击缩略图打开灯箱', m.open);
check('灯箱加载原图路径', !!m.src && m.src.endsWith('.png'), m.src);
check('详情含运行时资源字段与未批准警告', m.detail && m.warn);

const shot = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
fs.mkdirSync(path.dirname(SHOT), { recursive: true });
fs.writeFileSync(SHOT, Buffer.from(shot.result.data, 'base64'));
console.log('截图：', SHOT);

// ==========================================================================
// TASK-ARTLIB-CLEAN-001 新增：三条状态轴 / 动作分组 / 参考图 / 版本对照 / 序列帧
// ==========================================================================
await evalJs("document.querySelector('#close').click()");

// ---- 数据层：整理列是否齐全、枚举是否合法
const ACTS = ['外观设定', '待机', '普通行走', '推购物车', '反向拉车', '搬运', '其他动作', '不适用'];
const missFields = DATA.filter((d) => !d.act || !d.visual || !d.useState || !Array.isArray(d.tags));
check('CLEAN-001 整理列齐全（动作分组 / 视觉评价 / 使用状态 / 标记）',
  missFields.length === 0, missFields.map((d) => d.id + '@' + d.version).join(',') || '39 条齐全');
check('动作分组取值合法',
  DATA.every((d) => ACTS.includes(d.act)),
  [...new Set(DATA.map((d) => d.act))].join(','));
check('视觉评价取值合法',
  DATA.every((d) => ['认可', '待优化', '未评价', '不适用'].includes(d.visual)),
  [...new Set(DATA.map((d) => d.visual))].join(','));
check('使用状态取值合法',
  DATA.every((d) => ['正式使用', '回退保留', '未使用'].includes(d.useState)),
  [...new Set(DATA.map((d) => d.useState))].join(','));

// ---- 核心需求：技术通过 ≠ 美术满意。r09 必须同时命中三个互不冲突的标记
const r09v2 = DATA.find((d) => d.id === 'ART_CHAR_001' && d.version === 'r09');
const needTags = ['已通过技术验收', '当前游戏使用中', '视觉质量待优化'];
check('r09 同时具备「技术通过 + 正在用 + 视觉待优化」三个标记',
  !!r09v2 && needTags.every((t) => r09v2.tags.includes(t)),
  r09v2 ? r09v2.tags.join('+') : '缺失');
check('r09 保留技术验收记录（审核状态仍为运行时可用）', r09v2?.status === '运行时可用', r09v2?.status);
check('r09 视觉评价为待优化', r09v2?.visual === '待优化', r09v2?.visual);

// ---- 归档条目不得有运行时路径，且必须打上「历史归档」标记
const archived = DATA.filter((d) => d.archived === '是');
check('归档条目全部带「历史归档」标记且无运行时路径',
  archived.length > 0 && archived.every((d) => d.tags.includes('历史归档') && !(d.runtimePath || '').trim()),
  `${archived.length} 条：${archived.map((d) => d.id + '@' + d.version).join(',')}`);

// ---- 使用状态与审核状态的一致性
const badUse = DATA.filter((d) => d.useState === '正式使用' && d.status !== '运行时可用');
check('「正式使用」的条目都是运行时可用', badUse.length === 0,
  badUse.map((d) => d.id + '@' + d.version).join(',') || '无越权');

// ---- 序列帧：帧文件真实存在，帧数与台账一致
const frameRows = DATA.filter((d) => (d.frameHrefs || []).length);
const missingFrames = frameRows.flatMap((d) => d.frameHrefs.filter((h) => !fs.existsSync(path.join(ROOT, '素材库', h))));
check('序列帧文件全部存在', missingFrames.length === 0,
  `${frameRows.length} 组 / ${frameRows.reduce((a, d) => a + d.frameHrefs.length, 0)} 帧，缺失 ${missingFrames.join(',') || '无'}`);
const r09frames = DATA.find((d) => d.id === 'ART_CHAR_001' && d.version === 'r09');
const r02frames = DATA.find((d) => d.id === 'ART_CHAR_001' && d.version === 'r02');
const r04frames = DATA.find((d) => d.id === 'ART_CHAR_001' && d.version === 'r04');
check('帧数与台账一致：r02 = 4 / r04 = 4 / r09 = 16',
  r02frames?.frameHrefs.length === 4 && r04frames?.frameHrefs.length === 4 && r09frames?.frameHrefs.length === 16,
  `${r02frames?.frameHrefs.length} / ${r04frames?.frameHrefs.length} / ${r09frames?.frameHrefs.length}`);
const gifs = DATA.filter((d) => d.gif);
const badGifs = gifs.filter((d) => !fs.existsSync(path.join(ROOT, '素材库', d.gif)));
check('多帧条目都生成了预览 GIF 且文件存在', gifs.length === 3 && badGifs.length === 0,
  `${gifs.length} 个：${gifs.map((d) => d.version).join(',')} 缺失 ${badGifs.length}`);

// ---- 参考图：四个动作都有已登记参考图，且不含未登记素材
const refActions = ['普通行走', '推购物车', '搬箱', '搬水'];
const refKeys = new Set(DATA.flatMap((d) => d.refFor));
check('AI 视频参考图覆盖四个动作', refActions.every((a) => refKeys.has(a)), [...refKeys].join(','));
const refUnknown = [...refKeys].filter((k) => !DATA.some((d) => d.refFor.includes(k)));
check('参考图全部来自已登记素材', refUnknown.length === 0, refUnknown.join(',') || '全部已登记');
const refNoThumb = DATA.filter((d) => d.refFor.length && !d.thumb);
check('参考图条目都有缩略图', refNoThumb.length === 0, refNoThumb.map((d) => d.id).join(',') || '全部有图');

// ---- UI：动作导航 8 项
check('角色动作导航 = 8 项（全部 + 7 门类）',
  await evalJs("document.querySelectorAll('#actnav li').length") === 8);

// ---- UI：点动作「推购物车」只剩 2 条
await evalJs("[...document.querySelectorAll('#actnav li')].find(li=>li.dataset.a==='推购物车').click()");
const pushCount = DATA.filter((d) => d.act === '推购物车' && d.cat === '角色').length;
check(`动作筛选「推购物车」→ ${pushCount} 项`,
  await evalJs("document.querySelectorAll('.card').length") === pushCount);
await evalJs("document.querySelector('#actnav li').click();document.querySelector('#nav li').click()");

// ---- UI：r09 灯箱里版本对照完整 + 序列帧播放器可播放
const r09Index = DATA.findIndex((d) => d.id === 'ART_CHAR_001' && d.version === 'r09');
await evalJs(`document.querySelectorAll('.card')[${r09Index}].click()`);
const sibCount = DATA.filter((d) => d.id === 'ART_CHAR_001').length;
check(`灯箱「版本对照」列出同 ID 全部 ${sibCount} 个版本`,
  await evalJs("document.querySelectorAll('#detail .vitem').length") === sibCount);
const before = await evalJs("document.querySelector('#big').getAttribute('src')");
await evalJs("document.querySelector('#play').click()");
await sleep(350);
const after = await evalJs("document.querySelector('#big').getAttribute('src')");
check('序列帧播放器会切换帧', !!before && !!after && before !== after, `${before} → ${after}`);
await evalJs("document.querySelector('#play').click();document.querySelector('#close').click()");

// ---- UI：参考图页 4 张卡片
await evalJs("[...document.querySelectorAll('#tabs .tab')].find(t=>t.dataset.v==='refs').click()");
check('参考图页渲染 4 个动作卡片',
  await evalJs("document.querySelectorAll('.refcard').length") === 4);
check('参考图页不误用素材卡片 class（不干扰卡片计数）',
  await evalJs("document.querySelectorAll('.refcard .card').length") === 0);
await evalJs("[...document.querySelectorAll('#tabs .tab')].find(t=>t.dataset.v==='gaps').click()");
check('动作缺口页渲染 6 行',
  await evalJs("document.querySelectorAll('table.gaps tbody tr').length") === 6);
await evalJs("[...document.querySelectorAll('#tabs .tab')].find(t=>t.dataset.v==='assets').click()");

// ---- UI：状态标记多选筛选
await evalJs("[...document.querySelectorAll('#chips .chip')].find(c=>c.dataset.t==='视觉质量待优化').click()");
const visualCount = DATA.filter((d) => d.tags.includes('视觉质量待优化')).length;
check(`标记筛选「视觉质量待优化」→ ${visualCount} 项`,
  await evalJs("document.querySelectorAll('.card').length") === visualCount);
await evalJs("[...document.querySelectorAll('#chips .chip')].find(c=>c.dataset.t==='视觉质量待优化').click()");

const shot2 = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
fs.writeFileSync(`${ROOT}/tests/screenshots/artlib_refs.png`, Buffer.from(shot2.result.data, 'base64'));

const failed = results.filter((r) => !r.ok);
console.log(`\n结果：${results.length - failed.length}/${results.length} 通过`);
ws.close();
if (failed.length) process.exitCode = 1;
