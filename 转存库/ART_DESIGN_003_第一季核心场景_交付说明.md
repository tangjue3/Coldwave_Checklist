# 《寒潮清单》ART-DESIGN-003｜第一季核心横版场景设定

## 交付定位

本批为《寒潮清单》第一季可视化环境**概念设定**，采用 `960×540` 视口和暂定 `32×32` 世界 tile 的功能需求作为构图参考；目前 PNG 为整幅设定画，不是已经拆分的 TileSet、Parallax 层、可交互道具或完成可运行的 Godot 场景。

统一风格：成年人比例、正侧视横版、低饱和烟棕和暗绿、清晰手工像素、暖色室内与风雪蓝灰室外对照。参考许知夏 `ART_CHAR_001_v02` 的像素密度，不描摹任何外部角色/场景。

## 素材及关联

| 美术 ID | 状态 | 场景内容与第一季阶段 | 文件 |
|---|---|---|---|
| `ART_SCENE_101` | `v01` | D-7 邻里超市：玻璃入口、收银区、模块货架、饮水与罐头、右侧冷柜；保留前景横向通道 | `ART_SCENE_101_v01_灾前超市_横版概念.png` |
| `ART_SCENE_102` | `v01 / base` | D-7 旧安全屋：左侧入户门、厨房、沙发、空货架、右侧窗与暖气、杂物间和楼梯 | `ART_SCENE_102_v01_安全屋初始态_横版概念.png` |
| `ART_SCENE_102` | `v01 / upgraded` | D+3 之后的升级态：保持同一建筑结构，门加固、食品饮水储备、保温窗帘、电暖器、储能柜、暖色照明 | `ART_SCENE_102_v01_安全屋升级态_横版概念.png` |
| `ART_SCENE_103` | `v01` | D+1 之后的暴雪街道：封闭商店、自动售货机、积雪单车与三轮车、老小区入口、被雪覆盖的可行道路 | `ART_SCENE_103_v01_暴雪街道_横版概念.png` |

## 对开发 Agent 的重要说明

### 1. 超市

- 是横向可移动关卡，不是鸟瞰、3D 或斜 45° 等距场景。
- 入口、收银、货架、冰柜应拆成不同场景节点或可复用资源，最终按网格确定位置。
- 商品必须在运行时能被选择、查看、加入购物车；概念 PNG 不能直接充当整套交互。
- 大图内货架的包装图样仅提供风格参考，正式商品图标需要逐项设计。

### 2. 安全屋初始态与升级态

- 这两张图是**同一场景的两个建设状态**。游戏中门、窗、厨房、楼梯等固定建筑结构应保持同一坐标。
- 升级来自可配置的设施实例/房间状态，而不是通过将整个背景图片从 A 切换成 B 来冒充建造系统。
- 室内货架、储物箱、保温改造、照明、电暖设备应支持独立增减及状态变化。
- 为安全起见，燃油发电机不能放在生活空间中；正式设计应预留独立通风的室外/隔离设备区，室内使用符合设计的储能与电控设备。
- 始终保留安全出口及行走通道，不能用堆货堵门。

### 3. 暴雪街道

- 远景建筑、前景可行走地面、积雪覆盖和风雪特效应分别分层。
- D-7、初雪、暴雪几个时段可复用基础街道布局与同一套碰撞结构，通过天气层变化完成。
- 风雪可以有动画，但玩家、地面、建筑和进入点不能被特效遮住到无法操作。

## 入库与状态

1. 四张图放入 `素材库/美术设定集/02-场景/`，在 `素材台账.csv` 使用对应 ID，安全屋两张通过「状态/版本」区分。
2. 更新本地 `美术总览.html` 并确保图片缩略图和原图正常打开。
3. 标为「已通过设定审核 / 概念绘制」，所有运行时资源路径保持空值。
4. 已有 `ART_SCENE_001` 超市安全屋拼图保留为历史概念，不覆盖。
5. 这批素材不改动 PREP-003 的工程、现有 `scenes/`、`assets/` 或 `data/`，等待正式玩法工作单批准后再拆分精灵和 TileSet。

## 正式制作前的验证

- 角色高度试稿约 192px，地面、门、货架与 NPC 尺寸须在 `960×540` 场景内做一次实际对照；这些只是起始估计，不是最终锁死的像素规格。
- 对齐 `32×32` TileSet 前先验证碰撞、交互范围、购物车宽度、门净宽和摄像机移动空间。
- 背景与互动设施必须拆层并有唯一来源，别从概念大图直接硬抠后宣称可以无缝平铺。
- 关卡放大、缩小、整数缩放下均需像素清晰，后续 runtime 素材使用 nearest。

## 生成提示词摘要

Original mature hand-pixelled 2D Chinese apocalypse survival indie game environment, true orthographic horizontal side-view cutaway, wide walkable foreground, consistent tile-friendly modular objects, muted charcoal and smoky brown, warm amber interior vs blue-gray extreme winter exterior, no 3D or isometric perspective, no readable labels or UI, no characters, no logos. The shelter before/after uses identical architecture and camera; additions are reinforced door, organized stocks, electric heat, battery cabinets, sealed window and warmer lights while preserving exits.
