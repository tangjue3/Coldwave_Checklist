# VIDEO-INTEGRATE-001 交付报告

> 项目：寒潮清单 / Coldfront_Checklist　　分支：`角色制作`　　日期：2026-11-10
> 前置：`ART-RESET-001`（角色素材彻底重置）　　后续：`VIDEO-INTEGRATE-002` 或用户指定的下一编号任务
>
> **状态：候选 / 待用户与美术审核。**
> 本轮已**实际完成**视频拆帧、绿幕抠像、动画切分、SpriteFrames 生成与 Godot 正式接入，
> 但**未**把资源标为最终美术成品：`素材台账.csv`、运行时白名单、`美术总览.html` 的正式状态
> 一律未改，等用户确认视觉质量后再更新。

---

## 一、一句话结论

用户提供的一条 8.04 秒绿幕视频，被做成了 **walk_right（36 帧 / 24 FPS）、
walk_to_idle（21 帧 / 24 FPS）、idle_right（1 帧）** 三段透明 PNG 序列，
生成 SpriteFrames 并接入真实 `PlayerController`；游戏里角色重新可见，
走 / 停 / 再走 / 左右镜像全部实测通过。

**已具备正式美术审核条件**，但存在三项无法靠后期修复的固有问题（见 §6），
审核时请重点看这几项。

---

## 二、源视频与逐帧判断（不照抄任务书假设）

| 项 | 实测值 |
|---|---|
| 文件 | `转存库/Generating_pixel_art_walking_ani…_0afbba1d.mp4` |
| SHA-256 | `664a863c565dba9a468c88af9716cfd4cbd919372ecd8fa0c1ef68de3eb19688` |
| 规格 | 720×1280 竖版 / H.264 yuv420p / 24 FPS / **192 帧** / 8.043 s / 3.63 MB |
| 绿幕 | RGB ≈ (28,199,50)，四角一致，无光照渐变 |
| 人物 | 朝右全身，可见高 1094 px，画面质心 x 标准差 **4.3 px**（原地跟拍） |

用「非绿前景连通域 + 姿态轮廓自相关」逐帧量出的**真实动作阶段**：

| 阶段 | 帧 | 时间 | 判据 |
|---|---|---|---|
| 起始站立 | f1–f6 | 0–0.25 s | 帧间运动强度 ≈0.8（归一化 ×1000） |
| 起步 | f7–f12 | 0.25–0.50 s | 强度 13.6 → 33.7 |
| 稳定行走 | f13–f137 | 0.50–5.71 s | 强度稳定在 25–46 |
| 减速收脚 | f138–f156 | 5.75–6.50 s | 强度 11.3 → 0.3，双腿自然收拢 |
| 站立待机 | f157–f192 | 6.50–8.00 s | 相邻帧差 **0.00048**，视频基本冻结 |

**与任务书假设的差别**：0～1 秒不是"检查有效动作"，而是"起始站立 + 起步"；
停止从 **5.75 s** 就开始，不是 6 s；6.5 s 之后画面完全静止，因此待机用单帧而不是硬凑呼吸循环。
自相关给出步态周期 **L=36 帧（1.50 s）**，L=18 只是半周期（双腿交换时剪影相似造成的伪峰）。

### 循环窗口的选择依据

在 f13–f137 内穷举起点与周期，比较首尾姿态距离：

| 窗口 | 循环闭合差 | 末帧 → 停止段首帧 f137 的姿态差 |
|---|---|---|
| f36–f71 | 0.0017（最优） | **0.1944**（会是明显跳变） |
| **f28–f63（采用）** | 0.0020 | **0.0302**（小于循环内帧间均值） |

采用 f28–f63 是以 0.0003 的闭合度换停止过渡能自然接上，是正确的工程取舍。

---

## 三、三段动画（任务书第七节的重点汇报）

| 动画 | 源帧 | 帧数 | FPS | 时长 | 循环 |
|---|---|---:|---:|---:|---|
| `walk_right` | f28–f63 | **36** | **24** | 1.500 s | 是 |
| `walk_to_idle` | f137–f157 | **21** | **24** | 0.875 s | 否，播完自动回 idle |
| `idle_right` | f175 | **1** | 8 | 0.125 s | 是（单帧） |

