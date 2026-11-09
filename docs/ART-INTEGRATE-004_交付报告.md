# ART-INTEGRATE-004 交付报告｜购物车分层与装载素材接入

> 工程：`Coldwave_Checklist`（GitHub 公开仓库 `tangjue3/Coldwave_Checklist`）
> 基线：工程提交 `43fd012` / 报告提交 `b6278c8`（ART-FIX-003C）
> 引擎：Godot **4.7.2 stable**（`4.7.2.stable.official.ed1daf0bf`），视口 960×540，Nearest，GL Compatibility
> 本轮素材包：`Coldfront_ART_RUNTIME_004_v1.zip`（`转存库/`）

---

## 1. 一分钟结论

ART-RUNTIME-004 的四张 r03 分件已接入工程，在 **Windows 与 Web 双端实机跑通**。

| 项目 | 结果 |
|---|---|
| 四张分件接入 | **全部接入** `assets/facilities/`，画布统一 128×112、锚点统一 (64,104)、alpha 仅 0/255 两档 |
| 空车还原 AE=0 | **AE = 0**（引擎内逐像素合成实测，差异像素 0；与美术侧 ImageMagick 结论一致） |
| 装载三态 | EMPTY / HALF / FULL 均正确显示，**半载与满载强制互斥** |
| 图层顺序 | Back → Cargo → Player → Front，实机验证**近侧篮网正确压住人物腿部**（渲染色误差 0.000） |
| 冻结参数 | **一个都没改**：碰撞 28×160、间距 80px、车长 96px、推速 80 / 拉速 40、画布 128×112、锚点 (64,104)、分辨率 960×540 |
| r02 回退 | **保留**：`PushableCart.set_art_variant()` 可随时切回 r02 单图版本 |
| r03 状态 | **未擅自升「运行时可用」**，台账四行一律「待审核」，白名单已加断言拦住越权 |
| 商品 r02 四件 | 按总监裁定 **已升「运行时可用」**（ART_ITEM_101 / 102 的 r02 与 r02-shelf） |
| 回归 | Windows 26/26、巡检 4/4、CORE-001B 30/30、ART-003 29/29、ART-004 33/33、素材页 25/25、ID 登记全绿、Web 9/9 + 17/17 + 15/15 + 5/5 |
| PCK | 15.74 MB（+0.06 MB），四张 r03 在包内；母图 / 预览 / 素材库 / 转存库 **全部不在包内** |

**本轮未做**（按停止条件）：未接入 ART-RUNTIME-005、未开始 CORE-002、未做推车行走动画、未做车轮滚动动画、未做购物 / 库存 / 结算 / 存档、未修改任何原有美术素材。

---

## 2. 裁定执行情况

任务书里的「版本状态冲突」以最新裁定为准，逐条对齐如下：

| 素材 | 任务书最新裁定 | 本轮实际状态 | 一致 |
|---|---|---|---|
| `ART_CHAR_001 r03` | 运行时可用，仅限扶车待机 | 保持「运行时可用」，未改动 | ✅ |
| `ART_FURN_103 r02` | 运行时可用，现有购物车回退版本 | 保持「运行时可用」，并新增 `set_art_variant()` 回退通道 | ✅ |
| `ART_FURN_101 r01` | 运行时可用 | 保持「运行时可用」，未改动 | ✅ |
| `ART_ITEM_101/102` 旧 r01 | 不予通过 | 仍为「不予通过」且无运行时路径 | ✅ |
| `ART_ITEM_101/102` 新 r02 | 已获批准，登记为运行时可用 | **已升「运行时可用」**，并进白名单 | ✅ |
| `ART_FURN_103 r03`（本轮新增四件） | 暂不直接升为正式运行时可用 | 台账四行一律「**待审核**」，白名单断言强制拦住 | ✅ |

