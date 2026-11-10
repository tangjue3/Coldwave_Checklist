// CORE-001B Web 端交互验收（Chrome CDP）
//
// 前置：
//   python tools/serve_web.py                      # 8060，服务 builds/web
//   chrome --headless --remote-debugging-port=9333  # 无头 Chrome
// 用法：
//   node tools/check_core001b_web.mjs
//
// 检查点（比 CORE-001A 多了一整层「真按键触发交互」）：
//   1. Web 版能用 URL 参数直接进 core001b，不依赖命令行；
//   2. 量测行与桌面端一致（可见 41×160 / 碰撞 28×160 / 脚底误差 0 / 镜像偏移 0）；
//   3. 靠近车时 [HINT] 打印「E 推购物车」——提示是画在画布里的，只能靠这行断言；
//   4. 真按 E：PARKED→PUSHING；再按 E：PUSHING→PARKED（键盘路径与 request_interact 一致）；
//   5. 门场景：靠近打印「E 进入」，按 E 后真的切到 shelter 空场景；
//   6. 控制台无 error；顺带截一张 960×540 的 Web 画面。
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

// 真键盘事件：Godot 读的是 code/physical key，所以 code 必须是 KeyE
const pressE = async () => {
  const base = { windowsVirtualKeyCode: 69, nativeVirtualKeyCode: 69, code: 'KeyE', key: 'e' };
  await send('Input.dispatchKeyEvent', { type: 'keyDown', ...base, text: 'e' });
  await sleep(80);
  await send('Input.dispatchKeyEvent', { type: 'keyUp', ...base });
};

const restart = async (state) => {
  events = [];
  await send('Page.navigate', { url: `${URL_BASE}?dev=core001b&state=${state}&t=${Date.now()}` });
  for (let i = 0; i < 120; i++) {
    await sleep(500);
    if (await evalJs("!document.getElementById('status')")) return true;
  }
  return false;
};

await send('Page.enable');
await send('Runtime.enable');
await send('Log.enable');
await send('Network.enable');
await send('Network.setCacheDisabled', { cacheDisabled: true });
// 只设 cacheDisabled 不够：Godot 自己 fetch index.pck，浏览器仍可能复用旧包，
// 导致「改了代码但跑的还是上一版」，必须先清一次磁盘缓存。
await send('Network.clearBrowserCache');
await send('Emulation.setDeviceMetricsOverride', { width: 960, height: 540, deviceScaleFactor: 1, mobile: false });

// ---------------------------------------------------------------- A. 购物车
check('Web 引擎启动完成（车场景）', await restart('cart'));
await sleep(2500);
// 点一下画布，确保键盘事件进 Godot 的 canvas
await send('Input.dispatchMouseEvent', { type: 'mousePressed', x: 480, y: 270, button: 'left', clickCount: 1 });
await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: 480, y: 270, button: 'left', clickCount: 1 });
await sleep(600);

let all = logs();
let text = (frag) => all.some((l) => l.text.includes(frag));
check('URL 参数生效：出现 [CORE] 量测行', all.filter((l) => l.text.includes('[CORE]')).length >= 4);
check('可见包围盒 = 41×160', text('41×160'));
check('碰撞盒 = 28×160', text('28×160'));
check('脚底误差 = 0', text('脚底误差 = 0'));
check('朝左镜像偏移 = 0（绘制补偿生效）', text('差 0.0 px'));
check('靠近停放的车 → 提示「E 推购物车」', text('目标=CartHotspot 提示=E 推购物车'));

await pressE();
await sleep(700);
all = logs();
check('真按 E → PARKED→PUSHING（[CART] bind）', all.some((l) => l.text.includes('[CART] bind')));

// 推车期间按住右键：ART-INTEGRATE-003 起绑定时播的是扶车姿态 push_idle（r03 单帧），
// 不再是行走四帧 —— 因为本批没有交扶车行走循环，这是已知过渡限制。
await send('Input.dispatchKeyEvent', { type: 'keyDown', windowsVirtualKeyCode: 68, nativeVirtualKeyCode: 68, code: 'KeyD', key: 'd', text: 'd' });
await sleep(900);
await send('Input.dispatchKeyEvent', { type: 'keyUp', windowsVirtualKeyCode: 68, nativeVirtualKeyCode: 68, code: 'KeyD', key: 'd' });
await sleep(300);
all = logs();
// ART-RESET-001：角色贴图已删除，PlayerController 不再输出 [ANIM] 日志。
// 这里改为断言"确实没有动画在播"，而不是假装旧动画还在。
const animLines = all.filter((l) => l.text.includes('[ANIM]')).map((l) => l.text);
check('绑定推车后没有任何角色动画日志（旧动画已退役）',
  animLines.length === 0,
  animLines.join(' | ').slice(0, 120) || '无 [ANIM] 输出，符合预期');

await pressE();
await sleep(700);
all = logs();
check('再按 E → PUSHING→PARKED（[CART] unbind）', all.some((l) => l.text.includes('[CART] unbind')));

// 停放后走动应该回到行走四帧，确认扶车姿态没有把普通行走也顶掉
await send('Input.dispatchKeyEvent', { type: 'keyDown', windowsVirtualKeyCode: 68, nativeVirtualKeyCode: 68, code: 'KeyD', key: 'd', text: 'd' });
await sleep(800);
await send('Input.dispatchKeyEvent', { type: 'keyUp', windowsVirtualKeyCode: 68, nativeVirtualKeyCode: 68, code: 'KeyD', key: 'd' });
await sleep(300);
all = logs();
const animAll = all.filter((l) => l.text.includes('[ANIM]')).map((l) => l.text);
check('停放后走动仍无角色动画日志（行走渲染待新动画接入）',
  animAll.length === 0,
  animAll.join(' | ').slice(0, 160) || '无 [ANIM] 输出，符合预期');

const errsA = errors();
check('车流程控制台无 error', errsA.length === 0,
  errsA.length ? JSON.stringify(errsA[0].params).slice(0, 200) : '');

const shotA = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
fs.mkdirSync(OUT_DIR, { recursive: true });
fs.writeFileSync(path.join(OUT_DIR, 'core001b_web_cart.png'), Buffer.from(shotA.result.data, 'base64'));

// ---------------------------------------------------------------- B. 门
check('Web 引擎启动完成（门场景）', await restart('door'));
await sleep(2200);
all = logs();
check('靠近有效门 → 提示「E 进入」', all.some((l) => l.text.includes('目标=HouseDoor 提示=E 进入')));

await pressE();
await sleep(1400);
all = logs();
check('按 E → 触发 SceneRouter 切换（[DOOR] 触发）', all.some((l) => l.text.includes('[DOOR] 触发')));
check('已进入 shelter 空场景（[WORLD] ready key=shelter）',
  all.some((l) => l.text.includes('[WORLD] ready key=shelter')), '');

const errsB = errors();
check('门流程控制台无 error', errsB.length === 0,
  errsB.length ? JSON.stringify(errsB[0].params).slice(0, 1400) : '');

const shotB = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
fs.writeFileSync(path.join(OUT_DIR, 'core001b_web_door.png'), Buffer.from(shotB.result.data, 'base64'));
console.log('截图：', path.join(OUT_DIR, 'core001b_web_cart.png'), ' / core001b_web_door.png');

const failed = results.filter((r) => !r.ok);
console.log(`\n结果：${results.length - failed.length}/${results.length} 通过`);
ws.close();
if (failed.length) process.exitCode = 1;
