# ART-INTEGRATE-005 交付报告｜购物车 r03 转正 + 许知夏推车行走 r04 接入

- 日期：2026-11-09
- 工程：`https://github.com/tangjue3/Coldwave_Checklist`（Godot 4.7.2，gl_compatibility，960×540）
- 上一轮基线：工程 `6a46a18`、报告 `14d58aa`（ART-INTEGRATE-004）
- 素材包：`Coldfront_ART_RUNTIME_005_push_walk_r04_v1.zip`（`ART_CHAR_001 r04`，四帧 `push_walk_right`）

---

## 1. 提交记录

| 提交 | 内容 |
|---|---|
| `3854eeb` | `feat: ART-INTEGRATE-005 r03 购物车转正默认 + r04 推车行走动画接入` |
| `34f0977` | `docs: ART-INTEGRATE-005 交付报告` |

两个提交均已推送 `origin/main`。

## 2. 阶段1：ART-INTEGRATE-004 最终裁定同步

### 2.1 台账与白名单

| 项 | 变化 |
|---|---|
| 素材台账 | `ART_FURN_103 r03-back / r03-front / r03-half / r03-full` 四行「待审核 → 运行时可用」，制作说明追加裁定记录（`tools/sync_ledger_005_phase1.py`，脚本留档可复现） |
| 素材总览页 | 重新生成（38 条资产），审核状态同步显示 |
| 运行时白名单 | `tools/check_artlib_page.mjs` 中 `APPROVED_RUNTIME` **10 → 14 条**（新增 r03 四件） |
| 反向断言 | 原「r03 必须待审核、不得进白名单」两条断言**改为**「四件必须为运行时可用 + 必须全部在白名单内」——质量保护保留，只翻转判定方向，未删除任何检查 |
| ID 登记表 | 校验全绿（38 个编号，警告 0） |
| 素材页检查 | **25/25 通过**（含新断言） |

### 2.2 默认购物车版本 r02 → r03

- `PushableCart.art_variant` 导出默认值改为 `ART_VARIANT_R03`（`scripts/objects/pushable_cart.gd`）。
- 所有场景均未显式覆写 `art_variant`（已 grep 确认），默认切换即全局生效。
- **r02 完整保留**：贴图、`_build_r02_visual()`、`set_art_variant()` 双向回退能力不变；
  art004 场景 [J] 组断言「可切回 r02 / 可切回 r03 / 切换后 Front 常驻」继续通过。
- EMPTY / HALF / FULL 三档与互斥逻辑不变。
- 水平镜像不变，未新增左向美术。
- **物理参数一个未改**：间距 80、车长 96、推速 80 / 拉速 40、碰撞 28×160、锚点 (64,104)、960×540。

### 2.3 切换引发的唯一回归差异（已修复，不是删断言）

ART-003 场景有一条 r02 时代断言：「站在车旁前层隐藏 / 与车重叠才显示」——这是 r02
「单图横向重叠时再画一遍」的临时做法行为。r03 的近侧篮网是**固有结构、常驻显示**
（ART-004 已定的行为基线），因此默认切 r03 后该断言失败。

处理：`scripts/dev/art003_verify.gd` 中该断言**按版本分支**——r03 断言「常驻显示」，
显式切回 r02 时仍断言旧行为。修复后 ART-003 **29/29 通过**。没有删除任何断言。

### 2.4 ART-004 报告 §9.2 统计差异勘误

实测结论：**是报告笔误 + 统计口径过期，不是用例缺失**。

- 按当前 `art004_verify.gd` 实跑逐项统计，用例总数为 **35 项**，非报告所写 33 项；
- [G]（图层顺序与遮挡）实际 **5 项**（报告写 4 项）：遮挡检测在验收后期从「单点判定」
  升级为「像素求交 + 渲染取色」时追加了「离开车体后不复叠」用例，报告抄的是旧口径；
