class_name WhiteboxWorld
extends Node2D
## TASK-SCENE-002 · 第一季横版场景白盒工程统一构建器与开发预览器
##
## 节点结构（严格固定层级顺序，保障后续正式美术按槽位替换且不破坏购物车前后遮挡）：
##   World (WhiteboxWorld)
##   ├── Background        (天空底色、远景天际线剪影、分段背景色带)
##   ├── Environment       (1F/2F 连续地面与楼板、32px 格网刻度、左右物理边界墙)
##   ├── Buildings         (各建筑/房间独立容器 Building_<id>，挂载 art_slot 元数据与门窗楼梯结构)
##   ├── Props             (真实运行时货架 ART_FURN_101、商品 ART_ITEM_101/102、购物车 ART_FURN_103 及几何白盒道具)
##   ├── Actors            (Player 角色实例，位于 Props 之后以满足 PushableCart 分层绘制顺序)
##   ├── InteractionAreas  (DoorInteractable / StairInteractable / ShelfInteractable / SpotInteractable / InteractionSensor)
##   ├── DebugOverlay      (WhiteboxDebugOverlay，F3 比例与空间边界辅助线)
##   ├── Camera2D          (FollowCamera，支持跟随角色与 F2 自由平移/缩放)
##   └── UI                (开发预览顶栏、13 场景切换、地标快速跳转、F5 全图缩略总览条)

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const SHELF_TEX := preload("res://assets/facilities/ART_FURN_101_r01_empty_shelf_128x208.png")
const SHELF_ANCHOR := Vector2(64, 200)
const WATER_TEX := preload("res://assets/items/ART_ITEM_101_r02_water_64x48.png")
const WATER_SHELF_TEX := preload("res://assets/items/ART_ITEM_101_r02-shelf_water_32x32.png")
const FOOD_TEX := preload("res://assets/items/ART_ITEM_102_r02_food_carton_64x64.png")
const FOOD_SHELF_TEX := preload("res://assets/items/ART_ITEM_102_r02-shelf_food_32x32.png")

@export var location_key: StringName = &"outdoor_street"
@export var location_display_name: String = ""

var spec: Dictionary = {}
var current_floor: int = 1
var free_camera_mode: bool = false
var debug_guides_visible: bool = false
var clean_screenshot_mode: bool = false
var minimap_visible: bool = true

var _bg_root: Node2D
var _env_root: Node2D
var _buildings_root: Node2D
var _props_root: Node2D
var _actors_root: Node2D
var _interact_root: Node2D
var _debug_overlay: WhiteboxDebugOverlay
var _camera: FollowCamera
var _ui_layer: CanvasLayer

var _player: PlayerController
var _sensor: InteractionSensor
var _carts: Array[PushableCart] = []

var _top_panel: PanelContainer
var _header_label: Label
var _status_label: Label
var _prompt_label: Label
var _toast_label: Label
var _btn_cam_mode: Button
var _btn_zoom: Button
var _btn_debug: Button
var _btn_minimap: Button
var _minimap: WhiteboxMinimapStrip
var _toast_timer: float = 0.0


func _ready() -> void:
	spec = Season1Layout.get_scene_spec(location_key)
	if location_display_name == "":
		location_display_name = String(spec.get("title", String(location_key)))
	GameState.set_location(location_key)

	_ensure_hierarchy()
	_build_background()
	_build_environment()
	_build_buildings()
	_build_props_and_shelves()
	_spawn_player()
	_build_interaction_areas()
	_setup_camera()
	_setup_debug_overlay()
	_build_preview_ui()

	print("[WORLD] ready key=%s name=%s scene=%s width=%.0f" % [
		location_key,
		location_display_name,
		scene_file_path,
		float(spec.get("width", 1920.0)),
	])

	_check_cli_automation()


func _ensure_hierarchy() -> void:
	# 立即移除并释放预设空子节点，保证标准节点命名无重名后缀
	for child in get_children():
		remove_child(child)
		child.free()

	_bg_root = Node2D.new()
	_bg_root.name = "Background"
	add_child(_bg_root)

	_env_root = Node2D.new()
	_env_root.name = "Environment"
	add_child(_env_root)

	_buildings_root = Node2D.new()
	_buildings_root.name = "Buildings"
	add_child(_buildings_root)

	_props_root = Node2D.new()
	_props_root.name = "Props"
	add_child(_props_root)

	_actors_root = Node2D.new()
	_actors_root.name = "Actors"
	add_child(_actors_root)

	_interact_root = Node2D.new()
	_interact_root.name = "InteractionAreas"
	add_child(_interact_root)

	_debug_overlay = WhiteboxDebugOverlay.new()
	_debug_overlay.name = "DebugOverlay"
	_debug_overlay.visible = debug_guides_visible
	add_child(_debug_overlay)

	_camera = FollowCamera.new()
	_camera.name = "Camera2D"
	add_child(_camera)

	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UI"
	_ui_layer.layer = 20
	add_child(_ui_layer)


# ==============================================================================
# 1. Background：天空、远景城市剪影、分段背景色带
# ==============================================================================
func _build_background() -> void:
	var width: float = float(spec.get("width", 1920.0))
	var sky_col: Color = spec.get("sky_color", Color(0.22, 0.26, 0.31, 1.0))
	var is_outdoor: bool = bool(spec.get("is_outdoor", false))

	var sky := ColorRect.new()
	sky.name = "SkyBackdrop"
	sky.position = Vector2(-480.0, -360.0)
	sky.size = Vector2(width + 960.0, 960.0)
	sky.color = sky_col
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_root.add_child(sky)

	# 分段底色带
	var segments: Array = spec.get("segments", [])
	for seg in segments:
		var sx0: float = float(seg.get("x0", 0.0))
		var sx1: float = float(seg.get("x1", 0.0))
		var scol: Color = seg.get("color", sky_col)
		var band := ColorRect.new()
		band.name = "SegBand_%d" % int(seg.get("index", 1))
		band.position = Vector2(sx0, -260.0)
		band.size = Vector2(sx1 - sx0, 680.0)
		band.color = Color(scol.r, scol.g, scol.b, 0.45)
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bg_root.add_child(band)

	# 室外远景天际线剪影（纯几何色块，代表远处灰冷城区、高压塔与老居民楼轮廓）
	if is_outdoor:
		var skyline := Node2D.new()
		skyline.name = "DistantSkyline"
		skyline.set_meta("art_slot", "ART_BG_SKYLINE_S1")
		_bg_root.add_child(skyline)

		var sx := 64.0
		var idx := 0
		var heights := [160.0, 224.0, 192.0, 288.0, 176.0, 240.0, 312.0, 208.0]
		var widths := [192.0, 256.0, 160.0, 224.0, 288.0, 192.0, 224.0, 256.0]
		while sx < width - 256.0:
			var bw: float = widths[idx % widths.size()]
			var bh: float = heights[idx % heights.size()]
			var sil := ColorRect.new()
			sil.name = "Silhouette_%d" % idx
			sil.position = Vector2(sx, Season1Layout.GROUND_Y - bh - 96.0)
			sil.size = Vector2(bw, bh + 96.0)
			sil.color = Color(0.18, 0.21, 0.25, 0.42)
			sil.mouse_filter = Control.MOUSE_FILTER_IGNORE
			skyline.add_child(sil)
			sx += bw + 128.0
			idx += 1


