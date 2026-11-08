class_name PlayerController
extends CharacterBody2D
## 角色移动底座（CORE-001A 建立 / CORE-001B 接推车 / ART-INTEGRATE-002 接行走动画）
##
## 适用范围：购物 + 建造的**横向叙事**游戏。
## 本组件只做：水平移动 / 停下 / 朝向 / 碰撞 / 脚底接地 / 供相机跟随的锚点 / 播放待机与行走动画。
## 明确不做：跳跃、重力、攻击、平台动作、转身与搬运动作（美术尚未交付）。
##
## 坐标约定（很重要）：
##   - **节点原点 = 角色脚底**。纹理是 128×176、脚底在 (64,168)，所以 sprite 的
##     offset 让像素 (64,168) 落在节点原点。
##   - 向上为负 y，地面线由导出属性 `ground_y` 显式给出，不依赖视口 y=416。
##   - 贴图固定 1:1：禁止用 scale、小数倍缩放或线性过滤去"修"尺寸。
##
## 绘制对齐（ART-INTEGRATE-002）：
##   交付的四帧行走与 r01 静止帧**身体中轴不在同一列**（头中心 r01=63.5、r02 四帧=59.5），
##   直接播会在 待机↔行走 切换时横跳 4px。这里不再硬编码某个补偿值，而是**自动量**每张帧的
##   "身体中轴"（取头顶 32 行 alpha 包围盒中心，头不会随手脚摆动而移动），再反推 sprite.offset，
##   让任何帧的身体中轴都落在节点原点左侧 0.5px（= r01 的原始观感）。
##   这只改**绘制偏移**，不碰碰撞盒、不碰节点坐标：世界位置永远是唯一真相。
##   朝左镜像的 1px 也由同一套计算覆盖（镜像后中轴跟着镜像，offset 自动反向补偿）。

signal facing_changed(dir: int)
signal state_changed(state: StringName)

const STATE_IDLE := &"idle"
const STATE_WALK := &"walk"
const ANIM_IDLE := &"idle"
const ANIM_WALK := &"walk_right"

## 身体中轴的目标位置（相对节点原点）。r01 的原始画法就是 -0.5，保持不变以免改动既有观感。
const TARGET_AXIS_X := -0.5

## 水平最大速度 px/s。160px 人物按 1.72m 折算 → 100px/s ≈ 1.08 m/s，接近正常步行。
@export var move_speed: float = 100.0
@export var accel: float = 900.0
@export var decel: float = 1400.0

## 行走动画帧率。交付说明建议 6–7 FPS 起测，这里做成导出项，方便不进编辑器就能调。
@export var walk_fps: float = 7.0
## 手工微调绘制偏移（正常应为 0；只有在美术确认过某个固定补偿时才用它，别拿它盖住对轴问题）
@export var draw_offset_bias := Vector2.ZERO

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

var _override := 0.0
var _has_override := false
var _base_offset_y := -168.0
## 纹理 → 身体中轴 x 的缓存，避免每帧扫描像素
var _axis_cache: Dictionary = {}


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING  # 无重力、无平台
	# 像素画固定 1:1，Nearest，禁止任何缩放修补
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE
	_base_offset_y = _sprite.offset.y
	_apply_walk_fps()
	_sprite.frame_changed.connect(_apply_visual_offset)
	_sprite.animation = ANIM_IDLE
	_sprite.play(ANIM_IDLE)
	set_facing(1)
	_apply_visual_offset()
	if snap_to_ground:
		global_position.y = ground_y


## 帧率写进 SpriteFrames 的副本，避免为了调一个数字去改资源文件
func _apply_walk_fps() -> void:
	var frames := _sprite.sprite_frames
	if frames == null:
		return
	if frames.has_animation(ANIM_WALK):
		frames.set_animation_speed(ANIM_WALK, walk_fps)


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
	if next == state:
		return
	state = next
	var anim := ANIM_WALK if next == STATE_WALK else ANIM_IDLE
	if _sprite.animation != anim:
		_sprite.play(anim)
		# 打一行日志：桌面端与 Web 端都靠它断言"动画真的切了"，因为画面在画布上读不到
		print("[ANIM] %s 帧数=%d FPS=%.1f" % [
			String(anim), _sprite.sprite_frames.get_frame_count(anim),
			_sprite.sprite_frames.get_animation_speed(anim)])
	# play() 之后当前帧立即是 0，先把偏移对齐，别等下一次 frame_changed
	_apply_visual_offset()
	state_changed.emit(state)


