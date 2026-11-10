class_name PlayerController
extends CharacterBody2D
## 角色移动底座（CORE-001A 建立 / CORE-001B 接推车 / VIDEO-INTEGRATE-001 接动画）
##
## ART-RESET-001 删掉了 r01–r09 全部旧贴图，本组件一度只保留功能层。
## VIDEO-INTEGRATE-001 接上普通行走动画（r10/r11/r12，已正式登记）：
##   idle_right（1 帧） / walk_right（36 帧 24FPS） / walk_to_idle（21 帧 24FPS）
## VIDEO-INTEGRATE-002 追加推车动画（**候选**，来自用户第二条 AI 视频）：
##   push_idle_right（1 帧） / push_walk_right（32 帧 24FPS） / push_walk_to_idle（17 帧 24FPS）
## 只加渲染与动画切换，**移动 / 碰撞 / 脚底接地 / 推车接管 / 交互接口一律不动**。
##
## ⚠️ 推车三段仍是**候选，待用户视觉审核**，未进素材台账 / 运行时白名单 /
## 美术总览正式状态。购物车本体始终由 PushableCart 用 ART_FURN_103 r03 分层资源渲染，
## 人物贴图里**不含任何车体像素**，也没有第二辆车。
##
## 坐标约定（不变）：
##   - 节点原点 = 角色脚底；帧画布 **512×704**，脚底落在 **(256,672)**。
##   - VIDEO-QUALITY-002 起贴图几何全部由 `player.tscn` 单一管理：
##     `centered=false / offset=(-256,-672) / scale=(0.25,0.25)`，
##     画面上仍是 128×176 的显示大小，脚底锚点仍落在世界 (0,0)。
##   - 贴图用 **LINEAR**（texture_filter=2，由 player.tscn 设置）：512×704 缩小 4 倍时
##     NEAREST 会抽样出锯齿，mipmap 又会让 1× 窗口明显变软（实测锐度掉 39%），
##     LINEAR 是实测最优。只改角色这一个 CanvasItem，全局像素素材仍是 Nearest。
##   - 禁止用 scale 去"修"角色的实际显示大小；要改就改贴图分辨率与 offset。

signal facing_changed(dir: int)
signal state_changed(state: StringName)
signal animation_changed(anim: StringName)

const STATE_IDLE := &"idle"
const STATE_WALK := &"walk"

const ANIM_IDLE := &"idle_right"
const ANIM_WALK := &"walk_right"
const ANIM_STOP := &"walk_to_idle"

# ---- VIDEO-INTEGRATE-002：推车三段（候选） ----
const ANIM_PUSH_IDLE := &"push_idle_right"
const ANIM_PUSH_WALK := &"push_walk_right"
const ANIM_PUSH_STOP := &"push_walk_to_idle"
## 推车循环 f23–f54 共 32 帧 / 24FPS（两个完整步态周期，闭合差 0.00936）。
const PUSH_WALK_FRAME_COUNT := 32
## 与推车减速段首帧 f73 姿态差 ≤ 1.5× 循环内帧间均值的相位
## （tools/video/integrate_002.py 实测 7/32 = 21.9%）。
## 其它相位松手时视频没有对应减速段，不强行拼接，直接站稳。
const PUSH_STOP_OK_PHASES: Array[int] = [0, 1, 14, 15, 16, 30, 31]

## 这两个常量由 tools/video/integrate_001.py 对真实视频逐帧量测得出：
## 让 walk 循环窗口取 f28..f63，使末帧 f63 与减速段起点 f137 姿态差 0.0302
## （循环内相邻帧平均 0.0358），停止过渡因此能自然接上。
const WALK_FRAME_COUNT := 36
## 与过渡首帧姿态差 ≤ 1.5× 循环内帧间均值的相位（实测 0/1/15/16/17/34/35）。
## 玩家在其它相位松手时，视频里没有对应的减速段，**不强行拼接**，直接站稳。
const STOP_OK_PHASES: Array[int] = [0, 1, 15, 16, 17, 34, 35]

## 水平最大速度 px/s（ART-RESET-001 裁定：100 不改）。
@export var move_speed: float = 100.0
@export var accel: float = 900.0
@export var decel: float = 1400.0

## 脚底接地的世界 y。没有重力/跳跃，用显式值而不是物理下落。
@export var ground_y: float = 0.0
@export var snap_to_ground: bool = true

## 输入开关。自动化测试时关掉，改用 set_input_override()。
@export var input_enabled: bool = true

## 停止时是否只在「相位能接上」时播 walk_to_idle。关掉则每次松手都播过渡
## （会有可见跳变，仅供对照演示，不要当正式配置）。
@export var stop_phase_align: bool = true

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _collision: CollisionShape2D = $Collision

var facing: int = 1
var state: StringName = STATE_IDLE

## 外部接管移动（推购物车时由 PushableCart 驱动）。接管期间本组件不读输入、不 move_and_slide。
var external_control: bool = false

