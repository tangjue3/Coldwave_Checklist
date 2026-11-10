extends Node2D
## VIDEO-PREVIEW · AI 视频抽帧候选的独立预览与体检场景（TASK-ARTLIB-CLEAN-001 建立）
##
## 用途：用户把 AI 生成的视频交给开发 Agent，抽帧 / 抠像 / 对齐后的 PNG 序列先落到
## `assets/dev/video_candidates/<动作名>/`，用本场景在**真实 Godot 里**看一遍再谈接入。
## 本场景**不参与正式玩法**，不替换任何现有动画，不改台账、不改白名单。
##
## 命令行（写在 `--` 之后，须带 --dev-scene=video）：
##   --video-dir=walk_right      候选目录名（assets/dev/video_candidates/ 下）
##   --video-fps=10              播放帧率；不填读该目录的 meta.json，再不行默认 10
##   --video-zoom=1|2|4          放大倍数（Nearest，不插值）
##   --video-speed=100           按该速度（px/s）让角色在地面刻度上真实移动，用于看滑步
##   --video-test                体检用例：帧尺寸 / alpha / 脚底行 / 重复帧 / 形变 / 步幅，跑完退出
##   --video-tour                出检查点截图（原生 / 2x / 4x / 地面刻度 / 移动连拍）
##   --shot=name.png             单张截图
##   --quit                      完成后退出
##
## 为什么不做成「直接吃 mp4」：Godot 里解视频需要额外插件，而抽帧 / 抠像本来就该在
## Python 侧一次做干净（tools/video/pipeline.py）。引擎只负责**验收**，这才是可复现的分工。

const VIEW := Vector2(960, 540)
const GROUND_Y := 416.0
const FRAME_W := 128
const FRAME_H := 176
const ANCHOR := Vector2(64, 168)
const SHOT_DIR := "res://tests/screenshots"
const CAND_ROOT := "res://assets/dev/video_candidates"
const FONT_PATH := "res://assets/ui/fonts/NotoSansSC-Variable.ttf"

const C_BG := Color(0.30, 0.28, 0.26)
const C_FLOOR := Color(0.50, 0.42, 0.33)
const C_TICK := Color(0.62, 0.55, 0.44)
const C_ANCHOR := Color(0.95, 0.42, 0.35)
const C_INK := Color(0.95, 0.96, 0.97)
const C_WARN := Color(0.94, 0.72, 0.32)

var _args: Dictionary = {}
var _font: Font
var _sprite: Sprite2D
var _frames: PackedStringArray = PackedStringArray()
var _images: Array[Image] = []
var _tex: Array[ImageTexture] = []
var _fps: float = 10.0
var _zoom: int = 1
var _speed: float = 100.0
var _playing := true
var _t := 0.0
var _frame_i := 0
var _moving := false
var _world_x := 0.0
var _caption := ""
var _fail := 0
var _frame_sub := ""


func _ready() -> void:
	_parse_args()
	_font = load(FONT_PATH)
	if _font == null:
		_font = ThemeDB.fallback_font

	var dir_name := String(_args.get("video_dir", ""))
	if dir_name == "":
		dir_name = _first_candidate()
	if dir_name == "":
		print("[VIDEO] 没有任何候选目录。把抽好的 PNG 序列放到 %s/<动作名>/ 再开本场景。" % CAND_ROOT)
		if _args.has("quit"):
			get_tree().quit(0)
		return

	# 成品帧优先读 <batch>/frames_out/（管线的输出）；没有就直接读 <batch>/（手工丢帧也支持）
	_frame_sub = "frames_out" if _pick_sub(dir_name, "frames_out") != "" else ""
	var dir_path := "%s/%s/%s" % [CAND_ROOT, dir_name, _frame_sub]
	_fps = float(_args.get("video_fps", _read_meta_fps(dir_name, 10.0)))
	_zoom = int(_args.get("video_zoom", 1))
	_speed = float(_args.get("video_speed", 100.0))
	_frames = _list_png(dir_name, _frame_sub)
	if _frames.size() == 0:
		print("[VIDEO] %s 里没有 PNG。管线应输出到 frames_out/；手工丢帧就直接放在批次目录根下。" % dir_path)
		if _args.has("video_test") or _args.has("quit"):
			get_tree().quit(1)
		return

	_images = _load_images(dir_name, _frames)
	_build_sprite()
	_caption = "%s · %d 帧 · %.1f FPS · %dx" % [dir_name, _frames.size(), _fps, _zoom]

	print("[VIDEO] 候选目录=%s 帧数=%d FPS=%.1f 缩放=%dx 速度=%.0f px/s" % [
		dir_name, _frames.size(), _fps, _zoom, _speed])

	if _args.has("video_test"):
		await _run_tests(dir_name)
	elif _args.has("video_tour"):
		await _run_tour()
	elif _args.has("shot"):
		await _settle()
		_capture(String(_args["shot"]))
		if _args.has("quit"):
			get_tree().quit(0)
	elif _args.has("quit"):
		await _settle()
		get_tree().quit(0)


