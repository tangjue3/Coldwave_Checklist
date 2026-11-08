extends Node2D
## CORE-001A · 角色移动底座 + ART-RUNTIME-001 单帧接入实验场景
##
## 这是**开发实验场景**，不是正式关卡：
##   - 世界是一条横向长条，分三段检查区：灰底轮廓 / 暖色超市 / 冷色街景；
##   - 按已批准的生产尺寸摆等比例占位（住宅门 96×192、超市入口 192×224、
##     货架 96×192、购物车 96、主通道 192），用来跑通"可见宽度 vs 碰撞尺寸"的对照；
##   - 占位全部用矩形与标尺画出来，不是正式美术资源，也不进 assets/。
##
## 明确不做：购物 / 货币 / 建造 / 物资消耗 / 剧情 / 存档 / 正式 TileSet / 动画。
##
## 命令行（写在 `--` 之后，须同时带 --dev-scene=core001a）：
##   --core-tour                 依次渲染 5 个检查点并各截一张 960×540 原图后退出
##   --core-state=idle|door|aisle|market|street   只渲染一个检查点
##   --core-test-door            自动走过住宅门 + 加宽碰撞做阻挡对照，打印日志
##   --core-test-camera          自动横移，打印相机死区/滞后数据
##   --shot=name.png             单检查点截图文件名
##   --quit                      完成后退出

const VIEW := Vector2(960, 540)
const GROUND_Y := 0.0
const SHOT_DIR := "res://tests/screenshots"
const FONT_PATH := "res://assets/ui/fonts/NotoSansSC-Variable.ttf"

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")

# ---------------------------------------------------------------- 已批准尺度
# SCALE-001 报告批准版：角色可见高 160 / tile 32 / 住宅门 96×192（净 80×184）/
# 超市入口 192×224 / 货架 96×192 四层 / 购物车长 96 / 主通道 192。
const CHAR_VISIBLE_H := 160
const CHAR_COLLIDE_W := 28          # 实机起测值，允许按报告微调
const TILE := 32

const DOOR_X := 300.0
const DOOR_W := 96.0
const DOOR_H := 192.0
const DOOR_JAMB := 8.0
const DOOR_HEAD := 8.0

const ENTRY_X := 640.0
const ENTRY_W := 192.0
const ENTRY_H := 224.0
const ENTRY_REVEAL := 4.0

const SHELF_W := 96.0
const SHELF_H := 192.0
const SHELF_LAYERS := 4
const SHELF_POST := 6.0
const SHELF_TOP := 8.0
const SHELF_BASE := 16.0
const SHELF_BEAM := 6.0

const SHELF1_X := 900.0
const AISLE_W := 192.0
const SHELF2_X := SHELF1_X + SHELF_W + AISLE_W   # 1188
const CART_W := 96.0
const CART_H := 96.0
const CART_X := SHELF1_X + SHELF_W + (AISLE_W - CART_W) * 0.5   # 1044

const WORLD_LEFT := 0.0
const WORLD_RIGHT := 2400.0
const STREET_X := 1800.0

const C_GRAY_BG := Color(0.55, 0.575, 0.60)
const C_GRAY_FLOOR := Color(0.34, 0.36, 0.38)
const C_MARKET_BG := Color(0.36, 0.28, 0.21)
const C_MARKET_FLOOR := Color(0.58, 0.46, 0.33)
const C_STREET_BG := Color(0.46, 0.53, 0.60)
const C_STREET_FLOOR := Color(0.80, 0.85, 0.89)
const C_SHELF := Color(0.62, 0.65, 0.68)
const C_DOOR := Color(0.72, 0.66, 0.56)
const C_CART := Color(0.66, 0.72, 0.78)
const C_INK := Color(0.96, 0.97, 0.98)
const C_MUTED := Color(0.80, 0.83, 0.86)
const C_AMBER := Color(0.96, 0.72, 0.35)
const C_OK := Color(0.52, 0.84, 0.60)
const C_WARN := Color(0.95, 0.78, 0.42)
const C_BAD := Color(0.91, 0.42, 0.38)