# ==============================================================================
# 2. Environment：地面层、二层楼板、32px 刻度、分段柱与物理边界
# ==============================================================================
func _build_environment() -> void:
	var width: float = float(spec.get("width", 1920.0))
	var ground_y: float = float(spec.get("ground_y", Season1Layout.GROUND_Y))
	var ground_col: Color = spec.get("ground_color", Color(0.28, 0.30, 0.33, 1.0))
	var top_col: Color = spec.get("road_top_color", Color(0.44, 0.47, 0.50, 1.0))

	# 1F 主地面填充
	var ground_rect := ColorRect.new()
	ground_rect.name = "Ground1F_Fill"
	ground_rect.position = Vector2(-480.0, ground_y)
	ground_rect.size = Vector2(width + 960.0, 260.0)
	ground_rect.color = ground_col
	ground_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_env_root.add_child(ground_rect)

	var road_top := ColorRect.new()
	road_top.name = "Ground1F_Surface"
	road_top.position = Vector2(-480.0, ground_y)
	road_top.size = Vector2(width + 960.0, 10.0)
	road_top.color = top_col
	road_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_env_root.add_child(road_top)

	# 32px 地面砖缝刻度
	var ticks := Node2D.new()
	ticks.name = "GroundTileTicks"
	_env_root.add_child(ticks)
	var tx := 0.0
	while tx <= width:
		var is_major := is_zero_approx(fmod(tx, 320.0))
		var tick := ColorRect.new()
		tick.position = Vector2(tx, ground_y + 2.0)
		tick.size = Vector2(2.0 if is_major else 1.0, 14.0 if is_major else 7.0)
		tick.color = Color(0.10, 0.12, 0.14, 0.55 if is_major else 0.28)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ticks.add_child(tick)
		tx += 32.0

	# 分段立柱与顶部横幅提示
	var segments: Array = spec.get("segments", [])
	for seg in segments:
		var sx0: float = float(seg.get("x0", 0.0))
		var sx1: float = float(seg.get("x1", 0.0))
		var stitle: String = String(seg.get("title", ""))
		var ssum: String = String(seg.get("summary", ""))
		var marker := ColorRect.new()
		marker.name = "SegmentMarker_%d" % int(seg.get("index", 1))
		marker.position = Vector2(sx0, ground_y - 340.0)
		marker.size = Vector2(4.0, 340.0)
		marker.color = Color(0.92, 0.76, 0.38, 0.35)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_env_root.add_child(marker)

		var seg_lbl := _make_world_label(
			"【%s】 (%.0f ~ %.0f px)  %s" % [stitle, sx0, sx1, ssum],
			Vector2(sx0 + 16.0, -136.0),
			13,
			Color(0.95, 0.88, 0.68, 0.92)
		)
		_env_root.add_child(seg_lbl)

	# 物理碰撞边界与各层楼板 (1F / 2F 互不干扰)
	var floors: Array = spec.get("floors", [])
	for fl in floors:
		var fl_num: int = int(fl.get("floor", 1))
		var fg_y: float = float(fl.get("ground_y", ground_y))
		var fx0: float = float(fl.get("x0", 0.0))
		var fx1: float = float(fl.get("x1", width))

		if fl_num >= 2:
			# 2F 实体楼板视觉层 (厚 32px: y=128..160)
			var slab2f := ColorRect.new()
			slab2f.name = "Floor2F_SlabVisual"
			slab2f.position = Vector2(fx0, fg_y)
			slab2f.size = Vector2(fx1 - fx0, Season1Layout.SLAB_THICKNESS)
			slab2f.color = Color(top_col.r * 0.9, top_col.g * 0.9, top_col.b * 0.9, 1.0)
			slab2f.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_env_root.add_child(slab2f)

			var slab2f_top := ColorRect.new()
			slab2f_top.position = Vector2(fx0, fg_y)
			slab2f_top.size = Vector2(fx1 - fx0, 6.0)
			slab2f_top.color = top_col.lightened(0.15)
			slab2f_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_env_root.add_child(slab2f_top)

		# 该楼层的左右物理空气墙（仅包裹该层角色高度 y=fg_y-176 .. fg_y，避免跨层阻挡）
		_create_solid_box("Wall_F%d_Left" % fl_num, fx0 - 32.0, fg_y - 180.0, 32.0, 180.0)
		_create_solid_box("Wall_F%d_Right" % fl_num, fx1, fg_y - 180.0, 32.0, 180.0)


