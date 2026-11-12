extends SceneTree
## 第一季地图 · 站位规范版自检（headless）
## Godot_v4.7.2-stable_win64_console.exe --headless --path <项目根> --script res://tools/rd1_verify.gd

const PATH := "res://scenes/world/season1_map.tscn"
const WANT_W := 25095.0
const WANT_FRAMES := 18        # 有实体高度的站位框（巷道不算）
const WANT_ART_SLOTS := 18


func _initialize() -> void:
	var scn := load(PATH) as PackedScene
	if scn == null:
		print("[MAP-VERIFY] FAIL load ", PATH)
		quit(1)
		return
	var inst := scn.instantiate()
	root.add_child(inst)

	var p := inst.get_node_or_null("Actors/Player")
	var cam := inst.get_node_or_null("Camera2D")
	var ground := inst.get_node_or_null("00_Ground")
	var frames := inst.get_node_or_null("01_Placeholders")
	var art := inst.get_node_or_null("02_Art")
	var w := float(inst.get("world_width"))

	var nf := frames.get_child_count() if frames else 0
	var na := art.get_child_count() if art else 0
	var anchors := 0
	if frames != null:
		for c in frames.get_children():
			if c.get_node_or_null("GroundCorner") != null:
				anchors += 1

	# 逐个核对底边是否压在地面线上
	var bad := []
	if frames != null:
		for c in frames.get_children():
			var h := float(String(c.name).split("x")[-1])
			var bottom: float = (c as Node2D).position.y + h
			if absf(bottom - 0.0) > 0.5:
				bad.append("%s(bottom=%.0f)" % [c.name, bottom])

	var ok: bool = p != null and cam != null and ground != null \
		and absf(w - WANT_W) < 1.0 and nf == WANT_FRAMES and na == WANT_ART_SLOTS \
		and anchors == WANT_FRAMES and bad.is_empty()

	print("[MAP-VERIFY] %s w=%.0f(期望%.0f) frames=%d(期望%d) art_slots=%d anchors=%d nodes=%d player=%s cam=%s ground=%s %s%s" % [
		PATH, w, WANT_W, nf, WANT_FRAMES, na, anchors, _count(inst),
		p != null, cam != null, ground != null,
		"PASS" if ok else "FAIL",
		"" if bad.is_empty() else " 底边偏离地面线: " + str(bad)])

	inst.queue_free()
	quit(0 if ok else 1)


func _count(n: Node) -> int:
	var k := 1
	for c in n.get_children():
		k += _count(c)
	return k
