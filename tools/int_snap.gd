extends SceneTree
## 室内场景出图：默认视角 + 全景，用于核对美术与地面/人物对齐
##
##   Godot_v4.7.2-stable_win64_console.exe --path <项目根> --resolution 1920x1080 --script res://tools/int_snap.gd

const OUT_DIR := "res://tests/screenshots/season1/interior"

const JOBS := [
	{"scene": "res://scenes/world/int_c.tscn", "name": "int_c_默认", "x": 160.0, "zoom": 2.0, "y": -110.0},
	{"scene": "res://scenes/world/int_c.tscn", "name": "int_c_全景", "x": 407.0, "zoom": 2.36, "y": -205.0},
	{"scene": "res://scenes/world/int_a.tscn", "name": "int_a_默认", "x": 1100.0, "zoom": 2.0, "y": -120.0},
	{"scene": "res://scenes/world/int_a.tscn", "name": "int_a_全景", "x": 604.0, "zoom": 1.59, "y": -345.0},
]

var _abs := ""


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1920, 1080)
	_abs = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(_abs)
	_run()


func _run() -> void:
	await process_frame
	var current := ""
	var inst: Node2D = null

	for j in JOBS:
		var path := String(j["scene"])
		if path != current:
			if inst != null:
				inst.queue_free()
				await process_frame
			var ps := load(path) as PackedScene
			inst = ps.instantiate() as Node2D
			root.add_child(inst)
			await process_frame
			await process_frame
			current = path
			var ui := inst.get_node_or_null("UI") as CanvasLayer
			if ui != null:
				ui.visible = false

		var cam := inst.get_node_or_null("Camera2D") as Camera2D
		if cam == null:
			continue
		cam.set("follow_enabled", false)
		cam.limit_left = -1000000
		cam.limit_right = 1000000
		cam.limit_top = -1000000
		cam.limit_bottom = 1000000
		cam.zoom = Vector2(float(j["zoom"]), float(j["zoom"]))
		cam.global_position = Vector2(float(j["x"]), float(j["y"]))
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw

		var img := root.get_texture().get_image()
		if img == null:
			print("[ISNAP] FAIL null")
			quit(1)
			return
		var f := "%s.png" % String(j["name"])
		var err := img.save_png(_abs + "/" + f)
		print("[ISNAP] %s %dx%d err=%d" % [f, img.get_width(), img.get_height(), err])

	print("[ISNAP] done")
	quit(0)
