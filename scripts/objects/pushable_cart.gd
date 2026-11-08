class_name PushableCart
extends Node2D
## CORE-001B 建立状态机 / ART-INTEGRATE-002 换成真实购物车精灵
##
## 三条硬约束，来自 CORE-001A 的实测结论：
##   1) **停放的车不是硬墙**。CORE-001A 里车有 StaticBody2D，人物停在 x=1030 永远过不去。
##      本实现里车**没有任何物理体**，停放时玩家直接从它身上走过去。
##   2) **绑定后是一套刚体组合**。玩家与车的相对侧位在绑定瞬间确定，之后**永不翻面**；
##      按反方向键是"拉着车后退"，不是"车瞬移到另一侧"。
##   3) **撞墙整组停住，但仍可解绑**。用 1px 子步 + 矩形 shape 查询逐步试探，
##      停下的位置一定是"车和人都没和墙体重叠"的位置，不存在穿墙或把人挤到另一侧。
##
## 视觉（ART-RUNTIME-003A → 003C）：
##   r01 128×112 画布、可见 96×74（旧，扶手偏低，与 160px 主角的手对不上）
##   r02 128×112 画布、可见 96×90（当前，抬高车把后的版本；横向仍是 96，锚点仍是 (64,104)）
##   两个版本文件都留在库里，r01 可随时回滚。**画布 128 ≠ 车长 96，逻辑车长是冻结值。**
##   车头朝右、手柄在左。
##   前后两层用**同一张图**：Back 在玩家之后（z=0）常驻，Front 在玩家之前（z=1）
##   只在两者横向重叠时显示。车篮是稀疏网眼，前景压住腿部时仍能看到裤腿，
##   于是"站在车后面 / 侧身绕过"的观感保住了，而且**世界坐标的行走线一条都没动**。
##   注意：这是单张图做的两层，不是美术给的前后分件；正式分件交付后应替换掉这一招。

## 明确不做：容量、结算、装载、物资 UI、库存持久化（属 CORE-002 及以后）。

signal state_changed(state: StringName)
## 车实际移动了一帧时发出，供 HUD / 测试读取速度
signal moved(dx: float, speed: float)

const STATE_PARKED := &"parked"
const STATE_PUSHING := &"pushing"

## 当前使用加高车把的 r02（ART-RUNTIME-003C 候选件）。r01 文件保留，可一键换回。
const CART_TEXTURE := preload("res://assets/facilities/ART_FURN_103_r02_tall_handle_128x112.png")
const CART_TEXTURE_R01 := preload("res://assets/facilities/ART_FURN_103_r01_empty_cart_128x112.png")
## 精灵画布与锚点（两版一致：128×112，脚底锚点 (64,104)）
const SPRITE_CANVAS := Vector2(128, 112)
const SPRITE_ANCHOR := Vector2(64, 104)
## 真实可见尺寸：r02 = 96×90（r01 = 96×74）。横向 96 与冻结的车长一致；画布 128 不等于车长。
const VISIBLE_SIZE := Vector2(96, 90)
const VISIBLE_SIZE_R01 := Vector2(96, 74)

## 已批准尺寸：车长 96（横向占位），车身高度量用于 shape 查询
@export var cart_width: float = 96.0
@export var cart_height: float = 96.0
@export var ground_y: float = 0.0
## 推行速度待调参数（不是美术尺寸）：从 80 起测，普通行走仍是 100
@export var push_speed: float = 80.0
## 反向"拉着走"速度：明显低于推速，手感上区分"推"和"拖"
@export var pull_speed: float = 40.0
## 人物脚底原点到车中心的水平距离；交付说明建议 80，实际由原生截图确认无穿插
@export var side_offset: float = 80.0
## 场景横向边界
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

var _sprite_back: Sprite2D
var _sprite_front: Sprite2D


func _ready() -> void:
	global_position.y = ground_y
	_build_visual()
	_build_hotspot()
	_refresh_front_layer()


# ------------------------------------------------------------------ 视觉

func _build_visual() -> void:
	# Back：玩家之后，常驻
	_sprite_back = _make_sprite("Back", 0)
	# Front：玩家之前，只在横向重叠时显示（同一张图，见文件头说明）
	_sprite_front = _make_sprite("Front", 1)
	_sprite_front.visible = false


