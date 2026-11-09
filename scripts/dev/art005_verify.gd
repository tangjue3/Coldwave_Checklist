extends Node2D
## ART-INTEGRATE-005 · 许知夏推车行走四帧（r04）的实机验证场景（开发专用）
##
## 本场景只做一件事：把 ART-RUNTIME-005 的四帧按真实运行参数接入后**实机量出来**：
##   - 像素合同：128×176、alpha 仅 0/255、顶 y=8、脚底 y=167（可见高 160）；
##   - 上身 88 行与 r03 逐像素一致（头部 / 双手理应零漂移）；
##   - 状态机：绑定推行 → push_walk_right；停住 / 撞墙 / 拉车 → push_idle；解绑 → 普通动画；
##   - 6 FPS 与 7 FPS 对照：量单循环耗时与推进距离，供报告判断步幅是否协调；
##   - 180 帧连续循环：帧序 0→1→2→3 循环、脚底不漂、手部间隙不抖。
##
## 冻结参数一个不改：间距 80、车长 96、推速 80 / 拉速 40、碰撞 28×160、960×540。
## r04 全部用例通过后也**不升运行时可用**（等美术总监裁定）。
##
## 命令行（写在 `--` 之后，须带 --dev-scene=art005）：
##   --art005-test              跑全部实机用例后退出（不截图）
##   --art005-tour              十个检查点截图后退出
##   --art005-gif               连拍推车动画帧（生成 GIF 用）后退出
##   --art005-door              门「进入 / 离开」回归（复用 Art004DoorWatcher）
##   --shot=name.png            单检查点截图
##   --quit                     完成后退出

const VIEW := Vector2(960, 540)
const GROUND_Y := 416.0
const SHOT_DIR := "res://tests/screenshots"
const FONT_PATH := "res://assets/ui/fonts/NotoSansSC-Variable.ttf"
const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")

# ---------------------------------------------------------------- 素材
## r04 四帧（待审核 / 引擎试用）
const FRAMES_R04 := [
	preload("res://assets/characters/ART_CHAR_001_r04_push_walk_right_00_contact.png"),
	preload("res://assets/characters/ART_CHAR_001_r04_push_walk_right_01_transfer.png"),
	preload("res://assets/characters/ART_CHAR_001_r04_push_walk_right_02_contact.png"),
	preload("res://assets/characters/ART_CHAR_001_r04_push_walk_right_03_transfer.png"),
]
## r03 扶车待机（对照基准：上身 88 行 / 手部 / 中轴）
const TEX_R03_PUSH := preload("res://assets/characters/ART_CHAR_001_r03_push_idle_right_128x176.png")

const CART_ANCHOR := Vector2(64, 104)
const CART_SEP := 80.0
const WALL_X := 700.0
const WALL_W := 32.0
const WALL_H := 360.0

const C_BG := Color(0.32, 0.30, 0.28)
const C_BG_TOP := Color(0.38, 0.36, 0.33)
const C_FLOOR := Color(0.50, 0.42, 0.33)
const C_INK := Color(0.96, 0.97, 0.98)
const C_MUTED := Color(0.80, 0.83, 0.86)
const C_OK := Color(0.52, 0.84, 0.60)
const C_BAD := Color(0.91, 0.42, 0.38)

var _args: Dictionary = {}
var _font: Font
var _player: PlayerController
var _cart: PushableCart
var _sensor: InteractionSensor
var _overlay: Art004Overlay
var _door: DoorInteractable
var _caption := ""


