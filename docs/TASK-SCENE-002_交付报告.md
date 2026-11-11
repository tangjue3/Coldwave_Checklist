# TASK-SCENE-002｜第一季横版场景白盒工程交付报告

- **任务编号**：`TASK-SCENE-002`
- **工作分支**：`场景制作`
- **引擎版本**：Godot `4.7.2.stable.official.ed1daf0bf`
- **工程基线**：逻辑视口 `960 × 540` · 世界格网 `32 × 32 px` · 角色可见高度 `160 px`（碰撞盒 `28 × 160 px`）

---

## 一、已阅读并对齐的项目文档与代码资料

### 1. 项目规划、设定与剧本资料
1. `素材库/README.md`
2. `素材库/素材台账.csv`
3. `素材库/美术设定集/00-美术总览/README.md`、`素材库/美术设定集/00-美术总览/风格规范摘要.md`
4. `素材库/美术设定集/02-场景/README.md`
5. `素材库/美术设定集/02-场景/第一季横版场景设计与提示词.md`（第一季横版空间结构、三段室外路线、14 处地标顺序、全部室内场景与扩展建议的主依据）
6. `素材库/美术设定集/07-世界观与剧情/README.md`
7. `素材库/美术设定集/07-世界观与剧情/第一季/第一季完整剧本.md`（核对 `P00..P08B` 主线、`D00..D08B` 支线、`S01..S12` 碎片及 `E01..E06` 结局的全部演出落点）
8. `docs/v1.1_冲突清单与建议.md`、`docs/开发说明.md`

### 2. 复用的现有工程组件（零破坏接入）
- **角色控制器与动画**：`scenes/characters/player.tscn`、`scripts/characters/player_controller.gd`（保留 `160 px` 可见高度、`28 × 160 px` 碰撞盒、`move_speed = 100.0`、`r10..r12` 行走动画与 `vid002` 推车候选动画）。
- **相机跟随组件**：`scripts/characters/follow_camera.gd`（保留死区与指数平滑逻辑，并在预览模式下扩展自由平移与 `1.0x / 0.5x` 缩放）。
- **交互与推车系统**：
  - `scripts/interaction/interactable.gd`、`scripts/interaction/interaction_sensor.gd`、`scripts/interaction/shelf_interactable.gd`
  - `scripts/interaction/door_interactable.gd`（扩展 `target_spawn_id` 以支持从室内不同出口精确返回室外对应门位，同时保持旧参数 100% 兼容）
  - 新增 `scripts/interaction/stair_interactable.gd`（支持同一双层建筑内 `1F y=416 ↔ 2F y=128` 真实垂直上下楼）
  - 新增 `scripts/interaction/spot_interactable.gd`（支持公告栏、门岗交换点、公交站、管制路口、清单桌、发电机底座、预约窗口等非门类交互点按 `E` 查看）
  - `scripts/objects/pushable_cart.gd`（复用 `ART_FURN_103 r03` Back/Cargo/Front 三层分件购物车）
  - 已批准运行时设施与物资贴图：`ART_FURN_101_r01` 四层金属货架（`96 × 192`）、`ART_ITEM_101_r02` 饮用水（`64 × 48` / `32 × 32`）、`ART_ITEM_102_r02` 应急食品箱（`64 × 64` / `32 × 32`）。

---

## 二、文档规定的场景与实际完成的场景对照表

