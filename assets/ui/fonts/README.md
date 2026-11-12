# 字体与授权

本工程所有 UI 文字使用**随工程分发**的字体，不依赖系统安装的微软雅黑等字体。

| 文件 | 字号 / 字重 | 大小 | 用途 |
|---|---|---|---|
| `NotoSerifSC-Regular.ttf` | 思源宋体 400 | 14.8 MB | 正文、状态标签、按钮、说明文字 |
| `NotoSerifSC-SemiBold.ttf` | 思源宋体 600 | 14.8 MB | 面板标题、数值、栏目小标签 |
| `NotoSerifSC-Black.ttf` | 思源宋体 900 | 14.8 MB | 极重衬线标题（当前预设未用到，留作扩展） |
| `LXGWWenKaiScreen.ttf` | 霞鹜文楷 Screen 400 | 26.1 MB | 任务清单、剧情对白、手写感标题 |
| `NotoSansSC-Variable.ttf` | 思源黑体可变 | 17.8 MB | 工程旧默认字体，仍被 `main_theme.tres` 引用，勿删 |
| `OFL.txt` | — | 4.4 KB | Noto Sans SC 的 OFL 1.1 许可证 |
| `OFL-NotoSerifSC.txt` | — | 4.4 KB | Noto Serif SC 的 OFL 1.1 许可证 |
| `OFL-LXGWWenKaiScreen.txt` | — | 6.0 KB | 霞鹜文楷的 OFL 1.1 许可证（含作者附加许可说明） |

`variations/` 下是 `FontVariation` 字重实例，见下文。

## 来源（全部取自官方发布，未做任何修改）

| 字体 | 官方仓库 | 取用的文件 |
|---|---|---|
| 思源宋体 / Noto Serif SC | https://github.com/google/fonts/tree/main/ofl/notoserifsc | `NotoSerifSC[wght].ttf` 的静态实例 400 / 600 / 900，经 npm 镜像 `@expo-google-fonts/noto-serif-sc@0.4.4` 取得（包内即 Google Fonts 官方二进制） |
| 霞鹜文楷 Screen | https://github.com/lxgw/LxgwWenKai-Screen/releases/tag/v1.530 | `LXGWWenKaiScreen.ttf` |
| 思源黑体（旧） | https://github.com/google/fonts/tree/main/ofl/notosanssc | `NotoSansSC[wght].ttf` |

下载日期：2026-11-12。

## 校验和

```
SHA256(NotoSerifSC-Regular.ttf)    = c358a69de3df5f423a8946a7b03e3126fb6ba116f1130a463455b4e39e1f0742
SHA256(NotoSerifSC-SemiBold.ttf)   = 5d19e0f438d4a30371f584d34a87c9232dba0a85237db63fe5337fe743487def
SHA256(NotoSerifSC-Black.ttf)      = 092e71a70c744be3cc33999eb4edcb10fbe95c1b4cff6c2d7f04d6ff15d031e2
SHA256(LXGWWenKaiScreen.ttf)       = abd13364163e3cd84372b333f2fdcee9efb848634668f1c0ce5788dcd059ee61
SHA256(NotoSansSC-Variable.ttf)    = a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da
SHA256(OFL-NotoSerifSC.txt)        = 5e0da210fb04058a8c0087985d2d456b931c2579811a49655721d3cf0c36b6d6
SHA256(OFL-LXGWWenKaiScreen.txt)   = ba38832f9d7e0ad601a1ab90d58f251ba957532885ef80dca050a611962fd8b6
```

## 为什么思源宋体是三个静态文件，而不是一个可变字体

先试的是可变字体 `NotoSerifSC[wght].ttf`（25 MB 单文件，`wght` 轴 200–900）。
**实测在 Godot 4.7.2 上 `FontVariation.variation_opentype` 对这个文件不生效**：用 `wght`
200 / 400 / 600 / 900 渲染同一串字，墨迹像素数完全相同、字形没有任何变化。用隔离渲染
场景复现过，也排除了 `.tres` 写法问题（用 `ResourceSaver` 让引擎自己写出的变体资源同样无效）。
TextServer 报 `FEATURE_FONT_VARIABLE = true`，字体也正确报告 `wght: (200, 900, 200)`，
所以问题在变体应用层，不在字体本身。

因此改用三个官方静态实例（400 / 600 / 900）。代价是 14.8 MB × 3，比可变字体多约 19 MB；
好处是**渲染结果确定**：`get_font_style_name()` 直接返回 `Regular` / `SemiBold` / `Black`，
不依赖任何运行时轴解析。

> 如果以后 Godot 修好这个问题，可以换回可变字体省下约 19 MB：把 `variations/*.tres` 的
> `base_font` 指回可变字体、把固定字重换成 `wght` 轴即可，预设与场景不用动。

## variations/ 字重实例

`FontVariation` 让"同款字体不同字重 / 字距"成为可独立引用的资源，场景里不必重复配参数。

| 文件 | 基字体 | 设置 |
|---|---|---|
| `serif_w400.tres` | NotoSerifSC-Regular | — |
| `serif_w600.tres` | NotoSerifSC-SemiBold | — |
| `serif_w900.tres` | NotoSerifSC-Black | — |
| `serif_w600_wide.tres` | NotoSerifSC-SemiBold | `spacing_glyph = 1`（栏目小标签加字距） |
| `serif_w900_wide.tres` | NotoSerifSC-Black | `spacing_glyph = 2` |
| `wenkai_w400.tres` | LXGWWenKaiScreen | — |
| `wenkai_w600.tres` | LXGWWenKaiScreen | `variation_embolden = 0.45`（合成加粗，楷体只有常规字重） |

## 导入设置

`*.ttf.import` 统一：

```
antialiasing=1                # 灰度抗锯齿
allow_system_fallback=false   # 缺字直接露出来，不被系统字体悄悄兜底
hinting=3
subpixel_positioning=4
compress=true
```

**`allow_system_fallback=false` 是刻意的**：Web 端没有系统字体，桌面端却有。如果开着兜底，
"某字符在本字体里缺失"这个问题在桌面端永远发现不了，上线到浏览器才炸。关掉以后缺字显示为
方框，验收时一眼能看见。

## 授权要点

三款字体均为 SIL OFL 1.1：

- 允许使用、研究、修改、再分发（含随游戏打包与商业发行），需随字体附带许可证与版权声明。
- 不得单独售卖字体本身。
- 衍生字体不得使用保留字体名。霞鹜文楷的保留名为 `霞鹜` / `霞鶩` / `落霞孤鹜` / `落霞孤鶩` / `LXGW`；
  Noto 系列无保留名。
- 本工程**未修改**字体文件、按原名分发，因此只需保留各自的 `OFL*.txt`。

> ⚠️ 若将来为了压 Web 包体积做子集化，那属于"修改字体"：霞鹜文楷必须在文件名与字体名里
> 去掉保留字。当前为保证任意中文都能显示，用的是未裁剪的完整字库——这也是本目录体积偏大的原因。
