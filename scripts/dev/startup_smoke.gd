extends Control
## 《寒潮清单》工程自检场景（PREP-002）
##
## 一张场景同时承担四类验证：
##   1) 中文字体：标题 / 对白 / 按钮 / 长文本换行 / 特殊字符（用 Font.has_char 逐字核查）
##   2) 窗口适配：整数倍缩放、是否超屏、最大化与窗口模式切换
##   3) 输入映射：按键回显（桌面与 Web 都可用）
##   4) 像素渲染：Nearest、integer、gl_compatibility、控件不越界
##
## 命令行参数（写在 `--` 之后）：
##   --profile=1366x768    把窗口设为指定尺寸做适配检查（超过桌面时只做数值推演）
##   --mode-cycle          额外做 窗口→最大化→窗口 切换测试
##   --shot=name.png       指定截图文件名
##   --quit                完成后退出（Web 不带此参数，保持可交互）
##   --hold=8              退出前停留 N 秒，便于抓取操作系统级截图
##
## 例：godot --path . -- --profile=1366x768 --shot=win_1366.png --quit
## 本脚本不含任何玩法逻辑。

const SPEC := Vector2(960, 540)
const SHOT_DIR := "res://tests/screenshots"
const FONT_PATH := "res://assets/ui/fonts/NotoSansSC-Variable.ttf"
const OFL_PATH := "res://assets/ui/fonts/OFL.txt"
const THEME_PATH := "res://assets/ui/themes/main_theme.tres"
const EXPECTED_INPUTS := {
	&"move_left": "A Left",
	&"move_right": "D Right",
	&"interact": "E",
	&"toggle_inventory": "Tab",
	&"toggle_build_mode": "B",
	&"pause": "Escape",
}
## 需要确认字形确实存在（不是系统字体回退出来的）
const SPECIAL_CHARS := "寒潮清单零下°C¥±「」『』《》…—①②③→←↑↓℃㎡½αβγ×÷＝【】"
const LONG_TEXT := "寒潮预警提升为红色。她把采购清单摊在桌上，逐项核对饮用水、速食、燃油与门窗密封条；屋外第一片雪落下，加固门在身后合拢，货架上的纸箱从空到满，暖黄的灯把玻璃上的霜映成一小片光。清单最后一行仍未划掉。"

const INK := Color(0.86, 0.88, 0.91)
const MUTED := Color(0.58, 0.63, 0.69)
const AMBER := Color(0.94, 0.66, 0.29)
const GREEN := Color(0.55, 0.79, 0.60)

var _args: Dictionary = {}
var _pass: int = 0
var _fail: int = 0
var _check_lines: PackedStringArray = PackedStringArray()
var _echo: Label
var _win_info: Label
var _check_info: Label
var _status: Label
var _long_label: Label
var _ui_controls: Array[Control] = []
var _mode_log: PackedStringArray = PackedStringArray()
var _window_note: String = ""
var _screen_index: int = 0
## 启动时所在显示器的可用区域（虚拟桌面绝对坐标）
var _usable_rect: Rect2i = Rect2i(0, 0, 1920, 1080)


func _ready() -> void:
	_parse_args()
	_build_ui()
	_capture_screen_geometry()
	_apply_window()
	for i in 3:
		await get_tree().process_frame
	if _args.has("mode_cycle"):
		await _run_mode_cycle()
	_run_checks()
	_refresh_panels()
	await _finish()


# ---------------------------------------------------------------- 参数 / UI

func _parse_args() -> void:
	for raw in OS.get_cmdline_user_args():
		var a: String = raw
		if not a.begins_with("--"):
			continue
		var kv := a.substr(2).split("=", true, 1)
		if kv.size() == 1:
			_args[kv[0].replace("-", "_")] = true
		else:
			_args[kv[0].replace("-", "_")] = kv[1]


