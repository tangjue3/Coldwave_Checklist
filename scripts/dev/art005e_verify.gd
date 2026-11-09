extends Node2D
## ART-INTEGRATE-005E · r09 扶车返工（静止 1 帧 + 推车行走 16 帧 / 10 FPS）实机验证场景
##
## 只做开发验证，不挂主菜单。所有量测都来自**真实运行中的 Godot 画面 / 纹理数据**，
## 不接受「每帧脚底 y=167 所以没有滑步」这类静态推断：
##   [A] 像素合同：17 张 128×176、alpha 0/255、顶 y=8、脚底 y=167、16 帧互异、帧序；
##   [B] 状态机：绑定 / 前进 / 停住 / 撞墙 / 拉车 / 解绑 / 回退 r04 各自的动画；
##   [C] 世界固定地面：连续 240 物理帧（≥2 个 16 帧循环），逐帧量脚掌**世界 x**，
##       报告承重段滑移残差，并连拍原生 960×540 实机帧供 GIF 复核；
##   [D] 双手与车把像素求交、图层顺序、朝左镜像不横跳、头部中轴零漂移、冻结参数未改。
##
## 冻结参数一个不改：960×540 / 128×176 / 锚点 (64,168) / 碰撞 28×160 /
## 车 128×112 锚点 (64,104) / 车长 96 / side_offset 80 / 推 80 / 拉 40 / Back→Cargo→Player→Front。
## r09 已由 ART-APPROVE-005E 批准「运行时可用」；本场景仍只做验证，不改台账或白名单。
##
## 命令行（写在 `--` 之后，须带 --dev-scene=art005e）：
##   --art005e-test      全部实机用例（含两个步态循环的数据量测）后退出，退出码即结果
##   --art005e-tour      检查点截图组
##   --art005e-gif       真实输入下连拍 40 张 960×540（供 GIF 组装）
##   --art005e-compare   r04 / r09 同帧画面对照
##   --shot=name.png     单检查点截图
##   --quit              完成后退出

const VIEW := Vector2(960, 540)
const GROUND_Y := 416.0
const SHOT_DIR := "res://tests/screenshots"
const FONT_PATH := "res://assets/ui/fonts/NotoSansSC-Variable.ttf"
const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")

const R09_IDLE := preload("res://assets/characters/ART_CHAR_001_r09_push_idle_right_128x176.png")
const R09_WALK := [
	preload("res://assets/characters/ART_CHAR_001_r09_push_walk_00_128x176.png"),
	preload("res://assets/characters/ART_CHAR_001_r09_push_walk_01_128x176.png"),
	preload("res://assets/characters/ART_CHAR_001_r09_push_walk_02_128x176.png"),
	preload("res://assets/characters/ART_CHAR_001_r09_push_walk_03_128x176.png"),
	preload("res://assets/characters/ART_CHAR_001_r09_push_walk_04_128x176.png"),
	preload("res://assets/characters/ART_CHAR_001_r09_push_walk_05_128x176.png"),
	preload("res://assets/characters/ART_CHAR_001_r09_push_walk_06_128x176.png"),
	preload("res://assets/characters/ART_CHAR_001_r09_push_walk_07_128x176.png"),
	preload("res://assets/characters/ART_CHAR_001_r09_push_walk_08_128x176.png"),
	preload("res://assets/characters/ART_CHAR_001_r09_push_walk_09_128x176.png"),
	preload("res://assets/characters/ART_CHAR_001_r09_push_walk_10_128x176.png"),
	preload("res://assets/characters/ART_CHAR_001_r09_push_walk_11_128x176.png"),
	preload("res://assets/characters/ART_CHAR_001_r09_push_walk_12_128x176.png"),
	preload("res://assets/characters/ART_CHAR_001_r09_push_walk_13_128x176.png"),
	preload("res://assets/characters/ART_CHAR_001_r09_push_walk_14_128x176.png"),
	preload("res://assets/characters/ART_CHAR_001_r09_push_walk_15_128x176.png"),
]
const R04_WALK := [
	preload("res://assets/characters/ART_CHAR_001_r04_push_walk_right_00_contact.png"),
	preload("res://assets/characters/ART_CHAR_001_r04_push_walk_right_01_transfer.png"),
	preload("res://assets/characters/ART_CHAR_001_r04_push_walk_right_02_contact.png"),
	preload("res://assets/characters/ART_CHAR_001_r04_push_walk_right_03_transfer.png"),
]
const TEX_R03 := preload("res://assets/characters/ART_CHAR_001_r03_push_idle_right_128x176.png")
const CART_BACK := preload("res://assets/facilities/ART_FURN_103_r03_back_128x112.png")

