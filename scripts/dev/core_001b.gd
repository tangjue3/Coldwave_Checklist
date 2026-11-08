extends Node2D
## CORE-001B · 门 / 货架交互与购物车推行状态（开发实验场景）
##
## 这是**开发实验场景**，不是正式关卡。它只验证三件事：
##   1) 门 / 货架 = 背景层 + Area2D 热点，按 E 触发，不参与物理阻挡；
##   2) 购物车 = PARKED / PUSHING 两态，**停放时不是硬墙**，推行时与角色是一套刚体组合；
##   3) 以上交互共用一套轻量契约（Interactable / InteractionSensor），不为两个物件造框架。
##
## 明确不做：购物、结算、货币、容量、装载、库存持久化、剧情分支、存档、正式 TileSet、
## 双行走线、跳跃、动画。本场景里所有图形都是占位矩形，正式 PNG 由美术另行发包。
##
## 命令行（写在 `--` 之后，须同时带 --dev-scene=core001b）：
##   --core-tour                 渲染 5 个检查点，各截「叠加层开 / 叠加层关」两张后退出
##   --core-state=idle|door|deco|shelf|cart|aisle|wall   只渲染一个检查点
##   --core-test                 跑 9 组交互与推车用例（不切场景）后退出
##   --core-test-door            门的真实场景切换 + 连按保护，成功后由 watcher 退出
##   --shot=name.png             单检查点截图
##   --quit                      完成后退出

const VIEW := Vector2(960, 540)
const GROUND_Y := 0.0
const SHOT_DIR := "res://tests/screenshots"
const FONT_PATH := "res://assets/ui/fonts/NotoSansSC-Variable.ttf"
const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")

# ---------------------------------------------------------------- 已批准尺度（SCALE-001）
const CHAR_VISIBLE_H := 160
const CHAR_COLLIDE_W := 28
const TILE := 32

## 住宅门：外框 96×192，门框 8、门楣 8 → 净 80×184
const HOUSE_X := 180.0
const DOOR_W := 96.0
const DOOR_H := 192.0
const DOOR_JAMB := 8.0
const DOOR_HEAD := 8.0

## 装饰门：尺寸与住宅门一致，只是不允许交互
const DECO_X := 420.0

## 超市入口：192×224，玻璃收边 4 → 净 184×216
const ENTRY_X := 620.0
const ENTRY_W := 192.0
const ENTRY_H := 224.0
const ENTRY_REVEAL := 4.0

## 货架 96×192 四层；两段货架之间是 192 的主通道
const SHELF1_X := 940.0
const SHELF_W := 96.0
const SHELF_H := 192.0
const SHELF_LAYERS := 4
const SHELF_POST := 6.0
const SHELF_TOP := 8.0
const SHELF_BASE := 16.0
const SHELF_BEAM := 6.0
const AISLE_W := 192.0
const SHELF2_X := SHELF1_X + SHELF_W + AISLE_W          # 1228
const CART_CENTER := SHELF1_X + SHELF_W + AISLE_W * 0.5  # 1132
## 货架热点比货架本体左右各宽 48，用来制造「车与货架热点重叠」的真实优先级场景
const SHELF_PAD := 48.0

## 撞墙测试用的实体墙：推车顶到这里必须整组停住。
## 刻意放在货架右侧的空地上（1284..1700 之间无遮挡），这样推车不会从货架身上穿过去。
const WALL_X := 1700.0
const WALL_W := 32.0
const WALL_H := 360.0

const WORLD_LEFT := 0.0
const WORLD_RIGHT := 2000.0

const C_GRAY_BG := Color(0.55, 0.575, 0.60)
const C_GRAY_FLOOR := Color(0.34, 0.36, 0.38)
const C_MARKET_BG := Color(0.36, 0.28, 0.21)
const C_MARKET_FLOOR := Color(0.58, 0.46, 0.33)
const C_SHELF := Color(0.62, 0.65, 0.68)
const C_DOOR := Color(0.72, 0.66, 0.56)
const C_DECO := Color(0.56, 0.51, 0.45)
const C_WALL := Color(0.30, 0.32, 0.34)
const C_INK := Color(0.96, 0.97, 0.98)
const C_MUTED := Color(0.80, 0.83, 0.86)
const C_AMBER := Color(0.96, 0.72, 0.35)
const C_OK := Color(0.52, 0.84, 0.60)
const C_BAD := Color(0.91, 0.42, 0.38)
const C_CART := Color(0.70, 0.76, 0.82)

## 检查点：一个截图 = 一个站位 + 一个交互状态
const STATES := [
	{"key": "idle", "x": 120.0, "label": "① 静止 · 灰底轮廓"},
	{"key": "door", "x": 228.0, "label": "② 住宅门热点：E 进入"},
	{"key": "deco", "x": 468.0, "label": "③ 装饰门：无热点、无提示"},
	{"key": "shelf", "x": 988.0, "label": "④ 货架热点：E 查看"},
	{"key": "cart", "x": 1052.0, "label": "⑤ 购物车 PARKED：可走过去"},
	{"key": "aisle", "x": 1210.0, "label": "⑥ 车与货架热点重叠：车优先"},
	{"key": "wall", "x": 1292.0, "label": "⑦ 推车撞墙：整组停住"},
]

var _args: Dictionary = {}
var _font: Font
var _player: PlayerController
var _camera: FollowCamera
var _overlay: Core001BOverlay
var _sensor: InteractionSensor
var _cart: PushableCart

var _house_door: DoorInteractable
var _deco_door: DoorInteractable
var _entry_door: DoorInteractable
var _shelf1_hot: ShelfInteractable
var _shelf2_hot: ShelfInteractable

