class_name PushableCart
extends Node2D
## CORE-001B · 可推购物车（PARKED / PUSHING 两态骨架）
##
## 三条硬约束，来自 CORE-001A 的实测结论：
##   1) **停放的车不是硬墙**。CORE-001A 里车有 StaticBody2D，人物停在 x=1030 永远过不去。
##      本实现里车**没有任何物理体**，停放时玩家直接从它身上走过去，只用前后两层视觉
##      做"侧身绕过"的假象——世界坐标里的行走线一条都没变。
##   2) **绑定后是一套刚体组合**。玩家与车的相对侧位在绑定瞬间确定，之后**永不翻面**；
##      按反方向键是"拉着车后退"，不是"车瞬移到另一侧"。
##   3) **撞墙整组停住，但仍可解绑**。用 1px 子步 + 矩形 shape 查询逐步试探，
##      停下的位置一定是"车和人都没和墙体重叠"的位置，不存在穿墙或把人挤到另一侧。
##
## 明确不做：容量、结算、装载、物资 UI、库存持久化（属 CORE-002 及以后）。

signal state_changed(state: StringName)
## 车实际移动了一帧时发出，供 HUD / 测试读取速度
signal moved(dx: float, speed: float)

const STATE_PARKED := &"parked"
const STATE_PUSHING := &"pushing"

## 已批准尺寸：车长 96、车高 96（SCALE-001 批准版）
@export var cart_width: float = 96.0
@export var cart_height: float = 96.0
@export var ground_y: float = 0.0
## 推行速度待调参数（不是美术尺寸）：从 80 起测，普通行走仍是 100
@export var push_speed: float = 80.0
## 反向"拉着走"速度：明显低于推速，手感上区分"推"和"拖"
@export var pull_speed: float = 40.0
## 人物脚底原点到车中心的水平距离；初测 80，必须靠原生截图确认无穿插
@export var side_offset: float = 80.0
@export var cart_tint: Color = Color(0.70, 0.76, 0.82)
## 场景横向边界（写死世界边界，避免车被推出场景）
@export var world_left: float = -4096.0
@export var world_right: float = 4096.0

var state: StringName = STATE_PARKED
var player: PlayerController
## 绑定瞬间确定的相对侧位：+1 = 玩家在车右侧，-1 = 玩家在车左侧。绑定期间恒定不变。
var side: int = -1

## 诊断数据
var last_speed: float = 0.0
var last_dir: int = 0
var blocks_at_wall: int = 0
var hotspot: Interactable

var _part_back: Node2D
var _part_front: Node2D


func _ready() -> void:
	global_position.y = ground_y
	_build_visual()
	_build_hotspot()


# ------------------------------------------------------------------ 视觉

## 前后两层：Back 在玩家后面（z=0，先于玩家加入场景树 → 画在人之前），
## Front 在玩家前面（z=1）。玩家从车上走过时，腿被前景护栏挡住、身体在篮体之前，
## 读起来就是"站在车后面/侧身绕过"。
## 注意：这纯属绘制层级，**不参与任何碰撞判定**；用 z<0 会被场景背景盖住，所以不用负值。
func _build_visual() -> void:
	var back := CartPart.new()
	back.name = "Back"
	back.cart = self
	back.front = false
	back.z_as_relative = false
	back.z_index = 0
	add_child(back)
	_part_back = back

	var front := CartPart.new()
	front.name = "Front"
	front.cart = self
	front.front = true
	front.z_as_relative = false
	front.z_index = 1
	add_child(front)
	_part_front = front


func _build_hotspot() -> void:
	hotspot = Interactable.new()
	hotspot.name = "CartHotspot"
	hotspot.prompt_verb = "推购物车"
	hotspot.interact_priority = 20          # 高于货架(5)与门(10)：车压在货架前面时必须是车
	hotspot.prompt_lift = 76.0              # 车只有 96 高，提示抬到人物头顶之上一点，又不至于离车太远
	hotspot.interacted.connect(_on_hotspot_interacted)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	# 热点要够宽：绑定后玩家在 ±80，必须仍然压得住，否则无法按 E 停车
	r.size = Vector2(cart_width + 80.0, cart_height + 8.0)
	cs.shape = r
	cs.position = Vector2(0.0, -cart_height * 0.5)
	hotspot.add_child(cs)
	add_child(hotspot)