> 交付包 README 里「r02 仍是候选、r03 未由 Agent 接入」的说法是旧状态，本轮以最新裁定为准，未据此覆盖任何状态。

---

## 3. 本轮实际修改的文件及提交记录

### 3.1 改动文件清单

| 类别 | 文件 | 说明 |
|---|---|---|
| 运行时素材 | `assets/facilities/ART_FURN_103_r03_back_128x112.png`（+`.import`） | r03 后景结构（车把、后框架、支撑、车轮） |
| 运行时素材 | `assets/facilities/ART_FURN_103_r03_front_128x112.png`（+`.import`） | r03 近侧篮网与前景边缘 |
| 运行时素材 | `assets/facilities/ART_FURN_103_r03_cargo_half_128x112.png`（+`.import`） | 半载物资层 |
| 运行时素材 | `assets/facilities/ART_FURN_103_r03_cargo_full_128x112.png`（+`.import`） | 满载物资层 |
| 引擎 | `scripts/objects/pushable_cart.gd` | **重写视觉部分**：分层构建、装载状态、r02 回退、图层顺序自检 |
| 引擎 | `scripts/autoload/scene_router.gd` | 注册 `art004` 场景；Web URL 参数映射到 `art004_state` / `art004_load` |
| 开发场景 | `scenes/dev/art004_verify.tscn` | ART-004 实机验证场景 |
| 开发场景 | `scripts/dev/art004_verify.gd` | 八检查点 + 33 项实机用例 |
| 开发场景 | `scripts/dev/art004_overlay.gd` | 调试叠加层（按 F3 开关） |
| 开发场景 | `scripts/dev/art004_door_watcher.gd` | 门「进入 / 离开」回归观察者 |
| 工具 | `tools/check_art004_web.mjs` | Web 端 ART-004 验收（15 项） |
| 工具 | `tools/make_hand_contact_zoom.py` | 手部接触区 4× 放大图生成（只处理真实实机截图） |
| 工具 | `tools/sync_artlib_ledger_004.py` | 台账与登记表同步脚本（可重复执行） |
| 工具 | `tools/check_artlib_page.mjs` | 白名单扩到 10 条；新增 r03「必须待审核」断言 |
| 素材库 | `素材库/素材台账.csv` | 商品 r02 四件升状态 + 新增 r03 四行（37 行） |
| 素材库 | `素材库/ID登记表.csv` / `.md` | ART_FURN_103 备注补 r03 说明（**未新增编号**） |
| 素材库 | `素材库/美术设定集/03-物品与家具/ART_FURN_103_r03_*.png` | 四件归档副本 + 缩略图 |
| 素材库 | `素材库/美术总览.html` | 预览页重建（37 条） |
| 留档 | `转存库/ART_RUNTIME_004_留档/` | 母图、遮罩、3× 预览、960×540 示意图、交付说明（**不进 PCK**） |
| 截图 | `tests/screenshots/art004_*.png` | 17 张实机截图（8 检查点 × 关/开叠加层 + 1 张手部放大图） |
| 截图 | `tests/screenshots/art004_web_*.png` | 5 张 Web 端实机截图 |

### 3.2 提交记录

| 提交 | 内容 |
|---|---|
| `6a46a18` | `feat: ART-INTEGRATE-004 接入 r03 分层购物车与装载状态` |
| `（本次报告提交）` | `docs: ART-INTEGRATE-004 交付报告` |

两个提交均已推送 `origin/main`。

---

## 4. 四张素材的接入路径

