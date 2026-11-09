# ART-INTEGRATE-005E 交付报告｜ART_CHAR_001 r09 扶车返工接入

- 日期：2026-11-09
- 任务来源：`转存库/ART_ANIM_005E_留档/ART-INTEGRATE-005E_交接提示词.md`（用户于 2026-11-09 15:22 确认 r09 美术效果后生效）
- 素材包：`转存库/ART-ANIM-005E_r09_修复成品.zip`，SHA-256 `4fb3e85f25a4038288712a674723df6f29c36b7a191407081358beb76525668a`
- 上一轮基线：工程 `3854eeb`、报告 `34f0977`、哈希修正 `3b41a0d`（ART-INTEGRATE-005）
- 工程：Godot 4.7.2 stable / GDScript / gl_compatibility / 960×540 整数倍 + Nearest

---

## 0. 结论摘要

| 交付项 | 结果 |
|---|---|
| r09 素材归档 | 17 张 runtime PNG 进 `assets/characters/` 与 `素材库/美术设定集/01-角色/`，留档 26 个普通文件 + QA_SHA256 表 |
| 登记状态 | 台账新增 `ART_CHAR_001 / r09` 一行：**待审核 / 引擎试用**；白名单仍 14 条，**r09 不在其中** |
| 动画接入 | `r09_push_idle`（1 帧）+ `r09_push_walk_right`（16 帧 / 10 FPS / loop）；默认 r09，r03/r04 全部保留可回退 |
| 新增实机验证场景 | `art005e`：32 项用例，**32/32 通过，失败 0** |
| 世界固定地面 | 240 物理帧 / 40 次采样，车位移 **320.0 px**、实测 **80.00 px/s**、动画回绕 **2 次** |
| 脚掌世界滑移残差 | 承重段均值 **1.29 px/动画帧**（美术声明 1–3 px 固有微变化，不宣称 0px） |
| 全量回归 | 桌面 9 组全绿；Web 8 组全绿；素材页 28/28；ID 校验 0 警告 |
| PCK | 15.92 MiB；r09 十七张 **17/17 在包内**；母图 / GIF / 报告 / 预览 / 素材库 / 转存库 **CLEAN** |
| 状态 | **r09 保持待审核**。未启动 CORE-002，未做购物 / 库存 / 结算 / 存档 / 剧情 |

### 三条需要总监知道的结论

1. **默认扶车动画已从 r04 换成 r09**，全局生效。这是「确认美术效果」的直接结果。r04 的 6/7 FPS 裁定不再影响默认画面；r09 固定 10 FPS。
2. **旧回归没有减少测试项，但两处按版本做了适配**：`art005_verify.gd` 是 r04 专项，在 `_ready()` 显式固定回 r04；`check_art003_web.mjs` 的扶车姿态断言兼容两种动画名。首次回归曾因此出现 6 项失败，修复后 34/34 通过（详见 §7.1）。
3. **脚掌不是物理意义上的 0px 滑步**。固定世界里承重段仍有 1.29 px/动画帧的残差，与美术交付报告「鞋底承重段 1–3px 微变化」一致；不接受用「每帧脚底 y=167」推断无滑步。

---

## 1. 范围：做了什么、没做什么

**做了**

- 解包留档（zip 原件保留，`.gdignore` 隔离）、17 张贴图复制、`.import` 参数修正；
- 台账 / ID 登记表 / `ID登记表.md` / 离线 `美术总览.html` / 修订版台账重建；
- `check_artlib_page.mjs` 增加 3 条 r09 防越权断言（状态、白名单、帧数与旧版本状态）；
- `player_sprite_frames.tres` 新增 17 个 ext_resource 与 2 个动画；
- `player_controller.gd` 增加 `push_anim_variant` / `push_walk_r09_fps` / `set_push_anim_variant()`；
- `SceneRouter` 新增 `art005e` dev 入口与 Web `?dev=art005e&state=` 参数；
- 新增 `art005e_verify` 场景与 32 项用例、4 个工具脚本、88 张实机截图、2 个 GIF、2 张拼图；
- `docs/开发说明.md` 新增 §7.4 与对应命令，标题同步到本轮版本。

