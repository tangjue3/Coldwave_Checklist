extends Node2D
## VIDEO-INTEGRATE-002 独立验证场景（候选 / 待美术审核）
##
## 用**真实** PlayerController + PushableCart 实例跑完整状态链：
##   普通行走 → 接近购物车 → 绑定 → 扶车待机 → 推车行走 → 停止 → 扶车待机
##   → 解除绑定 → 普通行走
## 车本体始终是 ART_FURN_103 r03 四件分层，人物贴图里没有车体像素。
##
##   --vid002-test   真实断言 + 结果截图后退出
##   --vid002-tour   各检查点截图
##   --vid002-movie  逐帧录屏（供 ffmpeg 合成 MP4）
##
## 注意：不修改购物车世界坐标 / 碰撞 / 装载逻辑，全部走既有公开接口。

const VIEW := Vector2(960, 540)
const GROUND_Y := 416.0
const SHOT_DIR := "res://tests/screenshots"
const MOVIE_DIR := "res://tests/screenshots/vid002_movie"
const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const FONT_PATH := "res://assets/ui/fonts/NotoSansSC-Variable.ttf"

const C_BG := Color(0.196, 0.216, 0.239)
const C_TICK := Color(0.52, 0.56, 0.60)
const C_INK := Color(0.94, 0.95, 0.96)
const C_MUTED := Color(0.68, 0.72, 0.76)
const C_OK := Color(0.45, 0.82, 0.55)
const C_BAD := Color(0.95, 0.45, 0.40)
const C_HL := Color(0.95, 0.72, 0.35)

var _args: Dictionary = {}
var _font: Font
var _cart: PushableCart
var _player: PlayerController
var _caption := "VIDEO-INTEGRATE-002  candidate / pending art review"
var _sub := ""
var _fails := 0
var _checks := 0
var _test_lines: Array[String] = []
var _movie := false
var _movie_i := 0
var _movie_t := 0.0
var _movie_next := 0.0
var _movie_end := 9.0


func _ready() -> void:
	_parse_args()
	_font = load(FONT_PATH)
	if _font == null:
		_font = ThemeDB.fallback_font

	# 车先入树：Back / Cargo 是 z=0，必须在人物之前绘制
	_cart = PushableCart.new()
	_cart.name = "Cart"
	_cart.ground_y = GROUND_Y
	_cart.world_left = 0.0
	_cart.world_right = VIEW.x
	_cart.art_variant = PushableCart.ART_VARIANT_R03
	_cart.set_load_state(PushableCart.LOAD_EMPTY)
	add_child(_cart)
	# 车放 480：推车段最长累计 360px → 840，仍在 960 视口内且不撞右墙（上限 912）。
	_cart.place_at(480.0)

	_player = PLAYER_SCENE.instantiate() as PlayerController
	_player.name = "Player"
	_player.ground_y = GROUND_Y
	_player.input_enabled = false
	add_child(_player)
	# 起点 300：普通行走 1 秒（100px/s）正好停在 400 = 车心-80，
	# 这样 bind() 不会把玩家吸附回跳，状态链视觉连续。
	_player.teleport_to(300.0)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	if _args.has("vid002_test"):
		await _run_tests()
	elif _args.has("vid002_tour"):
		await _run_tour()
	elif _args.has("vid002_movie"):
		_movie = true
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MOVIE_DIR))
		_caption = "movie: real Godot push-cart state chain"
	else:
		_player.input_enabled = true
		_caption = "interactive: E to bind/unbind, arrows to push"


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
	if not _movie:
		return
	_movie_t += delta
	_run_movie_timeline()
	if _movie_t >= _movie_next:
		_movie_next += 1.0 / 20.0
		_capture_frame()
	if _movie_t >= _movie_end:
		print("[VID002] movie frames=%d" % _movie_i)
		get_tree().quit(0)