## 检查点：一个截图 = 一个站位 + 朝向 + 可选走动
const STATES := [
	{"key": "idle", "x": 180.0, "facing": 1, "walk": false, "label": "① 静止角色 · 灰底轮廓（1:1 原始像素）"},
	{"key": "door", "x": 336.0, "facing": 1, "walk": true, "label": "② 走动接门 · 住宅门 96×192（净 80×184）"},
	{"key": "aisle", "x": 1018.0, "facing": 1, "walk": false, "label": "③ 超市主通道 192 · 购物车 96"},
	{"key": "market", "x": 866.0, "facing": 1, "walk": false, "label": "④ 暖色超市 · 货架 96×192 四层"},
	{"key": "street", "x": 1960.0, "facing": -1, "walk": false, "label": "⑤ 冷色街景 · 朝左翻转（临时，仅供测试）"},
]

var _args: Dictionary = {}
var _font: Font
var _player: PlayerController
var _camera: FollowCamera
var _overlay: CoreOverlay
var _hud: CanvasLayer
var _hud_state: Label
var _hud_zone: Label
var _hud_note: Label
var _door_solids: Array[StaticBody2D] = []


func _ready() -> void:
	_parse_args()
	_font = load(FONT_PATH)
	if _font == null:
		_font = ThemeDB.fallback_font

	_build_colliders()
	_spawn_player()
	_build_camera()
	_build_overlay()
	_build_hud()
	_measure_and_report()
	queue_redraw()

	if _args.has("core_tour"):
		await _run_tour()
	elif _args.has("core_test"):
		await _run_tests()
	else:
		_apply_state(String(_args.get("core_state", "idle")))
		# 单点查看时跑几帧让速度/状态进入 walk，然后松手停住，避免截图时人物还在跑
		for i in 10:
			await get_tree().physics_frame
		_player.clear_input_override()
		for i in 3:
			await get_tree().process_frame
		if _args.has("shot"):
			await RenderingServer.frame_post_draw
			_capture(String(_args["shot"]))

	if _args.has("quit"):
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

func _build_colliders() -> void:
	# 碰撞分两层，这是本轮最重要的建模结论：
	#   背景层（不碰撞）：门、超市入口、货架 —— 它们贴在墙面/景深处，玩家从前面走过。
	#   实体层（碰撞）  ：购物车、世界两端墙 —— 它们确实在玩家的行走线上。
	# 门框碰撞体仍然建出来，但默认关闭，只给 A/B 对照测试临时启用（见 _run_tests）。
	_door_solids = [
		_solid(DOOR_X, -DOOR_H, DOOR_JAMB, DOOR_H, "door_jamb_l"),
		_solid(DOOR_X + DOOR_W - DOOR_JAMB, -DOOR_H, DOOR_JAMB, DOOR_H, "door_jamb_r"),
		_solid(DOOR_X, -DOOR_H, DOOR_W, DOOR_HEAD, "door_lintel"),
	]
	for b in _door_solids:
		_set_solid_enabled(b, false)

	_solid(CART_X, -CART_H, CART_W, CART_H, "cart")
	_solid(WORLD_LEFT - 32.0, -400.0, 32.0, 400.0, "wall_l")
	_solid(WORLD_RIGHT, -400.0, 32.0, 400.0, "wall_r")


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


func _set_solid_enabled(body: StaticBody2D, on: bool) -> void:
	body.collision_layer = 1 if on else 0
	body.collision_mask = 1 if on else 0


func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate() as PlayerController
	_player.name = "Player"
	_player.ground_y = GROUND_Y
	_player.move_speed = 100.0
	add_child(_player)
	_player.teleport_to(180.0)
	_player.facing_changed.connect(_on_facing_changed)


func _build_camera() -> void:
	_camera = FollowCamera.new()
	_camera.name = "FollowCam"
	# 必须在入树前给好 NodePath：脚本的 _ready() 会立刻解析目标
	_camera.target_path = NodePath("../Player")
	_camera.look_offset = Vector2(0, -64)
	_camera.dead_zone = Vector2(56, 28)
	_camera.smoothing = 8.0
	# 世界是一条横向长条：不锁死视口地面 y，只给足够的水平活动范围。
	_camera.limit_left = int(WORLD_LEFT - VIEW.x * 0.5)
	_camera.limit_right = int(WORLD_RIGHT + VIEW.x * 0.5)
	_camera.limit_top = int(-VIEW.y * 2.0)
	_camera.limit_bottom = int(VIEW.y * 2.0)
	add_child(_camera)
	_camera.make_current()
	_camera.snap_to_target()


