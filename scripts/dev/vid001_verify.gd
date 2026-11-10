extends Node2D
## VID-001-VERIFY · VIDEO-INTEGRATE-001 候选动画的独立测试场景
##
## 用的是**真实的 PlayerController**（不是拿 PNG 摆一个假精灵），因此这里量到的
## 移动 / 停止 / 镜像 / 推车状态就是游戏里的真实行为。
##
## 命令行（写在 `--` 之后，须带 --dev-scene=vid001）：
##   --vid001-test    跑 20 项真实断言，失败数写进退出码
##   --vid001-tour    出检查点截图（待机 1x / 行走 1x / 3x 放大 / 镜像 / 停止过渡 / 推车）
##   --vid001-movie   逐帧录「走→停→再走→镜像向左」演示，输出 PNG 序列供 ffmpeg 合成
##   --quit           跑完退出
##   不带参数       交互模式（方向键控制，空格暂停）
##
## 本场景不参与正式玩法，不改台账、不改白名单；资源状态是**候选 / 待美术审核**。

const VIEW := Vector2(960, 540)
const GROUND_Y := 416.0
# VIDEO-QUALITY-002：贴图 512×704（上一轮 128×176 的严格 4×），
# 由 player.tscn 的 scale=0.25 缩回同样的显示大小。
const TEX_W := 512
const TEX_H := 704
const ANCHOR := Vector2(256, 672)     # 贴图内的脚底锚点
const ANCHOR_Y := 672
const FOOT_TOL := 8                   # 4× 于上一轮的 ±2
const ZOOM_W := 256                   # 放大镜：高清源 0.5× = 游戏显示尺寸的 2×
const ZOOM_H := 352
const SHOT_DIR := "res://tests/screenshots"
const MOVIE_DIR := "res://tests/screenshots/vid001_movie"
const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const FONT_PATH := "res://assets/ui/fonts/NotoSansSC-Variable.ttf"

const C_BG := Color(0.196, 0.216, 0.239)
const C_FLOOR := Color(0.33, 0.36, 0.39)
const C_TICK := Color(0.52, 0.56, 0.60)
const C_ANCHOR := Color(0.95, 0.42, 0.35)
const C_INK := Color(0.94, 0.95, 0.96)
const C_MUTED := Color(0.68, 0.72, 0.76)
const C_OK := Color(0.45, 0.82, 0.55)
const C_BAD := Color(0.95, 0.45, 0.40)

var _args: Dictionary = {}
var _font: Font
var _player: PlayerController
var _zoom_sprite: Sprite2D
var _fails := 0
var _checks := 0
var _caption := "VIDEO-INTEGRATE-001  candidate / pending art review"
var _test_lines: Array[String] = []
var _t := 0.0
var _movie := false
var _movie_next := 0.0
var _movie_i := 0
var _movie_end := 7.0
var _input_dir := 0.0
var _paused := false

# 演示时间轴：[开始秒, 结束秒, 输入方向, 画面说明]
const TIMELINE: Array = [
	[0.0, 1.5, 1.0, "walk right  (100 px/s)"],
	[1.5, 2.5, 0.0, "release -> idle / walk_to_idle"],
	[2.5, 4.0, 1.0, "walk right again"],
	[4.0, 4.8, 0.0, "stop"],
	[4.8, 6.3, -1.0, "walk left (flip_h mirror)"],
	[6.3, 7.0, 0.0, "stop"],
]


