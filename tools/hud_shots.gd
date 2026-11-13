extends SceneTree
## 正式 HUD 截图工具（TASK-UI-009）
##
## 在真实第一季街道里跑一遍，产出：
##   ui009_game.png          960×540 整屏（HUD + 街景，无提示）
##   ui009_prompt.png        站在 A/B 门口，屏幕空间交互提示
##   ui009_tasks_open.png    今日清单展开
##   ui009_tasks_closed.png  今日清单收起
##   ui009_notext.png        去文字（只看面板 / 图标 / 进度条）
##
##   Godot_v4.7.2-stable_win64_console.exe --path <项目根> --script res://tools/hud_shots.gd
##
## 不能用 --headless：headless 渲染器截出来是空白图。

const STREET := "res://scenes/world/season1_map.tscn"
const SHOT_DIR := "res://tests/screenshots"
## A/B 门热点中心（热点相对门框右偏，属 TASK-UI-001 记录的既有问题）
const DOOR_A_X := 2377.0


func _initialize() -> void:
	_run()


func _wait(n: int = 6) -> void:
	for i in n:
		await process_frame
	for i in n:
		await physics_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	var err := root.get_texture().get_image().save_png("%s/%s" % [SHOT_DIR, name])
	print("[HUD-SHOT] %s err=%d" % [name, err])


func _hide_text(node: Node) -> void:
	if node is Label:
		(node as Label).visible = false
	if String(node.name).ends_with("Strike"):
		(node as CanvasItem).visible = false
	for c in node.get_children():
		_hide_text(c)


func _run() -> void:
	await _wait(3)
	change_scene_to_file(STREET)
	await _wait(10)

	var scene := current_scene
	var hud := scene.get_node_or_null("HUD")
	if hud == null:
		print("[HUD-SHOT] FAIL 没有 HUD")
		quit(1)
		return
	var player := scene.get_node_or_null("Actors/Player")
	var root_ctl := hud.get_node("Root") as Control

	# 1. 整屏
	await _shot("ui009_game.png")

	# 2. 走到 A/B 门口 → 交互提示
	player.call("teleport_to", DOOR_A_X)
	await _wait(10)
	await _shot("ui009_prompt.png")

	# 3. 清单收起 / 展开
	hud.call("set_tasks_collapsed", true, false)
	await _wait(2)
	await _shot("ui009_tasks_closed.png")
	hud.call("set_tasks_collapsed", false, false)
	await _wait(2)
	await _shot("ui009_tasks_open.png")

	# 4. 去文字
	_hide_text(root_ctl)
	await _wait(2)
	await _shot("ui009_notext.png")

	print("[HUD-SHOT] 完成")
	quit(0)