| 文档代号 | 文档规定场景名称 | 级别 | 实际工程场景 Key | 场景文件路径 | 画布宽度 (px) | 楼层结构 | 完成状态 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **D/E/F/O/U/M/T/W** | 第一季室外主地图（三段连续长街） | 必做主图 | `outdoor_street` | `res://scenes/world/outdoor_street.tscn` | `15,360` | 1F 连续地面 (`y=416`) + 双层立面 + 屋顶观察位 | ✅ 已完成 |
| **A + B (+M/V)** | 外婆旧两层小楼 · 安全屋（一层 + 二层） | 必做核心 | `shelter` | `res://scenes/world/shelter.tscn` | `3,200` | **真实双层**：1F (`y=416`) + 2F (`y=128`)，木楼梯连通 | ✅ 已完成 |
| **C** | 小楼外置独立通风设备区 | 必做核心 | `equipment_room` | `res://scenes/world/equipment_room.tscn` | `1,920` | 1F 独立通风设备间 (`y=416`) | ✅ 已完成 |
| **G** | 梧桐里居民楼公共楼道 | 必做核心 | `apartment_hallway` | `res://scenes/world/apartment_hallway.tscn` | `2,400` | **真实双层**：1F 门厅 (`y=416`) + 2F 住户走廊 (`y=128`) | ✅ 已完成 |
| **P** | 赵阿姨与小满家室内 | 扩展建议 | `zhao_home` | `res://scenes/world/zhao_home.tscn` | `1,920` | 201 室独立内景 (`y=416`)，由居民楼 2F 进入 | ✅ 已完成 |
| **Q** | 陈叔维修角室内 | 扩展建议 | `repair_corner` | `res://scenes/world/repair_corner.tscn` | `1,920` | 1F 半开卷帘维修空间 (`y=416`) | ✅ 已完成 |
| **J** | 唐宁的街角便利店室内 | 必做核心 | `convenience_store` | `res://scenes/world/convenience_store.tscn` | `2,400` | 1F 便利店 (`y=416`)，含货架、冷柜、收银台与后方装饰门 | ✅ 已完成 |
| **N** | 社区药店内景 | 扩展建议 | `pharmacy` | `res://scenes/world/pharmacy.tscn` | `1,920` | 1F 药店内景 (`y=416`)，含等候椅、非处方架与药师台 | ✅ 已完成 |
| **H + S** | 灾前连锁超市（含 S 临时批发预约区） | 必做核心 | `supermarket` | `res://scenes/world/supermarket.tscn` | `5,760` | 1F 大型横版卖场 (`y=416`)，含 `192px` 主通道与 S 预约区 | ✅ 已完成 |
| **I** | 五金 / 家电店室内 | 必做核心 | `hardware_store` | `res://scenes/world/hardware_store.tscn` | `4,320` | 1F 商店 (`y=416`)，含工具墙、密封门样板、取暖/发电样机 | ✅ 已完成 |
| **K** | 独立批发仓与装卸区室内 | 必做核心 | `wholesale_warehouse` | `res://scenes/world/wholesale_warehouse.tscn` | `5,120` | 1F 仓储空间 (`y=416`)，左正门与右装卸门双入口独立对应 | ✅ 已完成 |
| **L** | 物流中转点 / 大件取货口室内 | 必做核心 | `logistics_hub` | `res://scenes/world/logistics_hub.tscn` | `2,880` | 1F 取货雨棚与交接窗口 (`y=416`) | ✅ 已完成 |
| **G(P00)** | 序章 P00 前世门外冰封走廊 | 必做独立点 | `past_corridor` | `res://scenes/world/past_corridor.tscn` | `1,920` | 1F 前世走廊 (`y=416`)，与居民楼公共楼道 G 明确区分 | ✅ 已完成 |

---

## 三、室外主地图总长度与 14 栋主要建筑位置表

- **室外主地图场景**：`res://scenes/world/outdoor_street.tscn`（`location_key = &"outdoor_street"`）
- **总长度**：`15,360 px`（`480 tiles` = `16` 个 `960×540` 逻辑视口），分为三段无缝连续的 `5,120 px` 街区，地面基线统一为 `GROUND_Y = 416.0 px`。

