# TASK-SCENE-003｜场景白盒审核修正与美术交接准备交付报告

- **任务编号**：`TASK-SCENE-003`
- **工作分支**：`场景制作`
- **引擎版本**：`Godot Engine v4.7.2.stable.official.ed1daf0bf`
- **关联交付件**：
  1. **美术对接总表**：[`SCENE-003_美术对接表.csv`](../SCENE-003_美术对接表.csv)（同步归档于 [`docs/SCENE-003_美术对接表.csv`](SCENE-003_美术对接表.csv)）
  2. **正式参考截图索引**：[`docs/SCENE-003_场景截图索引.md`](SCENE-003_场景截图索引.md)
  3. **历史报告冲突勘误说明**：[`docs/TASK-SCENE-002_报告口径勘误与对齐说明.md`](TASK-SCENE-002_报告口径勘误与对齐说明.md)（未修改原始 [`docs/TASK-SCENE-002_交付报告.md`](TASK-SCENE-002_交付报告.md)）
  4. **正式美术参考截图库（59 张）**：[`tests/screenshots/scene003/`](../tests/screenshots/scene003/)

---

## 一、六项美术总监裁定同步落实情况

| 裁定序号 | 裁定内容 | 工程落实与核验结果 |
| :--- | :--- | :--- |
| **1** | 安全屋一层保留左卧床、右玄关布局 | 已核对并锁死 [`season1_layout.gd`](../scripts/world/season1_layout.gd) `_spec_shelter()`：一层（`x=128..3072, Y=416`）严格保持 **左卧床（`x=384`）→ 清单桌/绿植 V（`x=864`）→ 储物货架群（`x=1280..1664`）→ 简易厨房（`x=2112`）→ 室内木楼梯（`x=2496`）→ 右玄关安全门（`x=2848`）** 布局。 |
| **2** | 保持楼层 `Y=416 / Y=128`，允许镜头上下移动，不改变楼层物理坐标 | 一层地面物理坐标保持 `GROUND_Y = 416.0`、二层地面物理坐标保持 `FLOOR2_Y = 128.0` 不变；在 [`whitebox_world.gd`](../scripts/world/whitebox_world.gd) 中将 `Camera2D.limit_top` 放宽至 `-360`（自由预览模式上下限 `-1080..1080`，键盘 `W/S` 或上下方向键可平滑上下移动镜头 `-180..340`），二层原生截图镜头中心设为 `Y = -18`，完整居中呈现二层空间。 |
| **3** | 陈叔维修角保留室外门面和独立室内场景 | 室外保留 `b05_repair_corner`（`x=3648..4064, w=416×h=256`，卷帘门 `@ x=3856`），按 `E` 进入独立室内场景 [`scenes/world/repair_corner.tscn`](../scenes/world/repair_corner.tscn)（`1920×540 px`，含工具挂板墙、磨损工作台、空白零件柜、旧椅），离开返回室外 `x=3856`。 |
| **4** | 室外地图暂时保持 `15,360 px`，现有主要建筑位置不调整 | `outdoor_street` 总宽保持 `15,360 px`（16 个 `960 px` 标准视口，三段各 `5,120 px`），`b01_equip_bay` 至 `b14_logistics_hub` 共 14 处建筑/地标坐标与尺寸分毫不改。 |
| **5** | 所有角色、购物车、建筑物理参数不变 | 角色可见高度 `160 px`（碰撞 `28×160`）、移动速度 `100 px/s`、购物车 `96×96 px`、四层金属货架 `96×192 px`、标准门 `96×192 px`、商超/仓储门 `192×224 px`、超市主通道净宽 `192 px` 全部保持冻结状态，未触碰任何角色骨骼动画或推车控制逻辑。 |
| **6** | `art_slot` 为美术替换槽位标识，不代表正式素材 ID；核对与素材登记表的关系，避免编号混淆 | 已将代码中所有建筑、室内房间、门、楼梯、货架、道具、远景的 `art_slot` 统一规范为 **`SLOT_EXT_*` / `SLOT_INT_*` / `SLOT_DOOR_*` / `SLOT_STAIR_*` / `SLOT_SHELF_*` / `SLOT_PROP_*` / `SLOT_BG_*`**，并在 [`season1_layout.gd`](../scripts/world/season1_layout.gd) 与 [`SCENE-003_美术对接表.csv`](../SCENE-003_美术对接表.csv) 中新增 `registry_id` 映射字段，明确区分已用/预留的正式素材 ID 与待立项顺延编号（见第四节）。 |

---

## 二、交付文档冲突清理说明

