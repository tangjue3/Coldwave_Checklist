# PREP-002 阶段测试报告

> 日期：2026-11-08　｜　任务：字体、窗口适配、Web 导出、版本复现、v1.1 文档接收
> **正式玩法开发仍全部暂停**：未写剧情、物品数值、购物、建造、结算、存档。

## 0. 汇报摘要

| 项 | 内容 |
|---|---|
| 任务编号 | PREP-002 |
| 实际完成 | 任务 1–5 全部完成（任务 5 的冲突清单已输出，未改代码） |
| 尚未完成 | 无（另有 3 项环境限制，见 §6） |
| 工程路径 | `D:/work/bisai/Hackathon/GAME/Coldfront_Checklist` |
| 仓库 | https://github.com/tangjue3/Coldwave_Checklist（public，main） |
| Git commit | `chore: PREP-002 ...`（本次提交，见 `git log -1`） |
| 实际 Godot | `4.7.2.stable.official.ed1daf0bf` |
| 如何启动 | README「快速开始」；完整换机步骤见 `工程复现说明.md` |
| 已运行测试 | 桌面自检 24/24 × 4 次；窗口模式切换 3 组；Web 冒烟 24/24 × 3 视口 |
| 截图 | `tests/screenshots/`（引擎内、桌面级、浏览器级三类，见 §7） |

---

## 1. 任务 1：正式中文字体

| 项 | 结果 |
|---|---|
| 字体 | Noto Sans SC 可变字重 TTF，17,772,300 字节，来自 Google Fonts 官方仓库 |
| 授权 | SIL OFL 1.1，`assets/ui/fonts/OFL.txt` 随工程与 Web 包分发；来源、用途、SHA-256 见 `assets/ui/fonts/README.md` |
| 导入 | `.ttf.import` 中 `allow_system_fallback=false`，缺字不会被系统字体悄悄补齐 |
| Theme | `assets/ui/themes/main_theme.tres`（default_font / Label / RichTextLabel / LineEdit / Button 四态 / Panel），由 `scripts/dev/generate_ui_theme.gd` 生成 |
| 挂载 | `project.godot` → `gui/theme/custom`；**Godot 4.7 的设置名是 `gui/theme/custom`，没有 `custom_theme`**（已实测确认） |

**实测验证**（`tests/screenshots/prep002_default.png`）：

- 中文标题「寒潮清单 · 字体 / 窗口 / 输入自检」、三行中文对白、三个按钮文字全部正常，无方块、无乱码。
- 特殊字符 36 字逐字用 `Font.has_char()` 检查，**缺字 0**：含 `−43°C ¥1,200 ±5% 「」『』《》…— ①②③ →←↑↓ ℃ ㎡ ½ αβγ ×÷＝ 【】`。
- 长文本在 468px 宽标签内自动换成 3 行，未裁切。
- 按钮的 `get_theme_font()` 与 Theme.default_font 是同一对象，确认继承生效。
- 字体名回读为 `Noto Sans SC Thin`（可变字体默认实例名，不是错误）。

## 2. 任务 2：窗口适配

**发布版不再固定 1920×1080**：`project.godot` 删除了 `window_width/height_override`，启动时由 `scripts/dev/window_fit.gd` 读取窗口所在显示器的可用区域，选能放进去的最大整数倍并居中。

本机是双显示器（实测值）：

| 显示器 | 尺寸 | 虚拟坐标 | 可用区域 |
|---|---|---|---|
| #0（竖屏） | 1067×1707 | (0,0) | 1067×1659 |
| #1（主屏） | 1920×1080 | (1600,0) | 1920×1032 |

默认自适应结果：可用区域 1920×1032 → 最大整数倍 **1×** → 窗口 960×540，位置 (2080,246)，判定「贴合、未超屏」。

### 三种目标环境

| 目标 | 本机能否实测 | 实际结果 |
|---|---|---|
| **1366×768** | 能（小于可用区域） | 窗口设为 1366×768 @ (1877,132)，`fits=YES`；整数倍 1× 渲染 960×540 居中，四周留黑边；视口恒为 960×540，无裁切 |
| **1920×1080** | 部分（正是本机主屏物理分辨率） | 窗口化 1920×1080 会高于可用高度 1032，被任务栏遮挡，因此**不实际设置窗口**，改做数值推演：整数倍 2× 渲染 1920×1080 居中留边；真实覆盖通过全屏模式验证（见下） |
| **2560×1600** | 否（本机无此显示器） | 只做数值推演：整数倍 2× 渲染 1920×1080 居中留边；**未做真机实测**，列为限制 |

### 窗口 / 最大化 / 全屏切换（`--mode-cycle`）

