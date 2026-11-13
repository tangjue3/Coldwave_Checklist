# LabelSettings 文字样式预设

一整套 HUD 文字效果。**用法：在 `Label` 的 `label_settings` 里挂对应 `.tres`，不写任何
`add_theme_font_override` / `add_theme_color_override`。**

样式本身由三样东西组成，改动时按这个顺序查：

1. **字形** —— `FontVariation`（`assets/ui/fonts/variations/`）
2. **字号 / 颜色 / 描边 / 阴影** —— 本目录的 `LabelSettings`
3. **控件级容器样式**（面板底、按钮四态、进度条） —— `assets/ui/themes/font_theme.tres`

## 最终方案（TASK-UI-006 采用，`final/`）

美术总监裁定用 A/B 混合：**标题、正文、状态文字、数值走 A（宋体），只有任务清单正文走 B（霞鹜文楷、无描边）**。

| 角色 | 预设 | 字体 | 字号 | 描边 | 用在哪 |
|---|---|---|---|---|---|
| 面板标题 | `f_title_serif_18` | 宋 600 | 18 | 2px @40% | 今日清单 / 生存状态 |
| 正文 | `f_body_serif_14` | 宋 400 | 14 | 1px @32% | 状态标签（体温 / 饥饿…） |
| 数值 | `f_value_serif_14` | 宋 400 | 14 | 1px @32% | 体温、百分比 |
| 长数值 | `f_value_serif_12` | 宋 400 | 12 | 1px @32% | 负重 `28.4 / 40.0 kg` |
| 任务行 | `f_task_wenkai_14` | 楷 400 | 14 | **0** | 清单未完成项 |
| 任务已完成 | `f_task_done_wenkai_14` | 楷 400 | 14 | **0** | 已完成项（配删除线） |
| 小字 | `f_small_serif_11` | 宋 400 | 11 | 1px @30% | 说明、页脚、对照标注 |

预览：`scenes/dev/font_final.tscn`，`--dev-scene=fontfinal`。

### 数值为什么靠「固定盒 + 右对齐」而不是等宽字形

先查过字体特性：Noto Serif SC 的 OpenType 特性表里**没有 `tnum`**（只有 `fwid` / `hwid`，
那会把数字变成全角或半角，14px 下"36.4°C"会宽到 84px，塞不进状态面板）。
霞鹜文楷同样没有 `tnum`。所以"数字等宽"这条路在本工程走不通。

改用布局手段兑现同一条要求：

- 状态行的数值盒固定 **80px**（面板内 x 134–214），`horizontal_alignment = 2`；
- 右对齐意味着**右缘恒为盒右缘**，数字位数变化只影响左缘，不会推动左侧的进度条或标签；
- 实测：`9.9°C` 文本宽 35px、`36.4°C` 43px、`-12.8°C` 47px —— 三者右缘都是 80，左缘分别是 45 / 37 / 33。
  这条结论由 `--font-check` 打印，不是估的。

### 面板（占位，等美术的冰霜 PNG）

当前 HUD 面板是 Theme 里的 StyleBox，不是美术图：

```
bg      #1F242B @ 88%
边线    #736756 @ 55%，1px
圆角    5px
```

冰霜面板 PNG 到位后**只换底图，文字样式一行不改**——文字都挂在 Label / LabelSettings 上，
与面板贴图完全解耦。

## 第二轮：A/B 两套方案（TASK-UI-005，对比过程留档）

第一版（下面「预设一览」那 13 个）在视觉验收里被判**过于厚重**——标题 21px 带 3px 描边、
正文 16px 带 2px 描边、数值用金色，整体发闷。第二轮整组重做，放在 `ab/` 子目录：

| 层级 | 方案 A · 精致宋体 | 方案 B · 宋体标题 + 霞鹜文楷正文 |
|---|---|---|
| 面板标题 | `x_title_serif_18` 宋 600 / 18px / 描边 2 @40% | `b_title_serif_18` 同 A |
| 正文 | `a_body_serif_14` 宋 400 / 14px / 描边 1 @32% | `b_body_wenkai_14` 楷 400 / 14px / **无描边** |
| 数值 | `a_value_serif_14` 宋 400 / 14px / 描边 1 @32% | `b_value_wenkai_14` 楷 400 / 14px / 无描边 |
| 长数值 | `a_value_serif_12` / `b_value_wenkai_12` 12px | 同左 |
| 已完成 | `a_done_serif_14` / `b_done_wenkai_14` 降亮度 | 同左 |
| 小字 | `a_small_serif_11` / `b_small_wenkai_11` 11px | 同左 |
| 说明标签 | `x_caption_13` 宋 600 + 字距，浅金 | 共用 |

**和第一版的差别**：标题 21→18px、描边 3→2px；正文 16/17→14px、描边 2→1px；数值从
「宋 600 金色」改回「宋 400 米白」；全部去掉 Black 字重；阴影从 blur2/3 降到 blur0/1、
透明度 35–45% → 18–22%。

**B 组为什么没有描边**：楷体笔画细，1px 深色描边会把笔画糊在一起，14px 下反而更脏。
实测对比后 B 组正文/数值改为 0 描边，只靠面板底色（`#1F242B` @88%）提供对比。
A 组是宋体，笔画有锐角，1px 描边反而让它更利落，保留。

预览场景：`scenes/dev/font_ab.tscn`

```bash
godot --path . -- --dev-scene=fontab --shot=ui005_ab.png --quit              # A/B 同框
godot --path . -- --dev-scene=fontab --font-scheme=a --shot=ui005_a.png --quit
godot --path . -- --dev-scene=fontab --font-scheme=b --shot=ui005_b.png --quit
godot --headless --path . -- --dev-scene=fontab --font-check --quit          # 只校验
```