| 序号 | 所属分段 | 建筑节点 ID | 文档代号 | 建筑 / 地标名称 | 横向范围 X (px) | 尺寸 W×H (px) | 门洞中心 X | 门尺寸 (外框/净洞) | 美术替换槽位 (`art_slot`) |
| :---: | :--- | :--- | :---: | :--- | :--- | :--- | :---: | :---: | :--- |
| **①** | 第一段 (`0..5120`) | `b01_equip_bay` | **C** | 小楼外置独立设备区 | `160 .. 640` | `480 × 256` | `384` | `96×192` (`80×184`) | `ART_SCENE_EXT_C_EQUIP_BAY` |
| **②** | 第一段 (`0..5120`) | `b02_protagonist_house` | **A/B/D/M** | 外婆旧两层小楼与正门巷口 | `640 .. 1472` | `832 × 480` | `912` | `96×192` (`80×184`) | `ART_SCENE_EXT_AB_SAFEHOUSE` |
| **③** | 第一段 (`0..5120`) | `b03_notice_and_meng` | **F/R/W** | 社区主公告栏 & W 孟雨薇住处外观 | `1920 .. 2528` | `608 × 320` | `2048`(板) / `2384`(装饰门) | `96×192` (装饰门) | `ART_SCENE_EXT_FW_NOTICE_MENG` |
| **④** | 第一段 (`0..5120`) | `b04_apartment_building` | **F/T** | 梧桐里居民楼 & T 遮棚屋顶小狗位 | `2560 .. 3584` | `1024 × 512` | `3008` | `96×192` (`80×184`) | `ART_SCENE_EXT_FT_APARTMENT` |
| **⑤** | 第一段 (`0..5120`) | `b05_repair_corner` | **Q** | 陈叔维修角门面 | `3648 .. 4064` | `416 × 256` | `3856` | `96×192` (`80×184`) | `ART_SCENE_EXT_Q_REPAIR` |
| **⑥** | 第一段 (`0..5120`) | `b06_guard_booth` | **F/R** | 物业门岗 & R 临时信息/交换点 | `4128 .. 4544` | `416 × 256` | `4336`(查看点) | 窗口+交换桌 | `ART_SCENE_EXT_FR_GUARDBOOTH` |
| **⑦** | 第一段 (`0..5120`) | `b07_bus_stop` | **O** | 公交站与街角分界 | `4608 .. 5056` | `448 × 224` | `4864`(查看点) | 候车亭+站牌 | `ART_SCENE_EXT_O_BUSSTOP` |
| **⑧** | 第二段 (`5120..10240`) | `b08_convenience_store` | **J** | 唐宁的街角便利店（含 2F 唐母窗） | `5248 .. 5952` | `704 × 448` | `5568` | `96×192` (`80×184`) | `ART_SCENE_EXT_J_CONVENIENCE` |
| **⑨** | 第二段 (`5120..10240`) | `b09_pharmacy` | **N** | 社区药店门口 | `6080 .. 6784` | `704 × 288` | `6432` | `96×192` (`80×184`) | `ART_SCENE_EXT_N_PHARMACY` |
| **⑩** | 第二段 (`5120..10240`) | `b10_supermarket` | **H** | 灾前连锁超市外立面 | `6912 .. 8192` | `1280 × 352` | `7552` | `192×224` (`184×216`) | `ART_SCENE_101_EXT_SUPERMARKET` |
| **⑪** | 第二段 (`5120..10240`) | `b11_hardware_store` | **I** | 五金 / 家电店外立面 | `8320 .. 9344` | `1024 × 320` | `8784` | `96×192` (`80×184`) | `ART_SCENE_112_EXT_HARDWARE` |
| **⑫** | 第二段 (`5120..10240`) | `b12_traffic_checkpoint` | **U** | 临时管制路口（护栏+路牌） | `9472 .. 10176` | `704 × 256` | `9856`(查看点) | 龙门架+分流护栏 | `ART_SCENE_EXT_U_CHECKPOINT` |
| **⑬** | 第三段 (`10240..15360`) | `b13_wholesale_warehouse` | **K** | 独立批发仓与装卸区外立面 | `10432 .. 12480` | `2048 × 384` | `10880`(正门) / `12096`(装卸门) | `192×224` × 2 | `ART_SCENE_104_EXT_WAREHOUSE` |
| **⑭** | 第三段 (`10240..15360`) | `b14_logistics_hub` | **L** | 物流中转口 / 大件取货区 | `12736 .. 14592` | `1856 × 320` | `13440` | `96×192` (`80×184`) | `ART_SCENE_EXT_L_LOGISTICS` |

