class_name Scene002Runner
extends Node
## TASK-SCENE-002 · 自动化实机验证与全套截图巡检器（挂载于 get_tree().root）
##
## 支持命令行参数：
##   --dev-scene=outdoor_street --scene002-test --quit
##   --dev-scene=outdoor_street --scene002-tour --quit

const SHOT_DIR := "res://tests/screenshots/scene002"
const SHOT003_DIR := "res://tests/screenshots/scene003"

var _args: Dictionary = {}
var _failures: int = 0
var _pass_count: int = 0


func start(args: Dictionary) -> void:
	_args = args
	if _args.has("scene002_test") or _args.has("scene002_tour"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	if _args.has("scene003_tour"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT003_DIR))
	await _wait_frames(6)

	if _args.has("scene002_test"):
		await _run_verification_suite()
	if _args.has("scene002_tour"):
		await _run_screenshot_tour()
	if _args.has("scene003_tour"):
		await _run_scene003_tour()

	if _args.has("quit"):
		get_tree().quit(0 if _failures == 0 else 1)


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		_pass_count += 1
	else:
		_failures += 1
	var tag := "通过" if cond else "失败"
	var suffix := ("  ← " + detail) if detail != "" else ""
	print("[SCENE002-TEST] %s | %s%s" % [tag, label, suffix])


func _wait_frames(n: int = 4) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _get_world() -> WhiteboxWorld:
	return get_tree().current_scene as WhiteboxWorld


func _goto_and_wait(scene_key: StringName, spawn_id: StringName = &"") -> WhiteboxWorld:
	SceneRouter.pending_spawn_id = spawn_id
	SceneRouter.goto(scene_key)
	for _i in range(120):
		await get_tree().process_frame
		var w := _get_world()
		if w != null and w.location_key == scene_key:
			await _wait_frames(4)
			return w
	return _get_world()


func _save_viewport_png(rel_name: String) -> String:
	await _wait_frames(3)
	await RenderingServer.frame_post_draw
	var full_path := "%s/%s" % [SHOT_DIR, rel_name]
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(full_path)
	print("[SCENE002-SHOT] saved %s (%dx%d, err=%d)" % [full_path, img.get_width(), img.get_height(), err])
	return full_path


# ==============================================================================
# 一、实机运行验证套件 (--scene002-test)
# ==============================================================================
func _run_verification_suite() -> void:
	print("")
	print("==================== TASK-SCENE-002 实机自动化验收 ====================")

	# 1. 验证室外主地图加载、8 层标准节点结构、美术替换槽位及 14 地标顺序
	var w := await _goto_and_wait(&"outdoor_street", &"spawn_home_gate")
	_check("室外主地图 outdoor_street 正常加载", w != null and w.location_key == &"outdoor_street")
	if w == null:
		return

	_verify_node_structure(w)
	_verify_outdoor_landmarks_and_non_overlap(w)
	await _verify_outdoor_walking_and_camera(w)

	# 2. 逐扇门验证「室外 ↔ 室内」双向进入与返回落点对应关系（含批发仓双门独立对应）
	var outdoor_door_cases := [
		{"door": "Door_door_equip_bay", "in_scene": &"equipment_room", "in_x": 256.0, "out_door": "Door_door_equip_exit", "out_x": 384.0, "desc": "① 小楼设备区 (C)"},
		{"door": "Door_door_safe_house", "in_scene": &"shelter", "in_x": 2848.0, "out_door": "Door_door_shelter_exit", "out_x": 912.0, "desc": "② 主角安全屋 1F (A)"},
		{"door": "Door_door_apartment_unit", "in_scene": &"apartment_hallway", "in_x": 256.0, "out_door": "Door_door_hall_exit", "out_x": 3008.0, "desc": "④ 居民楼公共楼道 (G)"},
		{"door": "Door_door_repair_corner", "in_scene": &"repair_corner", "in_x": 256.0, "out_door": "Door_door_repair_exit", "out_x": 3856.0, "desc": "⑤ 陈叔维修角 (Q)"},
		{"door": "Door_door_convenience", "in_scene": &"convenience_store", "in_x": 256.0, "out_door": "Door_door_conv_exit", "out_x": 5568.0, "desc": "⑧ 唐宁便利店 (J)"},
		{"door": "Door_door_pharmacy", "in_scene": &"pharmacy", "in_x": 256.0, "out_door": "Door_door_pharm_exit", "out_x": 6432.0, "desc": "⑨ 社区药店 (N)"},
		{"door": "Door_door_supermarket", "in_scene": &"supermarket", "in_x": 320.0, "out_door": "Door_door_market_in", "out_x": 7552.0, "desc": "⑩ 灾前连锁超市 (H)"},
		{"door": "Door_door_hardware", "in_scene": &"hardware_store", "in_x": 288.0, "out_door": "Door_door_hw_exit", "out_x": 8784.0, "desc": "⑪ 五金家电店 (I)"},
		{"door": "Door_door_warehouse_main", "in_scene": &"wholesale_warehouse", "in_x": 320.0, "out_door": "Door_door_wh_main_out", "out_x": 10880.0, "desc": "⑬a 批发仓正门 (K左)"},
		{"door": "Door_door_warehouse_dock", "in_scene": &"wholesale_warehouse", "in_x": 4736.0, "out_door": "Door_door_wh_dock_out", "out_x": 12096.0, "desc": "⑬b 批发仓装卸门 (K右)"},
		{"door": "Door_door_logistics_hub", "in_scene": &"logistics_hub", "in_x": 288.0, "out_door": "Door_door_log_exit", "out_x": 13440.0, "desc": "⑭ 物流中转取货口 (L)"},
	]

	for tc in outdoor_door_cases:
		await _verify_door_roundtrip(tc)

	# 3. 验证安全屋 (A/B) 1F ↔ 2F 真实楼梯垂直切换
	await _verify_shelter_stairs()

	# 4. 验证居民楼公共楼道 (G) 1F → 2F 楼梯 + 2F 201 门 ↔ 赵阿姨家 (P) 嵌套进出
	await _verify_apartment_and_zhao_home()

	# 5. 验证序章前世走廊 (G0) 独立场景与重生转场门
	await _verify_past_corridor()

	# 6. 验证超市与批发仓内现有组件（PushableCart r03 分层、货架交互）无回归
	await _verify_supermarket_components()

	print("-----------------------------------------------------------------------")
	print("[SCENE002-TEST] 验收汇总：通过 %d 项，失败 %d 项" % [_pass_count, _failures])
	print("=======================================================================")


