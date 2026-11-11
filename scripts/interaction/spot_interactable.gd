class_name SpotInteractable
extends Interactable
## TASK-SCENE-002 · 场景地标与信息点交互组件（白盒浏览与空间验证用）
##
## 用途：
##   - 为公告栏、物业门岗信息交换点、公交站牌、临时管制路口、清单桌、设备底座、
##     超市临时预约窗口、批发仓交接台、物流取货口等非门类交互点提供「E 查看」反馈。
##   - 仅输出位置与场景结构核对反馈，不提前实现剧情分支、经济结算或库存逻辑。

signal spot_inspected(title: String, detail: String, anchor: Vector2)

@export var spot_title: String = "交互点"
@export var spot_detail: String = "场景白盒交互位（正式玩法未启用）"

var use_count: int = 0


func _ready() -> void:
	super._ready()
	single_use = false
	if interact_priority == 0:
		interact_priority = 6
	if prompt_verb == "":
		prompt_verb = "查看"


func prompt_text() -> String:
	if prompt_subject != "":
		return "E %s %s" % [prompt_verb, prompt_subject]
	if spot_title != "":
		return "E %s %s" % [prompt_verb, spot_title]
	return "E " + prompt_verb


func _do_interact(_actor: Node2D) -> void:
	use_count += 1
	var anchor := prompt_anchor()
	print("[SPOT] 查看（第 %d 次）%s：%s" % [use_count, spot_title, spot_detail])
	spot_inspected.emit(spot_title, spot_detail, anchor)
