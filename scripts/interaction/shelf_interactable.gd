class_name ShelfInteractable
extends Interactable
## CORE-001B · 货架热点
##
## 本轮只验证两件事：**E 查看** 的技术反馈链路，以及货架不会卡住水平行走。
## 明确不做：打开采购 / 物资界面、加载剧情、任何经济结算。
##
## 货架和门一样贴背景层：没有碰撞体，玩家从货架前面走过去不该有任何阻滞。

signal inspected(note: String, anchor: Vector2)

## 反馈文案。刻意写具体尺寸，方便对照 SCALE-001 的批准值，也顺带证明这确实是"查看"而不是"打开"
@export var note: String = "货架 · 四层 · 每层净高 37px（本轮只做查看反馈）"
## 可重复查看的次数上限，0 = 不限
@export var max_uses: int = 0

var use_count: int = 0


func _ready() -> void:
	super._ready()
	prompt_verb = "查看"


func can_interact(actor: Node2D) -> bool:
	if max_uses > 0 and use_count >= max_uses:
		return false
	return super.can_interact(actor)


func prompt_text() -> String:
	return "E 查看"


func _do_interact(_actor: Node2D) -> void:
	use_count += 1
	var anchor := prompt_anchor()
	print("[SHELF] 查看反馈（第 %d 次）：%s" % [use_count, note])
	inspected.emit(note, anchor)