## 真实状态链：全程只用 PushableCart.bind/unbind 与 PlayerController 的输入覆盖
func _run_movie_timeline() -> void:
	var t := _movie_t
	if t < 1.0:
		# ① 普通行走靠近购物车
		_player.set_input_override(1.0)
		_sub = "1/7  walk_right (r10) approaching cart"
	elif t < 1.35:
		_player.set_input_override(0.0)
		_sub = "2/7  stop before binding"
	elif t < 1.5:
		if _cart.state != PushableCart.STATE_PUSHING:
			_cart.bind(_player)
		_sub = "3/7  bind -> push_idle_right (candidate)"
	elif t < 4.2:
		_player.set_input_override(1.0)
		_sub = "4/7  push_walk_right 32f/24FPS @ 80 px/s"
	elif t < 5.4:
		_player.set_input_override(0.0)
		_sub = "5/7  stop -> push_walk_to_idle / push_idle"
	elif t < 7.2:
		_player.set_input_override(1.0)
		_cart.set_load_state(PushableCart.LOAD_HALF)
		_sub = "6/7  push again + HALF cargo"
	elif t < 8.0:
		_player.set_input_override(0.0)
		_cart.set_load_state(PushableCart.LOAD_FULL)
		_sub = "7/7  stop + FULL cargo"
	else:
		_player.set_input_override(0.0)
		_sub = "final: idle with full cart"


func _capture_frame() -> void:
	_movie_i += 1
	queue_redraw()
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png("%s/f_%04d.png" % [MOVIE_DIR, _movie_i])
	if err != OK:
		push_warning("[VID002] 录帧失败 err=%d" % err)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), C_BG, true)
	draw_line(Vector2(0, GROUND_Y), Vector2(VIEW.x, GROUND_Y), C_TICK, 1.0)
	for x in range(0, int(VIEW.x), 32):
		draw_line(Vector2(x, GROUND_Y - 4), Vector2(x, GROUND_Y), C_TICK.darkened(0.2), 1.0)
	_text(14, 24, _caption, 15, C_INK)
	_text(14, 44, _sub, 12, C_HL)
	_text(14, 64, "player anim=%s  frame=%d   cart=%s  load=%s  x=%.0f" % [
		String(_player.current_anim()), _player.anim_frame(), String(_cart.state),
		String(_cart.load_state), _cart.global_position.x], 11, C_MUTED)
	_text(14, 82, "r10–r12 untouched · cart uses ART_FURN_103 r03 layers · 100/80/40 px/s", 11, C_MUTED)
	var y := 108.0
	for line in _test_lines:
		_text(14, y, line, 11, C_BAD if line.begins_with("[FAIL]") else C_OK)
		y += 15.0