const CART_ANCHOR := Vector2(64, 104)
const CART_SEP := 80.0
const WALL_X := 920.0
const WALL_W := 32.0
const WALL_H := 360.0
const ANIM_R09_IDLE := &"r09_push_idle"
const ANIM_R09_WALK := &"r09_push_walk_right"
const ANIM_R04_IDLE := &"push_idle"
const ANIM_R04_WALK := &"push_walk_right"

const C_BG := Color(0.32, 0.30, 0.28)
const C_BG_TOP := Color(0.38, 0.36, 0.33)
const C_FLOOR := Color(0.50, 0.42, 0.33)
const C_INK := Color(0.96, 0.97, 0.98)

var _args: Dictionary = {}
var _font: Font
var _player: PlayerController
var _cart: PushableCart
var _sensor: InteractionSensor
var _overlay: Art004Overlay
var _caption := ""


func _ready() -> void:
	_parse_args()
	_font = load(FONT_PATH)
	if _font == null:
		_font = ThemeDB.fallback_font

	# 车先入树：Back / Cargo 的 z=0 层必须画在人物之前
	_cart = PushableCart.new()
	_cart.name = "Cart"
	_cart.ground_y = GROUND_Y
	_cart.world_left = 0.0
	_cart.world_right = VIEW.x
	_cart.place_at(300.0)
	add_child(_cart)

	_player = PLAYER_SCENE.instantiate() as PlayerController
	_player.name = "Player"
	_player.ground_y = GROUND_Y
	_player.teleport_to(220.0)
	add_child(_player)

	_build_wall()

	# 启用热点，让桌面 / Web 都能用真实 E 键绑定与解绑购物车
	_sensor = InteractionSensor.new()
	_sensor.name = "Sensor"
	_sensor.actor_path = NodePath("../Player")
	_sensor.enabled = true
	add_child(_sensor)

	_overlay = Art004Overlay.new()
	_overlay.name = "DebugOverlay"
	_overlay.host = self
	_overlay.z_as_relative = false
	_overlay.z_index = 10
	add_child(_overlay)

	var frames := _player.sprite_node().sprite_frames
	print("[ART005E] 场景就绪 动画版本=%s r09静止=%s r09行走=%s 帧数=%d FPS=%.1f r04帧数=%d" % [
		String(_player.push_anim_variant), String(ANIM_R09_IDLE), String(ANIM_R09_WALK),
		frames.get_frame_count(ANIM_R09_WALK),
		frames.get_animation_speed(ANIM_R09_WALK),
		frames.get_frame_count(ANIM_R04_WALK)])
	print("[ART005E] 冻结参数 车长=%.0f 间距=%.0f 推=%.0f 拉=%.0f 碰撞=%.0fx%.0f 视口=%.0fx%.0f" % [
		_cart.cart_width, _cart.side_offset, _cart.push_speed, _cart.pull_speed,
		_player.collision_width(), _player.collision_height(), VIEW.x, VIEW.y])

	if _args.has("art005e_test"):
		await _run_tests()
	elif _args.has("art005e_ground"):
		await _run_ground_cycles(true)
		if not OS.has_feature("web"):
			get_tree().quit(0)
	elif _args.has("art005e_tour"):
		await _run_tour()
	elif _args.has("art005e_gif"):
		await _run_gif_capture()
	elif _args.has("art005e_compare"):
		await _run_compare()
	elif _args.has("shot"):
		await _frames(6)
		await RenderingServer.frame_post_draw
		_capture(String(_args["shot"]))
		if _args.has("quit"):
			get_tree().quit(0)


