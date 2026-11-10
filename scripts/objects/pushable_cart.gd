class_name PushableCart
extends Node2D
## CORE-001B 建立状态机 / ART-INTEGRATE-002 换成真实购物车精灵
## ART-INTEGRATE-004 接入 r03 分层购物车（Back / Cargo / Front 三件分件）
##
## 三条硬约束，来自 CORE-001A 的实测结论：
##   1) **停放的车不是硬墙**。CORE-001A 里车有 StaticBody2D，人物停在 x=1030 永远过不去。
##      本实现里车**没有任何物理体**，停放时玩家直接从它身上走过去。
##   2) **绑定后是一套刚体组合**。玩家与车的相对侧位在绑定瞬间确定，之后**永不翻面**；
##      按反方向键是"拉着车后退"，不是"车瞬移到另一侧"。
##   3) **撞墙整组停住，但仍可解绑**。用 1px 子步 + 矩形 shape 查询逐步试探，
##      停下的位置一定是"车和人都没和墙体重叠"的位置，不存在穿墙或把人挤到另一侧。
##
## 视觉（ART-RUNTIME-002 → 003C → 004）：
##   - `art_variant = r02`（旧版，单张整图两层）：
##       r02 128×112 画布、可见 96×90，抬高车把；两层用**同一张图**，
##       玩家压到车身上时整张车再画一遍到玩家前面，制造"侧身绕过"的观感。
##       **这是没有分件时的临时做法，保留为回退版本**。
##   - `art_variant = r03`（默认版本，ART-INTEGRATE-005 阶段1 总监裁定）：
##       Back（车把 / 后框架 / 支撑 / 车轮）、Cargo（车内物资，可选）、
##       Front（近侧篮网与前景边缘）三张**独立**贴图，128×112 画布、锚点同为 (64,104)。
##       Back 与 Front 的非透明像素**互不重叠**（已用 numpy 逐像素核对），
##       所以 Back+Front 重组后与旧 r02 整图**像素差异 AE = 0**。
##       图层顺序固定为 Back → Cargo → Player → Front：
##         Back   z=0（车体后景，永远在人物之后）
##         Cargo  z=0（车内物资，在 Back 之后、人物之前）
##         Player z=0（人物，节点顺序在车之后）
##         Front  z=1（近侧篮网，永远在人物之前 → 正确遮挡腿部）
##       **约定**：购物车节点必须**先于**人物节点进入场景树，否则 z=0 的层之间
##       只能靠树顺序决定前后。开发场景都遵守这条，`_ready()` 会做一次检查并打印警告。
##
## 装载状态（EMPTY / HALF / FULL）**纯视觉**：只切 Cargo 层的贴图可见性，
## 不涉及库存、容量、结算、载重、持久化与自动装载阈值（属 CORE-002 及以后）。
##
## 明确不做：容量、结算、装载、物资 UI、库存持久化（属 CORE-002 及以后）。

signal state_changed(state: StringName)
## 车实际移动了一帧时发出，供 HUD / 测试读取速度
signal moved(dx: float, speed: float)

const STATE_PARKED := &"parked"
const STATE_PUSHING := &"pushing"

## 视觉版本：r02 = 单图两层（旧，回退用）；r03 = 三件分件（本轮）
const ART_VARIANT_R02 := &"r02"
const ART_VARIANT_R03 := &"r03"

## 装载状态（纯视觉）
const LOAD_EMPTY := &"empty"
const LOAD_HALF := &"half"
const LOAD_FULL := &"full"

## 当前使用加高车把的 r02（ART-RUNTIME-003C 候选件，已由 ART-FIX-003C 批准为运行时可用）。
## r01 文件保留，可一键换回。
const CART_TEXTURE := preload("res://assets/facilities/ART_FURN_103_r02_tall_handle_128x112.png")
const CART_TEXTURE_R01 := preload("res://assets/facilities/ART_FURN_103_r01_empty_cart_128x112.png")

## r03 三件分件（ART-RUNTIME-004 交付包；ART-INTEGRATE-005 阶段1 已批准为运行时可用）。
## 画布与锚点和 r02 完全一致。
const CART_TEX_R03_BACK := preload("res://assets/facilities/ART_FURN_103_r03_back_128x112.png")
const CART_TEX_R03_FRONT := preload("res://assets/facilities/ART_FURN_103_r03_front_128x112.png")
const CART_TEX_R03_CARGO_HALF := preload("res://assets/facilities/ART_FURN_103_r03_cargo_half_128x112.png")
const CART_TEX_R03_CARGO_FULL := preload("res://assets/facilities/ART_FURN_103_r03_cargo_full_128x112.png")