**停止过渡：已完成。** 21 帧自然减速收脚，接触表逐帧检查无突变、无脚底漂移。
接入时做了**相位感知**：逐帧算出与过渡首帧姿态差 ≤1.5× 循环内帧间均值的相位为
`0 / 1 / 15 / 16 / 17 / 34 / 35`；玩家在这些相位松手就播完整过渡，其余相位直接切稳定站姿，
**不把不匹配的姿态硬拼在一起**。演示视频 `godot_movement_demo.mp4` 的 t≈2.0 s 处
（HUD 显示 `anim=walk_to_idle frame=20/21`）就是自然命中的一次。

### 循环与外形一致性量测

| 指标 | 实测 |
|---|---|
| 循环内相邻帧平均姿态差 | 0.0358 |
| **循环接缝 f63→f28** | **0.0239（0.67× 均值，无可见跳变）** |
| 循环末帧 → 过渡首帧 | 0.0302（0.84× 均值） |
| 最坏相位 → 过渡首帧 | 0.1975（5.51× 均值，见 §6 遗留问题） |
| 成品帧可见高度 | 158–163 px，std **1.48 px** |
| 成品帧脚底行 | y=166–168，std **0.78 px** |

---

## 四、视频处理：哪些问题被成功修复

### 管线针对性改进（保留原有 11 项自检全绿）

`tools/video/pipeline.py` 原有两处实现不适合这种 1094 px 高的赛璐璐素材，本轮新增可复现的改进，
默认行为不变（`selftest.py` 仍走旧路径）：

1. **`matte --key-mode chroma`** — 见 `tools/video/chroma.py`。
   原实现用「RGB 到键色的最大通道差」，绿幕溢色边缘会留绿；
   改用 **G − max(R,B)** 色度键 + 溢色抑制 + 连通域去杂点。
2. **`align --resample quality`** — 原实现是整数倍 NEAREST 直接抽样，
   1094→162 px 会严重锯齿丢细节。改为**预乘 alpha 的两阶段降采样**
   （LANCZOS4 缩到 2× → AREA 缩到 1× → 轻度 unsharp），
   并对**全序列共用同一个仿射变换**，避免逐帧 bbox 居中把身体摆动误当整体位移。
3. 新增 `tools/video/integrate_001.py` 编排七步流程与全部量测，
   所有参数（窗口、阶段、相位集合）来自视频实测，写在文件头 CONFIG。

> 开发中修掉两个真实 bug：despill 曾误把每个像素的 G 抬到 `max(R,B)`，整个人物被染黄绿；
> SpriteFrames 曾同时设 `duration=1/24` 与 `speed=24`，实际帧时长变成 1/576 s。
> 两者都已修正并由逐像素颜色断言 / 引擎实测帧推进验证。

### 修复清单

| 问题 | 处理 | 验证 |
|---|---|---|
| 绿幕背景 | 色度键 + 软过渡 + 连通域去杂点 | 抠像后只剩 **1 个**连通域；成品帧 `gn>50` 残留 **0 px** |
| 边缘绿色溢色 | 只减 `G − max(R,B)` 的绿色优势部分，不动正常肤色/棕色 | **192/192 帧**人物核心 RGB 逐像素不变 |
| 缩放黑边 | 颜色外扩 + 预乘 alpha 插值 | 4× 放大对照无暗边 |
| 高分辨率粗暴缩小 | 两阶段高质量降采样 | 1× 游戏尺寸轮廓清晰，3× 仍可读发髻/包/补丁/靴子 |
| 逐帧 bbox 居中抖动 | 全序列统一变换 | 脚底 std 0.78 px，中轴锁在 x=64 |
| 停止段被卷进行走循环 | 按运动强度切分，只取 f28–f63 | 循环内无减速帧 |
| 循环首尾跳变 | 穷举最优窗口 | 接缝 0.67× 正常帧间差 |
| 待机抖动 | 静止段相邻差 0.00048 → 取单帧 | 引擎测「待机不抖动」通过 |

---

## 五、Godot 接入与实机效果

### 改动

- 重建 `assets/characters/`：58 张 128×176 PNG + `player_sprite_frames.tres`。
- `scenes/characters/player.tscn` 挂回 SpriteFrames；Sprite 保持
  `centered=false / offset=(-64,-168) / Nearest / 1:1`，**碰撞盒 28×160 与脚底原点未动**。
