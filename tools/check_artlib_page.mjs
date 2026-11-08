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
check('缩略图全部加载', await evalJs("[...document.querySelectorAll('.stage img')].every(i=>i.complete&&i.naturalWidth>0)"));
check('分类列表 = 7 项（全部 + 6 类）', await evalJs("document.querySelectorAll('#nav li').length") === 7);
check('v02 状态为「已通过设定审核」', DATA.some((d) => d.id === 'ART_CHAR_001' && d.version === 'v02' && d.status === '已通过设定审核'));
check('v01 历史备选仍保留', DATA.some((d) => d.id === 'ART_CHAR_001' && d.version === 'v01'));
check('安全屋双状态并存（v01-base / v01-upgraded）',
  ['v01-base', 'v01-upgraded'].every((v) => DATA.some((d) => d.id === 'ART_SCENE_102' && d.version === v)));
check('场景 101 / 102 / 103 已归档',
  ['101', '102', '103'].every((n) => DATA.some((d) => d.id === `ART_SCENE_${n}`)));
check('缩略图路径无重复（同 ID 多状态不撞名）',
  new Set(DATA.map((d) => d.thumb).filter(Boolean)).size === DATA.filter((d) => d.thumb).length);
check('场景条目制作状态均为概念绘制',
  DATA.filter((d) => d.cat === '场景').every((d) => d.makeStatus === '概念绘制'));
check('所有条目运行时路径为空', DATA.every((d) => !d.runtimePath));

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

const failed = results.filter((r) => !r.ok);
console.log(`\n结果：${results.length - failed.length}/${results.length} 通过`);
ws.close();
if (failed.length) process.exitCode = 1;
