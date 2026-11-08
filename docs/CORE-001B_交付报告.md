# CORE-001B · 门 / 货架交互与购物车推行状态 — 交付报告

| 项 | 内容 |
|---|---|
| 任务 | CORE-001B（门 / 货架交互 + 购物车 PARKED / PUSHING 骨架） |
| 前置 | CORE-001A 报告与截图审核通过；保留 Godot 4.7.2 / 960×540 / 32px tile / 160px 人物 / 128×176 画布 / (64,168) 脚底锚点 |
| 状态 | 已完成，**停在报告**。未进入 CORE-002 采购、未开始 ART-RUNTIME-002 动画 |
| 工程侧提交 | `456eeba77ab3088e69377b28d832669b5902265b`（`feat: CORE-001B 门/货架交互与购物车推行状态`） |

---

## 1. 一分钟结论

1. **门 / 货架已经是背景层 + Area2D 热点**，不是碰撞缺口。走近出中文提示（`E 进入` / `E 查看`），按 E 才触发；
   装饰门有节点但**不显示提示、按 E 无任何作用**。
2. **购物车停放时不再是硬墙**：它没有任何物理体，玩家从左、右两侧都能直接走过去（实测停滞 0 帧）。
   只有前后两层绘制制造"侧身绕过"的观感，**世界坐标里的行走线一条都没动**。
3. **推行是一套刚体组合**：绑定瞬间确定相对侧位，之后永不翻面；推速 80、反向 40（拉着走）；
   撞墙整组停住（车右沿 1700 = 墙左沿 1700），仍可按 E 解绑。
4. **朝左 1px 偏移已修**，且只动绘制偏移（`sprite.offset`），碰撞盒与世界坐标完全不变（实测 28×160、x 不变）。

---

## 2. 三条建模结论（数字来自实机，不是估计）

### 2.1 门必须是"热点"，不是"通行缺口"

CORE-001A 把门框当实体时人物停在 x=286，永远进不了门洞（门洞在 308–388）。原因不是碰撞参数错，
而是**严格侧视里门是墙面元素**：玩家从门前走过，x 方向不存在"穿过门洞"这回事。

本轮把门、超市入口、货架全部放到背景层（无碰撞体），只保留 Area2D 热点；碰撞层只留给
真正站在行走线上的东西（购物车推行时按字面参与阻挡、世界两端墙、撞墙测试墙）。

### 2.2 停放的车不能挡路，但推行时又要真的被墙挡住

这两个要求看似矛盾，解法是**碰撞体只存在于"组合体"的合法性判断里，而不是挂在车上**：

- 车始终是 `Node2D`，没有 `CollisionShape2D` / `StaticBody2D`，所以停放时对玩家完全透明；
- 推行时每帧用「1px 子步 + 矩形 `intersect_shape`」同时检查**车矩形**与**玩家矩形**是否与世界实体重叠，
  两边都合法才前进。撞墙时整组停在"最后一个合法位置"，因此既不会穿墙，也不会把玩家挤到另一侧。

实测：车从 1480 推到 `右沿 1700`（墙左沿 1700）停住；解绑后玩家能自由后退 60px，没有锁死。

### 2.3 「侧身绕过」只能是绘制层级，不能改行走线

车的前后两层是 `z=0`（篮体底）/ `z=1`（近侧护栏），玩家 `z=0` 且后入树，于是玩家从车上走过时
腿部被前景护栏压住、身体在篮体之前，读起来就是"人在车后面"。
**这只是绘制顺序**：碰撞、坐标、行走线一个都没改，也正因为如此，本任务没有被扩成 2.5D 双轴移动。

---

## 3. 交互契约（轻量，不造框架）

```
Interactable (Area2D)        提示文案 / interact_priority / enabled / single_use / interact(actor)
├── DoorInteractable         target_scene + interactive（false = 装饰门）+ single_use
└── ShelfInteractable        note + 只发「查看」反馈
InteractionSensor (Node2D)   每物理帧选唯一目标、画提示、E 只派发一次
```

- 判定方式：`Area2D.overlaps_body(玩家)`，热点 `collision_layer=0`、`collision_mask=1`，**自身不产生任何阻挡**；
- 选目标：`interact_priority` 大者优先 → 同优先级比水平距离 → 距离差 <1px 用实例顺序兜底（防逐帧抖动）；
  当前购物车 20 > 门 10 > 货架 5；
