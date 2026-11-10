extends Node2D
## ART-INTEGRATE-004 · 购物车分层与装载素材的实机验证场景（开发专用，不是正式关卡）
##
## 本场景只做一件事：**把 ART-RUNTIME-004 的四张 r03 分件按真实运行参数摆出来、
## 用 960×540 / Nearest / 1:1 拍原生截图、并把能变成数字的项全部量出来**。
##
## 刻意做对的几件事：
##   1) 人物与车不是"画上去的图"，而是直接实例化 `player.tscn` + `PushableCart`，
##      所以量到的手部间隙、锚点、镜像偏移就是游戏里的真实值；
##   2) 推车间距保持**逻辑值 80px**（冻结），美术静帧参考的 74px 只作为对照量一次，
##      **绝不通过改 side_offset 去凑画面**；
##   3) 空车 AE=0 是在**引擎里**做的：把 Back+Front 按同一锚点叠起来，
##      与 assets/ 里的 r02 原图逐像素比，差多少报多少；
##   4) 装载状态 EMPTY/HALF/FULL 只是**视觉开关**，不涉及库存、容量、结算、载重。
##
## 明确不做：购物、结算、库存、存档、TileSet、动画生成、推车行走动画、车轮动画。
##
## 命令行（写在 `--` 之后，须带 --dev-scene=art004）：
##   --art004-tour                八个检查点各截「叠加层关 / 开」两张后退出
##   --art004-state=empty|half|full|behind|overlap|mirror|push|wall  只渲染一个检查点
##   --art004-load=empty|half|full  指定装载状态（缺省 empty）
##   --art004-test                跑全部实机用例后退出（不截图）
##   --art004-door                门「进入 / 离开」回归（配合 Art004DoorWatcher）
##   --shot=name.png              单检查点截图
##   --quit                      完成后退出

const VIEW := Vector2(960, 540)
const GROUND_Y := 416.0
const SHOT_DIR := "res://tests/screenshots"
const FONT_PATH := "res://assets/ui/fonts/NotoSansSC-Variable.ttf"
const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")

# ---------------------------------------------------------------- 候选件（全部 1:1）
## r03 四件分件。画布统一 128×112，锚点统一 (64,104)，缩放统一 1:1。
const CART_TEX_R03_BACK := preload("res://assets/facilities/ART_FURN_103_r03_back_128x112.png")
const CART_TEX_R03_FRONT := preload("res://assets/facilities/ART_FURN_103_r03_front_128x112.png")
const CART_TEX_R03_CARGO_HALF := preload("res://assets/facilities/ART_FURN_103_r03_cargo_half_128x112.png")
const CART_TEX_R03_CARGO_FULL := preload("res://assets/facilities/ART_FURN_103_r03_cargo_full_128x112.png")
## 旧版整图，用于 AE=0 对照
const CART_TEX_R02 := preload("res://assets/facilities/ART_FURN_103_r02_tall_handle_128x112.png")

## 交付合同：画布 128×112，脚底锚点 (64,104)
const CART_ANCHOR := Vector2(64, 104)
## 逻辑推车间距：CORE-001B 冻结值。**不是美术静帧的 74。**
const CART_SEP := 80.0
## 美术交付说明里的静帧组合参考值，仅用于对照测量
const CART_SEP_ART := 74.0

## 墙：推车顶到这里必须整组停住
const WALL_X := 700.0
const WALL_W := 32.0
const WALL_H := 360.0

const C_BG := Color(0.32, 0.30, 0.28)
const C_BG_TOP := Color(0.38, 0.36, 0.33)
const C_FLOOR := Color(0.50, 0.42, 0.33)
const C_INK := Color(0.96, 0.97, 0.98)
const C_MUTED := Color(0.80, 0.83, 0.86)
const C_AMBER := Color(0.96, 0.72, 0.35)
const C_OK := Color(0.52, 0.84, 0.60)
const C_BAD := Color(0.91, 0.42, 0.38)

const STATES := ["empty", "half", "full", "behind", "overlap", "mirror", "push", "wall"]
const STATE_LABELS := {
	"empty": "① 空购物车：Back + Front（r03 分件）",
	"half": "② 半载：Back + Cargo_half + Front",
	"full": "③ 满载：Back + Cargo_full + Front",
	"behind": "④ 人物站在车后：Back 在人物之后，Front（近侧篮网）在人物之前",
	"overlap": "⑤ 人物与前景护栏重叠：近侧篮网正确遮挡腿部",
	"mirror": "⑥ 朝左镜像：整层水平翻转后各层仍对齐",
	"push": "⑦ 朝右推车：逻辑间距 80px，推速 80px/s",
	"wall": "⑧ 推车撞墙：整组停住，不穿墙",
}

var _args: Dictionary = {}
var _font: Font
var _player: PlayerController
var _cart: PushableCart
var _sensor: InteractionSensor
var _overlay: Art004Overlay
var _stage: Node2D