---

## 四、室内场景与出入口、楼层楼梯对应关系表

### 1. 门进出双向跳转关系（`DoorInteractable`）

| 起点场景 | 门节点名 | 起点门坐标 `(x, y)` | 目标场景 Key | 目标 Spawn ID | 目标落点坐标 `(x, y)` | 说明 |
| :--- | :--- | :---: | :--- | :--- | :---: | :--- |
| `outdoor_street` | `Door_door_equip_bay` | `(384, 416)` | `equipment_room` | `spawn_entrance` | `(256, 416)` | 室外设备区门 → C 设备间 |
| `equipment_room` | `Door_door_equip_exit` | `(256, 416)` | `outdoor_street` | `spawn_equip_gate` | `(384, 416)` | C 设备间 → 返回室外设备区门外 |
| `outdoor_street` | `Door_door_safe_house` | `(912, 416)` | `shelter` | `spawn_front_door` | `(2848, 416)` | 室外小楼正门 → A 安全屋 1F 玄关 |
| `shelter` | `Door_door_shelter_exit` | `(2848, 416)` | `outdoor_street` | `spawn_home_gate` | `(912, 416)` | A 安全屋 1F 玄关 → 返回室外小楼正门外 |
| `outdoor_street` | `Door_door_apartment_unit` | `(3008, 416)` | `apartment_hallway` | `spawn_unit_door` | `(256, 416)` | 室外居民楼单元门 → G 公共楼道 1F |
| `apartment_hallway` | `Door_door_hall_exit` | `(256, 416)` | `outdoor_street` | `spawn_unit_gate` | `(3008, 416)` | G 公共楼道 1F → 返回室外居民楼单元门外 |
| `apartment_hallway` (2F) | `Door_door_201_zhao` | `(1408, 128)` | `zhao_home` | `spawn_entrance` | `(256, 416)` | G 公共楼道 2F 201 门 → P 赵阿姨家室内 |
| `zhao_home` | `Door_door_zhao_exit` | `(256, 416)` | `apartment_hallway` | `spawn_zhao_door` | `(1408, 128)` | P 赵阿姨家 → 精确返回 G 居民楼 2F 201 门外 |
| `outdoor_street` | `Door_door_repair_corner` | `(3856, 416)` | `repair_corner` | `spawn_entrance` | `(256, 416)` | 室外维修角门 → Q 陈叔维修角 |
| `repair_corner` | `Door_door_repair_exit` | `(256, 416)` | `outdoor_street` | `spawn_repair_gate` | `(3856, 416)` | Q 陈叔维修角 → 返回室外维修角门外 |
| `outdoor_street` | `Door_door_convenience` | `(5568, 416)` | `convenience_store` | `spawn_entrance` | `(256, 416)` | 室外便利店门 → J 唐宁便利店 |
| `convenience_store` | `Door_door_conv_exit` | `(256, 416)` | `outdoor_street` | `spawn_conv_gate` | `(5568, 416)` | J 唐宁便利店 → 返回室外便利店门外 |
| `outdoor_street` | `Door_door_pharmacy` | `(6432, 416)` | `pharmacy` | `spawn_entrance` | `(256, 416)` | 室外药店门 → N 社区药店内景 |
| `pharmacy` | `Door_door_pharm_exit` | `(256, 416)` | `outdoor_street` | `spawn_pharm_gate` | `(6432, 416)` | N 社区药店内景 → 返回室外药店门外 |
| `outdoor_street` | `Door_door_supermarket` | `(7552, 416)` | `supermarket` | `spawn_entrance` | `(320, 416)` | 室外超市入口 → H 超市左端入口 |
| `supermarket` | `Door_door_market_in` / `out` | `(320, 416)` / `(5376, 416)` | `outdoor_street` | `spawn_market_gate` | `(7552, 416)` | H 超市入口/收银出口 → 返回室外超市门外 |
| `outdoor_street` | `Door_door_hardware` | `(8784, 416)` | `hardware_store` | `spawn_entrance` | `(288, 416)` | 室外五金店门 → I 五金/家电店 |
| `hardware_store` | `Door_door_hw_exit` / `loading` | `(288, 416)` / `(3968, 416)` | `outdoor_street` | `spawn_hardware_gate` | `(8784, 416)` | I 五金店正门/装货口 → 返回室外五金店门外 |
| `outdoor_street` | `Door_door_warehouse_main` | `(10880, 416)` | `wholesale_warehouse` | `spawn_entrance` | `(320, 416)` | 室外批发仓正门 → K 批发仓左入口 |
| `wholesale_warehouse` | `Door_door_wh_main_out` | `(320, 416)` | `outdoor_street` | `spawn_warehouse_gate` | `(10880, 416)` | K 批发仓左入口 → 返回室外批发仓正门外 |
| `outdoor_street` | `Door_door_warehouse_dock` | `(12096, 416)` | `wholesale_warehouse` | `spawn_loading_bay` | `(4736, 416)` | 室外批发仓装卸门 → K 批发仓右装卸区 |
| `wholesale_warehouse` | `Door_door_wh_dock_out` | `(4736, 416)` | `outdoor_street` | `spawn_warehouse_dock` | `(12096, 416)` | K 批发仓右装卸门 → 返回室外批发仓装卸门外 |
| `outdoor_street` | `Door_door_logistics_hub` | `(13440, 416)` | `logistics_hub` | `spawn_entrance` | `(288, 416)` | 室外物流中转口 → L 物流中转取货区 |
| `logistics_hub` | `Door_door_log_exit` | `(288, 416)` | `outdoor_street` | `spawn_logistics_gate` | `(13440, 416)` | L 物流中转取货区 → 返回室外物流中转口外 |
| `past_corridor` | `Door_door_past_to_present` | `(256, 416)` | `shelter` | `spawn_bed` | `(384, 416)` | G0 序章前世走廊 → A 现世安全屋 1F 卧床旁 |