- `PlayerController` 加动画状态机：`idle_right / walk_right / walk_to_idle`，
  停止相位感知、过渡播完信号回 idle、朝左 `flip_h` 镜像。
- **推车：`push_pose` 期间固定站姿**，绝不拿 `walk_right` 冒充推车动作；
  `push_walk_active` / 交互 / 绑定 / 物理行为原样保留。
- 新独立场景 `--dev-scene=vid001`（`scripts/dev/vid001_verify.gd`），
  用**真实 PlayerController** 跑测试 / 出检查点 / 录演示。
- 修掉一个路由 bug：`?dev=art003&state=...` 原本注入 `core_state`，
  而 art003 读的是 `art003_state`，导致 **Web 端检查点切换一直是无效的**
  （上一轮 Web 回归没实跑所以没发现）。

### 测试结果（全部为真实新测试，不是旧 r 系列断言沿用）

| 测试 | 结果 |
|---|---|
| `--dev-scene=vid001 --vid001-test` | **29 项全过 / 0 失败**（含 58 帧逐像素尺寸、脚底、绿色残留、动画切换、镜像、推车不冒充） |
| `--dev-scene=video --video-test`（候选帧引擎体检） | **8 项全过 / 0 失败**；高度波动 2.5%，脚底 166–167 |
| smoke | 26/26 |
| art003 / art004 / core001a / core001b | 全部符合预期，0 脚本错误 |
| **Web 端补测（上轮欠账）** | `check_art003_web` **10/10**、`check_core001b_web` **18/18** |
| 素材库审计 / ID 登记 / 页面验收 | 失败 0 警告 0 / 通过 / **52/52** |
| 视频管线 selftest | 通过（原 11 项未回归） |
| Web 导出 | `--export-release Web` 成功，58 张候选帧进 PCK，控制台无 error |

> `reset` 后退役的旧测试没有"恢复通过"：art003/art004 的手部贴合、像素交叠等断言
> 仍标退役，原因改为「本轮候选动画只有单人行走/停止/待机，没有推车手部姿态」。
> core001a / core001b 的量测行从「角色渲染 = 空」改成**真实 SpriteFrames 量测**。

### 八项验收效果对照

| # | 要求 | 交付物 |
|---|---|---|
| 1 | 原视频 ↔ 抠像对照 | `转存库/VIDEO-INTEGRATE-001/compare_greenscreen_matte.mp4`（8 s 并排视频）、`compare_raw_matte.png`、`compare_raw_matte_final.png` |
| 2 | 全部透明 PNG 序列 | `assets/dev/video_candidates/VIDEO-INTEGRATE-001/all_frames/` **192 张**，另三段目录 36/21/1 张 |
| 3 | 行走循环预览 | `.../preview/walk_right.gif`、`contact_walk_right.png` |
| 4 | 停止过渡预览 | `.../preview/walk_to_idle.gif`、`contact_walk_to_idle.png`、`vid001_stop_transition.png` |
| 5 | 待机预览 | `.../preview/idle_right.gif`、`vid001_idle_1x.png` |
| 6 | Godot 原生尺寸播放 | `vid001_walk_1x.png` / `vid001_test.png`（960×540，1× 角色 + 2× 放大窗） |
| 7 | 移动/停止/再行走演示 | `转存库/VIDEO-INTEGRATE-001/godot_movement_demo.mp4`（960×540 / 6.35 s / 127 帧）+ `.gif` + `demo_contact.png` |
| 8 | 边缘与脚底放大对照 | `compare_edges_4x.png`（发/手包/靴底三局部 4×）、`compare_game_scale.png`（1× + 3×） |

另附 `motion_curve.png`（逐帧运动强度与阶段划分）、`contact_sheet_raw.png` / `contact_stop.png`
（原片接触表）、`compare_v02_vs_video.png`（与 v02 基准对照）、`meta.json`（全部量测参数）。

---

## 六、仍然存在 / 无法靠后期修复的问题