| 步骤 | 窗口尺寸 | 位置 | 判定 | 内部视口 |
|---|---|---|---|---|
| windowed | 1366×768 | (1877,132) | fits=YES | 960×540 |
| maximized | 1920×1009 | (1600,23) | fits=YES | 960×540 |
| fullscreen | 1920×1080 | (1600,0) | fits=YES | 960×540 |
| windowed_again | 1366×768 | (1877,132) | fits=YES | 960×540 |
| restored（恢复默认） | 1366×768 | (1877,132) | fits=YES | 960×540 |

三种分辨率跑完，24 项自检均通过；所有模式下内部视口恒为 960×540，UI 控件越界数 0。

**UI 是否模糊**：桌面级截图按 1:1 裁切检查（`desktop_window_1366x768.png`、`desk_native_1x.png` 对比），文字边缘锐利、按钮描边清晰，没有插值发虚；窗口非整数倍尺寸时以黑边代替拉伸，因此不会糊化。Web 端 1920×1080 为精确 2×、1366×768 为 1× + 黑边，同样保持整数倍。

**过程中修掉的一个真实 bug**：初版把窗口居中写成 `screen_size/2`，忽略多显示器的虚拟坐标原点，窗口被摆到竖屏上并误报「超出桌面」。已改为 `usable_rect.position + (usable_rect.size - window_size)/2`，另外全屏时用整屏矩形而非可用区域判断超屏（全屏本来就会盖住任务栏）。

## 3. 任务 3：Web 导出冒烟测试

### 导出配置与包体积

- Godot 4.7.2 / GL Compatibility / **`variant/thread_support=false`（默认单线程）**
- `export_presets.cfg` 已提交；`export_filter=all_resources`，`include_filter` 显式包含 `assets/ui/fonts/OFL.txt`
- 导出命令：`godot --headless --path . --export-release "Web" builds/web/index.html`

| 文件 | 字节 | 占比 |
|---|---:|---:|
| `index.wasm` | 39,514,754 | 37.68 MiB |
| `index.pck` | 16,161,576 | 15.41 MiB |
| `index.js` | 279,815 | 0.27 MiB |
| `index.html` + 图标 / worklet | ~54,000 | ~0.05 MiB |
| **合计** | **56,010,484 B（53.42 MiB / 56.0 MB，未压缩）** | 100% |

`.pck` 里主要是完整 Noto Sans SC 字库与两张画风参考图。启用 gzip/brotli 的正式站可显著缩小传输体积。

### 目标浏览器与测试方法

| 项 | 值 |
|---|---|
| 浏览器 | **Google Chrome 157.0.8103.38**（`--headless=new`，SwiftShader / WebGL2） |
| 本地服务 | `python tools/serve_web.py` → `http://127.0.0.1:8060`（补 `application/wasm` MIME） |
| 自动化 | Chrome DevTools Protocol，`tools/web_smoke_cdp.mjs` |

Chrome 的 `--screenshot` + `--virtual-time-budget` 会在 WASM 编译完成前截到 Godot 加载页，所以改用 CDP 等待引擎就绪、模拟按键、逐视口截图。另一个坑：Godot 4.7 的 HTML 模板就绪时是 **`remove()` 掉 `#status` 覆盖层**，不是设成 hidden，就绪判断必须查「元素不存在」。

### 实测结果

| 检查 | 结果 |
|---|---|
| 浏览器加载 | 引擎启动完成，`#status` 移除，无 JS 异常；控制台错误 0 条（修复许可证后） |
| 中文字体 | 标题 / 对白 / 特殊字符 / 按钮全部正常，无方块（字体随包分发，不依赖系统） |
| 窗口适配 | 1366×768 → 1× + 黑边；1920×1080 → 精确 2× 铺满；2560×1600 → 2× + 黑边；三种都无裁切、无拉伸 |
| 基本输入 | 通过 CDP 派发 `E` 键，右侧「输入回显」显示 `最近输入：E / 匹配动作：interact` |
| Web 端自检 | **通过 24 项 / 失败 0 项** |
| 存档 | 按要求**未实现**任何正式存档逻辑 |

**导出过程中发现并修复的问题**：

1. `OFL.txt` 不是 Godot 资源，`all_resources` 默认不会打进 `.pck`，Web 自检报 `[SMOKE][FAIL] OFL.txt 随工程分发`。已在 `include_filter` 中加入该文件并重新导出，复测 24/24 通过、控制台错误 0。这也是把许可证检查写进自检的价值。
2. `export_filter="scenes"` 需要额外 `export_files` 清单，命令行导出会报 `Must select at least one file to export`；改用 `all_resources` + `exclude_filter`。
3. 浏览器缓存会让人误以为修复没生效，CDP 脚本已启用 `Network.setCacheDisabled` 并给 URL 加时间戳。

## 4. 任务 4：工程复现

`docs/工程复现说明.md` 已写好，包含：