func _text(x: float, y: float, s: String, size: int, col: Color) -> void:
	draw_string(_font, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _capture(filename: String) -> void:
	queue_redraw()
	await _frames(2)
	var err := get_viewport().get_texture().get_image().save_png("%s/%s" % [SHOT_DIR, filename])
	if err != OK:
		push_warning("[VID002] 截图失败 %s err=%d" % [filename, err])


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
	print("[VID002] " + line)


# ---------------------------------------------------------------- 真实测试
func _run_tests() -> void:
	print("[VID002] ==== 推车动画真实测试（新断言，不沿用旧结果）====")
	var spr := _player.get_node("Sprite") as AnimatedSprite2D
	var sf := spr.sprite_frames

	# --- A. 资源与规格 ---
	_ok(_player.push_anim_available(), "推车三段动画齐备（候选已挂载）")
	_ok(sf.has_animation(&"push_walk_right") and sf.has_animation(&"push_idle_right")
		and sf.has_animation(&"push_walk_to_idle"), "SpriteFrames 含三段推车动画")
	_ok(sf.get_frame_count(&"push_walk_right") == 32, "push_walk_right 32 帧")
	_ok(sf.get_frame_count(&"push_walk_to_idle") == 17, "push_walk_to_idle 17 帧")
	_ok(sf.get_frame_count(&"push_idle_right") == 1, "push_idle_right 1 帧")
	_ok(sf.get_animation_speed(&"push_walk_right") == 24.0, "推车行走 24 FPS")
	_ok(sf.get_animation_loop(&"push_walk_right"), "推车行走循环")
	_ok(not sf.get_animation_loop(&"push_walk_to_idle"), "推车停止过渡不循环")

	# 已验收的 r10–r12 必须原样保留
	_ok(sf.get_frame_count(&"walk_right") == 36 and sf.get_frame_count(&"walk_to_idle") == 21
		and sf.get_frame_count(&"idle_right") == 1, "r10/r11/r12 三段帧数未被改动")
	_ok(_player.move_speed == 100.0 and _cart.push_speed == 80.0
		and _cart.pull_speed == 40.0, "速度 100 / 80 / 40 px/s 未改")
	_ok(_player.collision_width() == 28.0 and _player.collision_height() == 160.0,
		"人物碰撞盒 28×160 未改")
	_ok(_cart.get_cart_offset() == Vector2(-64, -104), "购物车贴图锚点未改")

	# --- B. 512×704 高清帧规格 ---
	var tex := sf.get_frame_texture(&"push_walk_right", 0)
	_ok(tex.get_size() == Vector2(512, 704), "推车帧贴图 512×704", str(tex.get_size()))
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var data := img.get_data()
	var bottom := -1
	var green := 0
	for yy in range(0, 704, 2):
		var row_has := false
		for xx in range(0, 512, 2):
			var i := (yy * 512 + xx) * 4
			if data[i + 3] < 12:
				continue
			row_has = true
			if float(data[i + 1]) / 255.0 - maxf(float(data[i]) / 255.0,
					float(data[i + 2]) / 255.0) > 0.20:
				green += 1
		if row_has:
			bottom = yy
	_ok(absi(bottom - 672) <= 8, "脚底落在贴图 y=672±8", "实测 %d" % bottom)
	_ok(green == 0, "推车帧无绿色残留", "green px=%d" % green)
	_ok(spr.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR,
		"人物 LINEAR 过滤（沿用已验收配置）")

	# --- C. 初始：普通行走，不是推车帧 ---
	_player.set_input_override(1.0)
	await _frames(30)
	_ok(_player.current_anim() == &"walk_right", "绑定前是普通行走 r10",
		String(_player.current_anim()))
	var walked_x := _player.global_position.x
	_ok(walked_x > 300.0, "普通行走确实产生位移", "x=%.1f" % walked_x)
	_player.set_input_override(0.0)
	await _frames(20)

	# --- D. 绑定 → 扶车待机 ---
	var before_cart_x := _cart.global_position.x
	_ok(_cart.bind(_player), "购物车绑定成功")
	await _frames(4)
	_ok(_player.is_pushing_pose(), "push_pose 已置位")
	_ok(_player.current_anim() == &"push_idle_right", "绑定后播扶车待机（非普通站姿）",
		String(_player.current_anim()))
	_ok(_cart.state == PushableCart.STATE_PUSHING, "购物车进入 PUSHING")
	_ok(absi(_cart.global_position.x - before_cart_x) < 0.01, "绑定不改变车体世界坐标",
		"x=%.1f" % _cart.global_position.x)
	_ok(absi((_player.global_position.x - _cart.global_position.x) - (-80.0)) < 0.01,
		"玩家仍在车左侧 80px（side_offset 未改）")
	_ok(_cart.front_layer_visible(), "r03 Front 前景层常驻（遮挡关系保留）")

	# --- E. 推车行走 ---
	_player.set_input_override(1.0)
	await _frames(35)
	_ok(_player.current_anim() == &"push_walk_right", "推行时播 push_walk_right",
		String(_player.current_anim()))
	_ok(_player.push_walk_active, "push_walk_active 已置位")
	_ok(_cart.last_speed > 60.0, "推车速度≈80 px/s", "%.1f" % _cart.last_speed)
	var cx_mid := _cart.global_position.x
	await _frames(20)
	_ok(_cart.global_position.x > cx_mid + 10.0, "车与人同步前进")
	_ok(absi((_player.global_position.x - _cart.global_position.x) + 80.0) < 0.5,
		"推行中人与车间距恒定 80px（无相对滑动）",
		"Δ=%.2f" % ((_player.global_position.x - _cart.global_position.x) + 80.0))

	# --- F. 装载状态切换不破坏动画 ---
	_cart.set_load_state(PushableCart.LOAD_HALF)
	await _frames(6)
	_ok(_cart.cargo_half_visible() and not _cart.cargo_full_visible(), "半载层显示正确")
	_ok(_player.current_anim() == &"push_walk_right", "半载切换不影响推车动画")
	_cart.set_load_state(PushableCart.LOAD_FULL)
	await _frames(6)
	_ok(_cart.cargo_full_visible() and not _cart.cargo_half_visible(), "满载层显示正确")
	_cart.set_load_state(PushableCart.LOAD_EMPTY)
	await _frames(4)
	_ok(not _cart.cargo_visible(), "空载层隐藏正确")

	# --- G. 停止 → 扶车待机 ---
	_player.set_input_override(0.0)
	await _frames(45)
	var a := _player.current_anim()
	_ok(a == &"push_idle_right" or a == &"push_walk_to_idle",
		"停止后回到扶车姿态（过渡或待机）", String(a))
	await _frames(40)
	_ok(_player.current_anim() == &"push_idle_right", "过渡播完自动回扶车待机",
		String(_player.current_anim()))
	_ok(not _player.push_walk_active, "push_walk_active 已清除")

	# --- H. 重新推车 ---
	_player.set_input_override(1.0)
	await _frames(20)
	_ok(_player.current_anim() == &"push_walk_right", "重新推车自然衔接",
		String(_player.current_anim()))
	_player.set_input_override(0.0)
	await _frames(20)

	# --- I. 解绑 → 普通行走 ---
	var parked_x := _cart.global_position.x
	_cart.unbind()
	await _frames(4)
	_ok(not _player.is_pushing_pose(), "push_pose 已清除")
	_ok(absi(_cart.global_position.x - parked_x) < 0.01, "停车不改变车体坐标")
	_player.set_input_override(1.0)
	await _frames(25)
	_ok(_player.current_anim() == &"walk_right", "解绑后回到普通行走 r10（不残留推车帧）",
		String(_player.current_anim()))
	_player.set_input_override(0.0)
	await _frames(20)

	# --- J. 左右镜像（本轮至少验证右向，附带确认镜像不破坏状态） ---
	_player.set_facing(-1)
	await _frames(3)
	_ok(spr.flip_h, "朝左用 flip_h 镜像（无独立左向帧）")
	_player.set_facing(1)
	await _frames(3)

	await _finish()


func _finish() -> void:
	_caption = "TEST  %d checks / %d failed" % [_checks, _fails]
	_test_lines.append("[%s] 合计 %d 项，失败 %d 项" %
		["PASS" if _fails == 0 else "FAIL", _checks, _fails])
	await _capture("vid002_test.png")
	if _args.has("quit") or _args.has("vid002_test"):
		get_tree().quit(1 if _fails > 0 else 0)


# ---------------------------------------------------------------- 检查点截图
func _run_tour() -> void:
	_player.set_input_override(1.0)
	_cart.set_load_state(PushableCart.LOAD_HALF)
	await _frames(24)
	_player.set_input_override(0.0)
	await _frames(16)
	_sub = "checkpoint 1: walk_right r10 approaching the cart"
	await _capture("vid002_1_approach.png")

	_cart.bind(_player)
	await _frames(10)
	_sub = "checkpoint 2: push_idle_right  (bound, hands on handle)"
	await _capture("vid002_2_push_idle.png")

	_player.set_input_override(1.0)
	await _frames(40)
	_sub = "checkpoint 3: push_walk_right 32f/24FPS @80px/s, HALF cargo"
	await _capture("vid002_3_push_walk.png")

	_cart.set_load_state(PushableCart.LOAD_FULL)
	await _frames(20)
	_sub = "checkpoint 4: FULL cargo, layer order intact"
	await _capture("vid002_4_full_cargo.png")

	_player.set_input_override(0.0)
	await _frames(45)
	_sub = "checkpoint 5: stopped -> push_idle_right"
	await _capture("vid002_5_stop.png")

	# 2× 窗口看高清边缘与手部接触
	get_window().size = Vector2i(1920, 1080)
	_player.set_input_override(1.0)
	await _frames(30)
	_sub = "checkpoint 6: 2x window, HD edge / hand-handle contact"
	await _capture("vid002_6_hires.png")
	_player.set_input_override(0.0)
	get_tree().quit(0)
