# ART-INTEGRATE-005E · r09 修复成品留档

- 来源包：`转存库/ART-ANIM-005E_r09_修复成品.zip`（SHA-256 `4fb3e85f25a4038288712a674723df6f29c36b7a191407081358beb76525668a`）
- 解包日期：2026-11-09，由 `python tools/import_art005e_archive.py` 生成，**只复制不移动不删除**。
- 状态：**待审核 / 引擎试用**。工程侧已接入验证，但未经总监裁定，不进入「运行时可用」白名单。
- 本目录在 `转存库/` 下，受根目录 `.gdignore` 隔离，**不参与 Godot 导入、不进 PCK**。
- `previews/` 里的 GIF / 对照图仅供人眼复核，禁止当作运行时贴图或写进 `assets/`。

## 目录

```
runtime/    ART_CHAR_001_r09_push_idle_right_128x176.png
            ART_CHAR_001_r09_push_walk_00..15_128x176.png
previews/   固定地面 10FPS GIF、16 帧板、修复前后对照、8 检查点、接地放大
ART-ANIM-005E_r09_交付报告.md     美术侧自检结论
ART-INTEGRATE-005E_交接提示词.md  工程 Agent 任务书（用户确认美术后生效）
QA_FRAME_SHA256.txt               17 张成品逐文件哈希
```

## 冻结边界

960×540 / 角色画布 128×176 / 锚点 (64,168) / 碰撞 28×160 / 车 128×112 锚点 (64,104) /
车长 96 / `side_offset=80` / 推 80 / 拉 40 / `Back→Cargo→Player→Front` 分层 —— 一个都不改。
只交付朝右推车前进；朝左独立帧、反向拉车动作、车轮滚动不在本批。
