extends SceneTree
## 生成可复用的全局 UI Theme（工程工具，不参与游戏运行时）
##
## 运行：godot --headless --path . --script res://scripts/dev/generate_ui_theme.gd
## 依赖：先执行一次 --headless --import 让 TTF 生成 .import 元数据。

const FONT_PATH := "res://assets/ui/fonts/NotoSansSC-Variable.ttf"
const THEME_PATH := "res://assets/ui/themes/main_theme.tres"

const INK := Color(0.86, 0.88, 0.91)
const MUTED := Color(0.58, 0.63, 0.69)
const AMBER := Color(0.94, 0.66, 0.29)
const PANEL := Color(0.14, 0.17, 0.20)
const PANEL_HOVER := Color(0.21, 0.25, 0.29)
const PANEL_DOWN := Color(0.29, 0.23, 0.14)


func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 7
	box.content_margin_bottom = 7
	return box


func _init() -> void:
	var font := load(FONT_PATH) as FontFile
	if font == null:
		printerr("字体未导入，请先运行 --headless --import")
		quit(1)
		return

	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 16

	# 通用文字
	theme.set_color("font_color", "Label", INK)
	theme.set_color("default_color", "RichTextLabel", INK)
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_constant("line_spacing", "Label", 3)
	theme.set_constant("line_spacing", "RichTextLabel", 3)
	theme.set_font_size("normal", "RichTextLabel", 16)

	# 按钮：常态 / 悬停 / 按下 / 禁用
	theme.set_stylebox("normal", "Button", _style(PANEL, Color(0.31, 0.35, 0.40)))
	theme.set_stylebox("hover", "Button", _style(PANEL_HOVER, AMBER))
	theme.set_stylebox("pressed", "Button", _style(PANEL_DOWN, AMBER))
	theme.set_stylebox("disabled", "Button", _style(Color(0.12, 0.13, 0.15), Color(0.24, 0.26, 0.28)))
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", AMBER)
	theme.set_color("font_pressed_color", "Button", AMBER)
	theme.set_color("font_disabled_color", "Button", MUTED)

	# 面板 / 输入框
	theme.set_stylebox("panel", "Panel", _style(PANEL, Color(0.24, 0.28, 0.32)))
	theme.set_stylebox("normal", "LineEdit", _style(PANEL, Color(0.31, 0.35, 0.40)))
	theme.set_stylebox("focus", "LineEdit", _style(PANEL, AMBER))

	var err := ResourceSaver.save(theme, THEME_PATH)
	print("Theme 已保存：", THEME_PATH, " err=", err, " font=", font.get_font_name())

	# 打印主题相关 ProjectSettings，便于核对配置名
	for key: String in ["gui/theme/custom_theme", "gui/theme/custom_font", "gui/theme/default_font_multichannel_signed_distance_field"]:
		print("  ", key, " = ", ProjectSettings.get_setting(key, "<unset>"))

	quit(0 if err == OK else 1)