func _ready() -> void:
	_parse_args()
	_font = load(FONT_PATH)
	if _font == null:
		_font = ThemeDB.fallback_font

	_player = PLAYER_SCENE.instantiate() as PlayerController
	_player.ground_y = GROUND_Y
	_player.input_enabled = false
	_player.position = Vector2(240.0, GROUND_Y)
	add_child(_player)

	_zoom_sprite = Sprite2D.new()
	_zoom_sprite.name = "HDDetail"
	_zoom_sprite.centered = false
	_zoom_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_zoom_sprite.scale = Vector2(0.5, 0.5)
	_zoom_sprite.position = Vector2(694.0, 58.0)
	add_child(_zoom_sprite)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	if _args.has("vid001_test"):
		await _run_tests()
	elif _args.has("vid001_hires"):
		await _run_hires()
	elif _args.has("vid001_tour"):
		await _run_tour()
	elif _args.has("vid001_movie"):
		_movie = true
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MOVIE_DIR))
		_caption = "movie: recording Godot frames"
	else:
		_player.input_enabled = true
		_caption = "interactive: arrows to move, space to pause"


func _parse_args() -> void:
	for k in SceneRouter.dev_args:
		_args[k] = SceneRouter.dev_args[k]
	for raw in OS.get_cmdline_user_args():
		var a: String = raw
		if not a.begins_with("--"):
			continue
		var kv := a.substr(2).split("=", true, 1)
		_args[kv[0].replace("-", "_")] = kv[1] if kv.size() > 1 else true


func _process(delta: float) -> void:
	if _paused:
		return
	if _movie:
		_t += delta
		_input_dir = 0.0
		for seg in TIMELINE:
			if _t >= float(seg[0]) and _t < float(seg[1]):
				_input_dir = float(seg[2])
				_caption = String(seg[3])
				break
		_player.set_input_override(_input_dir)
		if _t >= _movie_next:
			_movie_next = _t + 1.0 / 20.0
			_capture("vid001_movie/f_%04d.png" % _movie_i)
			_movie_i += 1
		if _t >= _movie_end:
			print("[VID001] movie frames = %d" % _movie_i)
			_capture("vid001_movie_end.png")
			get_tree().quit(0)
			return
	_update_zoom()
	queue_redraw()


func _update_zoom() -> void:
	if _player == null or not _player.has_visual():
		return
	var spr := _player.get_node("Sprite") as AnimatedSprite2D
	if spr == null or spr.sprite_frames == null:
		return
	var tex := spr.sprite_frames.get_frame_texture(spr.animation, spr.frame)
	if tex != null:
		_zoom_sprite.texture = tex


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), C_BG, true)
	var floor_top := GROUND_Y - 48.0
	draw_rect(Rect2(0, GROUND_Y, VIEW.x, VIEW.y - GROUND_Y), C_FLOOR, true)
	draw_line(Vector2(0, GROUND_Y), Vector2(VIEW.x, GROUND_Y), C_TICK, 2.0)
	var x: float = 0.0
	while x <= VIEW.x:
		draw_line(Vector2(x, floor_top), Vector2(x, GROUND_Y), C_TICK.darkened(0.25), 1.0)
		x += 32.0
	# 脚底锚点十字（真实世界坐标）
	var anchor := _player.position
	draw_line(anchor + Vector2(-10, 0), anchor + Vector2(10, 0), C_ANCHOR, 2.0)
	draw_line(anchor + Vector2(0, -10), anchor + Vector2(0, 10), C_ANCHOR, 2.0)

	_text(20, 28, "VIDEO-INTEGRATE-001  /  candidate walk-right animation", 17, C_INK)
	_text(20, 50, _caption, 13, C_MUTED)
	var spr := _player.get_node("Sprite") as AnimatedSprite2D
	if spr != null:
		_text(20, 74, "state=%s  anim=%s  frame=%d/%d  fps=%.0f  x=%.0f  facing=%s  flip=%s" % [
			String(_player.state), String(_player.current_anim()), spr.frame,
			_player.anim_frame_count(), _player.anim_fps(), _player.position.x,
			"R" if _player.facing > 0 else "L", str(spr.flip_h)], 12, C_MUTED)
	_text(20, 94, "move_speed=100 px/s   ground_y=416   texture 512x704 @0.25   anchor (256,672)   Linear",
		11, C_MUTED)

	# 放大镜框：高清源按 0.5 显示 → 256x352，等于游戏显示尺寸的 2×
	draw_rect(Rect2(684, 48, ZOOM_W + 20, ZOOM_H + 20), C_TICK, false, 1.0)
	_text(684, 40, "HD source 0.5x = 2x game size (detail check)", 12, C_MUTED)
	if not _test_lines.is_empty():
		var y: float = 120.0
		for line in _test_lines:
			_text(20, y, line, 11, C_OK if line.begins_with("[PASS]") else C_BAD)
			y += 15.0