func _ready() -> void:
	_parse_args()
	_font = load(FONT_PATH)
	if _font == null:
		_font = ThemeDB.fallback_font

	var stage := Node2D.new()
	stage.name = "Stage"
	add_child(stage)

	# 车先入树（Back / Cargo z=0 要画在人物之前）
	_cart = PushableCart.new()
	_cart.name = "Cart"
	_cart.ground_y = GROUND_Y
	_cart.world_left = 0.0
	_cart.world_right = VIEW.x
	add_child(_cart)

	_player = PLAYER_SCENE.instantiate() as PlayerController
	_player.name = "Player"
	_player.ground_y = GROUND_Y
	add_child(_player)
	# 本场景是 r04 四帧的**专项**验证。ART-INTEGRATE-005E 起全局默认扶车动画改为 r09，
	# 必须在这里显式固定回 r04，否则帧序 / FPS / 手部基线断言会量到另一套动画。
	# 这不是删测试项：r09 有自己的 art005e 验证场景，两套用例各自跑各自的版本。
	_player.set_push_anim_variant(PlayerController.PUSH_ANIM_R04)

	_build_wall()
	_build_door()

	_sensor = InteractionSensor.new()
	_sensor.name = "Sensor"
	_sensor.actor_path = NodePath("../Player")
	_sensor.enabled = false
	add_child(_sensor)

	_overlay = Art004Overlay.new()
	_overlay.name = "DebugOverlay"
	_overlay.host = self
	_overlay.z_as_relative = false
	_overlay.z_index = 10
	add_child(_overlay)

	print("[ART005] 场景就绪 视觉=%s 动画=push_walk_right FPS=%.0f 帧数=%d" % [
		String(_cart.art_variant), _player.push_walk_fps, _frame_count()])

	if _args.has("art005_tour"):
		await _run_tour()
	elif _args.has("art005_test"):
		await _run_tests()
	elif _args.has("art005_door"):
		await _run_door_test()
	elif _args.has("art005_gif"):
		await _run_gif_capture()
	elif _args.has("art005_fps"):
		await _fps_shot(float(_args["art005_fps"]))
		if _args.has("quit"):
			get_tree().quit(0)
	elif _args.has("shot"):
		await _frames(6)
		_capture(String(_args["shot"]))
		if _args.has("quit"):
			get_tree().quit(0)


func _parse_args() -> void:
	var injected: Variant = SceneRouter.dev_args if SceneRouter else null
	if injected is Variant and injected is Dictionary:
		for k in injected:
			_args[k] = injected[k]
	for raw in OS.get_cmdline_user_args():
		var a: String = raw
		if not a.begins_with("--"):
			continue
		var kv := a.substr(2).split("=", true, 1)
		_args[kv[0].replace("-", "_")] = kv[1] if kv.size() > 1 else true


func _frame_count() -> int:
	var frames := _player.sprite_node().sprite_frames
	return frames.get_frame_count(PlayerController.ANIM_PUSH_WALK)


# ---------------------------------------------------------------- 世界搭建

func _build_wall() -> void:
	var body := StaticBody2D.new()
	body.name = "SolidWall"
	body.position = Vector2(WALL_X + WALL_W * 0.5, GROUND_Y - WALL_H * 0.5)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(WALL_W, WALL_H)
	shape.shape = rect
	body.add_child(shape)
	add_child(body)


func _build_door() -> void:
	_door = DoorInteractable.new()
	_door.name = "Door"
	_door.target_scene = &"shelter"
	_door.interactive = true
	_door.door_label = "安全屋门"
	_door.interact_priority = 10
	_door.position = Vector2(80.0, GROUND_Y - 96.0)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(120.0, 192.0)
	cs.shape = r
	_door.add_child(cs)
	add_child(_door)


# ---------------------------------------------------------------- 画面

func _draw() -> void:
	draw_rect(Rect2(0, 0, VIEW.x, GROUND_Y), C_BG, true, -1.0, false)
	draw_rect(Rect2(0, 0, VIEW.x, GROUND_Y - 104.0), C_BG_TOP, true, -1.0, false)
	draw_line(Vector2(0, GROUND_Y - 104.0), Vector2(VIEW.x, GROUND_Y - 104.0),
		Color(0.26, 0.22, 0.18, 0.9), 1.0)
	var seam := 160.0
	while seam < VIEW.x:
		draw_line(Vector2(seam, 0), Vector2(seam, GROUND_Y - 104.0),
			Color(0.34, 0.30, 0.26, 0.40), 1.0)
		seam += 160.0
	draw_rect(Rect2(0, GROUND_Y, VIEW.x, VIEW.y - GROUND_Y), C_FLOOR, true, -1.0, false)
	draw_line(Vector2(0, GROUND_Y), Vector2(VIEW.x, GROUND_Y), Color(0.68, 0.58, 0.46), 2.0)
	var x := 0.0
	while x < VIEW.x:
		draw_line(Vector2(x, GROUND_Y + 2.0), Vector2(x, GROUND_Y + 10.0),
			Color(0.40, 0.32, 0.24, 0.50), 1.0)
		x += 32.0
	draw_rect(Rect2(WALL_X, GROUND_Y - WALL_H, WALL_W, WALL_H), Color(0.26, 0.28, 0.30), true, -1.0, false)
	draw_rect(Rect2(WALL_X, GROUND_Y - WALL_H, WALL_W, WALL_H), Color(0, 0, 0, 0.35), false, 2.0, false)
	if _caption != "":
		_text(24, 40, _caption, 15, C_INK)


