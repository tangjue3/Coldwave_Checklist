# ART-APPROVE-005E 交付报告｜r09 美术正式验收与状态同步

- 日期：2026-11-09
- 任务来源：用户转达美术总监裁定 `ART-APPROVE-005E`（已审查实机 GIF、100ms 正常播放 GIF 与 r04/r09 对比图）
- 上一轮基线：工程 `010f2a4` / 报告 `ab9f874` / 哈希回填 `61b10bb`（ART-INTEGRATE-005E）
- 工程：Godot 4.7.2 stable / GDScript / gl_compatibility / 960×540 整数倍 + Nearest

---

## 0. 结论摘要

| 项 | 结果 |
|---|---|
| `ART_CHAR_001 r09` 审核状态 | **待审核 / 引擎试用 → 运行时可用 / 扶车十六帧可用** |
| 运行时白名单 | **14 条 → 15 条**（显式新增 r09 一行，未批量放行） |
| 素材页断言 | **28/28 → 30/30**（翻转 r09 断言 + 新增批准记录、r03/r04 回退两条） |
| 文档同步 | 根 README、素材库 README、开发说明 §7.4、ID 对照表修订记录、留档 README、代码注释全部同步 |
| GIF 描述修正 | 100ms/帧 = 正常 10FPS 播放；20ms/帧 = 50FPS 加速预览（已改报告、脚本文案与对照图标签） |
| 回归 | Windows 9 组、Web 8 组、素材页 30/30、ID 校验 0 警告、PCK PASS，全绿 |
| 范围 | 只做状态同步与文档修正；**未开始 CORE-002、未做新动画、未改任何物理参数** |

---

## 1. 六条裁定逐条执行

| # | 裁定 | 落地位置 | 结果 |
|---|---|---|---|
| 1 | r09 升「运行时可用」 | `素材库/素材台账.csv` r09 行：`审核状态=运行时可用`、`制作状态=扶车十六帧可用`，`制作与修改说明` 写入批准人 / 日期 / 任务编号；`tools/check_artlib_page.mjs` 白名单显式加第 15 条 | 完成 |
| 2 | r09 作为正式默认扶车动画，维持 16 帧 / 10 FPS | `PlayerController.push_anim_variant` 默认 `r09`（沿用接入轮，本轮未改）、`push_walk_r09_fps=10.0`、`r09_push_walk_right` 16 帧 | 完成 |
| 3 | 接受 1.29px/动画帧滑移残差，不重绘 | 未改任何贴图；`docs/开发说明.md` 与 `素材库/README.md` 记录为已接受的边界 | 完成 |
| 4 | 接受侧视双手合并为一个连续握把接触区 | 未改手部像素、未改 `side_offset`；文档记录为已接受 | 完成 |
| 5 | r03/r04 完整保留回退 | 动画、贴图、台账行、专项场景全部保留；新增素材页断言守护（见 §5） | 完成 |
| 6 | 不修改碰撞 / 速度 / 间距 / 锚点 / 图层 | `PushableCart` 逻辑一行未改；`art005e` 冻结参数 7 项用例全通过 | 完成 |

---

## 2. 状态差异（before → after）

| 位置 | 变更前 | 变更后 |
|---|---|---|
| `素材台账.csv` r09 审核状态 | 待审核 | **运行时可用** |
| `素材台账.csv` r09 制作状态 | 引擎试用 | **扶车十六帧可用** |
| `素材台账.csv` r09 说明 | 「全部实机用例通过也不升运行时可用，等裁定」 | 批准记录（美术总监 / ART-APPROVE-005E / 2026-11-09，含四项接受项） |
| `check_artlib_page.mjs` 白名单 | 14 条 | **15 条** |
| `check_artlib_page.mjs` r09 断言 | 必须待审核 + 不得进白名单 | **必须运行时可用 + 已进白名单 + 含批准记录** |
| `check_artlib_page.mjs` 回退断言 | 只检查状态未变 | 新增「r03/r04 台账行 + 运行时路径 + 原审核状态」完整保留 |
| `素材库/美术总览.html` | r09 显示待审核 | **显示运行时可用**（已重建，39 条资产 / 39 张缩略图） |
| `素材库/ID登记表.md` | 由脚本重生成 | 版本列表含 r09，全绿 0 警告 |

状态同步由 `python tools/approve_art005e.py` 幂等执行：重复运行不会覆盖已有批准状态，
也不会把 r09 退回待审核；白名单仍要求人工在脚本里显式加一行，保证「谁批准了什么」可逐行审查。

---

## 3. 文档同步清单

- **根 `README.md`**：状态由「PREP-002 工程准备完成」改为「ART-APPROVE-005E 已批准 r09 运行时可用」；
  目录树补齐 `characters/` `interaction/` `objects/` 与各 dev 场景、新增工具；文档索引补
  ART-INTEGRATE-005E / ART-APPROVE-005E 两份报告；Web 段补 `check_art005e_web.mjs` 与
  `check_art005e_pck.py`；「已暂停」段改为当前真实边界。
- **`素材库/README.md`**：白名单「六条」→ **15 条**，改为分组清单并列出每条来源；
  「仍然缺」删去已交付的扶车行走循环，改为反向拉车 / 车轮 / 左向独立帧 / 搬运动画 / TileSet；
  补记 r04 仍待审核但回退能力完整、两项已接受的边界。
