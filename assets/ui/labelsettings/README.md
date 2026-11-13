# LabelSettings 文字样式预设

一整套 HUD 文字效果。**用法：在 `Label` 的 `label_settings` 里挂对应 `.tres`，不写任何
`add_theme_font_override` / `add_theme_color_override`。**

样式本身由三样东西组成，改动时按这个顺序查：

1. **字形** —— `FontVariation`（`assets/ui/fonts/variations/`）
2. **字号 / 颜色 / 描边 / 阴影** —— 本目录的 `LabelSettings`
3. **控件级容器样式**（面板底、按钮四态、进度条） —— `assets/ui/themes/font_theme.tres`

## 第二轮：A/B 两套方案（TASK-UI-005，当前推荐）

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

`11 / 12 / 13 / 14 / 15 / 16 / 17 / 21 / 28`

档位是按实际用途定的，没有连续排。新增样式前先问：能不能用现有档？能复用就别加档——
HUD 上一堆相邻字号（15/16/17 三个并存）本来就是"每处单独调"留下的债。

## 颜色

| 名称 | 值 | 说明 |
|---|---|---|
| 米白 ink | `#F2E8D6` | 主文字 |
| 次要 dim | `#C9BCA4` | 已完成、说明、页脚 |
| 禁用 mute | `#8E8271` | 不可用条目 |
| 浅金 gold | `#D9A96E` | 栏目标签、进度条填充、选中框 |
| 高光金 hi | `#F0CB92` | 强调数值（当前未用于正文数值） |
| 暖白 value | `#F6EEDA` | 面板里的数值（概念图里数值不是金色，是偏亮米白） |
| 描边 outline | `#12100C` | 所有文字的描边 |
| 面板底 panel | `#1F242B` @88% | 半透明面板 |
| 面板边 border | `#736756` @55% | 面板 1px 边 |

## 与 `main_theme.tres` 的关系

- `assets/ui/themes/main_theme.tres` 是**现役全局主题**（`UiTheme` autoload 运行时挂载），
  字体是思源黑体、控件样式是深灰蓝。**本轮没有改它**，所以主菜单与现有开发界面不受影响。
- `assets/ui/themes/font_theme.tres` 是**本轮新增的字体主题**：默认字体思源宋体 400、
  Button 四态、Panel、ProgressBar、以及 `HotbarSlot` / `HotbarSlotActive` 两个面板类型变体。
  目前只被 `scenes/dev/font_preview.tscn` 使用。
- 将来接入正式 HUD 时有两条路：① 把 `font_theme.tres` 的内容并进 `main_theme.tres`；
  ② 保留两份、按场景挂。**这是待裁定的设计决策，不要自己拍。**

## 验证

```bash
# 资源是否都真的加载到了字形（每个预设打印字体名 / 字号 / 描边 / 字宽）
godot --headless --path . -- --dev-scene=fontprev --font-check --quit

# 视觉预览（HUD 页 / 参数对照页）
godot --path . -- --dev-scene=fontprev --shot=ui004_hud.png --quit
godot --path . -- --dev-scene=fontprev --font-page=spec --shot=ui004_spec.png --quit
```

`--font-check` 里有 `get_string_size("寒潮清单")` 的宽度断言：宽度接近 0 就说明字体没导入
或回退失败，会打 FAIL 并以非 0 退出。