func _build_overlay() -> void:
	_overlay = CoreOverlay.new()
	_overlay.name = "Overlay"
	_overlay.player_path = NodePath("../Player")
	add_child(_overlay)


func _on_facing_changed(dir: int) -> void:
	_refresh_hud(dir)


# ---------------------------------------------------------------- 绘制世界

func _draw() -> void:
	# 两端各多铺一屏：相机允许把世界边缘拉到画面中间，背景不能在这里断掉
	_draw_zone(WORLD_LEFT - VIEW.x, ENTRY_X, C_GRAY_BG, C_GRAY_FLOOR, "A · 灰底轮廓检查")
	_draw_zone(ENTRY_X, STREET_X, C_MARKET_BG, C_MARKET_FLOOR, "B · 暖色超市")
	_draw_zone(STREET_X, WORLD_RIGHT + VIEW.x, C_STREET_BG, C_STREET_FLOOR, "C · 冷色街景")
	_draw_street_props()
	_draw_ruler()
	_draw_door()
	_draw_entry()
	_draw_shelf(SHELF1_X)
	_draw_shelf(SHELF2_X)
	_draw_cart()
	_draw_labels()


func _draw_zone(x0: float, x1: float, bg: Color, floor_c: Color, title: String) -> void:
	draw_rect(Rect2(x0, -600.0, x1 - x0, 600.0), bg, true, -1.0, false)
	draw_rect(Rect2(x0, GROUND_Y, x1 - x0, 240.0), floor_c, true, -1.0, false)
	# 地面线
	draw_line(Vector2(x0, GROUND_Y), Vector2(x1, GROUND_Y), Color(0, 0, 0, 0.45), 1.0)
	# 分区标题（贴地，避免被截图顶部裁掉）
	_text(x0 + 16.0, GROUND_Y - 250.0, title, 13, Color(1, 1, 1, 0.30))
	# 地面纹理：32px 一条，方便肉眼数格
	var x := x0
	while x < x1:
		draw_line(Vector2(x, GROUND_Y + 2.0), Vector2(x, GROUND_Y + (10.0 if int(x) % 128 == 0 else 6.0)),
			Color(0, 0, 0, 0.22), 1.0)
		x += TILE


func _draw_street_props() -> void:
	# 远景楼体剪影 + 静态雪点，只为了给"冷色"一个可读的环境
	var heights := [180.0, 240.0, 150.0, 210.0, 260.0, 170.0]
	var x := STREET_X + 20.0
	for h in heights:
		draw_rect(Rect2(x, GROUND_Y - float(h), 120.0, float(h)), Color(0.33, 0.39, 0.46), true, -1.0, false)
		draw_rect(Rect2(x + 12.0, GROUND_Y - float(h) + 16.0, 18.0, 20.0),
			Color(0.55, 0.62, 0.70, 0.55), true, -1.0, false)
		draw_rect(Rect2(x + 48.0, GROUND_Y - float(h) + 16.0, 18.0, 20.0),
			Color(0.55, 0.62, 0.70, 0.55), true, -1.0, false)
		x += 132.0
	# 积雪堆
	draw_rect(Rect2(STREET_X + 40.0, GROUND_Y - 6.0, 200.0, 6.0), Color(0.92, 0.95, 0.98), true, -1.0, false)
	draw_rect(Rect2(STREET_X + 420.0, GROUND_Y - 4.0, 160.0, 4.0), Color(0.92, 0.95, 0.98), true, -1.0, false)
	# 静态雪点（不做动画）
	var rng := 7
	for k in 60:
		rng = (rng * 1103515245 + 12345) % 2147483648
		var sx := STREET_X + float(rng % 600)
		var sy := -float(rng % 320)
		draw_rect(Rect2(sx, sy, 2.0, 2.0), Color(1, 1, 1, 0.55), true, -1.0, false)


