extends Node2D
## ART-INTEGRATE-003 · 正式美术候选的实机验证场景（开发专用，不是正式关卡）
##
## 本场景只做一件事：**把 ART-RUNTIME-003B/003C 的候选件按真实运行参数摆出来、
## 用 960×540 / Nearest / 1:1 拍原生截图、并把能变成数字的项全部量出来**。
##
## 刻意做对的几件事：
##   1) 人物与车不是"画上去的图"，而是直接实例化 `player.tscn` + `PushableCart`，
##      所以量到的手部间隙、锚点、镜像偏移就是游戏里的真实值；
##   2) 推车间距保持**逻辑值 80px**（冻结），美术静帧参考的 74px 只作为对照量一次，
##      **绝不通过改 side_offset 去凑画面**；
##   3) 货架层高 / 内宽是从 PNG 的 alpha 扫描出来的，不是抄概念图的估计值。
##
## 明确不做：购物、结算、库存、存档、TileSet、动画生成。
##
## 命令行（写在 `--` 之后，须带 --dev-scene=art003）：
##   --art003-tour               六个检查点各截「叠加层关 / 开」两张后退出
##   --art003-state=hand_r|hand_l|shelves|compare|overview|mirror   只渲染一个检查点
##   --art003-test               跑七组实机用例后退出（不截图）
##   --shot=name.png             单检查点截图
##   --quit                      完成后退出

const VIEW := Vector2(960, 540)
const GROUND_Y := 416.0
const SHOT_DIR := "res://tests/screenshots"
const FONT_PATH := "res://assets/ui/fonts/NotoSansSC-Variable.ttf"
const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")

# ---------------------------------------------------------------- 候选件（全部 1:1）
const SHELF_TEX := preload("res://assets/facilities/ART_FURN_101_r01_empty_shelf_128x208.png")
## 交付合同：画布 128×208，可见 96×192，脚底锚点 (64,200)
const SHELF_ANCHOR := Vector2(64, 200)
const CART_TEX := preload("res://assets/facilities/ART_FURN_103_r02_tall_handle_128x112.png")
const CART_TEX_R01 := preload("res://assets/facilities/ART_FURN_103_r01_empty_cart_128x112.png")
## 交付合同：画布 128×112，脚底锚点 (64,104)；r02 可见 96×90，r01 可见 96×74
const CART_ANCHOR := Vector2(64, 104)
## ART-FIX-003C：四张商品图改用纠正后的 r02 / r02-shelf。
## 旧的 r01 / r01-shelf 文件仍在 assets/items/ 里（保留可追溯），但**内容与 ID 互换**，
## 已被总监裁定「不予审核通过」，任何代码都不得再 preload 它们。
const WATER_TEX := preload("res://assets/items/ART_ITEM_101_r02_water_64x48.png")
const WATER_SHELF_TEX := preload("res://assets/items/ART_ITEM_101_r02-shelf_water_32x32.png")
const FOOD_TEX := preload("res://assets/items/ART_ITEM_102_r02_food_carton_64x64.png")
const FOOD_SHELF_TEX := preload("res://assets/items/ART_ITEM_102_r02-shelf_food_32x32.png")

## 逻辑推车间距：CORE-001B 冻结值。**不是美术静帧的 74。**
const CART_SEP := 80.0
## 美术交付说明里的静帧组合参考值，仅用于对照测量
const CART_SEP_ART := 74.0

const C_BG := Color(0.35, 0.28, 0.22)
const C_BG_TOP := Color(0.40, 0.33, 0.26)
const C_FLOOR := Color(0.55, 0.43, 0.31)
const C_INK := Color(0.96, 0.97, 0.98)
const C_MUTED := Color(0.80, 0.83, 0.86)
const C_AMBER := Color(0.96, 0.72, 0.35)
const C_OK := Color(0.52, 0.84, 0.60)
const C_BAD := Color(0.91, 0.42, 0.38)
const C_DIM := Color(0.90, 0.88, 0.84, 0.55)