针对上轮会话窗口简版摘要与仓库权威报告 [`docs/TASK-SCENE-002_交付报告.md`](TASK-SCENE-002_交付报告.md) 之间的口径差异：
- **保留历史记录**：未对 [`docs/TASK-SCENE-002_交付报告.md`](TASK-SCENE-002_交付报告.md) 做任何回溯涂改。
- **建立专项勘误文档**：已新建 [`docs/TASK-SCENE-002_报告口径勘误与对齐说明.md`](TASK-SCENE-002_报告口径勘误与对齐说明.md)，逐项核对并更正了简版摘要中的 6 处口径偏差：
  1. 室外建筑/地标数量：明确为 **14 处**（`b01_equip_bay` .. `b14_logistics_hub`），而非 11 栋。
  2. 设备间（C）位置：明确位于**主角小楼（安全屋）左侧外墙旁**（`x=160..640`，门 `x=384`），与生活空间物理隔开通风，而非公寓底楼侧面。
  3. 安全屋一层（A）玄关门坐标：明确为 **`x=2848`**（对应室外 `x=912`），保留左卧床（`x=384`）、右玄关（`x=2848`）布局。
  4. 全部 12 张室内场景 Key 与真实像素尺寸：以 `season1_layout.gd` 实装值为准（如 `shelter 3200×720`、`equipment_room 1920×540`、`apartment_hallway 2400×720`、`supermarket 5760×540`、`hardware_store 4320×540`、`wholesale_warehouse 5120×540`、`logistics_hub 2880×540` 等）。
  5. 角色与 NPC 名称：严格对齐《第一季完整剧本》（主角**林序**、201 住户**赵阿姨与周小满**、维修工**陈叔**、便利店**唐宁**、医护**孟雨薇**、物业**李建国**、住户**王秀琴**、批发商**韩启程**）。
  6. `art_slot` 槽位标识与正式素材登记号分离。

---

## 三、正式美术参考截图生成与质量核验

通过扩展 [`scripts/world/whitebox_world.gd`](../scripts/world/whitebox_world.gd) 的 `set_clean_mode(true)` 与 [`scripts/dev/scene002_runner.gd`](../scripts/dev/scene002_runner.gd) 的 `--scene003-tour` 管线，已在 [`tests/screenshots/scene003/`](../tests/screenshots/scene003/) 下输出全部 **6 大类共 59 张** 正式美术参考截图：

1. **彻底隐藏白盒文字与调试元素**：
   - `set_clean_mode(true)` 自动隐藏顶栏/底栏 UI、头顶交互提示、网格/标尺/碰撞盒调试层、地面 32px 刻度线（`GroundTileTicks`）、分段立柱（`SegmentMarker_*`）以及场景内全部程序化 `Label` 文字节点（`_world_labels`），画面 100% 纯净。
2. **零缩放模糊（`zoom = 1.00x` 原生像素精度）**：
   - 所有 `960×540` 单视口截图均在 `zoom = 1.00x` 下原生截取。
   - 所有全景图（室外 `15360×540`、三段分幅 `5120×2160`、全部 12 张室内完整结构图、安全屋双层剖面 `3200×720`）均使用 `zoom = 1.00x` 原生视口逐段截取并通过 `Image.blit_rect()` 1:1 无损像素拼合，彻底消除此前因 `0.30x / 0.40x` 镜头缩小或双线性插值导致的边缘模糊。
3. **室外 16 段连续截图无缝拼合**：
   - `01_outdoor_seg01_x00000_00960.png` 至 `01_outdoor_seg16_x14400_15360.png` 镜头中心从 `x=480` 起按 `960 px` 步长递增至 `x=14880`（`y=180` 恒定），按顺序水平拼接即可像素级还原 `00_outdoor_overview_full_strip_1x.png`。
4. **完整索引**：
   - 每张截图的场景 Key、镜头中心坐标 `(x, y)`、缩放倍率 `1.00x`、画幅尺寸与覆盖范围均已记录在 [`docs/SCENE-003_场景截图索引.md`](SCENE-003_场景截图索引.md)。

---

## 四、`art_slot` 槽位与《ID登记表.csv》核对说明

核对 [`素材库/ID登记表.csv`](../素材库/ID登记表.csv) 与 [`素材库/素材台账.csv`](../素材库/素材台账.csv) 后，确认现有 `ART_SCENE_*` 编号登记状态如下：