func _draw_ruler() -> void:
	# 灰底区：1 tile = 32 的地面标尺，直接用来数像素
	var x := 32.0
	while x < ENTRY_X:
		var major := int(x) % 128 == 0
		draw_line(Vector2(x, GROUND_Y + 78.0), Vector2(x, GROUND_Y + (94.0 if major else 86.0)),
			Color(1, 1, 1, 0.55), 1.0)
		if major:
			_text(x - 12.0, GROUND_Y + 108.0, "%d" % int(x), 9, Color(1, 1, 1, 0.62))
		x += TILE
	_text(32.0, GROUND_Y + 128.0, "1 tile = 32px", 9, Color(1, 1, 1, 0.62))


func _draw_door() -> void:
	var x := DOOR_X
	var top := GROUND_Y - DOOR_H
	var net_w := DOOR_W - DOOR_JAMB * 2.0
	var net_h := DOOR_H - DOOR_HEAD
	# 门框
	draw_rect(Rect2(x, top, DOOR_W, DOOR_H), C_DOOR, true, -1.0, false)
	# 门洞（近黑，读作"洞"）
	draw_rect(Rect2(x + DOOR_JAMB, GROUND_Y - net_h, net_w, net_h), Color(0.07, 0.08, 0.09), true, -1.0, false)
	draw_rect(Rect2(x + DOOR_JAMB, GROUND_Y - net_h, net_w, net_h), Color(1, 1, 1, 0.25), false, 1.0, false)
	# 门槛
	draw_rect(Rect2(x + DOOR_JAMB, GROUND_Y - 2.0, net_w, 2.0), Color(1, 1, 1, 0.35), true, -1.0, false)
	# 净宽尺寸线
	_dim_h(x + DOOR_JAMB, x + DOOR_W - DOOR_JAMB, GROUND_Y + 8.0, "净宽 %d" % int(net_w), C_AMBER)
	_dim_v(x + DOOR_W + 10.0, GROUND_Y - net_h, GROUND_Y, "净高 %d" % int(net_h), C_AMBER)
	_text(x - 6.0, top - 26.0, "住宅门 %d×%d" % [int(DOOR_W), int(DOOR_H)], 11, C_INK)
	_text(x - 6.0, top - 12.0, "净 %d×%d" % [int(net_w), int(net_h)], 10, C_MUTED)


func _draw_entry() -> void:
	var x := ENTRY_X
	var top := GROUND_Y - ENTRY_H
	var net_w := ENTRY_W - ENTRY_REVEAL * 2.0
	draw_rect(Rect2(x, top, ENTRY_W, ENTRY_H), Color(0.20, 0.22, 0.25), true, -1.0, false)
	draw_rect(Rect2(x + ENTRY_REVEAL, GROUND_Y - 216.0, net_w, 216.0), Color(0.14, 0.11, 0.08), true, -1.0, false)
	# 玻璃门扇（向两侧折叠，占掉的正是收边）
	draw_rect(Rect2(x, top, ENTRY_REVEAL, ENTRY_H), Color(0.55, 0.66, 0.74, 0.7), true, -1.0, false)
	draw_rect(Rect2(x + ENTRY_W - ENTRY_REVEAL, top, ENTRY_REVEAL, ENTRY_H),
		Color(0.55, 0.66, 0.74, 0.7), true, -1.0, false)
	draw_rect(Rect2(x + ENTRY_REVEAL, GROUND_Y - 130.0, net_w, 2.0), Color(0.55, 0.66, 0.74, 0.45), true, -1.0, false)
	_dim_h(x + ENTRY_REVEAL, x + ENTRY_W - ENTRY_REVEAL, GROUND_Y + 8.0, "入口净 %d" % int(net_w), C_AMBER)
	_text(x - 2.0, top - 26.0, "超市入口 %d×%d" % [int(ENTRY_W), int(ENTRY_H)], 11, C_INK)
	_text(x - 2.0, top - 12.0, "净 %d×216" % int(net_w), 10, C_MUTED)


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
	# 32×32 小包装示意（正式素材未做，这里只是尺寸块）
	for i in SHELF_LAYERS:
		var iy := top + SHELF_TOP + i * (per + SHELF_BEAM) + per - 32.0
		for k in 2:
			draw_rect(Rect2(x + SHELF_POST + 1.0 + k * 32.0, iy, 30.0, 31.0),
				Color(0.68, 0.56, 0.38), true, -1.0, false)


