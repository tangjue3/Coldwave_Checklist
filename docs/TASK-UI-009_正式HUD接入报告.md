# TASK-UI-009 · 正式 HUD 接入报告

日期：2026-11-13　分支：`界面与UI`　执行：本地 Agent

本轮把 TASK-UI-007 / 008 里验证过的 HUD 从「开发预览」搬进正式游戏场景：
素材升为运行时可用、组件整理成可复用场景、接进第一季街道与 12 个室内、
交互提示改到屏幕空间、快捷栏与今日清单接上按键。

**没有做的事**：购物 / 背包 / 建造 / 存档 / 时间 / 生存 / 任务系统一律未开发；
主菜单未改；全局 `main_theme.tres` 未合并；白色盒场景未改。

---

## 一、素材批准与台账

### 1.1 进度条 r02（美术明确批准）

| ID | 版本 | 文件 | 原状态 | 现状态 |
|---|---|---|---|---|
| `ART_UI_041` | `r02` | 轨道 78×12 | 待审核 | **运行时可用** |
| `ART_UI_042` | `r02` | 填充 74×8 | 待审核 | **运行时可用** |
| `ART_UI_041` | `r01` | 270×22 | 待审核 | 保留追溯，未接入 |
| `ART_UI_042` | `r01` | 255×12 | 待审核 | 保留追溯，未接入 |

### 1.2 其余 HUD 素材（视觉初审通过 + 实机验收后逐项升）

**升「运行时可用」共 33 条**，都是在正式 HUD 里真实上屏、且本轮实机验收过的：

- 面板 7 张：`ART_UI_006` 地点 / `007` 日期时间 / `008` 天气 / `009` 今日清单 /
  `010` 生存状态 / `011` 资源条 / `012` 交互提示
- 快捷栏 2 条：`ART_UI_015` `r01` 普通态、`r02` 选中态
- 图标 21 枚：`ART_UI_016`–`024`、`026`–`032`、`034`–`038`
- 控件 3 件：`ART_UI_039` 空键帽、`ART_UI_041` `r02` 轨道、`ART_UI_042` `r02` 填充

**保持「待审核」8 条**（本轮没有上屏，不跟着一起升）：

| ID | 文件 | 原因 |
|---|---|---|
| `ART_UI_013` | Toast 面板 | 弹层组件，等对应界面开发 |
| `ART_UI_014` | Tooltip 面板 | 同上 |
| `ART_UI_015` `r03` | 快捷栏禁用态 | 正式 HUD 无禁用格 |
| `ART_UI_025` | 图标出口 | 未出现在任何模块 |
| `ART_UI_033` | 图标设置 | 未出现在任何模块 |
| `ART_UI_040` | 霜纹分隔 | 暂未使用 |
| `ART_UI_041` `r01` | 旧轨道 | 尺寸不匹配，r02 取代 |
| `ART_UI_042` `r01` | 旧填充 | 同上 |

台账校验：`check_id_registry.py` 全绿（77 号 / 75 行）；`audit_artlib.py` 运行时可用
**48 条**，失败 **119** 项、警告 53 —— 与改动前基线完全一致（119 项全部来自
`02-场景` 场景资产的既有口径冲突）。

### 1.3 运行时资源目录

```
assets/ui/hud/candidates_v01/   ← 删除（试做阶段的目录名）
assets/ui/hud/v01/              ← 33 张，全部已在台账登记运行时路径
```

只放**真的上屏**的 33 张；未使用的 8 张只留在素材库。这样 `assets/` 里没有孤儿文件，
也不会出现「运行时有、台账没有」的情况。

---

## 二、正式 HUD 场景

```
scenes/ui/hud/game_hud.tscn      CanvasLayer(layer=20) → Root(Control 960×540)
scripts/ui/hud/game_hud.gd       组件逻辑 + 自检 verify()
scripts/ui/hud/hud_source.gd     数据源接口（契约）
scripts/ui/hud/hud_source_live.gd  正式数据源
scripts/ui/hud/hud_source_mock.gd  测试数据源
```

模块与坐标沿用 TASK-UI-007/008 已审核的版式，**一个像素没动**：

| 模块 | 位置 | 尺寸 |
|---|---|---|
| 地点 / 日期时间 / 天气 | (12,10) (241,10) (390,10) | 216×35 / 136×35 / 130×35 |
| 今日清单 | (14,57) | 216×152（收起 216×35） |
| 生存状态 | (732,57) | 216×164 |
| 快捷栏 6 格 | (335,480) 起，步距 49 | 45×45 |
| 交互提示 | (12,490) | 178×35 |
| 资源条 | (706,490) | 242×35 |