func _create_solid_box(node_name: String, x: float, y_top: float, w: float, h: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = node_name
	body.position = Vector2(x + w * 0.5, y_top + h * 0.5)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	cs.shape = rect
	body.add_child(cs)
	_env_root.add_child(body)
	return body


# ==============================================================================
# 3. Buildings：建筑立面 / 室内房间剖面 / 屋顶 / 窗户 / 门框 / 楼梯
# ==============================================================================
func _build_buildings() -> void:
	var buildings: Array = spec.get("buildings", [])
	for b in buildings:
		var bid: String = String(b.get("id", "building"))
		var bx: float = float(b.get("x", 0.0))
		var bw: float = float(b.get("w", 320.0))
		var bh: float = float(b.get("h", 256.0))
		var bfloor: int = int(b.get("floor", 1))
		var floors_count: int = int(b.get("floors_count", 1))
		var base_y := Season1Layout.GROUND_Y if bfloor == 1 else Season1Layout.FLOOR2_Y
		var wall_col: Color = b.get("wall_color", Color(0.35, 0.37, 0.40, 1.0))
		var roof_col: Color = b.get("roof_color", Color(0.24, 0.26, 0.28, 1.0))
		var accent_col: Color = b.get("accent_color", Color(0.82, 0.66, 0.42, 1.0))
		var roof_style: String = String(b.get("roof_style", "flat"))
		var art_slot: String = String(b.get("art_slot", ""))
		var doc_code: String = String(b.get("doc_code", ""))
		var title: String = String(b.get("title", bid))
		var subtitle: String = String(b.get("subtitle", ""))

		var bnode := Node2D.new()
		bnode.name = "Building_" + bid
		bnode.position = Vector2(bx, base_y)
		bnode.set_meta("art_slot", art_slot)
		bnode.set_meta("doc_code", doc_code)
		bnode.set_meta("footprint_rect", Rect2(bx, base_y - bh, bw, bh))
		_buildings_root.add_child(bnode)

		# VisualSlot 供后续正式美术直接替换 Sprite2D / TileMapLayer
		var visual_slot := Node2D.new()
		visual_slot.name = "VisualSlot"
		bnode.add_child(visual_slot)

		# 主墙体
		var wall := ColorRect.new()
		wall.name = "WallBody"
		wall.position = Vector2(0.0, -bh)
		wall.size = Vector2(bw, bh)
		wall.color = wall_col
		wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual_slot.add_child(wall)

		# 墙体四周描边与底座踢脚线
		var plinth := ColorRect.new()
		plinth.name = "Plinth"
		plinth.position = Vector2(0.0, -16.0)
		plinth.size = Vector2(bw, 16.0)
		plinth.color = roof_col.darkened(0.15)
		plinth.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual_slot.add_child(plinth)

		var left_pillar := ColorRect.new()
		left_pillar.position = Vector2(0.0, -bh)
		left_pillar.size = Vector2(10.0, bh)
		left_pillar.color = roof_col
		left_pillar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual_slot.add_child(left_pillar)

		var right_pillar := ColorRect.new()
		right_pillar.position = Vector2(bw - 10.0, -bh)
		right_pillar.size = Vector2(10.0, bh)
		right_pillar.color = roof_col
		right_pillar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual_slot.add_child(right_pillar)

		# 若为室外双层建筑外观，绘制 1F/2F 分层腰线
		if floors_count >= 2:
			var belt := ColorRect.new()
			belt.name = "FloorBelt2F"
			belt.position = Vector2(0.0, -240.0)
			belt.size = Vector2(bw, 14.0)
			belt.color = roof_col
			belt.mouse_filter = Control.MOUSE_FILTER_IGNORE
			visual_slot.add_child(belt)

		# 屋顶 / 门头招牌 / 雨棚 / 屋顶天线 / 遮棚样式
		_build_roof_feature(visual_slot, bw, bh, roof_col, accent_col, roof_style)

		# 窗户 / 橱窗 / 百叶窗 / 信息板
		var windows: Array = b.get("windows", [])
		for w_idx in range(windows.size()):
			var win: Dictionary = windows[w_idx]
			var wx: float = float(win.get("x", bx + 64.0)) - bx
			var wy_off: float = float(win.get("y_off", 96.0))
			var ww: float = float(win.get("w", 96.0))
			var wh: float = float(win.get("h", 80.0))
			var wkind: String = String(win.get("kind", "warm"))
			var wlabel: String = String(win.get("label", ""))
			_build_window_node(visual_slot, w_idx, wx, -wy_off - wh, ww, wh, wkind, wlabel)

		# 建筑顶部信息铭牌
		var header_lbl := _make_world_label(
			"[%s] %s" % [doc_code, title],
			Vector2(14.0, -bh + 8.0),
			14,
			accent_col.lightened(0.25)
		)
		visual_slot.add_child(header_lbl)

		if subtitle != "":
			var sub_lbl := _make_world_label(
				subtitle,
				Vector2(14.0, -bh + 28.0),
				11,
				Color(0.86, 0.89, 0.93, 0.85)
			)
			visual_slot.add_child(sub_lbl)

		var notes: Array = b.get("notes", [])
		for n_i in range(notes.size()):
			var note_lbl := _make_world_label(
				"• " + String(notes[n_i]),
				Vector2(14.0, -bh + 46.0 + float(n_i) * 16.0),
				10,
				Color(0.76, 0.84, 0.90, 0.78)
			)
			visual_slot.add_child(note_lbl)

	# 绘制所有门框视觉（含可交互门与装饰门，严格按 96×192 或 192×224）
	var doors: Array = spec.get("doors", [])
	for d in doors:
		_build_door_visual(d)

	# 绘制所有室内楼梯视觉（连接 1F y=416 与 2F y=128）
	var stairs: Array = spec.get("stairs", [])
	for st in stairs:
		if int(st.get("from_floor", 1)) == 1:
			_build_stair_visual(st)


func _build_roof_feature(parent: Node2D, bw: float, bh: float, roof_col: Color, accent_col: Color, style: String) -> void:
	# 顶部檐口压条
	var cornice := ColorRect.new()
	cornice.position = Vector2(-8.0, -bh - 16.0)
	cornice.size = Vector2(bw + 16.0, 16.0)
	cornice.color = roof_col
	cornice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cornice)

	match style:
		"pitched_antenna":
			# 外婆旧两层小楼：坡屋顶 + M 屋顶电台天线支架
			var poly := Polygon2D.new()
			poly.polygon = PackedVector2Array([
				Vector2(-16.0, -bh - 16.0),
				Vector2(bw * 0.45, -bh - 64.0),
				Vector2(bw + 16.0, -bh - 16.0),
			])
			poly.color = roof_col.darkened(0.12)
			parent.add_child(poly)

			# M 屋顶天线杆
			var mast := ColorRect.new()
			mast.position = Vector2(bw * 0.68, -bh - 96.0)
			mast.size = Vector2(6.0, 80.0)
			mast.color = accent_col
			mast.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(mast)

			var cross1 := ColorRect.new()
			cross1.position = Vector2(bw * 0.68 - 24.0, -bh - 84.0)
			cross1.size = Vector2(54.0, 4.0)
			cross1.color = accent_col
			cross1.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(cross1)

			var ant_lbl := _make_world_label("M 屋顶天线位(P06B)", Vector2(bw * 0.68 + 12.0, -bh - 88.0), 11, accent_col)
			parent.add_child(ant_lbl)

		"apartment_awning":
			# 居民楼右侧 T 低遮棚屋顶与排水管 + 小狗观察位
			var awning := ColorRect.new()
			awning.position = Vector2(bw - 288.0, -248.0)
			awning.size = Vector2(304.0, 18.0)
			awning.color = accent_col.darkened(0.25)
			awning.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(awning)

			var pipe := ColorRect.new()
			pipe.position = Vector2(bw - 36.0, -bh)
			pipe.size = Vector2(10.0, bh)
			pipe.color = Color(0.50, 0.56, 0.62, 0.90)
			pipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(pipe)

			# 屋顶小狗白盒占位标记 (S04)
			var dog_marker := ColorRect.new()
			dog_marker.position = Vector2(bw - 180.0, -276.0)
			dog_marker.size = Vector2(36.0, 28.0)
			dog_marker.color = Color(0.92, 0.76, 0.48, 0.95)
			dog_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(dog_marker)

			var dog_lbl := _make_world_label("T 遮棚屋顶·小狗位(S04)", Vector2(bw - 240.0, -296.0), 11, Color(1.0, 0.88, 0.55, 0.98))
			parent.add_child(dog_lbl)

		"supermarket_fascia", "shop_sign":
			# 商铺空白招牌灯箱带（不烘焙硬编码店名，留给正式美术/贴花）
			var sign_board := ColorRect.new()
			sign_board.position = Vector2(24.0, -bh + 64.0)
			sign_board.size = Vector2(bw - 48.0, 36.0)
			sign_board.color = accent_col.darkened(0.35)
			sign_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(sign_board)

			var sign_trim := ColorRect.new()
			sign_trim.position = Vector2(24.0, -bh + 96.0)
			sign_trim.size = Vector2(bw - 48.0, 4.0)
			sign_trim.color = accent_col
			sign_trim.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(sign_trim)

		"industrial_warehouse":
			# 工业锯齿/桁架顶梁
			var beam := ColorRect.new()
			beam.position = Vector2(0.0, -bh + 56.0)
			beam.size = Vector2(bw, 12.0)
			beam.color = accent_col.darkened(0.30)
			beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(beam)


