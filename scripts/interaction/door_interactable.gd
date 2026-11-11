class_name DoorInteractable
extends Interactable
## CORE-001B · 门热点
##
## 门在严格侧视里是**墙面元素**：玩家从门前走过，不在 x 方向"穿过门洞"。
## 所以门不是碰撞缺口，而是背景图 + 一个 Area2D 热点，按 E 走 SceneRouter 切场景。
## 这条结论来自 CORE-001A 的 A/B 实测（门框当实体时人物停在 x=286，永远进不去）。
##
## 三种门共用这一个类：
##   - 有效门：interactive = true + target_scene 有效 → 显示「E 进入」，按 E 切场景；
##   - 装饰门：interactive = false      → 不显示提示、按 E 无任何作用（`accepts()` 直接返回 false）；
##   - 未接线的门：target_scene 为空     → 同装饰门处理，避免误触发一次空跳转。

signal transition_requested(target_scene: StringName)

## SceneRouter 登记过的场景 key（shelter / supermarket / menu …），空表示未接线
@export var target_scene: StringName = &""
## 目标场景内的落点/出生点标识（TASK-SCENE-002：实现室内外门一一对应返回）
@export var target_spawn_id: StringName = &""
## false = 装饰门：只作为背景，不参与交互
@export var interactive: bool = true
## 日志用的人类可读名，不影响逻辑
@export var door_label: String = ""

## 最近一次 goto 返回的错误码，供测试读取
var last_error: int = OK


func _ready() -> void:
	super._ready()
	prompt_verb = "进入"
	# 门天然一次性：切走之后场景就销毁了，但同一帧连按两次必须在本地挡掉
	single_use = true


func accepts(actor: Node2D) -> bool:
	if not interactive:
		return false
	if target_scene == &"":
		return false
	return super.accepts(actor)


func prompt_text() -> String:
	if prompt_subject == "":
		return "E 进入"
	return "E 进入 %s" % prompt_subject


func target_path() -> String:
	if not SceneRouter.PATHS.has(target_scene):
		return ""
	return String(SceneRouter.PATHS[target_scene])


func _do_interact(actor: Node2D) -> void:
	# 先关掉自己，再切场景：SceneRouter.goto 是延迟切换，同一帧再按一次 E 会二次触发
	enabled = false
	if target_spawn_id != &"":
		SceneRouter.pending_spawn_id = target_spawn_id
	print("[DOOR] 触发 %s → %s（%s, spawn=%s）actor_x=%.0f" % [
		door_label if door_label != "" else String(name), target_scene,
		target_path(), target_spawn_id, actor.global_position.x])
	transition_requested.emit(target_scene)
	last_error = SceneRouter.goto(target_scene)
	print("[DOOR] goto err=%d change_count=%d" % [last_error, SceneRouter.change_count])