func _draw_cart() -> void:
	var x := CART_X
	var top := GROUND_Y - CART_H
	draw_rect(Rect2(x + 4.0, top + 12.0, CART_W - 12.0, 48.0), Color(0.62, 0.70, 0.78, 0.35), true, -1.0, false)
	draw_rect(Rect2(x + 4.0, top + 12.0, CART_W - 12.0, 48.0), C_CART, false, 2.0, false)
	draw_rect(Rect2(x + CART_W - 6.0, top, 4.0, 60.0), C_CART, true, -1.0, false)
	draw_line(Vector2(x + 12.0, top + 60.0), Vector2(x + 12.0, GROUND_Y - 7.0), C_CART, 2.0)
	draw_line(Vector2(x + CART_W - 20.0, top + 60.0), Vector2(x + CART_W - 20.0, GROUND_Y - 7.0), C_CART, 2.0)
	draw_circle(Vector2(x + 12.0, GROUND_Y - 7.0), 7.0, C_CART.darkened(0.35))
	draw_circle(Vector2(x + CART_W - 20.0, GROUND_Y - 7.0), 7.0, C_CART.darkened(0.35))
	_dim_h(x, x + CART_W, GROUND_Y + 8.0, "车 %d" % int(CART_W), C_CART)
	_text(x - 2.0, top - 12.0, "购物车 %d×%d（占位）" % [int(CART_W), int(CART_H)], 10, C_MUTED)


func _draw_labels() -> void:
	# 主通道净宽尺寸线，画在货架顶上，不占地面
	var y := -SHELF_H - 26.0
	_dim_h(SHELF1_X + SHELF_W, SHELF2_X, y, "主通道净宽 %d" % int(AISLE_W), C_OK)
	_text(SHELF1_X + SHELF_W + 6.0, y - 8.0, "%.1f tile" % (AISLE_W / TILE), 9, C_MUTED)


func _dim_h(x1: float, x2: float, y: float, label: String, c: Color) -> void:
	draw_line(Vector2(x1, y), Vector2(x2, y), c, 1.0)
	draw_line(Vector2(x1, y - 4.0), Vector2(x1, y + 4.0), c, 1.0)
	draw_line(Vector2(x2, y - 4.0), Vector2(x2, y + 4.0), c, 1.0)
	_text_center((x1 + x2) * 0.5, y + 14.0, label, 9, c)


func _dim_v(x: float, y1: float, y2: float, label: String, c: Color) -> void:
	draw_line(Vector2(x, y1), Vector2(x, y2), c, 1.0)
	draw_line(Vector2(x - 4.0, y1), Vector2(x + 4.0, y1), c, 1.0)
	draw_line(Vector2(x - 4.0, y2), Vector2(x + 4.0, y2), c, 1.0)
	_text(x + 6.0, (y1 + y2) * 0.5, label, 9, c)


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

	_mk_label("CORE-001A · 角色移动底座（开发实验场景，不含玩法）",
		Vector2(14, 6), Vector2(700, 20), 13, C_INK)
	_hud_zone = _mk_label("", Vector2(VIEW.x - 300, 7), Vector2(288, 20), 12, C_AMBER,
		HORIZONTAL_ALIGNMENT_RIGHT)
	_hud_state = _mk_label("", Vector2(14, VIEW.y - 62), Vector2(940, 24), 12, C_INK)
	_hud_note = _mk_label("", Vector2(14, VIEW.y - 40), Vector2(940, 20), 11, C_MUTED)
	_refresh_hud(_player.facing if _player else 1)


## HUD 用 Label。字体显式指定，不依赖 Theme 传播：
## Web 端没有系统字体兜底，只靠主题继承会整行变成方块。
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