func _build_window_node(parent: Node2D, idx: int, x: float, y: float, w: float, h: float, kind: String, label_txt: String) -> void:
	var frame := ColorRect.new()
	frame.name = "Window_%d" % idx
	frame.position = Vector2(x, y)
	frame.size = Vector2(w, h)
	frame.color = Color(0.16, 0.19, 0.22, 0.95)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)

	var pane := ColorRect.new()
	pane.position = Vector2(4.0, 4.0)
	pane.size = Vector2(w - 8.0, h - 8.0)
	pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match kind:
		"warm", "warm_2f", "warm_plant":
			pane.color = Color(0.86, 0.68, 0.38, 0.72)
		"window_m":
			pane.color = Color(0.36, 0.52, 0.68, 0.78)
		"louver":
			pane.color = Color(0.28, 0.34, 0.38, 0.90)
		"board":
			pane.color = Color(0.68, 0.64, 0.54, 0.85)
		"shutter":
			pane.color = Color(0.42, 0.46, 0.50, 0.88)
		_:
			pane.color = Color(0.42, 0.56, 0.68, 0.58)
	frame.add_child(pane)

	# 窗棂十字线或百叶横条
	if kind == "louver" or kind == "shutter":
		var sy := 10.0
		while sy < h - 8.0:
			var slat := ColorRect.new()
			slat.position = Vector2(6.0, sy)
			slat.size = Vector2(w - 12.0, 3.0)
			slat.color = Color(0.18, 0.22, 0.26, 0.85)
			slat.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.add_child(slat)
			sy += 10.0
	else:
		var mullion_v := ColorRect.new()
		mullion_v.position = Vector2(w * 0.5 - 1.5, 4.0)
		mullion_v.size = Vector2(3.0, h - 8.0)
		mullion_v.color = Color(0.18, 0.20, 0.24, 0.80)
		mullion_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(mullion_v)

	# V 外婆留下的窗台绿植标记
	if kind == "warm_plant" or kind == "window_m":
		var pot := ColorRect.new()
		pot.position = Vector2(14.0, h - 22.0)
		pot.size = Vector2(20.0, 18.0)
		pot.color = Color(0.38, 0.72, 0.44, 0.95)
		pot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(pot)

	if label_txt != "":
		var wlbl := _make_world_label(label_txt, Vector2(4.0, -16.0), 10, Color(0.88, 0.92, 0.96, 0.88))
		frame.add_child(wlbl)


func _build_door_visual(d: Dictionary) -> void:
	var did: String = String(d.get("id", "door"))
	var dx: float = float(d.get("x", 0.0))
	var dw: float = float(d.get("w", Season1Layout.DOOR_STD_W))
	var dh: float = float(d.get("h", Season1Layout.DOOR_STD_H))
	var dfloor: int = int(d.get("floor", 1))
	var base_y := Season1Layout.GROUND_Y if dfloor == 1 else Season1Layout.FLOOR2_Y
	var is_inter: bool = bool(d.get("interactive", true))
	var style: String = String(d.get("style", "std"))
	var dlabel: String = String(d.get("label", did))

	var dnode := Node2D.new()
	dnode.name = "DoorVisual_" + did
	dnode.position = Vector2(dx, base_y)
	dnode.set_meta("art_slot", "ART_DOOR_" + did.to_upper())
	_buildings_root.add_child(dnode)

	# 门外框 (96×192 或 192×224)
	var frame := ColorRect.new()
	frame.position = Vector2(-dw * 0.5, -dh)
	frame.size = Vector2(dw, dh)
	frame.color = Color(0.22, 0.25, 0.28, 1.0) if is_inter else Color(0.24, 0.25, 0.27, 0.80)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dnode.add_child(frame)

	# 净通行门洞 (标准门 80×184，宽入口 184×216)
	var inset := 8.0 if dw <= 96.0 else 4.0
	var net_w := dw - inset * 2.0
	var net_h := dh - 8.0
	var leaf := ColorRect.new()
	leaf.position = Vector2(-net_w * 0.5, -net_h)
	leaf.size = Vector2(net_w, net_h)
	leaf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match style:
		"reinforced_home":
			leaf.color = Color(0.52, 0.36, 0.24, 1.0)
		"wide_glass", "glass":
			leaf.color = Color(0.36, 0.56, 0.66, 0.88)
		"wide_industrial", "metal":
			leaf.color = Color(0.38, 0.43, 0.48, 1.0)
		"shutter":
			leaf.color = Color(0.35, 0.42, 0.46, 1.0)
		"locked_warm_seam":
			leaf.color = Color(0.26, 0.30, 0.36, 1.0)
		"deco":
			leaf.color = Color(0.30, 0.32, 0.35, 0.72)
		_:
			leaf.color = Color(0.46, 0.38, 0.30, 1.0)
	dnode.add_child(leaf)

	# 双开门中缝或单开门把手
	if dw >= 160.0:
		var seam := ColorRect.new()
		seam.position = Vector2(-2.0, -net_h)
		seam.size = Vector2(4.0, net_h)
		seam.color = Color(0.15, 0.18, 0.20, 0.90)
		seam.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dnode.add_child(seam)
	else:
		var handle := ColorRect.new()
		handle.position = Vector2(net_w * 0.5 - 14.0, -96.0)
		handle.size = Vector2(6.0, 18.0)
		handle.color = Color(0.92, 0.78, 0.42, 0.95) if is_inter else Color(0.55, 0.55, 0.58, 0.70)
		handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dnode.add_child(handle)

	# P00 前世反锁家门底部暖光门缝
	if style == "locked_warm_seam":
		var warm_seam := ColorRect.new()
		warm_seam.position = Vector2(-net_w * 0.5, -6.0)
		warm_seam.size = Vector2(net_w, 6.0)
		warm_seam.color = Color(1.0, 0.76, 0.32, 0.95)
		warm_seam.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dnode.add_child(warm_seam)

	# 门楣标识条（绿色=可进入切换，灰色=装饰门）
	var header_bar := ColorRect.new()
	header_bar.position = Vector2(-dw * 0.5, -dh - 6.0)
	header_bar.size = Vector2(dw, 6.0)
	header_bar.color = Color(0.32, 0.88, 0.52, 0.95) if is_inter else Color(0.55, 0.58, 0.62, 0.65)
	header_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dnode.add_child(header_bar)

	var dlbl := _make_world_label(
		dlabel + (" [E]" if is_inter else ""),
		Vector2(-dw * 0.5, -dh - 24.0),
		11,
		Color(0.68, 0.98, 0.76, 0.96) if is_inter else Color(0.72, 0.75, 0.78, 0.78)
	)
	dnode.add_child(dlbl)


func _build_stair_visual(st: Dictionary) -> void:
	var sx: float = float(st.get("x", 0.0))
	var sw: float = float(st.get("w", 128.0))
	var y1: float = float(st.get("from_y", Season1Layout.GROUND_Y))
	var y2: float = float(st.get("to_y", Season1Layout.FLOOR2_Y))
	var slabel: String = String(st.get("label", "楼梯"))

	var snode := Node2D.new()
	snode.name = "StairVisual_" + String(st.get("id", "stair"))
	snode.set_meta("art_slot", "ART_STAIR_VERTICAL")
	_buildings_root.add_child(snode)

	# 楼梯井背景框
	var well := ColorRect.new()
	well.position = Vector2(sx - sw * 0.5, y2 - 160.0)
	well.size = Vector2(sw, (y1 - y2) + 160.0)
	well.color = Color(0.18, 0.20, 0.23, 0.78)
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	snode.add_child(well)

	# 台阶几何踏步 (9 级台阶，每级 32px 高，总计 288px)
	var steps_count := 9
	var dy := (y1 - y2) / float(steps_count)
	var dx := sw / float(steps_count)
	for i in range(steps_count):
		var step := ColorRect.new()
		step.position = Vector2(sx - sw * 0.5 + float(i) * dx, y1 - float(i + 1) * dy)
		step.size = Vector2(sw - float(i) * dx, 8.0)
		step.color = Color(0.56, 0.46, 0.34, 0.92)
		step.mouse_filter = Control.MOUSE_FILTER_IGNORE
		snode.add_child(step)

	# 扶手斜线
	var rail := Line2D.new()
	rail.points = PackedVector2Array([
		Vector2(sx - sw * 0.5, y1 - 36.0),
		Vector2(sx + sw * 0.5, y2 - 36.0),
	])
	rail.width = 3.0
	rail.default_color = Color(0.86, 0.72, 0.46, 0.90)
	snode.add_child(rail)

	var lbl_1f := _make_world_label(slabel + " (1F→2F [E])", Vector2(sx - sw * 0.5, y1 - 196.0), 11, Color(0.58, 0.92, 1.0, 0.96))
	snode.add_child(lbl_1f)
	var lbl_2f := _make_world_label(slabel + " (2F→1F [E])", Vector2(sx - sw * 0.5, y2 - 180.0), 11, Color(0.58, 0.92, 1.0, 0.96))
	snode.add_child(lbl_2f)