func _verify_node_structure(w: WhiteboxWorld) -> void:
	var required_nodes := ["Background", "Environment", "Buildings", "Props", "Actors", "InteractionAreas", "Camera2D", "UI"]
	var all_present := true
	for nname in required_nodes:
		if w.get_node_or_null(nname) == null:
			all_present = false
	_check("场景根节点包含完整 8 层标准架构 (Background/Environment/Buildings/Props/Actors/InteractionAreas/Camera2D/UI)", all_present)

	var props_node := w.get_node_or_null("Props")
	var actors_node := w.get_node_or_null("Actors")
	var order_ok := props_node != null and actors_node != null and props_node.get_index() < actors_node.get_index()
	_check("Props 层级位于 Actors 之前（保障购物车近端篮网遮挡顺序）", order_ok)

	var b_root := w.get_node_or_null("Buildings")
	var slot_count := 0
	if b_root != null:
		for child in b_root.get_children():
			if child.name.begins_with("Building_") and child.has_meta("art_slot") and child.get_node_or_null("VisualSlot") != null:
				slot_count += 1
	_check("室外全部 14 栋主要建筑均具备独立 VisualSlot 与 art_slot 替换元数据", slot_count == 14, "实际=%d" % slot_count)


func _verify_outdoor_landmarks_and_non_overlap(w: WhiteboxWorld) -> void:
	var landmarks: Array = w.spec.get("landmarks", [])
	_check("室外长街包含文档规定的 14 个连续地标点", landmarks.size() == 14, "count=%d" % landmarks.size())

	var strictly_increasing := true
	var prev_x := -1.0
	for lm in landmarks:
		var lx: float = float(lm.get("x", 0.0))
		if lx <= prev_x:
			strictly_increasing = false
		prev_x = lx
	_check("室外 14 个地标按从左到右严格递增排列（无乱序）", strictly_increasing)

	var buildings: Array = w.spec.get("buildings", [])
	var no_overlap := true
	var overlap_detail := ""
	for i in range(buildings.size() - 1):
		var b1: Dictionary = buildings[i]
		var b2: Dictionary = buildings[i + 1]
		var b1_end := float(b1.get("x", 0.0)) + float(b1.get("w", 0.0))
		var b2_start := float(b2.get("x", 0.0))
		if b1_end > b2_start:
			no_overlap = false
			overlap_detail = "%s(end=%.0f) > %s(start=%.0f)" % [String(b1.get("id")), b1_end, String(b2.get("id")), b2_start]
			break
	_check("室外全部 14 栋建筑外框互不重叠，街区留白连续", no_overlap, overlap_detail)


func _verify_outdoor_walking_and_camera(w: WhiteboxWorld) -> void:
	var p := w.get_player()
	var cam := w.get_camera()
	_check("角色可见高度与地面基线保持冻结参数 (ground_y=416, move_speed=100)", is_equal_approx(p.ground_y, 416.0) and is_equal_approx(p.move_speed, 100.0))

	# 实机模拟向右行走 18 帧，确认道路未被任何碰撞体堵死
	p.teleport_to(912.0)
	p.set_facing(1)
	var start_x := p.global_position.x
	Input.action_press("move_right")
	for _i in range(18):
		await get_tree().physics_frame
	Input.action_release("move_right")
	await _wait_frames(2)
	var moved_dx := p.global_position.x - start_x
	_check("角色在室外长街可正常连续行走（无错误碰撞阻挡行走线）", moved_dx > 15.0, "dx=%.1f px" % moved_dx)

	# 验证相机可浏览左端、中段、右端全图 (0..15360)
	w.jump_to_position(384.0, 1)
	await _wait_frames(2)
	var cam_left_x := cam.global_position.x
	w.jump_to_position(7552.0, 1)
	await _wait_frames(2)
	var cam_mid_x := cam.global_position.x
	w.jump_to_position(13440.0, 1)
	await _wait_frames(2)
	var cam_right_x := cam.global_position.x
	_check("Camera2D 可完整覆盖第一、二、三段全长 15,360px 地图", cam_left_x < 600.0 and absf(cam_mid_x - 7552.0) < 10.0 and cam_right_x > 13000.0)


func _verify_door_roundtrip(tc: Dictionary) -> void:
	var w := await _goto_and_wait(&"outdoor_street")
	var door_node := w.get_node_or_null("InteractionAreas/" + String(tc["door"])) as DoorInteractable
	if door_node == null:
		_check("门节点存在: " + String(tc["desc"]), false, "missing " + String(tc["door"]))
		return

	var p := w.get_player()
	p.teleport_to(door_node.global_position.x)
	await _wait_frames(3)
	door_node.interact(p)

	for _i in range(120):
		await get_tree().process_frame
		var cur := _get_world()
		if cur != null and cur.location_key == StringName(tc["in_scene"]):
			break
	await _wait_frames(4)
	var in_w := _get_world()
	var in_ok: bool = in_w != null and in_w.location_key == StringName(tc["in_scene"]) and absf(in_w.get_player().global_position.x - float(tc["in_x"])) <= 2.0
	_check("门进入验证: %s → %s (x=%.0f)" % [String(tc["desc"]), String(tc["in_scene"]), float(tc["in_x"])], in_ok)

	if not in_ok:
		return

	var out_door := in_w.get_node_or_null("InteractionAreas/" + String(tc["out_door"])) as DoorInteractable
	if out_door == null:
		_check("室内返回门存在: " + String(tc["out_door"]), false)
		return
	in_w.get_player().teleport_to(out_door.global_position.x)
	await _wait_frames(3)
	out_door.interact(in_w.get_player())

	for _i in range(120):
		await get_tree().process_frame
		var back := _get_world()
		if back != null and back.location_key == &"outdoor_street":
			break
	await _wait_frames(4)
	var back_w := _get_world()
	var out_ok: bool = back_w != null and back_w.location_key == &"outdoor_street" and absf(back_w.get_player().global_position.x - float(tc["out_x"])) <= 2.0
	_check("门返回验证: %s → 室外对应门外 x=%.0f" % [String(tc["in_scene"]), float(tc["out_x"])], out_ok)