func _refresh_hud(facing: int) -> void:
	if _hud_state == null or _player == null:
		return
	var zone := "A 灰底"
	if _player.global_position.x >= STREET_X:
		zone = "C 冷色街景"
	elif _player.global_position.x >= ENTRY_X:
		zone = "B 暖色超市"
	_hud_zone.text = zone
	var cam_x := _camera.global_position.x if _camera else 0.0
	_hud_state.text = "x=%d  vx=%.0f  朝向=%s  状态=%s  ｜ 相机 x=%.0f  偏移=%+.0f  ｜ 地面屏幕 y=%.0f" % [
		int(_player.global_position.x), _player.velocity.x,
		"右" if facing > 0 else "左", String(_player.state),
		cam_x, _player.global_position.x - cam_x,
		_screen_y_of_ground(),
	]
	_hud_note.text = "贴图 128×176 · scale 1:1 · Nearest ｜ 可见 41×%d · 碰撞 %d×%d ｜ 门/货架=背景层不碰撞，购物车=实体 ｜ 死区 %d×%d ｜ F3 叠加层" % [
		CHAR_VISIBLE_H, int(_player.collision_width()), CHAR_VISIBLE_H,
		int(_camera.dead_zone.x) if _camera else 0, int(_camera.dead_zone.y) if _camera else 0,
	]


func _process(_delta: float) -> void:
	_refresh_hud(_player.facing if _player else 1)


func _screen_y_of_ground() -> float:
	var xform := get_viewport().get_canvas_transform()
	return (xform * Vector2(0.0, GROUND_Y)).y


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_F3 and _overlay:
			_overlay.show_overlay = not _overlay.show_overlay


# ---------------------------------------------------------------- 量测与日志

func _measure_and_report() -> void:
	var tex_size := _player.sprite_texture_size()
	var draw_rect := _player.sprite_draw_rect()
	var vis := _player.visible_bbox()
	var coll := _player.collision_rect()
	var net_w := DOOR_W - DOOR_JAMB * 2.0
	var net_h := DOOR_H - DOOR_HEAD

	print("")
	print("========== CORE-001A 实机量测 ==========")
	var spr := _player.sprite_node()
	print("[CORE] 纹理 %d×%d  节点 scale=%s  filter=%d(Nearest=1)" % [
		int(tex_size.x), int(tex_size.y), str(spr.scale), spr.texture_filter])
	print("[CORE] sprite.get_rect() = %s  （期望 (-64,-168,128,176)）" % str(draw_rect))
	print("[CORE] 可见包围盒(实测 alpha) = %d×%d @ (%d,%d)  本地左下=%s" % [
		int(vis.size.x), int(vis.size.y), int(vis.position.x - draw_rect.position.x),
		int(vis.position.y - draw_rect.position.y), str(vis.position)])
	print("[CORE] 碰撞盒 = %d×%d @ (%d,%d)" % [
		int(coll.size.x), int(coll.size.y), int(coll.position.x), int(coll.position.y)])
	# alpha 洁净度：直接数加载后的像素，确认没有半透明边缘，也没有被导入流程改过
	var alpha_levels := {}
	var spr_node := _player.sprite_node()
	var cur_tex := _player.current_texture()
	var tex_img: Image = cur_tex.get_image() if cur_tex != null else null
	if tex_img != null:
		for y in tex_img.get_height():
			for x in tex_img.get_width():
				alpha_levels[tex_img.get_pixel(x, y).a8] = true
	var lv: Array = alpha_levels.keys()
	lv.sort()
	var lv_text := ""
	for v in lv:
		lv_text += ("%d " % int(v))
	print("[CORE] alpha 档位 = [%s]（%d 档）%s" % [
		lv_text.strip_edges(), lv.size(),
		"无半透明，边缘干净" if lv.size() <= 2 else "存在半透明，需要清理"])

	var foot_err := absf(vis.position.y + vis.size.y)
	print("[CORE] 脚底误差 = %.1f px （可见框底边 %.1f vs 原点 0）" % [foot_err, vis.position.y + vis.size.y])
	print("[CORE] 住宅门 净 %d×%d → 碰撞 %d 宽：左余 %d / 右余 %d；头顶余 %d" % [
		int(net_w), int(net_h), int(coll.size.x),
		int((net_w - coll.size.x) * 0.5), int((net_w - coll.size.x) * 0.5), int(net_h - coll.size.y)])
	print("[CORE] 超市主通道 %d，购物车 %d → 单侧可通行 %d（碰撞 %d）" % [
		int(AISLE_W), int(CART_W), int((AISLE_W - CART_W) * 0.5), int(coll.size.x)])
	print("[CORE] 世界地面 y=%.0f，当前屏幕 y=%.0f （HUD 在 CanvasLayer，不影响世界地面）" % [
		GROUND_Y, _screen_y_of_ground()])
	print("========================================")


