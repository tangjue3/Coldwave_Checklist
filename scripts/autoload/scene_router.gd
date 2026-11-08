extends Node
## 场景路由 + 开发测试入口（PREP-003，工程级，不含玩法逻辑）
##
## 职责：
##  1) 提供主菜单 / 超市空场景 / 安全屋空场景 / 启动自检之间的安全切换；
##  2) 切换时同步 GameState.location；
##  3) 提供仅用于验证的命令行入口（--dev-scene / --scene-tour），
##     让自检场景在正式入口改为主菜单后仍可独立运行与截图。
##
## 命令行参数写在 `--` 之后：
##   --dev-scene=menu|supermarket|shelter|smoke|scale
##   --scene-tour          依次切换 菜单→超市→安全屋→菜单 并逐场景截图
##   --shot=name.png       指定截图文件名（smoke / scale 场景自己截图）
##   --quit                完成后退出
##
## `scale` 是 SCALE-001 的尺寸验证场景，**只走命令行**，不挂到主菜单，
## 避免把测试入口暴露成正式游戏功能。

const PATHS: Dictionary = {
	&"menu": "res://scenes/menu/main_menu.tscn",
	&"supermarket": "res://scenes/world/supermarket.tscn",
	&"shelter": "res://scenes/world/shelter.tscn",
	&"smoke": "res://scenes/dev/test_scene.tscn",
	&"scale": "res://scenes/dev/scale_test.tscn",
}

## 自带检查 / 截图 / 退出逻辑的开发场景：路由不再代为截图，避免重复或抢先退出
const SELF_MANAGED: Array[StringName] = [&"smoke", &"scale"]

const SHOT_DIR := "res://tests/screenshots"

var _busy: bool = false


func _ready() -> void:
	var args := _parse_args()
	if args.has("dev_scene"):
		var key := StringName(String(args["dev_scene"]))
		if PATHS.has(key):
			call_deferred("_start_dev_scene", key, args)
		else:
			push_error("[SceneRouter] 未知 --dev-scene: %s" % key)
	elif args.has("scene_tour"):
		call_deferred("_run_tour", args)
	elif args.has("shot") or args.has("quit"):
		# 通用开发参数：截当前（默认主菜单）场景 / 退出。
		# 没有这个分支时，主入口改成菜单后 `--quit` 会无人处理导致进程常驻。
		call_deferred("_start_default_scene", args)


func _parse_args() -> Dictionary:
	var out := {}
	for raw in OS.get_cmdline_user_args():
		var arg: String = raw
		if not arg.begins_with("--"):
			continue
		var kv := arg.substr(2).split("=", true, 1)
		out[kv[0].replace("-", "_")] = kv[1] if kv.size() > 1 else true
	return out


## 唯一允许的场景切换入口。路径写死在 PATHS，禁止外部传任意路径。
func goto(key: StringName) -> Error:
	if not PATHS.has(key):
		push_error("[SceneRouter] 未登记的场景 key: %s" % key)
		return ERR_INVALID_PARAMETER
	if _busy:
		return ERR_BUSY
	_busy = true
	var err := get_tree().change_scene_to_file(String(PATHS[key]))
	if err == OK:
		GameState.set_location(key)
	else:
		push_error("[SceneRouter] 切换失败 %s err=%d" % [key, err])
	_busy = false
	return err


func goto_main_menu() -> Error:
	return goto(&"menu")


func goto_smoke() -> Error:
	return goto(&"smoke")


func current_scene_path() -> String:
	var scene := get_tree().current_scene
	return scene.scene_file_path if scene else ""


# ------------------------------------------------------------ 开发测试入口

func _start_dev_scene(key: StringName, args: Dictionary) -> void:
	goto(key)
	for i in 5:
		await get_tree().process_frame

	# smoke / scale 场景自带检查、截图与退出逻辑，避免重复截图 / 抢先退出
	if SELF_MANAGED.has(key):
		return

	await RenderingServer.frame_post_draw
	var shot := String(args.get("shot", ""))
	if shot != "":
		_capture(shot)
	print("[DEV] active_scene=", current_scene_path(), " location=", GameState.location)
	if args.has("quit"):
		get_tree().quit(0)


func _start_default_scene(args: Dictionary) -> void:
	for i in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var shot := String(args.get("shot", ""))
	if shot != "":
		_capture(shot)
	print("[DEV] active_scene=", current_scene_path(), " location=", GameState.location)
	if args.has("quit"):
		get_tree().quit(0)


func _run_tour(args: Dictionary) -> void:
	var sequence: Array[StringName] = [&"menu", &"supermarket", &"shelter", &"menu"]
	var captured := {}
	var failures := 0
	for key in sequence:
		var err := goto(key)
		for i in 6:
			await get_tree().process_frame
		var actual := current_scene_path()
		var ok: bool = err == OK and actual == String(PATHS[key]) and GameState.location == key
		if not ok:
			failures += 1
		print("[TOUR] %-12s err=%d scene=%s location=%s ok=%s" % [
			key, err, actual, GameState.location, "YES" if ok else "NO"
		])
		if not captured.has(key):
			await RenderingServer.frame_post_draw
			var name := "prep003_%s.png" % key
			_capture(name)
			captured[key] = true
	print("[TOUR] 切换 %d 次，失败 %d 次，截图 %d 张" % [sequence.size(), failures, captured.size()])
	if args.has("quit"):
		get_tree().quit(0 if failures == 0 else 1)


func _capture(filename: String) -> void:
	var absolute_dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var path := "%s/%s" % [SHOT_DIR, filename]
	var err := get_viewport().get_texture().get_image().save_png(path)
	print("[DEV] screenshot ", ProjectSettings.globalize_path(path), " err=", err)