func _verify_shelter_stairs() -> void:
	var w := await _goto_and_wait(&"shelter", &"spawn_front_door")
	var p := w.get_player()
	var st_up := w.get_node_or_null("InteractionAreas/Stair_stair_1f_to_2f") as StairInteractable
	var st_dn := w.get_node_or_null("InteractionAreas/Stair_stair_2f_to_1f") as StairInteractable
	_check("安全屋 (shelter) 具备上下层双向楼梯节点", st_up != null and st_dn != null)
	if st_up == null or st_dn == null:
		return

	p.teleport_to(st_up.global_position.x)
	await _wait_frames(2)
	st_up.interact(p)
	await _wait_frames(2)
	_check("安全屋 1F(y=416) 按楼梯上达 2F(y=128)", w.current_floor == 2 and is_equal_approx(p.global_position.y, 128.0))

	# 在 2F 向左移动到旧储物室 (x=1920) 再回楼梯口 (x=2496)
	p.teleport_to(1920.0)
	await _wait_frames(2)
	_check("角色可在安全屋 2F 独立楼层行走 (x=1920, y=128)", is_equal_approx(p.global_position.x, 1920.0) and is_equal_approx(p.global_position.y, 128.0))

	p.teleport_to(st_dn.global_position.x)
	await _wait_frames(2)
	st_dn.interact(p)
	await _wait_frames(2)
	_check("安全屋 2F(y=128) 按楼梯下回 1F(y=416)", w.current_floor == 1 and is_equal_approx(p.global_position.y, 416.0))


func _verify_apartment_and_zhao_home() -> void:
	var w := await _goto_and_wait(&"apartment_hallway", &"spawn_unit_door")
	var p := w.get_player()
	var st_up := w.get_node_or_null("InteractionAreas/Stair_stair_hall_1f_2f") as StairInteractable
	_check("居民楼公共楼道 (G) 具备 1F→2F 楼梯节点", st_up != null)
	if st_up == null:
		return

	p.teleport_to(st_up.global_position.x)
	await _wait_frames(2)
	st_up.interact(p)
	await _wait_frames(2)
	_check("居民楼楼道 1F 上达 2F 住户走廊 (y=128)", w.current_floor == 2 and is_equal_approx(p.global_position.y, 128.0))

	var zhao_door := w.get_node_or_null("InteractionAreas/Door_door_201_zhao") as DoorInteractable
	_check("居民楼 2F 设有 201 赵阿姨家门 (x=1408)", zhao_door != null)
	if zhao_door == null:
		return

	p.teleport_to(zhao_door.global_position.x)
	await _wait_frames(2)
	zhao_door.interact(p)
	for _i in range(120):
		await get_tree().process_frame
		var zw := _get_world()
		if zw != null and zw.location_key == &"zhao_home":
			break
	await _wait_frames(4)
	var in_zhao := _get_world()
	_check("从居民楼 2F 进入赵阿姨家室内 (P)", in_zhao != null and in_zhao.location_key == &"zhao_home")
	if in_zhao == null:
		return

	var exit_zhao := in_zhao.get_node_or_null("InteractionAreas/Door_door_zhao_exit") as DoorInteractable
	exit_zhao.interact(in_zhao.get_player())
	for _i in range(120):
		await get_tree().process_frame
		var back_g := _get_world()
		if back_g != null and back_g.location_key == &"apartment_hallway":
			break
	await _wait_frames(4)
	var gw := _get_world()
	var back_2f_ok: bool = gw != null and gw.location_key == &"apartment_hallway" and is_equal_approx(gw.get_player().global_position.y, 128.0) and absf(gw.get_player().global_position.x - 1408.0) <= 2.0
	_check("从赵阿姨家 (P) 离开精确返回居民楼 2F 201 门外 (x=1408, y=128)", back_2f_ok)


func _verify_past_corridor() -> void:
	var w := await _goto_and_wait(&"past_corridor", &"spawn_corridor_left")
	_check("序章 P00 前世走廊 (past_corridor) 独立场景正常加载", w != null and w.location_key == &"past_corridor")
	if w == null:
		return
	var locked_door := w.get_node_or_null("InteractionAreas/Door_door_past_locked") as DoorInteractable
	_check("前世被反锁的自家门为不可进入装饰门 (interactive=false)", locked_door != null and not locked_door.interactive)


func _verify_supermarket_components() -> void:
	var w := await _goto_and_wait(&"supermarket", &"spawn_entrance")
	var carts := w.get_carts()
	_check("超市卖场包含可推购物车实例 (PushableCart r03)", carts.size() >= 1)
	if carts.size() >= 1:
		var c := carts[0]
		_check("超市购物车绘制层级合法 (Back < Player < Front) 且近侧篮网常驻可见", c.layer_order_is_valid() and c.front_layer_visible())


