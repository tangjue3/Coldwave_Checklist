# 寒潮清单 / Coldfront Checklist

2D 横版像素游戏：重生回到末日前七天，把外婆留下的旧两层小楼改造成安全屋，熬过寒潮。

> **当前状态：角色美术已整体重置（ART-RESET-001，2026-11-10）。**
> 许知夏旧运行时动画 r01 / r02 / r03 / r04 / r09 及 RIG 骨骼原型已**全部删除**，
> 唯一外观基准是 `ART_CHAR_001_v02` 五视图，另有 5 张从它无损裁取的视频参考图。
> **游戏里角色暂时不可见**，但移动（100 px/s）、碰撞、摄像机、场景切换、门 / 货架交互、
> 购物车绑定与推 80 / 拉 40 全部正常。新角色动画走
> **[docs/AI视频转Godot动画接入规范.md](docs/AI视频转Godot动画接入规范.md)**：用户生成视频，
> 开发侧拆帧抠像对齐后接入。
> 剧情、道具数值、购物系统、建造系统、日程结算、存档仍全部暂停，等下一阶段任务批准。

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

# 默认启动：主菜单（标题 / 新游戏 / 继续[禁用] / 设置 / 开发测试入口 / 退出）
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- --shot=menu.png --quit

# 启动自检（26 项，独立运行，不经过主菜单跳转）
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- --dev-scene=smoke --shot=smoke.png --quit

# 场景切换巡检：菜单 → 超市 → 安全屋 → 菜单
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- --scene-tour --quit

# 素材库完整性审计 + 预览页重建（改素材后必跑）
python tools/audit_artlib.py
python tools/build_artlib.py

# 编辑器
.tools/godot/Godot_v4.7.2-stable_win64.exe --editor --path .
```

主菜单的「开发测试入口」可切换超市 / 安全屋空场景，Esc 或按钮返回主菜单。
自检场景里按 `A/D/E/Tab/B/Esc` 可看输入回显，`F10` 切最大化、`F11` 切全屏。
其余 dev 场景（`scale` / `core001a` / `core001b` / `art003` / `art004` / `video`）
**只走命令行或 Web URL 参数**，不挂主菜单。Web 版不带 `--quit`，页面保持可交互。

## 目录

```text
├─ project.godot             工程配置（主场景=主菜单 / 视口 / 渲染 / 输入 / 4 个 autoload）
├─ export_presets.cfg        Web 导出预设（随仓库提交，保证可复现）
├─ icon.svg
├─ assets/
│  ├─ ui/fonts/              NotoSansSC-Variable.ttf + OFL.txt + 来源说明
│  ├─ ui/themes/             main_theme.tres
│  ├─ characters/            已清空（ART-RESET-001 删除了全部角色帧与 SpriteFrames）
│  ├─ facilities/            ART_FURN_103 r01/r02/r03 分件、ART_FURN_101 r01 货架
│  ├─ items/                 ART_ITEM_101/102 落地版与 -shelf 版
│  ├─ reference/             v1.0 两张画风参考图（不是可用素材）
│  └─ tiles|audio|portraits/ 预留
├─ scenes/
│  ├─ menu/main_menu.tscn    **正式启动入口**
│  ├─ world/                 supermarket.tscn / shelter.tscn（占位空场景）
│  ├─ characters/player.tscn 可复用横向移动组件
│  ├─ dev/                   test_scene / scale_test / core_001a / core_001b /
│  │                        art003_verify / art004_verify / video_preview（视频候选体检）
│  └─ objects|ui/            预留
├─ scripts/
│  ├─ autoload/              UiTheme · GameState · SaveManager · SceneRouter
│  ├─ ui|world/              主菜单与占位场景控制器
│  ├─ characters/            player_controller.gd · follow_camera.gd
│  ├─ interaction/           Interactable / Door / Shelf / InteractionSensor
│  ├─ objects/               pushable_cart.gd（PARKED / PUSHING）
│  └─ dev/                   各轮验证场景与自检、主题生成脚本
├─ tools/                    复现 / 素材库索引 / Web 验收 / PCK 体检脚本（py + mjs）
├─ data/                     数据驱动文件预留，**仍为空**（只有 README.md）
├─ docs/
│  ├─ 开发说明.md            工程与像素约定（§7.4 记录角色动画移除后的状态）
│  ├─ 工程复现说明.md        版本、下载、校验、换电脑步骤
│  ├─ *_交付报告.md          PREP / SCALE / CORE / ART / ART-APPROVE 各轮实测
│  ├─ v1.1_冲突清单与建议.md 新旧交接包比对
│  └─ handover_v1.0|v1.1/   策划交接包
├─ tests/screenshots/        启动 / 窗口 / 桌面 / 浏览器 / 动画连拍截图与 GIF（含 .gdignore）
├─ 素材库/                   美术设定库（**仅人看**，根目录 .gdignore 隔离，不是运行时资源）
│  ├─ 美术总览.html          离线预览页，双击即可
│  ├─ 素材台账.csv           唯一权威台账
│  ├─ ID登记表.csv           编号唯一来源；ID对照表.md 为旧 ID 映射
│  └─ 美术设定集|收集素材库/ 按角色 / 场景 / 物品 / UI / 特效 / 世界观分类
├─ 转存库/                   新素材投递入口（含 .gdignore，不参与 Godot 导入）
└─ builds/web/               Web 导出产物（不入库，含 .gdignore）
```

> 素材库与 `assets/`、`scenes/` 完全分离：禁止脚本使用 `res://素材库/`，概念图未经批准不得进入运行时资源。
> 新增素材后运行 `python tools/build_artlib.py` 重建缩略图与预览页。
> 只有台账 `审核状态 = 运行时可用` 且进了 `tools/check_artlib_page.mjs` 白名单的条目才能被游戏引用。

