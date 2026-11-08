class_name Core001BOverlay
extends CoreOverlay
## CORE-001B 调试叠加层：在 CORE-001A 的「碰撞盒 / 可见框 / 脚底锚点」之上，
## 再加「热点范围 / 当前选中热点 / 购物车包围盒」。
##
## 只在开发实验场景使用，按 F3 开关；**关闭后必须一帧内清干净**，
## 所以这里覆写 `_process` 无条件重绘（父类只在开启时重绘，关掉会留下残影）。

const COL_HOT := Color(0.45, 0.72, 0.95)
const COL_HOT_ACTIVE := Color(0.98, 0.85, 0.35)
const COL_HOT_DEAD := Color(0.86, 0.56, 0.52)
const COL_CART := Color(0.42, 0.86, 0.78)

@export var cart_path: NodePath
@export var sensor_path: NodePath

var _cart: PushableCart
var _sensor: InteractionSensor


func _ready() -> void:
	super._ready()
	if cart_path != NodePath() and cart_path != NodePath(""):
		_cart = get_node_or_null(cart_path) as PushableCart
	if sensor_path != NodePath() and sensor_path != NodePath(""):
		_sensor = get_node_or_null(sensor_path) as InteractionSensor
	z_index = 60


func _process(_delta: float) -> void:
	# 无条件重绘：关掉叠加层时也要把上一帧的线擦掉
	queue_redraw()


func _draw() -> void:
	if not show_overlay:
		return
	super._draw()
	_draw_hotspots()
	_draw_cart()


func _draw_hotspots() -> void:
	if _sensor == null or get_tree() == null:
		return
	var active: Interactable = _sensor.current
	for n in get_tree().get_nodes_in_group(&"interactable"):
		var it := n as Interactable
		if it == null:
			continue
		# 装饰门也画出来，用灰虚线表示"存在但不可用"，便于截图说明"无提示≠无节点"
		var usable := it.can_interact(_sensor.actor)
		var c := COL_HOT if usable else COL_HOT_DEAD
		if it == active:
			c = COL_HOT_ACTIVE
		var cs := it.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if cs == null or not (cs.shape is RectangleShape2D):
			continue
		var size := (cs.shape as RectangleShape2D).size
		var r := Rect2(cs.global_position - size * 0.5, size)
		r = Rect2(to_local(r.position), r.size)
		draw_rect(r, Color(c.r, c.g, c.b, 0.08), true, -1.0, false)
		draw_rect(r, c, false, 1.0, false)
		var tag := "%s p%d%s" % [it.name, it.interact_priority, "" if usable else " 不可用"]
		# 贴地下沿，避免和人物画布说明、门标题抢同一行
		_plate_text(r.position.x + 2.0, r.position.y + r.size.y - 4.0, tag, 9, c)


func _draw_cart() -> void:
	if _cart == null:
		return
	var r: Rect2 = _cart.body_rect()
	r = Rect2(to_local(r.position), r.size)
	draw_rect(r, Color(COL_CART.r, COL_CART.g, COL_CART.b, 0.10), true, -1.0, false)
	draw_rect(r, COL_CART, false, 1.0, false)
	# 组合体的相对侧位：绑定期间必须恒定，画出来就能一眼看出有没有翻面
	if _cart.state == PushableCart.STATE_PUSHING and _cart.player != null:
		var cy := r.position.y + r.size.y
		var px := to_local(Vector2(_cart.player.global_position.x, cy))
		var cx := to_local(Vector2(_cart.global_position.x, cy))
		draw_line(Vector2(cx.x, cy), px, COL_CART, 1.0)
		_plate_text((cx.x + px.x) * 0.5 - 26.0, cy + 12.0,
			"间距 %d  side=%+d" % [int(absf(px.x - cx.x)), _cart.side], 9, COL_CART)
	_plate_text(r.position.x + 2.0, r.position.y - 3.0,
		"购物车 %s v=%.0f" % [_cart.state, _cart.last_speed], 9, COL_CART)