### 2. 双层建筑内部楼梯垂直连接关系（`StairInteractable`）

| 所属场景 | 楼梯节点名 | 水平对齐坐标 X | 起始楼层与地面 Y | 目标楼层与地面 Y | 垂直高差 ΔY | 结构说明 |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| `shelter`（外婆两层小楼） | `Stair_stair_1f_to_2f` / `2f_to_1f` | `x = 2496` (宽 `128`) | `1F (y = 416)` | `2F (y = 128)` | `288 px` (`9 tile`) | 1F 净高 `256px` + 2F 楼板厚 `32px`，2F 真实位于 1F 正上方 |
| `apartment_hallway`（居民楼道） | `Stair_stair_hall_1f_2f` / `2f_1f` | `x = 608` (宽 `128`) | `1F (y = 416)` | `2F (y = 128)` | `288 px` (`9 tile`) | 1F 单元门厅通过楼梯上达 2F 住户走廊（201 赵阿姨家所在层） |

---

## 五、场景节点结构与开发预览工具

### 1. 标准场景树层级（所有 13 张场景统一）
```text
World (WhiteboxWorld)
├── Background          # 天空背景、远景灰冷城区天际线剪影 (ART_BG_SKYLINE_S1)、分段背景色带
├── Environment         # 1F(y=416) 与 2F(y=128) 地面/楼板、32px 地砖刻度、分层左右物理空气墙
├── Buildings           # Building_<id> 独立容器（挂有 art_slot 与 footprint_rect 元数据及 VisualSlot 子节点）
├── Props               # 真实运行时货架 (ART_FURN_101)、商品 (ART_ITEM_101/102)、购物车 (ART_FURN_103 r03) 与几何道具
├── Actors              # Player 实例（位于 Props 之后，严格满足购物车 Back < Player < Front 遮挡关系）
├── InteractionAreas    # DoorInteractable / StairInteractable / ShelfInteractable / SpotInteractable / Sensor
├── DebugOverlay        # WhiteboxDebugOverlay（F3 切换：32px 格网、地面线、建筑外框、门净洞、160px 角色标尺）
├── Camera2D            # FollowCamera（支持跟随角色与 F2 自由平移/缩放）
└── UI                  # 开发预览顶栏（13 场景切换、地标跳转）+ 底部全图缩略总览条 (WhiteboxMinimapStrip)
```