# ==============================================================================
# 4. Props：真实运行时货架/商品/购物车 + 几何白盒道具
# ==============================================================================
func _build_props_and_shelves() -> void:
	var width: float = float(spec.get("width", 1920.0))

	# 4.1 真实四层金属货架 (ART_FURN_101 r01, 96×192) + 32×32 上架商品 (ART_ITEM_101/102 r02-shelf)
	var shelves: Array = spec.get("shelves", [])
	for sh in shelves:
		var sh_id: String = String(sh.get("id", "shelf"))
		var sh_x: float = float(sh.get("x", 0.0))
		var sh_floor: int = int(sh.get("floor", 1))
		var base_y := Season1Layout.GROUND_Y if sh_floor == 1 else Season1Layout.FLOOR2_Y
		var sh_label: String = String(sh.get("label", sh_id))
		var items: Array = sh.get("items", [])

		var snode := Node2D.new()
		snode.name = "Shelf_" + sh_id
		snode.position = Vector2(sh_x, base_y)
		snode.set_meta("art_slot", "ART_FURN_101")
		_props_root.add_child(snode)

		var sp := Sprite2D.new()
		sp.name = "ShelfSprite"
		sp.texture = SHELF_TEX
		sp.centered = false
		sp.offset = -SHELF_ANCHOR
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		snode.add_child(sp)

		# 在层板上放置真实 32×32 商品图标
		var tier_offsets := [-146.0, -104.0, -62.0, -20.0]
		for t_i in range(min(items.size(), tier_offsets.size())):
			var item_kind := String(items[t_i])
			var tex: Texture2D = WATER_SHELF_TEX if item_kind == "water" else FOOD_SHELF_TEX
			for col_i in range(2):
				var isp := Sprite2D.new()
				isp.texture = tex
				isp.centered = false
				isp.position = Vector2(-34.0 + float(col_i) * 36.0, tier_offsets[t_i] - 32.0)
				isp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				snode.add_child(isp)

		var slbl := _make_world_label(sh_label, Vector2(-48.0, -214.0), 10, Color(0.95, 0.86, 0.68, 0.92))
		snode.add_child(slbl)

	# 4.2 几何白盒道具与落地商品堆
	var props: Array = spec.get("props", [])
	for p in props:
		_build_single_prop(p)

	# 4.3 真实可推购物车 (PushableCart r03 分层，位于 Props 下，因此树顺序在 Actors/Player 之前)
	_carts.clear()
	var carts_spec: Array = spec.get("carts", [])
	for c_i in range(carts_spec.size()):
		var cdict: Dictionary = carts_spec[c_i]
		var cx: float = float(cdict.get("x", 640.0))
		var cfloor: int = int(cdict.get("floor", 1))
		var base_y := Season1Layout.GROUND_Y if cfloor == 1 else Season1Layout.FLOOR2_Y
		var cart := PushableCart.new()
		cart.name = "Cart" if c_i == 0 else ("Cart_%d" % (c_i + 1))
		cart.ground_y = base_y
		cart.world_left = 96.0
		cart.world_right = width - 96.0
		cart.load_state = cdict.get("load_state", &"empty")
		_props_root.add_child(cart)
		cart.place_at(cx)
		_carts.append(cart)


func _build_single_prop(p: Dictionary) -> void:
	var pid: String = String(p.get("id", "prop"))
	var plabel: String = String(p.get("label", pid))
	var pkind: String = String(p.get("kind", "box"))
	var px: float = float(p.get("x", 0.0))
	var pw: float = float(p.get("w", 128.0))
	var ph: float = float(p.get("h", 96.0))
	var pfloor: int = int(p.get("floor", 1))
	var base_y := Season1Layout.GROUND_Y if pfloor == 1 else Season1Layout.FLOOR2_Y
	var has_spot := String(p.get("spot_detail", "")) != ""

	var pnode := Node2D.new()
	pnode.name = "Prop_" + pid
	pnode.position = Vector2(px, base_y)
	pnode.set_meta("art_slot", "ART_PROP_" + pid.to_upper())
	_props_root.add_child(pnode)

	var body := ColorRect.new()
	body.position = Vector2(-pw * 0.5, -ph)
	body.size = Vector2(pw, ph)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match pkind:
		"bed":
			body.color = Color(0.46, 0.36, 0.32, 0.92)
		"desk_plant", "work_bench", "counter":
			body.color = Color(0.48, 0.38, 0.28, 0.94)
		"kitchen":
			body.color = Color(0.38, 0.40, 0.42, 0.94)
		"generator_pad":
			body.color = Color(0.32, 0.38, 0.42, 0.94)
		"breaker":
			body.color = Color(0.28, 0.36, 0.44, 0.95)
		"cooler":
			body.color = Color(0.32, 0.48, 0.56, 0.92)
		"notice_board", "bus_sign":
			body.color = Color(0.42, 0.46, 0.50, 0.92)
		"barrier":
			body.color = Color(0.76, 0.44, 0.28, 0.90)
		_:
			body.color = Color(0.38, 0.41, 0.45, 0.88)
	pnode.add_child(body)

	var top_bar := ColorRect.new()
	top_bar.position = Vector2(-pw * 0.5, -ph)
	top_bar.size = Vector2(pw, 6.0)
	top_bar.color = Color(0.92, 0.76, 0.42, 0.90) if has_spot else Color(0.65, 0.70, 0.75, 0.75)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pnode.add_child(top_bar)

	# 若是落地物资堆，叠加真实 64×48 饮用水与 64×64 食品箱图标
	if pkind == "floor_items" or pkind == "delivery_pad":
		var sp_w := Sprite2D.new()
		sp_w.texture = WATER_TEX
		sp_w.centered = false
		sp_w.position = Vector2(-56.0, -48.0)
		sp_w.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pnode.add_child(sp_w)

		var sp_f := Sprite2D.new()
		sp_f.texture = FOOD_TEX
		sp_f.centered = false
		sp_f.position = Vector2(4.0, -64.0)
		sp_f.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pnode.add_child(sp_f)

	var plbl := _make_world_label(
		plabel + (" [E]" if has_spot else ""),
		Vector2(-pw * 0.5, -ph - 20.0),
		10,
		Color(0.96, 0.88, 0.62, 0.95) if has_spot else Color(0.82, 0.86, 0.90, 0.85)
	)
	pnode.add_child(plbl)


