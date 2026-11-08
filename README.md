# 寒潮清单 / Coldfront Checklist

2D 横版像素游戏：重生回到末日前七天，把外婆留下的旧两层小楼改造成安全屋，熬过寒潮。

> **当前状态：PREP-002 工程准备完成。** 字体、窗口适配、Web 导出、版本复现、v1.1 文档接收均已验证。剧情、道具数值、购物系统、建造系统仍全部暂停，等下一阶段任务批准。

## 环境

| 项目 | 要求 |
|---|---|
| 引擎 | Godot **4.7.2 stable**（`4.7.2.stable.official.ed1daf0bf`），GDScript，不用 C# |
| 渲染 | GL Compatibility；内部视口 960×540；整数倍缩放；全局 Nearest |
| 中文字体 | 随工程分发的 Noto Sans SC（SIL OFL 1.1），**不依赖系统字体** |
| Web | 默认单线程导出，已在 Chrome 157 本地 HTTP 服务实测 |

引擎二进制不入库，换电脑怎么装见 **[docs/工程复现说明.md](docs/工程复现说明.md)**。

## 快速开始

```bash
# 首次导入资源（会自动生成 .godot/ 缓存，不入库）
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --import

# 启动自检场景：24 项检查 + 截图，完成后退出
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- --shot=smoke.png --quit

# 窗口适配 / 模式切换
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- --profile=1366x768 --mode-cycle --shot=win.png --quit

# 编辑器
.tools/godot/Godot_v4.7.2-stable_win64.exe --editor --path .
```

自检场景里按 `A/D/E/Tab/B/Esc` 可在右侧看到输入回显，`F10` 切最大化、`F11` 切全屏。
Web 版不带 `--quit`，页面保持可交互。

## 目录

```text
├─ project.godot             工程配置（主场景 / 视口 / 渲染 / 输入 / 全局 Theme）
├─ export_presets.cfg        Web 导出预设（随仓库提交，保证可复现）
├─ icon.svg
├─ assets/
│  ├─ ui/fonts/              NotoSansSC-Variable.ttf + OFL.txt + 来源说明
│  ├─ ui/themes/             main_theme.tres（可复用 UI Theme）
│  ├─ reference/             v1.0 两张画风参考图（不是可用素材）
│  └─ characters|tiles|items|facilities|audio|portraits/   预留
├─ scenes/dev/test_scene.tscn   字体 / 窗口 / 输入 / 渲染自检场景（当前主场景）
├─ scripts/dev/
│  ├─ startup_smoke.gd      自检与截图
│  ├─ window_fit.gd         整数倍缩放与窗口自适应
│  └─ generate_ui_theme.gd  生成 UI Theme 的工程工具
├─ tools/                   复现与测试脚本（Web 模板分段下载、静态服务、浏览器冒烟）
├─ data/                    数据驱动文件预留，**仍为空**
├─ docs/
│  ├─ 开发说明.md            工程约定
│  ├─ 工程复现说明.md        版本、下载、校验、换电脑步骤
│  ├─ PREP-002_测试报告.md   本阶段全部实测结果
│  ├─ v1.1_冲突清单与建议.md 新旧交接包比对
│  ├─ handover_v1.0/        v1.0 策划交接包
│  └─ handover_v1.1/        v1.1 剧情美术补充包
├─ tests/screenshots/        启动 / 窗口 / 桌面 / 浏览器截图（含 .gdignore）
├─ 素材库/                   美术设定库（**仅人看**，根目录 .gdignore 隔离，不是运行时资源）
│  ├─ 美术总览.html          离线预览页，双击即可
│  ├─ 素材台账.csv           唯一权威台账
│  ├─ ID对照表.md            旧美术 ID → ART_* 新 ID
│  ├─ 美术设定集/            按角色 / 场景 / 物品 / UI / 特效 / 世界观分类
│  └─ 收集素材库/            候选 / 待筛选 / 已采用 / 弃用 流程
└─ builds/web/               Web 导出产物（不入库，含 .gdignore）
```

> 素材库与 `assets/`、`scenes/` 完全分离：禁止脚本使用 `res://素材库/`，概念图未经批准不得进入运行时资源。
> 新增素材后运行 `python tools/build_artlib.py` 重建缩略图与预览页。

## 文档索引

| 文档 | 内容 |
|---|---|
| `docs/开发说明.md` | 渲染与输入设置理由、字体规范、目录命名、Git 约定 |
| `docs/工程复现说明.md` | 引擎版本、官方下载源、SHA-256、模板安装、新电脑步骤 |
| `docs/PREP-002_测试报告.md` | 24 项自检、三种分辨率、Web 导出包体积与浏览器结果、已知问题 |
| `docs/ARTLIB-001_交付报告.md` | 素材库目录树、台账字段、隔离测试、PCK 体积变化 |
| `docs/v1.1_冲突清单与建议.md` | v1.1 与 v1.0 的 ID/数据结构冲突清单 |
| `docs/handover_v1.0/00_README_先读我.md` | 需求与范围边界 |
| `docs/handover_v1.1/00_升级说明与执行顺序.md` | v1.1 增量说明 |

## Web 导出与验证

```bash
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Web" builds/web/index.html
python tools/serve_web.py                 # http://127.0.0.1:8060
node tools/web_smoke_cdp.mjs              # 需先起 --remote-debugging-port=9333 的 Chrome
```

详见 `docs/工程复现说明.md` 第 5 节。

## 已暂停（等下一阶段任务批准）

D-7 至 D+7 主线事件、道具与设施数值、购物车与结账、物流入库、建造与摆放、日程结算、存档、结局判定。
v1.1 补充包已接收并归档，但**没有把任何新剧情、物品、设施写进代码或 `data/`**。