### 2. 开发预览快捷键与功能
- **顶栏场景切换**：一键在 `室外长街(主图)` 与全部 `12` 张室内场景之间直接切换。
- **地标快速跳转**：点击顶栏第二行地标按钮，或直接点击底部 `F5` 全图缩略总览条任意位置，即可瞬移至对应坐标与楼层。
- **`F2` 镜头模式切换**：在「跟随角色」与「自由平移镜头（`J/L/I/K` 或顶栏 `◀/▶/▲/▼` 按钮 + `1.0x/0.5x` 视野缩放）」之间切换。
- **`F3` 调试与比例辅助线**：开关 `32×32` 格网、`320px` 坐标尺、建筑尺寸外框、`art_slot` 槽位名、门外框/净洞框、楼梯垂直连接线、货架通道净宽（`192px`）及跟随角色的 `160px` 高度标尺。
- **`F4` 干净截图模式**：一键隐藏全部预览 UI 与浮动交互提示框，输出纯净画面。
- **`F5` 全图缩略总览条**：开关底部全宽缩略图（实时显示分段、建筑、门、相机视野框与角色位置）。

---

## 六、自动化及实机测试结果

1. **TASK-SCENE-002 专项实机验收套件**（`--dev-scene=outdoor_street --scene002-test --quit`）：
   - **通过 45 项，失败 0 项**（Exit Code `0`）。
   - 覆盖验证：8 层节点结构完整性、`Props < Actors` 顺序、14 栋室外建筑 `art_slot` 槽位、14 处室外地标严格递增且零重叠、室外连续行走无阻挡、相机全图覆盖、全部 11 组「室外 ↔ 室内」门双向进出与返回坐标精度、安全屋 `1F ↔ 2F` 楼梯切换、居民楼 `1F → 2F → 赵阿姨家 → 返回 2F` 嵌套跳转、前世走廊独立性、超市购物车分层遮挡合法性。
2. **既有工程全量回归测试**：
   - `--dev-scene=smoke --quit`（PREP-003 启动自检）：**全部通过**
   - `--dev-scene=core001a --core-test --quit`（CORE-001A 移动/碰撞/相机）：**全部通过**
   - `--dev-scene=core001b --core-test --quit`（CORE-001B 门/货架/购物车）：**全部通过**
   - `--dev-scene=art004 --art004-test-door --quit`（ART-INTEGRATE-004 门进出安全屋回归）：**全部通过**
   - `python tools/check_id_registry.py`：**OK（244 unique IDs）**
   - `python tools/audit_artlib.py`：**0 errors, 0 warnings**

---

## 七、实机截图交付清单（`tests/screenshots/scene002/`）

### 1. 第一季室外主地图完整缩略总览
- `tests/screenshots/scene002/00_outdoor_full_overview_3segments.png`（`1920 × 648`，第一、二、三段三行叠排完整缩略总览图）
- `tests/screenshots/scene002/00_outdoor_full_overview_strip.png`（`3840 × 135`，`15,360 px` 单条连续横版长卷总览）
- `tests/screenshots/scene002/00_outdoor_preview_hud.png`（`960 × 540`，含顶栏预览器与底部全图缩略条的实机界面图）