# ---------------------------------------------------------------- 检查点

func _apply_state(key: String) -> void:
	var st := _find_state(key)
	_player.clear_input_override()
	_player.teleport_to(float(st["x"]))
	_player.set_facing(int(st["facing"]))
	_camera.snap_to_target()
	if bool(st.get("walk", false)):
		_player.set_input_override(1.0)
	queue_redraw()


func _find_state(key: String) -> Dictionary:
	for s in STATES:
		if String(s["key"]) == key:
			return s
	push_warning("[CORE] 未知检查点 %s，回退到 idle" % key)
	return STATES[0]


func _run_tour() -> void:
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var fails := 0
	for st in STATES:
		var key := String(st["key"])
		_apply_state(key)
		# 走动的检查点多跑几帧，让速度和状态真的进入 walk
		var frames := 14 if bool(st.get("walk", false)) else 6
		for i in frames:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		var name := "core001a_%s.png" % key
		var err := get_viewport().get_texture().get_image().save_png("%s/%s" % [SHOT_DIR, name])
		if err != OK:
			fails += 1
		print("[CORE] 截图 %-26s x=%d vx=%.0f 朝向=%s err=%d  %s" % [
			name, int(_player.global_position.x), _player.velocity.x,
			"右" if _player.facing > 0 else "左", err, String(st["label"])])
	print("[CORE] 巡览完成：%d 张，失败 %d 张" % [STATES.size(), fails])


func _capture(filename: String) -> void:
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var path := "%s/%s" % [SHOT_DIR, filename]
	var err := get_viewport().get_texture().get_image().save_png(path)
	print("[CORE] 截图 ", ProjectSettings.globalize_path(path), " err=", err)


# ---------------------------------------------------------------- 自动化测试
# 一次跑完三组：门（背景层 / 门框实体 A-B 对照）、购物车硬障碍、相机死区。
# 结论写进 docs/CORE-001A_交付报告.md，不在这里改任何正式数据。

func _run_tests() -> void:
	var all_ok := true
	print("")
	print("========== CORE-001A 实机测试 ==========")
	print("[T] 碰撞宽 %.0f，可见宽 %.0f，门净 80×184，主通道 192，购物车 96" % [
		float(CHAR_COLLIDE_W), 41.0])

	# ---- T1 门：背景层。从门前走过，不应有任何阻滞
	var r1: Dictionary = await _walk(240.0, 460.0, float(CHAR_COLLIDE_W), 220)
	var ok1 := bool(r1["passed"]) and int(r1["stall"]) < 5
	all_ok = all_ok and ok1
	print("[T1 门·背景层] %.0f → %.0f（目标 460），最长停滞 %d 帧 → %s" % [
		float(r1["start"]), float(r1["end"]), int(r1["stall"]), "通过" if ok1 else "异常"])

	# ---- T2 门：把门框临时当实体，A/B 对照。人物应被挡在门框外侧
	for b in _door_solids:
		_set_solid_enabled(b, true)
	var r2: Dictionary = await _walk(240.0, 460.0, float(CHAR_COLLIDE_W), 220)
	for b in _door_solids:
		_set_solid_enabled(b, false)
	var blocked_x := float(r2["end"])
	var expect_x := DOOR_X - float(CHAR_COLLIDE_W) * 0.5
	var ok2 := not bool(r2["passed"]) and absf(blocked_x - expect_x) < 2.0
	all_ok = all_ok and ok2
	print("[T2 门·门框实体] %.0f → 停在 %.0f（理论 %.0f）→ %s" % [
		float(r2["start"]), blocked_x, expect_x, "被正确阻挡" if ok2 else "与预期不符"])
	print("[T2 说明] 侧视里门是墙面元素，玩家从前面走过；把它当通行缺口会让人物卡在门框外，" )
	print("[T2 说明] 因此门必须是**交互点**（按 E 进门），不是 x 方向的碰撞缺口。")

	# ---- T3 购物车：在行走线上，是硬障碍
	var r3: Dictionary = await _walk(980.0, 1200.0, float(CHAR_COLLIDE_W), 220)
	var cart_stop := float(r3["end"])
	var cart_expect := CART_X - float(CHAR_COLLIDE_W) * 0.5
	var ok3 := not bool(r3["passed"]) and absf(cart_stop - cart_expect) < 2.0
	all_ok = all_ok and ok3
	print("[T3 购物车·硬障碍] %.0f → 停在 %.0f（理论 %.0f）→ %s" % [
		float(r3["start"]), cart_stop, cart_expect,
		"购物车挡停，单行走线无法绕过" if ok3 else "与预期不符"])

	# ---- T4 相机
	var ok4 := await _camera_section()
	all_ok = all_ok and ok4

	# 收尾：回到门前的检查点截图
	_player.clear_input_override()
	_player.teleport_to(336.0)
	_camera.snap_to_target()
	await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	_capture("core001a_test.png")

	print("[T] 汇总：%s" % ("全部符合预期" if all_ok else "存在与预期不符的项，见上"))
	print("========================================")
	get_tree().quit(0 if all_ok else 1)