| 素材 | 运行时路径 | 库内归档 | 原始来源（留档） | 画布 | 可见范围（实测 bbox） | 不透明像素 |
|---|---|---|---|---|---|---|
| back | `assets/facilities/ART_FURN_103_r03_back_128x112.png` | `素材库/美术设定集/03-物品与家具/ART_FURN_103_r03_back_128x112.png` | `转存库/ART_RUNTIME_004_留档/ART_FURN_103_r02_full_sprite_reference_128x112.png` | 128×112 | (16,14,82,90) | 949 |
| front | `assets/facilities/ART_FURN_103_r03_front_128x112.png` | 同上目录 `..._r03_front_...` | `转存库/ART_RUNTIME_004_留档/basket_front_region_mask.png` | 128×112 | (41,36,71,45) | 1534 |
| cargo_half | `assets/facilities/ART_FURN_103_r03_cargo_half_128x112.png` | 同上目录 `..._r03_cargo_half_...` | `转存库/ART_RUNTIME_004_留档/half_load_master.png` | 128×112 | (49,51,56,23) | 899 |
| cargo_full | `assets/facilities/ART_FURN_103_r03_cargo_full_128x112.png` | 同上目录 `..._r03_cargo_full_...` | `转存库/ART_RUNTIME_004_留档/full_load_master.png` | 128×112 | (47,40,60,34) | 1698 |

**导入参数**（四张统一，并**修正了 Godot 自动生成的默认值**）：

| 参数 | 值 | 说明 |
|---|---|---|
| `compress/mode` | 0（无损） | 保证像素与源文件逐位一致 |
| `mipmaps/generate` | false | 不做缩放模糊 |
| `process/fix_alpha_border` | **false**（Godot 默认是 true） | ⚠️ 见下 |
| `process/premult_alpha` | false | 与既有素材一致 |
| `detect_3d/compress_to` | **0**（Godot 默认是 1） | 避免被 3D 压缩路径接管 |

> ⚠️ **`fix_alpha_border` 必须关掉**：Godot 4.7 默认会把边缘颜色渗进 alpha=0 的像素。一旦打开，Back+Front 的合成结果就不再等于 r02 原图，**AE=0 直接失效**。本轮导入后立刻发现并改回 false，重新导入后 AE=0 复测通过。这一条是本轮最容易踩空的技术坑。

---

## 5. 节点及图层结构

### 5.1 节点树

```
art004_verify.tscn (Node2D)
├─ Stage (Node2D)                    ← 背景道具
├─ Cart (PushableCart)               ← ★ 必须先于 Player 入树
│  ├─ Back     (Sprite2D)  z=0  abs  ← 车把 / 后框架 / 支撑 / 车轮
│  ├─ CargoHalf(Sprite2D)  z=0  abs  ← 半载物资（EMPTY/HALF 可见）
│  ├─ CargoFull(Sprite2D)  z=0  abs  ← 满载物资（EMPTY/FULL 可见）
│  ├─ Front    (Sprite2D)  z=1  abs  ← 近侧篮网（常驻，永远压在人物之前）
│  └─ CartHotspot (Interactable/Area2D)  priority=20
├─ Player (CharacterBody2D)
│  ├─ Sprite (AnimatedSprite2D)
│  └─ Collision (CollisionShape2D) 28×160
├─ SolidWall (StaticBody2D)          ← 撞墙测试用
├─ Door (DoorInteractable)           priority=10
├─ Sensor (InteractionSensor)        z=20
├─ DebugOverlay (Art004Overlay)      z=10
└─ HUD (CanvasLayer)
```

### 5.2 绘制顺序

| z_index | 图层 | 相对人物 | 说明 |
|---|---|---|---|
| 0 | Back | 之后 | 车体后景结构 |
| 0 | Cargo | 之后 | 车内物资，在 Back 之后、人物之前 |
| 0 | **Player** | — | 人物 |
| 1 | Front | **之前** | 近侧篮网 → 正确遮挡腿部 |

同 z=0 的三层之间靠**树顺序**区分，因此**购物车节点必须先于人物节点进入场景树**。
`PushableCart.layer_order_is_valid()` 会比较两者的祖先链索引，违反时在 `bind()` 里打印警告；
ART-004 实测该断言为「通过」。

### 5.3 与 r02 时代的差别

