extends Node2D
## 第一季 · 室内横版场景通用控制器
##
## 由室内图接进来的场景都挂这个脚本：负责玩家落点、相机边界、日志。
## 门→场景的切换交给 Interaction/Door_To_Street（DoorInteractable），不在这里做。

## SceneRouter 里登记的场景 key，仅用于日志与断言
@export var location_key: StringName = &"int_a"
## 人类可读名，写日志用
@export var display_name: String = "室内"
## 室内可走的世界宽度（= 房间墙到墙）
@export var world_width: float = 1208.0
## 进门后的落点 x（世界坐标，地面 y=0）
@export var spawn_x: float = 1100.0
## 相机上边界（世界坐标，负值）
@export var ceiling_y: float = -760.0

@onready var _player: Node2D = get_node_or_null("Actors/Player")
@onready var _camera: Camera2D = get_node_or_null("Camera2D")


func _ready() -> void:
	if _player != null:
		_player.set("ground_y", 0.0)
		_player.call("teleport_to", spawn_x)
	else:
		push_warning("[INT] 场景里没有 Actors/Player")

	if _camera != null:
		_camera.limit_left = 0
		_camera.limit_right = int(world_width)
		_camera.limit_top = int(ceiling_y)
		_camera.limit_bottom = 40
		_camera.set("follow_enabled", true)
		_camera.call("snap_to_target")

	print("[INT] %s(%s) 就绪 w=%.0f spawn=%.0f" % [display_name, location_key, world_width, spawn_x])
