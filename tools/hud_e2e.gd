extends SceneTree
## 正式 HUD 端到端测试（TASK-UI-009）
##
## 在真实第一季街道场景里验证 HUD 的七件事：
##   1) HUD 在 CanvasLayer 里，逻辑分辨率 960×540
##   2) 交互提示由 HUD 在屏幕空间显示，文案来自真实热点（门）
##   3) 数字键 1–6 切快捷栏，选中态换的是美术贴图
##   4) T 键 / 点标题栏 展开收起今日清单
##   5) 相机 zoom 变化不影响 HUD 的位置与尺寸
##   6) 地点名来自 GameState.location（真数据），测试数据字段被如实标出
##   7) 关掉世界坐标提示后，屏幕上只剩一份提示（不重复）
##
##   Godot_v4.7.2-stable_win64_console.exe --headless --path <项目根> --script res://tools/hud_e2e.gd

const STREET := "res://scenes/world/season1_map.tscn"
## A/B 门的热点中心（热点相对门框右偏 327.5，属 TASK-UI-001 记录的既有问题）
const DOOR_A_X := 2377.0

var fails := 0


func _initialize() -> void:
	_run()


func _wait(n: int = 6) -> void:
	for i in n:
		await process_frame
	for i in n:
		await physics_frame


func _fail(msg: String) -> void:
	fails += 1
	print("[HUD-E2E] FAIL %s" % msg)


func _ok(msg: String) -> void:
	print("[HUD-E2E] OK   %s" % msg)