var _hud: CanvasLayer
var _hud_zone: Label
var _hud_state: Label
var _hud_note: Label
var _hud_toast: Label

var _toast_text := ""
var _toast_t := 0.0
var _flip_center_right := 0.0
var _flip_center_left := 0.0
var _flip_probe_done := false


func _ready() -> void:
	_parse_args()
	_font = load(FONT_PATH)
	if _font == null:
		_font = ThemeDB.fallback_font

	_build_solids()
	_build_cart()          # 车先入树：Back 层（z=0）才能画在玩家之前
	_spawn_player()
	_build_hotspots()
	_build_sensor()
	_build_camera()
	_build_overlay()
	_build_hud()
	_measure()
	queue_redraw()

	if _args.has("core_tour"):
		await _run_tour()
	elif _args.has("core_test"):
		await _run_tests()
	elif _args.has("core_test_door"):
		await _run_door_test()
	else:
		await _apply_state(String(_args.get("core_state", "idle")))
		if _args.has("shot"):
			await RenderingServer.frame_post_draw
			_capture(String(_args["shot"]))

	if _args.has("quit") and not _args.has("core_test_door"):
		get_tree().quit(0)


func _parse_args() -> void:
	# 先接住 SceneRouter 注入的参数（Web 端就是 URL query），再让命令行覆盖它
	var injected: Variant = SceneRouter.dev_args if SceneRouter else null
	if injected is Dictionary:
		for k in injected:
			_args[k] = injected[k]
	for raw in OS.get_cmdline_user_args():
		var a: String = raw
		if not a.begins_with("--"):
			continue
		var kv := a.substr(2).split("=", true, 1)
		_args[kv[0].replace("-", "_")] = kv[1] if kv.size() > 1 else true


# ---------------------------------------------------------------- 世界搭建

func _build_solids() -> void:
	# 只有真正站在行走线上的东西才是实体。门 / 入口 / 货架一律不建碰撞体。
	_solid(WORLD_LEFT - 32.0, -400.0, 32.0, 400.0, "world_l")
	_solid(WORLD_RIGHT, -400.0, 32.0, 400.0, "world_r")
	# 撞墙测试墙：推车顶到这里必须停
	_solid(WALL_X, -WALL_H, WALL_W, WALL_H, "block_wall")


func _solid(x: float, y_top: float, w: float, h: float, tag: String) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "Solid_" + tag
	body.position = Vector2(x + w * 0.5, y_top + h * 0.5)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	shape.shape = rect
	body.add_child(shape)
	add_child(body)
	return body


func _build_cart() -> void:
	_cart = PushableCart.new()
	_cart.name = "Cart"
	_cart.ground_y = GROUND_Y
	_cart.world_left = WORLD_LEFT
	_cart.world_right = WORLD_RIGHT
	add_child(_cart)
	_cart.place_at(CART_CENTER)


func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate() as PlayerController
	_player.name = "Player"
	_player.ground_y = GROUND_Y
	_player.move_speed = 100.0
	add_child(_player)
	_player.teleport_to(120.0)
	_player.facing_changed.connect(_on_facing_changed)


func _build_hotspots() -> void:
	# 有效门：按 E 走 SceneRouter 切到已有空场景
	_house_door = _make_door("HouseDoor", HOUSE_X, DOOR_W, DOOR_H, &"shelter", true, "住宅门")
	# 装饰门：尺寸一样，但 interactive=false → 不显示提示、按 E 无作用
	_deco_door = _make_door("DecoDoor", DECO_X, DOOR_W, DOOR_H, &"", false, "装饰门")
	_entry_door = _make_door("EntryDoor", ENTRY_X, ENTRY_W, ENTRY_H, &"supermarket", true, "超市入口")

	_shelf1_hot = _make_shelf("ShelfHotspot1", SHELF1_X, "货架 A · 四层 · 每层净高 37px")
	_shelf2_hot = _make_shelf("ShelfHotspot2", SHELF2_X, "货架 B · 四层 · 每层净高 37px")


func _make_door(node_name: String, x: float, w: float, h: float,
		target: StringName, interactive: bool, label: String) -> DoorInteractable:
	var d := DoorInteractable.new()
	d.name = node_name
	d.target_scene = target
	d.interactive = interactive
	d.door_label = label
	d.interact_priority = 10
	d.position = Vector2(x + w * 0.5, -h * 0.5)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	# 热点比门框略宽一圈：站在门前一小步就要能按到，而不是必须精确踩在门洞中
	r.size = Vector2(w + 24.0, h)
	cs.shape = r
	d.add_child(cs)
	add_child(d)
	return d


func _make_shelf(node_name: String, shelf_x: float, note: String) -> ShelfInteractable:
	var s := ShelfInteractable.new()
	s.name = node_name
	s.note = note
	s.interact_priority = 5
	s.position = Vector2(shelf_x + SHELF_W * 0.5, -SHELF_H * 0.5)
	s.inspected.connect(_on_shelf_inspected)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(SHELF_W + SHELF_PAD * 2.0, SHELF_H)
	cs.shape = r
	s.add_child(cs)
	add_child(s)
	return s


func _on_shelf_inspected(note: String, _anchor: Vector2) -> void:
	_toast_text = "货架反馈：" + note
	_toast_t = 2.5


func _build_sensor() -> void:
	_sensor = InteractionSensor.new()
	_sensor.name = "Sensor"
	_sensor.actor_path = NodePath("../Player")
	add_child(_sensor)


