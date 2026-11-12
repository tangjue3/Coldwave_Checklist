extends Control
## 正式主菜单（PREP-003 建立 / TASK-UI-003 接入美术背景）
##
## 背景是一张 1672×941 的主菜单插画（`assets/ui/menu/menu_bg_1672x941.png`），
## 图上已经画好了按钮框与文字，所以这里**只叠透明按钮**做点击区，不再另画底框与文字。
## 按钮矩形的来源：对原图逐行扫描边框得到像素坐标，再乘 960/1672 换算到逻辑视口。
##
## 只提供入口与工程验证功能，不启动任何玩法流程。
## 「继续游戏」因 SaveManager 未实现而明确禁用；「新游戏」「设置」只显示说明文字。

## 按钮矩形（960×540 逻辑坐标）。改背景图时必须重新量，不要凭感觉调。
const BTN_RECT := {
	&"NewGame": Rect2(666, 233, 219, 34),
	&"Continue": Rect2(666, 277, 219, 34),
	&"Settings": Rect2(666, 322, 219, 33),
	&"DevTest": Rect2(666, 365, 219, 33),
	&"Quit": Rect2(666, 408, 219, 34),
}

@onready var _hint: Label = $Hint
@onready var _dev_panel: Panel = $DevPanel


func _ready() -> void:
	$Buttons/NewGame.pressed.connect(_on_new_game)
	$Buttons/Settings.pressed.connect(_on_settings)
	$Buttons/DevTest.pressed.connect(_on_dev_test)
	$Buttons/Quit.pressed.connect(_on_quit)
	$DevPanel/Box/Supermarket.pressed.connect(func() -> void: SceneRouter.goto(&"supermarket"))
	$DevPanel/Box/Shelter.pressed.connect(func() -> void: SceneRouter.goto(&"shelter"))
	$DevPanel/Box/Smoke.pressed.connect(func() -> void: SceneRouter.goto_smoke())
	if has_node("DevPanel/Box/Season1Map"):
		$DevPanel/Box/Season1Map.pressed.connect(func() -> void: SceneRouter.goto(&"season1_map"))
	$DevPanel/Box/Close.pressed.connect(_on_close_dev)

	# 存档未实现：明确禁用，并在脚本层再兜一次底
	var continue_button: Button = $Buttons/Continue
	continue_button.disabled = not SaveManager.can_continue()
	continue_button.tooltip_text = SaveManager.status()

	_dev_panel.visible = false
	_hint.text = ""
	_apply_button_rects()
	print("[MENU] 主菜单就绪（美术背景 + 透明点击区）；continue_disabled=",
		continue_button.disabled, " save_status=", SaveManager.status())


## 把按钮摆到背景图上按钮框的位置。场景里已写好同名矩形，这里再对齐一次，
## 保证脚本与 `.tscn` 两处不会因为手改其中一个而错位。
func _apply_button_rects() -> void:
	for key in BTN_RECT:
		var b := get_node_or_null("Buttons/%s" % key) as Control
		if b == null:
			continue
		var r: Rect2 = BTN_RECT[key]
		b.position = r.position
		b.size = r.size


func _on_new_game() -> void:
	_hint.text = "新游戏流程尚未实现，等待下一阶段任务批准。"


func _on_settings() -> void:
	_hint.text = "设置界面尚未实现，等待单独任务。"


func _on_dev_test() -> void:
	_dev_panel.visible = true
	_hint.text = "开发测试入口：仅用于工程验证，不含玩法内容。"


func _on_close_dev() -> void:
	_dev_panel.visible = false
	_hint.text = ""


func _on_quit() -> void:
	if OS.has_feature("web"):
		_hint.text = "网页版请直接关闭浏览器标签页退出。"
	else:
		get_tree().quit(0)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE and _dev_panel.visible:
			_on_close_dev()