## 扶车姿态开关。打开时由 PushableCart 在绑定 / 解绑时切换。
## VIDEO-INTEGRATE-002 起切到专用推车动画，不再拿 walk_right 冒充推车动作。
var push_pose: bool = false
## 推车行走开关：绑定且向前实际推行时由 PushableCart 每帧驱动。
var push_walk_active: bool = false

var _override := 0.0
var _has_override := false
var _no_visual_warned := false
var _anim: StringName = ANIM_IDLE
var _prev_state: StringName = STATE_IDLE
var _in_stop_transition := false


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING  # 无重力、无平台
	# 贴图过滤 / scale / offset 全部由 player.tscn 配置（VIDEO-QUALITY-002 单一数据源）。
	# 这里**不再覆盖**，否则两处不一致会把高清缩放悄悄改回 1:1。
	if has_visual():
		_sprite.visible = true
		_sprite.animation_finished.connect(_on_animation_finished)
		_play(ANIM_IDLE)
		print("[PLAYER] r10–r12 普通行走 + vid002 推车候选动画已加载：%s" %
			", ".join(PackedStringArray(_sprite.sprite_frames.get_animation_names())))
		if push_anim_available():
			print("[PLAYER] VIDEO-INTEGRATE-002 推车动画可用（候选 / 待美术审核）")
		else:
			print("[PLAYER] VIDEO-INTEGRATE-002 推车动画缺失：推车状态将回退固定站姿")
	else:
		_sprite.visible = false
		_warn_no_visual()
	set_facing(1)
	if snap_to_ground:
		global_position.y = ground_y


## 当前是否真的有角色贴图。测试用它区分「功能通过」与「美术缺失」。
func has_visual() -> bool:
	return _sprite != null and _sprite.sprite_frames != null \
		and _sprite.sprite_frames.get_animation_names().size() > 0


## 推车三段是否齐备。缺任一段就回退固定站姿，绝不拿普通行走冒充推车。
func push_anim_available() -> bool:
	if not has_visual():
		return false
	var sf := _sprite.sprite_frames
	return sf.has_animation(ANIM_PUSH_IDLE) \
		and sf.has_animation(ANIM_PUSH_WALK) \
		and sf.has_animation(ANIM_PUSH_STOP)


func _warn_no_visual() -> void:
	if _no_visual_warned:
		return
	_no_visual_warned = true
	print("[PLAYER] 角色渲染为空：player.tscn 未挂 SpriteFrames。")


func _physics_process(delta: float) -> void:
	if external_control:
		# 位置由外部（推车组合体）决定，这里只保证贴地与状态不失真
		velocity.y = 0.0
		if snap_to_ground:
			global_position.y = ground_y
		_update_state()
		_enforce_push_anim()
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
	_enforce_push_anim()


## 兜底不变量：只要 push_pose 为真，当前动画就必须属于推车三段。
## 任何路径（包括以后新增的）把普通动画播了出来，这一帧就纠正回去。
## 与 _update_state() 里的守卫是双保险：守卫挡住已知路径，这里挡住未知路径。
func _enforce_push_anim() -> void:
	if not push_pose or not has_visual():
		return
	var cur := _sprite.animation
	if cur == ANIM_PUSH_WALK or cur == ANIM_PUSH_IDLE or cur == ANIM_PUSH_STOP:
		return
	_apply_push_anim()


func _update_state() -> void:
	var next := STATE_WALK if absf(velocity.x) > 1.0 else STATE_IDLE
	if next == state:
		# 状态没变，但仍要处理「过渡播到一半又起步」这类帧级情况。
		# ⚠️ 推车期间**绝不能**动动画（VIDEO-FIX-002A 的真实 bug）：
		# 松手那一帧 PushableCart 先 set_push_moving(false) 起了 push_walk_to_idle、
		# 把 _in_stop_transition 置真，而此时人物 velocity 还有 ~57（减速要几帧），
		# state 仍是 walk —— 这条分支就会把过渡覆盖成 walk_right，
		# 结果是「车在 PUSHING、人却垂手走路」。推车动画由 set_push_* 独占驱动。
		if next == STATE_WALK and _in_stop_transition and not push_pose:
			_play(ANIM_WALK)
			_in_stop_transition = false
		return

	_prev_state = state
	state = next
	state_changed.emit(state)
	# 推车期间动画由 set_push_pose / set_push_moving 独占驱动，
	# 避免与 PushableCart 每帧调用的时序竞争导致过渡被打断。
	if push_pose:
		return
	_apply_anim_for_state()


