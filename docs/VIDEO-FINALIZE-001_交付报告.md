# VIDEO-FINALIZE-001 交付报告 · 普通行走动画正式收尾

> 分支 `角色制作`　日期 2026-11-10　前置 `VIDEO-QUALITY-002`（用户已确认高清效果满意）
> 本轮**只做正式登记**：未重新生成视频、未加工素材、未改 Godot 动画与渲染配置、未做画质实验。

## 1. 正式登记内容

沿用 `ART_CHAR_001` 号，从 **r10** 起编号（r01–r09 已在 ART-RESET-001 全部删除，跳过废弃号避免混淆）。
台账由 29 行 / 27 列 → **32 行 / 28 列**，运行时白名单 **11 → 14 条**。

| 版本 | 动画 | 帧数 / FPS | 三轴状态 |
|---|---|---|---|
| `r10` | `walk_right` 右向普通行走 | 36 / 24 | 运行时可用 · 认可 · 正式使用 |
| `r11` | `walk_to_idle` 停止过渡 | 21 / 24 | 运行时可用 · 认可 · 正式使用 |
| `r12` | `idle_right` 站立待机 | 1 / 8 | 运行时可用 · 认可 · 正式使用 |

- **素材库**：58 张 512×704 帧副本落在 `素材库/美术设定集/01-角色/动画帧/{r10,r11,r12}/`。
  由 `tools/artlib_finalize_001.py` 从 `assets/characters/` **原样复制**并逐文件校验 SHA-256，
  没有缩放、调色或重新生成任何素材。
- **台账**：新增 `已知限制` 列（第 28 列）；三行的库内代表图、运行时路径、动画帧数/帧率、
  序列 glob、相关文件均已填实。ID 登记表备注同步。
- **白名单**：`tools/check_artlib_page.mjs` 的 `APPROVED_RUNTIME` 显式加三行。
- **总览页**：`tools/build_artlib.py` 重建 `素材库/美术总览.html`，
  32 张缩略图、58 张序列帧、2 个预览 GIF（r10 / r11）；角色卡片可播放序列帧与版本对照。

登记脚本幂等：`tools/artlib_finalize_001.py --check` 与 `tools/artlib_curate.py --check` 均通过；
两工具的「已知限制」正文共用 `LIMITS` 单一数据源，不会各写一份简写而漂移。

## 2. 未解决问题如实保留（没有标成已修复）

**「认可」只代表 512×704 高清画质获用户确认，不代表动作缺陷解决。**

| 问题 | 记录位置 |
|---|---|
| 脚底滑动约 **1.89 px/帧**：源视频原地跟拍，接入 100 px/s 后支撑脚无法锁地 | 台账 r10 `已知限制` 列、页面「角色动作状态」页已知限制列与汇总框、本报告 |
| 停止过渡仅 **7/36 相位（约 19%）** 能自然衔接，其余相位直接站稳、未强行拼接 | 台账 r11、页面、本报告 |
| 单帧待机无呼吸循环；朝左仅 flip_h 镜像；推车动画未制作 | 台账 r12、页面动作清单（推购物车仍标「待重新制作」） |

页面新增橙色「已知限制（未修复）」汇总区块与每行详情的高亮块；
`check_artlib_page.mjs` 有专门断言检查 `1.89`、`19%`、`未修复` 三个关键字确实出现，
防止以后被「认可 / 正式使用」标签悄悄盖掉。

## 3. 回归测试

| 项 | 结果 |
|---|---|
| `check_artlib_page.mjs`（页面 + 数据层 + 灯箱 + 筛选） | **59/59**（原 52 条中过时的「角色 0 条」等断言已改写为正式状态断言，另加 7 条限制与转正校验） |
| `audit_artlib.py` | 失败 0 / 警告 0；运行时可用 14 条；帧数闭环 assets 58 = 台账 58 = 素材库副本 58 |
| `check_id_registry.py` / `artlib_curate.py --check` / `artlib_finalize_001.py --check` | 全部通过 |
| Godot `smoke` | 26/26 |
| Godot `--dev-scene=vid001 --vid001-test` | 29/29 |
| art003 / art004 / core001a / core001b | 全部符合预期，0 脚本错误 |
| Web `check_art003_web` / `check_core001b_web` | 10/10、18/18 |

Godot 动画、SpriteFrames、贴图、`player.tscn`、`project.godot` 本轮**一个字节都没改**，
上述引擎回归只是确认登记动作没有副作用。

## 4. 文档同步

`README.md`、四份素材库 README / 规范、`docs/开发说明.md` §7.0/§7.4、
`docs/AI视频转Godot动画接入规范.md`、`docs/素材库目录树.md`、
`素材库/ID登记表.md`、`美术资产台账_ARTLIB-001修订版.md` 均已同步为正式状态；
两处历史候选 `meta.json` 标注「已于 VIDEO-FINALIZE-001 正式转正」，
避免把 128×176 候选帧误认成当前正式资源。

## 5. 交付物

- `素材库/素材台账.csv`（32 行 / 28 列）、`素材库/美术总览.html`
- `素材库/美术设定集/01-角色/动画帧/`（58 张 512×704）、`.thumbs/anim/`（2 个 GIF）
- `tools/artlib_finalize_001.py`（幂等登记）、`tools/artlib_curate.py` / `build_artlib.py` /
  `check_artlib_page.mjs` / `audit_artlib.py` 的相应更新
- 页面截图：`tests/screenshots/artlib_final_characters.png`、`artlib_final_actions.png`

本轮完成即停止；推购物车、反向拉车、搬运、转身、朝左独立绘制及上述两项遗留限制
留待后续编号任务处理。