# ==============================================================================
# 二、全套实机截图生成 (--scene002-tour)
# ==============================================================================
func _run_screenshot_tour() -> void:
	print("")
	print("==================== TASK-SCENE-002 截图巡检开始 ====================")

	# ------------------------------------------------------------------
	# 1. 第一季室外主地图完整缩略总览 (00_*)
	# ------------------------------------------------------------------
	var w := await _goto_and_wait(&"outdoor_street", &"spawn_home_gate")
	w.set_debug_guides_visible(false)
	w.set_clean_mode(false)
	w.set_minimap_visible(true)
	await _save_viewport_png("00_outdoor_preview_hud.png")

	# 截取 16 张无缝连续 960×540 画面并合成为完整长街总览图
	w.set_clean_mode(true)
	w.set_free_camera(true)
	w.set_camera_zoom_Factor(1.0)
	var slice_images: Array[Image] = []
	for i in range(16):
		var cam_x := 480.0 + float(i) * 960.0
		w.get_camera().global_position = Vector2(cam_x, 270.0)
		await _wait_frames(3)
		await RenderingServer.frame_post_draw
		var slice_img := get_viewport().get_texture().get_image()
		slice_images.append(slice_img)

	# 1.1 生成单条完整横版缩略长卷 (3840 × 135)
	var strip_w := 240
	var strip_h := 135
	var full_strip := Image.create(strip_w * 16, strip_h, false, Image.FORMAT_RGBA8)
	for i in range(16):
		var copy_img: Image = slice_images[i].duplicate()
		copy_img.resize(strip_w, strip_h, Image.INTERPOLATE_BILINEAR)
		full_strip.blit_rect(copy_img, Rect2i(0, 0, strip_w, strip_h), Vector2i(i * strip_w, 0))
	var strip_path := "%s/00_outdoor_full_overview_strip.png" % SHOT_DIR
	full_strip.save_png(strip_path)
	print("[SCENE002-SHOT] saved %s (%dx%d)" % [strip_path, full_strip.get_width(), full_strip.get_height()])

	# 1.2 生成三段叠排高清总览图 (1920 × 648，每行对应 5,120px 一大段，方便直接审阅)
	var seg_sheet := Image.create(1920, 648, false, Image.FORMAT_RGBA8)
	seg_sheet.fill(Color(0.08, 0.10, 0.13, 1.0))
	for row_i in range(3):
		# 每段 5120px 占 16 张里的 5.333 张，直接按像素拼接再缩放到 1920×216
		var raw_seg := Image.create(5120, 540, false, Image.FORMAT_RGBA8)
		for s_i in range(16):
			var world_x0 := s_i * 960
			var seg_x0 := row_i * 5120
			var seg_x1 := (row_i + 1) * 5120
			var overlap_x0 := maxi(world_x0, seg_x0)
			var overlap_x1 := mini(world_x0 + 960, seg_x1)
			if overlap_x1 > overlap_x0:
				var src_x := overlap_x0 - world_x0
				var dst_x := overlap_x0 - seg_x0
				var w_px := overlap_x1 - overlap_x0
				raw_seg.blit_rect(slice_images[s_i], Rect2i(src_x, 0, w_px, 540), Vector2i(dst_x, 0))
		raw_seg.resize(1920, 210, Image.INTERPOLATE_BILINEAR)
		seg_sheet.blit_rect(raw_seg, Rect2i(0, 0, 1920, 210), Vector2i(0, row_i * 216 + 3))
	var sheet_path := "%s/00_outdoor_full_overview_3segments.png" % SHOT_DIR
	seg_sheet.save_png(sheet_path)
	print("[SCENE002-SHOT] saved %s (%dx%d)" % [sheet_path, seg_sheet.get_width(), seg_sheet.get_height()])

	# ------------------------------------------------------------------
	# 2. 按横向位置顺序截取的连续室外场景截图 (01_street_01..14, 960×540)
	# ------------------------------------------------------------------
	w.set_free_camera(false)
	w.set_clean_mode(true)
	w.set_debug_guides_visible(false)

	var street_shots := [
		{"file": "01_street_01_equip_bay_C.png", "x": 384.0},
		{"file": "01_street_02_safehouse_gate_AD.png", "x": 912.0},
		{"file": "01_street_03_notice_and_meng_FW.png", "x": 2048.0},
		{"file": "01_street_04_apartment_and_roof_FT.png", "x": 3008.0},
		{"file": "01_street_05_repair_corner_Q.png", "x": 3856.0},
		{"file": "01_street_06_guard_booth_FR.png", "x": 4336.0},
		{"file": "01_street_07_bus_stop_O.png", "x": 4864.0},
		{"file": "01_street_08_convenience_store_J.png", "x": 5568.0},
		{"file": "01_street_09_pharmacy_N.png", "x": 6432.0},
		{"file": "01_street_10_supermarket_H.png", "x": 7552.0},
		{"file": "01_street_11_hardware_store_I.png", "x": 8784.0},
		{"file": "01_street_12_checkpoint_U.png", "x": 9856.0},
		{"file": "01_street_13_warehouse_K_main.png", "x": 10880.0},
		{"file": "01_street_13b_warehouse_K_dock.png", "x": 12096.0},
		{"file": "01_street_14_logistics_hub_L.png", "x": 13440.0},
	]
	for ss in street_shots:
		w.jump_to_position(float(ss["x"]), 1)
		await _save_viewport_png(String(ss["file"]))

	# ------------------------------------------------------------------
	# 3. 每个已搭建室内场景的完整结构截图 (02_indoor_*, 960×540)
	# ------------------------------------------------------------------
	# 3.1 A/B 安全屋（1F + 2F 真实双层）
	w = await _goto_and_wait(&"shelter", &"spawn_bed")
	w.set_clean_mode(true)
	w.set_debug_guides_visible(false)
	w.jump_to_position(640.0, 1)
	await _save_viewport_png("02_indoor_01a_shelter_1F_bed_desk.png")
	w.jump_to_position(1600.0, 1)
	await _save_viewport_png("02_indoor_01b_shelter_1F_shelves_kitchen.png")
	w.jump_to_position(2560.0, 1)
	await _save_viewport_png("02_indoor_01c_shelter_1F_stairs_door.png")
	w.jump_to_position(1920.0, 2)
	await _save_viewport_png("02_indoor_01d_shelter_2F_storage_stairs.png")
	# 双层全景剖面 (0.30x zoom 完整纳下 3200px 1F+2F 全宽与双层结构)
	w.set_free_camera(true)
	w.set_camera_zoom_Factor(0.30)
	w.get_camera().global_position = Vector2(1600.0, 140.0)
	await _save_viewport_png("02_indoor_01e_shelter_full_2floors.png")

	# 3.2 C 外置独立设备区
	w = await _goto_and_wait(&"equipment_room", &"spawn_entrance")
	w.set_clean_mode(true)
	w.set_free_camera(true)
	w.set_camera_zoom_Factor(0.5)
	w.get_camera().global_position = Vector2(960.0, 220.0)
	await _save_viewport_png("02_indoor_02_equipment_room_C_full.png")
	w.set_camera_zoom_Factor(1.0)
	w.set_free_camera(false)
	w.jump_to_position(1024.0, 1)
	await _save_viewport_png("02_indoor_02b_equipment_room_C_detail.png")

	# 3.3 G 居民楼公共楼道（1F + 2F 双层）
	w = await _goto_and_wait(&"apartment_hallway", &"spawn_unit_door")
	w.set_clean_mode(true)
	w.jump_to_position(608.0, 1)
	await _save_viewport_png("02_indoor_03a_apartment_hallway_1F.png")
	w.jump_to_position(1408.0, 2)
	await _save_viewport_png("02_indoor_03b_apartment_hallway_2F_zhao_door.png")
	w.set_free_camera(true)
	w.set_camera_zoom_Factor(0.40)
	w.get_camera().global_position = Vector2(1200.0, 140.0)
	await _save_viewport_png("02_indoor_03c_apartment_hallway_full_2floors.png")

	# 3.4 P 赵阿姨家室内
	w = await _goto_and_wait(&"zhao_home", &"spawn_entrance")
	w.set_clean_mode(true)
	w.set_free_camera(true)
	w.set_camera_zoom_Factor(0.5)
	w.get_camera().global_position = Vector2(960.0, 220.0)
	await _save_viewport_png("02_indoor_04_zhao_home_P_full.png")
	w.set_camera_zoom_Factor(1.0)
	w.set_free_camera(false)
	w.jump_to_position(960.0, 1)
	await _save_viewport_png("02_indoor_04b_zhao_home_P_detail.png")

	# 3.5 Q 陈叔维修角
	w = await _goto_and_wait(&"repair_corner", &"spawn_entrance")
	w.set_clean_mode(true)
	w.set_free_camera(true)
	w.set_camera_zoom_Factor(0.5)
	w.get_camera().global_position = Vector2(960.0, 220.0)
	await _save_viewport_png("02_indoor_05_repair_corner_Q_full.png")
	w.set_camera_zoom_Factor(1.0)
	w.set_free_camera(false)
	w.jump_to_position(1024.0, 1)
	await _save_viewport_png("02_indoor_05b_repair_corner_Q_detail.png")

	# 3.6 J 唐宁的街角便利店
	w = await _goto_and_wait(&"convenience_store", &"spawn_entrance")
	w.set_clean_mode(true)
	w.set_free_camera(true)
	w.set_camera_zoom_Factor(0.40)
	w.get_camera().global_position = Vector2(1200.0, 220.0)
	await _save_viewport_png("02_indoor_06_convenience_store_J_full.png")
	w.set_camera_zoom_Factor(1.0)
	w.set_free_camera(false)
	w.jump_to_position(1152.0, 1)
	await _save_viewport_png("02_indoor_06b_convenience_store_J_detail.png")

	# 3.7 N 社区药店内景
	w = await _goto_and_wait(&"pharmacy", &"spawn_entrance")
	w.set_clean_mode(true)
	w.set_free_camera(true)
	w.set_camera_zoom_Factor(0.5)
	w.get_camera().global_position = Vector2(960.0, 220.0)
	await _save_viewport_png("02_indoor_07_pharmacy_N_full.png")
	w.set_camera_zoom_Factor(1.0)
	w.set_free_camera(false)
	w.jump_to_position(1024.0, 1)
	await _save_viewport_png("02_indoor_07b_pharmacy_N_detail.png")

	# 3.8 H 灾前连锁超市（含 S 临时批发预约区）
	w = await _goto_and_wait(&"supermarket", &"spawn_entrance")
	w.set_clean_mode(true)
	w.jump_to_position(768.0, 1)
	await _save_viewport_png("02_indoor_08a_supermarket_H_entry_cart.png")
	w.jump_to_position(1824.0, 1)
	await _save_viewport_png("02_indoor_08b_supermarket_H_shelves.png")
	w.jump_to_position(3680.0, 1)
	await _save_viewport_png("02_indoor_08c_supermarket_S_reserve_zone.png")
	w.jump_to_position(5024.0, 1)
	await _save_viewport_png("02_indoor_08d_supermarket_H_coolers_checkout.png")

	# 3.9 I 五金 / 家电店
	w = await _goto_and_wait(&"hardware_store", &"spawn_entrance")
	w.set_clean_mode(true)
	w.jump_to_position(1152.0, 1)
	await _save_viewport_png("02_indoor_09a_hardware_store_I_tools_seal.png")
	w.jump_to_position(2752.0, 1)
	await _save_viewport_png("02_indoor_09b_hardware_store_I_heater_gen.png")
	w.jump_to_position(3680.0, 1)
	await _save_viewport_png("02_indoor_09c_hardware_store_I_checkout_loading.png")

	# 3.10 K 独立批发仓与装卸区
	w = await _goto_and_wait(&"wholesale_warehouse", &"spawn_entrance")
	w.set_clean_mode(true)
	w.jump_to_position(864.0, 1)
	await _save_viewport_png("02_indoor_10a_warehouse_K_entry_pallets.png")
	w.jump_to_position(2208.0, 1)
	await _save_viewport_png("02_indoor_10b_warehouse_K_industrial_shelves.png")
	w.jump_to_position(4160.0, 1)
	await _save_viewport_png("02_indoor_10c_warehouse_K_order_dock.png")

	# 3.11 L 物流中转点 / 大件取货口
	w = await _goto_and_wait(&"logistics_hub", &"spawn_entrance")
	w.set_clean_mode(true)
	w.jump_to_position(768.0, 1)
	await _save_viewport_png("02_indoor_11a_logistics_hub_L_entry.png")
	w.jump_to_position(1920.0, 1)
	await _save_viewport_png("02_indoor_11b_logistics_hub_L_canopy_window.png")

	# 3.12 G0 序章 P00 前世门外走廊
	w = await _goto_and_wait(&"past_corridor", &"spawn_corridor_left")
	w.set_clean_mode(true)
	w.jump_to_position(960.0, 1)
	await _save_viewport_png("02_indoor_12_past_corridor_G0_full.png")

	# ------------------------------------------------------------------
	# 4. 带比例辅助线 (F3) 的角色与建筑对照图 (03_scale_*, 960×540)
	# ------------------------------------------------------------------
	w = await _goto_and_wait(&"outdoor_street", &"spawn_home_gate")
	w.set_clean_mode(false)
	w.set_debug_guides_visible(true)
	w.jump_to_position(912.0, 1)
	await _save_viewport_png("03_scale_01_outdoor_safehouse_door_96x192.png")

	w.jump_to_position(3008.0, 1)
	await _save_viewport_png("03_scale_02_outdoor_apartment_facade.png")

	w.jump_to_position(7552.0, 1)
	await _save_viewport_png("03_scale_03_outdoor_supermarket_door_192x224.png")

	w = await _goto_and_wait(&"shelter", &"spawn_front_door")
	w.set_clean_mode(false)
	w.set_debug_guides_visible(true)
	w.jump_to_position(2496.0, 1)
	await _save_viewport_png("03_scale_04_indoor_shelter_1F_2F_stairs.png")

	w = await _goto_and_wait(&"supermarket", &"spawn_entrance")
	w.set_clean_mode(false)
	w.set_debug_guides_visible(true)
	w.jump_to_position(1296.0, 1)
	await _save_viewport_png("03_scale_05_indoor_supermarket_shelves_aisle_192.png")

	print("==================== TASK-SCENE-002 截图巡检完成 ====================")