**没做（按任务书禁止项）**

- 没删 r03 / r04 任何动画、贴图或回退路径；没改「运行时可用」白名单；
- 没改任何冻结物理参数（碰撞、间距、速度、锚点、分层、视口）；
- 没做朝左独立帧、反向拉车动作、车轮滚动、搬运动画；
- 没开始 CORE-002、购物 / 库存 / 容量 / 结算 / 存档 / 剧情 / 建造；
- 没把预览 GIF、母图、交付报告、交接提示词放进 `assets/` 或 PCK。

---

## 2. 归档与登记

| 项 | 结果 |
|---|---|
| 解包 | `转存库/ART_ANIM_005E_留档/`：`runtime/` 17 张、`previews/` 5 个、2 份 md、README、QA_SHA256，共 26 个普通文件 |
| 运行时副本 | `assets/characters/ART_CHAR_001_r09_*.png` 17 张，逐字节与包内一致 |
| 素材库副本 | `素材库/美术设定集/01-角色/ART_CHAR_001_r09_*.png` 17 张 |
| 台账 | 39 行（新增 1 行 `ART_CHAR_001 / r09`）：制作状态 `引擎试用`、审核状态 `待审核`、16 帧 / 10 FPS / 128×176 |
| ID 登记 | `ART_CHAR_001` 已是「已用」号，**不新开号**；`ID登记表.csv` 备注追加版本记录，`check_id_registry.py` 全绿（38 号，警告 0） |
| 导入参数 | 17 份 `.import` 全部 `compress/mode=0` / `mipmaps=false` / `fix_alpha_border=false` / `premult_alpha=false` / `detect_3d/compress_to=0` |
| 白名单 | `APPROVED_RUNTIME` **保持 14 条不变**；新增断言「r09 必须待审核且不在白名单」「r03/r04 原状态未改」 |

包内两份 md 与全部预览只在 `转存库/` 留档（受 `.gdignore` 隔离），不参与 Godot 导入。

---

## 3. 引擎接入

| 状态 | 动画 | 触发条件 |
|---|---|---|
| 普通待机 | `idle`（r01，不变） | 未推车、静止 |
| 普通行走 | `walk_right`（r02 四帧 / 7 FPS，不变） | 未推车、移动 |
| 扶车静止 | **`r09_push_idle`**（1 帧） | 绑定后；停住 / 撞墙 / 拉车 / 刚绑定 |
| 扶车推行 | **`r09_push_walk_right`**（16 帧 / 10 FPS / loop） | 绑定 + 向前推 + 实际位移 > 0 |

`PushableCart` 一行未改，仍由 `set_push_pose()` / `set_push_moving()` 驱动；`PlayerController._sync_animation()`
只按 `push_anim_variant` 选动画名，**没有第二套状态机**。`set_push_anim_variant(PUSH_ANIM_R04)` 可整组回退到
r03 静止 + r04 四帧，验证场景已实测切换与切回。

---

## 4. 实机验证：art005e 32 项

`--dev-scene=art005e --art005e-test`，退出码 0，`[T] 通过 32` / `[T] 失败 0`。

### [A] 像素合同（11 项）

17 张均 128×176、alpha 仅 0/255 两档、顶行 y=8、最后可见行 y=167（脚底基线 168）；
16 张行走帧像素数据两两不同；SpriteFrames 帧序 00→15 与交付包一致；
`r09_push_walk_right` 16 帧 / 10.0 FPS / loop；`r09_push_idle` 1 帧；r03/r04 旧动画仍在；
16 帧 y=0..94 与 r09 静止帧逐像素一致、y=0..60 与工程 r03 逐像素一致、头部中轴全部相同（不漂移）。