# ------------------------------------------------------------------ 绘制对齐

## 应用到 sprite.offset：让当前帧的身体中轴落在 TARGET_AXIS_X。
## 镜像时中轴在纹理里的位置跟着镜像，所以这里用两套公式，而不是简单加一个常数。
func _apply_visual_offset() -> void:
	var tex := current_texture()
	if tex == null:
		return
	var axis := _body_axis(tex)
	var w := float(tex.get_width())
	var off_x := (axis - w + TARGET_AXIS_X) if _sprite.flip_h else (TARGET_AXIS_X - axis)
	_sprite.offset = Vector2(off_x, _base_offset_y) + draw_offset_bias


## 身体中轴：取头顶 32 行 alpha 包围盒的水平中心。
## 头不会随手脚摆动而移动，比整体包围盒稳定（整体 bbox 会因跨步从 41px 变到 74px）。
func _body_axis(tex: Texture2D) -> float:
	var key := tex.get_instance_id()
	if _axis_cache.has(key):
		return float(_axis_cache[key])
	var img := tex.get_image()
	var axis := float(tex.get_width()) * 0.5
	if img != null:
		var used := img.get_used_rect()
		var band_top := used.position.y
		var band_h := mini(32, maxi(1, used.size.y))
		var left := 1 << 30
		var right := -1
		for y in range(band_top, band_top + band_h):
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.5:
					left = mini(left, x)
					right = maxi(right, x)
		if right >= left:
			axis = (float(left) + float(right) + 1.0) * 0.5
	_axis_cache[key] = axis
	return axis


func current_texture() -> Texture2D:
	var frames := _sprite.sprite_frames
	if frames == null or not frames.has_animation(_sprite.animation):
		return null
	var n := frames.get_frame_count(_sprite.animation)
	if n <= 0:
		return null
	return frames.get_frame_texture(_sprite.animation, clampi(_sprite.frame, 0, n - 1))


## 开发截图用：冻结在某个动画的某一帧，不推进
func freeze_frame(anim: StringName, index: int) -> void:
	if _sprite.sprite_frames == null or not _sprite.sprite_frames.has_animation(anim):
		return
	_sprite.play(anim)
	_sprite.pause()
	_sprite.frame = clampi(index, 0, _sprite.sprite_frames.get_frame_count(anim) - 1)
	_apply_visual_offset()


func resume_animation() -> void:
	_sprite.play(ANIM_WALK if state == STATE_WALK else ANIM_IDLE)


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


func set_facing(dir: int) -> void:
	var d := 1 if dir >= 0 else -1
	if d == facing and _sprite.flip_h == (d < 0):
		return
	facing = d
	# 只有朝右的帧；朝左是临时镜像，仅供控制测试，不是正式左右动作。
	_sprite.flip_h = d < 0
	_apply_visual_offset()
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

## 可见包围盒（本地坐标，相对脚底原点）。从当前帧的 alpha 实测，不是写死的数。
func visible_bbox() -> Rect2:
	var tex := current_texture()
	if tex == null:
		return Rect2()
	var img := tex.get_image()
	if img == null:
		return Rect2()
	var used := img.get_used_rect()
	var x := float(used.position.x)
	# 朝左时贴图水平镜像，包围盒必须跟着镜像，否则叠加层会偏（画布左右不对称）
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


func collision_height() -> float:
	var shape := _collision.shape as RectangleShape2D
	return shape.size.y if shape else 0.0


func collision_rect() -> Rect2:
	var shape := _collision.shape as RectangleShape2D
	if shape == null:
		return Rect2()
	return Rect2(_collision.position - shape.size * 0.5, shape.size)


func sprite_texture_size() -> Vector2:
	var tex := current_texture()
	return Vector2(tex.get_size()) if tex != null else Vector2.ZERO


func sprite_draw_rect() -> Rect2:
	return Rect2(_sprite.offset, sprite_texture_size())


func sprite_node() -> AnimatedSprite2D:
	return _sprite


## 当前帧绘制后身体中轴落在节点原点的哪一侧（本地坐标）。
## 镜像时纹理被翻转，中轴在纹理里的位置也跟着翻，所以这里按 flip 分别算。
func drawn_body_axis() -> float:
	var tex := current_texture()
	if tex == null:
		return 0.0
	var axis := _body_axis(tex)
	var local_axis := (float(tex.get_width()) - axis) if _sprite.flip_h else axis
	return _sprite.offset.x + local_axis


func body_axis_of_current() -> float:
	var tex := current_texture()
	return _body_axis(tex) if tex != null else 0.0