## 精灵画布与锚点（两版一致：128×112，脚底锚点 (64,104)）
const SPRITE_CANVAS := Vector2(128, 112)
const SPRITE_ANCHOR := Vector2(64, 104)
## 真实可见尺寸：r02 = 96×90（r01 = 96×74）；r03 的 Back+Front 合并后同样是 96×90。
## 横向 96 与冻结的车长一致；画布 128 不等于车长。
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

## 视觉版本与装载状态。r03 为默认（ART-INTEGRATE-005 阶段1 总监裁定）；
## r02 保留为回退版本，set_art_variant() 可随时切回。
@export var art_variant: StringName = ART_VARIANT_R03
@export var load_state: StringName = LOAD_EMPTY

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
## r03 专用：两张货物层互斥显示（半载 / 满载不能同时出现）
var _sprite_cargo_half: Sprite2D
var _sprite_cargo_full: Sprite2D
## 镜像状态单独记一份：重建视觉后精灵是新的，必须把朝向补回去
var _flipped: bool = false


func _ready() -> void:
	global_position.y = ground_y
	_build_visual()
	_build_hotspot()
	_refresh_front_layer()


# ------------------------------------------------------------------ 视觉

func _build_visual() -> void:
	if art_variant == ART_VARIANT_R03:
		_build_r03_visual()
	else:
		_build_r02_visual()


## 旧版：单张整图分两层画（保留为回退路径，行为与 ART-INTEGRATE-003 完全一致）
func _build_r02_visual() -> void:
	# Back：玩家之后，常驻
	_sprite_back = _make_sprite("Back", 0, CART_TEXTURE)
	# Front：玩家之前，只在横向重叠时显示（同一张图，见文件头说明）
	_sprite_front = _make_sprite("Front", 1, CART_TEXTURE)
	_sprite_front.visible = false


## 本轮正式分件：Back / Cargo / Front 三层，锚点与缩放完全一致
func _build_r03_visual() -> void:
	# Back：车体后景（车把、后框架、支撑、车轮）
	_sprite_back = _make_sprite("Back", 0, CART_TEX_R03_BACK)
	# Cargo：车内物资。半载与满载是两个独立节点，互斥显示，
	# 杜绝"半载和满载同时出现"这种错误状态。
	_sprite_cargo_half = _make_sprite("CargoHalf", 0, CART_TEX_R03_CARGO_HALF)
	_sprite_cargo_full = _make_sprite("CargoFull", 0, CART_TEX_R03_CARGO_FULL)
	# Front：近侧篮网与前景边缘，永远压在人物前面 → 腿部被正确遮挡
	_sprite_front = _make_sprite("Front", 1, CART_TEX_R03_FRONT)
	_apply_load_state()