### 2. 按横向位置顺序截取的连续室外场景截图（`960 × 540` 原生画幅）
- `tests/screenshots/scene002/01_street_01_equip_bay_C.png`（`x=384` ① 小楼设备区）
- `tests/screenshots/scene002/01_street_02_safehouse_gate_AD.png`（`x=912` ② 外婆旧两层小楼正门与巷口）
- `tests/screenshots/scene002/01_street_03_notice_and_meng_FW.png`（`x=2048` ③ 社区主公告栏与 W 孟雨薇住处外观）
- `tests/screenshots/scene002/01_street_04_apartment_and_roof_FT.png`（`x=3008` ④ 居民楼单元门与 T 遮棚屋顶小狗观察位）
- `tests/screenshots/scene002/01_street_05_repair_corner_Q.png`（`x=3856` ⑤ 陈叔维修角）
- `tests/screenshots/scene002/01_street_06_guard_booth_FR.png`（`x=4336` ⑥ 物业门岗与 R 交换点）
- `tests/screenshots/scene002/01_street_07_bus_stop_O.png`（`x=4864` ⑦ 公交站与第一/二段交界）
- `tests/screenshots/scene002/01_street_08_convenience_store_J.png`（`x=5568` ⑧ 唐宁街角便利店）
- `tests/screenshots/scene002/01_street_09_pharmacy_N.png`（`x=6432` ⑨ 社区药店门口）
- `tests/screenshots/scene002/01_street_10_supermarket_H.png`（`x=7552` ⑩ 灾前连锁超市入口）
- `tests/screenshots/scene002/01_street_11_hardware_store_I.png`（`x=8784` ⑪ 五金/家电店）
- `tests/screenshots/scene002/01_street_12_checkpoint_U.png`（`x=9856` ⑫ 临时管制路口）
- `tests/screenshots/scene002/01_street_13_warehouse_K_main.png`（`x=10880` ⑬a 独立批发仓正门）
- `tests/screenshots/scene002/01_street_13b_warehouse_K_dock.png`（`x=12096` ⑬b 独立批发仓装卸门）
- `tests/screenshots/scene002/01_street_14_logistics_hub_L.png`（`x=13440` ⑭ 物流中转取货口）

### 3. 已搭建室内场景完整结构截图（`960 × 540`）
- **A/B 安全屋（双层）**：
  - `02_indoor_01a_shelter_1F_bed_desk.png`、`02_indoor_01b_shelter_1F_shelves_kitchen.png`、`02_indoor_01c_shelter_1F_stairs_door.png`
  - `02_indoor_01d_shelter_2F_storage_stairs.png`
  - `02_indoor_01e_shelter_full_2floors.png`（1F + 2F 完整双层剖面总览）
- **C 外置独立设备区**：`02_indoor_02_equipment_room_C_full.png`、`02_indoor_02b_equipment_room_C_detail.png`
- **G 居民楼公共楼道（双层）**：`02_indoor_03a_apartment_hallway_1F.png`、`02_indoor_03b_apartment_hallway_2F_zhao_door.png`、`02_indoor_03c_apartment_hallway_full_2floors.png`
- **P 赵阿姨家室内**：`02_indoor_04_zhao_home_P_full.png`、`02_indoor_04b_zhao_home_P_detail.png`
- **Q 陈叔维修角**：`02_indoor_05_repair_corner_Q_full.png`、`02_indoor_05b_repair_corner_Q_detail.png`
- **J 唐宁便利店**：`02_indoor_06_convenience_store_J_full.png`、`02_indoor_06b_convenience_store_J_detail.png`
- **N 社区药店内景**：`02_indoor_07_pharmacy_N_full.png`、`02_indoor_07b_pharmacy_N_detail.png`
- **H/S 灾前连锁超市**：`02_indoor_08a_supermarket_H_entry_cart.png`、`02_indoor_08b_supermarket_H_shelves.png`、`02_indoor_08c_supermarket_S_reserve_zone.png`、`02_indoor_08d_supermarket_H_coolers_checkout.png`
- **I 五金 / 家电店**：`02_indoor_09a_hardware_store_I_tools_seal.png`、`02_indoor_09b_hardware_store_I_heater_gen.png`、`02_indoor_09c_hardware_store_I_checkout_loading.png`
- **K 独立批发仓**：`02_indoor_10a_warehouse_K_entry_pallets.png`、`02_indoor_10b_warehouse_K_industrial_shelves.png`、`02_indoor_10c_warehouse_K_order_dock.png`
- **L 物流中转点**：`02_indoor_11a_logistics_hub_L_entry.png`、`02_indoor_11b_logistics_hub_L_canopy_window.png`
- **G0 序章前世走廊**：`02_indoor_12_past_corridor_G0_full.png`