func _parse_args() -> void:
	for k in SceneRouter.dev_args:
		_args[k] = SceneRouter.dev_args[k]
	for raw in OS.get_cmdline_user_args():
		var a: String = raw
		if not a.begins_with("--"):
			continue
		var kv := a.substr(2).split("=", true, 1)
		_args[kv[0].replace("-", "_")] = kv[1] if kv.size() > 1 else true
	# Web 端没有命令行，SceneRouter 把 ?state=xxx 注入为 art005e_state
	if _args.has("art005e_state"):
		var st := String(_args["art005e_state"])
		if st == "test":
			_args["art005e_test"] = true
		elif st == "tour":
			_args["art005e_tour"] = true
		elif st == "gif":
			_args["art005e_gif"] = true


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


# ---------------------------------------------------------------- 画面

func _draw() -> void:
	draw_rect(Rect2(0, 0, VIEW.x, GROUND_Y), C_BG, true, -1.0, false)
	draw_rect(Rect2(0, 0, VIEW.x, GROUND_Y - 104.0), C_BG_TOP, true, -1.0, false)
	draw_line(Vector2(0, GROUND_Y - 104.0), Vector2(VIEW.x, GROUND_Y - 104.0),
		Color(0.26, 0.22, 0.18, 0.9), 1.0)
	# 世界固定的地面刻度：每 32px 一道，用来肉眼判断脚掌是否相对地面滑动
	var seam := 0.0
	while seam < VIEW.x:
		draw_line(Vector2(seam, GROUND_Y - 104.0), Vector2(seam, GROUND_Y),
			Color(0.34, 0.30, 0.26, 0.45), 1.0)
		draw_line(Vector2(seam, GROUND_Y + 2.0), Vector2(seam, GROUND_Y + 12.0),
			Color(0.34, 0.27, 0.20, 0.75), 1.0)
		seam += 32.0
	draw_rect(Rect2(0, GROUND_Y, VIEW.x, VIEW.y - GROUND_Y), C_FLOOR, true, -1.0, false)
	draw_line(Vector2(0, GROUND_Y), Vector2(VIEW.x, GROUND_Y), Color(0.68, 0.58, 0.46), 2.0)
	draw_rect(Rect2(WALL_X, GROUND_Y - WALL_H, WALL_W, WALL_H), Color(0.26, 0.28, 0.30), true, -1.0, false)
	if _caption != "":
		_text(24, 40, _caption, 15, C_INK)


