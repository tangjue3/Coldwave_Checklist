# 寒潮清单 / Coldfront Checklist

2D 横版像素游戏：重生回到末日前七天，把外婆留下的旧两层小楼改造成安全屋，熬过寒潮。

> **当前状态：v0.1 工程底座。** 只有工程骨架、渲染与输入配置、启动自检场景。剧情、道具数值、购物系统、建造系统全部暂停，等 v1.1 交接包到位后再开工，避免返工。

## 环境

| 项目 | 要求 |
|---|---|
| 引擎 | Godot **4.7.2 stable**（本仓库实测 `4.7.2.stable.official.ed1daf0bf`） |
| 脚本 | GDScript（不使用 C#，原因见 `docs/开发说明.md`） |
| 渲染后端 | GL Compatibility（为 Web 导出保留可行性） |
| 内部视口 | 960×540，整倍数缩放，最近邻采样 |

## 运行

本机已把引擎放在 `.tools/godot/`（不入库，见 `.gitignore`）：

```bash
# 启动自检场景（会打印检查项、截图到 tests/screenshots/，然后自动退出）
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path .

# 用编辑器打开工程
.tools/godot/Godot_v4.7.2-stable_win64.exe --editor --path .
```

如果你自己装了 Godot 4.7.2，用编辑器「导入」本目录的 `project.godot` 即可。

## 目录

```text
├─ project.godot            工程配置（版本、主场景、视口、渲染、输入映射）
├─ icon.svg                 工程图标
├─ scenes/
│  ├─ dev/test_scene.tscn   启动自检场景（当前主场景）
│  ├─ menu/ world/ characters/ objects/ ui/   预留，随玩法阶段填充
├─ scripts/
│  ├─ dev/startup_smoke.gd  自检脚本
│  ├─ autoload/ systems/    预留（GameState / DayManager / Inventory 等）
├─ assets/
│  ├─ reference/            画风参考图（不是可用素材）
│  └─ characters/ tiles/ items/ facilities/ ui/ audio/ portraits/   预留
├─ data/                    数据驱动文件预留（items / facilities / shops / economy / story）
├─ docs/
│  ├─ 开发说明.md           工程约定、设置理由、协作规范
│  └─ handover_v1.0/        v1.0 策划交接包（GDD / 剧本 / 技术方案）
└─ tests/
   ├─ README.md             自检与测试约定
   └─ screenshots/          启动截图输出目录
```

## 文档

- `docs/handover_v1.0/00_README_先读我.md` — 需求与范围边界
- `docs/handover_v1.0/01_GDD_玩法美术与数值.md` — 玩法闭环、数值基线
- `docs/handover_v1.0/02_完整剧情剧本与分支.md` — 主线/支线/结局
- `docs/handover_v1.0/03_技术架构开发路线与验收.md` — 架构与 P0–P7 验收
- `docs/开发说明.md` — 本工程的落地约定（先读这一份再写代码）

## 已暂停（等 v1.1）

D-7 至 D+7 主线事件、道具与设施数值、购物车与结账、物流入库、建造与摆放、日程结算、存档、结局判定。