### [B] 状态机（8 项）

绑定→`r09_push_idle`；向前实际推行→`r09_push_walk_right`；停住→回静止；
反向拉车（40 px/s）→保持静止；撞墙实际速度 0 →静止（不原地踏步，撞墙计数 51）；
解绑→`walk_right`；切 r04 →`push_walk_right`；切回 r09 →`r09_push_walk_right`。

### [C] 世界固定地面（6 项，见 §5）

### [D] 接触 / 图层 / 镜像 / 冻结参数（7 项）

手部行带（y=70..95）与车 Back 层像素求交 **26 px**，命中世界 x=252..256，**1 个连续接触区**
（严格侧视下双手投影重叠，未检出两个分离区域，请总监目视确认）；
购物车 Back 先于人物入树、r03 近侧篮网 Front 常驻；朝左镜像身体中轴差 **0.00 px**；
视口 960×540、车长 96、间距 80、推 80 / 拉 40、碰撞 28×160、车锚点 (64,104) 全部未改。

---

## 5. 世界固定地面与滑步残差（本轮重点）

场景没有相机跟随，画面里每 32px 一道的世界刻度线固定不动；绑定后按真实输入 `80 px/s` 推行，
连续 **240 物理帧（4.0 s）**，每 6 物理帧（= 1 个 10 FPS 动画帧）采样一次，共 40 次。

```
[GROUND] 采样 40 次 / 240 物理帧，车位移 320.0 px，实测速度 80.00 px/s（期望 80）
[GROUND] 动画循环回绕 2 次（要求 ≥2 个完整 16 帧循环）
[GROUND] 脚掌世界 x 每动画帧位移：min -1.00 / max 20.00 / mean 8.00 px（车每帧约 8px）
[GROUND] 动画帧序前 20 = [2,3,4,5,6,7,8,9,10,11,12,13,14,15,0,1,2,3,4,5]
[GROUND] 承重段脚掌世界滑移残差均值 = 1.29 px/动画帧
```

- 每动画帧车推进 8 px，与 `80 px/s ÷ 10 FPS` 的合同一致；
- 40 次采样中 17 次落在承重段（|Δ脚掌世界 x| < 4 px），说明脚掌确实存在「踩住固定地面」的阶段；
- 摆动段最大 20 px/帧，是抬脚摆腿，不是缩放或跳帧；
- **残差 1.29 px/动画帧**来自逐帧贴图鞋底的固有微变化（美术报告已声明 1–3 px），
  未通过改 `side_offset`、物理或贴图缩放去掩盖。

产物：`art005e_ground_00..39.png`（40 张原生 960×540）、`art005e_ground_checkpoints.png`（8 格拼图）。

---

## 6. 实机 GIF 与 r04 对照

| 文件 | 内容 |
|---|---|
| `art005e_push_walk.gif` | 40 帧真实 Godot 渲染 + 真实输入，960×540，20ms/帧（≈实机 50FPS 速度） |
| `art005e_push_walk_slow.gif` | 同帧 100ms/帧，5× 慢放，便于检查 15→00 循环接缝 |
| `art005e_r04_vs_r09.png` | 同位置 / 同车 / 同装载，r09 第 00 帧（上）与 r04 第 00 帧（下）对照 |
| `art005e_f00..f03.png` / `art005e_moving.png` / `art005e_mirror.png` | 逐帧冻结、连续推行、朝左镜像检查点 |

对照结论：r09 双手前伸压住握把端帽，r04 双手仍悬在车把后方有可见空隙；两版人物与车比例、
上半身、头部位置一致，无穿插、无悬空、无裁切。

---

## 7. 全量回归

### 7.1 桌面（9 组，全绿）