- 提示组标签代码里实际是 `[HINT]`，报告误写为 `[I]`；
- 已修正 `docs/ART-INTEGRATE-004_交付报告.md`：§9.2 更正为 35 项明细并附勘误说明，
  摘要表 / §9.1 / §13 的「33/33」同步更正为「35/35」。**未删改任何测试代码。**

## 3. 阶段2：ART-RUNTIME-005（r04 四帧）接入

### 3.1 像素合同核验（引擎内实测）

| 检查项 | 结果 |
|---|---|
| 画布 | 四帧均 128×176 ✅ |
| alpha 档位 | 均仅 0/255 两档 ✅ |
| 顶部可见坐标 | 均为 y=8 ✅ |
| 最后不透明脚底行 | 均为 y=167（可见高严格 160）✅ |
| 上身 88 行复用 r03 | 四帧与 r03 逐像素差异 **0 px** ✅ |
| SHA256 | 与交付包 `QA_FRAME_SHA256.txt` 完全一致 ✅ |

### 3.2 接入路径

| 项 | 路径 |
|---|---|
| 四帧运行时贴图 | `assets/characters/ART_CHAR_001_r04_push_walk_right_{00_contact,01_transfer,02_contact,03_transfer}.png` |
| SpriteFrames | `assets/characters/player_sprite_frames.tres` 新增 `push_walk_right` 动画（4 帧、loop、6 FPS 默认） |
| 导入参数 | `fix_alpha_border=false`、`premult_alpha=false`、`mipmaps=false`、`detect_3d/compress_to=0`、无损、Nearest（Godot 默认 `fix_alpha_border=true` 会污染透明边缘，已按上轮经验修正并复核） |
| 母图 / 预览 / GIF | `转存库/ART_RUNTIME_005_留档/`（含 README、QA 哈希表），不进 PCK |
| 素材库 | 四帧拷入 `素材库/美术设定集/01-角色/`，台账新增 r04 行（**待审核 / 引擎试用**） |

### 3.3 动画控制与状态机

复用现有 `AnimatedSprite2D` + `SpriteFrames` + 购物车状态机，未引入第二套动画框架：

| 状态 | 动画 | 实现位置 |
|---|---|---|
| 普通移动 | `walk_right`（r02，不变） | `player_controller._sync_animation()` |
| 普通待机 | `idle`（r01，不变） | 同上 |
| 绑定未动 | `push_idle`（r03 单帧） | 同上（`push_walk_active=false`） |
| 绑定 + 向前实际移动 | **`push_walk_right`（r04 四帧）** | 购物车 `_physics_process` 每帧调 `player.set_push_moving(pushing and spd > 1.0)` |
| 推车撞墙（实际位移 0） | 切回 `push_idle` | `dx=0 → spd=0 → set_push_moving(false)` |
| 反向拉车（40px/s） | 保持 `push_idle`（原过渡，**存在脚步滑动**，见 §8） | `pushing=false → set_push_moving(false)` |
| 解绑 | 恢复 `idle / walk_right` | `set_push_pose(false)` 时顺带清 `push_walk_active` |

未新增转身、后退或其他人物动画。FPS 做成导出项 `push_walk_fps`（默认 6），A/B 由验证场景切换。

## 4. 动画专项实测（Windows 实机）

| 检查项 | 结果 |
|---|---|
| 播放顺序 | SpriteFrames 帧序 = 交付包顺序 00→01→02→03 ✅ |
| 帧数 / FPS | 4 帧 / 默认 6 FPS（导出项生效）✅ |
| 脚底误差 | 四帧均 y=167，**误差 0.0 px** ✅ |
| 头部横向漂移 | 头顶 32 行中轴 r03=62.5，四帧均 62.5，**漂移 0.00 px** ✅ |
| 双手稳定 | 手部行带四帧均 (77,83)，与 r03 相同；上身 88 行逐像素 0 差异 ✅ |
| 与车把距离 | 冻结逐帧实测手部间隙：帧 0/1/2/3 均 **+2.0 px**（基线差 +0.0）✅ |
| 静止→行走切换 | 身体中轴 -0.5 → -0.5，**无瞬移**；第 0 物理帧即切入 ✅ |
| 行走→静止切换 | 撞墙后位移 0，动画切回 push_idle，无横跳 ✅ |
| 180 帧连续循环 | 采样 180 帧无乱序；脚底世界 y 恒定 416（抖动 0 px）；手部间隙 2.0–2.1 px（波动 0.1 px）✅ |
| 撞墙 | 车右沿 700 ≤ 墙左沿 700，整组停住，动画回 push_idle ✅ |