## 文档索引

| 文档 | 内容 |
|---|---|
| `docs/开发说明.md` | 渲染与输入设置、字体规范、尺寸与动画约定、目录命名、Git 约定 |
| `docs/工程复现说明.md` | 引擎版本、官方下载源、SHA-256、模板安装、新电脑步骤 |
| `docs/PREP-002_测试报告.md` | 24 项自检、三种分辨率、Web 导出包体积与浏览器结果 |
| `docs/PREP-003_交付报告.md` | 首次导入修复、主菜单与空场景、Windows/Web 验收 |
| `docs/SCALE-001_尺寸验证报告.md` | 第一季生产尺度定稿（160px 人物 / 32px tile / 96px 车长） |
| `docs/CORE-001A_交付报告.md` / `CORE-001B_交付报告.md` | 移动底座 / 交互与购物车状态机 |
| `docs/ART-INTEGRATE-003_交付报告.md` ~ `005_交付报告.md` | 行走四帧、货架商品、分层购物车、r04 推车四帧 |
| `docs/ART-INTEGRATE-005E_交付报告.md` | r09 十六帧接入、世界固定地面步态量测与全量回归 |
| `docs/ART-APPROVE-005E_交付报告.md` | r09 正式验收裁定、状态同步与回归结果 |
| `docs/ART-RIG-001_角色分层与骨骼制作规范.md` | 16 部件分层表、18 骨关节坐标、需补画区域、正式素材替换方法 |
| `docs/ART-RIG-001_交付报告.md` | 骨骼技术验证结论、33 项用例、素材需求与停止声明 |
| `docs/v1.1_冲突清单与建议.md` | v1.1 与 v1.0 的 ID/数据结构冲突清单 |
| `docs/handover_v1.0/00_README_先读我.md` | 需求与范围边界 |
| `docs/handover_v1.1/00_升级说明与执行顺序.md` | v1.1 增量说明 |

## Web 导出与验证

```bash
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Web" builds/web/index.html
python tools/serve_web.py                 # http://127.0.0.1:8060
node tools/web_smoke_cdp.mjs              # 三视口冒烟（需调试端口）
node tools/check_prep003_web.mjs          # 主菜单 + 场景切换验收
node tools/check_art003_web.mjs           # 购物车 / 交互 Web 验收（角色动画断言已退役）
node tools/check_core001b_web.mjs         # 门 / 货架 / 推车 Web 验收
node tools/check_artlib_page.mjs          # 素材库离线页断言（file:// + 9444）
python tools/build_artlib.py && python tools/check_id_registry.py && python tools/audit_artlib.py
```

详见 `docs/工程复现说明.md` 第 5 节与 `docs/开发说明.md` §8。

## 已暂停（等下一阶段任务批准）

D-7 至 D+7 主线事件、道具与设施数值、购物车与结账、物流入库、建造与摆放、日程结算、存档、结局判定。
v1.1 补充包已接收并归档，但**没有把任何新剧情、物品、设施写进代码或 `data/`**。

`ART_CHAR_001 r09` 已由 ART-APPROVE-005E 批准为「运行时可用」与正式默认扶车动画，r03 / r04 完整保留回退。
尚未交付的美术：反向拉车动作、车轮滚动、朝左独立绘制、搬运动画、正式 TileSet。
