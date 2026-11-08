extends Node2D
## 超市 / 安全屋空场景共用的占位控制器（PREP-003）
##
## 只做三件事：显示场景名与节点扩展说明、返回主菜单、打印位置用于验证。
## 不创建商品、家具、角色、天气、库存、建造或剧情逻辑。

@export var display_name: String = "空场景"
@export var location_key: StringName = &"unknown"
@export_multiline var structure_hint: String = ""


@onready var _title: Label = $UI/HUDPlaceholder/Header
@onready var _hint: Label = $UI/HUDPlaceholder/StructureHint


func _ready() -> void:
	_title.text = display_name + "（占位空场景）"
	_hint.text = structure_hint
	$UI/HUDPlaceholder/BackButton.pressed.connect(_on_back)
	print("[WORLD] ready key=", location_key, " name=", display_name,
		" scene=", get_tree().current_scene.scene_file_path)


func _on_back() -> void:
	SceneRouter.goto_main_menu()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			_on_back()