# ART-RESET-001：hand_r / hand_l / mirror / overlap 四个检查点依赖角色贴图，已删除。
# 保留的检查点只画车 / 货架 / 商品，与角色无关。
const STATES := ["shelves", "items", "compare", "overview"]
const STATE_LABELS := {
	"shelves": "① 四层空货架 + 32×32 上架商品 + 64×48 / 64×64 落地商品",
	"items": "①b 商品归属核对：101 必须是蓝灰水、102 必须是棕色纸箱（64 与 32 两种尺寸）",
	"compare": "② 旧车 r01（可见 96×74）与新车 r02（可见 96×90）对照",
	"overview": "③ 综合实机：货架 / 商品 / 推车同屏（角色渲染为空）",
}

var _args: Dictionary = {}
var _font: Font
var _player: PlayerController
var _cart: PushableCart
var _sensor: InteractionSensor
var _overlay: Art003Overlay
var _stage: Node2D
var _hud: CanvasLayer

## 各检查点的实测数据，供叠加层与报告引用
var _hand: Dictionary = {}
var _shelf_info: Dictionary = {}
var _state := "hand_r"

## 用于对照的一台"旧版车"精灵（只在本场景里当尺子用）
var _r01_ghost: Sprite2D


func _ready() -> void:
	_parse_args()
	_font = load(FONT_PATH)
	if _font == null:
		_font = ThemeDB.fallback_font

	_shelf_info = _analyze_shelf()

	_stage = Node2D.new()
	_stage.name = "Stage"
	add_child(_stage)

	# 车先入树：Back 层（z=0）才会画在玩家之前
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

	_sensor = InteractionSensor.new()
	_sensor.name = "Sensor"
	_sensor.actor_path = NodePath("../Player")
	_sensor.enabled = false
	add_child(_sensor)

	_overlay = Art003Overlay.new()
	_overlay.name = "DebugOverlay"
	_overlay.host = self
	_overlay.z_as_relative = false
	_overlay.z_index = 10
	add_child(_overlay)

	_build_hud()
	_apply_state(_state)
	queue_redraw()

	if _args.has("art003_tour"):
		await _run_tour()
	elif _args.has("art003_test"):
		await _run_tests()
	elif _args.has("shot"):
		await _frames(6)
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
	if _args.has("art003_state"):
		_state = String(_args["art003_state"])


# ---------------------------------------------------------------- 画面搭建

func _apply_state(key: String) -> void:
	_state = key
	for c in _stage.get_children():
		_stage.remove_child(c)
		c.queue_free()
	_r01_ghost = null
	_sensor.enabled = false
	if _cart.state == PushableCart.STATE_PUSHING:
		_cart.unbind()
	_cart.visible = false
	_player.clear_input_override()

	match key:
		"shelves":
			_build_shelves()
		"items":
			_build_items()
		"compare":
			_build_compare()
		"overview":
			_build_overview()
		_:
			_build_shelves()

	queue_redraw()
	_overlay.queue_redraw()


## ART-RESET-001：_build_hand / _build_mirror / _build_overlap 已随角色贴图退役。
## 它们搭的是「角色手部与车把的贴合对照画面」，没有角色像素就没有对照对象。
## _build_overlap 的"站进车里"改由 art004 的图层断言覆盖（那组不依赖角色贴图）。


func _build_shelves() -> void:
	_player.teleport_to(800.0)
	_player.set_facing(1)

	var xs := [150.0, 300.0, 450.0]
	# A：空载本体
	_mk_sprite(_stage, SHELF_TEX, SHELF_ANCHOR, Vector2(xs[0], GROUND_Y), "ShelfA")
	# B：每层两件 32×32 商品
	_mk_sprite(_stage, SHELF_TEX, SHELF_ANCHOR, Vector2(xs[1], GROUND_Y), "ShelfB")
	# C：每层一件 32×32 + 一层混合
	_mk_sprite(_stage, SHELF_TEX, SHELF_ANCHOR, Vector2(xs[2], GROUND_Y), "ShelfC")

	var levels: Array = _shelf_info["levels"]
	for i in levels.size():
		var bottom: float = float(levels[i])
		# B：两件水（每层左右各一）
		_mk_sprite(_stage, WATER_SHELF_TEX, Vector2(16, 32),
			Vector2(xs[1] - 16.0, GROUND_Y + bottom), "WaterB%d" % i)
		_mk_sprite(_stage, WATER_SHELF_TEX, Vector2(16, 32),
			Vector2(xs[1] + 16.0, GROUND_Y + bottom), "WaterB%db" % i)
		# C：一件食品
		_mk_sprite(_stage, FOOD_SHELF_TEX, Vector2(16, 32),
			Vector2(xs[2], GROUND_Y + bottom), "FoodC%d" % i)

	# 落地商品：64×48 与 64×64（放不进货架，只能落地）
	_mk_sprite(_stage, WATER_TEX, Vector2(32, 48), Vector2(620.0, GROUND_Y), "WaterFloor")
	_mk_sprite(_stage, FOOD_TEX, Vector2(32, 64), Vector2(720.0, GROUND_Y), "FoodFloor")


