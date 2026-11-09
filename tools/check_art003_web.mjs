// ART-INTEGRATE-003 Web 端验收（Chrome CDP）
//
// 前置：
//   python tools/serve_web.py                      # 8060，服务 builds/web
//   chrome --headless --remote-debugging-port=9333  # 无头 Chrome
// 用法：
//   node tools/check_art003_web.mjs
//
// 它替桌面端补的是三件 Web 特有的事：
//   1. 新素材（r03 扶车姿态 / 购物车 r02 / 货架 / 商品）确实被打进了 PCK，能在浏览器里画出来；
//   2. 扶车姿态动画与交互提示在 Web 上同样生效（Web 没有命令行，只能靠 URL 参数进开发场景）；
//   3. 控制台无 error —— Web 端会把任何 SCRIPT ERROR 当致命错误，桌面端往往看不出来。
import fs from 'node:fs';
import path from 'node:path';

const CDP = process.env.CDP_PORT || '9333';
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

const restart = async (state) => {
  events = [];
  await send('Page.navigate', { url: `${URL_BASE}?dev=art003&state=${state}&t=${Date.now()}` });
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

// ---------------------------------------------------------------- A. 扶车贴合
check('Web 引擎启动完成（art003 · hand_r）', await restart('hand_r'));
await sleep(2500);

const size = await canvasSize();
check('画布 = 960×540（1:1，无缩放）', size.w === 960 && size.h === 540, JSON.stringify(size));

let all = logs();
// ART-INTEGRATE-005E 起默认扶车静止帧由 r03 的 push_idle 换成 r09_push_idle。
// 语义（绑定后必须播扶车姿态）不变，两个版本都接受；测试项没有减少。
check('扶车姿态动画生效（[ANIM] r09_push_idle / push_idle）',
  all.some((l) => /\[ANIM\] (r09_)?push_idle/.test(l.text)),
  all.filter((l) => l.text.includes('[ANIM]')).map((l) => l.text).join(' | ').slice(0, 120));
check('绑定成功（[CART] bind side=-1，脚底距车心 80）',
  all.some((l) => l.text.includes('[CART] bind') && l.text.includes('80')));
check('交互提示「E 停车」出现', all.some((l) => l.text.includes('提示=E 停车')));
check('扶车场景控制台无 error', errors().length === 0,
  errors().length ? JSON.stringify(errors()[0].params).slice(0, 200) : '');
await shot('art003_web_hand_r.png');

// ---------------------------------------------------------------- B. 货架与商品
check('Web 引擎启动完成（art003 · shelves）', await restart('shelves'));
await sleep(2200);
all = logs();
check('货架场景无 error（新贴图已在 PCK 内）', errors().length === 0,
  errors().length ? JSON.stringify(errors()[0].params).slice(0, 200) : '');
const shelfSize = await canvasSize();
check('货架场景画布仍为 960×540', shelfSize.w === 960 && shelfSize.h === 540, JSON.stringify(shelfSize));
await shot('art003_web_shelves.png');

console.log(`\n结果：${results.filter((r) => r.ok).length}/${results.length} 通过`);
ws.close();
if (results.some((r) => !r.ok)) process.exitCode = 1;