func _process(delta: float) -> void:
	if _sprite == null or not _playing or _frames.size() < 2:
		return
	_t += delta
	var step: float = 1.0 / maxf(0.001, _fps)
	while _t >= step:
		_t -= step
		_frame_i = (_frame_i + 1) % _frames.size()
		_sprite.texture = _tex[_frame_i]
	if _moving:
		_world_x += _speed * delta
		_sprite.position.x = 320.0 - ANCHOR.x * _zoom + fmod(_world_x, 320.0) - 160.0
	queue_redraw()


## 放大后画面装不下 176px 画布，把地面线往下挪，保证**脚底始终可见**（头部允许被裁）
func _ground_y() -> float:
	var need := float(FRAME_H) * _zoom
	if need <= VIEW.y - 100.0:
		return GROUND_Y
	return VIEW.y - 24.0


func _anchor_pos() -> Vector2:
	return Vector2(320.0, _ground_y())


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), C_BG, true)
	var gy := _ground_y()
	var floor_top := gy - 56.0
	draw_rect(Rect2(0, floor_top, VIEW.x, VIEW.y - floor_top), C_FLOOR, true)
	draw_line(Vector2(0, gy), Vector2(VIEW.x, gy), C_TICK, 2.0)
	# 32px 地面刻度：滑步就是「脚跟着刻度走，但每帧位移对不上」
	var offset := int(_world_x) % 32
	var x := -offset
	while x < int(VIEW.x) + 32:
		draw_line(Vector2(x, floor_top), Vector2(x, gy), C_TICK.darkened(0.15), 1.0)
		x += 32
	if _sprite != null:
		# 锚点十字：画在脚底锚点的**世界坐标**上，不看 sprite 内部偏移
		var base := _anchor_pos()
		draw_line(base + Vector2(-10, 0), base + Vector2(10, 0), C_ANCHOR, 2.0)
		draw_line(base + Vector2(0, -10), base + Vector2(0, 10), C_ANCHOR, 2.0)

	var title := _caption if _caption != "" else "无候选"
	draw_string(_font, Vector2(24, 34), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, C_INK)
	var sub := "空格 播放/暂停　1/2/3 切换缩放　M 移动演示　←/→ 逐帧"
	draw_string(_font, Vector2(24, 58), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_WARN)


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed:
		return
	match k.keycode:
		KEY_SPACE:
			_playing = not _playing
		KEY_1:
			_set_zoom(1)
		KEY_2:
			_set_zoom(2)
		KEY_3:
			_set_zoom(3)
		KEY_M:
			_moving = not _moving
			_world_x = 0.0
			if not _moving:
				_sprite.position.x = 320.0 - ANCHOR.x * _zoom
			_playing = _moving or _playing
		KEY_LEFT:
			_playing = false
			_frame_i = (_frame_i - 1 + _frames.size()) % _frames.size()
			_sprite.texture = _tex[_frame_i]
		KEY_RIGHT:
			_playing = false
			_frame_i = (_frame_i + 1) % _frames.size()
			_sprite.texture = _tex[_frame_i]


func _set_zoom(z: int) -> void:
	_zoom = z
	if _sprite != null:
		_sprite.scale = Vector2(z, z)
		_sprite.position = Vector2(320.0 - ANCHOR.x * z, _ground_y() - ANCHOR.y * z)
	_caption = _caption.split(" · ")[0] + " · %d 帧 · %.1f FPS · %dx" % [_frames.size(), _fps, z]
	queue_redraw()


# ---------------------------------------------------------------- 构建