## 预设一览（第一版，已被 `ab/` 取代，保留供回退）

| 文件 | 字号 | 字体 / 字重 | 颜色 | 描边 | 阴影 | 用在哪 |
|---|---|---|---|---|---|---|
| `ls_title_wenkai_28.tres` | 28 | 霞鹜文楷 加粗 | 米白 `#F2E8D6` | 4px @62% | 模糊3 / (0,2) / 45% | 画面标题（右上「寒潮清单」） |
| `ls_h2_serif_21.tres` | 21 | 宋 600 | 米白 | 2px @55% | 模糊2 / (0,1) / 35% | 面板标题（今日清单、生存状态） |
| `ls_section_serif_13.tres` | 13 | 宋 600 + 字距1 | 浅金 `#D9A96E` | 1px @45% | 模糊1 / (0,1) / 30% | 栏目小标签、对照页小标题 |
| `ls_label_serif_16.tres` | 16 | 宋 400 | 米白 | 2px @45% | 模糊1 / (0,1) / 30% | 正文、状态标签（体温 / 饥饿…） |
| `ls_value_serif_17.tres` | 17 | 宋 600 | 暖白 `#F6EEDA` | 2px @50% | 模糊2 / (0,1) / 38% | 大号数值 |
| `ls_value_serif_15.tres` | 15 | 宋 600 | 暖白 | 2px @50% | 模糊1 / (0,1) / 35% | 中号数值 |
| `ls_value_serif_14.tres` | 14 | 宋 600 | 暖白 | 1px @50% | 模糊1 / (0,1) / 30% | 状态面板行内数值 |
| `ls_value_serif_12.tres` | 12 | 宋 600 | 暖白 | 1px @50% | 模糊1 / (0,1) / 30% | 长数值（28.4 / 40.0 kg） |
| `ls_task_wenkai_17.tres` | 17 | 霞鹜文楷 | 米白 | 2px @42% | 模糊1 / (0,1) / 30% | 任务清单未完成行 |
| `ls_task_done_wenkai_17.tres` | 17 | 霞鹜文楷 | 次要 `#C9BCA4` | 2px @40% | 模糊1 / (0,1) / 25% | 任务清单已完成行（删除线另画） |
| `ls_small_wenkai_12.tres` | 12 | 霞鹜文楷 | 次要 `#C9BCA4` | 1px @40% | 无 | 提示小字、说明、页脚 |
| `ls_button_serif_15.tres` | 15 | 宋 400 | 米白 | 2px @50% | 模糊1 / (0,1) / 30% | 按钮文字、快捷键提示 |
| `ls_number_serif_11.tres` | 11 | 宋 600 | 次要 | 1px @45% | 无 | 格位序号、物品数量 |

描边色统一 `#12100C`，阴影色统一纯黑（透明度见上表）。

## 字号档

**最终方案只用三档：`11 / 12 / 14 / 18`**（小字 / 长数值 / 正文与常规数值 / 面板标题）。

历史档位 `13 / 15 / 16 / 17 / 21 / 28` 来自第一、二轮，仍留在库里供回退，但新做界面不要再用——
15/16/17 三个相邻字号并存，本质是"每处单独调"留下的债。新增样式前先问：能不能用现有三档？

## 颜色

| 名称 | 值 | 说明 |
|---|---|---|
| 米白 ink | `#E6DDCB` | 主文字（最终方案，比第一版的 `#F2E8D6` 收了一档亮度） |
| 次要 dim | `#C9BCA4` | 已完成、说明、页脚 |
| 禁用 mute | `#8E8271` | 不可用条目 |
| 浅金 gold | `#D9A96E` | 栏目标签、进度条填充、选中框 |
| 高光金 hi | `#F0CB92` | 强调数值（当前未用于正文数值） |
| 暖白 value | `#F4EBD8` | 面板里的数值（不是金色，是偏亮米白） |
| 已完成 done | `#A89B85` | 任务已完成行，能读但明显次要 |
| 描边 outline | `#12100C` | 所有文字的描边 |
| 面板底 panel | `#1F242B` @88% | 半透明面板 |
| 面板边 border | `#736756` @55% | 面板 1px 边 |

## 与 `main_theme.tres` 的关系

- `assets/ui/themes/main_theme.tres` 是**现役全局主题**（`UiTheme` autoload 运行时挂载），
  字体是思源黑体、控件样式是深灰蓝。**本轮没有改它**，所以主菜单与现有开发界面不受影响。
- `assets/ui/themes/font_theme.tres` 是**本轮新增的字体主题**：默认字体思源宋体 400、
  Button 四态、Panel、ProgressBar、以及 `HotbarSlot` / `HotbarSlotActive` 两个面板类型变体。
  目前只被 `scenes/dev/font_preview.tscn` 使用。
  现在被 `font_preview.tscn`（TASK-UI-004）、`font_ab.tscn`（005）、`font_final.tscn`（006）三个预览场景共用。
- 将来接入正式 HUD 时有两条路：① 把 `font_theme.tres` 的内容并进 `main_theme.tres`；
  ② 保留两份、按场景挂。**TASK-UI-006 明确要求本轮不合并，两条路都还没选。**

## 验证

```bash
# 最终方案：校验 7 个角色 + 数值列宽 + 面板占位色
godot --headless --path . -- --dev-scene=fontfinal --font-check --quit
godot --path . -- --dev-scene=fontfinal --shot=ui006_final.png --quit

# 历史两轮（对照用）
godot --headless --path . -- --dev-scene=fontprev --font-check --quit
godot --headless --path . -- --dev-scene=fontab --font-check --quit
```

`--font-check` 里有 `get_string_size("寒潮清单")` 的宽度断言：宽度接近 0 就说明字体没导入
或回退失败，会打 FAIL 并以非 0 退出。