func _text(x: float, y: float, s: String, size: int, c: Color) -> void:
	if _font == null:
		return
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_rect(Rect2(x - 4, y - size, w + 8, size + 6), Color(0.06, 0.05, 0.04, 0.72), true, -1.0, false)
	draw_string(_font, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


## 叠加层入口（Art004Overlay 调用）
func debug_draw(_cv: CanvasItem) -> void:
	pass


# ---------------------------------------------------------------- 量测工具

## 纹理在「手部行带」内的横向范围（考虑 flip），返回 [min, max)
func _band_x(tex: Texture2D, node_pos: Vector2, offset: Vector2, flip: bool,
		y0: float, y1: float) -> Vector2:
	var img := tex.get_image()
	if img == null:
		return Vector2.ZERO
	var w := img.get_width()
	var lo := 1 << 30
	var hi := -(1 << 30)
	for y in img.get_height():
		var wy := node_pos.y + offset.y + float(y)
		if wy + 1.0 <= y0 or wy >= y1:
			continue
		for x in w:
			if img.get_pixel(x, y).a > 0.5:
				var col := (w - 1 - x) if flip else x
				var wx := int(node_pos.x + offset.x) + col
				lo = mini(lo, wx)
				hi = maxi(hi, wx + 1)
	return Vector2(float(lo), float(hi)) if hi > lo else Vector2.ZERO


## 角色"手"所在的行区间（纹理坐标）：取向前伸出最多的那几行。
## max_row 限定扫描范围：下身腿部随步态前后摆动，会把行带拉到脚的位置；
## 双手在上身 88 行内（ART-RUNTIME-005 交付合同），所以手部检查只看 y<88。
func _hand_rows(tex: Texture2D, max_row: int = -1) -> Vector2i:
	var img := tex.get_image()
	var used := img.get_used_rect()
	var right := used.position.x + used.size.x
	var y_end := used.position.y + used.size.y
	if max_row >= 0:
		y_end = mini(y_end, max_row)
	var lo := 1 << 30
	var hi := -1
	for y in range(used.position.y, y_end):
		for x in range(right - 1, used.position.x - 1, -1):
			if img.get_pixel(x, y).a > 0.5:
				if x >= right - 5:
					lo = mini(lo, y)
					hi = maxi(hi, y)
				break
	if hi < 0:
		return Vector2i(used.position.y, y_end)
	return Vector2i(lo, hi)


## 量当前实机画面里手与车把的贴合（与 ART-004 同口径，量 Back 层车把）
func _measure_hand() -> Dictionary:
	var tex := _player.current_texture()
	var off := _player.sprite_node().offset
	var flip := _player.sprite_node().flip_h
	var rows := _hand_rows(tex, 88)
	var y0 := _player.global_position.y + off.y + float(rows.x)
	var y1 := _player.global_position.y + off.y + float(rows.y + 1)

	var char_band := _band_x(tex, _player.global_position, off, flip, y0, y1)
	var cart_off := _cart.get_cart_offset()
	var cart_flip := _cart.is_visual_flipped()
	var cart_band := _band_x(_cart.CART_TEX_R03_BACK, _cart.global_position, cart_off, cart_flip, y0, y1)

	var gap := 0.0
	if _cart.side > 0:
		gap = char_band.x - cart_band.y
	else:
		gap = cart_band.x - char_band.y
	return {"side": _cart.side, "gap": gap, "rows": rows,
		"char_band": char_band, "cart_band": cart_band}


## 头顶 32 行的身体中轴（纹理坐标）——头部漂移用
func _head_axis(tex: Texture2D) -> float:
	var img := tex.get_image()
	var lo := 1 << 30
	var hi := -(1 << 30)
	for y in 32:
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				lo = mini(lo, x)
				hi = maxi(hi, x + 1)
	if hi <= lo:
		return -1.0
	return (float(lo) + float(hi)) * 0.5


## 纹理可见底行（最后一行有像素的 y）
func _bottom_row(tex: Texture2D) -> int:
	var img := tex.get_image()
	for y in range(img.get_height() - 1, -1, -1):
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				return y
	return -1


## 逐像素比较两张图（只比 RGB，alpha 视为两档），返回差异像素数
func _count_diff(a: Image, b: Image, rows := -1) -> int:
	var diff := 0
	var h := a.get_height() if rows < 0 else mini(rows, a.get_height())
	for y in h:
		for x in a.get_width():
			var pa := a.get_pixel(x, y)
			var pb := b.get_pixel(x, y)
			if absf(pa.r - pb.r) > 0.002 or absf(pa.g - pb.g) > 0.002 \
					or absf(pa.b - pb.b) > 0.002 or absf(pa.a - pb.a) > 0.002:
				diff += 1
	return diff


func _ok(label: String, cond: bool, extra: String = "") -> int:
	print("[T] %s %s%s" % ["通过" if cond else "失败", label, ("  ← " + extra) if extra != "" else ""])
	return 0 if cond else 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _capture(filename: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	var err := get_viewport().get_texture().get_image().save_png("%s/%s" % [SHOT_DIR, filename])
	print("[ART005] 截图 %-34s err=%d" % [filename, err])


# ---------------------------------------------------------------- 自动化用例

func _run_tests() -> void:
	var fails := 0
	print("")
	print("========== ART-INTEGRATE-005 实机验收 ==========")

	# ---- A 四帧像素合同
	print("[A] r04 四帧像素合同（画布 128×176 / alpha 两档 / 顶 y=8 / 脚底 y=167）")
	for i in FRAMES_R04.size():
		var tex: Texture2D = FRAMES_R04[i]
		var img := tex.get_image()
		var lv := {}
		for y in img.get_height():
			for x in img.get_width():
				lv[img.get_pixel(x, y).a8] = true
		var top := -1
		var bot := -1
		for y in img.get_height():
			var row_has := false
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.5:
					row_has = true
					break
			if row_has:
				if top < 0:
					top = y
				bot = y
		fails += _ok("帧 %d 画布 %d×%d / alpha %d 档 / 可见 y=%d..%d（高 %d）" % [
			i, img.get_width(), img.get_height(), lv.size(), top, bot, bot - top + 1],
			img.get_width() == 128 and img.get_height() == 176 and lv.size() <= 2
			and top == 8 and bot == 167)

	# ---- A2 上身 88 行与 r03 一致（头部 / 双手零漂移的像素级保证）
	print("[A2] 上身 88 行复用 r03（头发 / 脸 / 上身 / 双手应零漂移）")
	var r03_img := TEX_R03_PUSH.get_image()
	for i in FRAMES_R04.size():
		var d := _count_diff(FRAMES_R04[i].get_image(), r03_img, 88)
		fails += _ok("帧 %d 上身 88 行与 r03 差异像素 = %d（要求 0）" % [i, d], d == 0)

	# ---- B SpriteFrames 资源：动画存在 / 帧序 / loop / FPS
	print("[B] SpriteFrames 资源与帧序")
	var sf := _player.sprite_node().sprite_frames
	fails += _ok("push_walk_right 动画已注册（帧数 %d）" % _frame_count(),
		sf != null and sf.has_animation(PlayerController.ANIM_PUSH_WALK)
		and _frame_count() == 4)
	fails += _ok("动画循环 loop=true", sf.get_animation_loop(PlayerController.ANIM_PUSH_WALK))
	# 帧序：SpriteFrames 里的第 k 帧必须就是交付包顺序的第 k 张
	var order_ok := true
	for k in 4:
		if sf.get_frame_texture(PlayerController.ANIM_PUSH_WALK, k) != FRAMES_R04[k]:
			order_ok = false
	fails += _ok("播放顺序 00→01→02→03（SpriteFrames 帧序与交付包一致）", order_ok)
	fails += _ok("默认帧率 %.0f FPS（push_walk_fps 导出项生效）" % _player.push_walk_fps,
		absf(sf.get_animation_speed(PlayerController.ANIM_PUSH_WALK) - _player.push_walk_fps) < 0.01)

	# ---- C 脚底误差（逐帧）
	print("[C] 脚底误差（四帧脚底必须都踩在 y=168 基线，误差 0）")
	var foot_err_max := 0.0
	for i in FRAMES_R04.size():
		var br := _bottom_row(FRAMES_R04[i])
		var err := absf(float(br) - 167.0)
		foot_err_max = maxf(foot_err_max, err)
	fails += _ok("四帧脚底行均在 y=167（世界基线 y=168，最大误差 %.1f px）" % foot_err_max,
		foot_err_max < 0.51)

	# ---- D 头部横向漂移
	print("[D] 头部横向漂移（头顶 32 行中轴，四帧 + r03 必须同一位置）")
	var ax_r03 := _head_axis(TEX_R03_PUSH)
	var ax_max := 0.0
	var ax_texts := PackedStringArray()
	for i in FRAMES_R04.size():
		var ax := _head_axis(FRAMES_R04[i])
		ax_max = maxf(ax_max, absf(ax - ax_r03))
		ax_texts.append("%.1f" % ax)
	fails += _ok("头部中轴 r03=%.1f 四帧=[%s]（最大漂移 %.2f px）" % [
		ax_r03, ", ".join(ax_texts), ax_max],
		ax_max < 0.51)

	# ---- E 双手稳定（手部行带逐帧一致）
	print("[E] 双手稳定（手部行带逐帧一致 = 不抖）")
	var rows0 := _hand_rows(TEX_R03_PUSH, 88)
	var hands_ok := true
	for i in FRAMES_R04.size():
		var r := _hand_rows(FRAMES_R04[i], 88)
		if r != rows0:
			hands_ok = false
	fails += _ok("四帧手部行带均为 %s（与 r03 相同）" % str(rows0), hands_ok)

	# ---- F 状态机切换
	print("[F] 状态机：绑定 / 推行 / 停住 / 撞墙 / 解绑")
	_cart.place_at(480.0)
	_player.teleport_to(480.0 - CART_SEP)
	_cart.bind(_player)
	_player.resume_animation()
	await _frames(4)
	fails += _ok("绑定未动 → push_idle（实际 %s）" % String(_player.sprite_node().animation),
		_player.sprite_node().animation == PlayerController.ANIM_PUSH)
	# 推行：给输入后动画应切到 push_walk_right
	var ax_before_switch := _player.drawn_body_axis()
	_player.set_input_override(1.0)
	var switched := -1
	for i in 30:
		await get_tree().physics_frame
		if _player.sprite_node().animation == PlayerController.ANIM_PUSH_WALK:
			switched = i
			break
	fails += _ok("向前推行 → 切入 push_walk_right（%s 内生效，实测第 %d 物理帧）" % [
		"30 帧" if switched >= 0 else "未生效", switched],
		_player.sprite_node().animation == PlayerController.ANIM_PUSH_WALK)
	# 切入瞬间无瞬移：身体中轴不跳
	await _frames(2)
	var ax_after_switch := _player.drawn_body_axis()
	fails += _ok("静止 → 行走 切换瞬间身体中轴不跳（%.1f → %.1f）" % [ax_before_switch, ax_after_switch],
		absf(ax_before_switch - ax_after_switch) < 0.51)

	# ---- G 180 帧连续循环
	print("[G] 连续循环 180 物理帧（帧序 / 脚底 / 手部间隙）")
	# 换到离墙足够远的位置：480 起步推 1.5 秒就撞墙（那是 [H] 的活），
	# 200 起步到墙有 450+ px，够 180 帧连续推行不中断。
	_cart.unbind()
	_cart.place_at(200.0)
	_player.teleport_to(200.0 - CART_SEP)
	_cart.bind(_player)
	_player.resume_animation()
	await _frames(2)
	var seq: Array[int] = []
	var foot_min := 1 << 30
	var foot_max := -(1 << 30)
	var gap_min := 1 << 30
	var gap_max := -(1 << 30)
	for i in 180:
		await get_tree().physics_frame
		var spr := _player.sprite_node()
		if spr.animation == PlayerController.ANIM_PUSH_WALK:
			seq.append(spr.frame)
		var pb := _player.visible_bbox()
		var foot := _player.global_position.y + pb.position.y + pb.size.y
		foot_min = mini(foot_min, int(foot))
		foot_max = maxi(foot_max, int(foot))
		if i % 15 == 0:
			var g := float(_measure_hand()["gap"])
			gap_min = mini(gap_min, int(g * 10.0))
			gap_max = maxi(gap_max, int(g * 10.0) + 1)
	# 帧序合法：0→1→2→3→0…（允许同帧重复，因为引擎可能在两次物理帧间没走完一帧）
	var order_bad := 0
	for i in range(1, seq.size()):
		var expect := (seq[i - 1] + 1) % 4
		if seq[i] != seq[i - 1] and seq[i] != expect:
			order_bad += 1
	fails += _ok("180 帧内动画帧序 0→1→2→3 循环无乱序（采样 %d 帧，乱序 %d 次）" % [
		seq.size(), order_bad], order_bad == 0 and seq.size() >= 150)
	fails += _ok("循环期间脚底世界 y 恒定（%d..%d，抖动 %d px）" % [foot_min, foot_max, foot_max - foot_min],
		foot_max - foot_min <= 1)
	fails += _ok("循环期间手部间隙稳定（%.1f..%.1f px，波动 %.1f px 内）" % [
		gap_min / 10.0, gap_max / 10.0, (gap_max - gap_min) / 10.0],
		float(gap_max - gap_min) / 10.0 <= 2.0)

	# ---- H 撞墙：实际位移 0 → 切回 push_idle
	print("[H] 撞墙停止 → 动画回 push_idle")
	for i in 300:
		await get_tree().physics_frame
		if _cart.blocks_at_wall > 0:
			break
	_player.clear_input_override()
	await _frames(4)
	var cart_right := _cart.global_position.x + _cart.cart_width * 0.5
	fails += _ok("撞墙后位移 0 且动画切回 push_idle（车右沿 %.0f ≤ %.0f，动画 %s）" % [
		cart_right, WALL_X, String(_player.sprite_node().animation)],
		_cart.blocks_at_wall > 0 and cart_right <= WALL_X + 0.01
		and _player.sprite_node().animation == PlayerController.ANIM_PUSH)
	_cart.unbind()
	await _frames(4)
	fails += _ok("解绑后恢复普通动画（当前 %s）" % String(_player.sprite_node().animation),
		_player.sprite_node().animation == PlayerController.ANIM_IDLE
		or _player.sprite_node().animation == PlayerController.ANIM_WALK)

	# ---- I 每帧手部贴合（冻结逐帧量，与 r03 基线比）
	print("[I] 逐帧手部贴合（四帧各量一次，与 r03 push_idle 基线比）")
	_cart.place_at(480.0)
	_player.teleport_to(480.0 - CART_SEP)
	_cart.bind(_player)
	_player.resume_animation()
	await _frames(2)
	var base_m := _measure_hand()
	for k in 4:
		_player.freeze_frame(PlayerController.ANIM_PUSH_WALK, k)
		await _frames(1)
		var m := _measure_hand()
		fails += _ok("帧 %d 手部间隙 %+.1f px（基线 %+.1f，差 %+.1f）" % [
			k, float(m["gap"]), float(base_m["gap"]), float(m["gap"]) - float(base_m["gap"])],
			absf(float(m["gap"]) - float(base_m["gap"])) <= 1.5)
	_player.resume_animation()
	_cart.unbind()
	await _frames(2)

	# ---- J 装载与镜像（购物车专项抽查，完整覆盖在 ART-004 场景）
	print("[J] 装载 / 镜像 / r02 回退抽查")
	_cart.set_load_state(PushableCart.LOAD_FULL)
	fails += _ok("满载 + r03 分件默认（视觉=%s 装载=%s）" % [
		String(_cart.art_variant), String(_cart.load_state)],
		_cart.art_variant == PushableCart.ART_VARIANT_R03
		and _cart.load_state == PushableCart.LOAD_FULL)
	_cart.place_at(480.0)
	_player.teleport_to(480.0 + CART_SEP)
	_cart.bind(_player)
	_player.resume_animation()
	await _frames(2)
	fails += _ok("朝左镜像绑定成功（flip=%s）" % str(_cart.is_visual_flipped()),
		_cart.is_visual_flipped())
	_cart.set_art_variant(PushableCart.ART_VARIANT_R02)
	fails += _ok("绑定中可切回 r02 回退版本（视觉=%s）" % String(_cart.art_variant),
		_cart.art_variant == PushableCart.ART_VARIANT_R02)
	_cart.set_art_variant(PushableCart.ART_VARIANT_R03)
	_cart.unbind()
	await _frames(2)

	# ---- K FPS 对照：6 vs 7
	print("[K] FPS 对照（推速恒为 80 px/s，长窗口统计周期，消除单次相位抖动）")
	for fps in [6.0, 7.0]:
		# 每个 FPS 窗口都从同一位置起步（200 起步到墙 >450px，4s 窗口推进 320px 不会撞墙）
		if _cart.state == PushableCart.STATE_PUSHING:
			_cart.unbind()
			await _frames(2)
		_player.push_walk_fps = fps
		_cart.place_at(200.0)
		_player.teleport_to(200.0 - CART_SEP)
		_cart.bind(_player)
		_player.resume_animation()
		_player.set_input_override(1.0)
		await _frames(2)
		# 240 物理帧 = 4.0 s 窗口：数「回到帧 0」的次数（即完整循环数），
		# 再量窗口内推进距离。窗口两端各有 ≤1 个动画帧的相位误差，摊到 4 秒可忽略。
		var zero_count := 0
		var armed := true
		var x0 := _cart.global_position.x
		for i in 240:
			await get_tree().physics_frame
			var spr := _player.sprite_node()
			if spr.animation != PlayerController.ANIM_PUSH_WALK:
				continue
			if spr.frame == 0:
				if armed:
					zero_count += 1
					armed = false
			else:
				armed = true
		var window := 240.0 / 60.0
		var dist := _cart.global_position.x - x0
		var cycle := window / maxf(float(zero_count), 1.0)
		print("     %.0f FPS：4.0 s 窗口内 %d 个完整循环（单循环 %.2f s，理论 %.2f s），推进 %.1f px，实测车速 %.1f px/s" % [
			fps, zero_count, cycle, 4.0 / fps, dist, dist / window])
		fails += _ok("%.0f FPS 单循环实测 %.2f s（理论 %.2f s，±0.15 s 容差）" % [
			fps, cycle, 4.0 / fps], absf(cycle - 4.0 / fps) <= 0.15)
		fails += _ok("%.0f FPS 窗口内推速保持 %.0f±2 px/s（实测 %.1f）" % [
			fps, int(_cart.push_speed), dist / window],
			absf(dist / window - _cart.push_speed) <= 2.0)
	_player.push_walk_fps = 6.0
	_player.clear_input_override()
	_cart.unbind()
	await _frames(2)

	print("[T] 汇总：%s" % ("全部符合预期" if fails == 0 else "%d 项不符合预期" % fails))
	print("==============================================")
	if _args.has("quit"):
		get_tree().quit(0 if fails == 0 else 1)


# ---------------------------------------------------------------- 截图组

## 十个检查点：
##   f0/f1/f2/f3  四帧逐帧（冻结在推车行走各帧）
##   switch       静止→行走切换瞬间
##   moving       推车连续移动
##   overlap      人物与车篮重叠
##   wall         撞墙停止（已回 push_idle）
##   mirror       朝左镜像
##   fps_ab       6 vs 7 FPS（两次真实运行各截一张，由报告拼对照）
func _run_tour() -> void:
	# f0..f3：逐帧冻结
	_cart.set_load_state(PushableCart.LOAD_FULL)
	_cart.place_at(480.0)
	_player.teleport_to(480.0 - CART_SEP)
	_cart.bind(_player)
	_player.resume_animation()
	_player.set_input_override(1.0)
	await _frames(10)
	_player.clear_input_override()
	await _frames(2)
	for k in 4:
		_player.freeze_frame(PlayerController.ANIM_PUSH_WALK, k)
		_caption = "推车行走 第 %d 帧（%s）" % [k, ["00_contact", "01_transfer", "02_contact", "03_transfer"][k]]
		queue_redraw()
		await _frames(3)
		await RenderingServer.frame_post_draw
		_capture("art005_f%d.png" % k)

	# switch：静止→行走切换瞬间（先静止绑住，再给输入，第 2 物理帧截图）
	_cart.place_at(420.0)
	_player.teleport_to(420.0 - CART_SEP)
	_cart.unbind()
	_cart.bind(_player)
	_player.resume_animation()
	await _frames(6)
	_player.set_input_override(1.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_caption = "静止 → 行走 切换瞬间（push_idle → push_walk_right）"
	queue_redraw()
	await RenderingServer.frame_post_draw
	_capture("art005_switch.png")
	_player.clear_input_override()

	# moving：连续推行
	_cart.place_at(360.0)
	_player.teleport_to(360.0 - CART_SEP)
	_cart.unbind()
	_cart.bind(_player)
	_player.resume_animation()
	_player.set_input_override(1.0)
	await _frames(14)
	_caption = "推车连续移动（80 px/s · push_walk_right %d FPS）" % int(_player.push_walk_fps)
	queue_redraw()
	await RenderingServer.frame_post_draw
	_capture("art005_moving.png")
	_player.clear_input_override()
	await _frames(2)
	_cart.unbind()

	# overlap：人物与车篮重叠
	_cart.place_at(480.0)
	_player.teleport_to(470.0)
	_player.set_facing(1)
	_player.freeze_frame(PlayerController.ANIM_IDLE, 0)
	_caption = "人物与车篮重叠：近侧篮网正确遮挡腿部"
	queue_redraw()
	await _frames(4)
	await RenderingServer.frame_post_draw
	_capture("art005_overlap.png")

	# wall：撞墙停止
	_cart.place_at(560.0)
	_player.teleport_to(560.0 - CART_SEP)
	_cart.bind(_player)
	_player.resume_animation()
	_player.set_input_override(1.0)
	for i in 300:
		await get_tree().physics_frame
		if _cart.blocks_at_wall > 0:
			break
	_player.clear_input_override()
	await _frames(6)
	_caption = "推车撞墙停止：整组停住，动画已切回 push_idle"
	queue_redraw()
	await RenderingServer.frame_post_draw
	_capture("art005_wall.png")
	_cart.unbind()
	await _frames(2)

	# mirror：朝左镜像（绑定 + 行走）
	_cart.place_at(560.0)
	_player.teleport_to(560.0 + CART_SEP)
	_cart.bind(_player)
	_player.resume_animation()
	_player.set_input_override(-1.0)
	await _frames(14)
	_caption = "朝左镜像：整层水平翻转，人物与车把对位不变"
	queue_redraw()
	await RenderingServer.frame_post_draw
	_capture("art005_mirror.png")
	_player.clear_input_override()
	_cart.unbind()
	await _frames(2)

	print("[ART005] 截图完成，见 tests/screenshots/art005_*.png（FPS 对照用 --art005-fps 单独截）")
	if _args.has("quit"):
		get_tree().quit(0)


## --art005-fps=6|7：单状态截图（供 FPS 对照并排）
func _fps_shot(fps: float) -> void:
	_player.push_walk_fps = fps
	_cart.set_load_state(PushableCart.LOAD_FULL)
	_cart.place_at(400.0)
	_player.teleport_to(400.0 - CART_SEP)
	_cart.bind(_player)
	_player.resume_animation()
	_player.set_input_override(1.0)
	await _frames(16)
	_caption = "推车行走 %d FPS（推速恒为 80 px/s）" % int(fps)
	queue_redraw()
	await RenderingServer.frame_post_draw
	_capture("art005_fps_%d.png" % int(fps))
	_player.clear_input_override()
	_cart.unbind()
	await _frames(2)


## GIF 素材连拍：真实引擎逐帧渲染推车循环，60 帧原生 960×540
func _run_gif_capture() -> void:
	_cart.set_load_state(PushableCart.LOAD_FULL)
	_cart.place_at(420.0)
	_player.teleport_to(420.0 - CART_SEP)
	_cart.bind(_player)
	_player.resume_animation()
	_player.set_input_override(1.0)
	for i in 60:
		await RenderingServer.frame_post_draw
		_capture("art005_gif_%02d.png" % i)
	_player.clear_input_override()
	_cart.unbind()
	print("[ART005] GIF 素材连拍完成（60 帧真实引擎渲染）")
	if _args.has("quit"):
		get_tree().quit(0)


# ---------------------------------------------------------------- 门回归

func _run_door_test() -> void:
	print("")
	print("========== ART-INTEGRATE-005 门进出回归 ==========")
	var watcher := Art004DoorWatcher.new()
	watcher.name = "DoorWatcher"
	get_tree().root.add_child(watcher)
	watcher.start()
	_player.teleport_to(140.0)
	_sensor.enabled = true
	await _frames(8)
	var t := _sensor.current
	print("[DOOR-TEST] 靠近门 target=%s prompt=%s" % [
		t.name if t else "null", t.prompt_text() if t else "-"])
	_sensor.request_interact()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo:
		if k.keycode == KEY_F3:
			_overlay.show_overlay = not _overlay.show_overlay