1. **脚底滑动（无法根治）**：视频是原地跟拍（人物画面质心 std 4.3 px），
   而游戏按 100 px/s 平移。量得支撑脚在画面中每帧后退 2.28 px，
   游戏每帧前进 4.17 px，**净滑移 ≈1.89 px/帧**。24 FPS 全帧播放已是最优采样；
   降到 12 FPS 会让滑移翻倍，所以没用抽帧"修"。1× 下不明显，2×/3× 放大可见。
   要彻底解决需要重新生成"角色横向真实位移"的视频。
2. **停止过渡只在部分相位自然**：视频只提供**一次**减速过程。
   在允许相位（7/36 ≈ 19%）松手能无缝接过渡；其余相位直接切稳定站姿以避免跳变。
   若在非允许相位强行播过渡，姿态差可达 0.1975（5.51× 正常帧间差）——按要求**没有硬拼**。
   需要"多相位停止"视频才能全覆盖。
3. **画风与 v02 不完全一致**：v02 是明显像素颗粒的设定稿，AI 视频是平滑赛璐璐。
   服装要素（低马尾+发夹、深蓝连帽衫+橙领、卷袖、斜挎包、深棕工装裤膝部补丁、棕靴）
   一致，但包体偏小偏扁、外套口袋细节有漂移。缩到 128×176 后仍看得出风格差异。
4. **面容在 1× 下只有约 10 px 高**，五官不可辨——这是 960×540 视口 + 162 px 角色高的
   物理上限，不是缩放糊了（3× 放大图可见细节仍在）。
5. **推车动画本轮未制作**（按任务范围）。绑定购物车时角色是站姿滑行，
   状态与交互可用，但视觉上还没有扶车动作。
6. **朝左只是镜像**，没有独立绘制的左向帧（任务允许）。

---

## 七、是否具备正式美术审核条件

**具备。** 三段动画、全部对照图、预览、Godot 实机演示与 29 项引擎测试都已就绪，
`godot_movement_demo.mp4` 可以直接作为审核片。

**但尚不建议直接转正**，请先在审核中明确裁定 §6 的第 1、2、3 项是否可接受：

- 接受 → 下一个任务把 `vid001` 分配正式 `rNN`、写入 `素材台账.csv`、
  `check_artlib_page.mjs` 白名单、`美术总览.html` 正式状态；
- 不接受 → 按 `docs/AI视频转Godot动画接入规范.md` 的退回条款，
  由用户重新生成视频（尤其建议加入横向真实位移与多相位停止）。

本轮按停止条件到此结束：**未改台账、未改白名单、未改总览正式状态、未做推车动画、
未开发玩法、未生成任何 AI 视频、未重绘主角**。

---

## 八、复现命令

```bash
# 全流程（源视频在 转存库/ 根目录，脚本会自动定位唯一的 mp4）
python tools/video/integrate_001.py --source "转存库/Generating_pixel_art_walking_ani…_0afbba1d.mp4"
python tools/video/selftest.py                     # 原管线 11 项自检

# 引擎导入 + 新动画真实测试
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --import
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- --dev-scene=vid001 --vid001-test --quit
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- --dev-scene=vid001 --vid001-tour --quit
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- --dev-scene=vid001 --vid001-movie --quit
# 演示帧序列 → MP4（帧序列是中间产物，合成后删除）
ffmpeg -framerate 20 -i tests/screenshots/vid001_movie/f_%04d.png -c:v libx264 \
       -pix_fmt yuv420p -crf 20 转存库/VIDEO-INTEGRATE-001/godot_movement_demo.mp4

# 静态 / Web 回归
python tools/audit_artlib.py && python tools/check_id_registry.py && python tools/artlib_curate.py --check
python tools/build_artlib.py && CDP_PORT=9333 node tools/check_artlib_page.mjs
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release Web builds/web/index.html
python tools/serve_web.py &                        # 8060
CDP_PORT=9333 node tools/check_art003_web.mjs
CDP_PORT=9333 node tools/check_core001b_web.mjs
```

> 大体积中间产物（原始帧 / 全分辨率抠像帧 / 演示 PNG 序列，共约 119 MB）
> 在 `.work/video_in/` 与 `tests/screenshots/vid001_movie/`，已加入 `.gitignore`，
> 可由上述命令重建。入库的是成品帧、对照图、预览与两段 MP4。