r02 时代只有一张整图，前景层是**把同一张图再画一遍**到人物之前（见旧代码注释「这是单张图做的两层，不是美术给的前后分件；正式分件交付后应替换掉这一招」）。

本轮 r03 到位后，这招正式被替换：

| | r02（保留为回退） | r03（本轮） |
|---|---|---|
| 层数 | 2（Back=Front=同一张图） | 3（Back / Cargo / Front，各自独立） |
| Front 何时显示 | 仅当玩家与车**横向重叠**时 | **常驻显示**（近侧篮网是车的固有结构） |
| 遮挡效果 | 重叠时**整张车**压住人物 | 只有**近侧篮网**压住人物，远侧结构留在人物之后 |
| 装载状态 | 不支持 | EMPTY / HALF / FULL |

---

## 6. 空载、半载、满载的实机表现

### 6.1 像素合同

| 素材 | 画布 | alpha 档位 | 可见 bbox | 判定 |
|---|---|---|---|---|
| back | 128×112 | [0, 255] | (16,14,82,90) | ✅ |
| front | 128×112 | [0, 255] | (41,36,71,45) | ✅ |
| cargo_half | 128×112 | [0, 255] | (49,51,56,23) | ✅ |
| cargo_full | 128×112 | [0, 255] | (47,40,60,34) | ✅ |

四件画布**完全一致**，Back 可见底边 y=104 正好落在锚点上（**误差 0.0 px**）。

### 6.2 空车还原 AE=0（硬指标）

引擎内把 Back + Front 按同一锚点逐像素叠起来，与 `assets/facilities/ART_FURN_103_r02_tall_handle_128x112.png` 比：

```
[T] 通过 引擎内合成 Back+Front vs r02 → 差异像素 AE = 0（要求 0）  ← r02 原图 128×112
[T] 通过 合成可见范围 [P: (16.0, 14.0), S: (96.0, 90.0)] == r02 可见范围 [P: (16.0, 14.0), S: (96.0, 90.0)]
```

**AE = 0，差异像素 0 个。** 独立用 numpy 复算一遍同样是 0，两条路径结论一致。

补充实测：**Back 与 Front 的不透明像素完全不重叠（交集 0 像素）**——这正是「拆层不移动像素」的硬证据，说明 Front 是从 r02 整图里像素级切出来的，不是重新画的近似篮体。

### 6.3 三态实机表现

| 状态 | 组合 | 实机表现 |
|---|---|---|
| EMPTY | Back + Front | 篮网镂空处透出背景，车篮为空 ✅ |
| HALF | Back + Cargo_half + Front | 篮内有稀疏物资（箱 / 瓶装水 / 罐头 / 零食），篮网正确罩在物资之上 ✅ |
| FULL | Back + Cargo_full + Front | 篮内密实（毯子 / 箱 / 饮水 / 罐头 / 粮食），高度明显高于半载 ✅ |

- 半载不透明像素 **899**，满载 **1698**（多 799），两态在 960×540 正常视图下**可区分**。
- 两张货物图的像素内容差异 **1698 像素**，确认不是「同一张图改个名」。
- 货物层与篮网区域**必然相交**（货物被网罩住），因此货物层**必须画在 Front 之前**，否则会错误覆盖前景护栏 —— 代码里 Cargo 的 z=0、Front 的 z=1 就是为此。
- **半载与满载强制互斥**：`set_load_state()` 同时控制两个独立节点的 `visible`，实测 EMPTY / HALF / FULL 三态下互斥断言全部通过。

放大对照（4× Nearest，取自真实实机截图 `art004_empty/half/full.png`）：

![三态放大](tests/screenshots/art004_hand_contact_4x.png)

> 上图为手部接触区放大图；三态放大对照的原始素材见 `tests/screenshots/art004_{empty,half,full}.png`。

---

## 7. 与旧 r02 的像素差异