- **`docs/开发说明.md`**：§7.4 状态行改为已批准；保留 §7.4 其余技术约定与 §8 命令。
- **`docs/ART-INTEGRATE-005E_交付报告.md`**：顶部加后续状态注记（不篡改历史记录），
  §6 修正 GIF 播放速度描述，§8 的目视复核措辞同步。
- **`素材库/ID对照表.md`** §5：追加 ART-APPROVE-005E 修订记录（含白名单 6 → 14 → 15 的演进说明）。
- **`转存库/ART_ANIM_005E_留档/README.md`**：状态改为运行时可用（由归档脚本模板刷新）。
- **代码注释**：`player_controller.gd`、`art005e_verify.gd`、`import_art005e_archive.py` 中
  过期的「待审核 / 引擎试用」描述同步为已批准。

### GIF 播放速度修正（裁定明确要求）

| 文件 | 修正前描述 | 修正后描述 |
|---|---|---|
| `art005e_push_walk.gif` | 20ms/帧「≈实机 50FPS 速度」 | **20ms/帧 = 50FPS，5× 加速预览** |
| `art005e_push_walk_slow.gif` | 100ms/帧「5× 慢放」 | **100ms/帧 = 10FPS，正常播放速度**（与 r09 动画 10 FPS 一致）；文件名沿用接入阶段命名，并非慢放 |

同步修正：`tools/make_art005e_media.py` 的 docstring 与两条输出文案、
`docs/ART-INTEGRATE-005E_交付报告.md` §6 表格与 §8 措辞、
`art005e_r04_vs_r09.png` 上的英文标签 `pending review` → `approved runtime`（已重新生成对照图）。
GIF 二进制帧内容与帧时长**未改**，只改描述与标签。

---

## 4. r04 专项测试与回退能力（未被削弱）

| 证据 | 内容 |
|---|---|
| `art005_verify.gd:88` | `set_push_anim_variant(PlayerController.PUSH_ANIM_R04)` 仍显式固定 r04 |
| `player_controller.gd` | `PUSH_ANIM_R04` 常量、`push_anim_variant` 导出项、`set_push_anim_variant()` 均在 |
| `player_sprite_frames.tres` | `push_idle`（r03 单帧）与 `push_walk_right`（r04 四帧）两条动画仍在 |
| `assets/characters/` | r03 静止帧 1 张 + r04 四帧共 **5 张**贴图仍在 |
| `art005e_verify.gd` | 仍含「切换 r04 回退版本 → 旧四帧动画仍可用」「切回 r09 → 恢复十六帧行走」两项用例 |
| 素材页新增断言 | 「r03 / r04 回退版本仍完整保留（台账行 + 运行时路径 + 原审核状态）」 |
| 回归结果 | ART-005 专项 34 项全通过；ART-005E 32 项全通过（含回退切换） |

---

## 5. 回归结果

### Windows（9 组，全绿，无失败项）

| 组 | 结果 |
|---|---|
| 启动自检 smoke | 26/26，失败 0 |
| 场景巡检 | 4 次切换，失败 0 |
| CORE-001B / ART-003 / ART-004 / ART-005 | 全部「汇总：全部符合预期」，失败 0 |
| ART-005E | 32 项，失败 0 |
| ART-004 / ART-005 门进出回归 | 全部通过，失败 0 |

### Web（Chrome 157 headless / CDP 9444 / 8060 静态服务，重新导出后跑）

| 脚本 | 结果 |
|---|---|
| `check_art005e_web.mjs`（真派发 E / D） | 10/10 |
| `check_art005_web.mjs` | 5/5 |
| `check_art004_web.mjs` | 15/15 |
| `check_art003_web.mjs` | 9/9 |
| `check_core001b_web.mjs` | 17/17 |
| `check_prep003_web.mjs` | 5/5 |
| `web_smoke_cdp.mjs` | READY=true，三视口截图，`ERROR_EVENTS 0` |
| `check_artlib_page.mjs`（file:// 素材页） | **30/30**（原 28 + 新增 2 条） |

### 编号 / 素材页 / PCK

- `python tools/check_id_registry.py`：38 个号（已用 18 / 预留 19 / 空置 1），台账 39 行，警告 0；
- `python tools/build_artlib.py`：资产 39 条、缩略图 39 张；
- `python tools/check_art005e_pck.py`：**PASS**，重新导出的 `index.pck` 16,695,152 B = 15.92 MiB，
  r09 十七张 17/17 在包内，黑名单 0 命中，`.gif` 字节串 0 次。

---

## 6. 范围边界与停止声明

本轮只做状态同步、文档修正与回归验证。**未**开始 CORE-002，**未**制作新动画，
**未**改碰撞 / 速度 / 间距 / 锚点 / 图层参数，**未**做购物 / 库存 / 结算 / 存档开发，
**未**改 `data/`（仍只有 README.md），**未**改 `GameState` / `SaveManager`。

`ART_CHAR_001 r04` 仍为「待审核」（回退版本，不影响其可用性）；r09 是正式默认。
仍未交付的美术：反向拉车动作、车轮滚动、朝左独立绘制、搬运动画、正式 TileSet。
报告提交后停止，等待下一批美术素材。

---

## 7. 提交记录

| 提交 | 内容 |
|---|---|
| `55c12ff` | `feat: ART-APPROVE-005E r09 升运行时可用并同步台账与文档` |
| `（报告提交，待回填）` | `docs: ART-APPROVE-005E 交付报告` |

工程与报告提交均推送 `origin/main`。
