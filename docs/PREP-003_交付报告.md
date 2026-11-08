# PREP-003 基础场景框架与工程修复 · 交付报告

> 日期：2026-11-08　｜　前置：ARTLIB-001（已验收）　｜　引擎 `4.7.2.stable.official.ed1daf0bf`
> 本轮继续**禁止正式玩法开发**；购物 / 建造 / 经济数值 / 存档 / 剧情执行 / 第二季均未开发。
> 任务执行期间收到总策划追加指令：收录 `ART_CHAR_001_v02`，并同步 S10 命名裁定，均已并入本轮交付。

## 1. Git

| 项 | 内容 |
|---|---|
| 仓库 | https://github.com/tangjue3/Coldwave_Checklist |
| 实现提交 | `__SHA__` |
| 分支 | `main`，已推送 `origin/main` |
| 工作区 | 干净 |

## 2. 新增场景及脚本清单

### 场景（3 个新增正式场景 + 1 个保留）

| 场景 | 说明 |
|---|---|
| `scenes/menu/main_menu.tscn` | **正式启动入口**：《寒潮清单》标题；新游戏 / 继续游戏（禁用）/ 设置 / 开发测试入口 / 退出；含隐藏的开发测试面板 |
| `scenes/world/supermarket.tscn` | 超市占位空场景 |
| `scenes/world/shelter.tscn` | 安全屋占位空场景 |
| `scenes/dev/test_scene.tscn` | 原有启动自检场景，改为**独立运行** |

### 脚本

| 脚本 | 作用 |
|---|---|
| `scripts/autoload/ui_theme.gd` | 运行时把 `main_theme.tres` 挂到根窗口（首次导入修复的核心） |
| `scripts/autoload/game_state.gd` | 最小状态契约：只存 `location` 与 `location_changed` 信号 |
| `scripts/autoload/save_manager.gd` | 存档接口空实现：`has_save/can_continue/save_game/load_game/status` |
| `scripts/autoload/scene_router.gd` | 唯一场景切换白名单 + 开发 CLI（`--dev-scene` / `--scene-tour` / `--shot` / `--quit`） |
| `scripts/ui/main_menu.gd` | 主菜单入口逻辑；Web 退出改为提示关闭标签页 |
| `scripts/world/placeholder_world.gd` | 两个空场景共用的占位控制器（显示结构说明、返回主菜单） |
| `scripts/dev/startup_smoke.gd` | 修改：主题检查改为验证运行时挂载，新增「项目级 custom theme 已移除」回归项 |
| `tools/build_artlib.py` | 修改：`repo_link` 支持 `转存库/`；ID 修订版头部同步 S10 裁定 |
| `tools/check_artlib_page.mjs` | 修改：期望值改为从内嵌数据推导，新增 v02 / v01 / 运行时路径检查，灯箱固定打开 v02 |
| `tools/check_prep003_web.mjs` | **新增**：Web 启动、点击切场景、Esc 返回、控制台错误验收 |

### 配置

- `project.godot`：`run/main_scene` → `main_menu.tscn`；删除 `gui/theme/custom`；新增 4 个 autoload；版本 `0.3.0`。
- 字体 / 视口 / 输入 / 渲染设置**一项未改**。

## 3. 首次字体导入问题的修复结果

### 复现与定位（独立副本，非本机缓存）

在 `D:/prep003_repro`（`git clone` 的全新副本、无 `.godot/`）执行第一次 `--headless --import`，得到 **7 条 ERROR**：

```
ERROR: Cannot open file 'res://.godot/imported/NotoSansSC-Variable.ttf-...fontdata'.
ERROR: Failed loading resource: res://assets/ui/fonts/NotoSansSC-Variable.ttf.
ERROR: res://assets/ui/themes/main_theme.tres:118 - Parse Error: [ext_resource] referenced non-existent resource ...
ERROR: Error loading custom project theme 'res://assets/ui/themes/main_theme.tres'
   at: initialize_theme (scene/theme/theme_db.cpp:74)
```

**根因**：Godot 4.7 的 `ThemeDB::initialize_theme()` 在**资源导入之前**从 `project.godot` 读取 `gui/theme/custom` 并加载主题；
主题通过 `res://assets/ui/fonts/NotoSansSC-Variable.ttf` 引用字体，而 `.ttf.import` 的 remap 目标
`res://.godot/imported/*.fontdata` 此时尚未生成。属于引擎初始化顺序与项目级主题的组合限制。

### 修复（不是"跑两次"）

- 从 `project.godot` 移除 `gui/theme/custom`（对照实验：仅移除这一行，全新副本第一次导入 ERROR 从 7 → **0**）。
- 新增 `UiTheme` autoload，在运行时 `get_tree().root.theme = load("res://assets/ui/themes/main_theme.tres")`。
  `load()` 而非 `preload()`，避免脚本扫描阶段提前解析主题。
