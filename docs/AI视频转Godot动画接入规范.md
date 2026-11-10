> **VIDEO-QUALITY-002 更新**：接入贴图已升到 512×704，128×176 现在指**游戏内显示尺寸 /
> 锚点换算基准**，不再是贴图文件分辨率。候选帧序列仍按 128×176 产出做体检，
> 正式接入帧由 `tools/video/quality_002.py` 输出。其余工程约束不变。

# AI 视频 → Godot 动画接入规范

> 建立：2026-11-10 / TASK-ARTLIB-CLEAN-001
> 适用：《寒潮清单》第一季角色动作（步行为主）
> 状态：**链路已实跑通**（VIDEO-INTEGRATE-001 完成真实视频拆帧接入，
> VIDEO-QUALITY-002 完成 512×704 高清优化）；资源仍是候选，等最终美术审核转正。

---

## 0. 一句话分工

**用户生成视频，开发 Agent 只做「把视频变成能上机的帧序列」这一件事。**
开发 Agent **不调用任何 AI 视频生成服务，不设计新角色，不重绘已确认的美术资产**。

| 角色 | 负责 | 不负责 |
|---|---|---|
| ChatGPT 主对话 | 挑参考图、写视频提示词、定外观与动作质量标准、审最终效果 | 拆帧、抠像、写代码 |
| 用户 | 选模型、上传参考图、生成视频、挑满意版本、把视频交给 Agent | 手动拆帧 / 抠像 / 做 SpriteFrames |
| 开发 Agent（本侧） | 抽帧、抠像、对齐、循环检测、导出、引擎内验收、汇报 | 生成视频、改美术设定、擅自转正 |

---

## 1. 工程约束（以当前代码为准）

| 项 | 值 | 代码位置 / 说明 |
|---|---|---|
| 引擎 | Godot 4.7.2 stable，GDScript，GL Compatibility | `project.godot` |
| 游戏视口 | 960×540，整数倍缩放 | `project.godot` / `WindowFit` |
| 角色帧画布 | **游戏内显示 128×176**；VIDEO-QUALITY-002 起贴图文件为 **512×704 @ scale 0.25**，脚底贴图内 (256,672) → 世界 (0,0) | `scenes/characters/player.tscn`（几何单一数据源） |
| 脚底锚点 | **(64, 168)** | 同上；`sprite.offset` 让该像素落在节点原点 |
| 纹理过滤 | Nearest（无平滑） | 贴图导入参数；新贴图必须 `fix_alpha_border=false` |
| 普通行走速度 | **100 px/s** | `PlayerController.move_speed = 100.0` |
| 推车速度 | **80 px/s** | `PushableCart.push_speed = 80.0` |
| 拉车速度 | **40 px/s** | `PushableCart.pull_speed = 40.0` |
| 碰撞盒 | 28×160 | `PlayerController.collision_width/height` |
| 相机 | 跟随，无缩放 | `scripts/characters/follow_camera.gd` |

**禁止**为了「看起来能对上」而任意缩放、插帧、改 `move_speed`、改画布尺寸。
速度与帧率对不上就是滑步，滑步要改美术，不是改数值糊过去。

> ✅ **速度口径已统一（2026-11-10 美术总监裁定）**：普通行走 100 / 推车 80 / 拉车 40 px/s，
> 三者都不改。ART-RIG-001 里按 **70 px/s** 做的步态推演**作废**，不再用它约束新动画。
> 新动画的滑步测试一律以这三个真实值为基准。

---

## 2. 视频交付要求（给用户的最小清单）

| 项 | 要求 | 不合格的表现 |
|---|---|---|
| 容器 / 编码 | mp4（H.264）或 webm，能正常播放即可 | — |
| 分辨率 | **≥ 512×512**，人物在画面里占高度 1/2 以上 | 太小 → 放大必糊 |
| 帧率 | ≥ 10 FPS，优选 24 / 30 | 低于 10 抽不出连续动作 |
| 时长 | 0.6–4 s，**只含一个完整动作循环** | 太长 → 里面混了转身 / 停顿 |
| 背景 | 纯色或极简渐变，与人物对比明显 | 复杂背景 → 抠像边缘炸 |
| 机位 | **固定不动**，侧视，人物朝右 | 镜头推移 → 每帧比例都变 |
| 人物 | 全身入画、脚不贴边、不被裁切 | 脚被裁 → 无法对齐锚点 |
| 内容 | 只含同一个角色、同一套服装、道具同框且不遮挡躯干 | 中途换装 / 多角色 → 直接退回 |
| 命名 | `ART_CHAR_001_<动作>_<方向>_source.mp4`，如 `ART_CHAR_001_walk_right_source.mp4` | — |

**参考图从哪来**：`素材库/美术总览.html` → 顶部「AI 视频参考图」页。