func _build_sprite() -> void:
	_tex.clear()
	for img in _images:
		_tex.append(ImageTexture.create_from_image(img))
	_sprite = Sprite2D.new()
	_sprite.name = "Candidate"
	_sprite.texture = _tex[0]
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(_zoom, _zoom)
	# Sprite2D 关掉 centered 后，position 就是纹理左上角；
	# 脚底锚点 (64,168) 要落在地面线上 → position.y = ground - 168*z，position.x = 320 - 64*z
	_sprite.position = Vector2(320.0 - ANCHOR.x * _zoom, _ground_y() - ANCHOR.y * _zoom)
	add_child(_sprite)


func _base_abs() -> String:
	# 帧文件不需要 Godot 导入：直接走文件系统绝对路径，省掉 --import 这一步
	return ProjectSettings.globalize_path(CAND_ROOT)


func _pick_sub(dir_name: String, sub: String) -> String:
	var abs := "%s/%s/%s" % [_base_abs(), dir_name, sub]
	return sub if DirAccess.dir_exists_absolute(abs) else ""


func _list_png(dir_name: String, sub: String) -> PackedStringArray:
	var out := PackedStringArray()
	var rel := dir_name if sub == "" else "%s/%s" % [dir_name, sub]
	var d := DirAccess.open("%s/%s" % [_base_abs(), rel])
	if d == null:
		return out
	for f in d.get_files():
		var low := f.to_lower()
		if low.ends_with(".png"):
			out.append(f)
	out.sort()
	return out


func _load_images(dir_name: String, names: PackedStringArray) -> Array[Image]:
	var out: Array[Image] = []
	var rel := dir_name if _frame_sub == "" else "%s/%s" % [dir_name, _frame_sub]
	var base := "%s/%s" % [_base_abs(), rel]
	for n in names:
		var abs_path := "%s/%s" % [base, n]
		if not FileAccess.file_exists(abs_path):
			push_warning("[VIDEO] 帧不存在：%s" % abs_path)
			continue
		var img := Image.load_from_file(abs_path)
		if img == null:
			push_warning("[VIDEO] 帧读取失败：%s" % abs_path)
			continue
		if img.is_compressed():
			img.decompress()
		out.append(img)
	return out


func _first_candidate() -> String:
	var d := DirAccess.open(_base_abs())
	if d == null:
		return ""
	var subs := d.get_directories()
	subs.sort()
	return subs[0] if subs.size() > 0 else ""


func _read_meta_fps(dir_name: String, fallback: float) -> float:
	var p := "%s/%s/meta.json" % [_base_abs(), dir_name]
	if not FileAccess.file_exists(p):
		return fallback
	var txt := FileAccess.get_file_as_string(p)
	var data = JSON.parse_string(txt)
	if typeof(data) == TYPE_DICTIONARY and data.has("fps"):
		return float(data["fps"])
	return fallback


# ---------------------------------------------------------------- 体检