| 组 | 结果 |
|---|---|
| 启动自检 smoke | 26/26，失败 0 |
| 场景巡检（菜单→超市→安全屋→菜单） | 4 次切换，失败 0 |
| CORE-001B | 28 项通过，失败 0 |
| ART-003 | 30 项通过，失败 0 |
| ART-004 | 35 项通过，失败 0 |
| ART-005 | **34 项通过，失败 0**（专项固定 r04 后） |
| ART-005E | **32 项通过，失败 0** |
| ART-004 门进出回归 | 全部通过，失败 0 |
| ART-005 门进出回归 | 全部通过，失败 0 |

**首次回归出现过 6 项失败，已定位并修复，测试项一条没删**：全局默认改成 r09 后，
`art005_verify.gd`（r04 专项）的帧序 / FPS / 手部基线断言量到了 r09 动画，报「手部间隙 +2.0 基线 -5.0」
与「6/7 FPS 单循环实测 4.00s」。修法是在该场景 `_ready()` 显式 `set_push_anim_variant(PUSH_ANIM_R04)`，
让 r04 用例继续量 r04，r09 由新的 `art005e` 场景独立覆盖。复跑 34/34 通过。

### 7.2 Web（Chrome 157 headless / CDP 9444 / 8060 静态服务）

| 脚本 | 结果 |
|---|---|
| `check_art005e_web.mjs`（本轮新增，真派发 E / D） | **10/10** |
| `check_art005_web.mjs` | 5/5 |
| `check_art004_web.mjs` | 15/15 |
| `check_art003_web.mjs` | **9/9**（扶车姿态断言改为兼容 `push_idle` / `r09_push_idle`） |
| `check_core001b_web.mjs` | 17/17 |
| `check_prep003_web.mjs` | 5/5 |
| `web_smoke_cdp.mjs` | READY=true，三视口截图，`ERROR_EVENTS 0` |
| `check_artlib_page.mjs`（file:// 素材页） | **28/28**（含本轮新增 3 条 r09 断言） |

`check_art003_web.mjs` 首次 8/9：断言写死 `[ANIM] push_idle`，而默认已改为 `r09_push_idle`。
改为正则 `/\[ANIM\] (r09_)?push_idle/`，语义（绑定后必须播扶车姿态）不变，测试项保留，复跑 9/9。

### 7.3 编号、素材页与 PCK

- `python tools/check_id_registry.py`：38 个号（已用 18 / 预留 19 / 空置 1），台账 39 行，警告 0；
- `python tools/build_artlib.py`：资产 39 条、缩略图 39 张；
- `python tools/check_art005e_pck.py`：**PASS**，`index.pck` 16,695,088 B = 15.92 MiB，
  r09 十七张 17/17 在包内，黑名单文件/路径 0 命中，`.gif` 字节串 0 次。

> PCK 体检口径说明：Godot 会把 `.gd` 源码文本（含注释）打进 PCK，因此用「任务编号字符串」当黑名单会
> 误报（首次检查命中 `ART-ANIM-005E` / `ART-INTEGRATE-005E`，上下文全是脚本注释）。
> 体检脚本改为按**具体文件名 / 路径片段**判定母图、GIF、报告、预览与隔离目录，结论 CLEAN。

---

## 8. 未完成 / 待裁定 / 剩余风险

1. **`ART_CHAR_001 r09` 仍是「待审核 / 引擎试用」**。全部用例通过也不自动升「运行时可用」，
   是否进白名单、是否作为正式对外演示默认，等用户 / 美术总监裁定。r04 也仍待审核。
2. **承重段滑移残差 1.29 px/动画帧**，不宣称 0px 无滑步；如需进一步消除，需美术出修正帧，
   不得通过改 `side_offset`、物理速度或缩放贴图来凑。
3. **手部只检出 1 个连续接触区**（世界 x=252..256，26 px 交叠）。任务书要求观察两个手部接触区域，
   严格侧视下双手投影重叠，工程侧无法凭像素分离，建议总监目视复核慢放 GIF。