人物参考只有一套：`素材库/美术设定集/01-角色/参考图/` 下五张从 **v02 原图无损裁取**的裁图
（朝右 / 朝左 / 正面 / 背面 / 面容）。游戏内角色朝右，**动作视频以「朝右全身」为主参考**，
再配「正面全身」对齐服装细节。裁图规则见该目录 README。

道具参考来自已登记素材：购物车 `ART_FURN_103 r02`、食品纸箱 `ART_ITEM_102 v01`、
饮用水 `ART_ITEM_101 v01`。**不要拿无关图凑，也不要拿 v02 以外的旧角色图。**

---

## 3. 处理链路

工具：`tools/video/pipeline.py`（六个子命令，可单独跑，也可 `all` 一次到底）

```
INPUT.mp4
  ├─ probe    拍参数：编码 / 分辨率 / FPS / 时长 / 预估帧数，先判断值不值得做
  ├─ extract  抽全部原始帧        → assets/dev/video_candidates/<batch>/frames_raw/
  ├─ matte    按背景键色抠像       → .../frames_matte/
  ├─ analyze  体检：包围盒 / 脚底行 / 重复帧 / 形变 / 步幅   ← 不合格就在这里停
  ├─ align    整数最近邻缩放 + 水平居中 + 脚底贴 (64,168)  → .../frames_out/
  └─ build    接触表 + 循环 GIF    → .../preview/
```

一条命令跑完：

```bash
python tools/video/pipeline.py all 转存库/ART_CHAR_001_walk_right_source.mp4 \
    --batch walk_right --action walk --fps 10 --speed 100
```

只跑其中一步：

```bash
python tools/video/pipeline.py probe   转存库/xxx.mp4
python tools/video/pipeline.py matte   --batch walk_right --tolerance 28 --softness 24
python tools/video/pipeline.py analyze --batch walk_right --speed 100
```

产物目录 `assets/dev/video_candidates/<batch>/` 是**隔离区**：
不进 `assets/characters/`、不改 `player_sprite_frames.tres`、不改台账、不改白名单。
`.gitignore` 之外也不该长期保留 —— 要么转正时搬走，要么整目录删掉。

---

## 4. 引擎内验收

工具：`--dev-scene=video`（`scenes/dev/video_preview.tscn` + `scripts/dev/video_preview.gd`）

它是唯一「真的在 Godot 里看一眼」的地方：读 `frames_out/` 的 PNG（**不需要先 import**），
按台账 FPS 循环播放，画地面刻度与脚底锚点十字。

```bash
# 体检（不需要窗口，8 项用例，退出码即结论）
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . -- \
    --dev-scene=video --video-dir=walk_right --video-fps=10 --video-test

# 交互看：空格 播放/暂停　1/2/3 切换缩放　M 移动演示（看滑步）　←/→ 逐帧
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- \
    --dev-scene=video --video-dir=walk_right --video-fps=10 --video-speed=100

# 出检查点截图：video_1x / video_2x / video_3x / video_move_00…07
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- \
    --dev-scene=video --video-dir=walk_right --video-tour
```

引擎体检 8 项（任何一项失败都不得进入审核）：

| # | 用例 | 判据 |
|---|---|---|
| 1 | 帧数 | ≥ 2 |
| 2 | 画布 | 全部 128×176 |
| 3 | 透明 | 全部带 alpha 通道 |
| 4 | 脚底行可测 | 每帧能测到最下方不透明像素 |
| 5 | 脚底贴合锚点 | 最下方像素行 = 168 ± 2 |
| 6 | 脚底稳定 | 全部帧脚底行波动 ≤ 2px |
| 7 | 无重复帧 | 相邻帧不完全相同 |
| 8 | 无比例漂移 | 包围盒高度波动 ≤ 12%（宽度只记录，>60% 才失败，因手脚摆动天然变宽） |

---

## 5. 全量验收清单（12 项，对应任务要求）

| # | 检查 | 谁做 | 不通过的处置 |
|---|---|---|---|
| 1 | 视频格式 / FPS / 分辨率 / 时长 | `probe` | 不满足 §2 → 退回 |
| 2 | 提取全部原始帧 | `extract` | — |
| 3 | 识别主体并去背景 | `matte` | 边缘残留 → 调 tolerance / 退回 |
| 4 | 清理残留背景、半透明边缘、错误像素 | `matte`（软阈值）+ 人工看接触表 | 仍有块状残留 → 退回 |
| 5 | 人物比例 / 衣服 / 头发 / 面部是否漂移 | `analyze` 高度波动 + 接触表目视 | 漂移 → **退回重生成** |
| 6 | 连续动作是否突变或重复帧 | `analyze` 重复帧 + 接触表 | 突变 → 剪掉那段或退回 |
| 7 | 选自然循环区间 | 人工（接触表 / `--video-tour`） | 循环接缝跳 → 改起止帧重跑 align |
| 8 | 统一锚点 / 位置 / 画布 | `align` | — |
| 9 | 脚底滑动 vs 移动速度 | `engine --video-test` 的步幅推算 + `M` 移动演示 | 滑步 → 退回或改帧数 |
| 10 | 输出透明 PNG 序列 / SpriteSheet / SpriteFrames | `build` + 转正时手写 `.tres` | — |
| 11 | 原生尺寸与放大预览 | `--video-tour`（1x/2x/3x） | 放大糊 → 源分辨率不够，退回 |
| 12 | 真实 Godot 运行效果供审核 | `--video-tour` 的 `video_move_*` | — |

