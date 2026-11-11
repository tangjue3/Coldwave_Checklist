class_name StairInteractable
extends Interactable
## TASK-SCENE-002 · 楼层楼梯交互点（同一建筑内真实上下楼层切换）
##
## 设计说明：
##   - 第一季外婆旧两层小楼（A 一层 / B 二层）与梧桐里居民楼公共楼道（G 1F / 2F）
##     均具有真实的上下楼层空间关系，二层严格位于一层正上方（1F y=416，2F y=128），
##     不将两个楼层强行挤在同一条水平地面线上。
##   - 玩家在楼梯口按 E 后，沿垂直对齐的楼梯坐标切换所在楼层（更新 ground_y 与位置），
##     FollowCamera 随之平滑上移或下移至目标楼层。

signal stair_used(from_floor: int, to_floor: int, target_x: float, target_ground_y: float)

@export var stair_label: String = "楼梯"
@export var from_floor: int = 1
@export var to_floor: int = 2
@export var target_x: float = 0.0
@export var target_ground_y: float = 128.0


func _ready() -> void:
	super._ready()
	single_use = false
	interact_priority = 12
	prompt_verb = "上二层" if to_floor > from_floor else "下一层"


func prompt_text() -> String:
	var action := ("上 %dF" % to_floor) if to_floor > from_floor else ("下 %dF" % to_floor)
	if stair_label == "":
		return "E " + action
	return "E %s（%s）" % [action, stair_label]


func _do_interact(actor: Node2D) -> void:
	var p := actor as PlayerController
	if p != null:
		p.ground_y = target_ground_y
		p.teleport_to(target_x)
	print("[STAIR] %s：%dF -> %dF @ x=%.0f, y=%.0f" % [
		stair_label, from_floor, to_floor, target_x, target_ground_y
	])
	stair_used.emit(from_floor, to_floor, target_x, target_ground_y)
