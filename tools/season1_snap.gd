extends SceneTree
## 第一季站位场景 · 出图检查（占位框是否对齐、比例是否对）
##
## 运行（必须有窗口，不能加 --headless）：
##   Godot_v4.7.2-stable_win64_console.exe --path <项目根> --resolution 1920x1080 --script res://tools/season1_snap.gd

const SCENE_PATH := "res://scenes/world/season1_map.tscn"
const OUT_DIR := "res://tests/screenshots/season1/layout"

const SHOTS := [
	{"n": "00_C设备区_已接图", "x": 795.0, "zoom": 1.0, "y": -190.0},
	{"n": "01_小楼_游戏视角", "x": 2077.0, "zoom": 1.0, "y": -208.0},
	{"n": "02_小楼_站位框", "x": 2077.0, "zoom": 0.42, "y": -396.0},
	{"n": "03_社区_站位框", "x": 6150.0, "zoom": 0.21, "y": -600.0},
	{"n": "05_商业街_超市五金", "x": 15650.0, "zoom": 0.34, "y": -300.0},
	{"n": "06_仓储段_批发仓", "x": 21450.0, "zoom": 0.34, "y": -300.0},
	{"n": "07_道具_巷道", "x": 3300.0, "zoom": 0.6, "y": -220.0},
	{"n": "08_道具_路灯", "x": 4140.0, "zoom": 1.0, "y": -200.0},
	{"n": "09_道具_路灯远景", "x": 6400.0, "zoom": 0.5, "y": -260.0},
	{"n": "10_道具_垃圾桶", "x": 2900.0, "zoom": 1.0, "y": -190.0},
	{"n": "04_整条街", "x": 12547.0, "zoom": 0.038, "y": -656.0},
]

var _inst: Node2D
var _cam: Camera2D
var _player: Node2D
var _abs := ""


func _initialize() -> void:
	var scn := load(SCENE_PATH) as PackedScene
	if scn == null:
		print("[SNAP] FAIL load ", SCENE_PATH)
		quit(1)
		return
	_inst = scn.instantiate() as Node2D
	root.add_child(_inst)
	_cam = _inst.get_node_or_null("Camera2D") as Camera2D
	_player = _inst.get_node_or_null("Actors/Player") as Node2D
	var ui := _inst.get_node_or_null("UI") as CanvasLayer
	if ui != null:
		ui.visible = false
	_abs = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(_abs)
	_run()


func _run() -> void:
	await process_frame
	await process_frame
	for i in SHOTS.size():
		var s: Dictionary = SHOTS[i]
		if _player != null:
			_player.call("teleport_to", float(s.x))
		_cam.set("follow_enabled", false)
		_cam.limit_left = -1000000
		_cam.limit_right = 1000000
		_cam.limit_top = -1000000
		_cam.limit_bottom = 1000000
		_cam.zoom = Vector2(float(s.zoom), float(s.zoom))
		_cam.global_position = Vector2(float(s.x), float(s.y))
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		if img == null:
			print("[SNAP] FAIL null image")
			quit(1)
			return
		var fname := "%s.png" % String(s.n)
		var err := img.save_png(_abs + "/" + fname)
		print("[SNAP] %s %dx%d err=%d" % [fname, img.get_width(), img.get_height(), err])
	print("[SNAP] done")
	quit(0)