func _on_hotspot_interacted(actor: Node2D) -> void:
	var p := actor as PlayerController
	if p == null:
		return
	if state == STATE_PARKED:
		bind(p)
	else:
		unbind()


## 侧视里把手应该在"推车的人"这一侧。车本身没有朝向状态，只有绘制会翻转，
## 这样按反方向键（拉着走）时车不会突然翻面。
func _set_visual_flip(flipped: bool) -> void:
	var sx := -1.0 if flipped else 1.0
	if _part_back != null:
		_part_back.scale.x = sx
	if _part_front != null:
		_part_front.scale.x = sx


func _refresh_hotspot_prompt() -> void:
	if hotspot == null:
		return
	hotspot.prompt_verb = "停车" if state == STATE_PUSHING else "推购物车"


# ------------------------------------------------------------------ 状态切换

## 绑定：确定侧位 → 接管玩家移动 → 对齐间距
func bind(p: PlayerController) -> bool:
	if state == STATE_PUSHING or p == null:
		return false
	# 玩家正好站在车心时按朝向兜底，避免出现 side=0
	var dx := p.global_position.x - global_position.x
	side = 1 if dx > 0.0 else (-1 if dx < 0.0 else (p.facing))
	if side == 0:
		side = 1

	var before := p.global_position.x
	player = p
	state = STATE_PUSHING
	p.set_external_control(true)
	p.global_position.x = global_position.x + float(side) * side_offset
	p.velocity = Vector2.ZERO
	p.set_facing(-side)
	_set_visual_flip(side < 0)   # 把手朝向推车的人
	_refresh_hotspot_prompt()
	print("[CART] bind side=%+d  玩家 %.0f → %.0f（脚底原点距车心 %.0f）  状态=%s" % [
		side, before, p.global_position.x, side_offset, state])
	state_changed.emit(state)
	return true


## 停车：车留在当前位置，玩家恢复正常移动，从任意一侧都能走开
func unbind() -> void:
	if state != STATE_PUSHING:
		return
	var parked_x := global_position.x
	var p := player
	state = STATE_PARKED
	player = null
	_refresh_hotspot_prompt()
	if p != null:
		p.set_external_control(false)
		p.velocity = Vector2.ZERO
		# 解绑后不再对齐：玩家就站在当前位置，能往任意方向走
		print("[CART] unbind 停车于 x=%.0f，玩家 x=%.0f（可自由走开）" % [parked_x, p.global_position.x])
	state_changed.emit(state)


## 测试 / 关卡摆放用
func place_at(x: float) -> void:
	if state == STATE_PUSHING:
		unbind()
	global_position.x = x
	global_position.y = ground_y
	last_speed = 0.0


# ------------------------------------------------------------------ 推行

func _physics_process(delta: float) -> void:
	if state != STATE_PUSHING or player == null:
		return
	var dir := int(signf(player.input_axis()))
	last_dir = dir
	if dir == 0:
		player.velocity.x = move_toward(player.velocity.x, 0.0, 1400.0 * delta)
		last_speed = 0.0
		return
	# 车在玩家前方（方向为 -side）时是"推"；同向 side 时是"拉 / 后退"
	var pushing := dir == -side
	var sp := push_speed if pushing else pull_speed
	# 注意：局部变量不能叫 moved —— 会和 signal moved 撞名，解析器会把它当成 float 去找 .emit()
	var dx := _move_pair(float(dir) * sp * delta)
	var spd := absf(dx) / maxf(delta, 0.0001)
	last_speed = spd
	player.velocity.x = dx / maxf(delta, 0.0001)
	if not is_zero_approx(dx):
		player.set_facing(dir)
		moved.emit(dx, spd)


