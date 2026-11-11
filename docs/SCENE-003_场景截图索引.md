# SCENE-003｜正式美术参考截图索引

- **截图存放目录**：[`tests/screenshots/scene003/`](../tests/screenshots/scene003/)
- **截图总数**：**59 张**（分 6 大类，全部为不含 UI、不含网格、不含调试线、不含白盒说明文字的 100% 干净截图）
- **采样精度与抗模糊说明**：
  - 所有单视口截图均在原生逻辑视口 **`960 × 540`**、相机缩放倍率 **`zoom = 1.00x`** 下 1:1 采样输出，无任何缩放插值模糊。
  - 所有全景/长卷/双层剖面结构图均由 `zoom = 1.00x` 原生 `960 × 540` 视口逐段无缝 `blit_rect` 1:1 像素级拼合生成（仅 `00_outdoor_overview_strip_half_nearest.png` 额外提供一张 `INTERPOLATE_NEAREST` 最近邻 0.50x 锐利预览条供快速浏览）。
- **地面物理基线**：一层地面 `Y = 416`，二层地面 `Y = 128`（楼板厚 `32 px`，层高净空 `256 px`）。

---

## 一、类别 00：完整室外长街白盒总览（3 张）

| 序号 | 截图文件名 | 场景 Key | 镜头中心坐标 `(x, y)` | 缩放倍率 | 输出尺寸 | 覆盖世界范围与说明 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | [`00_outdoor_overview_full_strip_1x.png`](../tests/screenshots/scene003/00_outdoor_overview_full_strip_1x.png) | `outdoor_street` | `x = 480..14880`（步长 `960`）, `y = 180` | `1.00x`（1:1 拼合） | `15360 × 540` | 完整室外长街 16 段 `960×540` 原生 1:1 水平无缝拼合总览（覆盖 `X: 0..15360, Y: -90..450`） |
| 2 | [`00_outdoor_overview_strip_half_nearest.png`](../tests/screenshots/scene003/00_outdoor_overview_strip_half_nearest.png) | `outdoor_street` | `x = 480..14880`, `y = 180` | `0.50x`（Nearest 最近邻） | `7680 × 270` | 室外全街 1/2 尺寸最近邻锐利缩略长条（无双线性模糊，供快速审阅全街节奏） |
| 3 | [`00_outdoor_overview_3segments_1x.png`](../tests/screenshots/scene003/00_outdoor_overview_3segments_1x.png) | `outdoor_street` | 三行分段：`X: 0..5120 / 5120..10240 / 10240..15360` | `1.00x`（1:1 三段排布） | `5120 × 2160` | 第一段（社区段）、第二段（商业街段）、第三段（仓储中转段）上下三行 1:1 高清分幅总览图 |

---

## 二、类别 01：室外地图逐段连续 960×540 截图（16 张，可按坐标顺序无缝拼合）

> **拼合规则**：`seg01` 至 `seg16` 镜头中心 Y 固定为 `180`（覆盖世界纵坐标 `Y: -90..450`，完整包纳二层屋顶天线至一层道路基底），镜头中心 X 从 `480` 起每张严格递增 `960 px` 至 `14880`。将 16 张图按序号从左到右水平拼接，即可 0 误差还原 `15360 × 540` 完整长街。