func _make_sprite(node_name: String, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = node_name
	s.texture = CART_TEXTURE
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = false
	s.scale = Vector2.ONE
	# 锚点：让纹理里的 (64,104) 落在节点原点（= 地面上的车底中心）
	s.offset = -SPRITE_ANCHOR
	s.z_as_relative = false
	s.z_index = z
	add_child(s)
	return s


## 车头默认朝右、手柄在左。玩家站到右边时镜像，让手柄对着推车的人。
## 只镜像绘制，不引入"朝向状态"，所以按反方向键不会翻面。
func _set_visual_flip(flipped: bool) -> void:
	if _sprite_back != null:
		_sprite_back.flip_h = flipped
	if _sprite_front != null:
		_sprite_front.flip_h = flipped


## 前景层只在玩家横向压到车身上时显示
func _refresh_front_layer() -> void:
	if _sprite_front == null:
		return
	if player == null:
		_sprite_front.visible = false
		return
	var span := player_visible_span()
	var lo := global_position.x - VISIBLE_SIZE.x * 0.5
	var hi := global_position.x + VISIBLE_SIZE.x * 0.5
	_sprite_front.visible = span.x < hi and span.y > lo


## 玩家可见轮廓的横向范围（用真实 alpha 包围盒，不是碰撞盒——观感看的是轮廓）
func player_visible_span() -> Vector2:
	if player == null:
		return Vector2(global_position.x, global_position.x)
	var b := player.visible_bbox()
	var x0 := player.global_position.x + b.position.x
	return Vector2(x0, x0 + b.size.x)


func _build_hotspot() -> void:
	hotspot = Interactable.new()
	hotspot.name = "CartHotspot"
	hotspot.prompt_verb = "推购物车"
	hotspot.interact_priority = 20          # 高于货架(5)与门(10)：车压在货架前面时必须是车
	hotspot.prompt_lift = 76.0              # 车只有 74 高，提示抬到人物头顶之上一点
	hotspot.interacted.connect(_on_hotspot_interacted)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	# 热点要够宽：绑定后玩家在 ±80，必须仍然压得住，否则无法按 E 停车
	r.size = Vector2(cart_width + 80.0, VISIBLE_SIZE.y + 8.0)
	cs.shape = r
	cs.position = Vector2(0.0, -VISIBLE_SIZE.y * 0.5)
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
	# 扶车姿态：r03 单帧。绑定期间一直用这张，解绑才回到 idle / walk。
	p.set_push_pose(true)
	# 手柄朝向推车的人：默认手柄在左，玩家在右（side=+1）时才需要镜像
	_set_visual_flip(side > 0)
	_refresh_hotspot_prompt()
	_refresh_front_layer()
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
	_refresh_front_layer()
	if p != null:
		p.set_external_control(false)
		p.set_push_pose(false)
		p.velocity = Vector2.ZERO
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
	_refresh_front_layer()
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
	# 注意：局部变量不能叫 moved —— 会和 signal moved 撞名
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
	var moved_px := 0.0
	while remain > 0.0001:
		var s := minf(1.0, remain)
		var nx := global_position.x + (moved_px + s) * step
		if not _pair_free(nx):
			blocks_at_wall += 1
			break
		moved_px += s
		remain -= s
	if is_zero_approx(moved_px):
		return 0.0
	global_position.x += moved_px * step
	player.global_position.x = global_position.x + float(side) * side_offset
	return moved_px * step


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
## 真实可见范围 96×90（r02；r01 是 96×74），不是 128×112 的画布
func body_rect() -> Rect2:
	return Rect2(global_position + Vector2(-VISIBLE_SIZE.x * 0.5, -VISIBLE_SIZE.y), VISIBLE_SIZE)


## 精灵相对节点原点的绘制偏移（= -锚点）。量测手部贴合时要和玩家用同一套坐标算法。
func get_cart_offset() -> Vector2:
	return -SPRITE_ANCHOR


## 当前是否镜像绘制（手柄朝着推车的人）
func is_visual_flipped() -> bool:
	return _sprite_back != null and _sprite_back.flip_h


## 前景遮挡层此刻是否显示（测试用来核对"站进车里"的层级确实生效）
func front_layer_visible() -> bool:
	return _sprite_front != null and _sprite_front.visible
