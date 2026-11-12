extends Node2D
## RD1 · 第一季完整地图（一张文件）运行时逻辑（不含玩法）
##
## 只负责：角色落点、镜头、自由浏览、标尺。
## 不改 PlayerController / 动画 / 碰撞 / 移动速度 / 购物车；不写任何玩法数值。
## 可见几何由 tools/rd1_builder.gd 生成成静态 .tscn 节点。

@export var location_key: StringName = &"season1_map"
@export var location_display_name: String = ""
@export var world_width: float = 16380.0
@export var spawn_x: float = 1480.0
@export var spawn_y: float = 0.0
@export var is_exterior: bool = true

var _player: Node2D
var _camera: Camera2D
var _ui: CanvasLayer
var _hud: Control
var _guides: Node2D
var _free_cam := false
var _clean_on := false
var _dragging := false
var _zoom := 0.7


func _ready() -> void:
	_player = get_node_or_null("Actors/Player") as Node2D
	_camera = get_node_or_null("Camera2D") as Camera2D
	_ui = get_node_or_null("UI") as CanvasLayer
	_guides = get_node_or_null("DebugGuides") as Node2D
	_apply_spawn()
	_setup_camera()
	_build_ui()
	print("[RD1] ready key=%s width=%.0f player_x=%.0f" % [
		location_key, world_width, _player.global_position.x if _player else -1.0])


func _apply_spawn() -> void:
	if _player == null:
		return
	# 从室内返回：按 pending_spawn_id 落到对应那扇门口
	var back: StringName = SceneRouter.pending_spawn_id
	if back == &"door_A":
		spawn_x = 2050.0
	elif back == &"door_C":
		spawn_x = 1173.0
	SceneRouter.pending_spawn_id = &""
	_player.set("ground_y", spawn_y)
	_player.call("teleport_to", spawn_x)


func _setup_camera() -> void:
	if _camera == null:
		return
	if _player != null:
		_camera.set("_target", _player)
	_camera.set("follow_enabled", true)
	_camera.set("look_offset", Vector2(0, -210))
	_camera.set("dead_zone", Vector2(56, 48))
	_camera.limit_left = -480
	_camera.limit_right = int(world_width) + 480
	_camera.limit_top = -1340
	_camera.limit_bottom = 340
	_camera.zoom = Vector2(_zoom, _zoom)
	_camera.call("make_current")
	_camera.call("snap_to_target")


# ---------------------------------------------------------------- 预览 UI
func _build_ui() -> void:
	if _ui == null:
		return
	_hud = Control.new()
	_hud.name = "PreviewHUD"
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_hud)

	var bar := PanelContainer.new()
	bar.name = "TopBar"
	bar.position = Vector2(8, 6)
	bar.size = Vector2(944, 62)
	_hud.add_child(bar)
	var row := HBoxContainer.new()
	bar.add_child(row)
	var l1 := Label.new()
	l1.text = "镜头："
	l1.add_theme_font_size_override("font_size", 13)
	l1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l1)
	_add_button(row, "跟随 [1]", 88, func() -> void: _set_free_cam(false))
	_add_button(row, "自由 [F2]", 92, func() -> void: _set_free_cam(true))
	_add_button(row, "全景 [2]", 88, func() -> void: _view_overview(0.30))
	_add_button(row, "整街 [3]", 88, func() -> void: _view_whole_street())
	_add_button(row, "标尺 [F3]", 88, func() -> void: _toggle_guides())
	_add_button(row, "干净 [F4]", 88, func() -> void: _toggle_clean())
	_add_button(row, "名字 [4]", 88, func() -> void: _toggle_labels())

	var tip := Label.new()
	tip.name = "Tip"
	tip.position = Vector2(12, 510)
	tip.size = Vector2(936, 24)
	tip.add_theme_font_size_override("font_size", 12)
	tip.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	tip.text = "A / D 沿街行走 · F2 自由镜头（J/L/I/K、滚轮、中键拖拽）· [4] 显示/隐藏建筑名 · F4 隐藏文字标注"
	_hud.add_child(tip)
	if _guides != null:
		_guides.visible = false


func _add_button(parent: Control, txt: String, w: float, cb: Callable) -> void:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(w, 24)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)


func _set_free_cam(on: bool) -> void:
	_free_cam = on
	if _camera != null:
		_camera.set("follow_enabled", not on)
		if not on:
			# 回到跟随模式时恢复相机边界，避免看到街道两端外的空白
			_camera.limit_left = -480
			_camera.limit_right = int(world_width) + 480
			_camera.limit_top = -1340
			_camera.limit_bottom = 340


func _view_overview(z: float) -> void:
	_set_free_cam(true)
	if _camera == null:
		return
	_zoom = z
	_camera.zoom = Vector2(_zoom, _zoom)
	_camera.global_position = Vector2(maxf(spawn_x, 2400.0), -356.0)


## 整条街一屏装下：按世界宽度反算 zoom，并临时解除相机边界
func _view_whole_street() -> void:
	_set_free_cam(true)
	if _camera == null:
		return
	var z := clampf(960.0 / maxf(world_width + 240.0, 1.0), 0.02, 0.2)
	_zoom = z
	_camera.limit_left = -1000000
	_camera.limit_right = 1000000
	_camera.limit_top = -1000000
	_camera.limit_bottom = 1000000
	_camera.zoom = Vector2(z, z)
	_camera.global_position = Vector2(world_width * 0.5, -656.0)


func _toggle_guides() -> void:
	if _guides != null:
		_guides.visible = not _guides.visible


func _toggle_labels() -> void:
	var g := get_node_or_null("01_Labels") as Node2D
	if g != null:
		g.visible = not g.visible


func _toggle_clean() -> void:
	_clean_on = not _clean_on
	if _hud != null:
		_hud.visible = not _clean_on
	if _guides != null:
		_guides.visible = false
	for n in get_tree().get_nodes_in_group(&"layout_label"):
		var ci := n as CanvasItem
		if ci != null:
			ci.visible = not _clean_on


func _process(delta: float) -> void:
	if not _free_cam or _camera == null:
		return
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_J) or Input.is_key_pressed(KEY_LEFT):
		d.x -= 1.0
	if Input.is_key_pressed(KEY_L) or Input.is_key_pressed(KEY_RIGHT):
		d.x += 1.0
	if Input.is_key_pressed(KEY_I) or Input.is_key_pressed(KEY_UP):
		d.y -= 1.0
	if Input.is_key_pressed(KEY_K) or Input.is_key_pressed(KEY_DOWN):
		d.y += 1.0
	if d != Vector2.ZERO:
		_camera.global_position += d.normalized() * 460.0 * delta / maxf(_zoom, 0.11)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo and event.pressed:
		match event.keycode:
			KEY_F2:
				_set_free_cam(not _free_cam)
			KEY_F3:
				_toggle_guides()
			KEY_F4:
				_toggle_clean()
			KEY_4:
				_toggle_labels()
			KEY_1:
				_set_free_cam(false)
				_zoom = 0.7
				if _camera != null:
					_camera.zoom = Vector2(_zoom, _zoom)
			KEY_2:
				_view_overview(0.30)
			KEY_3:
				_view_whole_street()
	if event is InputEventMouseButton and _free_cam:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom = minf(_zoom + 0.06, 1.6)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom = maxf(_zoom - 0.06, 0.09)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
		if _camera != null:
			_camera.zoom = Vector2(_zoom, _zoom)
	if event is InputEventMouseMotion and _dragging and _camera != null:
		var mm := event as InputEventMouseMotion
		_camera.global_position -= mm.relative / maxf(_zoom, 0.09)
