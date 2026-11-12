extends SceneTree
## 交互体检：逐个加载场景，确认 InteractionSensor 能解析到玩家、且热点确实在组里
##
##   Godot_v4.7.2-stable_win64_console.exe --headless --path <项目根> --script res://tools/door_diag.gd

## 只体检正式场景（街道 + 两张室内）。旧白盒占位场景由 whitebox_world.gd
## 动态生成节点，没有 Interaction/InteractionSensor，不属于本工具的检查范围。
const SCENES: Array[String] = [
	"res://scenes/world/season1_map.tscn",
	"res://scenes/world/int_a.tscn",
	"res://scenes/world/int_c.tscn",
]

var fails: int = 0


func _initialize() -> void:
	_run()


func _wait(n: int = 6) -> void:
	for i in n:
		await process_frame
	for i in n:
		await physics_frame


func _run() -> void:
	await _wait(3)
	for path in SCENES:
		change_scene_to_file(path)
		await _wait(6)
		var s: Node = current_scene
		var sensor: Node = s.get_node_or_null("Interaction/InteractionSensor")
		var player: Node = s.get_node_or_null("Actors/Player")
		var actor: Object = null
		if sensor != null:
			actor = sensor.get("actor") as Object
		var group: int = get_nodes_in_group(&"interactable").size()
		var ok: bool = (sensor != null and actor == player and player != null)
		if not ok:
			fails += 1
		print("[DIAG] %-22s sensor=%s actor=%s 热点=%d %s" % [
			path.get_file(), sensor != null, actor != null, group, "PASS" if ok else "FAIL"])
	print("[DIAG] %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	quit(0 if fails == 0 else 1)
