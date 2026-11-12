extends SceneTree
## 门 <-> 室内 端到端测试（无窗口）
##
##  1) 打开 season1_map，把玩家挪到 A/B 门口，确认 InteractionSensor 锁定到 Door_IntA
##  2) 触发交互 → 应切到 int_a
##  3) 在 int_a 里挪到出口门，触发 → 应切回 season1_map，且落点在门口（约 x=2050）
##  4) 同样跑一遍 C 设备区
##
##   Godot_v4.7.2-stable_win64_console.exe --headless --path <项目根> --script res://tools/door_e2e.gd

const STREET := "res://scenes/world/season1_map.tscn"

var fails := 0


func _initialize() -> void:
	_run()


func _wait(n: int = 6) -> void:
	# 热点锁定发生在 _physics_process，只等 process_frame 会漏掉第一次
	for i in n:
		await process_frame
	for i in n:
		await physics_frame


func _run() -> void:
	await _wait(3)
	change_scene_to_file(STREET)
	await _wait(8)

	await _check_pair("A/B", 2050.0, "int_a", 1100.0)
	await _check_pair("C", 1173.0, "int_c", 160.0)

	print("[E2E] %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	quit(0 if fails == 0 else 1)


func _check_pair(label: String, street_x: float, int_key: String, int_door_x: float) -> void:
	var street := current_scene
	if street == null:
		print("[E2E] FAIL 街道未加载")
		fails += 1
		return

	var player := street.get_node_or_null("Actors/Player") as Node2D
	var sensor := street.get_node_or_null("Interaction/InteractionSensor")
	if player == null or sensor == null:
		print("[E2E] FAIL 街道缺少 Player/Sensor")
		fails += 1
		return

	player.call("teleport_to", street_x)
	await _wait(6)

	var target = sensor.get("current")
	var target_name := String(target.name) if target != null else "<无>"
	print("[E2E] %s 街道 x=%.0f 锁定=%s" % [label, street_x, target_name])
	if target == null:
		fails += 1
		print("[E2E] FAIL 门口没有可选热点")
		return

	target.call("interact", player)
	await _wait(10)

	var now := current_scene
	var now_path := now.scene_file_path if now else ""
	var want := "res://scenes/world/%s.tscn" % int_key
	if now_path != want:
		print("[E2E] FAIL 进门失败 期望 %s 实际 %s" % [want, now_path])
		fails += 1
		return
	print("[E2E] %s 进门 OK → %s" % [label, now_path])

	var in_player := now.get_node_or_null("Actors/Player") as Node2D
	var in_sensor := now.get_node_or_null("Interaction/InteractionSensor")
	if in_player == null or in_sensor == null:
		print("[E2E] FAIL 室内缺少 Player/Sensor")
		fails += 1
		return
	await _wait(4)
	var back = in_sensor.get("current")
	print("[E2E] %s 室内落点 x=%.0f 锁定=%s" % [label, in_player.global_position.x,
		String(back.name) if back != null else "<无>"])
	if back == null:
		fails += 1
		print("[E2E] FAIL 室内门口没有热点")
		return

	back.call("interact", in_player)
	await _wait(10)

	var back_scene := current_scene
	var back_path := back_scene.scene_file_path if back_scene else ""
	if back_path != STREET:
		print("[E2E] FAIL 出门失败 实际 %s" % back_path)
		fails += 1
		return
	var p2 := back_scene.get_node_or_null("Actors/Player") as Node2D
	var px := p2.global_position.x if p2 else -1.0
	print("[E2E] %s 出门 OK → 街道 x=%.0f（期望约 %.0f）" % [label, px, street_x])
	if absf(px - street_x) > 80.0:
		print("[E2E] FAIL 返回落点偏差过大")
		fails += 1