| 段号 | 截图文件名 | 场景 Key | 镜头中心坐标 `(x, y)` | 缩放倍率 | 输出尺寸 | 覆盖世界 X 范围 | 段内包含建筑与地标 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 01 | [`01_outdoor_seg01_x00000_00960.png`](../tests/screenshots/scene003/01_outdoor_seg01_x00000_00960.png) | `outdoor_street` | `(480, 180)` | `1.00x` | `960 × 540` | `0 .. 960` | ① 小楼设备区 (`b01_equip_bay`, `160..640`, 门 `x=384`) + ② 主角安全屋左半立面与正门 (`x=912`) + 林序站立基准 |
| 02 | [`01_outdoor_seg02_x00960_01920.png`](../tests/screenshots/scene003/01_outdoor_seg02_x00960_01920.png) | `outdoor_street` | `(1440, 180)` | `1.00x` | `960 × 540` | `960 .. 1920` | ② 主角安全屋右半立面 (`640..1472`) + D 门前收货箱放置位 (`x=1152`) + 巷口路灯与旧车架 (`x=1664`) |
| 03 | [`01_outdoor_seg03_x01920_02880.png`](../tests/screenshots/scene003/01_outdoor_seg03_x01920_02880.png) | `outdoor_street` | `(2400, 180)` | `1.00x` | `960 × 540` | `1920 .. 2880` | ③ 社区主公告栏 & W 孟雨薇住处外观 (`b03_notice_and_meng`, `1920..2528`, 装饰门 `x=2384`) + ④ 梧桐里居民楼左段 (`2560..2880`) |
| 04 | [`01_outdoor_seg04_x02880_03840.png`](../tests/screenshots/scene003/01_outdoor_seg04_x02880_03840.png) | `outdoor_street` | `(3360, 180)` | `1.00x` | `960 × 540` | `2880 .. 3840` | ④ 梧桐里居民楼中右段 (`2560..3584`, 单元门 `x=3008`, T 遮棚屋顶小狗观察位 `x=3360`) + ⑤ 陈叔维修角左半 (`3648..3840`) |
| 05 | [`01_outdoor_seg05_x03840_04800.png`](../tests/screenshots/scene003/01_outdoor_seg05_x03840_04800.png) | `outdoor_street` | `(4320, 180)` | `1.00x` | `960 × 540` | `3840 .. 4800` | ⑤ 陈叔维修角门 (`x=3856`) + ⑥ 物业门岗 & R 临时交换点 (`b06_guard_booth`, `4128..4544`) + ⑦ 公交站左半 (`4608..4800`) |
| 06 | [`01_outdoor_seg06_x04800_05760.png`](../tests/screenshots/scene003/01_outdoor_seg06_x04800_05760.png) | `outdoor_street` | `(5280, 180)` | `1.00x` | `960 × 540` | `4800 .. 5760` | ⑦ 公交站与街角 (`b07_bus_stop`, `4608..5056`, 站牌 `x=4864`) + ⑧ 唐宁街角便利店左大半 (`b08_convenience_store`, `5248..5760`, 门 `x=5568`) |
| 07 | [`01_outdoor_seg07_x05760_06720.png`](../tests/screenshots/scene003/01_outdoor_seg07_x05760_06720.png) | `outdoor_street` | `(6240, 180)` | `1.00x` | `960 × 540` | `5760 .. 6720` | ⑧ 唐宁便利店右端 (`5760..5952`) + ⑨ 社区药店 (`b09_pharmacy`, `6080..6720`, 门 `x=6432`) |
| 08 | [`01_outdoor_seg08_x06720_07680.png`](../tests/screenshots/scene003/01_outdoor_seg08_x06720_07680.png) | `outdoor_street` | `(7200, 180)` | `1.00x` | `960 × 540` | `6720 .. 7680` | ⑨ 药店右缘 + ⑩ 灾前连锁超市左半立面与大型自动门 (`b10_supermarket`, `6912..7680`, 自动门 `192×224 @ x=7552`) |
| 09 | [`01_outdoor_seg09_x07680_08640.png`](../tests/screenshots/scene003/01_outdoor_seg09_x07680_08640.png) | `outdoor_street` | `(8160, 180)` | `1.00x` | `960 × 540` | `7680 .. 8640` | ⑩ 灾前连锁超市右半立面 (`7680..8192`) + ⑪ 五金/家电店左段 (`b11_hardware_store`, `8320..8640`) |
| 10 | [`01_outdoor_seg10_x08640_09600.png`](../tests/screenshots/scene003/01_outdoor_seg10_x08640_09600.png) | `outdoor_street` | `(9120, 180)` | `1.00x` | `960 × 540` | `8640 .. 9600` | ⑪ 五金/家电店中右段 (`8640..9344`, 门 `x=8784`, 装货卷帘 `x=8928..9216`) + ⑫ 临时管制路口左端 (`9472..9600`) |
| 11 | [`01_outdoor_seg11_x09600_10560.png`](../tests/screenshots/scene003/01_outdoor_seg11_x09600_10560.png) | `outdoor_street` | `(10080, 180)` | `1.00x` | `960 × 540` | `9600 .. 10560` | ⑫ 临时管制路口 (`b12_traffic_checkpoint`, `9472..10176`, 护栏 `x=9856`) + ⑬ 独立批发仓左端 (`10432..10560`) |
| 12 | [`01_outdoor_seg12_x10560_11520.png`](../tests/screenshots/scene003/01_outdoor_seg12_x10560_11520.png) | `outdoor_street` | `(11040, 180)` | `1.00x` | `960 × 540` | `10560 .. 11520` | ⑬ 独立批发仓左半立面 (`b13_wholesale_warehouse`, 正门 `192×224 @ x=10880`, 高窗采光带 A) |
| 13 | [`01_outdoor_seg13_x11520_12480.png`](../tests/screenshots/scene003/01_outdoor_seg13_x11520_12480.png) | `outdoor_street` | `(12000, 180)` | `1.00x` | `960 × 540` | `11520 .. 12480` | ⑬ 独立批发仓右半立面 (`11520..12480`, 高窗采光带 B, 右侧装卸门 `192×224 @ x=12096`, 装卸车位 `x=12320`) |
| 14 | [`01_outdoor_seg14_x12480_13440.png`](../tests/screenshots/scene003/01_outdoor_seg14_x12480_13440.png) | `outdoor_street` | `(12960, 180)` | `1.00x` | `960 × 540` | `12480 .. 13440` | 仓储区街段过渡 + ⑭ 物流中转口左半立面 (`b14_logistics_hub`, `12736..13440`, 取货口门左缘) |
| 15 | [`01_outdoor_seg15_x13440_14400.png`](../tests/screenshots/scene003/01_outdoor_seg15_x13440_14400.png) | `outdoor_street` | `(13920, 180)` | `1.00x` | `960 × 540` | `13440 .. 14400` | ⑭ 物流中转口门 (`x=13440`) + 待领雨棚与大件订单交接窗 (`x=13760..14016`) |
| 16 | [`01_outdoor_seg16_x14400_15360.png`](../tests/screenshots/scene003/01_outdoor_seg16_x14400_15360.png) | `outdoor_street` | `(14880, 180)` | `1.00x` | `960 × 540` | `14400 .. 15360` | ⑭ 物流中转口右端 (`14400..14592`) + 城市边缘右侧留白边界 (`14592..15360`) |

