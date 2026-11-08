// Godot Web 导出冒烟测试：通过 CDP 等待引擎真正启动，再截图并模拟按键。
// 用法：node .tools/web_smoke_cdp.mjs
import fs from 'node:fs';

const PAGE = 'http://127.0.0.1:8060/index.html?t=' + Date.now();
const PORT = process.env.CDP_PORT || '9333';
const OUT_DIR = process.cwd().replace(/\\/g, '/') + '/tests/screenshots';
const targets = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json();
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

function send(method, params = {}) {
  return new Promise((resolve) => {
    const id = ++seq;
    pending.set(id, resolve);
    ws.send(JSON.stringify({ id, method, params }));
  });
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

await send('Page.enable');
await send('Runtime.enable');
await send('Log.enable');
await send('Network.enable');
await send('Network.setCacheDisabled', { cacheDisabled: true });
await send('Page.navigate', { url: PAGE });

// Godot 4.7 的 HTML 模板在启动完成后会直接 remove() 掉 #status 覆盖层，
// 不是把 visibility 设成 hidden；因此「元素消失」才是就绪信号。
const expr = `JSON.stringify({
  ready: !document.getElementById('status'),
  statusVisibility: document.getElementById('status')?.style.visibility,
  canvasW: document.getElementById('canvas')?.width,
  canvasH: document.getElementById('canvas')?.height,
  cssW: document.getElementById('canvas')?.clientWidth,
  cssH: document.getElementById('canvas')?.clientHeight,
  innerW: innerWidth, innerH: innerHeight,
  title: document.title
})`;

let ready = false;
let last = null;
for (let i = 0; i < 240; i++) {
  await sleep(500);
  const r = await send('Runtime.evaluate', { expression: expr, returnByValue: true });
  try { last = JSON.parse(r.result.result.value); } catch { continue; }
  if (i % 10 === 0) console.log('poll', i, JSON.stringify(last));
  if (last.ready === true) { ready = true; break; }
}

console.log('READY =', ready, JSON.stringify(last));
if (!ready) {
  const errs = events.filter((e) => e.method === 'Runtime.exceptionThrown' || e.method === 'Log.entryAdded' || (e.method === 'Runtime.consoleAPICalled' && e.params.type === 'error'));
  console.log('EVENTS', JSON.stringify(errs.slice(-10), null, 2));
  process.exitCode = 1;
} else {
  // 基本输入：按下 E，应触发 interact 动作并在「输入回显」中显示
  await send('Input.dispatchKeyEvent', { type: 'keyDown', key: 'e', code: 'KeyE', windowsVirtualKeyCode: 69, nativeVirtualKeyCode: 69, text: 'e' });
  await send('Input.dispatchKeyEvent', { type: 'keyUp', key: 'e', code: 'KeyE', windowsVirtualKeyCode: 69, nativeVirtualKeyCode: 69 });
  await sleep(1200);

  async function shot(name, w, h) {
    await send('Emulation.setDeviceMetricsOverride', { width: w, height: h, deviceScaleFactor: 1, mobile: false });
    await sleep(1200);
    const r = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
    const p = `${OUT_DIR}/${name}`;
    fs.writeFileSync(p, Buffer.from(r.result.data, 'base64'));
    const m = await send('Runtime.evaluate', { expression: expr, returnByValue: true });
    console.log('SHOT', name, JSON.stringify(JSON.parse(m.result.result.value)));
  }

  await shot('web_1366x768.png', 1366, 768);
  await shot('web_1920x1080.png', 1920, 1080);
  await shot('web_2560x1600.png', 2560, 1600);

  const errs = events.filter((e) => e.method === 'Runtime.exceptionThrown' || e.method === 'Log.entryAdded' || (e.method === 'Runtime.consoleAPICalled' && e.params.type === 'error'));
  console.log('ERROR_EVENTS', errs.length, JSON.stringify(errs.slice(-8), null, 2));
}

if (process.env.CDP_CLOSE === '1') { try { await send('Browser.close'); } catch {} }
ws.close();