- 门：`single_use=true`，触发前先 `enabled=false` 再 `SceneRouter.goto()`，同一帧连按第二次直接返回 null；
- 提示是画在世界坐标里的**正式 UI**，不受 F3 调试叠加层开关影响；字体取主工程主题的 `default_font`；
- 明确不做：交互状态机、条件系统、对话框架、剧情、经济。

---

## 4. 购物车状态机

| 状态 | 行为 | 数据 |
|---|---|---|
| `PARKED` | 无物理体，玩家可穿过；提示「E 推购物车」 | `side` 保留上次值但不参与计算 |
| `PUSHING` | 与角色成刚体组合，按输入推 / 拉；提示「E 停车」 | `side ∈ {+1,-1}` 绑定瞬间确定，永不翻面 |

- 绑定：`side = sign(玩家x − 车心x)`，玩家被对齐到 `车心 + side × 80`；
- 推行：车在玩家前方（`dir == −side`）用 `push_speed = 80`，反向（`dir == side`）用 `pull_speed = 40`，
  **相对侧位不变**，所以不存在"按反方向键车瞬移翻面"；
- 停放：车留在当前实际位置，玩家恢复正常移动，可从任意一侧走开；
- 撞墙：整组停住，`blocks_at_wall` 计数 +1，仍可按 E 解绑。

实测数据：绑定后间距 80.0；推行 60 帧位移 81px、速度 80.0；反向 30 帧速度 40.0、`side` 不变；
停车后 20 帧漂移 0.00px；再按 E 可重新绑定（循环成立）。

> **手感备注（需要总监确认）**：反向目前是"慢速后退 / 拉车"（40 px/s），没有做"转身绕到另一侧"。
> 这是按任务书里"如果无法可靠实现，先采用反向慢速后退并报告手感"的兜底方案做的。实测手感偏"拖重物"，
> 短距离调整够用，长距离倒退会显得笨重；若需要更自然的拉车，建议下一轮给 `pull_speed` 单独做加减速曲线。

---

## 5. 朝左 1px 偏移的修法

原图 alpha 包围盒是 `x=43 / 宽 41`、画布宽 128，左右留白不对称（左 43 / 右 44）。
水平镜像后包围盒落到 `x=44`，整体比原图右移 1px。

修法：`PlayerController.flip_draw_offset = Vector2(-1, 0)`，只在 `flip_h = true` 时叠加到 `sprite.offset`。
**不动碰撞盒、不动节点坐标**——用世界坐标补偿会让物理和视觉互相追着跑。

实测：可见框中心 右 `-0.5` / 左 `-0.5`，差 **0.0 px**；碰撞盒 `28×160` 与节点 x 在翻转前后完全一致（T8c）。

---

## 6. 验收用例（27 项全部通过）

| 编号 | 用例 | 实测结果 |
|---|---|---|
| T1a | 住宅门范围内 → 提示「E 进入」 | 通过，`target=HouseDoor` |
| T1b | 走出范围 → 提示消失 | 通过，`target=null` |
| T2a | 装饰门范围内 → 无提示 | 通过，`target=null`（截图 `core001b_deco_no_hint.png` 可见热点框但无提示） |
| T2b | 装饰门按 E → 无任何作用 | 通过（交互计数不变） |
| T3 | 热点范围外按 E | 通过，返回 null、无副作用 |
| T4a | 货架范围内 → 提示「E 查看」 | 通过 |
| T4b | 按 E → 输出查看反馈、不打开采购界面 | 通过，`toast=货架反馈：…每层净高 37px` |
| T4c | 从货架前水平走过 → 不被卡住 | 通过，850 → 1120，停滞 0 帧 |
| T5a | 从左穿过停放的车 | 通过，1010 → 1300，停滞 0 帧 |
| T5b | 从右穿过停放的车 | 通过，1300 → 1010，停滞 0 帧 |
| T6a | 靠近车 → 提示「E 推购物车」 | 通过 |
| T6b | 按 E → PARKED→PUSHING，间距 80 | 通过 |
| T6c | 推行速度 / 位移 | 80.0 px/s，60 帧位移 81px |
| T6d | 再按 E → PUSHING→PARKED | 通过，车停在 x=1213 |
| T6e | 停放后车不漂移 | 通过（20 帧 0.00px） |
| T6f | 循环：可重新绑定 | 通过 |
| T6g | 反向输入 → 侧位不变、不瞬移 | 通过（`side -1→-1`，速度 40.0） |
| T7a | 推车顶到实体墙 → 整组停住 | 通过，车右沿 1700 ≤ 墙 1700 |
| T7b | 撞墙后仍可按 E 解绑 | 通过 |
| T7c | 解绑后可自由后退 | 通过，后退 60px |
| T8a | 脚底误差 | 0.00 px |
| T8b | 朝左镜像可见框中心 | 右 -0.5 / 左 -0.5，差 0.0 |
| T8c | 镜像补偿不碰碰撞盒与世界坐标 | 通过 |
| T9a | 车与货架热点重叠 → 选车 | 通过（2 个候选，优先级 20 > 5） |
| T9b | 连续 12 帧目标不抖 | 通过 |
| T9c | 按 E 只触发一个 | 通过（计数 +1） |
| T10 | 相机参数未改动 | 死区 56×28 / 平滑 8.0 |