## ART-FIX-003C 专用检查点：四件商品平铺，左右两组分别对应 101 / 102。
## 上半排是 64 落地版，下半排是 32×32 货架版，同一列必须是同一个物品。
## 这一组存在的意义：修正前"尺寸全对、内容互换"，光看图例读不出来。
func _build_items() -> void:
	_player.teleport_to(880.0)
	_player.set_facing(1)
	_cart.visible = false

	# 每组放大 2 倍显示，1:1 的 64px 物件在 960 屏上太小、看不清内容
	var scale_k := 2.0
	var col_x := [300.0, 560.0]

	# 落地版（放大后底部对齐地面线）
	for i in 2:
		var tex: Texture2D = WATER_TEX if i == 0 else FOOD_TEX
		var anc: Vector2 = Vector2(32, 48) if i == 0 else Vector2(32, 64)
		var spr := _mk_sprite(_stage, tex, anc, Vector2(col_x[i], GROUND_Y), "Item64_%d" % i)
		spr.scale = Vector2(scale_k, scale_k)

	# 货架版（同一列，缩略显示在地面上方，保持原尺寸以便核对 32px 像素）
	for i in 2:
		var tex: Texture2D = WATER_SHELF_TEX if i == 0 else FOOD_SHELF_TEX
		var spr := _mk_sprite(_stage, tex, Vector2(16, 32),
			Vector2(col_x[i], GROUND_Y - 130.0), "Item32_%d" % i)
		spr.scale = Vector2(scale_k, scale_k)


func _build_compare() -> void:
	_player.teleport_to(760.0)
	_player.set_facing(1)
	_cart.visible = false

	_r01_ghost = _mk_sprite(_stage, CART_TEX_R01, CART_ANCHOR, Vector2(240.0, GROUND_Y), "CartR01")
	_mk_sprite(_stage, CART_TEX, CART_ANCHOR, Vector2(480.0, GROUND_Y), "CartR02")


func _build_overview() -> void:
	var sx := 220.0
	_mk_sprite(_stage, SHELF_TEX, SHELF_ANCHOR, Vector2(sx, GROUND_Y), "Shelf")
	var levels: Array = _shelf_info["levels"]
	for i in levels.size():
		_mk_sprite(_stage, WATER_SHELF_TEX, Vector2(16, 32),
			Vector2(sx - 16.0, GROUND_Y + float(levels[i])), "Water%d" % i)
		_mk_sprite(_stage, FOOD_SHELF_TEX, Vector2(16, 32),
			Vector2(sx + 16.0, GROUND_Y + float(levels[i])), "Food%d" % i)

	_mk_sprite(_stage, WATER_TEX, Vector2(32, 48), Vector2(380.0, GROUND_Y), "WaterFloor")
	_mk_sprite(_stage, FOOD_TEX, Vector2(32, 64), Vector2(460.0, GROUND_Y), "FoodFloor")

	# 往右推：车要放在玩家右侧（side=-1 → dir=+1 才是"推"而不是"拉"）
	_cart.visible = true
	_cart.place_at(700.0)
	_player.teleport_to(700.0 - CART_SEP)
	_cart.bind(_player)
	_player.set_input_override(1.0)
	await _frames(6)
	_player.clear_input_override()
	await _frames(2)