## 手部贴合实测数据，供叠加层与报告引用
var _hand: Dictionary = {}
## 装载状态（纯视觉）
var _load: StringName = PushableCart.LOAD_EMPTY
var _state := "empty"

## 场景里的门热点（供 --art004-door 用）
var _door: DoorInteractable


func _ready() -> void:
	_parse_args()
	_font = load(FONT_PATH)
	if _font == null:
		_font = ThemeDB.fallback_font

	_stage = Node2D.new()
	_stage.name = "Stage"
	add_child(_stage)

	# 车先入树：Back / Cargo 是 z=0，必须画在人物之前才能形成正确遮挡
	_cart = PushableCart.new()
	_cart.name = "Cart"
	_cart.ground_y = GROUND_Y
	_cart.world_left = 0.0
	_cart.world_right = VIEW.x
	# 本场景专门验证 r03 分件；r02 回退由 set_art_variant() 保留
	_cart.art_variant = PushableCart.ART_VARIANT_R03
	add_child(_cart)

	_player = PLAYER_SCENE.instantiate() as PlayerController
	_player.name = "Player"
	_player.ground_y = GROUND_Y
	add_child(_player)

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

	_apply_state(_state)
	queue_redraw()

	# Web 端没有命令行，只能靠控制台行断言"这一帧到底画的是什么"。
	# 这行日志把视觉版本、装载状态、图层构成一次说清楚：
	# 空载/半载/满载三个状态不会触发 bind，所以必须有这条独立日志。
	print("[ART004] 场景就绪 视觉=%s 装载=%s 图层=Back+Cargo+Front 锚点=(%d,%d) 画布=%dx%d 逻辑车长=%.0f" % [
		String(_cart.art_variant), String(_cart.load_state), int(CART_ANCHOR.x), int(CART_ANCHOR.y),
		int(CART_TEX_R03_BACK.get_width()), int(CART_TEX_R03_BACK.get_height()), _cart.cart_width])

	if _args.has("art004_tour"):
		await _run_tour()
	elif _args.has("art004_test"):
		await _run_tests()
	elif _args.has("art004_door"):
		await _run_door_test()
	elif _args.has("shot"):
		await _frames(6)
		_capture(String(_args["shot"]))
		if _args.has("quit"):
			get_tree().quit(0)


func _parse_args() -> void:
	# 先接住 SceneRouter 注入的参数（Web 端就是 URL query），再让命令行覆盖它
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
	if _args.has("art004_state"):
		_state = String(_args["art004_state"])
	if _args.has("art004_load"):
		_load = StringName(_args["art004_load"])


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


# ---------------------------------------------------------------- 画面搭建

func _apply_state(key: String) -> void:
	_state = key
	for c in _stage.get_children():
		_stage.remove_child(c)
		c.queue_free()
	_sensor.enabled = false
	if _cart.state == PushableCart.STATE_PUSHING:
		_cart.unbind()
	_cart.visible = false
	_cart.set_load_state(_load)
	_player.clear_input_override()

	match key:
		"empty":
			_build_empty()
		"half":
			_build_loaded(PushableCart.LOAD_HALF)
		"full":
			_build_loaded(PushableCart.LOAD_FULL)
		"behind":
			_build_behind()
		"overlap":
			_build_overlap()
		"mirror":
			_build_mirror()
		"push":
			await _build_push()
		"wall":
			await _build_wall_stop()
		_:
			_build_empty()

	queue_redraw()
	_overlay.queue_redraw()


## ① 空车：只有 Back + Front 两层
func _build_empty() -> void:
	_cart.visible = true
	_cart.set_load_state(PushableCart.LOAD_EMPTY)
	_cart.place_at(480.0)
	_player.teleport_to(820.0)
	_player.set_facing(1)


## ② / ③ 半载 / 满载
func _build_loaded(state: StringName) -> void:
	_cart.visible = true
	_cart.set_load_state(state)
	_cart.place_at(480.0)
	_player.teleport_to(820.0)
	_player.set_facing(1)


## ④ 人物站在车后：人物在车的正后方（x 相同），只有近侧篮网（Front）压住人
func _build_behind() -> void:
	_cart.visible = true
	_cart.set_load_state(PushableCart.LOAD_FULL)
	_cart.place_at(480.0)
	_player.teleport_to(480.0)
	_player.set_facing(1)


## ⑤ 人物与前景护栏重叠：人物站在篮网正前方，腿应当被近侧篮网压住
func _build_overlap() -> void:
	_cart.visible = true
	_cart.set_load_state(PushableCart.LOAD_FULL)
	_cart.place_at(480.0)
	# 站位稍微偏一点，让"腿被篮网压住"最容易看清
	_player.teleport_to(470.0)
	_player.set_facing(1)