ART-005 验证场景（`--dev-scene=art005 --art005-test`）合计 **33/33 项通过**。

## 5. FPS 对照：6 vs 7

推速两种设置下都精确保持 80 px/s（实测 80.0，±2 容差内无漂移）。

| 设置 | 单循环理论 | 实测（4s 窗口统计，±1 相位容差） | 循环推进 | 每动画帧 |
|---|---|---|---|---|
| 6 FPS | 0.667 s | 0.57 s | ≈53.3 px | 166.7 ms / 13.3 px |
| 7 FPS | 0.571 s | 0.57 s | ≈45.7 px | 142.9 ms / 11.4 px |

**观测结论（连续运行目检 + 帧序采样，非静态截图）：**

1. **步幅与速度**：80 px/s 下两种 FPS 都没有明显滑步——contact 帧（00/02）之间车推进
   53.3 px（6FPS）/ 45.7 px（7FPS），与跨步步幅量级吻合；transfer 帧只占一帧，脚离地
   时间短，滑行感不明显。
2. **节奏**：6 FPS 步子更大更舒展，但半步跨 26.7 px 略超过人物腿长的自然步幅，推 96px
   长的重物时观感偏「赶路」；7 FPS 步幅 22.9 px 更接近小步推车的自然节奏。
3. **03→00 接回**：03_transfer 与 00_contact 都是单脚支撑过渡帧，上身 88 行逐像素相同，
   引擎采样 180 帧未见跳变；两种 FPS 下接回均不突兀。
4. **切换横跳**：push_idle ↔ push_walk 切换时身体中轴不变（-0.5），无横跳。
5. **头手抖动**：上身 88 行逐像素复用，头部漂移 0.00 px、手部间隙逐帧 ±0.0 px，无抖动。

**推荐：7 FPS**。理由：与普通行走 `walk_right`（7 FPS）节奏统一；推车速 80 低于步速 100，
同样 7 FPS 下步幅自然变短，符合「小步推重物」的观感；transfer 帧更短进一步压低滑步感。
当前默认值仍为交付包建议的 6 FPS（`push_walk_fps=6`），**最终采用哪个请总监裁定**，
切换只需改一个导出属性。

对照截图：`tests/screenshots/art005_fps_ab.png`（6 / 7 FPS 上下并排，均为真实运行截图）。

## 6. 购物车专项（默认 r03 下回归）

- EMPTY / HALF / FULL 三态正常、半载满载互斥 ✅（art004 [D] 组）
- r03 默认显示、r02 绑定中可回退再切回 ✅（art004 [J] 组、art005 [J] 组）
- 人物遮挡：近侧篮网常驻、像素交叠 + 渲染色验证 ✅（art004 [G] 组 5 项）
- PARKED 穿行、PUSHING 联动、撞墙、解绑 ✅（art004 [H] 组）
- 朝左镜像：整层翻转 + push_walk_right 镜像播放正常（`art005_mirror.png`）✅
- 门与货架交互：art004 门回归 + art005 门回归均通过 ✅

## 7. 全量回归与 PCK

| 测试 | 结果 |
|---|---|
| Windows smoke | **26/26** |
| 场景巡检 | **4 次切换 0 失败** |
| CORE-001B | **30/30** |
| ART-003 | **29/29** |
| ART-004 | **35/35** |
| ART-004 门回归 | **通过（0 失败）** |
| ART-005 | **33/33** |
| 素材库页面检查 | **25/25**（白名单 14 条断言生效） |
| ID 登记检查 | **全绿（警告 0）** |
| Web 冒烟 | 通过，控制台 error 0 |
| Web PREP-003 | **5/5** |
| Web ART-003 | **9/9** |
| Web CORE-001B | **17/17** |
| Web ART-004 | **15/15** |
| Web ART-005（本轮新增 `tools/check_art005_web.mjs`） | **5/5** |

