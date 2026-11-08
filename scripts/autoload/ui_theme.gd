extends Node
## 全局 UI Theme 挂载（PREP-003 修复首次导入错误）
##
## 原因：Godot 4.7 的 ThemeDB 在**资源导入之前**就读取 project.godot 的
## `gui/theme/custom` 并加载项目主题。全新 .godot/ 里字体还没被导入成
## .fontdata，主题又通过 .ttf 引用它，于是第一次 --headless --import 报
## 「Failed loading resource / Error loading custom project theme」。
##
## 解决：不在 project.godot 里设项目级主题，改为运行时由本 autoload 把
## 同一个 main_theme.tres 挂到根窗口。资源导入阶段完全不触碰主题，
## 字体 / 主题内容 / 显示效果不变。
##
## 注意：这里必须用 load() 而不是 preload()，否则脚本被扫描时又会提前解析主题。

const THEME_PATH := "res://assets/ui/themes/main_theme.tres"

var is_ready: bool = false


func _ready() -> void:
	var theme := load(THEME_PATH) as Theme
	if theme == null:
		push_error("[UiTheme] 无法加载 UI Theme: %s" % THEME_PATH)
		return
	get_tree().root.theme = theme
	is_ready = true