## ⑥ 朝左镜像：整层翻转
func _build_mirror() -> void:
	_cart.visible = true
	_cart.set_load_state(PushableCart.LOAD_FULL)
	_cart.place_at(480.0)
	# 站到车右边 → 绑定时 side=+1 → 车整层翻转
	_player.teleport_to(480.0 + CART_SEP)
	_cart.bind(_player)
	_player.set_facing(-1)


## ⑦ 朝右推车：站到车左边 → side=-1 → 推
func _build_push() -> void:
	_cart.visible = true
	_cart.set_load_state(PushableCart.LOAD_FULL)
	_cart.place_at(480.0)
	_player.teleport_to(480.0 - CART_SEP)
	_cart.bind(_player)
	_player.set_input_override(1.0)
	await _frames(24)
	_player.clear_input_override()
	await _frames(2)


## ⑧ 推车撞墙
func _build_wall_stop() -> void:
	_cart.visible = true
	_cart.set_load_state(PushableCart.LOAD_FULL)
	_cart.place_at(560.0)
	_player.teleport_to(560.0 - CART_SEP)
	_cart.bind(_player)
	_player.set_input_override(1.0)
	for i in 300:
		await get_tree().physics_frame
		if _cart.blocks_at_wall > 0:
			break
	_player.clear_input_override()
	await _frames(4)


# ---------------------------------------------------------------- 背景

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
	_draw_wall()
	_draw_height_ruler()
	_draw_captions()


func _draw_wall() -> void:
	draw_rect(Rect2(WALL_X, GROUND_Y - WALL_H, WALL_W, WALL_H), Color(0.26, 0.28, 0.30), true, -1.0, false)
	draw_rect(Rect2(WALL_X, GROUND_Y - WALL_H, WALL_W, WALL_H), Color(0, 0, 0, 0.35), false, 2.0, false)
	for i in 6:
		var yy := GROUND_Y - 24.0 - float(i) * 56.0
		draw_line(Vector2(WALL_X + 4.0, yy), Vector2(WALL_X + WALL_W - 4.0, yy),
			Color(1, 1, 1, 0.10), 1.0)


## 右侧竖向标尺：每 32px 一格，每 64px 标一次
func _draw_height_ruler() -> void:
	var rx := 906.0
	draw_line(Vector2(rx, GROUND_Y), Vector2(rx, GROUND_Y - 232.0),
		Color(0.78, 0.70, 0.58, 0.55), 1.0)
	var h := 0
	while h <= 224:
		var y := GROUND_Y - float(h)
		var major := h % 64 == 0
		draw_line(Vector2(rx - (10.0 if major else 5.0), y), Vector2(rx, y),
			Color(0.78, 0.70, 0.58, 0.65), 1.0)
		if major:
			_text(rx - 14.0 - 14.0, y + 4.0, "%d" % h, 9, Color(0.90, 0.88, 0.84, 0.55))
		h += 32


func _draw_captions() -> void:
	match _state:
		"empty", "half", "full":
			var load_names := {"empty": "空载 EMPTY", "half": "半载 HALF", "full": "满载 FULL"}
			var load_txt: String = load_names[_state]
			_text(24, 40, STATE_LABELS[_state], 15, C_INK)
			_text(24, 62, "装载状态 %s（纯视觉，不涉及库存 / 容量 / 结算）· 车画布 128×112 锚点 (64,104)" % load_txt,
				12, C_MUTED)
			_text(24, 82, "半载与满载互斥：当前 cargo_half=%s cargo_full=%s" % [
				str(_cart.cargo_half_visible()), str(_cart.cargo_full_visible())], 11, C_OK)
		"behind", "overlap":
			_text(24, 40, STATE_LABELS[_state], 15, C_INK)
			_text(24, 62, "图层顺序 Back(z=0) → Cargo(z=0) → Player(z=0) → Front(z=1)", 12, C_MUTED)
			_text(24, 82, "近侧篮网始终压在人物之前 → 腿部被正确遮挡", 11, C_OK)
		"mirror":
			_text(24, 40, STATE_LABELS[_state], 15, C_INK)
			_text(24, 62, "玩家在车右侧 → side=+1 → 整层水平翻转（不是新画一张图）", 12, C_MUTED)
			_text(24, 82, "镜像只改绘制：碰撞盒 28×160 与世界坐标不变", 11, C_OK)
		"push":
			_text(24, 40, STATE_LABELS[_state], 15, C_INK)
			_text(24, 62, "逻辑间距 %.0f px（冻结值）· 推速 %.0f px/s · 反向拉速 %.0f px/s" % [
				CART_SEP, _cart.push_speed, _cart.pull_speed], 12, C_MUTED)
			_text(24, 82, "扶车姿态 r03 单帧；本轮**不做**扶车行走循环与车轮动画", 11, C_OK)
		"wall":
			_text(24, 40, STATE_LABELS[_state], 15, C_INK)
			_text(24, 62, "车右沿 %.0f ≤ 墙左沿 %.0f（撞墙停止，不穿墙）" % [
				_cart.global_position.x + _cart.cart_width * 0.5, WALL_X], 12,
				C_OK if _cart.global_position.x + _cart.cart_width * 0.5 <= WALL_X + 0.01 else C_BAD)


