# tools/video · AI 视频接入工具

**这里不生成视频。** 用户自己用 AI 生成，本目录只把视频变成能进 Godot 的帧序列。

完整规范见 [`docs/AI视频转Godot动画接入规范.md`](../../docs/AI视频转Godot动画接入规范.md)。

## 文件

| 文件 | 作用 |
|---|---|
| `pipeline.py` | 六步管线：probe / extract / matte / analyze / align / build，支持 `all` 串起来 |
| `selftest.py` | 合成一段测试片跑完整链路，断言产物，然后删掉临时批次 |

## 最快上手

```bash
# 1. 先确认这条链路在本机是通的（不碰任何真实素材）
python tools/video/selftest.py

# 2. 有真实视频之后
python tools/video/pipeline.py probe 转存库/ART_CHAR_001_walk_right_source.mp4
python tools/video/pipeline.py all   转存库/ART_CHAR_001_walk_right_source.mp4 \
    --batch walk_right --action walk --fps 10 --speed 100

# 3. 引擎里看
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path ../.. -- \
    --dev-scene=video --video-dir=walk_right --video-fps=10 --video-test
```

## 依赖

- `ffmpeg` / `ffprobe`（PATH 里，`probe` 与 `extract` 用）
- Python：`Pillow`、`numpy`

## 产物位置

`assets/dev/video_candidates/<batch>/`：

```
frames_raw/    原始帧（带背景）
frames_matte/  抠像后 RGBA
frames_out/    128×176 / 脚底 (64,168) 的成品帧 ← 引擎读这个
preview/       contact_sheet.png（一行 8 帧的接触表）+ loop.gif
meta.json      参数与体检结论
```

这个目录是隔离区：**不进 assets/characters/、不改 SpriteFrames、不改台账**。
转正流程见规范 §6。
