# rig001_proto — 许知夏骨骼技术原型的分层素材（**临时件**）

> 状态：**技术验证 / 待美术审核**
> 用途：ART-RIG-001 的 2D 骨骼方案验证，只给 `scenes/dev/rig001_verify.tscn` 用。

## 这里是什么

- `layers/*.png` — 16 张 128×176 分层图，由 `tools/make_rig001_layers.py`
  从 `assets/characters/ART_CHAR_001_r02_walk_right_00_contactA.png` **按骨轴几何切出来**的，
  不是美术绘制的成品分层，被遮挡处用的是相邻像素近似色。
- `rig001_spec.json` — 骨骼树 / 关节坐标 / 图层路径 / 绘制顺序 / 步态参数的唯一来源。
  换正式素材时改这个文件即可，不用重建骨骼、不用重写动画。
- `diagnostics/` — 区域归属图与逐层"需补绘"掩码（带 `.gdignore`，不进引擎、不进导出包）。

## 这里不是什么

- **不是正式美术资产**：不登记 `素材库/素材台账.csv`，不进 `tools/check_artlib_page.mjs` 的运行时白名单，
  不在 `assets/characters/` 下，不替换任何已批准的动画（r09 扶车十六帧保持默认）。
- 隔离状态由 `python tools/make_rig001_layers.py` 结尾的「隔离检查」每次校验。

## 删除方式

整个目录 + `scenes/dev/rig001_verify.tscn` + `scripts/dev/rig001_verify.gd` + `scripts/rig/` + `tools/make_rig001_*.py`
一起删掉即可完全回滚，不会影响正式游戏（`SceneRouter` 里只多一个 dev key `rig001`）。