# ==============================================================================
# 5. Actors：实例化现有 PlayerController（保持 160px 可见高度与冻结移动参数）
# ==============================================================================
func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate() as PlayerController
	_player.name = "Player"
	_actors_root.add_child(_player)

	var spawns: Dictionary = spec.get("spawns", {})
	var spawn_id: StringName = SceneRouter.pending_spawn_id
	SceneRouter.pending_spawn_id = &""
	if not spawns.has(spawn_id):
		spawn_id = spec.get("default_spawn", &"")

	var sp_data: Dictionary = spawns.get(spawn_id, {"x": 320.0, "floor": 1, "ground_y": Season1Layout.GROUND_Y, "facing": 1})
	current_floor = int(sp_data.get("floor", 1))
	var sy: float = float(sp_data.get("ground_y", Season1Layout.GROUND_Y))
	var sx: float = float(sp_data.get("x", 320.0))
	var sfacing: int = int(sp_data.get("facing", 1))

	_player.ground_y = sy
	_player.teleport_to(sx)
	_player.set_facing(sfacing)


# ==============================================================================
# 6. InteractionAreas：门 / 楼梯 / 货架 / 观察点 / 传感器
# ==============================================================================
func _build_interaction_areas() -> void:
	# 6.1 门热点 (DoorInteractable)
	var doors: Array = spec.get("doors", [])
	for d in doors:
		var did: String = String(d.get("id", "door"))
		var dx: float = float(d.get("x", 0.0))
		var dw: float = float(d.get("w", Season1Layout.DOOR_STD_W))
		var dh: float = float(d.get("h", Season1Layout.DOOR_STD_H))
		var dfloor: int = int(d.get("floor", 1))
		var base_y := Season1Layout.GROUND_Y if dfloor == 1 else Season1Layout.FLOOR2_Y

		var area := DoorInteractable.new()
		area.name = "Door_" + did
		area.door_label = String(d.get("label", did))
		area.prompt_subject = String(d.get("prompt", ""))
		area.target_scene = d.get("target_scene", &"")
		area.target_spawn_id = d.get("target_spawn", &"")
		area.interactive = bool(d.get("interactive", true))
		area.interact_priority = 10
		area.position = Vector2(dx, base_y - dh * 0.5)

		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(dw + 24.0, dh)
		cs.shape = rect
		area.add_child(cs)
		_interact_root.add_child(area)

	# 6.2 楼梯热点 (StairInteractable)
	var stairs: Array = spec.get("stairs", [])
	for st in stairs:
		var st_id: String = String(st.get("id", "stair"))
		var sx: float = float(st.get("x", 0.0))
		var sw: float = float(st.get("w", 128.0))
		var from_y: float = float(st.get("from_y", Season1Layout.GROUND_Y))

		var sarea := StairInteractable.new()
		sarea.name = "Stair_" + st_id
		sarea.stair_label = String(st.get("label", "楼梯"))
		sarea.from_floor = int(st.get("from_floor", 1))
		sarea.to_floor = int(st.get("to_floor", 2))
		sarea.target_ground_y = float(st.get("to_y", Season1Layout.FLOOR2_Y))
		sarea.target_x = float(st.get("target_x", sx))
		sarea.interact_priority = 9
		sarea.position = Vector2(sx, from_y - 96.0)
		sarea.stair_used.connect(_on_stair_used)

		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(sw + 16.0, 192.0)
		cs.shape = rect
		sarea.add_child(cs)
		_interact_root.add_child(sarea)

	# 6.3 货架热点 (ShelfInteractable)
	var shelves: Array = spec.get("shelves", [])
	for sh in shelves:
		var sh_id: String = String(sh.get("id", "shelf"))
		var sh_x: float = float(sh.get("x", 0.0))
		var sh_floor: int = int(sh.get("floor", 1))
		var base_y := Season1Layout.GROUND_Y if sh_floor == 1 else Season1Layout.FLOOR2_Y

		var sh_area := ShelfInteractable.new()
		sh_area.name = "ShelfArea_" + sh_id
		sh_area.note = String(sh.get("note", sh.get("label", sh_id)))
		sh_area.interact_priority = 5
		sh_area.position = Vector2(sh_x, base_y - 96.0)
		sh_area.inspected.connect(_on_shelf_inspected)

		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(120.0, 192.0)
		cs.shape = rect
		sh_area.add_child(cs)
		_interact_root.add_child(sh_area)

	# 6.4 关键地标/设施观察点 (SpotInteractable)
	var props: Array = spec.get("props", [])
	for p in props:
		var detail: String = String(p.get("spot_detail", ""))
		if detail == "":
			continue
		var pid: String = String(p.get("id", "spot"))
		var px: float = float(p.get("x", 0.0))
		var pw: float = float(p.get("w", 128.0))
		var ph: float = float(p.get("h", 96.0))
		var pfloor: int = int(p.get("floor", 1))
		var base_y := Season1Layout.GROUND_Y if pfloor == 1 else Season1Layout.FLOOR2_Y

		var sp_area := SpotInteractable.new()
		sp_area.name = "Spot_" + pid
		sp_area.spot_title = String(p.get("label", pid))
		sp_area.spot_detail = detail
		sp_area.interact_priority = 4
		sp_area.position = Vector2(px, base_y - maxf(ph, 128.0) * 0.5)
		sp_area.spot_inspected.connect(_on_spot_inspected)

		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(pw + 24.0, maxf(ph, 160.0))
		cs.shape = rect
		sp_area.add_child(cs)
		_interact_root.add_child(sp_area)

	# 6.5 交互传感器 (InteractionSensor)
	_sensor = InteractionSensor.new()
	_sensor.name = "Sensor"
	_sensor.actor = _player
	_sensor.target_changed.connect(_on_sensor_focus_changed)
	_interact_root.add_child(_sensor)
	_sensor.actor_path = _sensor.get_path_to(_player)


func _on_stair_used(from_fl: int, to_fl: int, _target_x: float, new_ground_y: float) -> void:
	current_floor = to_fl
	_show_toast("楼梯切换：%dF → %dF (地面 y=%.0f)" % [from_fl, to_fl, new_ground_y])
	if _camera != null and not free_camera_mode:
		_camera.snap_to_target()


func _on_shelf_inspected(note: String, _anchor: Vector2) -> void:
	_show_toast("查看货架：" + note)


func _on_spot_inspected(title: String, detail: String, _anchor: Vector2) -> void:
	_show_toast("【%s】%s" % [title, detail])


func _on_sensor_focus_changed(_item: Interactable) -> void:
	_refresh_hud_labels()


# ==============================================================================
# 7. Camera2D & DebugOverlay
# ==============================================================================
func _setup_camera() -> void:
	var width: float = float(spec.get("width", 1920.0))
	_camera.target_path = _camera.get_path_to(_player)
	_camera._target = _player
	_camera.look_offset = Vector2(0.0, -146.0)
	_camera.dead_zone = Vector2(56.0, 24.0)
	_camera.smoothing = 8.0
	_camera.limit_left = 0
	_camera.limit_right = int(maxf(width, 960.0))
	_camera.limit_top = -220
	_camera.limit_bottom = 540
	_camera.make_current()
	_camera.snap_to_target()


