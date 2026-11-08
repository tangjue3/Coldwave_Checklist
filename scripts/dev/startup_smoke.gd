extends Node2D
## 《寒潮清单》启动自检 —— 仅用于工程底座阶段（v0.1）
##
## 作用：验证工程能否正常启动、像素渲染与输入映射是否符合规格，并导出一张启动截图。
## 运行：.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path .
## 退出码：全部通过 = 0，存在失败项 = 1（便于以后接入 CI）
##
## 注意：本脚本不含任何玩法逻辑。正式开发阶段主场景会换成 scenes/bootstrap.tscn，
##       本脚本保留为回归自检工具。

## 动作名 → 期望的按键（顺序即输出顺序）
const EXPECTED_INPUTS := {
	&"move_left": "A Left",
	&"move_right": "D Right",
	&"interact": "E",
	&"toggle_inventory": "Tab",
	&"toggle_build_mode": "B",
	&"pause": "Escape",
}
const SHOT_DIR := "res://tests/screenshots"
const SPEC_VIEWPORT := Vector2(960, 540)

@onready var _checks_label: Label = $Checks

var _lines: PackedStringArray = PackedStringArray()
var _pass_count: int = 0
var _fail_count: int = 0


func _ready() -> void:
	_collect()
	_checks_label.text = "\n".join(_lines)
	await _shoot_and_quit()


func _check(ok: bool, detail: String) -> void:
	if ok:
		_pass_count += 1
		_lines.append("  [OK]    " + detail)
		print("[SMOKE][OK]   ", detail)
	else:
		_fail_count += 1
		_lines.append("  [FAIL]  " + detail)
		printerr("[SMOKE][FAIL] ", detail)


func _collect() -> void:
	_lines.append("引擎与渲染")
	var version_info := Engine.get_version_info()
	_check(
		str(version_info.string).begins_with("4.7"),
		"Godot 运行时版本 %s" % version_info.string
	)
	var vp := get_viewport().get_visible_rect().size
	_check(
		vp.is_equal_approx(SPEC_VIEWPORT),
		"内部视口 %d×%d（规格 960×540，整倍数放大到窗口）" % [int(vp.x), int(vp.y)]
	)
	_check(
		int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter", -1)) == 0,
		"默认纹理过滤 = Nearest"
	)
	_check(
		str(ProjectSettings.get_setting("display/window/stretch/scale_mode", "")) == "integer",
		"窗口缩放模式 = integer"
	)
	_check(
		str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")) == "gl_compatibility",
		"渲染后端 = gl_compatibility（兼容 Web 导出）"
	)
	_check(
		bool(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel", false)),
		"2D 变换像素对齐已开启"
	)

	_lines.append("")
	_lines.append("输入映射（GDD 8.1）")
	for action: StringName in EXPECTED_INPUTS:
		var exists := InputMap.has_action(action)
		var keys := ""
		if exists:
			for event in InputMap.action_get_events(action):
				if event is InputEventKey:
					var code: Key = (event as InputEventKey).physical_keycode
					keys += OS.get_keycode_string(code) + " "
		keys = keys.strip_edges()
		var expected: String = EXPECTED_INPUTS[action]
		_check(
			exists and keys == expected,
			"%-17s → %s（期望 %s）" % [action, keys if keys != "" else "空", expected]
		)

	_lines.append("")
	_lines.append("场景与资源")
	_check(get_tree().current_scene != null, "主场景已加载：%s" % (get_tree().current_scene.scene_file_path if get_tree().current_scene else "null"))
	_check(ResourceLoader.exists("res://icon.svg"), "工程图标 icon.svg 可加载")
	_check(
		ResourceLoader.exists("res://assets/reference/reference_character_style.png"),
		"美术参考图已导入（仅作画风参考，不是正式素材）"
	)


func _shoot_and_quit() -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var absolute_dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var shot_path := "%s/startup_%s.png" % [SHOT_DIR, stamp]
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(shot_path)

	print("")
	print("================ 自检汇总 ================")
	print("通过 %d 项，失败 %d 项" % [_pass_count, _fail_count])
	print("截图：", ProjectSettings.globalize_path(shot_path), "（err=", err, "）")
	print("=========================================")

	await get_tree().create_timer(0.6).timeout
	get_tree().quit(0 if _fail_count == 0 else 1)
