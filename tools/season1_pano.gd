extends SceneTree
## 第一季长街 · 整条横向全景（分段渲染，事后由 Python 拼接）
##
## 运行（必须有窗口）：
##   Godot_v4.7.2-stable_win64_console.exe --path <项目根> --resolution 1920x1080 --script res://tools/season1_pano.gd
##
## 输出：tests/screenshots/season1/pano/seg_00..NN.png（每帧 1920×1080，视野不重叠、首尾相接）

const SCENE_PATH := "res://scenes/world/season1_map.tscn"
const OUT_DIR := "res://tests/screenshots/season1/pano"

# 画面竖向要覆盖的世界区间：楼顶（-1500）到地面线下 120
const TOP_Y := -1500.0
const BOTTOM_Y := 120.0

var _inst: Node2D
var _cam: Camera2D
var _abs := ""


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1920, 1080)
	var scn := load(SCENE_PATH) as PackedScene
	if scn == null:
		print("[PANO] FAIL load")
		quit(1)
		return
	_inst = scn.instantiate() as Node2D
	root.add_child(_inst)
	_cam = _inst.get_node_or_null("Camera2D") as Camera2D
	var ui := _inst.get_node_or_null("UI") as CanvasLayer
	if ui != null:
		ui.visible = false
	_abs = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(_abs)
	_run()


func _run() -> void:
	await process_frame
	await process_frame

	var vw := float(root.get_visible_rect().size.x)
	var vh := float(root.get_visible_rect().size.y)
	var zoom := vh / (BOTTOM_Y - TOP_Y)          # 竖向正好覆盖
	var span := vw / zoom                          # 每帧覆盖的世界宽度
	var total := float(_inst.get("world_width"))
	var n := int(ceil(total / span))
	var cy := (TOP_Y + BOTTOM_Y) * 0.5

	print("[PANO] viewport=%dx%d zoom=%.4f span=%.0f total=%.0f frames=%d" % [int(vw), int(vh), zoom, span, total, n])

	for i in n:
		var cx := float(i) * span + span * 0.5
		_cam.set("follow_enabled", false)
		_cam.limit_left = -1000000
		_cam.limit_right = 1000000
		_cam.limit_top = -1000000
		_cam.limit_bottom = 1000000
		_cam.zoom = Vector2(zoom, zoom)
		_cam.global_position = Vector2(cx, cy)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		if img == null:
			print("[PANO] FAIL null image")
			quit(1)
			return
		var f := "seg_%02d.png" % i
		var err := img.save_png(_abs + "/" + f)
		print("[PANO] %s x=%.0f err=%d" % [f, cx, err])
	print("[PANO] done")
	quit(0)