func _mk_label(parent: Control, text: String, rect: Rect2, size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = rect.position
	l.size = rect.size
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	_ui_controls.append(l)
	return l


func _mk_panel(rect: Rect2) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	add_child(p)
	_ui_controls.append(p)
	return p


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.105882, 0.121569, 0.133333, 1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_ui_controls.append(bg)

	_mk_label(self, "寒潮清单 · 字体 / 窗口 / 输入自检", Rect2(40, 16, 880, 34), 22, AMBER)
	_mk_label(self, "Noto Sans SC (SIL OFL 1.1) · Godot 4.7.2 · 960×540 整数倍缩放 · 禁用系统字体回退", Rect2(40, 52, 880, 22), 12, MUTED)

	# ---- 左：字体验证 ----
	var left := _mk_panel(Rect2(40, 84, 500, 356))
	_mk_label(left, "① 中文标题与对白", Rect2(16, 10, 468, 22), 13, AMBER)
	_mk_label(left, "许知夏：「零下四十三度，门外的风像刀子。」\n孟雨薇：「开门……我只要你一点水和食物。」\n旁白：这一次，钥匙在她自己手里。", Rect2(16, 34, 468, 72), 13, INK)
	_mk_label(left, "② 特殊字符 / Unicode", Rect2(16, 110, 468, 22), 13, AMBER)
	_mk_label(left, "−43°C　¥1,200　±5%　「」『』《》…—\n①②③　→←↑↓　℃ ㎡ ½　αβγ　×÷＝　【】", Rect2(16, 134, 468, 48), 13, INK)
	_mk_label(left, "③ 长文本自动换行", Rect2(16, 186, 468, 22), 13, AMBER)
	_long_label = _mk_label(left, LONG_TEXT, Rect2(16, 210, 468, 82), 12, INK)

	var b1 := Button.new()
	b1.text = "结束今天"
	b1.position = Vector2(16, 302)
	b1.size = Vector2(136, 34)
	b1.pressed.connect(func() -> void: _set_echo("点击按钮：结束今天"))
	left.add_child(b1)
	_ui_controls.append(b1)
	var b2 := Button.new()
	b2.text = "打开清单（禁用）"
	b2.position = Vector2(160, 302)
	b2.size = Vector2(180, 34)
	b2.disabled = true
	left.add_child(b2)
	_ui_controls.append(b2)
	var b3 := Button.new()
	b3.text = "测试按钮"
	b3.position = Vector2(348, 302)
	b3.size = Vector2(136, 34)
	b3.pressed.connect(func() -> void: _set_echo("点击按钮：测试按钮"))
	left.add_child(b3)
	_ui_controls.append(b3)

	# ---- 右：输入 / 窗口 / 自检 ----
	var right := _mk_panel(Rect2(552, 84, 368, 356))
	_mk_label(right, "④ 输入回显", Rect2(14, 10, 340, 22), 13, AMBER)
	_echo = _mk_label(right, "等待按键…\nA / D / E / Tab / B / Esc 或点击左侧按钮", Rect2(14, 34, 340, 48), 12, INK)
	_mk_label(right, "⑤ 窗口 / 渲染", Rect2(14, 88, 340, 22), 13, AMBER)
	_win_info = _mk_label(right, "", Rect2(14, 112, 340, 112), 11, INK)
	_mk_label(right, "⑥ 自检", Rect2(14, 228, 340, 22), 13, AMBER)
	_check_info = _mk_label(right, "", Rect2(14, 252, 340, 92), 11, INK)

	var bottom := _mk_panel(Rect2(40, 452, 880, 66))
	_status = _mk_label(bottom, "", Rect2(14, 8, 852, 50), 11, MUTED)


func _set_echo(text: String) -> void:
	if _echo:
		_echo.text = text


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var code: Key = key_event.physical_keycode
	if code == KEY_F10:
		_toggle_maximized()
	elif code == KEY_F11:
		_toggle_fullscreen()
	var matched := ""
	for action: StringName in EXPECTED_INPUTS:
		for e in InputMap.action_get_events(action):
			if e is InputEventKey and (e as InputEventKey).physical_keycode == code:
				matched += String(action) + " "
	_set_echo("最近输入：%s\n匹配动作：%s" % [OS.get_keycode_string(code), matched.strip_edges() if matched != "" else "（无）"])


func _toggle_maximized() -> void:
	if OS.has_feature("web"):
		return
	var m := DisplayServer.window_get_mode()
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED if m == DisplayServer.WINDOW_MODE_MAXIMIZED
		else DisplayServer.WINDOW_MODE_MAXIMIZED
	)
	call_deferred("_refresh_panels")


func _toggle_fullscreen() -> void:
	if OS.has_feature("web"):
		return
	var m := DisplayServer.window_get_mode()
	var is_full := m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED if is_full else DisplayServer.WINDOW_MODE_FULLSCREEN
	)
	call_deferred("_refresh_panels")


# ---------------------------------------------------------------- 窗口

func _capture_screen_geometry() -> void:
	if OS.has_feature("web"):
		return
	_screen_index = DisplayServer.window_get_current_screen()
	_usable_rect = DisplayServer.screen_get_usable_rect(_screen_index)


