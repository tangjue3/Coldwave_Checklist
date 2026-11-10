// 页面视觉自查：截主视图 / 参考图 / 缺口 / 灯箱（含版本对照与序列播放器）
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
await shot('artlib_v2_main.png');

// 参考图视图
await evalJs("[...document.querySelectorAll('#tabs .tab')].find(t=>t.dataset.v==='refs').click()");
await sleep(400);
await shot('artlib_v2_refs.png');

// 缺口视图
await evalJs("[...document.querySelectorAll('#tabs .tab')].find(t=>t.dataset.v==='gaps').click()");
await sleep(300);
await shot('artlib_v2_gaps.png');

// 回到素材，打开 r09（版本对照 + 序列帧）
await evalJs("[...document.querySelectorAll('#tabs .tab')].find(t=>t.dataset.v==='assets').click()");
await sleep(300);
const i = await evalJs("(()=>{const D=JSON.parse(document.getElementById('asset-data').textContent);return D.findIndex(d=>d.id==='ART_CHAR_001'&&d.version==='r09')})()");
await evalJs(`document.querySelectorAll('#grid .card')[${i}].click()`);
await sleep(500);
await shot('artlib_v2_modal_r09.png');

// 播放序列
await evalJs("document.querySelector('#play').click()");
await sleep(700);
await shot('artlib_v2_play.png');

// 标记筛选：视觉质量待优化
await evalJs("document.querySelector('#close').click()");
await evalJs("[...document.querySelectorAll('#chips .chip')].find(c=>c.dataset.t==='视觉质量待优化').click()");
await sleep(300);
await shot('artlib_v2_filter_visual.png');
console.log('done');
ws.close();