func _text(x: float, y: float, s: String, size: int, c: Color) -> void:
	if _font == null:
		return
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_rect(Rect2(x - 4, y - size, w + 8, size + 6), Color(0.06, 0.05, 0.04, 0.72), true, -1.0, false)
	draw_string(_font, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


# ---------------------------------------------------------------- 量测

## ART-RESET-001：_measure_hand / _hand_rows / _band_x / _top_row_y 已随角色贴图退役。
## 它们量的是「角色手部像素」到车把的间隙；没有角色像素就没有可量对象。
## 接新动画时按新的帧画布重写，不要恢复这里的旧实现。

# ---------------------------------------------------------------- 引擎内像素合成

## 把 Back + Front 按同一锚点叠成一张 RGBA 图（引擎内逐像素合成，不依赖外部脚本）
func _compose_back_front() -> Image:
	var back := CART_TEX_R03_BACK.get_image()
	var front := CART_TEX_R03_FRONT.get_image()
	var w := back.get_width()
	var h := back.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var b := back.get_pixel(x, y)
			var f := front.get_pixel(x, y)
			# Front 在上：不透明处取 Front，否则取 Back
			if f.a > 0.5:
				out.set_pixel(x, y, f)
			elif b.a > 0.5:
				out.set_pixel(x, y, b)
			else:
				out.set_pixel(x, y, Color(0, 0, 0, 0))
	return out


## 逐像素比较两张图，返回不同的像素数
func _count_diff(a: Image, b: Image) -> int:
	var diff := 0
	for y in mini(a.get_height(), b.get_height()):
		for x in mini(a.get_width(), b.get_width()):
			var pa := a.get_pixel(x, y)
			var pb := b.get_pixel(x, y)
			if absf(pa.r - pb.r) > 0.002 or absf(pa.g - pb.g) > 0.002 \
					or absf(pa.b - pb.b) > 0.002 or absf(pa.a - pb.a) > 0.002:
				diff += 1
	return diff


# ---------------------------------------------------------------- 自动化用例

func _run_tests() -> void:
	var fails := 0
	print("")
	print("========== ART-INTEGRATE-004 实机验收 ==========")

	# ---- A 图片合同：尺寸 / alpha 档位 / 包围盒
	print("[A] r03 四件分件像素合同")
	var contract := [
		["r03 back", CART_TEX_R03_BACK, Vector2i(128, 112), Rect2(16, 14, 82, 90)],
		["r03 front", CART_TEX_R03_FRONT, Vector2i(128, 112), Rect2(41, 36, 71, 45)],
		["r03 cargo_half", CART_TEX_R03_CARGO_HALF, Vector2i(128, 112), Rect2(49, 51, 56, 23)],
		["r03 cargo_full", CART_TEX_R03_CARGO_FULL, Vector2i(128, 112), Rect2(47, 40, 60, 34)],
	]
	for row in contract:
		var label: String = row[0]
		var tex: Texture2D = row[1]
		var want_size: Vector2i = row[2]
		var want_bb: Rect2 = row[3]
		var img := tex.get_image()
		var lv := {}
		for y in img.get_height():
			for x in img.get_width():
				lv[img.get_pixel(x, y).a8] = true
		var keys: Array = lv.keys()
		var bb := _alpha_bbox(img)
		fails += _ok("%s 画布 %d×%d / 可见 %d×%d / alpha %d 档" % [
			label, img.get_width(), img.get_height(),
			int(want_bb.size.x), int(want_bb.size.y), keys.size()],
			Vector2i(img.get_width(), img.get_height()) == want_size
			and keys.size() <= 2 and bb == want_bb,
			"实际 bbox=%s 档位=%s" % [str(bb), str(keys)])

	# ---- A2 内容归属：货物图必须真的有货，且半载 ≠ 满载
	print("[A2] 货物内容归属（半载 / 满载必须能区分）")
	var half_img := CART_TEX_R03_CARGO_HALF.get_image()
	var full_img := CART_TEX_R03_CARGO_FULL.get_image()
	var half_px := _opaque_count(half_img)
	var full_px := _opaque_count(full_img)
	fails += _ok("半载不透明像素 %d / 满载 %d（满载必须更多）" % [half_px, full_px],
		half_px > 0 and full_px > half_px)
	fails += _ok("半载与满载的像素内容不同（不是同一张图改个名）",
		_count_diff(half_img, full_img) > 0,
		"差异像素=%d" % _count_diff(half_img, full_img))
	# 半载/满载都必须在篮网（front）范围内，不许跑到车外面
	fails += _ok("半载 / 满载都落在篮网范围内（不越出前景护栏）",
		_overlaps_front(CART_TEX_R03_CARGO_HALF) and _overlaps_front(CART_TEX_R03_CARGO_FULL))

	# ---- B 锚点：四件必须共用同一锚点与画布
	print("[B] 锚点与坐标一致性")
	var bb_back := _alpha_bbox(CART_TEX_R03_BACK.get_image())
	var anchor_err := absf(bb_back.position.y + bb_back.size.y - CART_ANCHOR.y)
	fails += _ok("Back 可见底边落在锚点 y=%.0f（误差 %.1f px）" % [CART_ANCHOR.y, anchor_err],
		anchor_err < 0.51, "底边=%.1f" % (bb_back.position.y + bb_back.size.y))
	fails += _ok("四件分件画布统一 128×112", _all_canvas_equal())
	fails += _ok("车体逻辑长度仍是冻结值 96（画布 128 不算车长）", _cart.cart_width == 96.0)

	# ---- C 空车还原 AE=0：Back + Front == r02 原图
	print("[C] 空车还原：Back + Front 与 r02 原图的像素差异")
	var composed := _compose_back_front()
	var r02_img := CART_TEX_R02.get_image()
	var ae := _count_diff(composed, r02_img)
	fails += _ok("引擎内合成 Back+Front vs r02 → 差异像素 AE = %d（要求 0）" % ae,
		ae == 0, "r02 原图 %d×%d" % [r02_img.get_width(), r02_img.get_height()])
	# 合成结果与 r02 的可见范围也必须一致
	var comp_bb := _alpha_bbox(composed)
	var r02_bb := _alpha_bbox(r02_img)
	fails += _ok("合成可见范围 %s == r02 可见范围 %s" % [str(comp_bb), str(r02_bb)],
		comp_bb == r02_bb)

	# ---- D 装载状态：互斥、可见性正确
	print("[D] 装载状态（纯视觉）")
	_cart.set_load_state(PushableCart.LOAD_EMPTY)
	fails += _ok("EMPTY：两层货物都不可见",
		not _cart.cargo_half_visible() and not _cart.cargo_full_visible()
		and not _cart.cargo_visible())
	_cart.set_load_state(PushableCart.LOAD_HALF)
	fails += _ok("HALF：只有半载可见，满载不可见（互斥）",
		_cart.cargo_half_visible() and not _cart.cargo_full_visible())
	_cart.set_load_state(PushableCart.LOAD_FULL)
	fails += _ok("FULL：只有满载可见，半载不可见（互斥）",
		_cart.cargo_full_visible() and not _cart.cargo_half_visible())
	_cart.set_load_state(PushableCart.LOAD_EMPTY)

	# ---- E 手部贴合：ART-RESET-001 退役
	# 这一组量的是「角色手部像素」与车把的横向间隙。角色贴图已全部删除，
	# 没有手部像素可量，原断言作废（不是通过，是退役）。接新动画后再恢复。
	print("[E] 手部贴合：已退役（角色贴图于 ART-RESET-001 删除，无手部像素可量）")

	# ---- F 镜像 / 分层对齐（角色中轴量测已随贴图退役，只保留车体分层与碰撞不变式）
	print("[F] 镜像 / 分层对齐")
	_cart.place_at(480.0)
	_player.teleport_to(480.0 + CART_SEP)
	_cart.bind(_player)
	await _frames(2)
	var flipped := _cart.is_visual_flipped()
	fails += _ok("玩家在车右侧 → 整层翻转（flip_h=true）", flipped)
	var x_before := _player.global_position.x
	var coll_before := _player.collision_width()
	_player.set_facing(-1)
	_player.set_facing(1)
	fails += _ok("镜像只改绘制：碰撞盒宽 %.0f 不变，世界坐标 x 不变" % coll_before,
		_player.collision_width() == coll_before
		and absf(_player.global_position.x - x_before) < 0.01)
	_cart.unbind()
	await _frames(2)

	# ---- G 图层顺序：Back 在人物之后，Front 在人物之前
	print("[G] 图层顺序与遮挡")
	_cart.place_at(480.0)
	_player.teleport_to(480.0)
	_player.set_facing(1)
	await _frames(2)
	fails += _ok("近侧篮网 Front 常驻可见（不再依赖横向重叠才显示）",
		_cart.front_layer_visible())
	fails += _ok("车节点在人物之前入树（z=0 的 Back/Cargo 才能画在人物之后）",
		_cart.layer_order_is_valid())

	# 遮挡实测：ART-RESET-001 退役
	# 这一项要「人物不透明像素 ∩ 近侧篮网不透明像素」，角色贴图已删，交集恒为空。
	# Front 常驻可见与车节点入树顺序仍在上方断言，图层顺序本身没被放松。
	print("[G] 人物 × 篮网像素交叠：已退役（角色贴图于 ART-RESET-001 删除）")

	# ---- H 交互回归
	print("[H] 购物车交互回归")
	_cart.place_at(480.0)
	_player.teleport_to(480.0 + CART_SEP)
	_cart.bind(_player)
	fails += _ok("绑定后 side=%+d 间距=%.0f（冻结值 80）" % [_cart.side, _cart.side_offset],
		_cart.state == PushableCart.STATE_PUSHING
		and absf(absf(_player.global_position.x - _cart.global_position.x) - CART_SEP) < 0.01)
	_cart.unbind()
	await _frames(2)
	fails += _ok("解绑后人物恢复正常移动（state=%s）" % String(_cart.state),
		_cart.state == PushableCart.STATE_PARKED and _cart.player == null)
	# PARKED 穿行：车没有物理体，人物能直接从它身上走过去
	_cart.place_at(480.0)
	var walk := await _walk(420.0, 560.0, 200, 1.0)
	fails += _ok("PARKED 人物从停放的车身上穿过（%.0f → %.0f）" % [
		float(walk["start"]), float(walk["end"])],
		bool(walk["passed"]) and int(walk["stall"]) < 3)
	# PUSHING 联动
	_cart.place_at(480.0)
	_player.teleport_to(480.0 - CART_SEP)
	_cart.bind(_player)
	var cart_x0 := _cart.global_position.x
	var player_x0 := _player.global_position.x
	_player.set_input_override(1.0)
	await _frames(30)
	_player.clear_input_override()
	var cart_dx := _cart.global_position.x - cart_x0
	var player_dx := _player.global_position.x - player_x0
	fails += _ok("PUSHING 车与人物同步移动（车 %+.0f / 人 %+.0f px，间距仍 %.0f）" % [
		cart_dx, player_dx, absf(_player.global_position.x - _cart.global_position.x)],
		absf(cart_dx - player_dx) < 0.6
		and absf(absf(_player.global_position.x - _cart.global_position.x) - CART_SEP) < 0.6
		and absf(_cart.last_speed - 80.0) < 0.6)
	_cart.unbind()
	await _frames(4)
	# 撞墙
	_cart.place_at(560.0)
	_player.teleport_to(560.0 - CART_SEP)
	_cart.bind(_player)
	_player.set_input_override(1.0)
	for i in 300:
		await get_tree().physics_frame
		if _cart.blocks_at_wall > 0:
			break
	_player.clear_input_override()
	var cart_right := _cart.global_position.x + _cart.cart_width * 0.5
	fails += _ok("推车撞墙：车右沿 %.0f ≤ 墙左沿 %.0f（不穿墙）" % [cart_right, WALL_X],
		_cart.blocks_at_wall > 0 and cart_right <= WALL_X + 0.01)
	_cart.unbind()
	await _frames(2)

	# ---- I 门与提示
	print("[I] 交互提示与门")
	_cart.place_at(480.0)
	_player.teleport_to(140.0)
	_sensor.enabled = true
	await _frames(6)
	var door_target := _sensor.current
	fails += _ok("靠近门 → 提示「E 进入」", door_target == _door and door_target != null
		and door_target.prompt_text() == "E 进入",
		"target=%s" % (door_target.name if door_target else "null"))
	_player.teleport_to(480.0)
	await _frames(6)
	var cart_target := _sensor.current
	fails += _ok("靠近车 → 提示「E 推购物车」（车优先级 20 > 门 10）",
		cart_target == _cart.hotspot and cart_target != null
		and cart_target.prompt_text() == "E 推购物车",
		"target=%s" % (cart_target.name if cart_target else "null"))

	# ---- J r02 回退能力
	print("[J] r02 回退能力")
	_cart.set_art_variant(PushableCart.ART_VARIANT_R02)
	fails += _ok("可切回 r02 单图版本（当前 %s）" % String(_cart.art_variant),
		_cart.art_variant == PushableCart.ART_VARIANT_R02)
	_cart.set_art_variant(PushableCart.ART_VARIANT_R03)
	fails += _ok("可切回 r03 分层版本（当前 %s）" % String(_cart.art_variant),
		_cart.art_variant == PushableCart.ART_VARIANT_R03)
	fails += _ok("切换版本后近侧篮网仍然常驻可见",
		_cart.front_layer_visible())

	print("[T] 汇总：%s" % ("全部符合预期" if fails == 0 else "%d 项不符合预期" % fails))
	print("==============================================")
	if _args.has("quit"):
		get_tree().quit(0 if fails == 0 else 1)


## 从 x0 走到 x1，记录终点与最长停滞帧数
func _walk(x0: float, x1: float, max_frames: int, dir: float) -> Dictionary:
	_player.set_collision_width(28.0)
	_player.teleport_to(x0)
	_player.set_input_override(dir)
	await get_tree().physics_frame
	var start := _player.global_position.x
	var stall := 0
	var best := 0
	var prev := start
	for i in max_frames:
		await get_tree().physics_frame
		var x := _player.global_position.x
		if absf(x - prev) < 0.05:
			stall += 1
			best = maxi(best, stall)
		else:
			stall = 0
		prev = x
		if dir > 0.0 and x >= x1:
			break
		if dir < 0.0 and x <= x1:
			break
	var endpos := _player.global_position.x
	_player.clear_input_override()
	var reached := (endpos >= x1 - 2.0) if dir > 0.0 else (endpos <= x1 + 2.0)
	return {"start": start, "end": endpos, "passed": reached, "stall": best}


# ---------------------------------------------------------------- 门回归

func _run_door_test() -> void:
	print("")
	print("========== ART-INTEGRATE-004 门进出回归 ==========")
	# 观察者挂在 root 上：切场景会销毁本场景，协程活不到切换完成那一刻
	var watcher := Art004DoorWatcher.new()
	watcher.name = "DoorWatcher"
	get_tree().root.add_child(watcher)
	watcher.start()
	# 走到门前按 E
	_player.teleport_to(140.0)
	_sensor.enabled = true
	await _frames(8)
	var t := _sensor.current
	print("[DOOR-TEST] 靠近门 target=%s prompt=%s" % [
		t.name if t else "null", t.prompt_text() if t else "-"])
	_sensor.request_interact()


# ---------------------------------------------------------------- 截图组

func _run_tour() -> void:
	_overlay.show_overlay = false
	for key in STATES:
		_apply_state(String(key))
		await _frames(8)
		await RenderingServer.frame_post_draw
		_capture("art004_%s.png" % key)
		_overlay.show_overlay = true
		_overlay.queue_redraw()
		await _frames(2)
		await RenderingServer.frame_post_draw
		_capture("art004_%s_debug.png" % key)
		_overlay.show_overlay = false
	print("[ART004] 截图完成，见 tests/screenshots/art004_*.png")
	if _args.has("quit"):
		get_tree().quit(0)


# ---------------------------------------------------------------- 叠加层用的绘制

func debug_draw(cv: CanvasItem) -> void:
	var ink := Color(0.95, 0.95, 0.94)
	if _cart.visible:
		var b := _cart.body_rect()
		cv.draw_rect(b, Color(0.45, 0.85, 0.95, 0.9), false, 1.0)
		# 车画布（128×112）与实际车长的差别也画出来，防止有人拿画布当碰撞
		cv.draw_rect(Rect2(_cart.global_position - CART_ANCHOR, Vector2(128, 112)),
			Color(0.45, 0.85, 0.95, 0.28), false, 1.0)
		# 四层各自的范围：Back / Cargo / Front 分色画出来，肉眼就能核对层级
		var off := _cart.get_cart_offset()
		var flip := _cart.is_visual_flipped()
		_draw_tex_rect(cv, CART_TEX_R03_BACK, _cart.global_position, off, flip,
			Color(0.55, 0.95, 0.60, 0.85))
		_draw_tex_rect(cv, CART_TEX_R03_FRONT, _cart.global_position, off, flip,
			Color(1.00, 0.55, 0.40, 0.95))
		if _cart.cargo_half_visible():
			_draw_tex_rect(cv, CART_TEX_R03_CARGO_HALF, _cart.global_position, off, flip,
				Color(0.98, 0.80, 0.35, 0.85))
		if _cart.cargo_full_visible():
			_draw_tex_rect(cv, CART_TEX_R03_CARGO_FULL, _cart.global_position, off, flip,
				Color(0.75, 0.60, 1.00, 0.85))

	# ART-RESET-001：角色无贴图，不画可见框

	var cr := _player.collision_rect()
	var cworld := Rect2(_player.global_position + cr.position, cr.size)
	cv.draw_rect(cworld, Color(1.0, 0.42, 0.38, 0.85), false, 1.0)

	# 数值统一写成左下角图例，避免标签压在人身上
	var lines := PackedStringArray([
		"红=角色碰撞 %.0f×%.0f（角色贴图已删，无可见框）" % [cr.size.x, cr.size.y],
		"青=车可见 96×90（细线=画布 128×112，不是车长）",
		"绿=Back 层　橙红=Front 层（近侧篮网）",
	])
	var ly := VIEW.y - 78.0
	for ln in lines:
		_label(cv, 24.0, ly, ln, 10, Color(0.93, 0.93, 0.9))
		ly += 15.0

	if _hand.has("gap"):
		var y0: float = float(_hand["y0"])
		var y1: float = float(_hand["y1"])
		cv.draw_line(Vector2(0, y0), Vector2(VIEW.x, y0), Color(0.96, 0.72, 0.35, 0.45), 1.0)
		cv.draw_line(Vector2(0, y1), Vector2(VIEW.x, y1), Color(0.96, 0.72, 0.35, 0.45), 1.0)
		var cb: Vector2 = _hand["char_band"]
		var tb: Vector2 = _hand["cart_band"]
		var left_side := int(_hand["side"]) < 0
		var hand_x: float = cb.y if left_side else cb.x
		var cart_x: float = tb.x if left_side else tb.y
		cv.draw_line(Vector2(hand_x, y0 - 6), Vector2(hand_x, y1 + 6),
			Color(1.0, 0.78, 0.45, 0.95), 1.0)
		cv.draw_line(Vector2(cart_x, y0 - 6), Vector2(cart_x, y1 + 6),
			Color(0.55, 0.90, 0.98, 0.95), 1.0)
		_label(cv, 24.0, VIEW.y - 30.0, "手部水平间隙 %+.1f px（正=没穿模，负=重叠）" % float(_hand["gap"]),
			11, ink)

	var note := "调试叠加层（F3）· 正式截图看无叠加层版本"
	var nw := _font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x if _font else 240.0
	_label(cv, VIEW.x - 24.0 - nw, VIEW.y - 14.0, note, 10, Color(0.9, 0.9, 0.88, 0.7))


## 把一张贴图的实际不透明范围画成框（按当前 offset / flip）
func _draw_tex_rect(cv: CanvasItem, tex: Texture2D, node_pos: Vector2, offset: Vector2,
		flip: bool, col: Color) -> void:
	var img := tex.get_image()
	var used := img.get_used_rect()
	var w := img.get_width()
	var lo := 1 << 30
	var hi := -(1 << 30)
	var top := 1 << 30
	var bot := -(1 << 30)
	for y in range(used.position.y, used.position.y + used.size.y):
		for x in range(used.position.x, used.position.x + used.size.x):
			if img.get_pixel(x, y).a > 0.5:
				var col_x := (w - 1 - x) if flip else x
				var wx := int(node_pos.x + offset.x) + col_x
				var wy := node_pos.y + offset.y + float(y)
				lo = mini(lo, wx)
				hi = maxi(hi, wx + 1)
				top = mini(top, int(wy))
				bot = maxi(bot, int(wy) + 1)
	if hi > lo:
		cv.draw_rect(Rect2(float(lo), float(top), float(hi - lo), float(bot - top)), col, false, 1.0)


func _label(cv: CanvasItem, x: float, y: float, s: String, size: int, c: Color) -> void:
	if _font == null:
		return
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	cv.draw_rect(Rect2(x - 2, y - size, w + 4, size + 3), Color(0.05, 0.045, 0.04, 0.8), true, -1.0, false)
	cv.draw_string(_font, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


# ---------------------------------------------------------------- 杂项

## 该世界坐标点是否落在近侧篮网（Front 层）的不透明像素上
func _cart_front_covers_point(p: Vector2) -> bool:
	var img := CART_TEX_R03_FRONT.get_image()
	var off := _cart.get_cart_offset()
	var flip := _cart.is_visual_flipped()
	var w := img.get_width()
	var lx := int(p.x - _cart.global_position.x - off.x)
	var ly := int(p.y - _cart.global_position.y - off.y)
	if lx < 0 or ly < 0 or lx >= w or ly >= img.get_height():
		return false
	if flip:
		lx = w - 1 - lx
	return img.get_pixel(lx, ly).a > 0.5


## 货物图是否与篮网（前景护栏）区域相交——必须相交才说明货物确实被网罩住
func _overlaps_front(cargo: Texture2D) -> bool:
	var ci := cargo.get_image()
	var fi := CART_TEX_R03_FRONT.get_image()
	for y in ci.get_height():
		for x in ci.get_width():
			if ci.get_pixel(x, y).a > 0.5 and fi.get_pixel(x, y).a > 0.5:
				return true
	return false


func _all_canvas_equal() -> bool:
	var w := CART_TEX_R03_BACK.get_width()
	var h := CART_TEX_R03_BACK.get_height()
	for t in [CART_TEX_R03_FRONT, CART_TEX_R03_CARGO_HALF, CART_TEX_R03_CARGO_FULL]:
		var tex: Texture2D = t
		if tex.get_width() != w or tex.get_height() != h:
			return false
	return true


func _opaque_count(img: Image) -> int:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				n += 1
	return n


func _alpha_bbox(img: Image) -> Rect2:
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a8 > 127:
				lo.x = mini(lo.x, x)
				lo.y = mini(lo.y, y)
				hi.x = maxi(hi.x, x)
				hi.y = maxi(hi.y, y)
	if hi.x < lo.x:
		return Rect2()
	return Rect2(Vector2(float(lo.x), float(lo.y)),
		Vector2(float(hi.x - lo.x + 1), float(hi.y - lo.y + 1)))


func _ok(label: String, cond: bool, extra: String = "") -> int:
	print("[T] %s %s%s" % ["通过" if cond else "失败", label, ("  ← " + extra) if extra != "" else ""])
	return 0 if cond else 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _capture(filename: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	var err := get_viewport().get_texture().get_image().save_png("%s/%s" % [SHOT_DIR, filename])
	print("[ART004] 截图 %-30s err=%d" % [filename, err])


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo:
		if k.keycode == KEY_F3:
			_overlay.show_overlay = not _overlay.show_overlay