func _apply_window() -> void:
	if OS.has_feature("web"):
		_window_note = "Web：窗口由浏览器画布决定，跳过桌面窗口设置"
		return
	var usable := _usable_rect.size
	var recommended := WindowFit.recommended_window_size(usable)

	if _args.has("profile"):
		var target := _profile_to_size(String(_args["profile"]))
		if target.x <= 0:
			_window_note = "profile 解析失败：" + String(_args["profile"])
		elif target.x > usable.x or target.y > usable.y:
			var scale := clampi(mini(target.x / 960, target.y / 540), 1, 3)
			_window_note = "目标 %dx%d 超出本机可用区域 %dx%d，未实际改窗口；按整数倍推演 = %d×（渲染 %dx%d，居中留边）" % [
				target.x, target.y, usable.x, usable.y, scale, 960 * scale, 540 * scale
			]
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(target)
			DisplayServer.window_set_position(WindowFit.centered_position(_usable_rect, target))
			_window_note = "profile：窗口已设为 %dx%d（整数倍 %d× 渲染）" % [
				target.x, target.y, clampi(mini(target.x / 960, target.y / 540), 1, 3)
			]
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(recommended)
		DisplayServer.window_set_position(WindowFit.centered_position(_usable_rect, recommended))
		_window_note = "自适应：按可用区域 %dx%d 选 %d× → %dx%d（屏幕原点 %d,%d）" % [
			usable.x, usable.y, WindowFit.best_scale(usable), recommended.x, recommended.y,
			_usable_rect.position.x, _usable_rect.position.y
		]


func _profile_to_size(s: String) -> Vector2i:
	var parts := s.to_lower().split("x")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))


func _snapshot_window(tag: String) -> void:
	if OS.has_feature("web"):
		return
	var w := DisplayServer.window_get_size()
	var p := DisplayServer.window_get_position()
	var vp := get_viewport().get_visible_rect().size
	var mode := DisplayServer.window_get_mode()
	var rect := WindowFit.comparison_rect(
		_usable_rect,
		DisplayServer.screen_get_position(_screen_index),
		DisplayServer.screen_get_size(_screen_index),
		WindowFit.is_fullscreen(mode)
	)
	var fits := WindowFit.fits_in(rect, w, p)
	_mode_log.append("%s: size=%dx%d pos=(%d,%d) compare_rect=%dx%d@(%d,%d) fits=%s viewport=%dx%d mode=%s" % [
		tag, w.x, w.y, p.x, p.y,
		rect.size.x, rect.size.y, rect.position.x, rect.position.y,
		"YES" if fits else "NO",
		int(vp.x), int(vp.y), WindowFit.describe_mode(mode)
	])


func _run_mode_cycle() -> void:
	if OS.has_feature("web"):
		return
	for state: String in ["windowed", "maximized", "fullscreen", "windowed_again"]:
		match state:
			"maximized": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
			"fullscreen": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			_: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		for i in 6:
			await get_tree().process_frame
		_snapshot_window(state)
	# 恢复默认窗口（确保不会把用户桌面留在全屏状态）
	_apply_window()
	for i in 4:
		await get_tree().process_frame
	_snapshot_window("restored")


# ---------------------------------------------------------------- 自检

func _check(ok: bool, detail: String) -> void:
	if ok:
		_pass += 1
		_check_lines.append("[OK]   " + detail)
		print("[SMOKE][OK]   ", detail)
	else:
		_fail += 1
		_check_lines.append("[FAIL] " + detail)
		printerr("[SMOKE][FAIL] ", detail)