对外 API（供以后接正式系统）：

```gdscript
hud.refresh()                       # 重新拉一次数据
hud.set_source(src)                 # 换 HudSource 实现
hud.select_slot(3)                  # 快捷栏
hud.set_tasks_collapsed(true)       # 今日清单
hud.show_prompt("进入 外婆老宅")     # 交互提示
hud.bind_sensor(sensor)             # 绑定场景里的 InteractionSensor
```

节点名保持稳定（`LocationText` / `TasksPanel` / `StatFill0` / `Slot3` …），
以后写自动化测试不用改选择器。

---

## 三、真实数据与测试数据的隔离

### 3.1 现在真的有数据的东西

| HUD 字段 | 来源 | 性质 |
|---|---|---|
| 地点 | `GameState.location`（SceneRouter 切场景时写入；场景自己也在 `_ready` 声明一次） | **正式数据** |
| 交互提示 | 场景里真实的 `Interactable.prompt_text()` + 门的 `door_label` | **正式数据** |
| 快捷栏选中格 | HUD 自己的 UI 状态 | 真状态（不是数据） |

### 3.2 还没有系统的，一律走 Mock

`HudSourceLive.snapshot()` 里：地点读 `GameState`，其余五个字段整块取自
`HudSourceMock`，并把 `mock = [datetime, weather, tasks, status, resources, hotbar]`
原样返回。HUD 拿到这份清单后：

- 右上角常驻一枚角标：**「测试数据：时间·天气·生存·物资·任务·快捷栏」**；
- `verify()` 里也会把字段名打出来。

也就是说：**屏幕上每一个假数字旁边都有标记，不会让人误以为时间/生存/任务已经做完。**
以后哪个系统做完了，把对应字段改读正式数据、并从 `mock` 里删掉即可，HUD 场景不用动。

### 3.3 数据源契约

```gdscript
class_name HudSource extends RefCounted
func snapshot() -> Dictionary   # location / datetime / weather / tasks / status / resources / hotbar / mock
```

开发预览用同一份契约换数据（`class VariantSource extends HudSource`），
所以「预览里能跑的」和「正式场景里跑的」是同一套 HUD，不存在两套版式漂移。

---

## 四、接入点

| 位置 | 改动 |
|---|---|
| `scenes/world/season1_map.tscn` | 新增 `HUD` 实例（`game_hud.tscn`），CanvasLayer 层，编辑器里可见 |
| `scripts/world/rd1_world.gd` | `_wire_hud()` 绑定 InteractionSensor；`GameState.set_location()`；开发工具条默认隐藏、F1 召唤；数字键从镜头预设里让出 |
| `scripts/world/interior_room.gd` | 进室内也用同一套 HUD（代码实例化，不改 12 个 .tscn，避免碰手工微调过的布局）；地点名取本场景 `display_name` 的缩写 |
| `scripts/interaction/interaction_sensor.gd` | 新增 `draw_world_prompt`（默认 true），正式场景里关掉世界坐标提示，避免双重提示 + 0.7× 缩放下 9px 小字 |
| `scenes/dev/hud_preview.tscn` | 改成实例正式 HUD，只保留背景与六态样张；`--values=b` / `--no-text` / `--bar-demo` / `--cam-zoom` 保留 |

**按键**（正式游戏内）：

| 键 | 作用 |
|---|---|
| `A` / `D` | 行走 |
| `E` | 交互 |
| `1`–`6` | 快捷栏切换 |
| `T` | 今日清单展开 / 收起（点标题栏同样有效） |
| `F1` | 开发工具条（镜头 / 标尺 / 干净模式），默认收起 |
| `F2`–`F5` | 自由镜头 / 标尺 / 隐藏文字标注 / 建筑名 |

数字键原本是镜头预设（1 跟随 / 2 全景 / 3 整街 / 4 名字），本轮让给快捷栏，
镜头预设仍在 F1 工具条里点按钮。

---

## 五、实机测试

### 5.1 `tools/hud_e2e.gd`（新增，15 项全通过）

在真实 `season1_map` 里跑，不 mock 场景：