| 比较项 | 结果 |
|---|---|
| Back + Front 合成 vs r02 原图 | **AE = 0**（0 像素差异） |
| 可见范围 | 完全一致：(16,14,96,90) |
| Back ∩ Front 不透明像素 | **0 像素**（完全不相交，拆层未移动任何像素） |
| 货物层 ∩ Back | 0 像素（货物落在篮内空腔，不与后景重叠） |
| 货物层 ∩ Front | half 515 / full 933 像素（货物被网罩住 → Cargo 必须先画） |

**r02 仍完整保留**：文件在 `assets/facilities/`，台账状态仍是「运行时可用」，
`PushableCart.set_art_variant(PushableCart.ART_VARIANT_R02)` 可随时切回，实测来回切换后
Front 层仍常驻可见、热点与提示不受影响。

---

## 8. 人物遮挡和手部接触误差

### 8.1 遮挡实测（不是"看起来对"，是逐像素验证）

ART-004 的遮挡用例不采用「取一个点猜它有没有被盖住」，而是：

1. 用两张贴图的 **alpha 实测**求出人物与近侧篮网的**真实像素交叠点**（实测 **64 个**）；
2. 从**渲染出来的画面**取那一格的颜色；
3. 与篮网贴图该点的颜色比对。

```
[T] 通过 站进车里时人物与近侧篮网存在像素交叠（交叠点 64 个）
[T] 通过 交叠点 (496,350) 渲染色 = 篮网色（误差 0.000，篮网=0.11,0.09,0.09）  ← 实际=0.11,0.09,0.09
[T] 通过 人物离开车体范围后不再与篮网交叠（不重叠）
```

**误差 0.000** —— 交叠处画出来的就是篮网，人物确实被正确压住。

### 8.2 手部接触误差（80px 冻结间距）

ART-004 用的是 **Back 层**（r03 的车把在 Back 里），测的是真实扶车姿态下的手部与车把：

| 侧位 | 逻辑间距 80px | 水平间隙 | 垂直差 | 判定 |
|---|---|---|---|---|
| side=+1（玩家在车右、车镜像） | 80px | **+1.0 px** | −1.0 px | ✅ 贴合 |
| side=-1（玩家在车左） | 80px | **+2.0 px** | −1.0 px | ✅ 贴合 |

**与 ART-003 用 r02 测得的数值完全一致（+1.0 / +2.0 px）** —— 这从侧面证明 r03 的 Back 层车把与 r02 原图中的车把像素位置完全相同，AE=0 不只是「合成结果相同」，也意味着「手能摸到的那个把手还在原位」。

美术参考值 74px 仅作对照量了一次（会轻微重叠：−5.0 / −4.0 px），
**`side_offset` 保持冻结值 80，没有改成 74**。

### 8.3 放大的手部接触图

`tests/screenshots/art004_hand_contact_4x.png`（800×908）——由真实实机截图裁剪 + 4× Nearest 放大，
并标注水平与垂直误差：

![手部接触放大](tests/screenshots/art004_hand_contact_4x.png)

放大后可见**拳心贴在车把末端的端帽上**，1–2px 的间隙是"没有穿模"的余量，不是穿帮。

---

## 9. Windows / Web 测试结果

### 9.1 Windows（Godot 4.7.2 真实窗口运行）

| 测试 | 命令 | 结果 |
|---|---|---|
| 启动自检 | `--dev-scene=smoke --shot=smoke.png --quit` | **26/26 通过，失败 0** |
| 场景巡检 | `--scene-tour --quit` | **4/4 切换成功，失败 0** |
| CORE-001B | `--dev-scene=core001b --core-test --quit` | **30/30 通过，失败 0** |
| CORE-001B 门切换 | `--dev-scene=core001b --core-test-door --quit` | **通过**（连按保护 + 切换增量 = 1） |
| ART-003 | `--dev-scene=art003 --art003-test --quit` | **29/29 通过，失败 0** |
| **ART-004** | `--dev-scene=art004 --art004-test --quit` | **33/33 通过，失败 0** |
| **ART-004 门进出** | `--dev-scene=art004 --art004-door --quit` | **6/6 通过，失败 0** |
| 素材库页面 | `node tools/check_artlib_page.mjs` | **25/25 通过** |
| 素材 ID 登记 | `python tools/check_id_registry.py` | **全部通过，警告 0**（38 个号 / 台账 37 行） |

