extends Control
## 正式主菜单（PREP-003）
##
## 只提供入口与工程验证功能，不启动任何玩法流程。
## 「继续游戏」因 SaveManager 未实现而明确禁用；「新游戏」「设置」只显示说明文字。

@onready var _hint: Label = $Hint
@onready var _dev_panel: Panel = $DevPanel


func _ready() -> void:
	$MenuBox/NewGame.pressed.connect(_on_new_game)
	$MenuBox/Settings.pressed.connect(_on_settings)
	$MenuBox/DevTest.pressed.connect(_on_dev_test)
	$MenuBox/Quit.pressed.connect(_on_quit)
	$DevPanel/Box/Supermarket.pressed.connect(func() -> void: SceneRouter.goto(&"supermarket"))
	$DevPanel/Box/Shelter.pressed.connect(func() -> void: SceneRouter.goto(&"shelter"))
	$DevPanel/Box/Smoke.pressed.connect(func() -> void: SceneRouter.goto_smoke())
	if has_node("DevPanel/Box/Season1Map"):
		$DevPanel/Box/Season1Map.pressed.connect(func() -> void: SceneRouter.goto(&"season1_map"))
	$DevPanel/Box/Close.pressed.connect(_on_close_dev)

	# 存档未实现：明确禁用，并在脚本层再兜一次底
	var continue_button: Button = $MenuBox/Continue
	continue_button.disabled = not SaveManager.can_continue()
	continue_button.tooltip_text = SaveManager.status()

	_dev_panel.visible = false
	_hint.text = "工程框架阶段：正式玩法等待下一阶段任务批准。"
	print("[MENU] 主菜单就绪；continue_disabled=", continue_button.disabled,
		" save_status=", SaveManager.status())


func _on_new_game() -> void:
	_hint.text = "新游戏流程尚未实现，等待下一阶段任务批准。"


func _on_settings() -> void:
	_hint.text = "设置界面尚未实现，等待单独任务。"


func _on_dev_test() -> void:
	_dev_panel.visible = true
	_hint.text = "开发测试入口：仅用于工程验证，不含玩法内容。"


func _on_close_dev() -> void:
	_dev_panel.visible = false
	_hint.text = "已关闭开发测试入口。"


func _on_quit() -> void:
	if OS.has_feature("web"):
		_hint.text = "网页版请直接关闭浏览器标签页退出。"
	else:
		get_tree().quit(0)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE and _dev_panel.visible:
			_on_close_dev()