func _apply_anim_for_state() -> void:
	if not has_visual():
		return
	# ---- 推车状态：只用专用推车三段，绝不拿普通行走冒充 ----
	# PushableCart 在 bind() 里 set_push_pose(true)，在 _physics_process 里
	# 每帧 set_push_moving(pushing and 实际位移>1)。两条独立通道。
	if push_pose:
		_apply_push_anim()
		return
	if state == STATE_WALK:
		_in_stop_transition = false
		_play(ANIM_WALK)
		return
	# 刚停下
	if _prev_state == STATE_WALK and _can_play_stop_transition():
		_in_stop_transition = true
		_play(ANIM_STOP)
	else:
		_in_stop_transition = false
		_play(ANIM_IDLE)


## 推车动画切换（仅供 _apply_anim_for_state 兜底；正常路径由两个 set_* 接口驱动）。
func _apply_push_anim() -> void:
	if _in_stop_transition and _sprite.animation == ANIM_PUSH_STOP:
		return                       # 过渡播放中不打断
	_in_stop_transition = false
	if not push_anim_available():
		_play(ANIM_IDLE)
		return
	_play(ANIM_PUSH_WALK if push_walk_active else ANIM_PUSH_IDLE)


func _can_play_push_stop_transition() -> bool:
	if not push_anim_available():
		return false
	if not stop_phase_align:
		return true
	var f := _sprite.frame
	return f >= 0 and f < PUSH_WALK_FRAME_COUNT and PUSH_STOP_OK_PHASES.has(f)


## 是否允许播停止过渡。相位集合来自视频逐帧量测，见 STOP_OK_PHASES 注释。
func _can_play_stop_transition() -> bool:
	if not _sprite.sprite_frames.has_animation(ANIM_STOP):
		return false
	if not stop_phase_align:
		return true
	var f := _sprite.frame
	return f >= 0 and f < WALK_FRAME_COUNT and STOP_OK_PHASES.has(f)


func _on_animation_finished() -> void:
	match _sprite.animation:
		ANIM_STOP:
			_in_stop_transition = false
			_play(ANIM_IDLE)
		ANIM_PUSH_STOP:
			_in_stop_transition = false
			_play(ANIM_PUSH_IDLE if push_pose else ANIM_IDLE)


func _play(anim: StringName) -> void:
	if _sprite.sprite_frames == null or not _sprite.sprite_frames.has_animation(anim):
		return
	if _anim == anim and _sprite.animation == anim and _sprite.is_playing() \
			and anim != ANIM_STOP:
		return
	_anim = anim
	_sprite.play(anim)
	animation_changed.emit(anim)


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


## 扶车姿态开关（PushableCart 在 bind/unbind 时切）。
## 进入：立刻播扶车待机；离开：回到普通待机/行走，绝不残留推车帧。
func set_push_pose(on: bool) -> void:
	if push_pose == on:
		return
	push_pose = on
	_in_stop_transition = false
	if not on:
		push_walk_active = false
	if has_visual():
		if on and not push_anim_available():
			# 候选未挂载：固定站姿，不拿 walk_right 冒充推车
			_play(ANIM_IDLE)
		else:
			_play(ANIM_PUSH_IDLE if on else (ANIM_WALK if state == STATE_WALK else ANIM_IDLE))


## 推车行走开关：PushableCart 每帧驱动。只在**值变化**时切帧，避免每帧重置播放。
## 松开方向键时先看当前 walk 相位能否自然接上视频减速段，能则播过渡，否则直接站稳。
func set_push_moving(moving: bool) -> void:
	if push_walk_active == moving:
		return
	push_walk_active = moving
	if not has_visual() or not push_pose or not push_anim_available():
		return
	if moving:
		_in_stop_transition = false
		_play(ANIM_PUSH_WALK)
	elif _can_play_push_stop_transition():
		_in_stop_transition = true
		_play(ANIM_PUSH_STOP)
	else:
		_in_stop_transition = false
		_play(ANIM_PUSH_IDLE)


func is_pushing_pose() -> bool:
	return push_pose


func set_facing(dir: int) -> void:
	var d := 1 if dir >= 0 else -1
	if d == facing and _sprite.flip_h == (d < 0):
		return
	facing = d
	# flip_h 只镜像绘制：碰撞盒与世界坐标不变
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


# ------------------------------------------------------------------ 动画查询（测试用）

func current_anim() -> StringName:
	return _anim


func anim_frame() -> int:
	return _sprite.frame if _sprite != null else -1


func anim_frame_count() -> int:
	if not has_visual():
		return 0
	return _sprite.sprite_frames.get_frame_count(_sprite.animation)


func anim_fps() -> float:
	if not has_visual():
		return 0.0
	return float(_sprite.sprite_frames.get_animation_speed(_sprite.animation))


func in_stop_transition() -> bool:
	return _in_stop_transition


## 强制播一次停止过渡（演示 / 对照用，不改变游戏默认行为）。
func force_stop_transition() -> void:
	if not has_visual() or not _sprite.sprite_frames.has_animation(ANIM_STOP):
		return
	_in_stop_transition = true
	_play(ANIM_STOP)


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