### 9.2 ART-004 的 33 项用例明细

```
[A]  r03 四件分件像素合同（画布 / alpha 档位 / 可见 bbox）              4 项
[A2] 货物内容归属（半载满载可区分、不越出护栏）                          3 项
[B]  锚点与坐标一致性（锚点误差 0 / 画布统一 / 车长 96 冻结）            3 项
[C]  空车还原 AE=0（合成 vs r02 / 可见范围一致）                        2 项
[D]  装载状态互斥（EMPTY / HALF / FULL）                                3 项
[E]  手部贴合（两侧 ±8 内 / 74px 仅对照）                                2 项
[F]  镜像（整层翻转 / 身体中轴 / 不碰碰撞盒）                            3 项
[G]  图层顺序与遮挡（Front 常驻 / 树序 / 像素交叠 / 渲染色）              4 项
[H]  购物车交互回归（绑定 / 解绑 / 穿行 / 联动 / 撞墙）                   5 项
[I]  交互提示与门（门提示 / 车优先级）                                   2 项
[J]  r02 回退能力（双向切换 / Front 仍常驻）                             3 项
```

### 9.3 Web（Chrome 157，CDP 驱动）

| 测试 | 脚本 | 结果 |
|---|---|---|
| Web 冒烟（三视口） | `tools/web_smoke_cdp.mjs` | **通过**，控制台 error **0** 条 |
| Web PREP-003 | `tools/check_prep003_web.mjs` | **5/5 通过** |
| Web ART-003 | `tools/check_art003_web.mjs` | **9/9 通过** |
| Web CORE-001B | `tools/check_core001b_web.mjs` | **17/17 通过** |
| **Web ART-004** | `tools/check_art004_web.mjs`（本轮新增） | **15/15 通过** |

Web ART-004 覆盖：三态装载切换（`?load=half|full`）、画布 960×540、r03 分层贴图在 PCK 内、
重叠遮挡、镜像绑定、**全程控制台 0 error**。

### 9.4 PCK 体检（15.74 MB）

`builds/web/index.pck` = **16,509,200 B = 15.74 MiB**（上一轮 15.68 MB，**+0.06 MB**；
四张 r03 PNG 合计仅 54,032 B，其余增量来自新增场景与脚本）。

**必须在包内** ✅：

```
OK  ART_FURN_103_r03_back_128x112
OK  ART_FURN_103_r03_front_128x112
OK  ART_FURN_103_r03_cargo_half_128x112
OK  ART_FURN_103_r03_cargo_full_128x112
OK  ART_FURN_103_r02_tall_handle_128x112      （r02 回退仍可用）
OK  ART_FURN_101_r01_empty_shelf_128x208
OK  ART_ITEM_101_r02_water_64x48
OK  ART_ITEM_102_r02_food_carton_64x64
```

**绝不在包内** ✅（字节级扫描全部 CLEAN）：

```
CLEAN  half_load_master                    CLEAN  full_load_master
CLEAN  basket_front_region_mask            CLEAN  ART_FURN_103_r03_states_3x
CLEAN  ART_FURN_103_r03_actor_occlusion_test_3x
CLEAN  ART-RUNTIME-004_supermarket_mock_960x540
CLEAN  ART_FURN_103_r02_full_sprite_reference
CLEAN  美术设定集        CLEAN  素材台账.csv
CLEAN  美术总览.html     CLEAN  .thumbs
CLEAN  转存库
```

