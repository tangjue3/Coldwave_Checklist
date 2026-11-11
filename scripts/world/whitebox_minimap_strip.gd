class_name WhiteboxMinimapStrip
extends Control
## TASK-SCENE-002 · 全图缩略总览条（F5 切换，支持点击快速跳转）
##
## 显示整张室外长街 (15,360 px) 或当前室内场景的全宽缩略结构：
##   - 分段底色与分段名
##   - 全部建筑/房间轮廓（含 1F/2F 双层高度关系）
##   - 全部可交互门洞（绿点）与楼梯（蓝线）
##   - 当前 Camera2D 视野框（亮黄框）与角色位置（亮青色竖标）
##   - 鼠标左键点击缩略图任意位置即可跳转至对应世界 X 坐标

signal jump_requested(world_x: float, floor_num: int)

var spec: Dictionary = {}
var player_ref: Node2D = null
var camera_ref: Camera2D = null


func setup(scene_spec: Dictionary, p_player: Node2D, p_camera: Camera2D) -> void:
	spec = scene_spec
	player_ref = p_player
	camera_ref = p_camera
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		var map_w: float = maxf(float(spec.get("width", 1920.0)), 1.0)
		var pad_x := 12.0
		var usable_w := maxf(size.x - pad_x * 2.0, 1.0)
		var ratio := clampf((mb.position.x - pad_x) / usable_w, 0.0, 1.0)
		var target_x := ratio * map_w
		var floors: Array = spec.get("floors", [])
		var target_floor := 1
		if floors.size() > 1 and mb.position.y < size.y * 0.48:
			target_floor = 2
		jump_requested.emit(target_x, target_floor)
		accept_event()


func _draw() -> void:
	if spec.is_empty():
		return
	var font := ThemeDB.fallback_font
	var map_w: float = maxf(float(spec.get("width", 1920.0)), 1.0)
	var pad_x := 12.0
	var usable_w := maxf(size.x - pad_x * 2.0, 1.0)
	var scale_x := usable_w / map_w
	var base_y := size.y - 14.0
	var scale_y := 0.068

	# 背景面板
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.09, 0.12, 0.90), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.42, 0.56, 0.70, 0.70), false, 1.0)

	# 分段色块
	var segments: Array = spec.get("segments", [])
	for seg in segments:
		var sx0 := pad_x + float(seg.get("x0", 0.0)) * scale_x
		var sx1 := pad_x + float(seg.get("x1", 0.0)) * scale_x
		var scol: Color = seg.get("color", Color(0.2, 0.25, 0.3, 1.0))
		draw_rect(Rect2(Vector2(sx0, 16.0), Vector2(maxf(sx1 - sx0, 1.0), base_y - 16.0)), Color(scol.r, scol.g, scol.b, 0.38), true)
		draw_line(Vector2(sx0, 14.0), Vector2(sx0, base_y), Color(0.95, 0.78, 0.35, 0.55), 1.0)
		if font:
			draw_string(
				font,
				Vector2(sx0 + 4.0, 12.0),
				"%s (%.0f..%.0f)" % [String(seg.get("title", "")), float(seg.get("x0", 0.0)), float(seg.get("x1", 0.0))],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				10,
				Color(0.92, 0.86, 0.68, 0.95)
			)

	# 地面线 (1F & 2F)
	draw_line(Vector2(pad_x, base_y), Vector2(pad_x + usable_w, base_y), Color(0.35, 0.90, 0.55, 0.80), 1.5)
	var floors: Array = spec.get("floors", [])
	if floors.size() > 1:
		var y2 := base_y - (Season1Layout.GROUND_Y - Season1Layout.FLOOR2_Y) * scale_y
		draw_line(Vector2(pad_x, y2), Vector2(pad_x + usable_w, y2), Color(0.40, 0.82, 1.0, 0.75), 1.2)

	# 建筑缩略块
	var buildings: Array = spec.get("buildings", [])
	for b in buildings:
		var bx := pad_x + float(b.get("x", 0.0)) * scale_x
		var bw := maxf(float(b.get("w", 320.0)) * scale_x, 3.0)
		var bh := maxf(float(b.get("h", 256.0)) * scale_y, 6.0)
		var bfloor: int = int(b.get("floor", 1))
		var by_ground := base_y if bfloor == 1 else (base_y - (Season1Layout.GROUND_Y - Season1Layout.FLOOR2_Y) * scale_y)
		var bcol: Color = b.get("wall_color", Color(0.4, 0.4, 0.45, 1.0))
		var brect := Rect2(Vector2(bx, by_ground - bh), Vector2(bw, bh))
		draw_rect(brect, Color(bcol.r + 0.12, bcol.g + 0.12, bcol.b + 0.12, 0.88), true)
		draw_rect(brect, Color(0.88, 0.84, 0.72, 0.70), false, 1.0)
		if font and bw >= 26.0:
			var code_str: String = String(b.get("doc_code", ""))
			draw_string(font, Vector2(bx + 2.0, by_ground - bh + 9.0), code_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.94, 0.72, 0.95))

	# 门标记
	var doors: Array = spec.get("doors", [])
	for d in doors:
		if not bool(d.get("interactive", true)):
			continue
		var dx := pad_x + float(d.get("x", 0.0)) * scale_x
		var dfloor: int = int(d.get("floor", 1))
		var dy := base_y if dfloor == 1 else (base_y - (Season1Layout.GROUND_Y - Season1Layout.FLOOR2_Y) * scale_y)
		draw_rect(Rect2(Vector2(dx - 2.0, dy - 8.0), Vector2(4.0, 8.0)), Color(0.25, 1.0, 0.55, 0.95), true)

	# 相机视口范围框
	if camera_ref != null and is_instance_valid(camera_ref):
		var inv_z := 1.0 / maxf(camera_ref.zoom.x, 0.05)
		var vw := 960.0 * inv_z * scale_x
		var cx := pad_x + camera_ref.global_position.x * scale_x
		var vrect := Rect2(Vector2(clampf(cx - vw * 0.5, pad_x, pad_x + usable_w - 4.0), 15.0), Vector2(clampf(vw, 4.0, usable_w), base_y - 14.0))
		draw_rect(vrect, Color(1.0, 0.88, 0.25, 0.90), false, 1.5)

	# 角色当前位置
	if player_ref != null and is_instance_valid(player_ref):
		var px := pad_x + player_ref.global_position.x * scale_x
		draw_line(Vector2(px, 14.0), Vector2(px, base_y + 2.0), Color(0.25, 0.95, 1.0, 1.0), 2.0)
		draw_circle(Vector2(px, base_y - 4.0), 3.5, Color(0.25, 0.95, 1.0, 1.0))

	if font:
		draw_string(
			font,
			Vector2(pad_x, size.y - 3.0),
			"全图缩略总览 (0 .. %.0f px, %d tiles) — 点击任意位置快速跳转 [F5 隐藏]" % [map_w, int(map_w / 32.0)],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			9,
			Color(0.70, 0.82, 0.94, 0.90)
		)