func _build_camera() -> void:
	_camera = FollowCamera.new()
	_camera.name = "FollowCam"
	_camera.target_path = NodePath("../Player")
	_camera.look_offset = Vector2(0, -64)
	_camera.dead_zone = Vector2(56, 28)
	_camera.smoothing = 8.0
	_camera.limit_left = int(WORLD_LEFT - VIEW.x * 0.5)
	_camera.limit_right = int(WORLD_RIGHT + VIEW.x * 0.5)
	_camera.limit_top = int(-VIEW.y * 2.0)
	_camera.limit_bottom = int(VIEW.y * 2.0)
	add_child(_camera)
	_camera.make_current()
	_camera.snap_to_target()


func _build_overlay() -> void:
	_overlay = Core001BOverlay.new()
	_overlay.name = "Overlay"
	_overlay.player_path = NodePath("../Player")
	_overlay.cart_path = NodePath("../Cart")
	_overlay.sensor_path = NodePath("../Sensor")
	add_child(_overlay)


func _on_facing_changed(_dir: int) -> void:
	_refresh_hud()


# ---------------------------------------------------------------- 绘制世界（占位）

func _draw() -> void:
	_draw_zone(WORLD_LEFT - VIEW.x, ENTRY_X, C_GRAY_BG, C_GRAY_FLOOR, 24.0, "A · 住宅区（门 = 背景 + 热点）")
	_draw_zone(ENTRY_X, WORLD_RIGHT + VIEW.x, C_MARKET_BG, C_MARKET_FLOOR, ENTRY_X + 16.0,
		"B · 超市（货架 / 购物车）")
	_draw_ruler()
	_draw_house_door()
	_draw_deco_door()
	_draw_entry()
	_draw_shelf(SHELF1_X)
	_draw_shelf(SHELF2_X)
	_draw_wall()
	_draw_labels()


func _draw_zone(x0: float, x1: float, bg: Color, floor_c: Color, title_x: float, title: String) -> void:
	draw_rect(Rect2(x0, -600.0, x1 - x0, 600.0), bg, true, -1.0, false)
	draw_rect(Rect2(x0, GROUND_Y, x1 - x0, 240.0), floor_c, true, -1.0, false)
	draw_line(Vector2(x0, GROUND_Y), Vector2(x1, GROUND_Y), Color(0, 0, 0, 0.45), 1.0)
	_text(title_x, GROUND_Y - 280.0, title, 13, Color(1, 1, 1, 0.34))
	var x := x0
	while x < x1:
		draw_line(Vector2(x, GROUND_Y + 2.0),
			Vector2(x, GROUND_Y + (10.0 if int(x) % 128 == 0 else 6.0)),
			Color(0, 0, 0, 0.22), 1.0)
		x += TILE


func _draw_ruler() -> void:
	var x := 32.0
	while x < ENTRY_X - 40.0:
		var major := int(x) % 128 == 0
		draw_line(Vector2(x, GROUND_Y + 78.0), Vector2(x, GROUND_Y + (94.0 if major else 86.0)),
			Color(1, 1, 1, 0.55), 1.0)
		if major:
			_text(x - 12.0, GROUND_Y + 108.0, "%d" % int(x), 9, Color(1, 1, 1, 0.62))
		x += TILE
	_text(32.0, GROUND_Y + 128.0, "1 tile = 32px", 9, Color(1, 1, 1, 0.62))


func _draw_house_door() -> void:
	var x := HOUSE_X
	var top := GROUND_Y - DOOR_H
	var net_w := DOOR_W - DOOR_JAMB * 2.0
	var net_h := DOOR_H - DOOR_HEAD
	draw_rect(Rect2(x, top, DOOR_W, DOOR_H), C_DOOR, true, -1.0, false)
	draw_rect(Rect2(x + DOOR_JAMB, GROUND_Y - net_h, net_w, net_h), Color(0.07, 0.08, 0.09), true, -1.0, false)
	draw_rect(Rect2(x + DOOR_JAMB, GROUND_Y - net_h, net_w, net_h), Color(1, 1, 1, 0.25), false, 1.0, false)
	draw_rect(Rect2(x + DOOR_JAMB, GROUND_Y - 2.0, net_w, 2.0), Color(1, 1, 1, 0.35), true, -1.0, false)
	# 把手：给"这是门"一个可读线索，也给正式美术一个位置参考
	draw_circle(Vector2(x + DOOR_W - DOOR_JAMB - 12.0, GROUND_Y - 96.0), 3.0, Color(0.95, 0.88, 0.66))
	_text(x - 6.0, -262.0, "住宅门 96×192（净 80×184）", 11, C_INK)
	_text(x - 6.0, -248.0, "背景层 + 热点 · 可交互", 10, C_AMBER)


func _draw_deco_door() -> void:
	var x := DECO_X
	var top := GROUND_Y - DOOR_H
	var net_w := DOOR_W - DOOR_JAMB * 2.0
	var net_h := DOOR_H - DOOR_HEAD
	draw_rect(Rect2(x, top, DOOR_W, DOOR_H), C_DECO, true, -1.0, false)
	draw_rect(Rect2(x + DOOR_JAMB, GROUND_Y - net_h, net_w, net_h), Color(0.13, 0.13, 0.13), true, -1.0, false)
	# 装饰门画满横板，视觉上就是"封住的/布景门"，和周遭一致但没有把手
	for i in 4:
		var yy := top + 24.0 + float(i) * 40.0
		draw_line(Vector2(x + DOOR_JAMB, yy), Vector2(x + DOOR_W - DOOR_JAMB, yy),
			Color(0.42, 0.38, 0.33), 2.0)
	_text(x - 6.0, -262.0, "装饰门（同尺寸）", 11, C_MUTED)
	_text(x - 6.0, -248.0, "无热点提示 · 按 E 无作用", 10, C_BAD)