另有一组**门切换专项**（`--core-test-door`，33 项之外的独立流程）：

```
[DOOR-TEST] 靠近有效门 target=HouseDoor prompt=E 进入
[DOOR] 触发 住宅门 → shelter（res://scenes/world/shelter.tscn）actor_x=228
[DOOR-TEST] 首次派发=HouseDoor 连按第二次=null 切换次数 +1（期望 +1）
[DOOR-TEST] 已切换到 res://scenes/world/shelter.tscn  location=shelter  截图 err=0
```

即：有效门能切进现有空场景、`GameState.location` 同步、**连按不会重复加载**（第二次派发为 null）。

---

## 7. 截图（全部 960×540 原始逻辑分辨率）

| 文件 | 内容 |
|---|---|
| `core001b_door_prompt.png` / `_clean.png` | 住宅门提示「E 进入」（叠加层开 / 关） |
| `core001b_deco_no_hint.png` | 装饰门：有热点框、**无提示**，HUD 显示"热点 无" |
| `core001b_door_after.png` | 按 E 进门后自动截的安全屋空场景（验证真的切过去了） |
| `core001b_shelf_prompt.png` / `_clean.png` | 货架提示「E 查看」+ 底部「货架反馈」条 |
| `core001b_cart_bind.png` / `_clean.png` | 绑定后推行（车仍在通道内，间距 80，把手朝玩家） |
| `core001b_cart_pass.png` / `_clean.png` | 车 PARKED，玩家站在车上：前景护栏压腿，读出"在车后面" |
| `core001b_cart_wall.png` / `_clean.png` | 推车顶到实体墙，整组停住 |
| `core001b_web_cart.png` / `core001b_web_door.png` | Web 端同流程（真键盘 E） |

`*_clean.png` 是**去掉调试叠加层**的游戏视图，用于判断观感；带叠加层的那张用于核对热点范围与碰撞盒。

---

## 8. 回归与验收

| 项 | 结果 |
|---|---|
| Windows 启动自检 | **26/26** |
| 场景巡检（菜单→超市→安全屋→菜单） | **4/4**，失败 0 |
| 素材 ID 登记校验 | 37 个号（已用 17 / 预留 19 / 空置 1），全部通过 |
| 素材库离线页 | **21/21**（新增运行时白名单断言） |
| Web 端 CORE-001B 验收 | **15/15**（含真按键 E 的绑定/停放与进门切场景） |
| 导出 PCK | 16.33MB；`素材库` / `转存库` / 母图 / 4x 预览均**不在包内** |
| 未改动 | 世界尺寸、`assets/` 新增资源（仅沿用 r01 单帧）、剧情 / 存档 / 采购 / 建造 |

**白名单反向验证**：把 `ART_ITEM_101` 临时标成「运行时可用」后，素材页从 21/21 掉到 18/21，
并点名 `ART_ITEM_101`；随后已还原。

---

## 9. 顺手修的三个既有问题

### 9.1 Web 端换场景后中文全变方块（PREP-003 遗留，影响本轮门交互）

`get_tree().root.theme = …` 只对**当时已在树上**的节点完成传播。之后用 `change_scene_to_file` 载入的
新场景拿不到主题：桌面端有系统字体兜底所以看不出来，**Web 端没有兜底，占位页整页变方块**
（`tests/screenshots/prep003_web_supermarket.png` 就是那个状态）。

