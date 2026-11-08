// PREP-003 Web 启动与场景切换验收（Chrome CDP）
//
// 前置：python tools/serve_web.py 在 8060；带 --remote-debugging-port=9333 的 Chrome 无头运行。
// 用法：node tools/check_prep003_web.mjs
import fs from 'node:fs';
import path from 'node:path';

const PORT = process.env.CDP_PORT || '9333';
const PAGE = 'http://127.0.0.1:8060/index.html?t=' + Date.now();
const OUT = path.join(process.cwd().replace(/\\/g, '/'), 'tests/screenshots');

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
const check = (name, ok, extra = '') => { results.push({ name, ok }); console.log(`${ok ? 'OK  ' : 'FAIL'} ${name} ${extra}`); };

await send('Page.enable');
await send('Runtime.enable');
await send('Log.enable');
await send('Network.enable');
await send('Network.setCacheDisabled', { cacheDisabled: true });
await send('Emulation.setDeviceMetricsOverride', { width: 1366, height: 768, deviceScaleFactor: 1, mobile: false });
await send('Page.navigate', { url: PAGE });

let ready = false;
for (let i = 0; i < 120; i++) {
  await sleep(500);
  if (await evalJs("!document.getElementById('status')")) { ready = true; break; }
}
check('Web 引擎启动完成', ready);
await sleep(1500);

async function shot(name) {
  const r = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
  fs.mkdirSync(OUT, { recursive: true });
  fs.writeFileSync(path.join(OUT, name), Buffer.from(r.result.data, 'base64'));
  console.log('  截图', name);
}
await shot('prep003_web_menu.png');

// 画布内的游戏坐标 → CSS 像素：整数倍缩放 + 居中黑边
const geom = JSON.parse(await evalJs(`JSON.stringify((function(){
  var c=document.getElementById('canvas');var r=c.getBoundingClientRect();
  var w=r.width,h=r.height;var s=Math.max(1,Math.min(Math.floor(w/960),Math.floor(h/540)));
  return {x:r.left+(w-960*s)/2,y:r.top+(h-540*s)/2,s:s,w:w,h:h};
})())`));
console.log('  画布映射', JSON.stringify(geom));
const clickGame = async (gx, gy) => {
  const x = geom.x + gx * geom.s, y = geom.y + gy * geom.s;
  for (const type of ['mousePressed', 'mouseReleased']) {
    await send('Input.dispatchMouseEvent', { type, x, y, button: 'left', clickCount: 1 });
  }
  await sleep(900);
};

// 主菜单「开发测试入口」→ 面板「超市空场景」→ Esc 返回主菜单
await clickGame(480, 357);
await shot('prep003_web_devpanel.png');
await clickGame(780, 214);
const worldLog = logs().some((l) => l.includes('[WORLD] ready key=supermarket'));
check('Web 内点击可切换到超市场景', worldLog);
await shot('prep003_web_supermarket.png');

await send('Input.dispatchKeyEvent', { type: 'keyDown', key: 'Escape', code: 'Escape', windowsVirtualKeyCode: 27, nativeVirtualKeyCode: 27 });
await send('Input.dispatchKeyEvent', { type: 'keyUp', key: 'Escape', code: 'Escape', windowsVirtualKeyCode: 27, nativeVirtualKeyCode: 27 });
await sleep(900);
const menuLogs = logs().filter((l) => l.includes('[MENU] 主菜单就绪'));
check('Web 内 Esc 可返回主菜单', menuLogs.length >= 2, `(菜单就绪日志 ${menuLogs.length} 条)`);
await shot('prep003_web_return_menu.png');

const errs = errors();
check('无浏览器控制台错误', errs.length === 0, `(${errs.length} 条)`);
check('无 [SMOKE][FAIL]', !logs().some((l) => l.includes('[SMOKE][FAIL]')) && !errs.some((e) => JSON.stringify(e).includes('[SMOKE][FAIL]')));

const failed = results.filter((r) => !r.ok);
console.log(`\n结果：${results.length - failed.length}/${results.length} 通过`);
ws.close();
if (failed.length) process.exitCode = 1;
