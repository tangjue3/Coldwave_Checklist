extends SceneTree
## 室内场景结构自检：两个室内是否可实例化、玩家/相机/门/传感器是否就位

const PATHS := ["res://scenes/world/int_c.tscn", "res://scenes/world/int_a.tscn"]


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var fail := 0
	for p in PATHS:
		var ps := load(p) as PackedScene
		if ps == null:
			print("[INT-VERIFY] FAIL load ", p)
			fail += 1
			continue
		var inst := ps.instantiate()
		root.add_child(inst)
		await process_frame
		await process_frame

		var art := inst.get_node_or_null("00_Art") as Sprite2D
		var player := inst.get_node_or_null("Actors/Player") as Node2D
		var cam := inst.get_node_or_null("Camera2D") as Camera2D
		var door := inst.get_node_or_null("Interaction/Door_To_Street")
		var sensor := inst.get_node_or_null("Interaction/InteractionSensor")

		var w: float = float(inst.get("world_width"))
		var sx: float = player.global_position.x if player else -9999.0
		var ok: bool = art != null and player != null and cam != null and door != null and sensor != null and art.texture != null
		print("[INT-VERIFY] %s w=%.0f 玩家x=%.0f art=%s tex=%s cam=%s door=%s sensor=%s %s" % [
			p.get_file(), w, sx,
			art != null, art.texture != null if art else false,
			cam != null, door != null, sensor != null,
			"PASS" if ok else "FAIL"])
		if not ok:
			fail += 1
		inst.queue_free()
		await process_frame

	print("[INT-VERIFY] 总计 %s" % ("PASS" if fail == 0 else "FAIL %d" % fail))
	quit(0 if fail == 0 else 1)
