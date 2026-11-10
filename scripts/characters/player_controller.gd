class_name PlayerController
extends CharacterBody2D
## 角色移动底座（CORE-001A 建立 / CORE-001B 接推车）
##
## ART-RESET-001：许知夏旧运行时角色素材（r01–r09）**已全部删除**，
## 本组件现在只保留与美术无关的功能层：水平移动 / 停下 / 朝向 / 碰撞 / 脚底接地 /
## 外部接管（推车） / 交互锚点。**没有任何贴图与动画。**
##
## 美术状态：角色渲染暂时为空，这是明确的当前状态，不是遗漏。
## 新外观动画要等用户按 `素材库/美术设定集/01-角色/参考图/` 的五张裁图生成 AI 视频，
## 再由 VIDEO-INTEGRATE 任务拆帧接入。届时只加渲染层，不动这里的移动与碰撞。
##
## 坐标约定（仍然有效，将来接新帧必须遵守）：
##   - **节点原点 = 角色脚底**。
##   - 新的角色帧画布若沿用 128×176，脚底应落在 (64,168)；
##     Sprite 节点已按 centered=false、offset=(-64,-168) 摆好，直接换 SpriteFrames 即可。
##   - 向上为负 y，地面线由导出属性 `ground_y` 显式给出，不依赖视口 y=416。
##   - 贴图固定 1:1：禁止用 scale、小数倍缩放或线性过滤去"修"尺寸。

signal facing_changed(dir: int)
signal state_changed(state: StringName)

const STATE_IDLE := &"idle"
const STATE_WALK := &"walk"

## 水平最大速度 px/s。160px 人物按 1.72m 折算 → 100px/s ≈ 1.08 m/s，接近正常步行。
@export var move_speed: float = 100.0
@export var accel: float = 900.0
@export var decel: float = 1400.0

## 脚底接地的世界 y。没有重力/跳跃，用显式值而不是物理下落。
@export var ground_y: float = 0.0
@export var snap_to_ground: bool = true

## 输入开关。自动化测试时关掉，改用 set_input_override()。
@export var input_enabled: bool = true

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _collision: CollisionShape2D = $Collision

var facing: int = 1
var state: StringName = STATE_IDLE

## 外部接管移动（推购物车时由 PushableCart 驱动）。接管期间本组件不读输入、不 move_and_slide，
## 只保留"贴地 + 状态同步"，避免两套逻辑同时改位置。
var external_control: bool = false

## 扶车姿态开关。打开时由 PushableCart 在绑定 / 解绑时切换。
## 目前没有扶车动画，这个开关只作为**状态标记**保留给交互与测试读取，
## 不再驱动任何帧切换；接新动画时在这里接上。
var push_pose: bool = false
## 推车行走开关：绑定且向前实际推行时由 PushableCart 每帧驱动。
var push_walk_active: bool = false

var _override := 0.0
var _has_override := false
var _no_visual_warned := false


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING  # 无重力、无平台
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE
	# ART-RESET-001：没有 SpriteFrames 就是没有美术，直接隐藏节点。
	# 不加载任何旧人物贴图，也不留一张"占位图"假装角色还在。
	if _sprite.sprite_frames == null:
		_sprite.visible = false
		_warn_no_visual()
	set_facing(1)
	if snap_to_ground:
		global_position.y = ground_y


## 当前是否真的有角色贴图。测试用它区分「功能通过」与「美术缺失」，不许把两者混为一谈。
func has_visual() -> bool:
	return _sprite != null and _sprite.sprite_frames != null \
		and _sprite.sprite_frames.get_animation_names().size() > 0


func _warn_no_visual() -> void:
	if _no_visual_warned:
		return
	_no_visual_warned = true
	print("[PLAYER] 角色渲染为空：ART-RESET-001 已删除 r01–r09 旧素材，新动画待 AI 视频接入。")


func _physics_process(delta: float) -> void:
	if external_control:
		# 位置由外部（推车组合体）决定，这里只保证贴地与状态不失真
		velocity.y = 0.0
		if snap_to_ground:
			global_position.y = ground_y
		_update_state()
		return

	var dir := input_axis()

	if is_zero_approx(dir):
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)
	else:
		velocity.x = move_toward(velocity.x, dir * move_speed, accel * delta)
		if dir < 0.0:
			set_facing(-1)
		elif dir > 0.0:
			set_facing(1)
	velocity.y = 0.0

	move_and_slide()

	if snap_to_ground:
		global_position.y = ground_y

	_update_state()


func _update_state() -> void:
	var next := STATE_WALK if absf(velocity.x) > 1.0 else STATE_IDLE
	if next != state:
		state = next
		state_changed.emit(state)


# ------------------------------------------------------------------ 对外接口

## 当前移动意图（-1/0/1）。推车组合体读同一个来源，保证"输入"只有一处定义。
func input_axis() -> float:
	if _has_override:
		return _override
	if not input_enabled:
		return 0.0
	return Input.get_axis(&"move_left", &"move_right")


## 交/收回移动控制权（推车用）
func set_external_control(on: bool) -> void:
	external_control = on
	if on:
		velocity = Vector2.ZERO


## 扶车姿态开关（推车绑定/解绑时切）。当前只记状态，不切帧。
func set_push_pose(on: bool) -> void:
	if push_pose == on:
		return
	push_pose = on
	if not on:
		push_walk_active = false


## 推车行走开关：由 PushableCart 每帧驱动——向前实际移动 true，停住/拉车/撞墙 false。
## 当前只记状态，不切帧；接新动画时由这里决定播哪一组。
func set_push_moving(moving: bool) -> void:
	push_walk_active = moving


func is_pushing_pose() -> bool:
	return push_pose


func set_facing(dir: int) -> void:
	var d := 1 if dir >= 0 else -1
	if d == facing and _sprite.flip_h == (d < 0):
		return
	facing = d
	# 目前没有贴图，flip_h 只作为将来镜像绘制的开关位保留，不影响碰撞与世界坐标。
	_sprite.flip_h = d < 0
	facing_changed.emit(facing)


## 测试用：绕过键盘输入直接给定方向（-1/0/1）
func set_input_override(dir: float) -> void:
	_has_override = true
	_override = dir


func clear_input_override() -> void:
	_has_override = false
	_override = 0.0


func teleport_to(x: float) -> void:
	global_position = Vector2(x, ground_y)
	velocity = Vector2.ZERO


# ------------------------------------------------------------------ 量尺寸（只量碰撞）

## 测试用：临时改碰撞宽度，验证碰撞确实生效（不是靠贴图挡人）
func set_collision_width(w: float) -> void:
	var shape := _collision.shape as RectangleShape2D
	if shape == null:
		return
	shape.size = Vector2(w, shape.size.y)


func collision_width() -> float:
	var shape := _collision.shape as RectangleShape2D
	return shape.size.x if shape else 0.0


func collision_height() -> float:
	var shape := _collision.shape as RectangleShape2D
	return shape.size.y if shape else 0.0


func collision_rect() -> Rect2:
	var shape := _collision.shape as RectangleShape2D
	if shape == null:
		return Rect2()
	return Rect2(_collision.position - shape.size * 0.5, shape.size)
