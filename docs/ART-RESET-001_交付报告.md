# ART-RESET-001 交付报告 · 许知夏角色素材彻底重置

> 执行日期：2026-11-10　|　分支：`角色制作`
> 回退点：标签 `pre-ART-RESET-001`（重置前完整工作区，= 096c7fc）
> 本轮**没有生成任何 AI 视频，没有重绘主角，没有做新动画**。

---

## 一、结论先说

许知夏的旧运行时形象（r01 / r02 / r03 / r04 / r09）连同贴图、SpriteFrames、动画状态机、
RIG 骨骼原型、验证场景、交付包、缩略图、测试截图**全部从当前工作树删除**，
不保留归档、不保留回退版本。

**唯一外观基准**：`素材库/美术设定集/01-角色/ART_CHAR_001_v02_许知夏_五视图设定候选.png`，
另从它无损裁出 5 张视频参考图。

**游戏现状**：角色不可见，但移动 / 碰撞 / 摄像机 / 场景切换 / 门与货架交互 /
购物车绑定与推拉全部正常。Godot 启动零资源加载错误。

---

## 二、删除清单（共 499 个文件）

| 类别 | 数量 | 明细 |
|---|---:|---|
| 素材库角色图 | 31 | `01-角色/` 下 v01 + r01(2) + r02(5) + r03(2) + r04(4) + r09(17) |
| 运行时角色资源 | 56 | `assets/characters/` 27 张 PNG + 27 个 `.import` + `player_sprite_frames.tres` + 1 个 uid |
| RIG 骨骼原型 | 54 | `assets/dev/rig001_proto/`：layers 32 + diagnostics 20 + spec 等 |
| 转存库旧交付包 | 54 | `ART_ANIM_005E_留档/`（26）、`ART_RUNTIME_004/005_留档`（22）、r01/推车姿态/行走四帧母图与 4 个 zip（6） |
| 缩略图与动画缓存 | 14 | `.thumbs/` 下 10 张角色缩略图 + `.thumbs/anim/` 4 个 GIF |
| 错误商品图 | 8 | `assets/items/` 4 张 r01/r01-shelf + 4 个 `.import` |
| 素材库历史归档 | 5 | `03-物品与家具/历史归档/` 4 张错误图 + README（目录一并删除） |
| 脚本 | 11 | `import_art005e_archive.py`、`approve_art005e.py`、`make_art005e_media.py`、`make_hand_contact_zoom.py`、`make_rig001_layers.py`、`make_rig001_media.py`、`check_art005e_web.mjs`、`check_art005e_pck.py`、`sync_ledger_005_phase1/2.py` |
| 验证场景与脚本 | 9 | `art005_verify` / `art005e_verify` / `rig001_verify` 的 `.tscn` + `.gd` + `.uid` |
| 测试截图 | 257 | `art002_*` / `art005_*` / `art005e_*` / `rig001_*` / 角色对位类（hand / mirror / overlap / hand_contact） |

**没有误删**：NPC 五视图（104–107）、`ART_CHAR_002` / `003`、场景 6 张、购物车与货架与商品、
字体、UI 主题、`assets/reference/` 外部风格参考，全部原样。

> Git 历史没有改写。要看旧素材：`git show pre-ART-RESET-001:<路径>`。

---

## 三、游戏代码怎么清的

### 3.1 PlayerController 去美术化

| 删除 | 保留 |
|---|---|
| `ANIM_IDLE / WALK / PUSH / PUSH_WALK / PUSH_R09 …` 全部动画常量 | 水平移动（`move_speed=100`）、加减速、朝向 |
| `push_anim_variant` + `set_push_anim_variant()` 默认版本切换与回退 | 碰撞 28×160、脚底接地、`ground_y` |
| `_apply_walk_fps()` / `_sync_animation()` 的播帧逻辑 | `state` / `push_pose` / `push_walk_active` 三个**状态标记**（仍由推车驱动） |
| `_body_axis()` / `_apply_visual_offset()` 绘制对齐 | `external_control`（推车接管）、`input_axis()` |
| `freeze_frame()` / `resume_animation()` / `current_texture()` / `visible_bbox()` / `drawn_body_axis()` | `teleport_to()` / 碰撞盒读写 / `has_visual()` |