func _mk_sprite(parent: Node, tex: Texture2D, anchor: Vector2, pos: Vector2, node_name: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = node_name
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = false
	s.scale = Vector2.ONE
	s.offset = -anchor
	s.position = pos
	parent.add_child(s)
	return s


# ---------------------------------------------------------------- 背景

func _draw() -> void:
	# 墙面：上浅下深两段 + 踢脚线，纯粹为了让 1:1 的素材有东西可比对，
	# 不是正式场景美术（正式场景会另外做 TileSet）
	draw_rect(Rect2(0, 0, VIEW.x, GROUND_Y), C_BG, true, -1.0, false)
	draw_rect(Rect2(0, 0, VIEW.x, GROUND_Y - 104.0), C_BG_TOP, true, -1.0, false)
	draw_line(Vector2(0, GROUND_Y - 104.0), Vector2(VIEW.x, GROUND_Y - 104.0),
		Color(0.30, 0.24, 0.19, 0.9), 1.0)
	var seam := 160.0
	while seam < VIEW.x:
		draw_line(Vector2(seam, 0), Vector2(seam, GROUND_Y - 104.0),
			Color(0.36, 0.30, 0.24, 0.45), 1.0)
		seam += 160.0
	# 地面
	draw_rect(Rect2(0, GROUND_Y, VIEW.x, VIEW.y - GROUND_Y), C_FLOOR, true, -1.0, false)
	draw_line(Vector2(0, GROUND_Y), Vector2(VIEW.x, GROUND_Y), Color(0.72, 0.62, 0.48), 2.0)
	var x := 0.0
	while x < VIEW.x:
		draw_line(Vector2(x, GROUND_Y + 2), Vector2(x, GROUND_Y + 10),
			Color(0.44, 0.34, 0.25, 0.55), 1.0)
		x += 32.0
	_draw_height_ruler()
	_draw_captions()


## 右侧竖向标尺：每 32px 一格，每 64px 标一次。1:1 素材的高度可以直接对着读。
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
			var label := "%d" % h
			var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x if _font else 12.0
			_text(rx - 14.0 - w, y + 4.0, label, 9, C_DIM)
		h += 32


## 画面里的静态说明（不是调试叠加层，属于验证展板的一部分）
func _draw_captions() -> void:
	match _state:
		"hand_r", "hand_l":
			var gap: float = float(_hand.get("gap", 0.0))
			var side: int = int(_hand.get("side", -1))
			_text(24, 40, STATE_LABELS["hand_r" if side < 0 else "hand_l"], 15, C_INK)
			_text(24, 62, "逻辑间距 %.0f px（冻结值）· 手部与车把水平间隙 %+.1f px %s" % [
				CART_SEP, gap, "（贴合）" if absf(gap) <= 8.0 else "（需修）"], 12,
				C_OK if absf(gap) <= 8.0 else C_BAD)
			_text(24, 82, "垂直差 %+.1f px · 车可见 96×90 · 人可见 58×160（r03 扶车姿态）" % [
				float(_hand.get("dy", 0.0))], 11, C_MUTED)
		"shelves":
			_text(24, 40, STATE_LABELS["shelves"], 15, C_INK)
			_text(24, 62, "层高 %s px · 内宽 %d px · 32×32 上架 · 64×48 / 64×64 只能落地" % [
				str(_shelf_info.get("heights", [])), int(_shelf_info.get("inner", 0))], 11, C_MUTED)
			_text_center(150.0, GROUND_Y - 208.0, "空载本体", 11, C_MUTED)
			_text_center(300.0, GROUND_Y - 208.0, "每层 2×32×32", 11, C_MUTED)
			_text_center(450.0, GROUND_Y - 208.0, "每层 1×32×32", 11, C_MUTED)
			_text_center(620.0, GROUND_Y + 26.0, "水 64×48", 10, C_MUTED)
			_text_center(720.0, GROUND_Y + 26.0, "纸箱 64×64", 10, C_MUTED)
			_text_center(800.0, GROUND_Y - 178.0, "人物 160", 10, C_MUTED)
		"items":
			_text(24, 40, STATE_LABELS["items"], 15, C_INK)
			_text(24, 66, "每组放大 2 倍 · 左列 = ART_ITEM_101 饮用水 · 右列 = ART_ITEM_102 食品纸箱", 11, C_MUTED)
			_text_center(300.0, GROUND_Y + 26.0, "101 · 水 64×48", 11, C_OK)
			_text_center(560.0, GROUND_Y + 26.0, "102 · 纸箱 64×64", 11, C_AMBER)
			_text_center(300.0, GROUND_Y - 200.0, "101 · 水 32×32（顶端留白 8px）", 10, C_OK)
			_text_center(560.0, GROUND_Y - 200.0, "102 · 纸箱 32×32（满幅）", 10, C_AMBER)
		"compare":
			_text(24, 40, STATE_LABELS["compare"], 15, C_INK)
			_text(24, 62, "横向都是 96（冻结车长）· 高度 74 → 90（+16）· 锚点都是 (64,104)", 11, C_MUTED)
			_v_bracket(310.0, GROUND_Y - 74.0, GROUND_Y, "74", C_MUTED)
			_v_bracket(550.0, GROUND_Y - 90.0, GROUND_Y, "90", C_AMBER)
			_text_center(240.0, GROUND_Y + 26.0, "r01 旧版", 11, C_MUTED)
			_text_center(480.0, GROUND_Y + 26.0, "r02 加高车把", 11, C_AMBER)
		"overview":
			_text(24, 40, STATE_LABELS["overview"], 15, C_INK)
		# ART-RESET-001：mirror / overlap / hand_* 三个检查点已随角色贴图删除


## 竖直尺寸括号
func _v_bracket(x: float, y_top: float, y_bottom: float, label: String, c: Color) -> void:
	draw_line(Vector2(x, y_top), Vector2(x, y_bottom), c, 1.0)
	draw_line(Vector2(x - 4, y_top), Vector2(x + 4, y_top), c, 1.0)
	draw_line(Vector2(x - 4, y_bottom), Vector2(x + 4, y_bottom), c, 1.0)
	_text(x + 6.0, (y_top + y_bottom) * 0.5 + 3.0, label, 10, c)


func _text(x: float, y: float, s: String, size: int, c: Color) -> void:
	if _font == null:
		return
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_rect(Rect2(x - 4, y - size, w + 8, size + 6), Color(0.06, 0.05, 0.04, 0.72), true, -1.0, false)
	draw_string(_font, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


func _text_center(cx: float, y: float, s: String, size: int, c: Color) -> void:
	if _font == null:
		return
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text(cx - w * 0.5, y, s, size, c)


# ---------------------------------------------------------------- 量测

## 货架层高与内宽：直接从 alpha 扫，不抄概念图
func _analyze_shelf() -> Dictionary:
	var img := SHELF_TEX.get_image()
	var w := img.get_width()
	var used := img.get_used_rect()
	var beam_rows := PackedInt32Array()
	for y in range(used.position.y, used.position.y + used.size.y):
		var cnt := 0
		for x in w:
			if img.get_pixel(x, y).a > 0.5:
				cnt += 1
		if cnt > int(float(w) * 0.6):
			beam_rows.append(y)

	# 把连续行合并成横梁组
	var groups: Array = []
	var start := -1
	var prev := -2
	for y in beam_rows:
		if start < 0:
			start = y
		elif y != prev + 1:
			groups.append(Vector2i(start, prev))
			start = y
		prev = y
	if start >= 0:
		groups.append(Vector2i(start, prev))

	# 层 = 相邻横梁组之间的净空；坐标相对脚底（纹理 y=200 处）
	var foot_row := int(SHELF_ANCHOR.y)
	var levels: Array = []
	var heights: Array = []
	for i in range(groups.size() - 1):
		var ceil_row: int = groups[i].y + 1
		var floor_row: int = groups[i + 1].x - 1
		levels.append(-float(foot_row - floor_row))          # 负值 = 在脚底之上
		heights.append(floor_row - ceil_row + 1)

	# 内宽：取第一层中间那一行的左右立柱之间
	var probe_row: int = int(groups[1].x) - 6
	var inner_l := 0
	var inner_r := 0
	var opaque := PackedInt32Array()
	for x in w:
		if img.get_pixel(x, probe_row).a > 0.5:
			opaque.append(x)
	if opaque.size() >= 2:
		inner_l = opaque[0] + 1
		inner_r = opaque[opaque.size() - 1] - 1

	return {
		"groups": groups,
		"levels": levels,
		"heights": heights,
		"inner": inner_r - inner_l + 1,
		"inner_l": inner_l,
		"inner_r": inner_r,
	}


## ART-RESET-001：_band_x / _hand_rows / _measure_hand / _top_row_y 已随角色贴图退役。
## 它们量的是角色像素与车把的横向间隙；没有角色像素就没有可量对象。
## 接新动画后按新帧画布重写，不要恢复旧实现。


func _run_tests() -> void:
	var fails := 0
	print("")
	print("========== ART-INTEGRATE-003 实机验收 ==========")

	# ---- A 图片合同：尺寸 / alpha 档位 / 包围盒
	print("[A] 候选件像素合同")
	var contract := [
		["ART_FURN_103 r02", CART_TEX, Vector2i(128, 112), Rect2(16, 14, 96, 90)],
		["ART_FURN_101 r01", SHELF_TEX, Vector2i(128, 208), Rect2(16, 8, 96, 192)],
		["ART_ITEM_101 r02", WATER_TEX, Vector2i(64, 48), Rect2(0, 0, 64, 48)],
		["ART_ITEM_101 r02-shelf", WATER_SHELF_TEX, Vector2i(32, 32), Rect2(0, 8, 32, 24)],
		["ART_ITEM_102 r02", FOOD_TEX, Vector2i(64, 64), Rect2(0, 0, 64, 64)],
		["ART_ITEM_102 r02-shelf", FOOD_SHELF_TEX, Vector2i(32, 32), Rect2(0, 0, 32, 32)],
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

	# ---- A2 内容归属：编号画的是不是那个东西
	# 这一组是 ART-FIX-003C 加的：上一批四张图的文件名与内容互换，尺寸/alpha/锚点全部合格，
	# 只靠像素合同根本查不出来。判据用"不透明像素的平均色相"——水是冷蓝灰，纸箱是暖棕。
	print("[A2] 内容归属（编号必须画对东西）")
	var belong := [
		["ART_ITEM_101 r02", WATER_TEX, true],
		["ART_ITEM_101 r02-shelf", WATER_SHELF_TEX, true],
		["ART_ITEM_102 r02", FOOD_TEX, false],
		["ART_ITEM_102 r02-shelf", FOOD_SHELF_TEX, false],
	]
	for row in belong:
		var label: String = row[0]
		var tex: Texture2D = row[1]
		var want_water: bool = row[2]
		var c := _avg_rgb(tex)
		# 水：蓝比红高 20 以上；纸箱：红比蓝高 20 以上。两条互斥，不会被同一张图同时满足
		var is_water := (c.z - c.x) > 20.0
		var is_carton := (c.x - c.z) > 20.0
		var got := is_water or is_carton
		fails += _ok("%s 内容=%s（平均 RGB %.0f,%.0f,%.0f → %s）" % [
			label, "饮用水" if is_water else ("食品纸箱" if is_carton else "无法判定"),
			c.x, c.y, c.z, "蓝灰偏 %+.0f" % (c.z - c.x) if is_water else "棕偏 %+.0f" % (c.x - c.z)],
			got and (is_water == want_water))

	# ---- B 锚点：按合同 offset 摆好后，可见底边必须落在脚底原点
	print("[B] 脚底锚点")
	var anchor_cases := [
		["购物车 r02", CART_TEX, CART_ANCHOR, 0.0],
		["货架 r01", SHELF_TEX, SHELF_ANCHOR, 0.0],
		["水 64×48", WATER_TEX, Vector2(32, 48), 0.0],
		["食品 64×64", FOOD_TEX, Vector2(32, 64), 0.0],
	]
	for row in anchor_cases:
		var tex: Texture2D = row[1]
		var anc: Vector2 = row[2]
		var bb := _alpha_bbox(tex.get_image())
		var err: float = absf(bb.position.y + bb.size.y - anc.y)
		fails += _ok("%s 锚点 (%.0f,%.0f) → 可见底边误差 %.1f px" % [row[0], anc.x, anc.y, err],
			err < 0.51, "bbox 底 = %.1f" % (bb.position.y + bb.size.y))

	# ---- C 手部贴合：ART-RESET-001 退役
	# 量的是角色手部像素到车把的间隙；角色贴图已删，没有手部像素可量。
	print("[C] 手部贴合：已退役（角色贴图于 ART-RESET-001 删除，无手部像素可量）")

	# ---- D 货架层高与内宽
	print("[D] 货架结构")
	var heights: Array = _shelf_info["heights"]
	var inner: int = int(_shelf_info["inner"])
	fails += _ok("货架 %d 层，层高 %s，内宽 %d px" % [heights.size(), str(heights), inner],
		heights.size() == 4 and int(heights.min()) >= 32 and inner >= 64)
	fails += _ok("32×32 商品每层放得下（需 32 ≤ 最小层高 %d）" % int(heights.min()),
		int(heights.min()) >= 32)
	fails += _ok("64×48 上不了架（需 48 > 最小层高 %d）" % int(heights.min()),
		48 > int(heights.min()))
	fails += _ok("每层并排两件 32×32（需 64 ≤ 内宽 %d）" % inner, inner >= 64)
	fails += _ok("32×32 两件并排后左右各留余量 %d px" % (inner - 64), inner - 64 >= 0)

	# ---- E 上架落位：商品脚底贴层板，头不顶横梁
	print("[E] 商品落位")
	var levels: Array = _shelf_info["levels"]
	var ok_all := true
	for i in levels.size():
		var bottom: float = float(levels[i])
		var top: float = bottom + 32.0
		var head_room: float = float(heights[i]) - 32.0
		if head_room < 0.0:
			ok_all = false
		print("     第 %d 层：层板 y=%+.0f，放 32×32 后头顶余 %.0f px" % [i + 1, bottom, head_room])
	fails += _ok("四层摆放后都留有头顶余量", ok_all)

	# ---- F 镜像与碰撞不变式（角色中轴/绘制偏移已随贴图退役）
	print("[F] 镜像 / 碰撞不变式")
	_player.teleport_to(400.0)
	_player.set_facing(1)
	var x0 := _player.global_position.x
	_player.set_facing(-1)
	_player.set_facing(1)
	fails += _ok("镜像不碰碰撞盒：宽 %.0f 高 %.0f，仍以脚底为基线，世界 x 不变" % [
		_player.collision_width(), _player.collision_height()],
		_player.collision_width() == 28.0 and _player.collision_height() == 160.0
		and absf(_player.global_position.x - x0) < 0.01)

	# ---- G 交互与遮挡是否被加高影响
	print("[G] 交互 / 遮挡")
	var body := _cart.body_rect()
	fails += _ok("车可见包围盒 %.0f×%.0f（r02，旧版 96×74）" % [body.size.x, body.size.y],
		body.size.x == 96.0 and body.size.y == 90.0)
	fails += _ok("逻辑车长仍是冻结值 96（画布 128 不算车长）", _cart.cart_width == 96.0)
	_cart.place_at(560.0)
	_player.teleport_to(560.0 + 80.0)
	_cart.bind(_player)
	var prompt_y := _cart.hotspot.prompt_anchor().y
	var head_y := _player.global_position.y - 160.0
	fails += _ok("推行中提示锚点 y=%.0f，人物头顶 y=%.0f → 提示在头顶之上 %.0f px" % [
		prompt_y, head_y, head_y - prompt_y], head_y - prompt_y >= 4.0)
	await _frames(2)
	var front_on := _cart.front_layer_visible()
	_player.teleport_to(560.0)
	await _frames(2)
	var front_overlap := _cart.front_layer_visible()
	# ART-INTEGRATE-005 阶段1 起默认购物车为 r03 分件：近侧篮网是车的固有结构，
	# 前景层**常驻显示**（ART-004 的行为基线）。r02 单图版的"横向重叠才再画一遍"
	# 是旧实现细节，只在显式切回 r02 时断言，防止这条基线被静默改掉。
	if _cart.art_variant == PushableCart.ART_VARIANT_R03:
		fails += _ok("前景遮挡层（r03 分件）：站在车旁 %s / 与车重叠 %s（常驻显示）" % [
			"显示" if front_on else "隐藏", "显示" if front_overlap else "隐藏"],
			front_on and front_overlap)
	else:
		fails += _ok("前景遮挡层（r02 单图）：站在车旁 %s / 与车重叠 %s" % [
			"显示" if front_on else "隐藏", "显示" if front_overlap else "隐藏"],
			not front_on and front_overlap)
	_cart.unbind()
	await _frames(2)

	print("[T] 汇总：%s" % ("全部符合预期" if fails == 0 else "%d 项不符合预期" % fails))
	print("==============================================")
	if _args.has("quit"):
		get_tree().quit(0 if fails == 0 else 1)


# ---------------------------------------------------------------- 截图组

func _run_tour() -> void:
	_overlay.show_overlay = false
	for key in STATES:
		_apply_state(String(key))
		await _frames(8)
		await RenderingServer.frame_post_draw
		_capture("art003_%s.png" % key)
		_overlay.show_overlay = true
		_overlay.queue_redraw()
		await _frames(2)
		await RenderingServer.frame_post_draw
		_capture("art003_%s_debug.png" % key)
		_overlay.show_overlay = false
	print("[ART003] 截图完成，见 tests/screenshots/art003_*.png")
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

	# ART-RESET-001：角色没有贴图，不再画"可见框"；只画碰撞盒
	var cr := _player.collision_rect()
	var cworld := Rect2(_player.global_position + cr.position, cr.size)
	cv.draw_rect(cworld, Color(1.0, 0.42, 0.38, 0.85), false, 1.0)

	# 数值统一写成左下角图例，避免标签压在人身上
	var lines := PackedStringArray([
		"红=角色碰撞 %.0f×%.0f（角色贴图已删，无可见框）" % [cr.size.x, cr.size.y],
		"青=车可见 96×90（细线=画布 128×112，不是车长）",
	])
	var ly := VIEW.y - 62.0
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

	if _state == "shelves" or _state == "overview":
		var levels: Array = _shelf_info["levels"]
		var heights: Array = _shelf_info["heights"]
		for i in levels.size():
			var sx := 150.0 if _state == "shelves" else 220.0
			var bottom := GROUND_Y + float(levels[i])
			cv.draw_line(Vector2(sx - 48, bottom), Vector2(sx + 48, bottom),
				Color(0.55, 0.90, 0.98, 0.55), 1.0)
			_label(cv, sx + 52.0, bottom - 4.0, "层高 %d" % int(heights[i]), 9,
				Color(0.55, 0.90, 0.98))

	var note := "调试叠加层（F3）· 正式截图看无叠加层版本"
	var nw := _font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x if _font else 240.0
	_label(cv, VIEW.x - 24.0 - nw, VIEW.y - 14.0, note, 10, Color(0.9, 0.9, 0.88, 0.7))


func _label(cv: CanvasItem, x: float, y: float, s: String, size: int, c: Color) -> void:
	if _font == null:
		return
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	cv.draw_rect(Rect2(x - 2, y - size, w + 4, size + 3), Color(0.05, 0.045, 0.04, 0.8), true, -1.0, false)
	cv.draw_string(_font, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


# ---------------------------------------------------------------- 杂项

## 不透明像素的平均颜色。用来判断"这张图画的是水还是纸箱"，
## 尺寸、alpha、锚点都合格也查不出图形内容时，靠它兜底。
func _avg_rgb(tex: Texture2D) -> Vector3:
	var img := tex.get_image()
	if img == null:
		return Vector3.ZERO
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if p.a > 0.5:
				r += p.r
				g += p.g
				b += p.b
				n += 1
	if n == 0:
		return Vector3.ZERO
	return Vector3(r / float(n) * 255.0, g / float(n) * 255.0, b / float(n) * 255.0)


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
	print("[ART003] 截图 %-30s err=%d" % [filename, err])


## 顶部标题本身已经是字幕，底部再写一遍是冗余，所以 HUD 只在需要时给一行副标题
func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "HUD"
	add_child(_hud)


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and k.keycode == KEY_F3:
		_overlay.show_overlay = not _overlay.show_overlay