旧错误商品图（`ART_ITEM_101_r01_*` / `ART_ITEM_102_r01_*`）仍在包内**仅作追溯**，
脚本里**没有任何 preload 指向它们**（沿用 ART-FIX-003C 的结论，本轮未新增引用）。

---

## 10. 素材台账及白名单变化

### 10.1 台账（`素材库/素材台账.csv`：33 → **37 行**）

**状态变更（按总监裁定）**：

| 素材ID | 版本 | 变更前 | 变更后 |
|---|---|---|---|
| `ART_ITEM_101` | r02 | 待总监验收 | **运行时可用** |
| `ART_ITEM_101` | r02-shelf | 待总监验收 | **运行时可用** |
| `ART_ITEM_102` | r02 | 待总监验收 | **运行时可用** |
| `ART_ITEM_102` | r02-shelf | 待总监验收 | **运行时可用** |

> 本轮**只同步审核状态**，没有重新制作、也没有修改任何商品图（内容归属断言在 ART-003 回归里仍然全过）。

**新增四行**：

| 素材ID | 版本 | 名称 | 制作状态 | 审核状态 | 运行时路径 |
|---|---|---|---|---|---|
| `ART_FURN_103` | r03-back | 空购物车 · 分层后景 | 分层后景可用 | **待审核** | `assets/facilities/ART_FURN_103_r03_back_128x112.png` |
| `ART_FURN_103` | r03-front | 空购物车 · 分层近侧篮网 | 分层前景可用 | **待审核** | `assets/facilities/ART_FURN_103_r03_front_128x112.png` |
| `ART_FURN_103` | r03-half | 空购物车 · 分层半载物资 | 分层货物可用 | **待审核** | `assets/facilities/ART_FURN_103_r03_cargo_half_128x112.png` |
| `ART_FURN_103` | r03-full | 空购物车 · 分层满载物资 | 分层货物可用 | **待审核** | `assets/facilities/ART_FURN_103_r03_cargo_full_128x112.png` |

**ID 登记表**：**没有新增编号**。r03 属于 `ART_FURN_103` 的新版本，已在该号的备注里补说明
（`check_id_registry.py` 校验通过：38 个号，已用 18 / 预留 19 / 空置 1，警告 0）。

### 10.2 白名单（`tools/check_artlib_page.mjs`）

运行时白名单从 6 条扩到 **10 条**（新增商品 r02 / r02-shelf 四条），
并新增两条**针对 r03 的反向断言**：

```
OK  r03 购物车四件分件全部为「待审核」（本轮不升运行时可用）
    实际 4 条，状态 r03-back:待审核,r03-front:待审核,r03-half:待审核,r03-full:待审核
OK  r03 四件分件均未进入运行时白名单
OK  「运行时可用」仅限已批准白名单（角色 r01–r03 + 车 r01/r02 + 货架 r01 + 商品 r02/r02-shelf）
    10 条，越权 无
```

这样以后谁想把 r03 提前标成「运行时可用」，素材页验收会**直接报错**，
而不是靠人记着规矩。

---

## 11. 截图清单

**全部来自真实 Godot 运行**（Windows 实机 + Web 实机），原生 960×540，无合成示意图。

| 文件 | 内容 |
|---|---|
| `art004_empty.png` / `_debug.png` | ① 空购物车（Back + Front） |
| `art004_half.png` / `_debug.png` | ② 半载（Back + Cargo_half + Front） |
| `art004_full.png` / `_debug.png` | ③ 满载（Back + Cargo_full + Front） |
| `art004_behind.png` / `_debug.png` | ④ 人物站在车后 |
| `art004_overlap.png` / `_debug.png` | ⑤ 人物与前景护栏重叠 |
| `art004_mirror.png` / `_debug.png` | ⑥ 朝左镜像状态 |
| `art004_push.png` / `_debug.png` | ⑦ 朝右推车状态 |
| `art004_wall.png` / `_debug.png` | ⑧ 推车撞墙状态 |
| `art004_hand_contact_4x.png` | 放大的手部接触图（4× Nearest，标注水平/垂直误差） |
| `art004_web_{empty,half,full,overlap,mirror}.png` | Web 端实机截图 |