func _draw_entry() -> void:
	var x := ENTRY_X
	var top := GROUND_Y - ENTRY_H
	var net_w := ENTRY_W - ENTRY_REVEAL * 2.0
	draw_rect(Rect2(x, top, ENTRY_W, ENTRY_H), Color(0.20, 0.22, 0.25), true, -1.0, false)
	draw_rect(Rect2(x + ENTRY_REVEAL, GROUND_Y - 216.0, net_w, 216.0), Color(0.14, 0.11, 0.08), true, -1.0, false)
	draw_rect(Rect2(x, top, ENTRY_REVEAL, ENTRY_H), Color(0.55, 0.66, 0.74, 0.7), true, -1.0, false)
	draw_rect(Rect2(x + ENTRY_W - ENTRY_REVEAL, top, ENTRY_REVEAL, ENTRY_H),
		Color(0.55, 0.66, 0.74, 0.7), true, -1.0, false)
	draw_rect(Rect2(x + ENTRY_REVEAL, GROUND_Y - 130.0, net_w, 2.0), Color(0.55, 0.66, 0.74, 0.45), true, -1.0, false)
	_text(x - 2.0, -262.0, "超市入口 192×224（净 184×216）", 11, C_INK)
	_text(x - 2.0, -248.0, "背景层 + 热点 · 可交互", 10, C_AMBER)


func _draw_shelf(x: float) -> void:
	var top := GROUND_Y - SHELF_H
	var usable := SHELF_W - SHELF_POST * 2.0
	var per := (SHELF_H - SHELF_TOP - SHELF_BASE - (SHELF_LAYERS - 1) * SHELF_BEAM) / float(SHELF_LAYERS)
	draw_rect(Rect2(x, top, SHELF_POST, SHELF_H), C_SHELF, true, -1.0, false)
	draw_rect(Rect2(x + SHELF_W - SHELF_POST, top, SHELF_POST, SHELF_H), C_SHELF, true, -1.0, false)
	draw_rect(Rect2(x, top, SHELF_W, SHELF_TOP), C_SHELF, true, -1.0, false)
	draw_rect(Rect2(x, GROUND_Y - SHELF_BASE, SHELF_W, SHELF_BASE), C_SHELF.darkened(0.2), true, -1.0, false)
	var y := top + SHELF_TOP
	for i in SHELF_LAYERS:
		draw_rect(Rect2(x + SHELF_POST, y, usable, per), Color(0.10, 0.09, 0.08), true, -1.0, false)
		if i < SHELF_LAYERS - 1:
			draw_rect(Rect2(x + SHELF_POST, y + per, usable, SHELF_BEAM), C_SHELF, true, -1.0, false)
		y += per + SHELF_BEAM
	for i in SHELF_LAYERS:
		var iy := top + SHELF_TOP + i * (per + SHELF_BEAM) + per - 32.0
		for k in 2:
			draw_rect(Rect2(x + SHELF_POST + 1.0 + k * 32.0, iy, 30.0, 31.0),
				Color(0.68, 0.56, 0.38), true, -1.0, false)


func _draw_wall() -> void:
	draw_rect(Rect2(WALL_X, GROUND_Y - WALL_H, WALL_W, WALL_H), C_WALL, true, -1.0, false)
	draw_rect(Rect2(WALL_X, GROUND_Y - WALL_H, WALL_W, WALL_H), Color(0, 0, 0, 0.35), false, 2.0, false)
	for i in 6:
		var yy := GROUND_Y - 24.0 - float(i) * 56.0
		draw_line(Vector2(WALL_X + 4.0, yy), Vector2(WALL_X + WALL_W - 4.0, yy),
			Color(1, 1, 1, 0.10), 1.0)
	_text(WALL_X - 4.0, GROUND_Y - WALL_H - 14.0, "实体墙（推车到此停住）", 10, C_MUTED)


func _draw_labels() -> void:
	# 主通道净宽：画在货架顶上，不占地面
	var y := -SHELF_H - 22.0
	_dim_h(SHELF1_X + SHELF_W, SHELF2_X, y, "主通道净宽 %d" % int(AISLE_W), C_OK)
	_text(SHELF1_X + SHELF_W + 6.0, y - 8.0, "%.1f tile" % (AISLE_W / TILE), 9, C_MUTED)


func _dim_h(x1: float, x2: float, y: float, label: String, c: Color) -> void:
	draw_line(Vector2(x1, y), Vector2(x2, y), c, 1.0)
	draw_line(Vector2(x1, y - 4.0), Vector2(x1, y + 4.0), c, 1.0)
	draw_line(Vector2(x2, y - 4.0), Vector2(x2, y + 4.0), c, 1.0)
	_text_center((x1 + x2) * 0.5, y + 14.0, label, 9, c)