### 4. 带比例辅助线（`F3`）的角色与建筑对照图（`960 × 540`）
- `tests/screenshots/scene002/03_scale_01_outdoor_safehouse_door_96x192.png`（`160px` 角色 vs 小楼两层立面与 `96×192` 标准门）
- `tests/screenshots/scene002/03_scale_02_outdoor_apartment_facade.png`（`160px` 角色 vs 居民楼双层立面与 `T` 遮棚屋顶）
- `tests/screenshots/scene002/03_scale_03_outdoor_supermarket_door_192x224.png`（`160px` 角色 vs 超市门面与 `192×224` 自动门入口）
- `tests/screenshots/scene002/03_scale_04_indoor_shelter_1F_2F_stairs.png`（`160px` 角色 vs 安全屋 1F `256px` 层高、`32px` 楼板、2F 与 `ΔY=288px` 楼梯）
- `tests/screenshots/scene002/03_scale_05_indoor_supermarket_shelves_aisle_192.png`（`160px` 角色 vs `96×192` 货架与 `192px` 主通道净宽）

---

## 八、文档细节差异说明与需请 ChatGPT 美术总监裁定的问题

1. **安全屋一层（`A`）内部左右布局方向裁定**：
   - **现状说明**：《第一季横版场景设计与提示词.md》§1.2 与 §5.A 建议从左到右为「卧床/外婆照片 → 清单桌/绿植 → 储物墙 → 厨房 → 楼梯 → 右侧玄关门」，而《素材台账.csv》中已选概念图 `ART_SCENE_102` 的描述为「左侧入户门 → 厨房 → 沙发 → 空货架 → 右侧窗与暖气 → 杂物间与楼梯」（文档 §5.A 亦注明：“已选概念不强制上述左右顺序，制作时先锁定一套并贯穿所有状态”）。
   - **本轮处理**：当前白盒严格按《第一季横版场景设计与提示词.md》§1.2 执行（左侧卧床与清单桌、中部储物货架、右侧楼梯与临街玄关门），所有坐标集中定义在 `Season1Layout._spec_shelter()` 中。
   - **请总监裁定**：后续正式切片生成时，安全屋 1F 是锁定当前白盒的「左卧右门」顺序，还是镜像翻转为与 `ART_SCENE_102` 概念图一致的「左门右梯」顺序？（工程侧只需在 `Season1Layout` 修改坐标即可无缝切换）。
2. **室外长街建筑间距与留白节奏裁定**：
   - 当前 `15,360 px` 室外长街在 14 栋主要建筑之间预留了 `64 px ~ 448 px` 的巷口、围墙、路灯与街角过渡段。请美术总监结合 `00_outdoor_full_overview_3segments.png` 审核各建筑高宽比例与街区留白是否需要微调。
3. **本轮未开发项确认（符合任务停止条件）**：
   - 本轮仅完成第一季场景白盒结构、门与楼梯切换及开发预览工具；未开发购物结算、库存、经济数值、剧情演出与存档系统，也未使用任何 AI 场景概念图直接充当背景。