修法：`SceneRouter.goto()` 成功后 `UiTheme.reapply_after_scene_change()` —— 轮询等新场景挂上
（`current_scene` 会先变成 null，固定等一帧不够），再把主题递归挂到场景里所有"没有自己的 theme"的 Control。
只重挂 Window 级主题无效：已在树上的 Control 在入树时就绑定了 theme owner，不会重新解析字体。

### 9.2 交互提示文案不刷新

`CanvasItem` 的 draw 指令是**保留**的，只靠"目标变化时重绘"会让「E 推购物车」在车已经绑定后仍留在屏幕上
（HUD 显示「E 停车」、提示框显示「E 推购物车」，自相矛盾）。改为目标存在时每帧 `queue_redraw()`。

### 9.3 Web 上按 E 进门后报 `Condition "!is_inside_tree()" is true`

门在 `request_interact()` 内部就切了场景，本节点随之脱树，紧接着的 `get_viewport().set_input_as_handled()`
在 Web 的帧时序下会打到已脱树的节点。加 `is_inside_tree()` 保护即可。桌面端因为时序不同一直没暴露。

---

## 10. 需要总监拍板的问题

1. **反向手感**：目前是"慢速后退 / 拉车"（40 px/s），不是"转身绕到另一侧"。可接受，还是需要单独做
   拉车加减速与转身过渡？
2. **热点范围**：货架热点比货架本体左右各宽 48px（为了站在货架旁就能查看）。这个"宽容度"是否合适？
   门热点各宽 12px。范围太宽会出现"离得很远也能按 E"，太窄则要求像素级站位。
3. **单行走线上多个可交互物件**：本轮用优先级 + 距离解决重叠（车 20 > 门 10 > 货架 5）。
   若以后出现"两个同优先级且等距"的常见布局，是否需要一个"切换目标"的键（如 Tab）？
4. **推车时的遮挡层**：现在是纯 z 层切换；若后续要更真实的"侧身"，需要美术给推车姿态（属 ART-RUNTIME-002）。

---

## 11. 文件清单

新增：

```
scripts/interaction/interactable.gd          交互基类（Area2D）
scripts/interaction/door_interactable.gd     门热点
scripts/interaction/shelf_interactable.gd    货架热点
scripts/interaction/interaction_sensor.gd    目标选择 + E 派发 + 提示绘制
scripts/objects/pushable_cart.gd             购物车 PARKED / PUSHING
scripts/dev/core_001b.gd                     实验场景（世界 / 检查点 / 用例）
scripts/dev/core_001b_overlay.gd             叠加层（热点框 / 车盒 / 间距）
scripts/dev/door_switch_watcher.gd           门切换测试观察者（挂 root，抗场景销毁）
scenes/dev/core_001b.tscn
tools/check_core001b_web.mjs                 Web 交互验收（真键盘 E）
docs/CORE-001B_交付报告.md                    本文
tests/screenshots/core001b_*.png             13 张
```

修改：

```
scripts/characters/player_controller.gd  flip_draw_offset / external_control / input_axis / collision_height
scripts/autoload/scene_router.gd         core001b 入口、change_count、换场景后重挂主题
scripts/autoload/ui_theme.gd             主题重挂（force_reapply / apply_to / reapply_after_scene_change）
tools/check_artlib_page.mjs              运行时可用白名单断言
tools/check_core001a_web.mjs             补 Network.clearBrowserCache
素材库/素材台账.csv                        ART_CHAR_001 r01 → 运行时可用 / 单帧可用
素材库/ID对照表.md / 素材库/README.md      编号与运行时资质的说明
docs/开发说明.md                          §3 主题坑、§7.2 交互与推车、§8 命令
```

---

## 12. 复现命令

```bash
# 交互与推车用例（27 项，顺带产出 9 张截图）
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- --dev-scene=core001b --core-test

# 门切换专项（真实换场景 + 连按保护）
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- --dev-scene=core001b --core-test-door

# 5 组交互检查点，各截叠加层开/关两张
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- --dev-scene=core001b --core-tour --quit

# Web（先 python tools/serve_web.py + 9333 调试端口的 Chrome）
node tools/check_core001b_web.mjs
```