---

## 三、类别 02：所有室内场景完整结构图（12 张，1:1 无模糊拼合）

| 序号 | 截图文件名 | 场景 Key | 拼合镜头中心序列 `(x, y)` | 缩放倍率 | 输出尺寸 | 结构与楼层说明 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 01 | [`02_indoor_full_01_shelter_3200x720.png`](../tests/screenshots/scene003/02_indoor_full_01_shelter_3200x720.png) | `shelter` | `X=[480, 1440, 2400, 2720] × Y=[90, 270]` | `1.00x`（1:1 拼合） | `3200 × 720` | **安全屋（A 一层 + B 二层）**完整双层剖面：1F (`Y=416`) 左卧床 (`x=384`) → 清单桌 (`x=864`) → 货架群 (`x=1280..1664`) → 厨房 (`x=2112`) → 木楼梯 (`x=2496`) → 右玄关门 (`x=2848`)；2F (`Y=128`) 备用室 → 临街窗 → 旧储物室 → 2F楼梯口 |
| 02 | [`02_indoor_full_02_equipment_room_1920x540.png`](../tests/screenshots/scene003/02_indoor_full_02_equipment_room_1920x540.png) | `equipment_room` | `[(480, 270), (1440, 270)]` | `1.00x`（1:1 拼合） | `1920 × 540` | **外置独立设备间（C）**完整结构：左安全门 (`x=256`) → 外墙百叶通风口 (`x=512..736`) → 发电机底座 (`x=1024`) → 断路器配电箱 (`x=1440`) → 检修台 (`x=1664`) |
| 03 | [`02_indoor_full_03_apartment_hallway_2400x720.png`](../tests/screenshots/scene003/02_indoor_full_03_apartment_hallway_2400x720.png) | `apartment_hallway` | `X=[480, 1440, 1920] × Y=[90, 270]` | `1.00x`（1:1 拼合） | `2400 × 720` | **梧桐里居民楼公共楼道（G）**完整双层剖面：1F (`Y=416`) 单元门 (`x=256`) → 公共楼梯 (`x=608`) → 101/102门 → 配电柜；2F (`Y=128`) 2F楼梯口 (`x=608`) → S12纸条位 (`x=1280`) → **201 赵阿姨家门 (`x=1408`)** → 202门 |
| 04 | [`02_indoor_full_04_zhao_home_1920x540.png`](../tests/screenshots/scene003/02_indoor_full_04_zhao_home_1920x540.png) | `zhao_home` | `[(480, 270), (1440, 270)]` | `1.00x`（1:1 拼合） | `1920 × 540` | **赵阿姨与小满家室内（P）**完整结构：201入户门 (`x=256`) → 小鞋架 (`x=448`) → 简桌与药单 (`x=736`) → 老人椅 (`x=1024`) → 小满折叠铺 (`x=1312`) → 临街窗 (`x=1536..1728`) |
| 05 | [`02_indoor_full_05_repair_corner_1920x540.png`](../tests/screenshots/scene003/02_indoor_full_05_repair_corner_1920x540.png) | `repair_corner` | `[(480, 270), (1440, 270)]` | `1.00x`（1:1 拼合） | `1920 × 540` | **陈叔维修角室内（Q）**完整结构：旧卷帘门 (`x=256`) → 工具挂板墙 (`x=544..800`) → 磨损工作台 (`x=1024`) → 空白零件抽屉柜 (`x=1376`) → 旧工作椅 (`x=1632`) |
| 06 | [`02_indoor_full_06_convenience_store_2400x540.png`](../tests/screenshots/scene003/02_indoor_full_06_convenience_store_2400x540.png) | `convenience_store` | `[(480, 270), (1440, 270), (1920, 270)]` | `1.00x`（1:1 拼合） | `2400 × 540` | **唐宁的街角便利店（J）**完整结构：玻璃门 (`x=256`) → 橱窗 → 货架 A/B (`x=768, 960`) → 饮料冷柜 (`x=1184`) → 收银柜台与旧电台位 (`x=1600`) → 后方休息室装饰门 (`x=2048`) |
| 07 | [`02_indoor_full_07_pharmacy_1920x540.png`](../tests/screenshots/scene003/02_indoor_full_07_pharmacy_1920x540.png) | `pharmacy` | `[(480, 270), (1440, 270)]` | `1.00x`（1:1 拼合） | `1920 × 540` | **社区药店内景（N）**完整结构：玻璃门 (`x=256`) → 橱窗 → 等候排椅 (`x=640`) → 非处方陈列架 (`x=1024`) → 药师服务柜台 (`x=1472`) |
| 08 | [`02_indoor_full_08_supermarket_5760x540.png`](../tests/screenshots/scene003/02_indoor_full_08_supermarket_5760x540.png) | `supermarket` | `[(480, 270), (1440, 270), (2400, 270), (3360, 270), (4320, 270), (5280, 270)]` | `1.00x`（1:1 拼合） | `5760 × 540` | **灾前连锁超市（H + S 临时批发预约区）**完整结构：自动门入口 (`x=320`) → 购物车 (`x=768`) → 饮水与食品货架阵列 (`x=1152..2880`, 主通道净宽 `192 px`) → S 预约桌 (`x=3552`) & 后仓门 (`x=3904`) → 冷柜 (`x=4544`) → 收银台 (`x=5024`) → 右出口 (`x=5376`) |
| 09 | [`02_indoor_full_09_hardware_store_4320x540.png`](../tests/screenshots/scene003/02_indoor_full_09_hardware_store_4320x540.png) | `hardware_store` | `[(480, 270), (1440, 270), (2400, 270), (3360, 270), (3840, 270)]` | `1.00x`（1:1 拼合） | `4320 × 540` | **五金 / 家电店（I）**完整结构：玻璃门 (`x=288`) → 工具挂板 (`x=864..1248`) → 零件架 (`x=1344`) → 门窗密封样板架 (`x=1920`) → 取暖器与未运行发电机样机台 (`x=2752`) → 收银订单台 (`x=3520`) → 大件装货门 (`x=3968`) |
| 10 | [`02_indoor_full_10_wholesale_warehouse_5120x540.png`](../tests/screenshots/scene003/02_indoor_full_10_wholesale_warehouse_5120x540.png) | `wholesale_warehouse` | `[(480, 270), (1440, 270), (2400, 270), (3360, 270), (4320, 270), (4640, 270)]` | `1.00x`（1:1 拼合） | `5120 × 540` | **独立批发仓与装卸区（K）**完整结构：左正门 (`x=320`) → 满载推车 (`x=864`) & 空托盘 (`x=1152`) → 工业重型货架群 (`x=1920..2784`) → 批发订单交接台 (`x=3680`) → 装卸缓冲台 (`x=4288`) → 右装卸门 (`x=4736`) |
| 11 | [`02_indoor_full_11_logistics_hub_2880x540.png`](../tests/screenshots/scene003/02_indoor_full_11_logistics_hub_2880x540.png) | `logistics_hub` | `[(480, 270), (1440, 270), (2400, 270)]` | `1.00x`（1:1 拼合） | `2880 × 540` | **物流中转点 / 大件取货口（L）**完整结构：街道入口门 (`x=288`) → 等候路障 (`x=768`) → 中转棚待领货架 (`x=1536`) → 手推车位 (`x=1920`) → 工作人员交接窗口 (`x=2336`) |
| 12 | [`02_indoor_full_12_past_corridor_1920x540.png`](../tests/screenshots/scene003/02_indoor_full_12_past_corridor_1920x540.png) | `past_corridor` | `[(480, 270), (1440, 270)]` | `1.00x`（1:1 拼合） | `1920 × 540` | **序章 P00 前世门外冰封走廊（G0）**完整结构：重生转场门 (`x=256`) → 结霜走廊窗 (`x=640..864`) → 前世被孟雨薇反锁的自家安全门 (`x=1440`, 门底透微弱暖光) |