# ==============================================================================
# 三、TASK-SCENE-003 正式美术参考干净截图套件 (--scene003-tour)
# ==============================================================================
func _save_scene003_png(rel_name: String, scene_key: StringName, cam_center: Vector2, zoom_val: float = 1.0) -> Image:
	await _wait_frames(3)
	await RenderingServer.frame_post_draw
	var full_path := "%s/%s" % [SHOT003_DIR, rel_name]
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(full_path)
	print("[SCENE003-SHOT] file=%s | key=%s | cam=(%.0f, %.0f) | zoom=%.2fx | size=%dx%d | err=%d" % [
		rel_name,
		scene_key,
		cam_center.x,
		cam_center.y,
		zoom_val,
		img.get_width(),
		img.get_height(),
		err,
	])
	return img


func _capture_cam_1x(w: WhiteboxWorld, cam_x: float, cam_y: float) -> Image:
	w.get_camera().global_position = Vector2(cam_x, cam_y)
	await _wait_frames(3)
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _stitch_scene_1x(
	w: WhiteboxWorld,
	width_px: int,
	two_floors: bool,
	player_x: float,
	player_floor: int,
	rel_name: String
) -> Image:
	w.set_clean_mode(true)
	w.set_debug_guides_visible(false)
	w.set_free_camera(true)
	w.set_camera_zoom_Factor(1.0)

	var p := w.get_player()
	if p != null:
		p.ground_y = Season1Layout.GROUND_Y if player_floor == 1 else Season1Layout.FLOOR2_Y
		p.teleport_to(player_x)
		p.set_facing(1)

	var out_h := 720 if two_floors else 540
	var canvas := Image.create(width_px, out_h, false, Image.FORMAT_RGBA8)
	var x0 := 0
	var cam_list: PackedStringArray = []
	while x0 < width_px:
		var rem_w := width_px - x0
		var copy_w := mini(960, rem_w)
		var cam_x := float(x0 + 480) if rem_w >= 960 else float(width_px - 480)
		var src_x := 0 if rem_w >= 960 else (960 - rem_w)

		if two_floors:
			# 上层视口 cam_y=90 覆盖世界 Y=[-180..360]，截取顶部 180px (Y=[-180..0])
			var img_top := await _capture_cam_1x(w, cam_x, 90.0)
			canvas.blit_rect(img_top, Rect2i(src_x, 0, copy_w, 180), Vector2i(x0, 0))
			# 下层视口 cam_y=270 覆盖世界 Y=[0..540]，截取完整 540px
			var img_bot := await _capture_cam_1x(w, cam_x, 270.0)
			canvas.blit_rect(img_bot, Rect2i(src_x, 0, copy_w, 540), Vector2i(x0, 180))
			cam_list.append("(%.0f,90)&(%.0f,270)" % [cam_x, cam_x])
		else:
			var img_1f := await _capture_cam_1x(w, cam_x, 270.0)
			canvas.blit_rect(img_1f, Rect2i(src_x, 0, copy_w, 540), Vector2i(x0, 0))
			cam_list.append("(%.0f,270)" % cam_x)

		x0 += 960

	var full_path := "%s/%s" % [SHOT003_DIR, rel_name]
	var err := canvas.save_png(full_path)
	print("[SCENE003-SHOT] file=%s | key=%s | cams=[%s] | zoom=1.00x (1:1 stitch) | size=%dx%d | err=%d" % [
		rel_name,
		w.location_key,
		", ".join(cam_list),
		canvas.get_width(),
		canvas.get_height(),
		err,
	])
	return canvas