| 正式素材编号 | 登记表名称 | 当前登记状态 | 对应白盒场景 Key 与 `art_slot` 槽位 | 备注与防混淆约束 |
| :--- | :--- | :--- | :--- | :--- |
| `ART_SCENE_101` | 灾前超市 | `已用`（v01 概念已入库） | `supermarket` (`SLOT_INT_SUPERMARKET`) / 室外 `b10_supermarket` (`SLOT_EXT_B10_SUPERMARKET`) | 后续正式切片使用 `ART_SCENE_101` 下的 `r01` 运行时资源 |
| `ART_SCENE_102` | 安全屋一层 | `已用`（v01-base / v01-upgraded 概念已入库） | `shelter` 1F (`SLOT_INT_SHELTER_1F`) / 室外 `b02_protagonist_house` (`SLOT_EXT_B02_SAFEHOUSE`) | 保持左卧床、右玄关与 `Y=416` 坐标不变 |
| `ART_SCENE_103` | 暴雪街道 | `已用`（v01 概念已入库） | `outdoor_street` (`SLOT_BG_SKYLINE` / 街道基底 / 门岗 `SLOT_EXT_B06_GUARD_BOOTH`) | 室外 `15,360 px` 主街视觉母本 |
| `ART_SCENE_104` | 批发仓库 | `预留` | `wholesale_warehouse` (`SLOT_INT_WAREHOUSE`) / 室外 `b13_wholesale_warehouse` (`SLOT_EXT_B13_WAREHOUSE`) | D-4 独立批发仓（K）内外景正式编号 |
| `ART_SCENE_105` | 街角与路牌 | `预留` | 室外 `b03_notice_and_meng` / `b07_bus_stop` (`SLOT_EXT_B07_BUS_STOP`) / `b12_traffic_checkpoint` (`SLOT_EXT_B12_CHECKPOINT`) | 公告栏、公交站候车亭（O）、管制路口路牌（U） |
| `ART_SCENE_106` | 小楼楼上旧房间 | `预留` | `shelter` 2F (`SLOT_INT_SHELTER_2F`) | 安全屋二层（B，`Y=128`）旧储物室与备用扩建室 |
| `ART_SCENE_107` | 安全设备区 | `预留` | `equipment_room` (`SLOT_INT_EQUIP_ROOM`) / 室外 `b01_equip_bay` (`SLOT_EXT_B01_EQUIP_BAY`) | 主角小楼左侧外置独立通风设备间（C） |
| `ART_SCENE_108` | 门外楼道 | `预留` | `apartment_hallway` 1F/2F (`SLOT_INT_HALL_1F` / `SLOT_INT_HALL_2F`) & `past_corridor` (`SLOT_INT_PAST_CORRIDOR`) | 梧桐里居民楼公共楼道（G）与序章前世冰封走廊（G0） |
| `ART_SCENE_109` | 电台/手机特写背景 | `预留`（受 PREP-003 保护） | **不绑定任何横版地图建筑槽位** | **严禁被物流中转口或其他室内外场景占用** |
| `ART_SCENE_110` | 可选地下一层 | `预留` | 当前第一季白盒未启用地下层（按文档设为可选，仅立项 1F+2F） | 保留预留状态 |
| `ART_SCENE_111` | 暴雪窗外 | `预留` | `shelter` 1F/2F 窗外远景槽位（`window_m`） | 安全屋朝街窗户与屋顶电台天线 M 窗景 |
| `ART_SCENE_112` | 五金/家电店 | `预留` | `hardware_store` (`SLOT_INT_HARDWARE`) / 室外 `b11_hardware_store` (`SLOT_EXT_B11_HARDWARE`) | 五金与取暖/发电设备店（I）内外景 |
| `ART_SCENE_113+` | 待立项扩展场景 | **待美术总监自 `ART_SCENE_113` 起顺延分配** | `convenience_store` (`SLOT_INT_CONVENIENCE`)、`pharmacy` (`SLOT_INT_PHARMACY`)、`zhao_home` (`SLOT_INT_ZHAO_HOME`)、`repair_corner` (`SLOT_INT_REPAIR_CORNER`)、`logistics_hub` (`SLOT_INT_LOGISTICS`) 及对应独立外立面 | 已在 [`SCENE-003_美术对接表.csv`](../SCENE-003_美术对接表.csv) 中逐项列明尺寸与待制作内容 |

---

## 五、实机自动化测试与素材库校验结果

1. **Godot 4.7.2 实机自动化测试（`--scene002-test`）**：
   - 运行命令：`Godot_v4.7.2-stable_win64_console.exe --path . -- --dev-scene=outdoor_street --scene002-test --scene003-tour --quit`
   - 验收结果：**通过 45 项，失败 0 项**（含 14 处室外建筑 `VisualSlot` 与 `art_slot` 校验、全部室内外双向门切换、安全屋与居民楼 1F/2F 楼梯上下层切换、2F 赵阿姨家进出、购物车与角色遮挡层级校验）。
2. **正式参考截图批量渲染（`--scene003-tour`）**：
   - 输出 [`tests/screenshots/scene003/`](../tests/screenshots/scene003/) 共 **59 张** PNG，全部 `err=0`。
3. **素材库与 ID 登记表脚本校验**：
   - `python tools/check_id_registry.py` 与 `python tools/audit_artlib.py` 零报错通过。
4. **停止条件确认**：
   - 未生成任何正式游戏美术，未启动 `CORE-002`，未修改剧情或角色动画，未合并 `main`。现已完成全部截图、对接表、索引与报告交付，等待 ChatGPT 美术总监根据本批 1:1 干净参考截图制作正式场景原画与美术素材。