---

## 四、类别 03：重要房间的 960×540 原生游戏截图（24 张，`zoom = 1.00x`）

| 序号 | 截图文件名 | 场景 Key | 镜头中心坐标 `(x, y)` | 缩放倍率 | 输出尺寸 | 画面重点区域 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 01 | [`03_native_01_shelter_1F_bed_desk.png`](../tests/screenshots/scene003/03_native_01_shelter_1F_bed_desk.png) | `shelter` | `(608, 270)` | `1.00x` | `960 × 540` | 安全屋 1F 左侧：卧床 (`x=384`)、清单桌与绿植窗台 V (`x=864`) |
| 02 | [`03_native_02_shelter_1F_shelves_kitchen.png`](../tests/screenshots/scene003/03_native_02_shelter_1F_shelves_kitchen.png) | `shelter` | `(1600, 270)` | `1.00x` | `960 × 540` | 安全屋 1F 中段：四层金属储物架 A/B/C (`x=1280..1664`)、落地水粮箱 (`x=1840`)、简易厨房左缘 |
| 03 | [`03_native_03_shelter_1F_stairs_entrance.png`](../tests/screenshots/scene003/03_native_03_shelter_1F_stairs_entrance.png) | `shelter` | `(2560, 270)` | `1.00x` | `960 × 540` | 安全屋 1F 右侧：简易厨房 (`x=2112`)、室内木楼梯 (`x=2496`)、右玄关防寒安全门 (`x=2848`) |
| 04 | [`03_native_04_shelter_2F_spare_window.png`](../tests/screenshots/scene003/03_native_04_shelter_2F_spare_window.png) | `shelter` | `(960, -18)` | `1.00x` | `960 × 540` | 安全屋 2F 左中段（镜头上移对准 `Y=128` 二层）：备用扩建室 (`x=640`)、旧家具与临街观察窗 (`x=1312`) |
| 05 | [`03_native_05_shelter_2F_storage_stairs.png`](../tests/screenshots/scene003/03_native_05_shelter_2F_storage_stairs.png) | `shelter` | `(2080, -18)` | `1.00x` | `960 × 540` | 安全屋 2F 右段（镜头上移对准 `Y=128` 二层）：封存旧储物室 (`x=1920`)、2F 楼梯口 (`x=2496`) |
| 06 | [`03_native_06_equipment_room_vent_gen.png`](../tests/screenshots/scene003/03_native_06_equipment_room_vent_gen.png) | `equipment_room` | `(640, 270)` | `1.00x` | `960 × 540` | 外置设备区 C 左半：安全门 (`x=256`)、外墙百叶通风格栅 (`x=512..736`)、发电机底座左缘 |
| 07 | [`03_native_07_equipment_room_gen_breaker.png`](../tests/screenshots/scene003/03_native_07_equipment_room_gen_breaker.png) | `equipment_room` | `(1280, 270)` | `1.00x` | `960 × 540` | 外置设备区 C 右半：发电机安装底座 (`x=1024`)、断路器配电箱 (`x=1440`)、检修工作位 (`x=1664`) |
| 08 | [`03_native_08_apartment_hallway_1F.png`](../tests/screenshots/scene003/03_native_08_apartment_hallway_1F.png) | `apartment_hallway` | `(608, 270)` | `1.00x` | `960 × 540` | 居民楼公共楼道 G 1F：单元门入口 (`x=256`)、1F→2F 公共楼梯 (`x=608`)、1F 采光窗 (`x=928`) |
| 09 | [`03_native_09_apartment_hallway_2F_zhao_door.png`](../tests/screenshots/scene003/03_native_09_apartment_hallway_2F_zhao_door.png) | `apartment_hallway` | `(1408, -18)` | `1.00x` | `960 × 540` | 居民楼公共楼道 G 2F（镜头上移对准 `Y=128` 二层）：2F 采光窗、门边求助纸条位 S12 (`x=1280`)、201 赵阿姨家门 (`x=1408`) |
| 10 | [`03_native_10_zhao_home_table_bed.png`](../tests/screenshots/scene003/03_native_10_zhao_home_table_bed.png) | `zhao_home` | `(960, 270)` | `1.00x` | `960 × 540` | 赵阿姨与小满家 P：简桌与手写药单 (`x=736`)、老人椅 (`x=1024`)、小满临时折叠铺 (`x=1312`) |
| 11 | [`03_native_11_repair_corner_workbench.png`](../tests/screenshots/scene003/03_native_11_repair_corner_workbench.png) | `repair_corner` | `(960, 270)` | `1.00x` | `960 × 540` | 陈叔维修角 Q：电工工具挂板墙 (`x=544..800`)、磨损维修工作台 (`x=1024`)、空白零件抽屉柜 (`x=1376`) |
| 12 | [`03_native_12_convenience_store_shelves_cooler.png`](../tests/screenshots/scene003/03_native_12_convenience_store_shelves_cooler.png) | `convenience_store` | `(800, 270)` | `1.00x` | `960 × 540` | 唐宁便利店 J 左半：临街橱窗、便利店货架 A/B (`x=768, 960`)、饮料冷藏柜 (`x=1184`) |
| 13 | [`03_native_13_convenience_store_counter_backdoor.png`](../tests/screenshots/scene003/03_native_13_convenience_store_counter_backdoor.png) | `convenience_store` | `(1664, 270)` | `1.00x` | `960 × 540` | 唐宁便利店 J 右半：收银柜台与旧电台位 (`x=1600`)、后方唐母休息室装饰门 (`x=2048`) |
| 14 | [`03_native_14_pharmacy_shelf_counter.png`](../tests/screenshots/scene003/03_native_14_pharmacy_shelf_counter.png) | `pharmacy` | `(1024, 270)` | `1.00x` | `960 × 540` | 社区药店 N：等候排椅 (`x=640`)、非处方陈列架 (`x=1024`)、药师咨询服务柜台 (`x=1472`) |
| 15 | [`03_native_15_supermarket_entry_cart.png`](../tests/screenshots/scene003/03_native_15_supermarket_entry_cart.png) | `supermarket` | `(768, 270)` | `1.00x` | `960 × 540` | 灾前超市 H 入口区：192×224 自动门 (`x=320`)、可推购物车 (`x=768`)、首组饮水货架 (`x=1152`) |
| 16 | [`03_native_16_supermarket_shelves_aisle.png`](../tests/screenshots/scene003/03_native_16_supermarket_shelves_aisle.png) | `supermarket` | `(1728, 270)` | `1.00x` | `960 × 540` | 灾前超市 H 货架主通道区：饮水货架 B (`x=1440`)、整箱堆头 (`x=1824`)、速食货架 A (`x=2016`) |
| 17 | [`03_native_17_supermarket_S_reserve_zone.png`](../tests/screenshots/scene003/03_native_17_supermarket_S_reserve_zone.png) | `supermarket` | `(3680, 270)` | `1.00x` | `960 × 540` | 灾前超市 S 临时批发预约区：预约登记桌 (`x=3552`)、后仓装饰门 (`x=3904`)、待交接整托纸箱 (`x=4128`) |
| 18 | [`03_native_18_supermarket_coolers_checkout.png`](../tests/screenshots/scene003/03_native_18_supermarket_coolers_checkout.png) | `supermarket` | `(5024, 270)` | `1.00x` | `960 × 540` | 灾前超市 H 冷柜与收银出口区：冷藏柜阵列 (`x=4544`)、收银结账台 (`x=5024`)、右侧出口门 (`x=5376`) |
| 19 | [`03_native_19_hardware_store_tools_seal.png`](../tests/screenshots/scene003/03_native_19_hardware_store_tools_seal.png) | `hardware_store` | `(1440, 270)` | `1.00x` | `960 × 540` | 五金/家电店 I 左中段：工具挂板 (`x=864..1248`)、维修耗材货架 (`x=1344`)、门窗密封条与加固门样板架 (`x=1920`) |
| 20 | [`03_native_20_hardware_store_heater_checkout.png`](../tests/screenshots/scene003/03_native_20_hardware_store_heater_checkout.png) | `hardware_store` | `(3136, 270)` | `1.00x` | `960 × 540` | 五金/家电店 I 右中段：取暖器与未运行发电机样机展示台 (`x=2752`)、五金收银与大件订单台 (`x=3520`) |
| 21 | [`03_native_21_warehouse_entry_shelves.png`](../tests/screenshots/scene003/03_native_21_warehouse_entry_shelves.png) | `wholesale_warehouse` | `(1440, 270)` | `1.00x` | `960 × 540` | 独立批发仓 K 左中段：满载购物车 (`x=864`)、空木托盘区 (`x=1152`)、工业重型货架 A (`x=1920`) |
| 22 | [`03_native_22_warehouse_order_dock.png`](../tests/screenshots/scene003/03_native_22_warehouse_order_dock.png) | `wholesale_warehouse` | `(4160, 270)` | `1.00x` | `960 × 540` | 独立批发仓 K 右段：批发订单交接台 (`x=3680`)、装卸平台缓冲位 (`x=4288`)、右侧工业装卸门 (`x=4736`) |
| 23 | [`03_native_23_logistics_hub_canopy_window.png`](../tests/screenshots/scene003/03_native_23_logistics_hub_canopy_window.png) | `logistics_hub` | `(1824, 270)` | `1.00x` | `960 × 540` | 物流中转点 L 中右段：中转棚待领货架 (`x=1536`)、手推车停靠位 (`x=1920`)、工作人员交接窗口 (`x=2336`) |
| 24 | [`03_native_24_past_corridor_locked_door.png`](../tests/screenshots/scene003/03_native_24_past_corridor_locked_door.png) | `past_corridor` | `(1024, 270)` | `1.00x` | `960 × 540` | 序章 P00 前世走廊 G0：结霜走廊窗 (`x=640..864`)、前世被孟雨薇反锁的自家安全门 (`x=1440`, 门底透暖光) |

