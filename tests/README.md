# 测试

## 桌面启动自检

```bash
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- --shot=smoke.png --quit
```

由 `scenes/dev/test_scene.tscn` 触发，检查 24 项：引擎版本、视口、像素渲染设置、6 个输入动作、全局 Theme 与中文字体（含 36 个特殊字符的字形）、长文本换行、按钮字体继承、许可证随包、UI 控件边界、资源可加载、发布窗口未写死尺寸。

- 退出码 `0`：全部通过
- 退出码 `1`：存在失败项，终端里以 `[SMOKE][FAIL]` 标出

### 窗口适配

```bash
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- --profile=1366x768 --mode-cycle --shot=win.png --quit
```

`--profile` 支持 `1366x768` / `1920x1080` / `2560x1600` 等；超过本机桌面时只做数值推演并打印说明，不会强行改窗口。
`--mode-cycle` 依次测试 windowed → maximized → fullscreen → windowed，并恢复默认窗口，控制台以 `[WINDOW]` 输出尺寸、位置、是否贴合、内部视口。
`--hold=<秒>` 可让窗口停留，便于抓操作系统级截图；`F10` 切最大化、`F11` 切全屏。

## Web 冒烟测试

```bash
# 1) 导出
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Web" builds/web/index.html
# 2) 本地 HTTP（补 .wasm MIME）
python tools/serve_web.py
# 3) 另开终端：带 --remote-debugging-port=9333 --headless=new 的 Chrome
node tools/web_smoke_cdp.mjs
```

脚本会等待 Godot 引擎真正就绪、派发 `E` 键，并在 1366×768 / 1920×1080 / 2560×1600 三种视口下截图，最后汇总浏览器控制台错误。详见 `docs/工程复现说明.md` 第 5 节。

## screenshots/

保留每次启动的截图，用于**渲染回归对比**：改动渲染设置、缩放模式、字体或导出预设后，前后两张图应当肉眼一致。
目录内有 `.gdignore`，Godot 不会把截图当资源导入。

| 前缀 | 来源 |
|---|---|
| `prep002_` / `win_` | 引擎内 960×540 视口截图 |
| `desktop_` / `hold_` | 操作系统桌面级截图 |
| `web_` | 浏览器 CDP 截图 |

## 后续（不在本阶段）

无 UI 的逻辑测试要能脱离画面运行，直接用 `godot --headless --script` 执行：
购物车结算、库存增减、抗寒/供电结算、剧情 flag 分支、存档读档一致性。
这些测试等对应系统实现后再建，本阶段不预写空壳；**正式存档逻辑按要求尚未实现**。
