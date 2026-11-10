# VIDEO-QUALITY-002 交付报告 · 许知夏高清动画优化

> 分支 `角色制作`　日期 2026-11-10　前置 `VIDEO-INTEGRATE-001`
> **状态：候选 / 待最终美术审核。** 台账、运行时白名单、`美术总览.html` 正式状态一律未改。
> 未生成新视频、未重新设计角色、未做多套画质方案、未重做动作拆分。

## 1. 最终贴图分辨率

**512×704**（上一轮 128×176 的严格 4×），三段共 **58 张**透明 PNG，
动作结构与帧率完全不变：`walk_right` 36 帧 / 24 FPS、`walk_to_idle` 21 帧 / 24 FPS、`idle_right` 1 帧。

来源是上一轮 `.work/video_in/frames_matte/` 里 **720×1280 的全分辨率抠像帧**，
重新做颜色外扩 + 预乘 alpha 的两阶段降采样（LANCZOS4 → AREA）生成；
**没有**把任何 128×176 的成品帧放大。脚本 `tools/video/quality_002.py` 可复现。

配套几何（`scenes/characters/player.tscn` 单点管理）：

| 项 | 上一轮 | 本轮 |
|---|---|---|
| 贴图 | 128×176 | **512×704** |
| 贴图内脚底锚点 | (64,168) | (256,672) |
| Sprite `scale` | 1.0 | **0.25** |
| Sprite `offset` | (-64,-168) | (-256,-672) |
| `texture_filter` | NEAREST(1) | **LINEAR(2)**，不开 mipmap |
| **游戏内显示大小** | 128×176 | **128×176（不变）** |
| 世界脚底 / 碰撞 / 速度 | (0,0) / 28×160 / 100 | **完全不变** |

## 2. 实际游戏画质改善

关键是查出一个**全局渲染限制**：`project.godot` 原本是
`window/stretch/mode="viewport"` + `scale_mode="integer"`，渲染目标被钉死在 960×540，
再整数放大到窗口。实测 1920×1080 窗口下 `viewport_tex` 仍是 **960×540**——
**只换高清贴图、不改这一行，实机画质根本不会变**（角色永远只有 128×176 个采样点）。

最小修复：把这一行改成 `canvas_items`（保留 `integer` 缩放，其它设置一律没动）。
像素素材仍走 Nearest、逻辑视口仍是 960×540；UI 与场景内容未改。
改后 2× 窗口渲染目标变为 1920×1080，高清贴图才真正生效。

以角色区域的 Laplacian 方差（实机截图，非素材图）量化：

| 窗口 | 修复前 | 修复后 | 变化 |
|---|---:|---:|---|
| 1×（960×540） | 1189 | **1396** | **+17.4%** |
| 2×（1920×1080） | 305 | **565** | **+85.2%** |

2× 窗口里 BEFORE 的 2×2 马赛克块完全消失，头发分缕、发夹、眼睛、
连帽衫抽绳、包扣、鞋带都能辨认。见
`转存库/VIDEO-QUALITY-002/compare_godot_2x_before_after.png` 与
`tests/screenshots/vid001_hires_walk.png`（1920×1080 实机）、
`tests/screenshots/art003_overview.png`（货架 / 商品 / 购物车真实场景）。

> 过滤方式是实测选定的：mipmap 方案在 1× 窗口反而让锐度掉到 727（−38.9%），
> LINEAR 在 1× 是 1396、2× 同样清晰且无锯齿，还省掉 33% 纹理显存，因此定稿 LINEAR。

## 3. 是否仍有明显模糊或马赛克

- **2× 及以上窗口：没有马赛克，也没有明显模糊**，边缘干净。
- **1× 窗口：没有马赛克**，但角色物理上只有约 162 像素高，面容细节受
  960×540 视口上限约束——这是分辨率的物理上限，不是贴图糊了，继续提高贴图也无法解决。