`_debug` 版本叠加调试层：人物可见框（橙）、碰撞盒（红）、车可见框（青）、
画布框（细青）、Back 层（绿）、Front 层（橙红）、Cargo 层（黄/紫）、手部间隙标线。

---

## 12. 未完成问题及需要美术总监裁定的事项

### 12.1 需要总监拍板

1. **`ART_FURN_103 r03` 四件的运行时状态** —— 本轮已跑通全部实机用例，
   但按任务书要求**未擅自升「运行时可用」**，台账四行仍为「待审核」。
   请总监复核本报告后决定是否升状态；升状态时需同步在
   `tools/check_artlib_page.mjs` 的 `APPROVED_RUNTIME` 里加四条（现在有断言会拦住越权）。

2. **r03 是否替换正式运行时默认** —— 当前 `PushableCart.art_variant` 默认仍是
   `r02`（已批准的那个），r03 在 `art004` 开发场景里显式启用。
   这样正式运行时行为**本轮完全不变**，回退只需改一个默认值。
   是否把默认值切到 r03，请总监裁定。

3. **半载 / 满载的视觉档位是否够用** —— 目前只有三档视觉状态，
   货物图是整块贴图（半载 899 px / 满载 1698 px 不透明像素）。
   若后续希望「装一点点」和「装半篮」有区别，需要美术再出第三档。

4. **左向专用绘制** —— r03 目前仍是**水平镜像**得到左向，
   与角色现状一致。美术侧若要出真正的左向版本，需要再交付两套。

### 12.2 本轮明确未做（等后续裁定）

- ART-RUNTIME-005（已由美术侧完成，仍在等待队列，未接入）
- CORE-002（购物、库存、结算、建造、存档）
- 推车行走动画（扶车四帧循环）
- 车轮滚动动画
- 购物库存 / 真实物品容量 / 购物结算 / 装载重量 / 持久化 / 自动装载阈值
  —— 装载状态**纯视觉**，切状态不动任何逻辑

### 12.3 技术遗留

- `fix_alpha_border` 的坑已在 §4 记录。**后续若再导入新贴图，务必核对
  `process/fix_alpha_border=false` 与 `detect_3d/compress_to=0`**，否则 AE 类断言会假失败。
- 购物车节点**必须先于人物节点入树**（同 z=0 的层靠树序区分）。
  `PushableCart.layer_order_is_valid()` 会在绑定时检查并警告。
  正式场景摆放购物车时请注意这个顺序。

---

## 13. 复现命令

```bash
# ART-004 实机用例（33 项）
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- --dev-scene=art004 --art004-test --quit

# ART-004 门进出回归（6 项）
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- --dev-scene=art004 --art004-door --quit

# 八个检查点截图（叠加层关/开各一张）
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- --dev-scene=art004 --art004-tour --quit

# 手部接触 4× 放大图（只处理真实实机截图）
python tools/make_hand_contact_zoom.py

# 回归
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- --dev-scene=smoke --shot=smoke.png --quit
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- --scene-tour --quit
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- --dev-scene=core001b --core-test --quit
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- --dev-scene=art003 --art003-test --quit
python tools/build_artlib.py && python tools/check_id_registry.py

# Web 回归
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Web" builds/web/index.html
python tools/serve_web.py
CDP_PORT=9444 node tools/check_art004_web.mjs
CDP_PORT=9444 node tools/check_art003_web.mjs
CDP_PORT=9444 node tools/check_core001b_web.mjs
CDP_PORT=9444 node tools/web_smoke_cdp.mjs
```