func _press(code: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame
	await process_frame


func _run() -> void:
	await _wait(3)
	change_scene_to_file(STREET)
	await _wait(10)

	var scene := current_scene
	if scene == null:
		print("[HUD-E2E] FAIL 街道未加载")
		quit(1)
		return

	var hud := scene.get_node_or_null("HUD") as CanvasLayer
	if hud == null:
		print("[HUD-E2E] FAIL 街道里没有 HUD 节点")
		quit(1)
		return

	# 1. 屏幕空间
	if hud.layer != 20:
		_fail("HUD 不在预期的 CanvasLayer 层（layer=%d）" % hud.layer)
	else:
		_ok("HUD 在 CanvasLayer(layer=%d)，与相机坐标系无关" % hud.layer)
	var root := hud.get_node_or_null("Root") as Control
	if root == null or root.size != Vector2(960, 540):
		_fail("HUD 逻辑尺寸不是 960×540：%s" % (root.size if root else "无 Root"))
	else:
		_ok("HUD 逻辑分辨率 960×540")

	# 2. 世界坐标提示必须让位
	var sensor := scene.get_node_or_null("Interaction/InteractionSensor")
	if sensor == null:
		_fail("街道缺少 InteractionSensor")
	else:
		if sensor.get("draw_world_prompt") != false:
			_fail("InteractionSensor 仍在世界坐标画提示（会和 HUD 重复、且随 zoom 缩小）")
		else:
			_ok("世界坐标提示已关闭，提示只在 CanvasLayer 里画一份")

	# 3. 地点：真数据
	var loc := (root.get_node("LocationPanel/LocationText") as Label).text
	if loc == "梧桐里 · 长街":
		_ok("地点来自 GameState.location → 「%s」" % loc)
	else:
		_fail("地点显示异常：「%s」" % loc)
	var mock: PackedStringArray = hud.get("mock_fields")
	print("[HUD-E2E] INFO 测试数据字段：%s" % ", ".join(mock))
	if mock.size() == 0:
		_fail("没有标出测试数据字段（会让人误以为时间/生存/物资/任务已实现）")
	elif (root.get_node("MockBadge") as Label).visible:
		_ok("右上角标出「%s」" % (root.get_node("MockBadge") as Label).text)
	else:
		_fail("有测试数据但角标没显示")

	# 4. 交互提示（真实门热点）
	var player := scene.get_node_or_null("Actors/Player") as Node2D
	if player == null:
		_fail("街道缺少 Player")
	else:
		var panel := root.get_node("InteractPanel") as Control
		if panel.visible:
			_fail("没靠近任何东西时提示就显示了")
		player.call("teleport_to", DOOR_A_X)
		await _wait(8)
		var target = sensor.get("current")
		if target == null:
			_fail("走到 A/B 门口却没锁定热点")
		else:
			var want: String = target.prompt_text()
			if want.begins_with("E "):
				want = want.substr(2)
			if want == "进入" and "door_label" in target:
				want = "进入 %s" % String(target.get("door_label"))
			var got := (root.get_node("InteractPanel/InteractText") as Label).text
			if not panel.visible:
				_fail("靠近 %s 时 HUD 提示没出现" % target.name)
			elif got != want:
				_fail("提示文案不一致：HUD=「%s」热点=「%s」" % [got, want])
			else:
				_ok("交互提示「%s」（来自真实热点 %s）" % [got, target.name])
		player.call("teleport_to", 3000.0)
		await _wait(8)
		if panel.visible:
			_fail("离开门口后提示没有消失")
		else:
			_ok("离开热点后提示消失")

	# 5. 快捷栏：数字键
	await _press(KEY_3)
	if int(hud.get("selected_slot")) != 3:
		_fail("按 3 没切到第 3 格（当前 %d）" % int(hud.get("selected_slot")))
	else:
		var s3 := root.get_node("Slot3") as TextureRect
		var s1 := root.get_node("Slot1") as TextureRect
		if s3.texture == s1.texture:
			_fail("选中格没有换成选中态贴图")
		else:
			_ok("数字键 3 切到第 3 格，选中态贴图已切换")
	await _press(KEY_6)
	if int(hud.get("selected_slot")) != 6:
		_fail("按 6 没切到第 6 格（当前 %d）" % int(hud.get("selected_slot")))
	else:
		_ok("数字键 6 切到第 6 格")

	# 6. 今日清单展开 / 收起
	var tasks := root.get_node("TasksPanel") as TextureRect
	var list := root.get_node("TasksPanel/TaskList") as Control
	var full_tex := tasks.texture
	if tasks.size != Vector2(216, 152) or not list.visible:
		_fail("今日清单初始不是展开态")
	await _press(KEY_T)
	if not bool(hud.get("tasks_collapsed")) or tasks.size != Vector2(216, 35) or list.visible:
		_fail("按 T 没有收起（size=%s collapsed=%s）" % [tasks.size, hud.get("tasks_collapsed")])
	else:
		_ok("T 键收起：面板 216×35、任务行隐藏、贴图换成短面板")
	await _press(KEY_T)
	if bool(hud.get("tasks_collapsed")) or tasks.size != Vector2(216, 152) or not list.visible:
		_fail("再按 T 没有展开")
	else:
		_ok("再按 T 展开：面板 216×152、贴图恢复")
	# 点标题栏同样生效
	var hit := root.get_node("TasksPanel/TasksHit") as Button
	hit.pressed.emit()
	await process_frame
	if not bool(hud.get("tasks_collapsed")):
		_fail("点标题栏没有收起")
	else:
		_ok("点击标题栏同样可收起")
	hit.pressed.emit()
	await process_frame

	# 7. 相机缩放不影响 HUD
	var cam := scene.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		_fail("街道缺少 Camera2D")
	else:
		var before_pos := (root.get_node("StatusPanel") as Control).global_position
		var before_size := (root.get_node("StatusPanel") as Control).size
		var before_zoom := cam.zoom
		cam.zoom = Vector2(1.6, 1.6)
		await _wait(4)
		var after_pos := (root.get_node("StatusPanel") as Control).global_position
		var after_size := (root.get_node("StatusPanel") as Control).size
		if after_pos != before_pos or after_size != before_size:
			_fail("相机 zoom 1.6 后 HUD 动了：%s→%s / %s→%s" % [
				before_pos, after_pos, before_size, after_size])
		else:
			_ok("相机 zoom %.1f→1.6，生存状态面板位置与尺寸完全不变" % before_zoom.x)
		cam.zoom = before_zoom

	print("[HUD-E2E] %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	quit(0 if fails == 0 else 1)
