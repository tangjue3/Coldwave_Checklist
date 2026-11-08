class_name Interactable
extends Area2D
## CORE-001B · 轻量交互契约（门 / 货架 / 购物车共用的基类）
##
## 设计底线：**只做一件事**——「玩家站在这个范围内，按 E 会发生什么」。
## 不引入交互状态机、不引入条件系统、不引入对话框架；需要特殊行为时覆写 `_do_interact()`。
##
## 约定：
##   - 热点是 Area2D，`collision_layer = 0`（自己不被检测），`collision_mask = 1`（只关心物理体）；
##   - 玩家是 CharacterBody2D（layer 1），所以 `overlaps_body(player)` 就是"在范围内"；
##   - 门/货架贴在背景层，热点本身**不产生任何物理阻挡**，玩家照常从前面走过；
##   - 同一时刻只允许触发一个热点，选择逻辑在 InteractionSensor，不在这里。

signal interacted(actor: Node2D)

## 提示动词，最终显示为「E <动词> [主语]」，例如「E 进入」「E 查看」「E 推购物车」
@export var prompt_verb: String = "查看"
## 可选主语，留空则只显示动词
@export var prompt_subject: String = ""
## 重叠时的优先级，数值大的优先；相同优先级再按距离、最后按节点顺序稳定选择
@export var interact_priority: int = 0
## 关掉后既不出提示也不能触发（装饰门就用这个）
@export var enabled: bool = true
## 触发一次后自动失效（门用这个，防连按重复加载）
@export var single_use: bool = false
## 提示框再往上抬多少像素。购物车只有 96 高，不抬就会压在人脸上
@export var prompt_lift: float = 0.0

var _consumed := false


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1
	add_to_group(&"interactable")


## 子类可以进一步限制"这个 actor 能不能用"，例如装饰门恒为 false
func accepts(actor: Node2D) -> bool:
	return actor != null


func can_interact(actor: Node2D) -> bool:
	if not enabled:
		return false
	if single_use and _consumed:
		return false
	return accepts(actor)


func prompt_text() -> String:
	if prompt_subject == "":
		return "E " + prompt_verb
	return "E %s %s" % [prompt_verb, prompt_subject]


## 提示框挂在哪：默认取热点矩形上边中点，子类可覆写
func prompt_anchor() -> Vector2:
	var cs := _shape_node()
	if cs == null:
		return global_position + Vector2(0.0, -prompt_lift)
	return cs.global_position + Vector2(0.0, -rect_size().y * 0.5 - prompt_lift)


func rect_size() -> Vector2:
	var cs := _shape_node()
	if cs != null and cs.shape is RectangleShape2D:
		return (cs.shape as RectangleShape2D).size
	return Vector2.ZERO


## 统一的触发入口：先标记已用，再执行，最后广播。
## 顺序很关键——门在 `_do_interact` 里会切场景，标记必须在那之前完成，否则连按会重复加载。
func interact(actor: Node2D) -> void:
	if not can_interact(actor):
		return
	_consumed = true
	_do_interact(actor)
	interacted.emit(actor)


## 子类实现具体行为
func _do_interact(_actor: Node2D) -> void:
	pass


func _shape_node() -> CollisionShape2D:
	for c in get_children():
		var cs := c as CollisionShape2D
		if cs != null:
			return cs
	return null