- 指定版本 `4.7.2.stable.official.ed1daf0bf`、官方下载页与发布页
- 两个官方资产的 SHA-256 与字节数（编辑器 `7319…a953`，模板 `f298…a011`）
- 三种校验方式：`Get-FileHash` / `sha256sum` / `godot --version` / `Help > About`
- 新电脑 5 步：克隆 → 放引擎到 `.tools/godot/` → 导入 `project.godot` → 跑自检 → （可选）装模板
- 导出模板完整安装路径（Windows / macOS / Linux），以及只取 Web 模板的省流量脚本 `tools/fetch_web_templates.py`
- 明确列出哪些要提交（`*.import`、`*.uid`、`export_presets.cfg`、字体与许可证），哪些不提交（引擎、`.godot/`、`builds/web/`、`*.zip`）

**没有把 180MB 引擎程序提交到 Git**。

## 5. 任务 5：v1.1 补充包

- 原始 zip 已解包到 `docs/handover_v1.1/`（4 份 md + 3 张概念图），并加了 `.gdignore` 避免引擎把文档图当资源导入。
- 与 v1.0 的关系、ID 统计、9 条冲突（C1–C9）、数据结构影响、4 条建议、3 个待决策问题，全部写在 `docs/v1.1_冲突清单与建议.md`。
- 最关键的发现：**v1.1 美术台账的素材 ID `S01–S11` 与剧情事件 ID 100% 撞名**（`S01–S06` 撞 v1.0 支线，`S07–S11` 撞 v1.1 支线），其中 `S10` 在三份文档里是三个不同含义；以及 P07B 的延迟订单需要扩展 `pending_delivery` 状态机。
- **没有把任何新剧情、物品、设施或数值写进 `data/`、脚本或场景**。

## 6. 已知问题 / 限制 / 风险

| # | 类型 | 说明 | 建议 |
|---|---|---|---|
| 1 | 限制 | 本机没有 2560×1600 显示器，该档只做了数值推演，未真机实测 | 后续在有该分辨率的机器上跑一次 `--profile=2560x1600 --mode-cycle` |
| 2 | 限制 | 浏览器只实测 Chrome 157 无头（SwiftShader）；Edge / Firefox 未测 | 正式试玩版发布前补一轮真实浏览器 |
| 3 | 限制 | 1080p 桌面扣除任务栏后只容得下 1× 窗口（960×540），画面偏小 | 后续给用户提供 1× / 2×（2× 走全屏或无边窗）切换设置 |
| 4 | 风险 | Web 包 56MB 未压缩，其中约 15MB 是完整中文字库 | 正式版考虑子集化（注意 OFL 保留字体名规则）或按文本动态收集字形；并启用服务器压缩 |
| 5 | 风险 | 单线程 Web 不需要 COOP/COEP；若以后开启线程支持，静态服务器必须补响应头 | 见 `开发说明.md` §8 |
| 6 | 环境 | 无头 Chrome 出现过 `GPU stall due to ReadPixels` 性能警告（SwiftShader 软件渲染），不是游戏错误 | 真机浏览器复测即可 |
| 7 | 设计 | v1.0 的资金/容量/AP 三约束失效、抗寒阈值偏低问题，v1.1 仍未处理 | 见 `data/README.md` 与冲突清单 C4 |
| 8 | 流程 | v1.1 `06` 假定 INIT-001 已做「标题菜单 + 空超市 + 空安全屋 + GameState/SaveManager 空接口」，实际未做；其「当前唯一任务是 INIT-001」也已落后一轮 | 以用户下发的任务编号为准，需另行批准补做 |

## 7. 截图清单

| 文件 | 内容 |
|---|---|
| `prep002_default.png` | 引擎内 960×540 自检画面：字体 / 特殊字符 / 长文本 / 按钮 / 窗口信息 / 24 项通过 |
| `win_1366x768.png` / `win_1920x1080.png` / `win_2560x1600.png` | 三种 profile 的引擎内截图 |
| `desktop_1366x768.png` | 双显示器桌面全量截图 |
| `desktop_window_1366x768.png` | 桌面级游戏窗口裁切，可见 1× 居中黑边 |
| `web_1366x768.png` / `web_1920x1080.png` / `web_2560x1600.png` | Chrome 中三种浏览器视口，含 `E → interact` 输入回显与 24/0 自检结果 |

## 8. 需要总策划决定的问题（最多 3 项）

1. 素材 ID 是否统一改为 `ART_Snn` 前缀（或语义化 ID），以消除与剧情 ID 的撞名？
2. 下一批任务是「补 3 个空场景 + GameState/SaveManager 空接口」，还是直接进入 CORE-001 横版移动？
3. 黑客松演示目标采用 v1.0 的 8–15 分钟纵切，还是 v1.1 的 7 项 P0 清单？

---

**停止条件已满足**：PREP-002 全部任务完成并提交。未经下一阶段任务批准，不开始购物、建造、生存结算和正式剧情实现。