---

## 6. 转正流程（重要：不得跳过）

```
候选 (frames_out + 体检通过)
   ↓  ① 引擎验收：--video-test 全绿 + --video-tour 截图
   ↓  ② 用户 + ChatGPT 美术审核（看 GIF / 移动连拍，不看单帧）
   ↓  ③ 明确批准：写清批准人 / 日期 / 任务编号
   ↓  ④ 帧文件搬进 assets/characters/，新增/改写 SpriteFrames
   ↓  ⑤ 台账新增一行 rNN：审核状态=运行时可用、视觉评价=认可、使用状态=正式使用
   ↓  ⑥ 旧版本保留：使用状态改「回退保留」，代码里留可切回的 variant
```

硬规则：

- **未获批准前，`审核状态` 只能写 `待审核`，`使用状态` 只能写 `未使用`。**
- 不得直接覆盖现有正式动画；新版本一律新开 `rNN` 行。
- 切换默认版本必须同时在代码里留回退开关（参考 `PlayerController.push_anim_variant`）。
- 每次转正都要跑：
  ```bash
  python tools/artlib_curate.py     # 写整理列
  python tools/audit_artlib.py      # 完整性
  python tools/build_artlib.py      # 重建页面
  node tools/check_artlib_page.mjs  # 页面验收
  ```

---

## 7. 必须退回重生成的情形

出现下面任何一条，**不要试图修**，直接退回并说明原因：

1. 人物形象漂移：五官、发型、服装配色在片段内明显变化。
2. 身体结构错误：多手多脚、关节反向、道具穿模。
3. 背景残留无法清除：大面积非纯色背景、地面阴影与人物粘连。
4. 动作不可修复：镜头推移、人物出画、动作本身不是循环。
5. 分辨率不足：放大到 3x 明显糊（本作是像素游戏，糊就是不能用）。
6. 帧数不够凑不出步态：一个循环少于 4 帧。

退回话术模板：

> 该视频无法用于 `ART_CHAR_001` 的 `<动作>`：`<具体问题>`。
> 建议重生成时：机位固定侧视朝右、纯色背景、人物全身入画高度占 2/3、单循环 1–2 秒、
> 不要镜头推移与换装。参考图见 `素材库/美术总览.html` → AI 视频参考图 → `<动作>`。

---

## 8. 已知缺口与未定事项

| 项 | 状态 |
|---|---|
| 待机 / 普通行走 / 推购物车 / 反向拉车 / 搬运 / 转身 / 朝左独立帧 | **待重新制作**（旧 r01–r09 已删除），页面「角色动作状态」页有清单 |
| 车轮滚动 | 未交付，车体目前整图滑行 |
| 步速口径 | **已裁定**：100 / 80 / 40，70 px/s 作废，见 §1 |
| 抠像只做纯色键控 | 复杂背景（渐变 / 阴影）效果差，属已知限制 |
| 无 GPU 训练的分割模型 | 本侧不引入深度学习依赖，保持 Pillow + numpy 可复现 |
| SpriteSheet 打包 | 本轮只出 PNG 序列 + GIF；`.tres` 用逐帧纹理，没做单图 sheet |
| 视频预览 | 引擎内不支持直接播 mp4（需插件），一律先转帧序列 |

---

## 9. 相关文件

| 文件 | 作用 |
|---|---|
| `tools/video/pipeline.py` | 六步处理管线 |
| `tools/video/selftest.py` | 用合成测试片端到端自检（`python tools/video/selftest.py`） |
| `scripts/dev/video_preview.gd` | 引擎内预览与体检场景 |
| `scenes/dev/video_preview.tscn` | 上者的场景壳 |
| `素材库/美术设定集/05-特效与动画/动画素材记录规范.md` | 动画在台账里怎么记 |
| `素材库/美术总览.html` | 参考图入口（AI 视频参考图页） |
| `docs/ART-RIG-001_角色分层与骨骼制作规范.md` | 另一条路线（分层 + 骨骼），与本链路并行不冲突 |