`has_visual()` 是新增的：测试用它区分「功能通过」与「美术缺失」，不许把两者混为一谈。
启动会打印一次 `[PLAYER] 角色渲染为空：ART-RESET-001 …`，让人一眼看到当前是空渲染而不是忘了接。

### 3.2 场景与节点

`player.tscn` 删掉 `SpriteFrames` 外链，`Sprite` 节点保留并 `visible=false`，
`centered=false` / `offset=(-64,-168)` 不动 —— 将来换新 SpriteFrames 即可，锚点约定不变。

### 3.3 旧动画专项测试：**标记退役，不是删掉换绿灯**

| 场景 | 处 置 |
|---|---|
| `art005` / `art005e` / `rig001` | 整场景删除（它们只测角色动画，没有别的对象） |
| `core001b --art002` 截图组 | 删掉整组，参数保留并打印「已退役」 |
| `art003` B（脚底锚点）/ C（手部贴合）/ F（镜像绘制偏移） | 三组删除，原位打印「已退役（角色贴图已删除，无手部像素可量）」 |
| `art004` E（手部贴合）/ G 的像素交叠 | 同上，打印退役说明 |
| `core001a` `_measure_and_report` | 删掉可见框 / alpha 档位量测，保留碰撞、门净宽、通道余量 |
| `core001b` `_measure` 与 T8 | 删掉可见框 / 中轴 / 冻结帧，保留碰撞与世界坐标不变式 |
| Web 验收 `check_art003_web` / `check_core001b_web` | 旧「[ANIM] 播了某动画」断言 → 改为「确实没有 [ANIM] 输出」，并注明原因 |

**退役 ≠ 通过**。凡是删掉的断言，原位置都留了一条打印说明为什么删、以后怎么恢复；
没删的断言照常跑，必须真通过。修复后实测：
`art003` 全部符合预期、`art004` 全部符合预期、`core001b --core-test` 失败 0 项、
`smoke` 26/26、`core001a` 0 script error。

### 3.4 速度口径统一

- 普通移动 **100 px/s**（`PlayerController.move_speed`，未改）
- 推车 **80 px/s**、拉车 **40 px/s**（`PushableCart.push_speed / pull_speed`，未改）
- **ART-RIG-001 的 70 px/s 步态推演作废**，不再约束新动画；规范里已改写，滑步测试一律以 100/80/40 为基准。

---

## 四、五张视频参考图（从 v02 无损裁取）

工具：纯 `PIL.Image.crop()`，**不缩放、不重绘、不调色、不去背景**；
每张生成后立刻用 `np.array_equal` 与源图同区域比对，5/5 全 `True`。

| 文件 | 内容 | 裁取区域 | 尺寸 |
|---|---|---|---|
| `ART_CHAR_001_v02_ref_right.png` | 朝右全身 | 800,25,984,957 | 184×932 |
| `ART_CHAR_001_v02_ref_left.png` | 朝左全身 | 1026,26,1221,957 | 195×931 |
| `ART_CHAR_001_v02_ref_front.png` | 正面全身 | 498,26,760,958 | 262×932 |
| `ART_CHAR_001_v02_ref_back.png` | 背面全身 | 1248,23,1502,958 | 254×935 |
| `ART_CHAR_001_v02_ref_face.png` | 面容特写 | 22,125,512,782 | 490×657 |

放在 `素材库/美术设定集/01-角色/参考图/`，**不占素材 ID、不进 `assets/`、不是 Godot 精灵**。
游戏内角色朝右，所以规范里把「朝右全身」标为主参考，正面对齐服装细节。

---

## 五、素材库与总览页

- **台账**：39 行 → **29 行**（删 7 条角色行 + 4 条错误商品行）。
  「运行时可用」15 条 → **11 条**，全部是道具/设施，**角色 0 条**。
- **白名单**：15 → 11 条，`check_artlib_page.mjs` 里角色条目已移除；新动画接入必须显式加行。
- **ID 登记表**：`ART_CHAR_001` 仍为「已用」，备注改为「v02 唯一基准；v01 与 r01–r09 已删除」。
- **页面**（`美术总览.html`）改三处：
  1. 顶部横幅写明「旧动画 r01–r09 已全部删除，角色渲染为空」；
  2. 「AI 视频参考图」页 = v02 五张裁图（竖版大图，按 右/左/正/背/面容 排序）+ 四个动作的
     人物参考与道具参考组合；
  3. 第三个 tab 从「动作缺口」改为「角色动作状态」：7 个动作里
     待机 / 普通行走 / 推购物车 标 **待重新制作**，反向拉车 / 搬运 / 转身 / 朝左独立绘制 标 **未开始**。