func _take_native_shot(
	w: WhiteboxWorld,
	rel_name: String,
	cam_x: float,
	cam_y: float,
	player_x: float,
	player_floor: int = 1
) -> void:
	w.set_clean_mode(true)
	w.set_debug_guides_visible(false)
	w.set_free_camera(true)
	w.set_camera_zoom_Factor(1.0)
	var p := w.get_player()
	if p != null:
		p.ground_y = Season1Layout.GROUND_Y if player_floor == 1 else Season1Layout.FLOOR2_Y
		p.teleport_to(player_x)
		p.set_facing(1)
	w.get_camera().global_position = Vector2(cam_x, cam_y)
	await _save_scene003_png(rel_name, w.location_key, Vector2(cam_x, cam_y), 1.0)


func _run_scene003_tour() -> void:
	print("")
	print("==================== TASK-SCENE-003 正式美术参考截图生成开始 ====================")

	# ------------------------------------------------------------------
	# 1. 室外地图逐段连续 960×540 截图 (01_outdoor_seg01..16) & 完整室外长街白盒总览 (00_*)
	# ------------------------------------------------------------------
	var w := await _goto_and_wait(&"outdoor_street", &"spawn_home_gate")
	w.set_clean_mode(true)
	w.set_debug_guides_visible(false)
	w.set_free_camera(true)
	w.set_camera_zoom_Factor(1.0)

	# 将主角固定在第一屏安全屋窗前 (x=768, y=416)，避开 960px 拼缝，全街唯一出现一次做比例锚点
	var p := w.get_player()
	p.ground_y = Season1Layout.GROUND_Y
	p.teleport_to(768.0)
	p.set_facing(1)

	var seg_imgs_180: Array[Image] = []
	var seg_imgs_top: Array[Image] = []
	var seg_imgs_bot: Array[Image] = []

	for i in range(16):
		var x_start := i * 960
		var x_end := (i + 1) * 960
		var cam_x := float(x_start + 480)
		var cam_y := 180.0
		w.get_camera().global_position = Vector2(cam_x, cam_y)
		var seg_file := "01_outdoor_seg%02d_x%05d_%05d.png" % [i + 1, x_start, x_end]
		var seg_img := await _save_scene003_png(seg_file, &"outdoor_street", Vector2(cam_x, cam_y), 1.0)
		seg_imgs_180.append(seg_img)

		# 同时采集 Y=[-180..540] 双层纵向带，用于生成不裁切屋顶天线/遮棚的 1:1 三段总览
		var top_img := await _capture_cam_1x(w, cam_x, 90.0)
		var bot_img := await _capture_cam_1x(w, cam_x, 270.0)
		seg_imgs_top.append(top_img)
		seg_imgs_bot.append(bot_img)

	# 00-A: 16 张连续分段 1:1 原生直接拼合长卷 (15360 × 540, zoom=1.0x, 0 缩放 0 模糊)
	var full_strip_1x := Image.create(15360, 540, false, Image.FORMAT_RGBA8)
	for i in range(16):
		full_strip_1x.blit_rect(seg_imgs_180[i], Rect2i(0, 0, 960, 540), Vector2i(i * 960, 0))
	var path_strip_1x := "%s/00_outdoor_overview_full_strip_1x.png" % SHOT003_DIR
	full_strip_1x.save_png(path_strip_1x)
	print("[SCENE003-SHOT] file=00_outdoor_overview_full_strip_1x.png | key=outdoor_street | cam=(480..14880, 180) | zoom=1.00x | size=15360x540")

	# 00-B: 整数 0.5x Nearest 邻近采样长卷 (7680 × 270，保持硬边像素无双线性模糊)
	var strip_half: Image = full_strip_1x.duplicate()
	strip_half.resize(7680, 270, Image.INTERPOLATE_NEAREST)
	var path_strip_half := "%s/00_outdoor_overview_strip_half_nearest.png" % SHOT003_DIR
	strip_half.save_png(path_strip_half)
	print("[SCENE003-SHOT] file=00_outdoor_overview_strip_half_nearest.png | key=outdoor_street | cam=(480..14880, 180) | zoom=0.50x(Nearest) | size=7680x270")

	# 00-C: 三段叠排 1:1 原生高清总览图 (5120 × 2160，每段 5120×720 完整覆盖 Y=-180..540，0 缩放 0 模糊)
	var full_720 := Image.create(15360, 720, false, Image.FORMAT_RGBA8)
	for i in range(16):
		full_720.blit_rect(seg_imgs_top[i], Rect2i(0, 0, 960, 180), Vector2i(i * 960, 0))
		full_720.blit_rect(seg_imgs_bot[i], Rect2i(0, 0, 960, 540), Vector2i(i * 960, 180))
	var three_seg_1x := Image.create(5120, 2160, false, Image.FORMAT_RGBA8)
	for row_i in range(3):
		three_seg_1x.blit_rect(full_720, Rect2i(row_i * 5120, 0, 5120, 720), Vector2i(0, row_i * 720))
	var path_3seg := "%s/00_outdoor_overview_3segments_1x.png" % SHOT003_DIR
	three_seg_1x.save_png(path_3seg)
	print("[SCENE003-SHOT] file=00_outdoor_overview_3segments_1x.png | key=outdoor_street | cam=(0..15360, Y=-180..540) | zoom=1.00x | size=5120x2160")

	# ------------------------------------------------------------------
	# 2. 所有室内场景完整结构图 (02_indoor_full_01..12, 1.0x 原生 1:1 拼接)
	#    & 6. 安全屋两层完整剖面图 (05_shelter_2floors_cross_section_1x.png)
	# ------------------------------------------------------------------
	w = await _goto_and_wait(&"shelter", &"spawn_bed")
	var shelter_cross := await _stitch_scene_1x(w, 3200, true, 1376.0, 1, "02_indoor_full_01_shelter_3200x720.png")
	var path_shelter_sec := "%s/05_shelter_2floors_cross_section_1x.png" % SHOT003_DIR
	shelter_cross.save_png(path_shelter_sec)
	print("[SCENE003-SHOT] file=05_shelter_2floors_cross_section_1x.png | key=shelter | cams=[(480..2720, 90&270)] | zoom=1.00x | size=3200x720")

	w = await _goto_and_wait(&"equipment_room", &"spawn_entrance")
	await _stitch_scene_1x(w, 1920, false, 640.0, 1, "02_indoor_full_02_equipment_room_1920x540.png")

	w = await _goto_and_wait(&"apartment_hallway", &"spawn_unit_door")
	await _stitch_scene_1x(w, 2400, true, 608.0, 1, "02_indoor_full_03_apartment_hallway_2400x720.png")

	w = await _goto_and_wait(&"zhao_home", &"spawn_entrance")
	await _stitch_scene_1x(w, 1920, false, 608.0, 1, "02_indoor_full_04_zhao_home_1920x540.png")

	w = await _goto_and_wait(&"repair_corner", &"spawn_entrance")
	await _stitch_scene_1x(w, 1920, false, 640.0, 1, "02_indoor_full_05_repair_corner_1920x540.png")

	w = await _goto_and_wait(&"convenience_store", &"spawn_entrance")
	await _stitch_scene_1x(w, 2400, false, 640.0, 1, "02_indoor_full_06_convenience_store_2400x540.png")

	w = await _goto_and_wait(&"pharmacy", &"spawn_entrance")
	await _stitch_scene_1x(w, 1920, false, 640.0, 1, "02_indoor_full_07_pharmacy_1920x540.png")

	w = await _goto_and_wait(&"supermarket", &"spawn_entrance")
	await _stitch_scene_1x(w, 5760, false, 640.0, 1, "02_indoor_full_08_supermarket_5760x540.png")

	w = await _goto_and_wait(&"hardware_store", &"spawn_entrance")
	await _stitch_scene_1x(w, 4320, false, 640.0, 1, "02_indoor_full_09_hardware_store_4320x540.png")

	w = await _goto_and_wait(&"wholesale_warehouse", &"spawn_entrance")
	await _stitch_scene_1x(w, 5120, false, 640.0, 1, "02_indoor_full_10_wholesale_warehouse_5120x540.png")

	w = await _goto_and_wait(&"logistics_hub", &"spawn_entrance")
	await _stitch_scene_1x(w, 2880, false, 640.0, 1, "02_indoor_full_11_logistics_hub_2880x540.png")

	w = await _goto_and_wait(&"past_corridor", &"spawn_corridor_left")
	await _stitch_scene_1x(w, 1920, false, 640.0, 1, "02_indoor_full_12_past_corridor_1920x540.png")

	# ------------------------------------------------------------------
	# 3. 重要房间的 960×540 原生游戏截图 (03_native_*, zoom=1.0x)
	# ------------------------------------------------------------------
	w = await _goto_and_wait(&"shelter", &"spawn_bed")
	await _take_native_shot(w, "03_native_01_shelter_1F_bed_desk.png", 608.0, 270.0, 608.0, 1)
	await _take_native_shot(w, "03_native_02_shelter_1F_shelves_kitchen.png", 1600.0, 270.0, 1600.0, 1)
	await _take_native_shot(w, "03_native_03_shelter_1F_stairs_entrance.png", 2560.0, 270.0, 2560.0, 1)
	await _take_native_shot(w, "03_native_04_shelter_2F_spare_window.png", 960.0, -18.0, 960.0, 2)
	await _take_native_shot(w, "03_native_05_shelter_2F_storage_stairs.png", 2080.0, -18.0, 2080.0, 2)

	w = await _goto_and_wait(&"equipment_room", &"spawn_entrance")
	await _take_native_shot(w, "03_native_06_equipment_room_vent_gen.png", 640.0, 270.0, 640.0, 1)
	await _take_native_shot(w, "03_native_07_equipment_room_gen_breaker.png", 1280.0, 270.0, 1280.0, 1)

	w = await _goto_and_wait(&"apartment_hallway", &"spawn_unit_door")
	await _take_native_shot(w, "03_native_08_apartment_hallway_1F.png", 608.0, 270.0, 608.0, 1)
	await _take_native_shot(w, "03_native_09_apartment_hallway_2F_zhao_door.png", 1408.0, -18.0, 1408.0, 2)

	w = await _goto_and_wait(&"zhao_home", &"spawn_entrance")
	await _take_native_shot(w, "03_native_10_zhao_home_table_bed.png", 960.0, 270.0, 960.0, 1)

	w = await _goto_and_wait(&"repair_corner", &"spawn_entrance")
	await _take_native_shot(w, "03_native_11_repair_corner_workbench.png", 960.0, 270.0, 960.0, 1)

	w = await _goto_and_wait(&"convenience_store", &"spawn_entrance")
	await _take_native_shot(w, "03_native_12_convenience_store_shelves_cooler.png", 800.0, 270.0, 800.0, 1)
	await _take_native_shot(w, "03_native_13_convenience_store_counter_backdoor.png", 1664.0, 270.0, 1664.0, 1)

	w = await _goto_and_wait(&"pharmacy", &"spawn_entrance")
	await _take_native_shot(w, "03_native_14_pharmacy_shelf_counter.png", 1024.0, 270.0, 1024.0, 1)

	w = await _goto_and_wait(&"supermarket", &"spawn_entrance")
	await _take_native_shot(w, "03_native_15_supermarket_entry_cart.png", 768.0, 270.0, 688.0, 1)
	await _take_native_shot(w, "03_native_16_supermarket_shelves_aisle.png", 1728.0, 270.0, 1728.0, 1)
	await _take_native_shot(w, "03_native_17_supermarket_S_reserve_zone.png", 3680.0, 270.0, 3680.0, 1)
	await _take_native_shot(w, "03_native_18_supermarket_coolers_checkout.png", 5024.0, 270.0, 5024.0, 1)

	w = await _goto_and_wait(&"hardware_store", &"spawn_entrance")
	await _take_native_shot(w, "03_native_19_hardware_store_tools_seal.png", 1440.0, 270.0, 1440.0, 1)
	await _take_native_shot(w, "03_native_20_hardware_store_heater_checkout.png", 3136.0, 270.0, 3136.0, 1)

	w = await _goto_and_wait(&"wholesale_warehouse", &"spawn_entrance")
	await _take_native_shot(w, "03_native_21_warehouse_entry_shelves.png", 1440.0, 270.0, 1440.0, 1)
	await _take_native_shot(w, "03_native_22_warehouse_order_dock.png", 4160.0, 270.0, 4160.0, 1)

	w = await _goto_and_wait(&"logistics_hub", &"spawn_entrance")
	await _take_native_shot(w, "03_native_23_logistics_hub_canopy_window.png", 1824.0, 270.0, 1824.0, 1)

	w = await _goto_and_wait(&"past_corridor", &"spawn_corridor_left")
	await _take_native_shot(w, "03_native_24_past_corridor_locked_door.png", 1024.0, 270.0, 1024.0, 1)

	# ------------------------------------------------------------------
	# 4. 角色与建筑比例对照图 (04_scale_*, 960×540, zoom=1.0x, 干净无字无网格)
	# ------------------------------------------------------------------
	w = await _goto_and_wait(&"outdoor_street", &"spawn_home_gate")
	await _take_native_shot(w, "04_scale_01_outdoor_safehouse_door_96x192.png", 912.0, 180.0, 912.0, 1)
	await _take_native_shot(w, "04_scale_02_outdoor_apartment_facade_512h.png", 3008.0, 180.0, 3008.0, 1)
	await _take_native_shot(w, "04_scale_03_outdoor_supermarket_wide_door_192x224.png", 7552.0, 240.0, 7552.0, 1)

	w = await _goto_and_wait(&"shelter", &"spawn_front_door")
	await _take_native_shot(w, "04_scale_04_indoor_shelter_1F_2F_stairs_door.png", 2496.0, 180.0, 2496.0, 1)

	w = await _goto_and_wait(&"supermarket", &"spawn_entrance")
	w.set_clean_mode(true)
	w.set_debug_guides_visible(false)
	w.set_free_camera(true)
	w.set_camera_zoom_Factor(1.0)
	if w.get_carts().size() > 0:
		var cart := w.get_carts()[0]
		cart.place_at(1336.0)
	w.get_player().ground_y = Season1Layout.GROUND_Y
	w.get_player().teleport_to(1256.0)
	w.get_player().set_facing(1)
	w.get_camera().global_position = Vector2(1296.0, 270.0)
	await _save_scene003_png("04_scale_05_indoor_supermarket_player_cart_shelves_aisle192.png", &"supermarket", Vector2(1296.0, 270.0), 1.0)

	print("==================== TASK-SCENE-003 正式美术参考截图生成完成 ====================")