**PCK 体检**：`builds/web/index.pck` = 16,576,852 B = **15.81 MiB**（上轮 15.74，+0.07）。
r04 四帧、r03 分件、r02 回退图均在包内；母图 / 预览 / GIF / 素材库 / 转存库全部不在包内（字节级核验 CLEAN）。

## 8. 未解决问题与待裁定事项

1. **反向拉车脚步滑动（保留现状）**：拉车（40 px/s）仍播 `push_idle` 单帧，人物位移时
   脚不迈步，存在与上轮相同的滑行感。本轮按任务书要求未新增后退动画；如需消除，
   需美术补一套反向（或通用）拉车帧——建议与「手包握把中段」返修一并考虑。
2. **手部 1–2px 间隙（保持冻结）**：side=+1 间隙 +1.0 px、side=-1 +2.0 px，与 ART-003/004
   基线一致。r04 四帧因上身 88 行复用，逐帧间隙与基线完全相同（±0.0），**未扩大**。
   未改 r03 手臂、车把或 80px 间距。
3. **FPS 采用**：实测推荐 7 FPS（§5），当前默认 6 FPS，待裁定后改一个导出属性即可。
4. **`ART_CHAR_001 r04` 状态**：全部用例通过，仍保持「**待审核 / 引擎试用**」，
   白名单未加入（素材页断言拦截越权）。升格请总监裁定。
5. **r02 回退路径**：`set_art_variant()` 与 r02 全套资源完整保留，随时可切回。

## 9. 截图与动态预览（全部真实 Godot 运行，960×540 原生）

| 检查点 | 文件 |
|---|---|
| 第 00/01/02/03 帧 | `tests/screenshots/art005_f0..f3.png`（并排放大：`art005_frames_2x.png`） |
| 静止→行走切换瞬间 | `art005_switch.png` |
| 推车连续移动 | `art005_moving.png` |
| 人物与车篮重叠 | `art005_overlap.png` |
| 推车撞墙停止 | `art005_wall.png` |
| 朝左镜像 | `art005_mirror.png` |
| 6 / 7 FPS 对照 | `art005_fps_6.png`、`art005_fps_7.png`、并排 `art005_fps_ab.png` |
| 动态预览 GIF | `art005_push_walk.gif`（60 帧引擎连拍 `art005_gif_00..59.png` 组装，帧内容全部来自真实渲染） |
| Web 实机 | `art005_web.png` |

## 10. 复现命令

```bash
# ART-005 实机用例（33 项）
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- --dev-scene=art005 --art005-test --quit

# ART-005 门进出回归 / 截图组 / GIF 素材 / FPS 单态截图
... --dev-scene=art005 --art005-door --quit
... --dev-scene=art005 --art005-tour --quit
... --dev-scene=art005 --art005-gif --quit
... --dev-scene=art005 --art005-fps=6 --quit   # 或 7

# Web（需 serve_web.py + 无头 Chrome 9444）
CDP_PORT=9444 node tools/check_art005_web.mjs

# 素材库 / ID 登记
python tools/build_artlib.py && python tools/check_id_registry.py
node tools/check_artlib_page.mjs
```

---

**停止声明**：本轮只做了 ART-004 收尾（状态同步 + 默认切换 + 报告勘误）与 ART-005 接入。
未开始 CORE-002，未做购物库存 / 容量 / 结算 / 存档，未制作新的角色动作与车轮动画，
未修改既有美术母图，未改动物理 / 碰撞 / 速度 / 相机参数，未擅自批准 r04 运行时状态。
报告提交后停止，等待美术总监审核与下一步裁定。