func _setup_debug_overlay() -> void:
	_debug_overlay.setup(spec, _player)
	_debug_overlay.visible = debug_guides_visible


# ==============================================================================
# 8. UI：开发预览顶栏、场景切换、地标跳转、自由镜头、F3/F4/F5 控制
# ==============================================================================
func _build_preview_ui() -> void:
	_top_panel = PanelContainer.new()
	_top_panel.name = "PreviewTopPanel"
	_top_panel.position = Vector2(8.0, 6.0)
	_top_panel.size = Vector2(944.0, 108.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.11, 0.88)
	sb.border_color = Color(0.38, 0.52, 0.66, 0.75)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 5.0
	sb.content_margin_bottom = 5.0
	_top_panel.add_theme_stylebox_override("panel", sb)
	_ui_layer.add_child(_top_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	_top_panel.add_child(vbox)

	# 第一行：当前场景标题 + 坐标状态 + 当前可交互提示
	var row_info := HBoxContainer.new()
	row_info.add_theme_constant_override("separation", 10)
	vbox.add_child(row_info)

	_header_label = Label.new()
	_header_label.add_theme_font_size_override("font_size", 12)
	_header_label.add_theme_color_override("font_color", Color(0.98, 0.88, 0.56))
	row_info.add_child(_header_label)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.78, 0.88, 0.96))
	row_info.add_child(_status_label)

	_prompt_label = Label.new()
	_prompt_label.add_theme_font_size_override("font_size", 12)
	_prompt_label.add_theme_color_override("font_color", Color(0.42, 1.0, 0.65))
	row_info.add_child(_prompt_label)

	# 第二行：13 张场景快速切换栏
	var row_scenes := HBoxContainer.new()
	row_scenes.add_theme_constant_override("separation", 2)
	vbox.add_child(row_scenes)

	var sc_tag := Label.new()
	sc_tag.text = "场景:"
	sc_tag.add_theme_font_size_override("font_size", 10)
	sc_tag.add_theme_color_override("font_color", Color(0.70, 0.78, 0.86))
	row_scenes.add_child(sc_tag)

	for skey in Season1Layout.SCENE_ORDER:
		var sbtn := _make_compact_btn(String(Season1Layout.SCENE_SHORT_NAMES.get(skey, String(skey))), skey == location_key)
		sbtn.pressed.connect(func() -> void:
			SceneRouter.pending_spawn_id = &""
			SceneRouter.goto(skey)
		)
		row_scenes.add_child(sbtn)

	var menu_btn := _make_compact_btn("主菜单(Esc)", false)
	menu_btn.pressed.connect(func() -> void: SceneRouter.goto_main_menu())
	row_scenes.add_child(menu_btn)

	# 第三行：当前场景地标快速跳转按钮
	var row_landmarks := HBoxContainer.new()
	row_landmarks.add_theme_constant_override("separation", 2)
	vbox.add_child(row_landmarks)

	var lm_tag := Label.new()
	lm_tag.text = "跳转:"
	lm_tag.add_theme_font_size_override("font_size", 10)
	lm_tag.add_theme_color_override("font_color", Color(0.70, 0.78, 0.86))
	row_landmarks.add_child(lm_tag)

	var landmarks: Array = spec.get("landmarks", [])
	for lm in landmarks:
		var lx: float = float(lm.get("x", 0.0))
		var lfl: int = int(lm.get("floor", 1))
		var lbtn := _make_compact_btn(String(lm.get("label", "")), false)
		lbtn.pressed.connect(func() -> void: jump_to_position(lx, lfl))
		row_landmarks.add_child(lbtn)

	# 第四行：预览工具栏（自由镜头、平移、缩放、F3 辅助线、F4 干净截图、F5 缩略图）+ 反馈 Toast
	var row_tools := HBoxContainer.new()
	row_tools.add_theme_constant_override("separation", 4)
	vbox.add_child(row_tools)

	_btn_cam_mode = _make_compact_btn("[F2] 镜头:跟随角色", false)
	_btn_cam_mode.pressed.connect(func() -> void: set_free_camera(not free_camera_mode))
	row_tools.add_child(_btn_cam_mode)

	var btn_pan_l := _make_compact_btn("◀左移", false)
	btn_pan_l.pressed.connect(func() -> void: pan_camera_by(Vector2(-480.0, 0.0)))
	row_tools.add_child(btn_pan_l)

	var btn_pan_r := _make_compact_btn("右移▶", false)
	btn_pan_r.pressed.connect(func() -> void: pan_camera_by(Vector2(480.0, 0.0)))
	row_tools.add_child(btn_pan_r)

	var btn_pan_u := _make_compact_btn("▲上层", false)
	btn_pan_u.pressed.connect(func() -> void: pan_camera_by(Vector2(0.0, -180.0)))
	row_tools.add_child(btn_pan_u)

	var btn_pan_d := _make_compact_btn("▼下层", false)
	btn_pan_d.pressed.connect(func() -> void: pan_camera_by(Vector2(0.0, 180.0)))
	row_tools.add_child(btn_pan_d)

	_btn_zoom = _make_compact_btn("视野:1.0x", false)
	_btn_zoom.pressed.connect(_toggle_camera_zoom)
	row_tools.add_child(_btn_zoom)

	_btn_debug = _make_compact_btn("[F3] 比例/边界线:关", debug_guides_visible)
	_btn_debug.pressed.connect(func() -> void: set_debug_guides_visible(not debug_guides_visible))
	row_tools.add_child(_btn_debug)

	var btn_clean := _make_compact_btn("[F4] 干净截图模式", false)
	btn_clean.pressed.connect(func() -> void: set_clean_mode(not clean_screenshot_mode))
	row_tools.add_child(btn_clean)

	_btn_minimap = _make_compact_btn("[F5] 缩略条:开", minimap_visible)
	_btn_minimap.pressed.connect(func() -> void: set_minimap_visible(not minimap_visible))
	row_tools.add_child(_btn_minimap)

	_toast_label = Label.new()
	_toast_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toast_label.add_theme_font_size_override("font_size", 11)
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	row_tools.add_child(_toast_label)

	# 底部全图缩略总览条
	_minimap = WhiteboxMinimapStrip.new()
	_minimap.name = "MinimapStrip"
	_minimap.position = Vector2(8.0, 480.0)
	_minimap.size = Vector2(944.0, 54.0)
	_minimap.setup(spec, _player, _camera)
	_minimap.jump_requested.connect(jump_to_position)
	_ui_layer.add_child(_minimap)

	_refresh_hud_labels()


func _make_compact_btn(txt: String, active: bool) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 10)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.24, 0.46, 0.68, 0.95) if active else Color(0.14, 0.18, 0.24, 0.92)
	st.border_color = Color(0.65, 0.85, 1.0, 0.95) if active else Color(0.32, 0.42, 0.54, 0.75)
	st.set_border_width_all(1)
	st.set_corner_radius_all(3)
	st.content_margin_left = 4.0
	st.content_margin_right = 4.0
	st.content_margin_top = 1.0
	st.content_margin_bottom = 1.0
	btn.add_theme_stylebox_override("normal", st)
	return btn


func _make_world_label(txt: String, pos: Vector2, fsize: int, col: Color) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", fsize)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