```
OK   HUD 在 CanvasLayer(layer=20)，与相机坐标系无关
OK   HUD 逻辑分辨率 960×540
OK   世界坐标提示已关闭，提示只在 CanvasLayer 里画一份
OK   地点来自 GameState.location → 「梧桐里 · 长街」
OK   右上角标出「测试数据 · 时间 / 天气 / 任务 / 生存 / 物资 / 快捷栏」
OK   交互提示「进入 A/B 外婆小楼」（来自真实热点 Door_IntA）
OK   离开热点后提示消失
OK   数字键 3 切到第 3 格，选中态贴图已切换
OK   数字键 6 切到第 6 格
OK   T 键收起：面板 216×35、任务行隐藏、贴图换成短面板
OK   再按 T 展开：面板 216×152、贴图恢复
OK   点击标题栏同样可收起
OK   相机 zoom 0.7→1.6，生存状态面板位置与尺寸完全不变
PASS
```

快捷键是**真按键**：用 `Input.parse_input_event` 造 `InputEventKey` 送进视口，
不是直接调函数。

### 5.2 既有回归

| 测试 | 结果 | 说明 |
|---|---|---|
| `--dev-scene=smoke` | **26 / 26 通过** | 与改动前一致 |
| `tools/int_verify.gd` | **PASS** | 室内结构未被破坏（HUD 是运行时加的，不写进场景文件） |
| `tools/door_e2e.gd` | FAIL 1 | **改动前就是 FAIL 1**：A/B 门热点中心在 x=2377.5，门框在 2050，TASK-UI-001 已记录，本轮未改 |

### 5.3 交互提示的已知边界

- 街道 12 扇门的热点大部分**相对门框右偏**（A/B 偏 327.5px，K/L/B2 也偏几百）。
  这是场景数据问题，不是 HUD 问题：HUD 只是如实显示「当前锁定了哪个热点」。
  站在门框前看不到提示，走到热点位置才会出现。**需要单独一批任务修热点坐标**，
  本轮没有擅自改场景（会动到已验收的关卡数据）。
- 室内进门即站在出口热点内，仍会立刻出现「进入 梧桐里长街」——老问题，同上。

---

## 六、截图

| 文件 | 内容 |
|---|---|
| `tests/screenshots/ui009_prompt.png` | 960×540 实机整屏：街道 + HUD + 交互提示「进入 A/B 外婆小楼」 |
| `tests/screenshots/ui009_tasks_open.png` | 今日清单展开态 |
| `tests/screenshots/ui009_tasks_closed.png` | 今日清单收起态（换成短面板，圆角完整） |
| `tests/screenshots/ui009_notext.png` | 去文字，只看面板 / 图标 / 进度条 |
| `tests/screenshots/ui009_int_a.png` | 室内（外婆老宅）实机：同一套 HUD，地点自动换成室内名 |
| `tests/screenshots/hud009_tasks_2x.png` | 今日清单 2× |
| `tests/screenshots/hud009_status_2x.png` | 生存状态 2× |
| `tests/screenshots/hud_v03_preview.png` | 开发预览（正式 HUD + 六态样张） |
| `tests/screenshots/hud_v03_bars_4x.png` | 进度条六态 4×：100/72/64/46/5/0% |
| `tests/screenshots/hud_v03_values_b.png` | 第二套极端数据（5% / 100% / 8% / 39.9/40） |
| `tests/screenshots/ui009_editor.png` | 编辑器：`game_hud.tscn` 场景树 + 视口 |

---

## 七、已知问题 / 待裁定

1. **门的交互热点偏移**（见 5.3）——影响所有门的可用性，建议单独开一轮改场景数据。
2. **今日清单收起用的是「地点栏」短面板贴图**（同为 432×70）。风格一致、圆角完整，
   但它严格来说不是为清单设计的；若要专属的「清单收起条」，需要美术补一张。
3. **测试数据角标**占据画面右上角。若美术总监认为干扰，可用
   `show_mock_badge = false` 关掉——但那样就没有「这些不是真数据」的可见提示了。
4. **底部黑边**：街道相机在 0.7× 下能看到人行道以下，这是场景既有构图，不是 HUD 造成。
5. 快捷栏图标与数量仍是 Mock（没有背包系统），换格子只切换选中态，不触发任何物品行为。

---

## 八、提交与复现

```
feat(ui): TASK-UI-009 正式 HUD 接入第一季街道与室内
```

复现命令：

```bash
# 正式 HUD 实机截图（窗口模式，不能 --headless）
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tools/hud_shots.gd

# 端到端测试
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/hud_e2e.gd

# 开发预览
Godot_v4.7.2-stable_win64_console.exe --path . -- --dev-scene=hudprev --bar-demo --quit
```