func _make_sprite(node_name: String, z: int, tex: Texture2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = node_name
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = false
	s.scale = Vector2.ONE
	# 锚点：让纹理里的 (64,104) 落在节点原点（= 地面上的车底中心）
	s.offset = -SPRITE_ANCHOR
	s.z_as_relative = false
	s.z_index = z
	add_child(s)
	return s


## 运行时切换视觉版本（开发验证与回退用）。保留当前状态、绑定关系与镜像。
func set_art_variant(variant: StringName) -> void:
	if variant == art_variant:
		return
	art_variant = variant
	_rebuild_visual()


func _rebuild_visual() -> void:
	for s in [_sprite_back, _sprite_front, _sprite_cargo_half, _sprite_cargo_full]:
		if s != null and is_instance_valid(s):
			s.queue_free()
	_sprite_back = null
	_sprite_front = null
	_sprite_cargo_half = null
	_sprite_cargo_full = null
	_build_visual()
	# 重建后把镜像状态补回去，避免切换版本后朝向突然翻面
	_set_visual_flip(_flipped)
	_refresh_front_layer()


## 车头默认朝右、手柄在左。玩家站到右边时镜像，让手柄对着推车的人。
## 只镜像绘制，不引入"朝向状态"，所以按反方向键不会翻面。
func _set_visual_flip(flipped: bool) -> void:
	_flipped = flipped
	for s in _layer_sprites():
		s.flip_h = flipped


## 所有可见层（r02 两层 / r03 四层），顺序即绘制顺序
func _layer_sprites() -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	for s in [_sprite_back, _sprite_cargo_half, _sprite_cargo_full, _sprite_front]:
		if s != null and is_instance_valid(s):
			out.append(s)
	return out


## 前景遮挡层：r03 的近侧篮网是车的固有结构，**常驻显示**；
## r02 没有真正的分件，只能沿用旧做法——横向重叠时才把整张图再画一遍。
func _refresh_front_layer() -> void:
	if _sprite_front == null:
		return
	if art_variant == ART_VARIANT_R03:
		_sprite_front.visible = true
		return
	if player == null:
		_sprite_front.visible = false
		return
	var span := player_visible_span()
	var lo := global_position.x - VISIBLE_SIZE.x * 0.5
	var hi := global_position.x + VISIBLE_SIZE.x * 0.5
	_sprite_front.visible = span.x < hi and span.y > lo


# ------------------------------------------------------------------ 装载状态（纯视觉）

## 设置装载状态。半载与满载互斥，空载不显示任何货物层。
func set_load_state(value: StringName) -> void:
	load_state = value
	_apply_load_state()


## 在三种状态之间轮转（开发场景用）
func cycle_load_state() -> void:
	match load_state:
		LOAD_EMPTY:
			set_load_state(LOAD_HALF)
		LOAD_HALF:
			set_load_state(LOAD_FULL)
		_:
			set_load_state(LOAD_EMPTY)


func _apply_load_state() -> void:
	if _sprite_cargo_half == null or _sprite_cargo_full == null:
		return
	_sprite_cargo_half.visible = load_state == LOAD_HALF
	_sprite_cargo_full.visible = load_state == LOAD_FULL


## 当前是否有货物层可见
func cargo_visible() -> bool:
	return (_sprite_cargo_half != null and _sprite_cargo_half.visible) \
		or (_sprite_cargo_full != null and _sprite_cargo_full.visible)


func cargo_half_visible() -> bool:
	return _sprite_cargo_half != null and _sprite_cargo_half.visible


func cargo_full_visible() -> bool:
	return _sprite_cargo_full != null and _sprite_cargo_full.visible


# ------------------------------------------------------------------ 遮挡顺序自检

## z=0 的层之间只能靠树顺序决定前后：车必须先于人物进入场景树。
## 违反时立刻打印警告，避免"看起来对但其实被人物盖住"的静默错误。
func layer_order_is_valid() -> bool:
	if player == null or get_parent() == null:
		return true
	return _draw_order_index(self) < _draw_order_index(player)


## 节点在场景树中的绘制序（逐级比较祖先索引）。同层同序时靠前的先画。
func _draw_order_index(n: Node) -> Array[int]:
	var chain: Array[int] = []
	var cur := n
	while cur != null:
		chain.push_front(cur.get_index())
		cur = cur.get_parent()
	return chain


func _warn_if_layer_order_broken() -> void:
	if not layer_order_is_valid():
		push_warning("[CART] 购物车节点在人物之后入树：z=0 的 Back/Cargo 层会被人物盖住。")


## 玩家"身体横向范围"（用于 r02 单图版判断前景重叠）。
## ART-RESET-001 起角色没有贴图，改用量碰撞盒估算；r03 分件默认常驻前景，不依赖这一项。
func player_visible_span() -> Vector2:
	if player == null:
		return Vector2(global_position.x, global_position.x)
	var b := player.collision_rect()
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
	# 扶车姿态：绑定起步先播扶车静止帧；真正推行时由 _physics_process 切当前版本的推车行走
	# （ART-INTEGRATE-005E 默认 r09 十六帧 / 10FPS，可一键回退 r04 四帧）。
	p.set_push_pose(true)
	p.set_push_moving(false)
	# 手柄朝向推车的人：默认手柄在左，玩家在右（side=+1）时才需要镜像
	_set_visual_flip(side > 0)
	_refresh_hotspot_prompt()
	_refresh_front_layer()
	_warn_if_layer_order_broken()
	print("[CART] bind side=%+d  玩家 %.0f → %.0f（脚底原点距车心 %.0f）  状态=%s  视觉=%s  装载=%s" % [
		side, before, p.global_position.x, side_offset, state, art_variant, load_state])
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
		player.set_push_moving(false)
		return
	# 车在玩家前方（方向为 -side）时是"推"；同向 side 时是"拉 / 后退"
	var pushing := dir == -side
	var sp := push_speed if pushing else pull_speed
	# 注意：局部变量不能叫 moved —— 会和 signal moved 撞名
	var dx := _move_pair(float(dir) * sp * delta)
	var spd := absf(dx) / maxf(delta, 0.0001)
	last_speed = spd
	player.velocity.x = dx / maxf(delta, 0.0001)
	# 推车行走动画（r04 / r09）：只认「向前推 + 实际位移 > 0」。
	# 撞墙（dx=0）与反向拉车都切回 push_idle 单帧（拉车脚步滑动保留现状）。
	player.set_push_moving(pushing and spd > 1.0)
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
## 真实可见范围 96×90（r02 与 r03 的 Back+Front 合并结果一致），不是 128×112 的画布
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
