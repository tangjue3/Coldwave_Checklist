// CORE-001A Web 端验收（Chrome CDP）
//
// 前置：
//   python tools/serve_web.py                       # 8060，服务 builds/web
//   chrome --headless --remote-debugging-port=9333   # 无头 Chrome
// 用法：
//   node tools/check_core001a_web.mjs
//
// 检查点：
//   1. Web 版能用 URL 参数直接进开发场景（?dev=core001a），不依赖命令行；
//   2. 引擎把 [CORE] 量测行打到控制台，数值与桌面端一致（纹理/可见框/碰撞盒/脚底误差）；
//   3. 控制台无 error、无未捕获异常；
//   4. 截一张 960×540 的 Web 画面。
import fs from 'node:fs';
import path from 'node:path';

const CDP = process.env.CDP_PORT || '9333';
const URL_BASE = process.env.WEB_BASE || 'http://127.0.0.1:8060/index.html';
const STATE = process.env.CORE_STATE || 'door';
const OUT_DIR = path.join(process.cwd().replace(/\\/g, '/'), 'tests/screenshots');

const targets = await (await fetch(`http://127.0.0.1:${CDP}/json/list`)).json();
const page = targets.find((t) => t.type === 'page');
if (!page) throw new Error('no page target');
const ws = new WebSocket(page.webSocketDebuggerUrl);
const pending = new Map();
const events = [];
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
  .filter((e) => e.method === 'Runtime.consoleAPICalled' && e.params.type !== 'error')
  .map((e) => e.params.args.map((a) => a.value ?? a.description ?? '').join(' '));
const errors = () => events.filter((e) =>
  (e.method === 'Runtime.consoleAPICalled' && e.params.type === 'error') ||
  (e.method === 'Log.entryAdded' && e.params.entry.level === 'error') ||
  e.method === 'Runtime.exceptionThrown');

const results = [];
const check = (name, ok, extra = '') => {
  results.push({ name, ok });
  console.log(`${ok ? 'OK  ' : 'FAIL'} ${name} ${extra}`);
};

await send('Page.enable');
await send('Runtime.enable');
await send('Log.enable');
await send('Network.enable');
await send('Network.setCacheDisabled', { cacheDisabled: true });
// 只设 cacheDisabled 不够：Godot 自己 fetch index.pck，浏览器仍可能复用旧包，
// 导致「改了代码但跑的还是上一版」，必须先清一次磁盘缓存。
await send('Network.clearBrowserCache');
// 让画布正好是 960×540，截图即为 1:1
await send('Emulation.setDeviceMetricsOverride', { width: 960, height: 540, deviceScaleFactor: 1, mobile: false });
await send('Page.navigate', { url: `${URL_BASE}?dev=core001a&state=${STATE}&t=${Date.now()}` });

let ready = false;
for (let i = 0; i < 120; i++) {
  await sleep(500);
  if (await evalJs("!document.getElementById('status')")) { ready = true; break; }
}
check('Web 引擎启动完成', ready);
await sleep(2500);

const all = logs();
const core = all.filter((l) => l.includes('[CORE]'));
const has = (frag) => core.some((l) => l.includes(frag));

check(`开发入口生效：控制台出现 [CORE] 量测行（${core.length} 行）`, core.length >= 4);
check('纹理 = 128×176', has('纹理 128×176'));
check('sprite.get_rect() 锚点 = (-64,-168)', has('-64.0, -168.0'));
check('可见包围盒 = 41×160', has('41×160'));
check('碰撞盒 = 28×160', has('28×160'));
check('脚底误差 = 0', has('脚底误差 = 0'));
check('门净宽 80 / 净高 184', has('净 80×184'));
// 主菜单是启动场景，必然先打印一次 [MENU]；要确认的是之后切到了 core001a 且没有弹回去
const lastCore = all.map((l, i) => (l.includes('[CORE]') ? i : -1)).filter((i) => i >= 0).pop() ?? -1;
const lastMenu = all.map((l, i) => (l.includes('[MENU]') ? i : -1)).filter((i) => i >= 0).pop() ?? -1;
check('Web 启动后已切到 core001a（[CORE] 在最后一次 [MENU] 之后）',
  lastCore > lastMenu,
  `lastMenu=${lastMenu} lastCore=${lastCore}`);

const errs = errors();
check('控制台无 error / 未捕获异常', errs.length === 0,
  errs.length ? errs.slice(0, 3).map((e) => JSON.stringify(e.params).slice(0, 160)).join(' | ') : '');

const shot = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
fs.mkdirSync(OUT_DIR, { recursive: true });
const out = path.join(OUT_DIR, `core001a_web_${STATE}.png`);
fs.writeFileSync(out, Buffer.from(shot.result.data, 'base64'));
console.log('截图：', out);

const failed = results.filter((r) => !r.ok);
console.log(`\n结果：${results.length - failed.length}/${results.length} 通过`);
ws.close();
if (failed.length) process.exitCode = 1;