func _run_checks() -> void:
	_check(Engine.get_version_info().hash != "" and str(Engine.get_version_info().string).begins_with("4.7"), "Godot %s" % Engine.get_version_info().string)
	var vp := get_viewport().get_visible_rect().size
	_check(vp.is_equal_approx(SPEC), "内部视口 %d×%d" % [int(vp.x), int(vp.y)])
	_check(int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter", -1)) == 0, "纹理过滤 = Nearest")
	_check(str(ProjectSettings.get_setting("display/window/stretch/scale_mode", "")) == "integer", "缩放模式 = integer")
	_check(str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")) == "gl_compatibility", "渲染后端 = gl_compatibility")
	_check(bool(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel", false)), "2D 像素对齐")

	for action: StringName in EXPECTED_INPUTS:
		var keys := ""
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				keys += OS.get_keycode_string((e as InputEventKey).physical_keycode) + " "
		_check(keys.strip_edges() == EXPECTED_INPUTS[action], "输入 %-17s = %s" % [action, keys.strip_edges()])

	# 字体 / 授权（PREP-003：主题改由 UiTheme autoload 挂到根窗口）
	var root_theme := get_tree().root.theme
	_check(root_theme != null, "运行时 UI Theme 已挂载到根窗口")
	_check(
		str(ProjectSettings.get_setting("gui/theme/custom", "")) == "",
		"项目级 custom theme 已移除（首次导入无错的前提）"
	)
	var theme := root_theme as Theme
	_check(theme != null and theme.resource_path == THEME_PATH, "根窗口主题 = main_theme.tres")
	var font: FontFile = theme.default_font as FontFile if theme else null
	_check(font != null, "Theme.default_font = FontFile")
	if font:
		_check(font.get_font_name().contains("Noto Sans SC"), "字体名 %s" % font.get_font_name())
		var missing := ""
		for c in SPECIAL_CHARS:
			if not font.has_char(c.unicode_at(0)):
				missing += c
		_check(missing == "", "特殊字符字形齐全（%d 字，缺：%s）" % [SPECIAL_CHARS.length(), missing if missing != "" else "无"])
		var btn_font := b1_font()
		_check(btn_font == font, "按钮继承 Theme 字体")
	_check(FileAccess.file_exists(OFL_PATH), "OFL.txt 随工程分发")
	_check(ResourceLoader.exists(FONT_PATH), "字体文件可加载")
	_check(_long_label.get_line_count() > 1, "长文本已换行（%d 行）" % _long_label.get_line_count())

	# 控件不越界
	var overflow := 0
	for c in _ui_controls:
		var r := c.get_global_rect()
		if r.position.x < -1 or r.position.y < -1 or r.end.x > SPEC.x + 1 or r.end.y > SPEC.y + 1:
			overflow += 1
	_check(overflow == 0, "UI 控件全部在 960×540 内（越界 %d 个）" % overflow)

	_check(get_tree().current_scene != null, "主场景 %s" % (get_tree().current_scene.scene_file_path if get_tree().current_scene else "null"))
	_check(ResourceLoader.exists("res://icon.svg"), "icon.svg 可加载")
	_check(int(ProjectSettings.get_setting("display/window/size/window_width_override", 0)) == 0, "发布版未写死初始窗口尺寸（运行时自适应）")


func b1_font() -> Font:
	for c in _ui_controls:
		if c is Button:
			return (c as Button).get_theme_font("font")
	return null


func _refresh_panels() -> void:
	if OS.has_feature("web"):
		_win_info.text = "平台：Web（浏览器画布）\n内部视口：960×540\n窗口尺寸由 HTML 画布策略决定\n字体：随包分发的 Noto Sans SC"
	else:
		var w := DisplayServer.window_get_size()
		var p := DisplayServer.window_get_position()
		var s := DisplayServer.screen_get_size(_screen_index)
		var usable := _usable_rect.size
		var mode := DisplayServer.window_get_mode()
		var cmp_rect := WindowFit.comparison_rect(
			_usable_rect,
			DisplayServer.screen_get_position(_screen_index),
			DisplayServer.screen_get_size(_screen_index),
			WindowFit.is_fullscreen(mode)
		)
		var fits := WindowFit.fits_in(cmp_rect, w, p)
		_win_info.text = "显示器 #%d %dx%d / 可用 %dx%d\n窗口 %dx%d @ (%d,%d)  %s\n模式 %s / 整数倍 %d×\n视口 %dx%d / 超屏 %s\n%s" % [
			_screen_index, s.x, s.y, usable.x, usable.y, w.x, w.y, p.x, p.y,
			"贴合" if fits else "超出可用区域",
			WindowFit.describe_mode(DisplayServer.window_get_mode()),
			WindowFit.best_scale(usable),
			int(get_viewport().get_visible_rect().size.x), int(get_viewport().get_visible_rect().size.y),
			"否" if fits else "是",
			_window_note
		]
	_check_info.text = "通过 %d 项 / 失败 %d 项\n覆盖：字体 / 输入 / 渲染 / 窗口 / 控件边界\n逐项结果见控制台 [SMOKE] 日志\n模式切换：--mode-cycle（或 F10 / F11）" % [_pass, _fail]
	_status.text = "本场景仅用于工程验证：字体、窗口、输入、渲染。不含购物 / 建造 / 剧情 / 存档。\n截图保存到 tests/screenshots/；F10 切换最大化，F11 切换全屏，按键结果见右侧④。\nPREP-002：正式玩法仍暂停，等待下一阶段任务批准。"


func _finish() -> void:
	for i in 2:
		await get_tree().process_frame

	print("")
	print("================ 自检汇总 ================")
	print("通过 %d 项，失败 %d 项" % [_pass, _fail])
	for line in _mode_log:
		print("[WINDOW] ", line)
	print("窗口说明：", _window_note)

	if not OS.has_feature("web"):
		await RenderingServer.frame_post_draw
		var dir := ProjectSettings.globalize_path(SHOT_DIR)
		DirAccess.make_dir_recursive_absolute(dir)
		var name: String = String(_args.get("shot", ""))
		if name == "":
			name = "startup_" + Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_") + ".png"
		var path := SHOT_DIR + "/" + name
		var err := get_viewport().get_texture().get_image().save_png(path)
		print("截图：", ProjectSettings.globalize_path(path), " err=", err)
	print("=========================================")

	if _args.has("hold"):
		await get_tree().create_timer(float(_args["hold"])).timeout
	if _args.has("quit"):
		get_tree().quit(0 if _fail == 0 else 1)
