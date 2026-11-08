class_name Art003Overlay
extends Node2D
## ART-INTEGRATE-003 · 开发调试叠加层（F3 开关）
##
## 只画量测用的框与线，**不参与任何逻辑**。正式截图一律用 `show_overlay = false` 的版本，
## 这样总监看到的画面就是玩家会看到的画面。
##
## 绘制委托给宿主：draw_* 只能在"正在 _draw 的 CanvasItem"上调用，而本节点此刻正在 _draw，
## 所以把 self 传回宿主是合法的。

var host: Node2D
## 默认关闭：截图默认就是玩家会看到的画面，按 F3 才显示量测框
var show_overlay := false


func _process(_delta: float) -> void:
	visible = show_overlay
	if show_overlay:
		queue_redraw()


func _draw() -> void:
	if not show_overlay or host == null:
		return
	host.debug_draw(self)