func _text(x: float, y: float, s: String, size: int, col: Color) -> void:
	draw_string(_font, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _capture(filename: String) -> void:
	var err := get_viewport().get_texture().get_image().save_png("%s/%s" % [SHOT_DIR, filename])
	if err != OK:
		push_warning("[VID001] 截图失败 %s err=%d" % [filename, err])


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _ok(cond: bool, msg: String, detail: String = "") -> void:
	_checks += 1
	if not cond:
		_fails += 1
	var line := "[%s] %s%s" % ["PASS" if cond else "FAIL", msg,
		("  → " + detail) if detail != "" else ""]
	_test_lines.append(line)
	print("[VID001] " + line)


# ---------------------------------------------------------------- 真实测试
func _run_tests() -> void:
	print("[VID001] ==== 新角色动画真实测试（不是旧 r09 测试的沿用）====")
	var spr := _player.get_node("Sprite") as AnimatedSprite2D
	var sf := spr.sprite_frames

	_ok(_player.has_visual(), "has_visual() = true（角色渲染已恢复）")
	_ok(sf != null, "player.tscn 挂上了 SpriteFrames")
	if sf == null:
		_finish()
		return
	var names := sf.get_animation_names()
	_ok(names.has(&"idle_right") and names.has(&"walk_right") and names.has(&"walk_to_idle"),
		"三段动画齐全：idle_right / walk_right / walk_to_idle", ", ".join(PackedStringArray(names)))
	_ok(sf.get_frame_count(&"walk_right") == 36, "walk_right = 36 帧",
		str(sf.get_frame_count(&"walk_right")))
	_ok(sf.get_frame_count(&"walk_to_idle") == 21, "walk_to_idle = 21 帧",
		str(sf.get_frame_count(&"walk_to_idle")))
	_ok(sf.get_frame_count(&"idle_right") == 1, "idle_right = 1 帧（视频后段实测冻结）")
	_ok(absf(sf.get_animation_speed(&"walk_right") - 24.0) < 0.01,
		"walk_right = 24 FPS", str(sf.get_animation_speed(&"walk_right")))
	_ok(absf(sf.get_animation_speed(&"walk_to_idle") - 24.0) < 0.01,
		"walk_to_idle = 24 FPS")
	_ok(sf.get_animation_loop(&"walk_right") and not sf.get_animation_loop(&"walk_to_idle"),
		"walk 循环 / 停止过渡不循环")

	# 逐帧检查：尺寸、脚底、绿色残留（真实读纹理像素，不靠文件名推断）
	var bad_size := 0
	var bad_foot := 0
	var green_px := 0
	var foot_rows: Array[int] = []
	for anim in names:
		for i in range(sf.get_frame_count(anim)):
			var tex := sf.get_frame_texture(anim, i)
			if tex == null:
				bad_size += 1
				continue
			if tex.get_size() != Vector2(TEX_W, TEX_H):
				bad_size += 1
				continue
			var img := tex.get_image()
			if img.is_compressed():
				img.decompress()
			if img.get_format() != Image.FORMAT_RGBA8:
				img.convert(Image.FORMAT_RGBA8)
			var w := img.get_width()
			var h := img.get_height()
			var data := img.get_data()      # RGBA8，一次性读出来，别用百万次 get_pixel
			var stride := w * 4
			var bottom := -1
			for y in range(h):
				var row_has := false
				var base := y * stride
				# 512×704×58 帧逐像素太慢，按 4 像素步长采样做质量断言
				for px in range(0, w, 4):
					var o := base + px * 4
					if data[o + 3] < 10:
						continue
					row_has = true
					var rv := float(data[o])
					var gv := float(data[o + 1])
					var bv := float(data[o + 2])
					if gv - maxf(rv, bv) > 50.0:
						green_px += 1
				if row_has:
					bottom = y
			foot_rows.append(bottom)
			if absi(bottom - ANCHOR_Y) > FOOT_TOL:
				bad_foot += 1
	_ok(bad_size == 0, "全部 58 帧尺寸 512×704", "异常 %d" % bad_size)
	_ok(bad_foot == 0, "全部帧脚底落在 y=672±8（等价 1x 的 ±2）", "异常 %d，范围 %d–%d" % [
		bad_foot, foot_rows.min(), foot_rows.max()])
	_ok(green_px == 0, "透明 PNG 里没有绿色残留像素", "%d px" % green_px)

	# 待机稳定
	_player.set_input_override(0.0)
	await _frames(20)
	_ok(_player.state == PlayerController.STATE_IDLE, "静止输入 → state=idle")
	_ok(_player.current_anim() == PlayerController.ANIM_IDLE, "静止 → idle_right")
	var idle_f := spr.frame
	await _frames(24)
	_ok(spr.frame == idle_f, "待机不抖动（单帧不漂移）")

	# 行走
	var x0 := _player.position.x
	_player.set_input_override(1.0)
	await _frames(30)
	_ok(_player.state == PlayerController.STATE_WALK, "输入 +1 → state=walk")
	_ok(_player.current_anim() == PlayerController.ANIM_WALK, "行走 → walk_right")
	var f0 := spr.frame
	await _frames(12)
	_ok(spr.frame != f0, "行走动画帧真的在推进", "%d → %d" % [f0, spr.frame])
	var dx := _player.position.x - x0
	_ok(dx > 30.0, "角色按 100px/s 真实前进", "本次采样位移 %.1f px" % dx)
	_ok(absf(_player.position.y - GROUND_Y) < 0.01, "脚底始终贴地 ground_y")

	# 停止
	_player.set_input_override(0.0)
	await _frames(90)
	var stopped_anim := String(_player.current_anim())
	_ok(stopped_anim != "walk_right", "松手后不再停在 walk_right", stopped_anim)
	_ok(_player.current_anim() == PlayerController.ANIM_IDLE,
		"过渡播完自动回到 idle_right", stopped_anim)
	_ok(not _player.in_stop_transition(), "过渡状态已清理")

	# 再起步（验证 walk → stop → walk 不卡死）
	_player.set_input_override(1.0)
	await _frames(18)
	_ok(_player.current_anim() == PlayerController.ANIM_WALK, "重新起步 → walk_right")
	_player.set_input_override(0.0)
	await _frames(90)

	# 停止过渡确实存在且能播完（强制一次，验证资源与信号链）
	_player.force_stop_transition()
	await _frames(2)
	_ok(_player.current_anim() == PlayerController.ANIM_STOP, "walk_to_idle 可播放")
	await _frames(70)
	_ok(_player.current_anim() == PlayerController.ANIM_IDLE, "过渡播完 → idle_right")

	# 镜像
	var cx := _player.position.x
	var cw := _player.collision_width()
	_player.set_facing(-1)
	_ok(spr.flip_h, "朝左 flip_h=true（镜像只改绘制）")
	_ok(_player.collision_width() == cw and absf(_player.position.x - cx) < 0.01,
		"镜像不碰碰撞盒与世界坐标")
	_player.set_facing(1)

	# 推车：VIDEO-INTEGRATE-001 时期没有推车动画，原断言要求「固定站姿」。
	# VIDEO-INTEGRATE-002 已接入三段专用推车候选动画，这里改为验证
	# 「进入推车切 push_idle_right、退出回到普通动画，且 r10–r12 帧数不变」。
	# 旧断言不是被删除，而是被真实的新状态验证取代。
	_player.set_push_pose(true)
	await _frames(4)
	_ok(_player.current_anim() == PlayerController.ANIM_PUSH_IDLE,
		"绑定推车切专用 push_idle_right，不拿 walk_right 冒充",
		String(_player.current_anim()))
	_player.set_push_moving(true)
	await _frames(4)
	_ok(_player.current_anim() == PlayerController.ANIM_PUSH_WALK,
		"推车行走切 push_walk_right", String(_player.current_anim()))
	_player.set_push_moving(false)
	_player.set_push_pose(false)
	await _frames(4)
	_ok(_player.current_anim() == PlayerController.ANIM_IDLE
		or _player.current_anim() == PlayerController.ANIM_WALK,
		"解除推车回到普通动画，不残留推车帧", String(_player.current_anim()))
	_ok(sf.get_frame_count(&"walk_right") == 36
		and sf.get_frame_count(&"walk_to_idle") == 21
		and sf.get_frame_count(&"idle_right") == 1,
		"r10/r11/r12 三段帧数在推车动画加入后仍保持不变")

	_finish()


func _finish() -> void:
	_caption = "TEST  %d checks / %d failed" % [_checks, _fails]
	_test_lines.append("[%s] 合计 %d 项，失败 %d 项" %
		["PASS" if _fails == 0 else "FAIL", _checks, _fails])
	queue_redraw()
	await _frames(2)
	_capture("vid001_test.png")
	if _args.has("quit") or _args.has("vid001_test"):
		get_tree().quit(1 if _fails > 0 else 0)


# ---------------------------------------------------------------- 高 DPI 实机验证
func _run_hires() -> void:
	# 把窗口开到 1920×1080（960×540 的 2× 整数倍），用来验证
	# stretch/mode=canvas_items 下高清贴图是否真的多出细节。
	get_window().size = Vector2i(1920, 1080)
	await _frames(8)
	print("[VID001] hires window=%s viewport_tex=%s stretch=%s" % [
		str(get_window().size), str(get_viewport().get_texture().get_size()),
		"canvas_items" if ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items"
		else "viewport"])
	_player.set_input_override(1.0)
	await _frames(40)
	_caption = "hires 2x window: walk_right 36f / 24FPS"
	queue_redraw()
	await _frames(2)
	_capture("vid001_hires_walk.png")
	_player.set_input_override(0.0)
	await _frames(100)
	_caption = "hires 2x window: idle_right"
	queue_redraw()
	await _frames(2)
	_capture("vid001_hires_idle.png")
	get_tree().quit(0)


# ---------------------------------------------------------------- 检查点截图
func _run_tour() -> void:
	_player.set_input_override(0.0)
	await _frames(6)
	_caption = "checkpoint 1: idle_right  (1 frame, stable)"
	queue_redraw(); await _frames(2); _capture("vid001_idle_1x.png")

	_player.set_input_override(1.0)
	await _frames(40)
	_caption = "checkpoint 2: walk_right  (36 frames / 24 FPS)"
	queue_redraw(); await _frames(2); _capture("vid001_walk_1x.png")

	_player.set_facing(-1)
	_player.set_input_override(-1.0)
	await _frames(30)
	_caption = "checkpoint 3: walk left = flip_h mirror"
	queue_redraw(); await _frames(2); _capture("vid001_walk_left.png")
	_player.set_facing(1)

	_player.set_input_override(0.0)
	await _frames(4)
	_player.force_stop_transition()
	_caption = "checkpoint 4: walk_to_idle  (21 frames / 0.875s)"
	queue_redraw(); await _frames(2); _capture("vid001_stop_transition.png")

	_player.set_push_pose(true)
	_caption = "checkpoint 5: cart bound -> idle only (no fake push animation)"
	queue_redraw(); await _frames(2); _capture("vid001_cart_state.png")
	_player.set_push_pose(false)
	_caption = "tour complete"
	queue_redraw(); await _frames(2)
	print("[VID001] tour 截图完成")
	if _args.has("quit"):
		get_tree().quit(0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_paused = not _paused
