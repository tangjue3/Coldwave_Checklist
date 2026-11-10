// 页面视觉自查（ART-RESET-001 版）：素材网格 / 视频参考图 / 角色动作状态 / v02 灯箱 / 裁图灯箱
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const PORT = process.env.CDP_PORT || '9444';
const ROOT = process.cwd().replace(/\\/g, '/');
const PAGE = pathToFileURL(path.join(process.cwd(), '素材库', '美术总览.html')).href;
const OUT = `${ROOT}/tests/screenshots`;

const targets = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json();
const page = targets.find((t) => t.type === 'page');
const ws = new WebSocket(page.webSocketDebuggerUrl);
const pending = new Map();
let seq = 0;
ws.onmessage = (e) => { const m = JSON.parse(e.data); if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); } };
await new Promise((r) => { ws.onopen = r; });
const send = (method, params = {}) => new Promise((res) => { const id = ++seq; pending.set(id, res); ws.send(JSON.stringify({ id, method, params })); });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const evalJs = async (expression) => (await send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true })).result?.result?.value;
const shot = async (name) => {
  const r = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
  fs.mkdirSync(OUT, { recursive: true });
  fs.writeFileSync(`${OUT}/${name}`, Buffer.from(r.result.data, 'base64'));
  console.log('截图', name);
};

await send('Page.enable');
await send('Runtime.enable');
await send('Page.navigate', { url: PAGE });
await sleep(1400);
await shot('artlib_reset_main.png');

// 分类「角色」→ 只剩 v02
await evalJs("[...document.querySelectorAll('#nav li')].find(li=>li.dataset.c==='角色').click()");
await sleep(300);
await shot('artlib_reset_character.png');
await evalJs("document.querySelector('#nav li').click()");

// 视频参考图 + 裁图
await evalJs("[...document.querySelectorAll('#tabs .tab')].find(t=>t.dataset.v==='refs').click()");
await sleep(500);
await shot('artlib_reset_refs.png');

// 裁图灯箱（朝右全身）
await evalJs("[...document.querySelectorAll('.refitem')].find(e=>e.dataset.label==='朝右全身').click()");
await sleep(400);
await shot('artlib_reset_crop_lightbox.png');
await evalJs("document.querySelector('#close').click()");

// 角色动作状态
await evalJs("[...document.querySelectorAll('#tabs .tab')].find(t=>t.dataset.v==='gaps').click()");
await sleep(300);
await shot('artlib_reset_actions.png');

// v02 灯箱
await evalJs("[...document.querySelectorAll('#tabs .tab')].find(t=>t.dataset.v==='assets').click()");
await sleep(300);
const i = await evalJs("(()=>{const D=JSON.parse(document.getElementById('asset-data').textContent);return D.findIndex(d=>d.id==='ART_CHAR_001'&&d.version==='v02')})()");
await evalJs(`document.querySelectorAll('#grid .card')[${i}].click()`);
await sleep(500);
await shot('artlib_reset_v02_modal.png');
console.log('done');
ws.close();