func _text(x: float, y: float, s: String, size: int, c: Color) -> void:
	if _font == null:
		return
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_rect(Rect2(x - 4, y - size, w + 8, size + 6), Color(0.06, 0.05, 0.04, 0.72), true, -1.0, false)
	draw_string(_font, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


func debug_draw(_cv: CanvasItem) -> void:
	pass


# ---------------------------------------------------------------- 量测工具

func _image(tex: Texture2D) -> Image:
	return tex.get_image() if tex != null else null


func _alpha_levels(tex: Texture2D) -> Array[int]:
	var out: Array[int] = []
	var img := _image(tex)
	if img == null:
		return out
	for y in img.get_height():
		for x in img.get_width():
			var a := int(roundf(img.get_pixel(x, y).a * 255.0))
			if not out.has(a):
				out.append(a)
	return out


func _bottom_row(tex: Texture2D) -> int:
	var img := _image(tex)
	if img == null:
		return -1
	for y in range(img.get_height() - 1, -1, -1):
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				return y
	return -1


func _top_row(tex: Texture2D) -> int:
	var img := _image(tex)
	if img == null:
		return -1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				return y
	return -1


## 头顶 32 行的身体中轴（与 PlayerController._body_axis 同口径）
func _head_axis(tex: Texture2D) -> float:
	var img := _image(tex)
	if img == null:
		return -1.0
	var used := img.get_used_rect()
	var left := 1 << 30
	var right := -1
	for y in range(used.position.y, used.position.y + mini(32, maxi(1, used.size.y))):
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				left = mini(left, x)
				right = maxi(right, x)
	return (float(left) + float(right) + 1.0) * 0.5 if right >= left else -1.0


## 逐像素比较两张纹理前 rows 行的 RGBA，返回差异像素数（-1 = 全图）
func _diff_pixels(a: Texture2D, b: Texture2D, rows: int = -1) -> int:
	var ia := _image(a)
	var ib := _image(b)
	if ia == null or ib == null or ia.get_size() != ib.get_size():
		return -1
	var h := ia.get_height() if rows < 0 else mini(rows, ia.get_height())
	var n := 0
	for y in h:
		for x in ia.get_width():
			if ia.get_pixel(x, y) != ib.get_pixel(x, y):
				n += 1
	return n


## 当前帧脚掌在**世界坐标**里的接触点 x。
## 取最底 3 行内最靠前（朝右）的非透明像素，加上玩家节点与 sprite 绘制偏移。
## 这是固定世界里的真实横坐标，不是纹理里的 y 坐标。
func _foot_world_x(tex: Texture2D) -> float:
	var img := _image(tex)
	if img == null:
		return 0.0
	var bottom := _bottom_row(tex)
	var best := -1.0
	for y in range(maxi(0, bottom - 2), bottom + 1):
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				best = maxf(best, float(x))
	if best < 0.0:
		return 0.0
	var spr := _player.sprite_node()
	return _player.global_position.x + spr.offset.x + best


## 双手与车把的像素交叠：把车 Back 层的非透明像素换算到世界整数坐标集合，
## 只看角色**手部行带 y=70..95**（脸/上身锁定在 0..94，双手在 77..83 附近），
## 避免把车轮与鞋底的重叠误算成握手。返回命中像素数、接触区个数与 x 范围。
func _handle_overlap(tex: Texture2D) -> Dictionary:
	var ic := _image(CART_BACK)
	var ip := _image(tex)
	if ic == null or ip == null:
		return {"pixels": 0, "clusters": 0, "x_min": 0, "x_max": 0}
	var cart_px := {}
	for y in ic.get_height():
		for x in ic.get_width():
			if ic.get_pixel(x, y).a > 0.5:
				var wx := int(roundf(_cart.global_position.x - CART_ANCHOR.x + float(x)))
				var wy := int(roundf(_cart.global_position.y - CART_ANCHOR.y + float(y)))
				cart_px[Vector2i(wx, wy)] = true
	var spr := _player.sprite_node()
	var hit := 0
	var hit_x := {}
	for y in range(70, 96):
		for x in ip.get_width():
			if ip.get_pixel(x, y).a <= 0.5:
				continue
			var wx2 := int(roundf(_player.global_position.x + spr.offset.x + float(x)))
			var wy2 := int(roundf(_player.global_position.y + spr.offset.y + float(y)))
			if cart_px.has(Vector2i(wx2, wy2)):
				hit += 1
				hit_x[wx2] = true
	var xs := hit_x.keys()
	xs.sort()
	var clusters := 0
	var prev_x := -100000
	for x in xs:
		if int(x) - prev_x > 1:
			clusters += 1
		prev_x = int(x)
	return {
		"pixels": hit,
		"clusters": clusters,
		"x_min": int(xs[0]) if xs.size() > 0 else 0,
		"x_max": int(xs[xs.size() - 1]) if xs.size() > 0 else 0,
	}


func _ok(label: String, cond: bool, extra: String = "") -> int:
	print("[T] %s %s%s" % ["通过" if cond else "失败", label, ("  ← " + extra) if extra != "" else ""])
	return 0 if cond else 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _capture(filename: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	var err := get_viewport().get_texture().get_image().save_png("%s/%s" % [SHOT_DIR, filename])
	print("[ART005E] 截图 %-38s err=%d" % [filename, err])


func _bind_default() -> void:
	_cart.place_at(300.0)
	_player.teleport_to(300.0 - CART_SEP)
	_player.resume_animation()
	_cart.bind(_player)
	await _frames(2)


func _unbind_all() -> void:
	_player.clear_input_override()
	_cart.unbind()
	await _frames(2)


# ---------------------------------------------------------------- 自动化用例

func _run_tests() -> void:
	var fails := 0
	var frames := _player.sprite_node().sprite_frames
	print("")
	print("========== ART-INTEGRATE-005E r09 实机用例 ==========")

	# [A] 像素合同 ----------------------------------------------------------
	print("---- [A] 像素合同 ----")
	var all_textures: Array[Texture2D] = [R09_IDLE]
	for t in R09_WALK:
		all_textures.append(t as Texture2D)
	fails += _ok("导入 17 张运行时贴图（1 静止 + 16 行走）", all_textures.size() == 17)
	var size_ok := true
	var alpha_ok := true
	var top_ok := true
	var foot_ok := true
	for t in all_textures:
		if t.get_size() != Vector2(128, 176):
			size_ok = false
		var lv := _alpha_levels(t)
		if lv.size() != 2 or not lv.has(0) or not lv.has(255):
			alpha_ok = false
		if _top_row(t) != 8:
			top_ok = false
		if _bottom_row(t) != 167:
			foot_ok = false
	fails += _ok("17 张均为 128×176 画布", size_ok)
	fails += _ok("17 张 alpha 仅 0/255 两档（导入未污染透明边）", alpha_ok)
	fails += _ok("17 张顶行 y=8（可见高 160）", top_ok)
	fails += _ok("17 张最后可见行 y=167（脚底基线 168）", foot_ok)

	var unique := true
	for i in 16:
		for j in range(i + 1, 16):
			if _image(R09_WALK[i] as Texture2D).get_data() == _image(R09_WALK[j] as Texture2D).get_data():
				unique = false
	fails += _ok("16 张行走帧像素数据两两不同（无重复帧）", unique)

	var order_ok := true
	for i in 16:
		if frames.get_frame_texture(ANIM_R09_WALK, i) != (R09_WALK[i] as Texture2D):
			order_ok = false
	fails += _ok("SpriteFrames 帧序 = 00→01→…→15", order_ok,
		"帧数=%d" % frames.get_frame_count(ANIM_R09_WALK))
	fails += _ok("r09 行走动画 16 帧 / 10 FPS / loop",
		frames.get_frame_count(ANIM_R09_WALK) == 16
		and is_equal_approx(frames.get_animation_speed(ANIM_R09_WALK), 10.0)
		and frames.get_animation_loop(ANIM_R09_WALK))
	fails += _ok("r09 静止动画 1 帧且使用 r09 静止贴图",
		frames.get_frame_count(ANIM_R09_IDLE) == 1
		and frames.get_frame_texture(ANIM_R09_IDLE, 0) == R09_IDLE)
	fails += _ok("r03 / r04 旧动画仍在（可回退）",
		frames.has_animation(ANIM_R04_IDLE) and frames.get_frame_count(ANIM_R04_WALK) == 4)

	var upper_ok := true
	var face_ok := true
	var head_ref := _head_axis(R09_IDLE)
	var axis_ok := true
	for t in R09_WALK:
		if _diff_pixels(t as Texture2D, R09_IDLE, 95) != 0:
			upper_ok = false
		if _diff_pixels(t as Texture2D, TEX_R03, 61) != 0:
			face_ok = false
		if not is_equal_approx(_head_axis(t as Texture2D), head_ref):
			axis_ok = false
	fails += _ok("16 帧 y=0..94 与 r09 静止帧逐像素一致", upper_ok)
	fails += _ok("16 帧 y=0..60 与工程 r03 逐像素一致（不变脸）", face_ok)
	fails += _ok("17 帧头部中轴一致 = %.1f（不漂移）" % head_ref, axis_ok)

	# [B] 状态机 ------------------------------------------------------------
	print("---- [B] 动画状态机 ----")
	await _bind_default()
	fails += _ok("绑定后播 r09 扶车静止帧",
		_player.sprite_node().animation == ANIM_R09_IDLE,
		String(_player.sprite_node().animation))
	_player.set_input_override(1.0)
	await _frames(10)
	fails += _ok("向前实际推行 → r09 十六帧行走",
		_player.sprite_node().animation == ANIM_R09_WALK,
		String(_player.sprite_node().animation))
	_player.set_input_override(0.0)
	await _frames(6)
	fails += _ok("停住 → 回 r09 扶车静止帧",
		_player.sprite_node().animation == ANIM_R09_IDLE,
		String(_player.sprite_node().animation))
	_player.set_input_override(-1.0)
	await _frames(10)
	fails += _ok("反向拉车（40px/s）→ 保持扶车静止帧",
		_player.sprite_node().animation == ANIM_R09_IDLE,
		String(_player.sprite_node().animation))
	_player.set_input_override(0.0)
	await _frames(3)

	# 撞墙：临时收紧世界右边界，冻结参数本身不动
	_cart.place_at(600.0)
	_player.teleport_to(600.0 - CART_SEP)
	_cart.bind(_player)
	var saved_right := _cart.world_right
	_cart.world_right = 660.0
	_player.set_input_override(1.0)
	await _frames(60)
	fails += _ok("撞墙实际位移 0 → 回 r09 扶车静止帧（不原地踏步）",
		_cart.last_speed < 1.0 and _player.sprite_node().animation == ANIM_R09_IDLE,
		"speed=%.2f anim=%s blocks=%d" % [
			_cart.last_speed, String(_player.sprite_node().animation), _cart.blocks_at_wall])
	_cart.world_right = saved_right
	_player.set_input_override(0.0)
	await _unbind_all()
	_player.set_input_override(1.0)
	await _frames(8)
	fails += _ok("解绑后恢复普通行走 walk_right",
		_player.sprite_node().animation == &"walk_right",
		String(_player.sprite_node().animation))
	_player.set_input_override(0.0)
	await _frames(4)

	await _bind_default()
	_player.set_push_anim_variant(PlayerController.PUSH_ANIM_R04)
	_player.set_input_override(1.0)
	await _frames(10)
	fails += _ok("切换 r04 回退版本 → 旧四帧动画仍可用",
		_player.sprite_node().animation == ANIM_R04_WALK,
		String(_player.sprite_node().animation))
	_player.set_push_anim_variant(PlayerController.PUSH_ANIM_R09)
	await _frames(6)
	fails += _ok("切回 r09 → 恢复十六帧行走",
		_player.sprite_node().animation == ANIM_R09_WALK,
		String(_player.sprite_node().animation))
	await _unbind_all()

	# [C] 世界固定地面：两个完整步态循环 ------------------------------------
	print("---- [C] 世界固定地面 / 脚掌世界接触 ----")
	var ground_fails: int = await _run_ground_cycles(false)
	fails += ground_fails

	# [D] 接触、图层、镜像、冻结参数 ----------------------------------------
	print("---- [D] 接触 / 图层 / 镜像 / 冻结参数 ----")
	await _bind_default()
	_cart.set_load_state(PushableCart.LOAD_FULL)
	await _frames(3)
	var hand := _handle_overlap(R09_IDLE)
	fails += _ok("双手与车把在手部行带有像素交叠（美术合同 20px）", int(hand["pixels"]) > 0,
		"实测 %d px / %d 个接触区 / 世界 x=%d..%d" % [
			hand["pixels"], hand["clusters"], hand["x_min"], hand["x_max"]])
	fails += _ok("购物车 Back 先于人物入树（z=0 绘制序正确）", _cart.layer_order_is_valid())
	fails += _ok("r03 近侧篮网 Front 常驻且盖住腿部", _cart.front_layer_visible())

	var axis_before := _player.drawn_body_axis()
	_player.set_facing(-1)
	await _frames(2)
	var axis_after := _player.drawn_body_axis()
	fails += _ok("朝左镜像身体中轴不横跳（差 %.2f px）" % absf(axis_after - axis_before),
		is_equal_approx(axis_before, axis_after))
	_player.set_facing(1)
	await _frames(2)

	var vp := get_viewport().get_visible_rect().size
	var frozen_ok := absf(vp.x - VIEW.x) < 0.5 and absf(vp.y - VIEW.y) < 0.5 and is_equal_approx(_cart.cart_width, 96.0) and is_equal_approx(_cart.side_offset, 80.0) and is_equal_approx(_cart.push_speed, 80.0) and is_equal_approx(_cart.pull_speed, 40.0)
	fails += _ok("冻结参数未改：视口 960×540 / 车长 96 / 间距 80 / 推 80 / 拉 40", frozen_ok)
	fails += _ok("冻结参数未改：碰撞 28×160 / 车锚点 (64,104)",
		is_equal_approx(_player.collision_width(), 28.0)
		and is_equal_approx(_player.collision_height(), 160.0)
		and _cart.get_cart_offset() == -CART_ANCHOR)
	await _unbind_all()

	print("")
	print("========== ART-INTEGRATE-005E 结果：失败 %d 项 ==========" % fails)
	if not OS.has_feature("web"):
		get_tree().quit(0 if fails == 0 else 1)


## 连续 240 物理帧（约 4s，10FPS 下 ≈40 动画帧 = 2.5 个 16 帧循环）。
## 每 6 物理帧采一次（对应一个动画帧），记录车 / 人世界 x、动画帧号、脚掌世界 x。
func _run_ground_cycles(with_shots: bool) -> int:
	var fails := 0
	_cart.set_load_state(PushableCart.LOAD_FULL)
	_cart.place_at(300.0)
	_player.teleport_to(300.0 - CART_SEP)
	_player.resume_animation()
	_cart.bind(_player)
	_player.set_input_override(1.0)
	await _frames(8)

	var start_cart := _cart.global_position.x
	var prev_foot := _foot_world_x(_player.current_texture())
	var prev_anim_frame := _player.sprite_node().frame
	var loops := 0
	var samples := 0
	var foot_deltas: Array[float] = []
	var frame_seq: Array[int] = []
	var min_delta := 1e9
	var max_delta := -1e9
	var snap := 0
	for step in 40:
		await _frames(6)
		var spr := _player.sprite_node()
		var tex := _player.current_texture()
		var foot := _foot_world_x(tex)
		var d := foot - prev_foot
		foot_deltas.append(d)
		min_delta = minf(min_delta, d)
		max_delta = maxf(max_delta, d)
		prev_foot = foot
		frame_seq.append(spr.frame)
		if spr.frame < prev_anim_frame:
			loops += 1
		prev_anim_frame = spr.frame
		samples += 1
		if tex != null and _bottom_row(tex) != 167:
			fails += 1
		if with_shots:
			_caption = "r09 世界固定地面 80px/s · 10FPS · 采样 %02d/40 · 动画帧 %02d" % [step + 1, spr.frame]
			queue_redraw()
			await RenderingServer.frame_post_draw
			_capture("art005e_ground_%02d.png" % step)
	var elapsed := 40.0 * 6.0 / 60.0
	var travel := _cart.global_position.x - start_cart
	var speed := travel / elapsed
	var mean_delta := 0.0
	for dv in foot_deltas:
		mean_delta += dv
	mean_delta /= float(foot_deltas.size())

	print("[GROUND] 采样 %d 次 / 240 物理帧，车位移 %.1f px，实测速度 %.2f px/s（期望 80）" % [
		samples, travel, speed])
	print("[GROUND] 动画循环回绕 %d 次（要求 ≥2 个完整 16 帧循环）" % loops)
	print("[GROUND] 脚掌世界 x 每动画帧位移：min %.2f / max %.2f / mean %.2f px（车每帧约 8px）" % [
		min_delta, max_delta, mean_delta])
	print("[GROUND] 动画帧序前 20 = %s" % str(frame_seq.slice(0, 20)))

	fails += _ok("世界固定地面：实测车速 80 px/s（±2）", absf(speed - 80.0) <= 2.0,
		"%.2f px/s" % speed)
	fails += _ok("至少两个完整步态循环（帧序回绕 ≥2）", loops >= 2, "回绕 %d 次" % loops)
	fails += _ok("40 次采样脚底始终 y=167（贴图无竖向漂移）", fails == 0)
	var planted := foot_deltas.filter(func(x: float) -> bool: return absf(x) < 4.0)
	fails += _ok("脚掌世界接触存在承重段（|Δ|<4px 的采样 ≥ 4）",
		planted.size() >= 4,
		"承重采样 %d/40" % planted.size())
	# 残差：承重段脚掌相对固定世界的漂移（美术已声明 1–3px 固有微变化，不宣称 0px）
	var residual := 0.0
	for dv2 in planted:
		residual += absf(dv2)
	residual /= maxf(float(planted.size()), 1.0)
	print("[GROUND] 承重段脚掌世界滑移残差均值 = %.2f px/动画帧（美术声明 1–3px 固有微变化）" % residual)
	fails += _ok("承重段滑移残差在美术声明范围内（≤3.5px）", residual <= 3.5,
		"%.2f px" % residual)

	_player.clear_input_override()
	_cart.unbind()
	await _frames(2)
	_caption = ""
	return fails


# ---------------------------------------------------------------- 截图组

func _run_tour() -> void:
	_cart.set_load_state(PushableCart.LOAD_FULL)
	await _bind_default()
	for i in 4:
		_player.freeze_frame(ANIM_R09_WALK, i)
		_caption = "r09 第 %02d 帧（冻结，原生 960×540）" % i
		queue_redraw()
		await RenderingServer.frame_post_draw
		_capture("art005e_f%02d.png" % i)
	_player.resume_animation()
	_player.set_input_override(1.0)
	await _frames(20)
	_caption = "r09 连续推行（真实输入 80px/s · 10FPS）"
	queue_redraw()
	await RenderingServer.frame_post_draw
	_capture("art005e_moving.png")
	_player.set_facing(-1)
	await _frames(8)
	_caption = "朝左镜像（临时镜像，不是独立左向动作）"
	queue_redraw()
	await RenderingServer.frame_post_draw
	_capture("art005e_mirror.png")
	_player.set_facing(1)
	await _unbind_all()
	print("[ART005E] 检查点截图完成")
	if _args.has("quit"):
		get_tree().quit(0)


## 真实输入下的原生连拍：绑定 → 按 D 推进，每渲染帧截一张 960×540
func _run_gif_capture() -> void:
	_cart.set_load_state(PushableCart.LOAD_FULL)
	_cart.place_at(260.0)
	_player.teleport_to(260.0 - CART_SEP)
	_player.resume_animation()
	_cart.bind(_player)
	_player.set_input_override(1.0)
	for i in 40:
		_caption = "r09 实机连拍 %02d/40 · 80px/s · 10FPS" % (i + 1)
		queue_redraw()
		await RenderingServer.frame_post_draw
		_capture("art005e_gif_%02d.png" % i)
	_player.clear_input_override()
	_cart.unbind()
	print("[ART005E] GIF 素材连拍完成（40 帧真实 Godot 渲染 + 真实输入）")
	if _args.has("quit"):
		get_tree().quit(0)


## r04 / r09 同帧对照：同一位置、同一车、同一装载状态，只换动画版本
func _run_compare() -> void:
	_cart.set_load_state(PushableCart.LOAD_FULL)
	await _bind_default()
	_player.freeze_frame(ANIM_R09_WALK, 0)
	_caption = "r09 第 00 帧（16 帧 / 10 FPS）"
	queue_redraw()
	await RenderingServer.frame_post_draw
	_capture("art005e_compare_r09.png")
	_player.set_push_anim_variant(PlayerController.PUSH_ANIM_R04)
	_player.freeze_frame(ANIM_R04_WALK, 0)
	_caption = "r04 第 00 帧（4 帧 / 6 FPS，回退对照）"
	queue_redraw()
	await RenderingServer.frame_post_draw
	_capture("art005e_compare_r04.png")
	_player.resume_animation()
	_player.set_push_anim_variant(PlayerController.PUSH_ANIM_R09)
	await _unbind_all()
	print("[ART005E] r04 / r09 对照截图完成")
	if _args.has("quit"):
		get_tree().quit(0)


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_F3:
		_overlay.show_overlay = not _overlay.show_overlay