func _run_tests(dir_name: String) -> void:
	await get_tree().process_frame
	var f := 0
	f += _ok(_frames.size() >= 2, "帧数 ≥ 2（当前 %d）" % _frames.size())

	var bad_size := 0
	var no_alpha := 0
	for img in _images:
		if img.get_width() != FRAME_W or img.get_height() != FRAME_H:
			bad_size += 1
		if img.detect_alpha() == Image.ALPHA_NONE:
			no_alpha += 1
	f += _ok(bad_size == 0, "全部帧为 %dx%d（不合规 %d 张）" % [FRAME_W, FRAME_H, bad_size])
	f += _ok(no_alpha == 0, "全部帧带透明通道（无 alpha %d 张）" % no_alpha)

	# 脚底行：每帧最下方不透明像素的 y，应稳定在 ANCHOR.y 附近
	var foot_lo := 9999
	var foot_hi := -1
	for img in _images:
		var row := _bottom_row(img)
		if row < 0:
			continue
		foot_lo = min(foot_lo, row)
		foot_hi = max(foot_hi, row)
	f += _ok(foot_hi >= 0, "能量到脚底行")
	f += _ok(abs(foot_hi - int(ANCHOR.y)) <= 2, "脚底行贴合锚点 y=%d（实测 %d）" % [int(ANCHOR.y), foot_hi])
	f += _ok(foot_hi - foot_lo <= 2, "脚底行波动 ≤2px（实测 %d–%d）" % [foot_lo, foot_hi])

	# 重复帧：相邻帧完全相同说明抽帧重复或视频静止
	var dup := 0
	for i in range(1, _images.size()):
		if _images[i].get_data() == _images[i - 1].get_data():
			dup += 1
	f += _ok(dup == 0, "相邻帧无完全重复（重复 %d 对）" % dup)

	# 形变：包围盒高度 / 宽度波动，超出 12% 视为人物比例漂移
	var hs: Array[float] = []
	var ws: Array[float] = []
	for img in _images:
		var r := _bbox(img)
		if r.size.x > 0:
			ws.append(r.size.x)
			hs.append(r.size.y)
	if hs.size() > 1:
		var h_var: float = (hs.max() - hs.min()) / maxf(1.0, hs.max())
		var w_var: float = (ws.max() - ws.min()) / maxf(1.0, ws.max())
		# 高度是「人物比例漂移」的可靠代理；宽度会随手脚摆动天然变大变小，
		# 所以宽度只做记录 + 极宽松兜底（>60% 才判失败），不拿它当硬门槛。
		f += _ok(h_var <= 0.12, "包围盒高度波动 ≤12%%（实测 %.1f%%）" % (h_var * 100.0))
		f += _ok(w_var <= 0.60, "包围盒宽度波动 ≤60%%（实测 %.1f%%，推车时手臂伸展属正常）" % (w_var * 100.0))

	# 循环时长与建议速度
	var loop_s: float = float(_frames.size()) / maxf(0.001, _fps)
	print("[VIDEO][INFO] 一循环 = %d 帧 / %.1f FPS = %.2f s；按 %.0f px/s 一个循环该走 %.1f px" % [
		_frames.size(), _fps, loop_s, _speed, _speed * loop_s])
	print("[VIDEO][INFO] 逐帧位移应为 %.2f px；若视频里脚掌每循环的位移不是这个数，就会滑步" % [
		_speed * loop_s / float(_frames.size())])

	print("[VIDEO] 体检结果：%d 项失败（候选 %s）" % [f, dir_name])
	if not OS.has_feature("web"):
		get_tree().quit(0 if f == 0 else 1)


func _ok(cond: bool, msg: String) -> int:
	print("[VIDEO][%s] %s" % ["PASS" if cond else "FAIL", msg])
	return 0 if cond else 1


func _bottom_row(img: Image) -> int:
	for y in range(img.get_height() - 1, -1, -1):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.08:
				return y
	return -1


func _bbox(img: Image) -> Rect2i:
	var minx := 9999
	var miny := 9999
	var maxx := -1
	var maxy := -1
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.08:
				minx = min(minx, x)
				maxx = max(maxx, x)
				miny = min(miny, y)
				maxy = max(maxy, y)
	if maxx < 0:
		return Rect2i()
	return Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)


# ---------------------------------------------------------------- 截图

func _run_tour() -> void:
	await _settle()
	_capture("video_1x.png")
	_set_zoom(2)
	await get_tree().process_frame
	_capture("video_2x.png")
	_set_zoom(3)
	await get_tree().process_frame
	_capture("video_3x.png")
	_set_zoom(1)
	_moving = true
	_playing = true
	_world_x = 0.0
	for i in 8:
		for j in 4:
			await get_tree().process_frame
		_capture("video_move_%02d.png" % i)
	_moving = false
	_sprite.position.x = 320.0 - ANCHOR.x * _zoom
	print("[VIDEO] 检查点截图完成")
	if not OS.has_feature("web"):
		get_tree().quit(0)


func _settle() -> void:
	for i in 6:
		await get_tree().process_frame


func _capture(filename: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	var err := get_viewport().get_texture().get_image().save_png("%s/%s" % [SHOT_DIR, filename])
	if err != OK:
		push_warning("[VIDEO] 截图失败 %s err=%d" % [filename, err])


func _parse_args() -> void:
	for k in SceneRouter.dev_args:
		_args[k] = SceneRouter.dev_args[k]
	for raw in OS.get_cmdline_user_args():
		var a: String = raw
		if not a.begins_with("--"):
			continue
		var kv := a.substr(2).split("=", true, 1)
		_args[kv[0].replace("-", "_")] = kv[1] if kv.size() > 1 else true
	if _args.has("video_state"):
		var st := String(_args["video_state"])
		if st == "test":
			_args["video_test"] = true
		elif st == "tour":
			_args["video_tour"] = true