func _text(x: float, y: float, s: String, size: int, c: Color) -> void:
	if _font == null:
		return
	draw_string(_font, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


func _text_center(cx: float, y: float, s: String, size: int, c: Color) -> void:
	if _font == null:
		return
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(_font, Vector2(cx - w * 0.5, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


# ---------------------------------------------------------------- HUD

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "HUD"
	add_child(_hud)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.07, 0.82)
	bg.position = Vector2.ZERO
	bg.size = Vector2(VIEW.x, 30)
	_hud.add_child(bg)

	_mk_label("CORE-001B · 门 / 货架交互与购物车推行（开发实验场景，不含购物结算）",
		Vector2(14, 6), Vector2(760, 20), 13, C_INK)
	_hud_zone = _mk_label("", Vector2(VIEW.x - 240, 7), Vector2(226, 20), 12, C_AMBER,
		HORIZONTAL_ALIGNMENT_RIGHT)
	_hud_toast = _mk_label("", Vector2(14, VIEW.y - 92), Vector2(940, 22), 12, C_AMBER)
	_hud_state = _mk_label("", Vector2(14, VIEW.y - 62), Vector2(940, 24), 12, C_INK)
	_hud_note = _mk_label("", Vector2(14, VIEW.y - 40), Vector2(940, 20), 11, C_MUTED)
	_refresh_hud()


## HUD 用 Label。字体显式指定，不依赖 Theme 传播：Web 端没有系统字体兜底。
func _mk_label(text: String, pos: Vector2, size: Vector2, fs: int, color: Color,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	if _font != null:
		l.add_theme_font_override("font", _font)
	_hud.add_child(l)
	return l


func _refresh_hud() -> void:
	if _hud_state == null or _player == null:
		return
	var zone := "A 住宅区"
	if _player.global_position.x >= ENTRY_X:
		zone = "B 超市"
	_hud_zone.text = zone

	var cart_x := _cart.global_position.x if _cart else 0.0
	var cart_txt := "车 -"
	if _cart != null:
		cart_txt = "车 %s @%.0f" % [String(_cart.state), cart_x]
		if _cart.state == PushableCart.STATE_PUSHING:
			cart_txt += " v=%.0f side=%+d 间距=%.0f" % [_cart.last_speed, _cart.side, _cart.side_offset]
	_hud_state.text = "x=%d  vx=%.0f  朝向=%s  状态=%s  ｜  %s  ｜  热点 %s" % [
		int(_player.global_position.x), _player.velocity.x,
		"右" if _player.facing > 0 else "左", String(_player.state),
		cart_txt, _target_text(),
	]
	_hud_note.text = "门/货架=背景层+Area2D 热点（不阻挡）；车 PARKED 无碰撞体、可走过，PUSHING 与角色成刚体组合 ｜ 推速 80 / 反向 40 / 行走 100 ｜ E 交互  F3 叠加层"

	_hud_toast.text = _toast_text


func _target_text() -> String:
	if _sensor == null:
		return "-"
	if _sensor.current == null:
		return "无"
	return "%s「%s」" % [_sensor.current.name, _sensor.current.prompt_text()]


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t = maxf(0.0, _toast_t - delta)
		if _toast_t <= 0.0:
			_toast_text = ""
	_refresh_hud()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_F3 and _overlay:
			_overlay.show_overlay = not _overlay.show_overlay


# ---------------------------------------------------------------- 量测

func _measure() -> void:
	var vis := _player.visible_bbox()
	var coll := _player.collision_rect()
	var net_w := DOOR_W - DOOR_JAMB * 2.0
	var net_h := DOOR_H - DOOR_HEAD
	print("")
	print("========== CORE-001B 实机量测 ==========")
	print("[CORE] 可见 %d×%d @(%.0f,%.0f)  碰撞 %d×%d  脚底误差 = %.1f" % [
		int(vis.size.x), int(vis.size.y), vis.position.x, vis.position.y,
		int(coll.size.x), int(coll.size.y), absf(vis.position.y + vis.size.y)])
	print("[CORE] 住宅门 净 %d×%d  净宽余量 %d（单侧 %d）  门内头顶余 %d" % [
		int(net_w), int(net_h), int(net_w - coll.size.x), int((net_w - coll.size.x) * 0.5),
		int(net_h - coll.size.y)])
	print("[CORE] 购物车间距=%.0f（脚底原点到车心）  推速=%.0f 反向=%.0f 行走=%.0f" % [
		_cart.side_offset, _cart.push_speed, _cart.pull_speed, _player.move_speed])
	print("[CORE] 车包围盒 宽 %.0f 高 %.0f；停放时无物理体（is_instance_valid(body)=%s）" % [
		_cart.cart_width, _cart.cart_height, str(_cart.get_node_or_null("Body") != null)])
	# 镜像偏移实测：翻转前后可见框中心必须重合
	var x_before := _player.global_position.x
	var coll_before := _player.collision_rect()
	_player.set_facing(1)
	var vr := _player.visible_bbox()
	_player.set_facing(-1)
	var vl := _player.visible_bbox()
	_player.set_facing(1)
	_flip_center_right = vr.position.x + vr.size.x * 0.5
	_flip_center_left = vl.position.x + vl.size.x * 0.5
	_flip_probe_done = true
	var coll_after := _player.collision_rect()
	print("[CORE] 朝向绘制偏移 flip_offset=%s → 可见框中心 右 %.1f / 左 %.1f，差 %.1f px（0 = 已对齐）" % [
		str(_player.flip_draw_offset), _flip_center_right, _flip_center_left,
		absf(_flip_center_right - _flip_center_left)])
	print("[CORE] 镜像补偿只作用于绘制：碰撞盒 %s → %s，节点 x %.1f → %.1f（必须完全不变）" % [
		str(coll_before), str(coll_after), x_before, _player.global_position.x])
	print("========================================")


# ---------------------------------------------------------------- 检查点

func _apply_state(key: String) -> void:
	var st := _find_state(key)
	_player.clear_input_override()
	if _cart.state == PushableCart.STATE_PUSHING:
		_cart.unbind()
	_cart.place_at(CART_CENTER)
	_player.teleport_to(float(st["x"]))
	_player.set_facing(1)
	_camera.snap_to_target()
	await _frames(4)
	queue_redraw()


func _find_state(key: String) -> Dictionary:
	for s in STATES:
		if String(s["key"]) == key:
			return s
	push_warning("[CORE] 未知检查点 %s，回退到 idle" % key)
	return STATES[0]


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _place(x: float) -> void:
	_player.clear_input_override()
	_player.teleport_to(x)
	_camera.snap_to_target()


func _shot(name_: String) -> Error:
	return get_viewport().get_texture().get_image().save_png("%s/%s" % [SHOT_DIR, name_])


func _capture(filename: String) -> void:
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var err := _shot(filename)
	print("[CORE] 截图 %-34s err=%d" % [filename, err])


# ---------------------------------------------------------------- 巡览

func _run_tour() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	var keys := PackedStringArray(["door_prompt", "shelf_prompt", "cart_bind", "cart_pass", "cart_wall"])
	var fails := 0
	for key in keys:
		await _setup_shot(key)
		await RenderingServer.frame_post_draw
		var err := _shot("core001b_%s.png" % key)
		if err != OK:
			fails += 1
		# 同一画面再来一张去掉调试叠加层的「游戏视图」
		_overlay.show_overlay = false
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		err = _shot("core001b_%s_clean.png" % key)
		if err != OK:
			fails += 1
		_overlay.show_overlay = true
		await get_tree().process_frame
		print("[CORE] 截图 %-30s err=%d" % [key, err])
	print("[CORE] 巡览完成：%d 组（每组 叠加层开/关 各一张），失败 %d" % [keys.size(), fails])


func _setup_shot(key: String) -> void:
	match key:
		"door_prompt":
			_cart.place_at(CART_CENTER)
			_place(228.0)
			await _frames(6)
		"shelf_prompt":
			_cart.place_at(CART_CENTER)
			_place(988.0)
			await _frames(6)
			_sensor.request_interact()
			await _frames(2)
		"cart_bind":
			_cart.place_at(CART_CENTER)
			_place(1052.0)
			await _frames(6)
			_sensor.request_interact()
			_player.set_input_override(1.0)
			await _frames(26)
		"cart_pass":
			if _cart.state == PushableCart.STATE_PUSHING:
				_cart.unbind()
			_cart.place_at(CART_CENTER)
			_place(CART_CENTER)     # 人就站在车的位置：检验前后两层遮挡
			_player.set_facing(1)
			await _frames(6)
		"cart_wall":
			if _cart.state == PushableCart.STATE_PUSHING:
				_cart.unbind()
			_cart.place_at(1480.0)
			_place(1400.0)
			await _frames(4)
			_sensor.request_interact()
			_player.set_input_override(1.0)
			for i in 240:
				await get_tree().physics_frame
				if _cart.blocks_at_wall > 0:
					break
			await _frames(6)


# ---------------------------------------------------------------- 自动化测试

func _run_tests() -> void:
	var fails := 0
	print("")
	print("========== CORE-001B 实机测试 ==========")
	print("[T] 基准：人物可见 %d / 碰撞 %d | 门净 80×184 | 货架 96×192 四层 | 车 96×96 | 通道 192" % [
		CHAR_VISIBLE_H, CHAR_COLLIDE_W])

	# ---- T1 门：靠近出现提示，离开消失
	_cart.place_at(CART_CENTER)
	_place(HOUSE_X + DOOR_W * 0.5)
	await _frames(5)
	var near := _sensor.current
	var ok1 := near == _house_door and near != null and near.prompt_text() == "E 进入"
	fails += _ok("T1a 住宅门范围内 → 提示「E 进入」", ok1,
		"target=%s prompt=%s" % [near.name if near else "null", near.prompt_text() if near else "-"])
	await RenderingServer.frame_post_draw
	_capture("core001b_door_prompt.png")
	_overlay.show_overlay = false
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_capture("core001b_door_prompt_clean.png")
	_overlay.show_overlay = true

	_place(860.0)
	await _frames(5)
	fails += _ok("T1b 走出范围 → 提示消失", _sensor.current == null,
		"target=%s" % (_sensor.current.name if _sensor.current else "null"))

	# ---- T2 装饰门：同尺寸、无热点提示
	_place(DECO_X + DOOR_W * 0.5)
	await _frames(6)
	fails += _ok("T2a 装饰门范围内 → 无提示", _sensor.current == null,
		"target=%s" % (_sensor.current.name if _sensor.current else "null"))
	await RenderingServer.frame_post_draw
	_capture("core001b_deco_no_hint.png")
	var c2 := _sensor.interact_count
	_sensor.request_interact()
	fails += _ok("T2b 装饰门按 E → 无任何作用", _sensor.interact_count == c2 and _deco_door.last_error == OK)

	# ---- T3 热点范围外按 E：无作用
	_place(860.0)
	await _frames(5)
	var c3 := _sensor.interact_count
	var r3 := _sensor.request_interact()
	fails += _ok("T3 范围外按 E → 不产生任何交互", r3 == null and _sensor.interact_count == c3,
		"返回 %s" % (r3.name if r3 else "null"))

	# ---- T4 货架：提示 + 反馈 + 不被卡
	_place(SHELF1_X + SHELF_W * 0.5)
	await _frames(6)
	var sh := _sensor.current
	fails += _ok("T4a 货架范围内 → 提示「E 查看」",
		sh == _shelf1_hot and sh != null and sh.prompt_text() == "E 查看",
		"target=%s" % (sh.name if sh else "null"))
	var before_toast := _toast_text
	var r4 := _sensor.request_interact()
	fails += _ok("T4b 按 E → 输出查看反馈（不开采购界面）",
		r4 == _shelf1_hot and _toast_text != "" and _toast_text.begins_with("货架反馈"),
		"toast=%s (前:%s)" % [_toast_text, before_toast])

	await _frames(2)
	await RenderingServer.frame_post_draw
	_capture("core001b_shelf_prompt.png")
	_overlay.show_overlay = false
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_capture("core001b_shelf_prompt_clean.png")
	_overlay.show_overlay = true

	var w4: Dictionary = await _walk(850.0, 1120.0, 220, 1.0)
	fails += _ok("T4c 从货架前水平走过 → 不被卡住",
		bool(w4["passed"]) and int(w4["stall"]) < 3,
		"%.0f → %.0f 停滞 %d 帧" % [float(w4["start"]), float(w4["end"]), int(w4["stall"])])

	# ---- T5 车 PARKED：左右两侧都能走过去，不是硬墙
	_cart.place_at(CART_CENTER)
	var w5a: Dictionary = await _walk(1010.0, 1300.0, 240, 1.0)
	fails += _ok("T5a 从左穿过停放的车 → 通过",
		bool(w5a["passed"]) and int(w5a["stall"]) < 3,
		"%.0f → %.0f 停滞 %d" % [float(w5a["start"]), float(w5a["end"]), int(w5a["stall"])])
	var w5b: Dictionary = await _walk(1300.0, 1010.0, 240, -1.0)
	fails += _ok("T5b 从右穿过停放的车 → 通过",
		bool(w5b["passed"]) and int(w5b["stall"]) < 3,
		"%.0f → %.0f 停滞 %d" % [float(w5b["start"]), float(w5b["end"]), int(w5b["stall"])])

	# ---- T6 绑定 / 推行 / 停放 / 再绑定
	_cart.place_at(CART_CENTER)
	_place(1052.0)
	await _frames(6)
	await RenderingServer.frame_post_draw
	_capture("core001b_cart_bind_before.png")
	var t6 := _sensor.current
	fails += _ok("T6a 靠近停放的车 → 提示「E 推购物车」",
		t6 == _cart.hotspot and t6 != null and t6.prompt_text() == "E 推购物车",
		"target=%s prompt=%s" % [t6.name if t6 else "null", t6.prompt_text() if t6 else "-"])
	_sensor.request_interact()
	fails += _ok("T6b 按 E → PARKED→PUSHING，侧位=%+d 间距=%.0f" % [_cart.side, _cart.side_offset],
		_cart.state == PushableCart.STATE_PUSHING and _cart.player == _player
		and absf(absf(_player.global_position.x - _cart.global_position.x) - _cart.side_offset) < 0.01,
		"player=%.0f cart=%.0f" % [_player.global_position.x, _cart.global_position.x])

	var cart_x0 := _cart.global_position.x
	_player.set_input_override(1.0)
	# 先在通道内抓图（车还在两段货架之间），再跑满 60 帧做速度断言
	await _frames(30)
	await RenderingServer.frame_post_draw
	_capture("core001b_cart_bind.png")
	_overlay.show_overlay = false
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_capture("core001b_cart_bind_clean.png")
	_overlay.show_overlay = true
	await _frames(30)
	var pushed := _cart.global_position.x - cart_x0
	fails += _ok("T6c 推行 → 速度 %.1f px/s，位移 %.0f px" % [_cart.last_speed, pushed],
		absf(_cart.last_speed - 80.0) < 0.6 and pushed > 40.0 and absf(_player.velocity.x - 80.0) < 0.6)

	_player.clear_input_override()
	await _frames(3)
	var park_x := _cart.global_position.x
	var r6c := _sensor.request_interact()
	fails += _ok("T6d 再按 E → PUSHING→PARKED，车停在 x=%.0f" % park_x,
		r6c == _cart.hotspot and _cart.state == PushableCart.STATE_PARKED and _cart.player == null)
	await _frames(20)
	fails += _ok("T6e 停放后车不漂移（20 帧内位移 %.2f px）" % absf(_cart.global_position.x - park_x),
		absf(_cart.global_position.x - park_x) < 0.01)

	var r6d := _sensor.request_interact()
	fails += _ok("T6f 循环：再按 E 可重新绑定（state=%s）" % String(_cart.state),
		r6d == _cart.hotspot and _cart.state == PushableCart.STATE_PUSHING)

	var side_before := _cart.side
	_player.set_input_override(-1.0)
	await _frames(30)
	fails += _ok("T6g 反向输入 → 侧位不变（%+d→%+d），速度 %.1f 不瞬移" % [
		side_before, _cart.side, _cart.last_speed],
		_cart.side == side_before and _cart.last_speed <= 40.6 and _cart.state == PushableCart.STATE_PUSHING)
	_player.clear_input_override()
	await _frames(2)

	# 停放后从车上走过：车不挡人，仅靠前后两层做"侧身绕过"的观感
	_cart.place_at(CART_CENTER)
	_place(CART_CENTER)
	await _frames(4)
	await RenderingServer.frame_post_draw
	_capture("core001b_cart_pass.png")
	_overlay.show_overlay = false
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_capture("core001b_cart_pass_clean.png")
	_overlay.show_overlay = true

	# ---- T7 撞墙：整组停住，不穿墙，可解绑
	_cart.unbind()
	_cart.place_at(1480.0)
	_place(1400.0)
	await _frames(5)
	_sensor.request_interact()
	var ok7a := _cart.state == PushableCart.STATE_PUSHING
	_player.set_input_override(1.0)
	var blocked := false
	for i in 300:
		await get_tree().physics_frame
		if _cart.blocks_at_wall > 0:
			blocked = true
			break
	_player.clear_input_override()
	var cart_right := _cart.global_position.x + _cart.cart_width * 0.5
	fails += _ok("T7a 推车顶到实体墙 → 整组停住（车右沿 %.0f ≤ 墙 %.0f）" % [cart_right, WALL_X],
		ok7a and blocked and cart_right <= WALL_X + 0.01)
	await _frames(4)
	await RenderingServer.frame_post_draw
	_capture("core001b_cart_wall.png")
	_overlay.show_overlay = false
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_capture("core001b_cart_wall_clean.png")
	_overlay.show_overlay = true

	var wall_player_x := _player.global_position.x
	var r7 := _sensor.request_interact()
	fails += _ok("T7b 撞墙后仍可按 E 解绑（state=%s）" % String(_cart.state),
		r7 == _cart.hotspot and _cart.state == PushableCart.STATE_PARKED)
	_player.set_input_override(-1.0)
	await _frames(40)
	var back := wall_player_x - _player.global_position.x
	_player.clear_input_override()
	await _frames(2)
	fails += _ok("T7c 解绑后可自由后退 %.0f px（未被锁死）" % back, back > 20.0)

	# ---- T8 镜像偏移 / 脚底 / 坐标不变
	var vis := _player.visible_bbox()
	fails += _ok("T8a 脚底误差 %.2f px" % absf(vis.position.y + vis.size.y),
		absf(vis.position.y + vis.size.y) < 0.5)
	var x_before := _player.global_position.x
	var coll_before := _player.collision_width()
	var coll_h_before := _player.collision_height()
	_player.set_facing(1)
	var vr := _player.visible_bbox()
	_player.set_facing(-1)
	var vl := _player.visible_bbox()
	var cr := vr.position.x + vr.size.x * 0.5
	var cl := vl.position.x + vl.size.x * 0.5
	fails += _ok("T8b 朝左镜像 → 可见框中心 右 %.1f / 左 %.1f（差 %.1f）" % [cr, cl, absf(cr - cl)],
		absf(cr - cl) < 0.51)
	fails += _ok("T8c 镜像补偿不碰到碰撞盒与世界坐标",
		absf(_player.collision_width() - coll_before) < 0.01
		and absf(_player.collision_height() - coll_h_before) < 0.01
		and absf(_player.global_position.x - x_before) < 0.01,
		"碰撞 %.0f×%.0f  x=%.1f" % [_player.collision_width(), _player.collision_height(), _player.global_position.x])
	_player.set_facing(1)

	# ---- T9 多热点重叠：稳定优先级
	_cart.place_at(CART_CENTER)
	_place(1210.0)
	await _frames(6)
	var cands := _sensor.candidates()
	var stable := true
	for i in 12:
		await get_tree().physics_frame
		if _sensor.current != _cart.hotspot:
			stable = false
	fails += _ok("T9a 车与货架热点重叠（%d 个候选）→ 选车（优先级 20 > 5）" % cands.size(),
		cands.size() >= 2 and _sensor.current == _cart.hotspot)
	fails += _ok("T9b 连续 12 帧目标不抖", stable)
	var c9 := _sensor.interact_count
	_sensor.request_interact()
	fails += _ok("T9c 按 E 只触发一个（计数 +%d）" % (_sensor.interact_count - c9),
		_sensor.interact_count == c9 + 1 and _cart.state == PushableCart.STATE_PUSHING)
	_cart.unbind()

	# ---- T10 相机沿用 CORE-001A 参数
	_cart.place_at(CART_CENTER)
	_place(700.0)
	await _frames(4)
	fails += _ok("T10 相机死区 %.0f×%.0f / 平滑 %.1f 未改动" % [
		_camera.dead_zone.x, _camera.dead_zone.y, _camera.smoothing],
		absf(_camera.dead_zone.x - 56.0) < 0.01 and absf(_camera.smoothing - 8.0) < 0.01)

	print("[T] 汇总：%s（失败 %d 项）" % ["全部符合预期" if fails == 0 else "存在不符合预期项", fails])
	print("========================================")
	get_tree().quit(0 if fails == 0 else 1)


func _ok(label: String, cond: bool, extra: String = "") -> int:
	print("[T] %s %s%s" % ["通过" if cond else "失败", label, ("  ← " + extra) if extra != "" else ""])
	return 0 if cond else 1


## 从 x0 走到 x1（dir=+1 向右 / -1 向左），记录终点与最长停滞帧数
func _walk(x0: float, x1: float, max_frames: int, dir: float) -> Dictionary:
	_player.set_collision_width(CHAR_COLLIDE_W)
	_player.teleport_to(x0)
	_camera.snap_to_target()
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


# ---------------------------------------------------------------- 门切换测试

func _run_door_test() -> void:
	print("")
	print("========== CORE-001B 门切换测试 ==========")
	_cart.place_at(CART_CENTER)
	_place(HOUSE_X + DOOR_W * 0.5)
	await _frames(6)
	var t := _sensor.current
	print("[DOOR-TEST] 靠近有效门 target=%s prompt=%s" % [
		t.name if t else "null", t.prompt_text() if t else "-"])

	# watcher 挂在 root 上：本场景会被切走销毁，只有 root 的子树能活到切换完成
	var watcher := DoorSwitchWatcher.new()
	watcher.name = "DoorWatcher"
	get_tree().root.add_child(watcher)
	watcher.start(String(SceneRouter.PATHS[&"shelter"]), &"shelter", "core001b_door_after.png")

	var before := SceneRouter.change_count
	var a := _sensor.request_interact()
	var b := _sensor.request_interact()   # 同一帧连按：必须被本地挡掉
	print("[DOOR-TEST] 首次派发=%s 连按第二次=%s 切换次数 +%d（期望 +1）" % [
		a.name if a else "null", b.name if b else "null", SceneRouter.change_count - before])
	if a == null or b != null or SceneRouter.change_count - before != 1:
		print("[DOOR-TEST] 失败：门必须一次性，且连按不能重复加载")
		get_tree().quit(1)