---

## 五、类别 04：角色与建筑比例对照图（5 张，`zoom = 1.00x` 干净版）

| 序号 | 截图文件名 | 场景 Key | 镜头中心坐标 `(x, y)` | 缩放倍率 | 输出尺寸 | 比例核对基准说明 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 01 | [`04_scale_01_outdoor_safehouse_door_96x192.png`](../tests/screenshots/scene003/04_scale_01_outdoor_safehouse_door_96x192.png) | `outdoor_street` | `(912, 180)` | `1.00x` | `960 × 540` | 林序（高 `160 px`）站立于主角两层小楼（高 `480 px`）与标准入户门（`96 × 192 px`, 门顶高于头顶 `32 px`）前比例对照 |
| 02 | [`04_scale_02_outdoor_apartment_facade_512h.png`](../tests/screenshots/scene003/04_scale_02_outdoor_apartment_facade_512h.png) | `outdoor_street` | `(3008, 180)` | `1.00x` | `960 × 540` | 林序（高 `160 px`）站立于梧桐里居民楼（高 `512 px`）单元门（`96 × 192 px @ x=3008`）与低遮棚屋顶 T 前比例对照 |
| 03 | [`04_scale_03_outdoor_supermarket_wide_door_192x224.png`](../tests/screenshots/scene003/04_scale_03_outdoor_supermarket_wide_door_192x224.png) | `outdoor_street` | `(7552, 240)` | `1.00x` | `960 × 540` | 林序（高 `160 px`）站立于灾前连锁超市外立面（高 `352 px`）与大型商超自动门（`192 × 224 px @ x=7552`）前比例对照 |
| 04 | [`04_scale_04_indoor_shelter_1F_2F_stairs_door.png`](../tests/screenshots/scene003/04_scale_04_indoor_shelter_1F_2F_stairs_door.png) | `shelter` | `(2496, 180)` | `1.00x` | `960 × 540` | 林序（高 `160 px`）在安全屋 1F 楼梯口（`x=2496, Y=416`）与 1F 层高（`256 px`）、楼板厚（`32 px`）、2F 地面（`Y=128`）、右玄关门（`96 × 192 px @ x=2848`）比例对照 |
| 05 | [`04_scale_05_indoor_supermarket_player_cart_shelves_aisle192.png`](../tests/screenshots/scene003/04_scale_05_indoor_supermarket_player_cart_shelves_aisle192.png) | `supermarket` | `(1296, 270)` | `1.00x` | `960 × 540` | 林序（高 `160 px`）+ 超市购物车（`96 × 96 px`）+ 两侧四层金属货架（`96 × 192 px @ x=1152 / 1440`）+ 主通道净宽（`192 px`）同屏比例对照 |

---

## 六、类别 05：安全屋两层完整剖面图（1 张，`zoom = 1.00x` 1:1 拼合）

| 序号 | 截图文件名 | 场景 Key | 镜头中心序列 `(x, y)` | 缩放倍率 | 输出尺寸 | 剖面说明 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 01 | [`05_shelter_2floors_cross_section_1x.png`](../tests/screenshots/scene003/05_shelter_2floors_cross_section_1x.png) | `shelter` | `X=[480, 1440, 2400, 2720] × Y=[90, 270]` | `1.00x`（1:1 拼合） | `3200 × 720` | **安全屋（A 一层 `Y=416` + B 二层 `Y=128`）两层完整剖面专项交付图**：清晰呈现左卧床 (`x=384`) → 清单桌 (`x=864`) → 四层货架群 (`x=1280..1664`) → 厨房 (`x=2112`) → 1F/2F 贯通木楼梯 (`x=2496`) → 右玄关防寒门 (`x=2848`) 与二层旧储物室/备用室的上下正对剖面关系 |