## 从 x0 向右走到 x1，记录终点与最长停滞帧数
func _walk(x0: float, x1: float, collide_w: float, max_frames: int) -> Dictionary:
	_player.set_collision_width(collide_w)
	_player.teleport_to(x0)
	_camera.snap_to_target()
	_player.set_input_override(1.0)
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
		if x >= x1:
			break
	var end := _player.global_position.x
	_player.clear_input_override()
	_player.set_collision_width(float(CHAR_COLLIDE_W))
	return {"start": start, "end": end, "passed": end >= x1 - 2.0, "stall": best}


func _camera_section() -> bool:
	print("[T4 相机] 死区 %s，平滑 %.1f，视线偏移 %s" % [
		str(_camera.dead_zone), _camera.smoothing, str(_camera.look_offset)])
	_player.teleport_to(700.0)
	_camera.snap_to_target()
	await get_tree().physics_frame

	var moved_in_deadzone := 0
	var max_off := 0.0
	var cam_moved := 0
	_player.set_input_override(1.0)
	print("[T4 相机]  帧 | 玩家 x | 相机 x | 偏移 dx | 本帧位移 | 死区触发")
	for i in 180:
		await get_tree().physics_frame
		await get_tree().process_frame
		var px := _player.global_position.x
		var cx := _camera.global_position.x
		var dx := px - cx
		var step: float = _camera.last_step.x
		var over: float = _camera.last_overshoot.x
		max_off = maxf(max_off, absf(dx))
		if absf(step) > 0.0001:
			cam_moved += 1
			if absf(dx) < _camera.dead_zone.x - 1.0:
				moved_in_deadzone += 1
		if i % 45 == 0 or i == 179:
			print("[T4 相机] %4d | %6.0f | %6.0f | %+6.1f | %+8.2f | %s" % [
				i, px, cx, dx, step, "是" if absf(over) > 0.001 else "否"])
	_player.clear_input_override()
	await get_tree().physics_frame

	print("[T4 相机] 相机移动 %d 帧，死区内误动 %d 帧，最大偏移 %.1f（死区半宽 %.1f）" % [
		cam_moved, moved_in_deadzone, max_off, _camera.dead_zone.x])
	print("[T4 相机] 稳态滞后理论值 ≈ 死区半宽 + 速度/平滑 = %.1f + %.0f/%.1f ≈ %.1f px" % [
		_camera.dead_zone.x, _player.move_speed, _camera.smoothing,
		_camera.dead_zone.x + _player.move_speed / _camera.smoothing])
	var ok := moved_in_deadzone == 0
	print("[T4 相机] %s" % ("死区生效：目标在死区内时相机不动" if ok else "死区未守住"))
	return ok
