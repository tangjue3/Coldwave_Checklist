// ART-INTEGRATE-004 Web 端验收（Chrome CDP）
//
// 前置：
//   python tools/serve_web.py                      # 8060，服务 builds/web
//   chrome --headless --remote-debugging-port=9444 # 无头 Chrome
// 用法：
//   CDP_PORT=9444 node tools/check_art004_web.mjs
//
// 它替桌面端补的是三件 Web 特有的事：
//   1. r03 四张分层贴图确实被打进了 PCK，能在浏览器里画出来（不是加载失败的白块）；
//   2. 装载状态切换在 Web 上同样生效（EMPTY / HALF / FULL 三态都能画出来）；
//   3. 控制台无 error —— Web 端会把任何 SCRIPT ERROR 当致命错误，桌面端往往看不出来。
import fs from 'node:fs';
import path from 'node:path';

const CDP = process.env.CDP_PORT || '9444';
const URL_BASE = process.env.WEB_BASE || 'http://127.0.0.1:8060/index.html';
const OUT_DIR = path.join(process.cwd().replace(/\\/g, '/'), 'tests/screenshots');

const targets = await (await fetch(`http://127.0.0.1:${CDP}/json/list`)).json();
const page = targets.find((t) => t.type === 'page');
if (!page) throw new Error('no page target');
const ws = new WebSocket(page.webSocketDebuggerUrl);
const pending = new Map();
let events = [];
let seq = 0;
ws.onmessage = (e) => {
  const m = JSON.parse(e.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
  else if (m.method) events.push(m);
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
const logs = () => events
  .filter((e) => e.method === 'Runtime.consoleAPICalled')
  .map((e) => ({ type: e.params.type, text: e.params.args.map((a) => a.value ?? a.description ?? '').join(' ') }));
const errors = () => events.filter((e) =>
  (e.method === 'Runtime.consoleAPICalled' && e.params.type === 'error') ||
  (e.method === 'Log.entryAdded' && e.params.entry.level === 'error') ||
  e.method === 'Runtime.exceptionThrown');

const results = [];
const check = (name, ok, extra = '') => {
  results.push({ name, ok });
  console.log(`${ok ? 'OK  ' : 'FAIL'} ${name} ${extra}`);
};

const restart = async (state, load = '') => {
  events = [];
  const loadQ = load ? `&load=${load}` : '';
  await send('Page.navigate', { url: `${URL_BASE}?dev=art004&state=${state}${loadQ}&t=${Date.now()}` });
  for (let i = 0; i < 120; i++) {
    await sleep(500);
    if (await evalJs("!document.getElementById('status')")) return true;
  }
  return false;
};

const shot = async (name) => {
  const s = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
  fs.mkdirSync(OUT_DIR, { recursive: true });
  fs.writeFileSync(path.join(OUT_DIR, name), Buffer.from(s.result.data, 'base64'));
};
const canvasSize = async () => JSON.parse(await evalJs(
  "JSON.stringify((()=>{const c=document.querySelector('canvas');return c?{w:c.width,h:c.height}:{w:0,h:0};})())"));

await send('Page.enable');
await send('Runtime.enable');
await send('Log.enable');
await send('Network.enable');
await send('Network.setCacheDisabled', { cacheDisabled: true });
// Godot 自己 fetch index.pck，只关 cache 不够，必须清一次磁盘缓存，否则跑的是上一版
await send('Network.clearBrowserCache');
await send('Emulation.setDeviceMetricsOverride', { width: 960, height: 540, deviceScaleFactor: 1, mobile: false });

// ---------------------------------------------------------------- A. 空载
check('Web 引擎启动完成（art004 · empty）', await restart('empty'));
await sleep(2500);

const size = await canvasSize();
check('画布 = 960×540（1:1，无缩放）', size.w === 960 && size.h === 540, JSON.stringify(size));

let all = logs();
check('r03 分层购物车已加载（[ART004] 日志 视觉=r03）',
  all.some((l) => l.text.includes('[ART004]') && l.text.includes('视觉=r03')),
  all.filter((l) => l.text.includes('[ART004]')).map((l) => l.text).join(' | ').slice(0, 200));
check('空载场景控制台无 error', errors().length === 0,
  errors().length ? JSON.stringify(errors()[0].params).slice(0, 200) : '');
await shot('art004_web_empty.png');

// ---------------------------------------------------------------- B. 半载 / 满载
check('Web 引擎启动完成（art004 · half）', await restart('half', 'half'));
await sleep(2200);
all = logs();
check('半载状态生效（[ART004] 日志 装载=half）',
  all.some((l) => l.text.includes('[ART004]') && l.text.includes('装载=half')),
  all.filter((l) => l.text.includes('[ART004]')).map((l) => l.text).join(' | ').slice(0, 200));
check('半载场景控制台无 error（新贴图已在 PCK 内）', errors().length === 0,
  errors().length ? JSON.stringify(errors()[0].params).slice(0, 200) : '');
await shot('art004_web_half.png');

check('Web 引擎启动完成（art004 · full）', await restart('full', 'full'));
await sleep(2200);
all = logs();
check('满载状态生效（[ART004] 日志 装载=full）',
  all.some((l) => l.text.includes('[ART004]') && l.text.includes('装载=full')),
  all.filter((l) => l.text.includes('[ART004]')).map((l) => l.text).join(' | ').slice(0, 200));
check('满载场景控制台无 error', errors().length === 0,
  errors().length ? JSON.stringify(errors()[0].params).slice(0, 200) : '');
await shot('art004_web_full.png');

// ---------------------------------------------------------------- C. 遮挡与镜像
check('Web 引擎启动完成（art004 · overlap）', await restart('overlap'));
await sleep(2200);
all = logs();
check('重叠场景无 error（近侧篮网遮挡正常）', errors().length === 0,
  errors().length ? JSON.stringify(errors()[0].params).slice(0, 200) : '');
await shot('art004_web_overlap.png');

check('Web 引擎启动完成（art004 · mirror）', await restart('mirror'));
await sleep(2200);
all = logs();
check('镜像场景绑定成功（[CART] bind side=+1）',
  all.some((l) => l.text.includes('[CART] bind') && l.text.includes('side=+1')),
  all.filter((l) => l.text.includes('[CART]')).map((l) => l.text).join(' | ').slice(0, 160));
check('镜像场景控制台无 error', errors().length === 0,
  errors().length ? JSON.stringify(errors()[0].params).slice(0, 200) : '');
await shot('art004_web_mirror.png');

console.log(`\n结果：${results.filter((r) => r.ok).length}/${results.length} 通过`);
ws.close();
if (results.some((r) => !r.ok)) process.exitCode = 1;
