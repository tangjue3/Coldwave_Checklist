class_name FollowCamera
extends Camera2D
## CORE-001A · 参数化跟随相机（死区 + 平滑）
##
## 参数是**待调项**，只属于本组件，不写进美术数据，也不假设世界地面固定在某个屏幕 y。
## 死区语义：目标在死区矩形内移动时相机**完全不动**；超出后相机把超出量补回来，
## 再按指数平滑逼近，避免一帧贴死造成的生硬推镜。

@export var target_path: NodePath
## 视线偏移：负 y 表示相机中心看目标上方，角色因此落在画面偏下位置。
@export var look_offset := Vector2(0, -64)
## 死区半宽 / 半高（px）。目标在这个矩形内移动，相机不动。
@export var dead_zone := Vector2(56, 28)
## 平滑系数，越大越紧跟；8 约等于 0.12 s 收敛到 63%。
@export var smoothing: float = 8.0
@export var follow_enabled: bool = true

var _target: Node2D
var _center := Vector2.ZERO
## 供测试读取：本帧死区是否被触发、相机移动了多少
var last_overshoot := Vector2.ZERO
var last_step := Vector2.ZERO


func _ready() -> void:
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	_target = get_node_or_null(target_path) as Node2D
	snap_to_target()


func snap_to_target() -> void:
	if _target == null:
		return
	_center = _target.global_position + look_offset
	global_position = _center
	last_overshoot = Vector2.ZERO
	last_step = Vector2.ZERO


func _process(delta: float) -> void:
	if not follow_enabled or _target == null:
		return
	var before := _center
	var want := _target.global_position + look_offset
	var d := want - _center

	# 只补「超出死区」的那部分；目标在死区内时 over = 0，相机一步都不动。
	var over := Vector2(
		signf(d.x) * maxf(0.0, absf(d.x) - dead_zone.x),
		signf(d.y) * maxf(0.0, absf(d.y) - dead_zone.y)
	)
	last_overshoot = over
	if over != Vector2.ZERO:
		var k := 1.0 - exp(-smoothing * delta)
		_center = _center.lerp(_center + over, k)
		global_position = _center
	last_step = _center - before


## 测试用：目标相对相机中心的偏移量
func offset_from_target() -> Vector2:
	if _target == null:
		return Vector2.ZERO
	return _target.global_position + look_offset - _center