# ==============================================================================
# 9. 交互控制与开发预览 API
# ==============================================================================
func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0 and _toast_label != null:
			_toast_label.text = ""

	# 自由镜头模式下支持 J/L/I/K 或方向键平滑平移镜头
	if free_camera_mode and _camera != null:
		var pan_dir := Vector2.ZERO
		if Input.is_key_pressed(KEY_J):
			pan_dir.x -= 1.0
		if Input.is_key_pressed(KEY_L):
			pan_dir.x += 1.0
		if Input.is_key_pressed(KEY_I):
			pan_dir.y -= 1.0
		if Input.is_key_pressed(KEY_K):
			pan_dir.y += 1.0
		if pan_dir != Vector2.ZERO:
			pan_camera_by(pan_dir * 640.0 * delta)

	_refresh_hud_labels()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var ke := event as InputEventKey
		match ke.keycode:
			KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				SceneRouter.goto_main_menu()
			KEY_F2:
				get_viewport().set_input_as_handled()
				set_free_camera(not free_camera_mode)
			KEY_F3:
				get_viewport().set_input_as_handled()
				set_debug_guides_visible(not debug_guides_visible)
			KEY_F4:
				get_viewport().set_input_as_handled()
				set_clean_mode(not clean_screenshot_mode)
			KEY_F5:
				get_viewport().set_input_as_handled()
				set_minimap_visible(not minimap_visible)


func jump_to_position(world_x: float, floor_num: int = 1) -> void:
	var width: float = float(spec.get("width", 1920.0))
	var clamped_x := clampf(world_x, 64.0, width - 64.0)
	current_floor = floor_num
	var target_y := Season1Layout.GROUND_Y if floor_num == 1 else Season1Layout.FLOOR2_Y
	if _player != null:
		for cart in _carts:
			if cart.state == PushableCart.STATE_PUSHING:
				cart.unbind()
		_player.ground_y = target_y
		_player.teleport_to(clamped_x)
	if _camera != null:
		if free_camera_mode:
			_camera.global_position = Vector2(clamped_x, target_y - 146.0)
		else:
			_camera.snap_to_target()
	_refresh_hud_labels()


func set_free_camera(enabled: bool) -> void:
	free_camera_mode = enabled
	if _camera != null:
		var width: float = float(spec.get("width", 1920.0))
		_camera.follow_enabled = not enabled
		if enabled:
			_camera.limit_left = -960
			_camera.limit_right = int(width) + 960
			_camera.limit_top = -640
			_camera.limit_bottom = 960
		else:
			_camera.limit_left = 0
			_camera.limit_right = int(maxf(width, 960.0))
			_camera.limit_top = -220
			_camera.limit_bottom = 540
			_camera.snap_to_target()
	if _btn_cam_mode != null:
		_btn_cam_mode.text = "[F2] 镜头:自由平移(J/L/I/K)" if enabled else "[F2] 镜头:跟随角色"
	_refresh_hud_labels()


func pan_camera_by(delta_pos: Vector2) -> void:
	if not free_camera_mode:
		set_free_camera(true)
	if _camera != null:
		var width: float = float(spec.get("width", 1920.0))
		_camera.global_position.x = clampf(_camera.global_position.x + delta_pos.x, 240.0, maxf(width - 240.0, 480.0))
		_camera.global_position.y = clampf(_camera.global_position.y + delta_pos.y, -80.0, 340.0)


func set_camera_zoom_Factor(z: float) -> void:
	if _camera != null:
		_camera.zoom = Vector2(z, z)
	if _btn_zoom != null:
		_btn_zoom.text = "视野:%.1fx" % z


func _toggle_camera_zoom() -> void:
	if _camera == null:
		return
	var next_z := 0.5 if is_equal_approx(_camera.zoom.x, 1.0) else 1.0
	set_camera_zoom_Factor(next_z)


func set_debug_guides_visible(vis: bool) -> void:
	debug_guides_visible = vis
	if _debug_overlay != null:
		_debug_overlay.visible = vis
		_debug_overlay.queue_redraw()
	if _btn_debug != null:
		_btn_debug.text = "[F3] 比例/边界线:开" if vis else "[F3] 比例/边界线:关"


func set_clean_mode(clean: bool) -> void:
	clean_screenshot_mode = clean
	if _ui_layer != null:
		_ui_layer.visible = not clean
	if _sensor != null:
		_sensor.visible = not clean


func set_minimap_visible(vis: bool) -> void:
	minimap_visible = vis
	if _minimap != null:
		_minimap.visible = vis
	if _btn_minimap != null:
		_btn_minimap.text = "[F5] 缩略条:开" if vis else "[F5] 缩略条:关"


func _show_toast(msg: String) -> void:
	if _toast_label != null:
		_toast_label.text = msg
	_toast_timer = 4.0


func _refresh_hud_labels() -> void:
	if _header_label == null:
		return
	var doc_code: String = String(spec.get("doc_code", ""))
	var width: float = float(spec.get("width", 1920.0))
	_header_label.text = "【%s】%s (全长 %.0fpx)" % [doc_code, String(spec.get("title", "")), width]

	if _player != null and _camera != null:
		var px := _player.global_position.x
		var py := _player.global_position.y
		var seg_name := _find_segment_name(px)
		_status_label.text = "%dF | %s | 角色:(%.0f, %.0f) | 相机:(%.0f, %.0f)" % [
			current_floor,
			seg_name,
			px,
			py,
			_camera.global_position.x,
			_camera.global_position.y,
		]

	if _sensor != null and _sensor.current != null:
		_prompt_label.text = "▶ [" + _sensor.current.prompt_text() + "]"
	else:
		_prompt_label.text = "A/D 左右移动 | E 进门/上下楼/查看/推车 | F2~F5 预览工具"


func _find_segment_name(x: float) -> String:
	var segments: Array = spec.get("segments", [])
	for seg in segments:
		if x >= float(seg.get("x0", 0.0)) and x <= float(seg.get("x1", 0.0)):
			return String(seg.get("title", ""))
	return "主区域"


func get_player() -> PlayerController:
	return _player


func get_camera() -> FollowCamera:
	return _camera


func get_sensor() -> InteractionSensor:
	return _sensor


func get_carts() -> Array[PushableCart]:
	return _carts


# ==============================================================================
# 10. CLI 自动化巡检与截图入口（挂载 Scene002Runner 到 root 跨场景执行）
# ==============================================================================
func _check_cli_automation() -> void:
	if get_tree().root.has_node("Scene002Runner"):
		return
	var args := {}
	if SceneRouter and SceneRouter.dev_args is Dictionary:
		for k in SceneRouter.dev_args:
			args[k] = SceneRouter.dev_args[k]
	for raw in OS.get_cmdline_user_args():
		var a: String = raw
		if not a.begins_with("--"):
			continue
		var kv := a.substr(2).split("=", true, 1)
		args[kv[0].replace("-", "_")] = kv[1] if kv.size() > 1 else true

	if args.has("scene002_tour") or args.has("scene002_test"):
		var runner_script := load("res://scripts/dev/scene002_runner.gd")
		if runner_script != null:
			var runner: Node = runner_script.new()
			runner.name = "Scene002Runner"
			get_tree().root.add_child.call_deferred(runner)
			runner.call_deferred("start", args)