- 主题文件、字体文件、字体导入参数、显示效果**完全不变**；自检新增两项防止把设置加回来。

### 独立全新工程副本验证

`D:/prep003_final_fresh` 由当前工作树打包复制（排除 `.git` / `.godot` / `.tools` / `builds`），无导入缓存：

| 检查 | 结果 |
|---|---|
| 第一次 `--headless --import` ERROR 数 | **0** |
| `素材库/` + `转存库/` 内 `.import` 数 | **0** |
| `.godot/` 缓存中出现素材库/转存库 | **无** |
| 副本内运行自检 | **26/26 通过** |
| 同一副本第二次导入 ERROR 数 | **0**（仅作对照，不是修复手段） |

未采用「运行两次」绕过；也未改动字体、主题内容、窗口或输入系统。

## 4. 三张运行截图

| 截图 | 内容 |
|---|---|
| `tests/screenshots/prep003_menu.png` | 主菜单：标题、5 个入口、继续游戏明显禁用、底部提示 |
| `tests/screenshots/prep003_supermarket.png` | 超市占位空场景：结构说明、节点预留、返回按钮 |
| `tests/screenshots/prep003_shelter.png` | 安全屋占位空场景：结构说明、暖光占位、返回按钮 |

补充：`prep003_default_launch.png`（无参数默认启动）、`prep003_smoke.png`（自检）、
`prep003_window_1366.png`（窗口回归）、`prep003_web_menu.png` / `prep003_web_supermarket.png` /
`prep003_web_return_menu.png`（Web 端）。

**不使用任何未经审核的概念图作为背景**；三个场景只有纯色占位与文字。

## 5. Windows / Web 启动测试结果

### Windows（桌面）

| 测试 | 结果 |
|---|---|
| 默认启动 = 主菜单 | `active_scene=res://scenes/menu/main_menu.tscn`，`continue_disabled=true` |
| 启动自检 | **26/26 通过**，中文 / 36 个特殊字符 / 按钮字体继承 / 许可证全部 OK |
| 场景切换巡检 | 菜单 → 超市 → 安全屋 → 菜单，**4 次切换 0 失败**，`GameState.location` 同步正确 |
| 窗口回归 1366×768 | windowed / maximized / fullscreen / 还原全部 `fits=YES`，视口恒 960×540 |
| 模式切换 | F10 最大化、F11 全屏、Esc 从空场景返回主菜单均可用 |

### Web（Chrome 157 headless + CDP，本地 HTTP）

`tools/check_prep003_web.mjs` **5/5 通过**：

| 检查 | 结果 |
|---|---|
| Web 引擎启动完成（单线程 / Compatibility） | 通过 |
| 画布内点击「开发测试入口」→「超市空场景」 | 通过（控制台出现 `[WORLD] ready key=supermarket`） |
| Esc 返回主菜单 | 通过（`[MENU] 主菜单就绪` 日志 2 次） |
| 无浏览器控制台错误 | 通过（0 条） |
| 无 `[SMOKE][FAIL]` | 通过 |

Web 主菜单截图显示中文正常、960×540 内容以 **1× 整数缩放居中、四周黑边**，无裁切。

### Godot 隔离与导出

- 新增 `转存库/.gdignore`（与 `素材库/.gdignore` 同规则），避免新投递的 PNG 被 Godot 扫描/导出。
- 重新导入后 `素材库/` + `转存库/` 内 `.import` = 0，`.godot/` 缓存无相关记录。
- Web 导出成功；PCK 字节级扫描 `ART_CHAR_001` / `ART_CHAR_001_v02` / `五视图设定候选` /
  `素材库` / `转存库` / `美术总览.html` / `素材台账.csv` / `.thumbs/` **全部 clean**。
- PCK：16,140,892 → **16,164,684 B**（+23,792 B，来自新增场景/脚本/autoload，非素材库图片）；
  Web 包总计 56,010,737 B。

## 6. 现有自检是否全部通过

| 项目 | 结果 |
|---|---|
| 桌面启动自检（26 项） | ✅ 全通过 |
| 窗口适配 / 模式切换 | ✅ 全通过 |
| 场景切换巡检 | ✅ 4/4 |
| 离线美术预览页自动验收 | ✅ 11/11（6 条记录、v02 状态、v01 保留、运行时路径全空） |
| Web 启动与场景切换 | ✅ 5/5 |
| 独立全新副本第一次导入 | ✅ 0 ERROR |
| 素材库 / 转存库 隔离 | ✅ 未导入、未导出 |

## 7. 任务二～四与追加指令落实

### 主菜单

