class_name Art004DoorWatcher
extends Node
## ART-INTEGRATE-004 · 门「进入 / 离开」回归观察者
##
## 为什么挂在 root 上：按 E 之后 SceneRouter 会切场景，**发起切换的那个场景会被销毁**，
## 写在场景里的协程活不到"切换完成"那一刻。挂在 get_tree().root 上就不受场景切换影响
## （与 CORE-001B 的 DoorSwitchWatcher 同一思路）。
##
## 它做四件事：
##   1) 等 shelter 场景就位 → 核对 location 与切换次数；
##   2) 再切回 art004 场景 → 核对「离开门」也正常；
##   3) 确认回到的 art004 场景里购物车热点还在、还能绑定（分层改造没把车弄坏）；
##   4) 全程打印 [DOOR-TEST] 行，供 Web / 桌面端断言。

const ART004_PATH := "res://scenes/dev/art004_verify.tscn"
const SHELTER_PATH := "res://scenes/world/shelter.tscn"

var _before_enter: int = 0
var _before_leave: int = 0
var _failures: int = 0


func start() -> void:
	_before_enter = SceneRouter.change_count
	_run()


func _ok(label: String, cond: bool, extra: String = "") -> void:
	if not cond:
		_failures += 1
	print("[DOOR-TEST] %s %s%s" % ["通过" if cond else "失败", label, ("  ← " + extra) if extra != "" else ""])


func _run() -> void:
	print("")
	print("========== ART-INTEGRATE-004 门进出回归 ==========")

	# ---- 1) 进入 shelter
	for i in 300:
		await get_tree().process_frame
		var cur := get_tree().current_scene
		if cur != null and cur.scene_file_path == SHELTER_PATH:
			break
	var cur := get_tree().current_scene
	var entered := cur != null and cur.scene_file_path == SHELTER_PATH
	var delta_in := SceneRouter.change_count - _before_enter
	_ok("按 E 进入 shelter（场景=%s location=%s 切换增量=%d）" % [
		cur.scene_file_path if cur else "null", String(GameState.location), delta_in],
		entered and delta_in == 1 and GameState.location == &"shelter")

	# ---- 2) 离开：切回 art004
	_before_leave = SceneRouter.change_count
	var err := SceneRouter.goto(&"art004")
	for i in 300:
		await get_tree().process_frame
		var back := get_tree().current_scene
		if back != null and back.scene_file_path == ART004_PATH:
			break
	cur = get_tree().current_scene
	var returned := cur != null and cur.scene_file_path == ART004_PATH
	var delta_out := SceneRouter.change_count - _before_leave
	_ok("从 shelter 离开、回到 art004（err=%d 场景=%s 切换增量=%d）" % [
		err, cur.scene_file_path if cur else "null", delta_out],
		returned and delta_out == 1)

	# ---- 3) 回到的 art004 场景里购物车仍然完好（分层改造没把交互弄坏）
	if returned:
		await get_tree().process_frame
		var cart := cur.get_node_or_null("Cart") as PushableCart
		var has_hotspot := cart != null and cart.hotspot != null
		_ok("回到 art004 后购物车节点与热点仍在", has_hotspot)
		if has_hotspot:
			var ok_prompt := cart.hotspot.prompt_text() == "E 推购物车"
			_ok("购物车热点提示仍为「E 推购物车」（实际 %s）" % cart.hotspot.prompt_text(), ok_prompt)
			var ok_variant := cart.art_variant == PushableCart.ART_VARIANT_R03
			_ok("购物车视觉版本仍为 r03 分层（实际 %s）" % String(cart.art_variant), ok_variant)
			var ok_layers := cart.front_layer_visible()
			_ok("近侧篮网层常驻可见（Front 始终压在人物之前）", ok_layers)

	print("[DOOR-TEST] 汇总：%s（失败 %d 项）" % [
		"全部通过" if _failures == 0 else "存在失败项", _failures])
	print("==============================================")
	get_tree().quit(0 if _failures == 0 else 1)
