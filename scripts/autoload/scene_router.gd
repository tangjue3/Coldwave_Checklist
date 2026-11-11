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
##   --dev-scene=menu|supermarket|shelter|smoke|scale|core001a|core001b|art003|art004|video|vid001|vid002
##   --scene-tour          依次切换 菜单→超市→安全屋→菜单 并逐场景截图
##   --shot=name.png       指定截图文件名（smoke / scale 场景自己截图）
##   --quit                完成后退出
##
## `scale` 是 SCALE-001 的尺寸验证场景，`core001a` / `core001b` 是角色与交互实验场景，
## `art003` 是 ART-INTEGRATE-003 的美术实机验证场景，
## `art004` 是 ART-INTEGRATE-004 的购物车分层实机验证场景（两组角色像素断言已按
## ART-RESET-001 退役）。`video` 读视频候选帧做引擎体检，
## `vid001` 是 VIDEO-INTEGRATE-001 普通行走候选动画的独立测试场景，
## `vid002` 是 VIDEO-INTEGRATE-002 推车候选动画的独立测试场景
## （真实 PlayerController + 真实 PushableCart，跑完整状态链）。
## 以上**只走命令行**，不挂到主菜单，避免把测试入口暴露成正式游戏功能。
## Web 版没有命令行，改用 URL 参数：`?dev=core001b&state=door`（同样是开发入口）。

const PATHS: Dictionary = {
	&"menu": "res://scenes/menu/main_menu.tscn",
	&"outdoor_street": "res://scenes/world/outdoor_street.tscn",
	&"supermarket": "res://scenes/world/supermarket.tscn",
	&"shelter": "res://scenes/world/shelter.tscn",
	&"equipment_room": "res://scenes/world/equipment_room.tscn",
	&"apartment_hallway": "res://scenes/world/apartment_hallway.tscn",
	&"past_corridor": "res://scenes/world/past_corridor.tscn",
	&"zhao_home": "res://scenes/world/zhao_home.tscn",
	&"repair_corner": "res://scenes/world/repair_corner.tscn",
	&"convenience_store": "res://scenes/world/convenience_store.tscn",
	&"pharmacy": "res://scenes/world/pharmacy.tscn",
	&"hardware_store": "res://scenes/world/hardware_store.tscn",
	&"wholesale_warehouse": "res://scenes/world/wholesale_warehouse.tscn",
	&"logistics_hub": "res://scenes/world/logistics_hub.tscn",
	&"smoke": "res://scenes/dev/test_scene.tscn",
	&"scale": "res://scenes/dev/scale_test.tscn",
	&"core001a": "res://scenes/dev/core_001a.tscn",
	&"core001b": "res://scenes/dev/core_001b.tscn",
	&"art003": "res://scenes/dev/art003_verify.tscn",
	&"art004": "res://scenes/dev/art004_verify.tscn",
	&"video": "res://scenes/dev/video_preview.tscn",
	&"vid001": "res://scenes/dev/vid001_verify.tscn",
	&"vid002": "res://scenes/dev/vid002_verify.tscn",
}

## 自带检查 / 截图 / 退出逻辑的开发场景：路由不再代为截图，避免重复或抢先退出
const SELF_MANAGED: Array[StringName] = [&"smoke", &"scale", &"core001a", &"core001b",
	&"art003", &"art004", &"video", &"vid001", &"vid002"]

const SHOT_DIR := "res://tests/screenshots"

## 本次启动解析出的开发参数（命令行 + Web URL）。开发场景通过它读取 --core-state 之类的值，
## 因为 Web 端没有命令行，参数只能由本单例从 query string 注入。
var dev_args: Dictionary = {}

## 跨场景门切换时的目标落点 ID（TASK-SCENE-002：进入室内/返回室外时定位到对应门旁）
var pending_spawn_id: StringName = &""

## 成功切换次数。CORE-001B 用它断言「连按 E 不会重复加载」。
var change_count: int = 0

var _busy: bool = false


func _ready() -> void:
	var args := _parse_args()
	# Web 版没有命令行参数：用 ?dev=<场景key>&state=<检查点> 打开开发场景
	if not args.has("dev_scene"):
		var q := _web_query()
		if q.has("dev") and PATHS.has(StringName(q["dev"])):
			args["dev_scene"] = q["dev"]
			# 各开发场景的检查点参数名不同：core001b 用 core_state，art004 用 art004_state
			var dev_key := StringName(q["dev"])
			if q.has("state"):
				if dev_key == &"art003":
					args["art003_state"] = q["state"]
				elif dev_key == &"art004":
					args["art004_state"] = q["state"]
				else:
					args["core_state"] = q["state"]
			# art004 专用：?load=half|full 切装载状态（纯视觉，不涉及库存）
			if dev_key == &"art004" and q.has("load"):
				args["art004_load"] = q["load"]
			if q.has("tour"):
				args["core_tour"] = true

	dev_args = args

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


## 只在 Web 导出里有意义；其它平台直接返回空字典
func _web_query() -> Dictionary:
	var out := {}
	if not OS.has_feature("web"):
		return out
	var search: String = str(JavaScriptBridge.eval("window.location.search", true))
	if search.begins_with("?"):
		search = search.substr(1)
	for pair in search.split("&", false):
		var kv := pair.split("=", true, 1)
		if kv.size() == 2 and String(kv[0]) != "":
			out[String(kv[0])] = String(kv[1])
	return out


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
		change_count += 1
		GameState.set_location(key)
		# 新载入的场景拿不到启动时挂在 root 上的 Theme（Web 端会整页变方块），换完必须重挂
		UiTheme.reapply_after_scene_change()
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

	# smoke / scale 场景及 scene002 巡检/测试自带检查、截图与退出逻辑，避免重复截图 / 抢先退出
	if SELF_MANAGED.has(key) or args.has("scene002_tour") or args.has("scene002_test"):
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