## 以 1px 子步把整组往前挪，遇到墙体就停在"最后一个合法位置"
func _move_pair(dx: float) -> float:
	var step := signf(dx)
	var remain := absf(dx)
	var moved := 0.0
	while remain > 0.0001:
		var s := minf(1.0, remain)
		var nx := global_position.x + (moved + s) * step
		if not _pair_free(nx):
			blocks_at_wall += 1
			break
		moved += s
		remain -= s
	if is_zero_approx(moved):
		return 0.0
	global_position.x += moved * step
	player.global_position.x = global_position.x + float(side) * side_offset
	return moved * step


## 组合体在 cart_x 处是否合法：车与人都不能和世界实体重叠，也不能越界
func _pair_free(cart_x: float) -> bool:
	if cart_x - cart_width * 0.5 < world_left:
		return false
	if cart_x + cart_width * 0.5 > world_right:
		return false
	if not _rect_free(cart_x, cart_width * 0.5, cart_height):
		return false
	var px := cart_x + float(side) * side_offset
	return _rect_free(px, player.collision_width() * 0.5, player.collision_height())


## 用矩形 shape 查询世界实体（layer 1，排除玩家自己）
func _rect_free(cx: float, half_w: float, h: float) -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(maxf(half_w * 2.0, 1.0), h)
	q.shape = sh
	q.transform = Transform2D(0.0, Vector2(cx, ground_y - h * 0.5))
	q.collision_mask = 1
	q.exclude = [player.get_rid()] if player != null else []
	return get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


# ------------------------------------------------------------------ 布局信息（供叠加层与测试）
func body_rect() -> Rect2:
	return Rect2(global_position + Vector2(-cart_width * 0.5, -cart_height),
		Vector2(cart_width, cart_height))


## 双层占位绘制。刻意只画线框 + 半透明篮体：
## 正式购物车 PNG 由美术另行发包，这里的形状只用来验证尺寸与遮挡关系。
class CartPart:
	extends Node2D

	var cart: PushableCart
	var front := false

	func _draw() -> void:
		if cart == null:
			return
		var w: float = cart.cart_width
		var h: float = cart.cart_height
		var x0 := -w * 0.5
		var top := -h
		var tint: Color = cart.cart_tint

		if not front:
			# 远侧：篮体底色 + 远端轮与支柱
			draw_rect(Rect2(x0 + 4.0, top + 12.0, w - 12.0, 48.0),
				Color(tint.r, tint.g, tint.b, 0.34), true, -1.0, false)
			draw_line(Vector2(x0 + w - 20.0, top + 60.0), Vector2(x0 + w - 20.0, -7.0),
				tint.darkened(0.30), 2.0)
			draw_circle(Vector2(x0 + w - 20.0, -7.0), 7.0, tint.darkened(0.45))
			return

		# 近侧：篮体网线（竖向），挡住玩家腿部，读出"在车后面"
		for i in 4:
			var gx := x0 + 10.0 + float(i) * 18.0
			draw_line(Vector2(gx, top + 14.0), Vector2(gx, top + 58.0),
				Color(tint.r, tint.g, tint.b, 0.85), 1.0)
		draw_rect(Rect2(x0 + 4.0, top + 12.0, w - 12.0, 48.0), tint, false, 2.0, false)
		# 把手
		draw_rect(Rect2(x0 + w - 8.0, top, 4.0, 62.0), tint, true, -1.0, false)
		# 近侧支柱与轮
		draw_line(Vector2(x0 + 12.0, top + 60.0), Vector2(x0 + 12.0, -7.0), tint, 2.0)
		draw_circle(Vector2(x0 + 12.0, -7.0), 7.0, tint.darkened(0.35))
		# 横幅标签，方便截图辨认（占位，不是正式 UI）
		draw_line(Vector2(x0 + 4.0, top + 60.0), Vector2(x0 + w - 8.0, top + 60.0),
			tint.darkened(0.15), 2.0)