4. **反向拉车仍播扶车静止帧**，人物位移时脚不迈步（沿用既有过渡限制）；车轮滚动、朝左独立绘制、
   搬运动画本轮未做。
5. **全局默认切换的连带影响**：CORE-001B / ART-003 / ART-004 等回归截图现在是 r09 画面；
   这些场景本身不断言扶车动画名，回归全绿。若以后需要还原 r04 画面，用 `set_push_anim_variant()` 即可。
6. **既有文档滞后仍有两处未改**（本轮不在任务范围）：根 `README.md` 仍写「PREP-002 工程准备完成」；
   `素材库/README.md` 写「白名单六条」（实际 14 条）。本轮已把 `docs/开发说明.md` 标题同步为
   ART-INTEGRATE-005E 版并新增 §7.4。

---

## 9. 文件清单

**新增**：17 张 `assets/characters/ART_CHAR_001_r09_*.png`（+17 `.import`）、17 张素材库副本、
`转存库/ART_ANIM_005E_留档/`（26 个文件）、`scenes/dev/art005e_verify.tscn`、
`scripts/dev/art005e_verify.gd`(+`.uid`)、
`tools/import_art005e_archive.py` / `tools/make_art005e_media.py` /
`tools/check_art005e_web.mjs` / `tools/check_art005e_pck.py`、
`docs/ART-INTEGRATE-005E_交付报告.md`、
`tests/screenshots/art005e_*.png`（88 张）、`art005e_push_walk*.gif`（2）、
`art005e_r04_vs_r09.png`、`art005e_ground_checkpoints.png`、`art005e_web.png`。

**修改**：`assets/characters/player_sprite_frames.tres`、`scripts/characters/player_controller.gd`、
`scripts/autoload/scene_router.gd`、`scripts/objects/pushable_cart.gd`（注释）、
`scripts/dev/art005_verify.gd`（固定 r04）、`tools/check_artlib_page.mjs`（+3 断言）、
`tools/check_art003_web.mjs`（版本兼容）、`素材库/素材台账.csv`、`素材库/ID登记表.csv`、
`素材库/ID登记表.md`、`素材库/美术总览.html`、`素材库/美术设定集/00-美术总览/美术资产台账_ARTLIB-001修订版.md`、
`docs/开发说明.md`、既有 Web 回归截图若干。

---

## 10. 复现命令

```bash
# 归档（可重复运行）与导入参数修正
python tools/import_art005e_archive.py
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --import
python tools/import_art005e_archive.py --fix-imports
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --import

# 实机用例 / 截图组
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- --dev-scene=art005e --art005e-test
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- --dev-scene=art005e --art005e-gif --quit
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- --dev-scene=art005e --art005e-compare --quit
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- --dev-scene=art005e --art005e-ground --quit

# 组装与第一方检查
python tools/make_art005e_media.py
python tools/build_artlib.py && python tools/check_id_registry.py
python tools/check_art005e_pck.py

# Web（先 serve_web.py + 9444 端口 Chrome）
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Web" builds/web/index.html
CDP_PORT=9444 node tools/check_art005e_web.mjs
```

---

## 11. 提交记录

| 提交 | 内容 |
|---|---|
| `010f2a4` | `feat: ART-INTEGRATE-005E 接入 r09 扶车返工十六帧并新增实机验证` |
| `ab9f874` | `docs: ART-INTEGRATE-005E 交付报告` |

工程与报告提交均推送 `origin/main`。

---

**停止声明**：本轮只做了 ART-INTEGRATE-005E 补丁。r09 全部用例通过后**仍保持「待审核」**，
未升运行时可用、未改白名单、未删除 r03/r04、未擅改任何冻结参数。未开始 CORE-002，
未做购物 / 库存 / 容量 / 结算 / 存档 / 剧情 / 建造，未制作新美术动作。报告提交后停止，
等待用户 / 美术总监对 §8 各项的裁定。
