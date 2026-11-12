extends Node2D
## 第一季 · 室内横版场景通用控制器
##
## 由室内图接进来的场景都挂这个脚本。
## 设计原则：**编辑器里摆的就是运行时的样子（所见即所得）**。
##
## 00_Art（背景图）：
##   position / scale 直接决定画面与相机边界，改了立即生效。
##
## Camera2D（三态，camera_mode 可在检查器里改）：
##   自动 —— 00_Art 显示范围不大于视口时用「固定镜头」，
##           Camera2D 的 position / zoom 完全以场景里摆的值为准；
##           图大于视口（如两层楼）时自动切「跟随玩家」。
##   固定镜头 —— 相机钉在场景里摆的位置，不跟人；玩家 x 限制在背景图范围内。
##   跟随玩家 —— 相机 = 玩家 + look_offset，边界按 00_Art 显示范围计算。

## SceneRouter 里登记的场景 key，仅用于日志与断言
@export var location_key: StringName = &"int_a"
## 人类可读名，写日志用
@export var display_name: String = "室内"
## 兜底参数：场景里没摆 00_Art 时，用它算相机边界
@export var world_width: float = 1208.0
## 兜底参数：场景里没摆 Player（position 为零向量）时的落点 x
@export var spawn_x: float = 1100.0
## 兜底参数：场景里没摆 00_Art 时的相机上边界
@export var ceiling_y: float = -760.0
## 相机模式：0=自动 1=固定镜头 2=跟随玩家
## 默认「跟随玩家」——总监裁定室内也要跟人走；
## 「自动」保留：图不大于视口时自动用固定镜头（所见即所得）。
@export_enum("自动:0", "固定镜头:1", "跟随玩家:2")
var camera_mode: int = 2

@onready var _player: Node2D = get_node_or_null("Actors/Player")
@onready var _camera: Camera2D = get_node_or_null("Camera2D")

## 00_Art 在世界坐标里的显示范围，由 _ready 计算
var _art_rect := Rect2()
## Camera2D / Player 在 .tscn 里被摆放的位置（_enter_tree 时抢在子节点 _ready
## 之前取，否则 Player 的 y 会被它自己的 snap_to_ground 先弹回 0，
## Camera2D 的 position 会被 follow_camera 的 snap_to_target 覆盖掉）
var _cam_scene_pos := Vector2.ZERO
var _player_scene_pos := Vector2.ZERO


func _enter_tree() -> void:
	var cam := get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		_cam_scene_pos = cam.position
	var pl := get_node_or_null("Actors/Player") as Node2D
	if pl != null:
		_player_scene_pos = pl.position


func _ready() -> void:
	var art := get_node_or_null("00_Art") as Sprite2D
	if art != null and art.texture != null:
		_art_rect = Rect2(art.position, art.texture.get_size() * art.scale)

	if _player != null:
		# 落点以场景里摆的 Player 为准：编辑器里拖到哪，进门后就站在哪。
		# 必须用 _enter_tree 里存的场景原始值 —— _ready 执行时 Player 自己的
		# snap_to_ground 已经把 y 弹回 0，再读 position.y 就全是 0 了。
		# y 同步写入 ground_y，否则之后每个物理帧还会继续把人拉回 0。
		var x: float = _player_scene_pos.x if not is_zero_approx(_player_scene_pos.x) else spawn_x
		var y: float = _player_scene_pos.y if not is_zero_approx(_player_scene_pos.y) else 0.0
		_player.set("ground_y", y)
		_player.call("teleport_to", x)
	else:
		push_warning("[INT] 场景里没有 Actors/Player")

	_apply_camera()

	print("[INT] %s(%s) 就绪 图=%.0fx%.0f spawn=%.0f 相机=%s" % [display_name, location_key,
		_art_rect.size.x, _art_rect.size.y,
		_player.global_position.x if _player else spawn_x,
		"固定" if _camera != null and not _camera.get("follow_enabled") else "跟随"])


func _apply_camera() -> void:
	if _camera == null:
		return
	var mode := camera_mode
	if mode == 0:
		# 自动：图（含位置/缩放后的显示范围）不大于视口 → 固定镜头；否则跟随
		var vis: Vector2 = _camera.get_viewport_rect().size / _camera.zoom
		mode = 1 if _art_rect.size != Vector2.ZERO \
			and _art_rect.size.x <= vis.x and _art_rect.size.y <= vis.y else 2

	if mode == 1:
		# 固定镜头：所见即所得，不吸附、不跟随、不设边界
		_camera.set("follow_enabled", false)
		_camera.position = _cam_scene_pos
		_camera.limit_left = -10000000
		_camera.limit_right = 10000000
		_camera.limit_top = -10000000
		_camera.limit_bottom = 10000000
		return

	# 跟随玩家：边界优先按 00_Art 的显示范围算，没有图才退回根节点参数
	_camera.set("follow_enabled", true)
	if _art_rect.size != Vector2.ZERO:
		_camera.limit_left = int(_art_rect.position.x)
		_camera.limit_top = int(_art_rect.position.y)
		_camera.limit_right = int(_art_rect.position.x + _art_rect.size.x)
		_camera.limit_bottom = int(_art_rect.position.y + _art_rect.size.y)
	else:
		_camera.limit_left = 0
		_camera.limit_right = int(world_width)
		_camera.limit_top = int(ceiling_y)
		_camera.limit_bottom = 40
	_camera.call("snap_to_target")


func _physics_process(_delta: float) -> void:
	# 固定镜头下玩家走出背景图就再也看不到了，把 x 夹在图内（留 20px 余量）
	if _player == null or _camera == null or _camera.get("follow_enabled"):
		return
	if _art_rect.size == Vector2.ZERO:
		return
	var p := _player.global_position
	var x := clampf(p.x, _art_rect.position.x + 20.0,
		_art_rect.position.x + _art_rect.size.x - 20.0)
	if not is_equal_approx(x, p.x):
		_player.global_position.x = x
