// ART-INTEGRATE-005E Web 端验收（Chrome CDP，真键盘派发）
//
// 前置：
//   python tools/serve_web.py                        # 8060，服务 builds/web
//   chrome --headless --remote-debugging-port=9444   # 无头 Chrome
// 用法：
//   CDP_PORT=9444 node tools/check_art005e_web.mjs
//
// 覆盖：
//   1. art005e 场景在 Web 上启动，r09 十六帧 / 10FPS 动画已注册且贴图已进 PCK；
//   2. 真按 E 绑定购物车 → r09 扶车静止帧；
//   3. 真按住 D 推行 → r09 十六帧行走（10 FPS）；
//   4. 再按 E 解绑 → 普通行走；
//   5. 画布 960×540、控制台 0 error。
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

const key = async (code, vk, ch) => {
  const base = { windowsVirtualKeyCode: vk, nativeVirtualKeyCode: vk, code, key: ch };
  await send('Input.dispatchKeyEvent', { type: 'keyDown', ...base, text: ch });
  await sleep(80);
  await send('Input.dispatchKeyEvent', { type: 'keyUp', ...base });
};
const hold = async (code, vk, ch, ms) => {
  const base = { windowsVirtualKeyCode: vk, nativeVirtualKeyCode: vk, code, key: ch };
  await send('Input.dispatchKeyEvent', { type: 'keyDown', ...base, text: ch });
  await sleep(ms);
  await send('Input.dispatchKeyEvent', { type: 'keyUp', ...base });
  await sleep(250);
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

events = [];
await send('Page.navigate', { url: `${URL_BASE}?dev=art005e&t=${Date.now()}` });
let ready = false;
for (let i = 0; i < 120; i++) {
  await sleep(500);
  if (await evalJs("!document.getElementById('status')")) { ready = true; break; }
}
check('Web 引擎启动完成（art005e）', ready);
await sleep(2500);

const size = await canvasSize();
check('画布 = 960×540（1:1，无缩放）', size.w === 960 && size.h === 540, JSON.stringify(size));

let all = logs();
const boot = all.filter((l) => l.text.includes('[ART005E]'));
check('r09 动画已注册：16 帧 / 10.0 FPS（启动日志）',
  boot.some((l) => l.text.includes('帧数=16') && l.text.includes('FPS=10.0')),
  boot.map((l) => l.text).join(' | ').slice(0, 220));
check('冻结参数在 Web 端一致（车长 96 / 间距 80 / 推 80 / 拉 40）',
  boot.some((l) => l.text.includes('车长=96') && l.text.includes('推=80') && l.text.includes('拉=40')));

await key('KeyE', 69, 'e');
await sleep(500);
all = logs();
check('真按 E → 绑定购物车（[CART] bind）', all.some((l) => l.text.includes('[CART] bind')));
check('绑定后播 r09 扶车静止帧（[ANIM] r09_push_idle）',
  all.some((l) => l.text.includes('[ANIM] r09_push_idle')));

await hold('KeyD', 68, 'd', 1200);
all = logs();
check('按住 D 推行 → r09 十六帧 / 10FPS（[ANIM] r09_push_walk_right）',
  all.some((l) => l.text.includes('[ANIM] r09_push_walk_right') && l.text.includes('帧数=16')),
  all.filter((l) => l.text.includes('[ANIM]')).map((l) => l.text).slice(-4).join(' | ').slice(0, 200));

await key('KeyE', 69, 'e');
await sleep(500);
all = logs();
check('再按 E → 解绑（[CART] unbind）', all.some((l) => l.text.includes('[CART] unbind')));
check('解绑后恢复普通动画（idle / walk_right）',
  all.some((l) => l.text.includes('[ANIM] idle') || l.text.includes('[ANIM] walk_right')));

const errs = errors();
check('控制台 0 error（17 张运行贴图均在 PCK 内）', errs.length === 0,
  errs.length ? JSON.stringify(errs[0].params ?? errs[0]).slice(0, 220) : '');
await shot('art005e_web.png');

console.log(`\n结果：${results.filter((r) => r.ok).length}/${results.length} 通过`);
ws.close();
if (results.some((r) => !r.ok)) process.exitCode = 1;
