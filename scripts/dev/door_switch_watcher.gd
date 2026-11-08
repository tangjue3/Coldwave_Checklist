class_name DoorSwitchWatcher
extends Node
## CORE-001B · 门切换测试观察者
##
## 为什么需要它：门按 E 之后会用 SceneRouter 切场景，**发起切换的那个场景会被销毁**，
## 所以测试协程活不到"切换完成"那一刻。把观察者挂在 `get_tree().root` 上就不受场景切换影响。
##
## 它做三件事：等目标场景就位 → 截一张 960×540 原图 → 核对 location 与切换次数后退出。

var target_path := ""
var expect_location := ""
var shot_name := ""

var _before := 0


func start(tp: String, loc: StringName, shot: String) -> void:
	target_path = tp
	expect_location = String(loc)
	shot_name = shot
	_before = SceneRouter.change_count
	_run()


func _run() -> void:
	for i in 300:
		await get_tree().process_frame
		var cur := get_tree().current_scene
		if cur != null and cur.scene_file_path == target_path:
			# 等场景把 UI 建好、画一帧再截图
			for k in 16:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var err := _capture()
			var delta := SceneRouter.change_count - _before
			var loc := String(GameState.location)
			print("[DOOR-TEST] 已切换到 %s  location=%s  切换次数增量=%d  截图 err=%d" % [
				target_path, loc, delta, err])
			var ok := delta == 1 and loc == expect_location and err == OK
			print("[DOOR-TEST] %s（期望 增量=1 / location=%s）" % [
				"通过" if ok else "失败", expect_location])
			print("========================================")
			get_tree().quit(0 if ok else 1)
			return
	print("[DOOR-TEST] 失败：等待超时，未切到 %s" % target_path)
	get_tree().quit(1)


func _capture() -> Error:
	var dir := "res://tests/screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	return get_viewport().get_texture().get_image().save_png("%s/%s" % [dir, shot_name])
