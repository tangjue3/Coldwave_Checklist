// ART-INTEGRATE-005 Web 端验收（Chrome CDP）
//
// 前置：
//   python tools/serve_web.py                      # 8060，服务 builds/web
//   chrome --headless --remote-debugging-port=9444 # 无头 Chrome
// 用法：
//   CDP_PORT=9444 node tools/check_art005_web.mjs
//
// 覆盖：
//   1. art005 场景在 Web 上能启动，push_walk_right 动画已注册（[ART005] 日志：帧数=4 FPS=6）；
//   2. r04 四帧已打进 PCK（若缺资源，Godot 会在控制台报 error）；
//   3. 画布 960×540、控制台 0 error。
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

const restart = async () => {
  events = [];
  await send('Page.navigate', { url: `${URL_BASE}?dev=art005&t=${Date.now()}` });
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
await send('Network.clearBrowserCache');
await send('Emulation.setDeviceMetricsOverride', { width: 960, height: 540, deviceScaleFactor: 1, mobile: false });

check('Web 引擎启动完成（art005）', await restart());
await sleep(3000);

const size = await canvasSize();
check('画布 = 960×540（1:1，无缩放）', size.w === 960 && size.h === 540, JSON.stringify(size));

const all = logs();
check('art005 场景就绪（[ART005] 日志 动画=push_walk_right 帧数=4）',
  all.some((l) => l.text.includes('[ART005]') && l.text.includes('push_walk_right') && l.text.includes('帧数=4')),
  all.filter((l) => l.text.includes('[ART005]')).map((l) => l.text).join(' | ').slice(0, 200));
check('默认 6 FPS（日志 FPS=6）',
  all.some((l) => l.text.includes('[ART005]') && l.text.includes('FPS=6')));
check('r04 四帧已在 PCK 内（无加载 error）', errors().length === 0,
  errors().length ? JSON.stringify(errors()[0].params ?? errors()[0]).slice(0, 220) : '');
await shot('art005_web.png');

console.log(`\n结果：${results.filter((r) => r.ok).length}/${results.length} 通过`);
ws.close();
if (results.some((r) => !r.ok)) process.exitCode = 1;