中文标题、5 个入口齐全；「继续游戏」在场景中 `disabled=true`，脚本再用
`SaveManager.can_continue()`（恒 false）兜底并给出 tooltip；「新游戏」「设置」只显示说明文字，不启动玩法；
Web 端「退出」改为提示关闭标签页。沿用 `main_theme.tres` 的临时基础 UI 样式，960×540 + 整数缩放不变。

### 两个空场景与未来资产接入点

每个空场景的节点结构完全一致：`Environment / Props / Actors / InteractionAreas / Camera2D / UI(CanvasLayer)/HUDPlaceholder`。

| 场景节点 | 未来接入内容 | 建议目录 |
|---|---|---|
| `Environment/` | TileMapLayer、背景与视差、窗外雪景 / 建筑剖面 tileset | `assets/tiles/` |
| `Props/` | 货架、商品、已安装设施、可见物资堆叠 | `assets/items/`、`assets/facilities/` |
| `Actors/` | 主角与 NPC 的 spritesheet / 动画 | `assets/characters/` |
| `InteractionAreas/` | 收银台 / 门 / 设备触发区（Area2D） | 场景内定义 |
| `Camera2D` | 跟随与边界 | 场景内定义 |
| `UI/HUDPlaceholder` | HUD、购物车、建造网格、对话框 | `assets/ui/` |

切换统一走 `SceneRouter.goto(key)` 白名单；Esc 或「返回主菜单」按钮安全返回。
**没有**放入正式家具 / 商品 / 角色动画，**没有**实现购物 / 库存 / 建造 / 天气 / 剧情推进。

### 预留接口

`GameState` 只保存 `location`（工程级），明确注释不保存任何玩法数值；
`SaveManager` 全部方法为空实现且不读写文件。第一季经济平衡、购物数据、剧情条件、存档 schema 均未设计。

### 追加指令：ART_CHAR_001_v02

- `转存库/ART_CHAR_001_v02_许知夏_五视图设定候选.png` 与设定说明 MD **各复制一份**到
  `素材库/美术设定集/01-角色/`（SHA-256 一致），`转存库/` 原件保留。
- 台账新增 v02 行：`审核状态 = 已通过设定审核`，设为第一季角色外观基准；`对应运行时资源路径` 为空，
  动画字段全空；明确「不是可运行 Sprite Sheet / 不制作动画 / 不接入正式游戏场景」。
- v01 保留为**历史备选版本**，独立一行、不覆盖不删除，名称加注「（历史备选）」，状态仍为 `待审核`。
- 重建 `.thumbs/` 与 `美术总览.html`（6 条记录）；离线页验收 11/11。
- `ID对照表.md`、`候选索引.md`、`素材库/README.md`、`01-角色/README.md` 同步基准说明。

### 命名同步（任务六）

| 名称 | 裁定 |
|---|---|
| 剧情 `S10` | 第一季支线《一个放错的箱子》 |
| 美术「电台/手机特写背景」 | `ART_SCENE_109` |
| v1.1 `00`「`S10` 必须保留门口通路」 | **指剧情 S10** |

已同步 `素材库/ID对照表.md` §4、`docs/v1.1_冲突清单与建议.md`、
`docs/ARTLIB-001_交付报告.md` 与 ID 修订版头部；
`docs/handover_v1.0/02`、`docs/handover_v1.1/00`、`docs/handover_v1.1/04` **剧情文档一字未改**。

## 8. 本轮遗留问题

| # | 类型 | 说明 |
|---|---|---|
| 1 | 未实现（按要求） | 存档系统：新游戏 / 继续游戏 / 设置界面 / 正式玩法流程均为入口占位 |
| 2 | 待批准 | `ART_CHAR_001_v02` 已通过**设定审核**，但不是运行时资源；进入 `assets/characters/` 仍需单独批准、像素精修、帧对齐与动画 QA |
| 3 | 待批准 | 主角站立 / 行走 / 交互 / 搬运动画、GIF/APNG 预览、方向帧；本轮一律未生成 |
| 4 | 限制 | Web 端「退出」只能提示关闭标签页（浏览器无法主动退出） |
| 5 | 环境 | 无头 Chrome 的 SwiftShader 偶发 `GPU stall due to ReadPixels` 性能警告，非游戏错误 |
| 6 | 流程 | `SceneRouter` 的开发 CLI（`--dev-scene` / `--scene-tour`）只用于验证，正式发行前可保留但不应暴露给玩家 |
| 7 | 旧限制 | 1080p 桌面扣除任务栏只容 1× 窗口；2560×1600 仍无真机；Firefox/Edge 未测 |

---

**PREP-003 到此停止。未进入 CORE-001，未开发任何正式玩法。等待下一条任务。**