- 边缘检查：58 帧高清图不透明区绿色残留 **0 px**；抽样半透明边缘 101774 px 中
  绿色优势 **0 px**；实机 2× 截图高饱和青 / 品红渗色 **0 px**；
  近黑边缘像素约 8 px/帧（占 0.002%，集中在头发与靴子的深色区），实机无可见黑边。
- **遗留（非本轮范围）**：角色是平滑赛璐璐风，与场景像素素材仍有风格差异；
  这需要重新设计 / 重绘才能统一，按本轮约束未处理。

## 4. 性能与资源体积影响

| 指标 | 上一轮 | 本轮 | 变化 |
|---|---:|---:|---|
| 单帧 RGBA8 显存 | 88 KB | 1408 KB | **×16** |
| 58 帧常驻纹理显存 | 5.0 MB | **79.8 MB** | +74.8 MB |
| PNG 磁盘 | ≈0.68 MB | **7.73 MB** | ×11 |
| Web PCK | 17.17 MB | **20.90 MB** | +3.73 MB |
| 全量 192 张高清帧 | — | 27 MB | 仅本地 `.work/`，已忽略不入库 |

**如实说明风险**：+75 MB 常驻显存对低端设备与 Web 版是实打实的负担；
`canvas_items` 在 2× 窗口下整体渲染像素变为 4 倍（这是画质提升的代价）。
角色**显示尺寸没变**，所以单帧 fill rate 与动画帧数（36/21/1）、播放 FPS 都没变，
CPU 侧动画逻辑零改动。没有开 mipmap，避免了再叠加 33% 显存。
若后续目标平台显存吃紧，需要由美术/技术共同裁定是否回退到 256×352——
本轮按任务要求只交付 512×704 一套，不做多方案。

## 5. 回归测试

| 项 | 结果 |
|---|---|
| `--dev-scene=vid001 --vid001-test` | **29/29**（已适配 512×704、脚底 672±8、绿色残留、动画切换、镜像、推车不冒充） |
| `--dev-scene=vid001 --vid001-hires` | 2× 窗口渲染目标 1920×1080，截图正常 |
| smoke | 26/26 |
| art003 / art004 / core001a / core001b | 全部符合预期，**0 脚本错误** |
| Web：`check_art003_web` / `check_core001b_web` | **10/10** / **18/18**（重新导出 Web 后实跑） |
| `check_artlib_page` | 52/52 |
| 素材库审计 / ID 登记 / curate / 视频管线 selftest | 失败 0 警告 0 / 通过 / 已同步 / 通过 |

顺带修掉一个上一轮遗留的真实脚本错误：`art003_verify.gd` 的默认状态还是
已删除的检查点 `hand_r`，`_draw_captions()` 会访问不存在的字典键并报 SCRIPT ERROR。
改成 `shelves` 并移除失效分支后，art003 测试 0 错误（没有靠忽略日志掩盖）。

## 6. 交付物与复现

- 高清帧：`assets/characters/ART_CHAR_001_vid001_hd_*.png`（58 张）+ `player_sprite_frames.tres`
- 对照与接触表：`转存库/VIDEO-QUALITY-002/`（`compare_godot_1x_before_after.png`、
  `compare_godot_2x_before_after.png`、`compare_edge_detail.png`、`compare_edges_hd.png`、
  `compare_game_size.png`、`contact_hd_walk.png`、`meta.json`）
- 实机截图：`tests/screenshots/vid001_walk_1x.png`（1×）、
  `vid001_hires_walk.png` / `vid001_hires_idle.png`（2×）、`art003_overview.png`（真实场景）

```bash
python tools/video/quality_002.py                 # 全量高清帧 + 游戏帧 + 对照
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --import   # 生成 .import
python tools/video/quality_002.py --fix-imports   # 固化导入预设（no mipmap / fix_alpha_border=false / compress_to=0）
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --import   # 应用
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- --dev-scene=vid001 --vid001-test --quit
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- --dev-scene=vid001 --vid001-hires --quit
```

本轮到此停止：**保持美术候选状态**，等最终审核通过后才分配 `rNN`、
写台账 / 白名单 / 总览正式状态。