- **角色网格**：`分类=角色` 只剩 7 张卡（v02 + 4 位 NPC 五视图 + 群像 + 画风参考），
  没有任何 r 系列卡片。

---

## 六、验收结果

| 项 | 结果 |
|---|---|
| Godot 导入（`--import`） | 0 报错 |
| 默认启动 / 超市场景 | 退出码 0，**0 个 SCRIPT ERROR / Failed** |
| 冒烟自检 `--dev-scene=smoke` | **通过 26 项，失败 0 项** |
| `art003 --art003-test` | **全部符合预期**（手部贴合 / 镜像绘制偏移已退役并打印说明） |
| `art004 --art004-test` | **全部符合预期**（手部贴合 / 人物篮网交叠已退役） |
| `core001b --core-test` | **失败 0 项** |
| `core001a` | 0 script error，量测输出只剩碰撞与门/通道 |
| `python tools/check_id_registry.py` | 通过（登记 38 号 / 台账 29 行 / 17 个 ID） |
| `python tools/audit_artlib.py` | **失败 0，警告 0** |
| `node tools/check_artlib_page.mjs` | **52 / 52 通过** |
| `python tools/video/selftest.py` | 通过（视频管线完好保留） |
| 全项目 `grep ART_CHAR_001_r` | **代码/场景/资源文件中 0 命中**（仅历史文档与 memory 提及） |

---

## 七、视频管线保留情况

`tools/video/pipeline.py`（probe → extract → matte → analyze → align → build）、
`tools/video/selftest.py`、`--dev-scene=video` 预览体检场景**一条没动**，
`docs/AI视频转Godot动画接入规范.md` 只改了三处：速度口径（70 作废）、参考图来源（改用 v02 裁图）、
缺口清单（改为「待重新制作」）。

---

## 八、剩余问题

1. **角色完全不可见** —— 这是本轮要的结果，不是遗留 bug。下一条视频到位前，游戏里看不到主角。
2. **`assets/characters/` 目录已整体移除** —— 全项目已无任何对该路径的引用
   （`grep assets/characters` 在 .gd / .tscn / .tres / .cfg 里 0 命中）。
   接新动画时重建该目录即可，`player.tscn` 的 Sprite 节点已经留好锚点。
3. **`art003_web` / `core001b_web` 的 Web 断言尚未实跑** —— 本轮只做了静态修改与桌面端验证，
   Web 端需要导出 + 起服务 + CDP，属下一轮回归项。
4. **`转存库/ART_CORRECTION_003C_纠错与接入说明.md` 保留** —— 它记录的是"内容互换"这个事故本身，
   不是错误素材；文件指向的四张图已删，文档保留作复盘。
5. **历史交付报告（`docs/ART-*_交付报告.md`）未改写** —— 它们是当时的真实记录，
   描述的资源现已删除。看这些报告请先读本文件，不要拿它们当当前状态。

---

## 九、给下一条视频的交接

```bash
# 用户把视频放到 转存库/ 后
python tools/video/pipeline.py all 转存库/<视频> --batch walk_right --action walk --fps 10 --speed 100
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . -- \
    --dev-scene=video --video-dir=walk_right --video-fps=10 --video-test
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- \
    --dev-scene=video --video-dir=walk_right --video-tour
```

体检全绿 → 交美术审核 → 批准后搬进 `assets/characters/`、写 SpriteFrames、
在 `素材库/素材台账.csv` 新增 `rNN` 行、白名单显式加行、`state=正式使用`。
**本轮到此停止，不开始新的角色动画制作，也不动 CORE-002。**

---

## 提交记录

| 提交 | 内容 |
|---|---|
| `e7da982` | docs：交付报告、开发说明 §7.0/§7.4 改写、接入规范速度裁定、目录树、失效横幅 |
| `f3a4543` | feat：删除 499 个旧角色相关文件、代码去美术化、测试断言退役、参考图裁取、台账与页面 |
| （本行提交） | docs：回填提交哈希 |

回退方式：`git checkout pre-ART-RESET-001`（指向重置前的工作区）。
