class_name WhiteboxDebugOverlay
extends Node2D
## TASK-SCENE-002 · 场景白盒比例与空间结构辅助线（F3 切换）
##
## 绘制内容（世界坐标系）：
##   1) 32×32 世界格网与 320px (10 tile) 坐标标尺
##   2) 室外三段分界线 / 室内功能区段分界线
##   3) 1F (y=416) 与 2F (y=128) 地面基线、楼板厚度 (32px) 与层高标尺
##   4) 建筑/房间边界框、尺寸标注 (W×H) 与美术替换槽位名 (art_slot)
##   5) 门外框 (96×192 / 192×224) 与净门洞 (80×184 / 184×216) 对比框及跳转目标
##   6) 楼梯上下层垂直对齐连接线 (1F ↔ 2F, ΔY=288px)
##   7) 货架 (96×192) 与相邻主通道净宽标尺
##   8) 跟随玩家位置的 160px 角色可见高度标尺与 28×160 碰撞盒对照框

var spec: Dictionary = {}
var player_ref: Node2D = null
var show_grid: bool = true


func setup(scene_spec: Dictionary, p_player: Node2D) -> void:
	spec = scene_spec
	player_ref = p_player
	z_index = 60
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if spec.is_empty():
		return
	var font := ThemeDB.fallback_font
	var width: float = float(spec.get("width", 1920.0))
	var ground_y: float = float(spec.get("ground_y", Season1Layout.GROUND_Y))

	# 1. 32×32 格网线（为兼顾 15,360px 性能，32px 细线按相机附近绘制，320px 主刻度全图绘制）
	var cam := get_viewport().get_camera_2d()
	var view_x0 := 0.0
	var view_x1 := width
	if cam != null:
		var inv_zoom := 1.0 / maxf(cam.zoom.x, 0.05)
		var half_w := 600.0 * inv_zoom
		view_x0 = maxf(0.0, floorf((cam.global_position.x - half_w) / 32.0) * 32.0)
		view_x1 = minf(width, ceilf((cam.global_position.x + half_w) / 32.0) * 32.0)

	if show_grid:
		var gx := view_x0
		while gx <= view_x1:
			var is_major := is_zero_approx(fmod(gx, 320.0))
			var col := Color(0.55, 0.78, 0.95, 0.22 if is_major else 0.08)
			draw_line(Vector2(gx, -192.0), Vector2(gx, 540.0), col, 1.0)
			gx += 32.0

		for gy_i in range(-6, 18):
			var gy := float(gy_i * 32)
			var is_major_y := (gy_i % 4 == 0)
			var col_y := Color(0.55, 0.78, 0.95, 0.20 if is_major_y else 0.07)
			draw_line(Vector2(view_x0, gy), Vector2(view_x1, gy), col_y, 1.0)

	# 320px 全图 X 标尺刻度
	var mx := 0.0
	while mx <= width:
		draw_line(Vector2(mx, ground_y), Vector2(mx, ground_y + 18.0), Color(0.65, 0.86, 1.0, 0.75), 2.0)
		if font:
			var tile_idx := int(round(mx / 32.0))
			draw_string(
				font,
				Vector2(mx + 4.0, ground_y + 30.0),
				"x=%d (%dt)" % [int(mx), tile_idx],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				11,
				Color(0.75, 0.90, 1.0, 0.90)
			)
		mx += 320.0

	# 2. 区段分界线
	var segments: Array = spec.get("segments", [])
	for seg in segments:
		var sx0: float = float(seg.get("x0", 0.0))
		var sx1: float = float(seg.get("x1", 0.0))
		var stitle: String = String(seg.get("title", ""))
		draw_line(Vector2(sx0, -180.0), Vector2(sx0, 520.0), Color(1.0, 0.78, 0.28, 0.65), 2.0)
		draw_line(Vector2(sx1, -180.0), Vector2(sx1, 520.0), Color(1.0, 0.78, 0.28, 0.65), 2.0)
		if font:
			draw_string(
				font,
				Vector2(sx0 + 12.0, -148.0),
				"【%s】 %.0f..%.0f px (%.0f px)" % [stitle, sx0, sx1, sx1 - sx0],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				13,
				Color(1.0, 0.86, 0.42, 0.95)
			)

	# 3. 楼层地面基线与净高线
	var floors: Array = spec.get("floors", [])
	for fl in floors:
		var fl_num: int = int(fl.get("floor", 1))
		var fg_y: float = float(fl.get("ground_y", ground_y))
		var fc_y: float = float(fl.get("ceiling_y", fg_y - 256.0))
		var fx0: float = float(fl.get("x0", 0.0))
		var fx1: float = float(fl.get("x1", width))
		var fname: String = String(fl.get("name", ""))
		var line_col := Color(0.25, 0.95, 0.55, 0.92) if fl_num == 1 else Color(0.35, 0.85, 1.0, 0.92)
		draw_line(Vector2(fx0, fg_y), Vector2(fx1, fg_y), line_col, 2.5)
		draw_line(Vector2(fx0, fc_y), Vector2(fx1, fc_y), Color(line_col.r, line_col.g, line_col.b, 0.40), 1.5)
		if font:
			draw_string(
				font,
				Vector2(fx0 + 8.0, fg_y - 6.0),
				"%s · 地面 y=%.0f (%dt) | 净高 %.0fpx" % [fname, fg_y, int(fg_y / 32.0), fg_y - fc_y],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				12,
				line_col
			)

	# 4. 建筑与房间外框、尺寸及 art_slot
	var buildings: Array = spec.get("buildings", [])
	for b in buildings:
		var bx: float = float(b.get("x", 0.0))
		var bw: float = float(b.get("w", 320.0))
		var bh: float = float(b.get("h", 256.0))
		var bfloor: int = int(b.get("floor", 1))
		var base_y := Season1Layout.GROUND_Y if bfloor == 1 else Season1Layout.FLOOR2_Y
		var rect := Rect2(Vector2(bx, base_y - bh), Vector2(bw, bh))
		draw_rect(rect, Color(1.0, 0.82, 0.30, 0.85), false, 2.0)
		if font:
			var btitle: String = String(b.get("title", ""))
			var bslot: String = String(b.get("art_slot", ""))
			draw_string(
				font,
				Vector2(bx + 6.0, base_y - bh - 22.0),
				"%s | %.0f×%.0f px (%d×%d tile)" % [btitle, bw, bh, int(bw / 32.0), int(bh / 32.0)],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				12,
				Color(1.0, 0.90, 0.45, 0.98)
			)
			draw_string(
				font,
				Vector2(bx + 6.0, base_y - bh - 6.0),
				"art_slot: %s | x=%.0f..%.0f" % [bslot, bx, bx + bw],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				11,
				Color(0.72, 0.92, 1.0, 0.92)
			)

	# 5. 门洞外框 + 净通行洞口 (SCALE-001 §4.1/4.2) + 跳转关系
	var doors: Array = spec.get("doors", [])
	for d in doors:
		var dx: float = float(d.get("x", 0.0))
		var dw: float = float(d.get("w", 96.0))
		var dh: float = float(d.get("h", 192.0))
		var dfloor: int = int(d.get("floor", 1))
		var base_y := Season1Layout.GROUND_Y if dfloor == 1 else Season1Layout.FLOOR2_Y
		var is_inter: bool = bool(d.get("interactive", true))
		var outer_rect := Rect2(Vector2(dx - dw * 0.5, base_y - dh), Vector2(dw, dh))
		var frame_inset := 8.0 if dw <= 96.0 else 4.0
		var top_inset := 8.0
		var net_w := dw - frame_inset * 2.0
		var net_h := dh - top_inset
		var net_rect := Rect2(Vector2(dx - net_w * 0.5, base_y - net_h), Vector2(net_w, net_h))

		var dcol := Color(0.25, 1.0, 0.55, 0.95) if is_inter else Color(0.75, 0.75, 0.78, 0.75)
		draw_rect(outer_rect, dcol, false, 2.0)
		draw_rect(net_rect, Color(1.0, 1.0, 1.0, 0.65), false, 1.0)
		if font:
			var dlabel: String = String(d.get("label", ""))
			var tscene := String(d.get("target_scene", &""))
			var tspawn := String(d.get("target_spawn", &""))
			draw_string(
				font,
				Vector2(dx - dw * 0.5, base_y - dh - 44.0),
				"%s [外%.0f×%.0f / 净%.0f×%.0f]" % [dlabel, dw, dh, net_w, net_h],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				11,
				dcol
			)
			if is_inter and tscene != "":
				draw_string(
					font,
					Vector2(dx - dw * 0.5, base_y - dh - 30.0),
					"→ %s @ %s (x=%.0f)" % [tscene, tspawn, dx],
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					11,
					Color(0.65, 1.0, 0.80, 0.95)
				)

	# 6. 楼梯垂直对齐关系
	var stairs: Array = spec.get("stairs", [])
	for st in stairs:
		if int(st.get("from_floor", 1)) != 1:
			continue
		var sx: float = float(st.get("x", 0.0))
		var sw: float = float(st.get("w", 128.0))
		var y1: float = float(st.get("from_y", Season1Layout.GROUND_Y))
		var y2: float = float(st.get("to_y", Season1Layout.FLOOR2_Y))
		var srect := Rect2(Vector2(sx - sw * 0.5, y2 - 160.0), Vector2(sw, (y1 - y2) + 160.0))
		draw_rect(srect, Color(0.45, 0.85, 1.0, 0.45), false, 1.5)
		draw_line(Vector2(sx, y1), Vector2(sx, y2), Color(0.45, 0.90, 1.0, 0.95), 2.5)
		if font:
			draw_string(
				font,
				Vector2(sx - sw * 0.5 + 4.0, (y1 + y2) * 0.5),
				"楼梯连通 1F(416)↔2F(128) ΔY=288px",
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				11,
				Color(0.55, 0.92, 1.0, 0.98)
			)

	# 7. 货架尺寸框与相邻主通道净宽标尺
	var shelves: Array = spec.get("shelves", [])
	for i in range(shelves.size()):
		var sh: Dictionary = shelves[i]
		var shx: float = float(sh.get("x", 0.0))
		var shf: int = int(sh.get("floor", 1))
		var by := Season1Layout.GROUND_Y if shf == 1 else Season1Layout.FLOOR2_Y
		var sh_rect := Rect2(Vector2(shx - 48.0, by - 192.0), Vector2(96.0, 192.0))
		draw_rect(sh_rect, Color(0.95, 0.55, 0.95, 0.85), false, 1.5)
		if font:
			draw_string(
				font,
				Vector2(shx - 46.0, by - 222.0),
				"货架 96×192 (ART_FURN_101)",
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				10,
				Color(0.98, 0.70, 0.98, 0.95)
			)
		if i + 1 < shelves.size():
			var next_sh: Dictionary = shelves[i + 1]
			if int(next_sh.get("floor", 1)) == shf:
				var nx: float = float(next_sh.get("x", 0.0))
				var right_edge := shx + 48.0
				var left_edge := nx - 48.0
				var gap := left_edge - right_edge
				if gap >= 64.0 and gap <= 384.0:
					var gy := by - 96.0
					draw_line(Vector2(right_edge, gy), Vector2(left_edge, gy), Color(1.0, 0.92, 0.35, 0.90), 2.0)
					if font:
						draw_string(
							font,
							Vector2((right_edge + left_edge) * 0.5 - 38.0, gy - 6.0),
							"通道净宽 %.0fpx" % gap,
							HORIZONTAL_ALIGNMENT_LEFT,
							-1,
							11,
							Color(1.0, 0.95, 0.45, 0.98)
						)

	# 8. 角色实时比例尺 (160px 可见高 / 28×160 碰撞盒 / 门与货架对照刻度)
	if player_ref != null and is_instance_valid(player_ref):
		var ppos := player_ref.global_position
		var vis_rect := Rect2(Vector2(ppos.x - 32.0, ppos.y - 160.0), Vector2(64.0, 160.0))
		var col_rect := Rect2(Vector2(ppos.x - 14.0, ppos.y - 160.0), Vector2(28.0, 160.0))
		draw_rect(vis_rect, Color(0.30, 0.95, 1.0, 0.75), false, 1.5)
		draw_rect(col_rect, Color(1.0, 0.45, 0.35, 0.85), false, 1.5)

		var rx := ppos.x + 42.0
		draw_line(Vector2(rx, ppos.y), Vector2(rx, ppos.y - 256.0), Color(0.95, 0.95, 0.98, 0.90), 2.0)
		var ticks := [
			{"h": 96.0, "txt": "96px (推车/桌柜 3t)", "col": Color(0.85, 0.88, 0.95, 0.90)},
			{"h": 160.0, "txt": "160px (角色可见高 5t)", "col": Color(0.35, 0.98, 1.0, 1.0)},
			{"h": 192.0, "txt": "192px (标准门/货架 6t)", "col": Color(0.45, 1.0, 0.60, 0.95)},
			{"h": 224.0, "txt": "224px (超市大门 7t)", "col": Color(1.0, 0.86, 0.42, 0.95)},
			{"h": 256.0, "txt": "256px (1F标准净高 8t)", "col": Color(0.95, 0.65, 0.95, 0.90)},
		]
		for tk in ticks:
			var th: float = float(tk["h"])
			var ty := ppos.y - th
			var tcol: Color = tk["col"]
			draw_line(Vector2(rx - 6.0, ty), Vector2(rx + 6.0, ty), tcol, 2.0)
			if font:
				draw_string(font, Vector2(rx + 10.0, ty + 4.0), String(tk["txt"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, tcol)
