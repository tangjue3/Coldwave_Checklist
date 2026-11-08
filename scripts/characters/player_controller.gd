class_name PlayerController
extends CharacterBody2D
## CORE-001A · 正式角色移动底座（隔离组件，可被正式场景复用）
##
## 适用范围：购物 + 建造的**横向叙事**游戏。
## 本组件只做：水平移动 / 停下 / 朝向 / 碰撞 / 脚底接地 / 供相机跟随的锚点。
## 明确不做：跳跃、重力、攻击、平台动作、动画状态机（当前只有一张静止帧）。
##
## 坐标约定（很重要）：
##   - **节点原点 = 角色脚底**。sprite 的 offset = (-64, -168)，让 128×176 纹理里
##     像素 (64,168) 落在节点原点，也就是交付说明给的脚底锚点。
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

@onready var _sprite: Sprite2D = $Sprite
@onready var _collision: CollisionShape2D = $Collision

var facing: int = 1
var state: StringName = STATE_IDLE

var _override := 0.0
var _has_override := false


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING  # 无重力、无平台
	# 像素画固定 1:1，Nearest，禁止任何缩放修补
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE
	set_facing(1)
	if snap_to_ground:
		global_position.y = ground_y


func _physics_process(delta: float) -> void:
	var dir := 0.0
	if _has_override:
		dir = _override
	elif input_enabled:
		dir = Input.get_axis(&"move_left", &"move_right")

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

	var next := STATE_WALK if absf(velocity.x) > 1.0 else STATE_IDLE
	if next != state:
		state = next
		state_changed.emit(state)


# ------------------------------------------------------------------ 对外接口

func set_facing(dir: int) -> void:
	var d := 1 if dir >= 0 else -1
	if d == facing and _sprite.flip_h == (d < 0):
		return
	facing = d
	# 只有一张朝右的静止帧；朝左是临时翻转，仅供控制测试，不是正式左右动作。
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


# ------------------------------------------------------------------ 量尺寸

## 可见包围盒（本地坐标，相对脚底原点）。从纹理 alpha 实测，不是写死的数。
func visible_bbox() -> Rect2:
	var tex := _sprite.texture
	if tex == null:
		return Rect2()
	var img := tex.get_image()
	if img == null:
		return Rect2()
	var used := img.get_used_rect()
	var x := float(used.position.x)
	# 朝左时贴图水平镜像，包围盒必须跟着镜像，否则叠加层会偏 1px（画布左右不对称）
	if _sprite.flip_h:
		x = float(img.get_width() - used.position.x - used.size.x)
	return Rect2(Vector2(x, float(used.position.y)) + _sprite.offset, Vector2(used.size))


## 测试用：临时改碰撞宽度，验证碰撞确实生效（不是靠贴图挡人）
func set_collision_width(w: float) -> void:
	var shape := _collision.shape as RectangleShape2D
	if shape == null:
		return
	shape.size = Vector2(w, shape.size.y)


func collision_width() -> float:
	var shape := _collision.shape as RectangleShape2D
	return shape.size.x if shape else 0.0


func collision_rect() -> Rect2:
	var shape := _collision.shape as RectangleShape2D
	if shape == null:
		return Rect2()
	return Rect2(_collision.position - shape.size * 0.5, shape.size)


func sprite_texture_size() -> Vector2:
	if _sprite.texture == null:
		return Vector2.ZERO
	return Vector2(_sprite.texture.get_size())


func sprite_draw_rect() -> Rect2:
	return _sprite.get_rect()
