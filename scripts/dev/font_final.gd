extends Control
## TASK-UI-006 最终 HUD 字体方案（A 为主 + 任务行用 B）
##
## 只做三块：今日清单、数值对齐验证、生存状态。不是正式 HUD，面板用 Theme 的 StyleBox 占位。
##
## 命令行（写在 `--` 之后，须带 --dev-scene=fontfinal）：
##   --dev-scene=fontfinal --shot=ui006_final.png --quit
##   --dev-scene=fontfinal --font-check --quit

const THEME_PATH := "res://assets/ui/themes/font_theme.tres"
const DIR := "res://assets/ui/labelsettings/final"

## 最终推荐样式：角色 → 预设 → 期望的字体族（校验用）
const ROLES := {
	"title": ["f_title_serif_18.tres", "Noto Serif SC"],
	"body": ["f_body_serif_14.tres", "Noto Serif SC"],
	"value": ["f_value_serif_14.tres", "Noto Serif SC"],
	"value_long": ["f_value_serif_12.tres", "Noto Serif SC"],
	"task": ["f_task_wenkai_14.tres", "LXGW WenKai Screen"],
	"task_done": ["f_task_done_wenkai_14.tres", "LXGW WenKai Screen"],
	"small": ["f_small_serif_11.tres", "Noto Serif SC"],
}

## 数值对齐验证用的样本（刻意让位数不同）
const SAMPLES := ["9.9°C", "36.4°C", "-12.8°C"]

var _theme: Theme


func _ready() -> void:
	_theme = load(THEME_PATH) as Theme
	var ok := _report()
	if SceneRouter.dev_args.has("font_check"):
		get_tree().quit(0 if ok else 1)
		return
	_keep_own_theme()


func _keep_own_theme() -> void:
	for i in 4:
		await get_tree().process_frame
		_stamp(self)


func _stamp(node: Node) -> void:
	var c := node as Control
	if c != null:
		c.theme = _theme
	for child in node.get_children():
		_stamp(child)


func _report() -> bool:
	var ok := true
	print("[FONT-FINAL] ==== 最终推荐样式 ====")
	for role in ROLES:
		var file: String = ROLES[role][0]
		var want_family: String = ROLES[role][1]
		var ls := load("%s/%s" % [DIR, file]) as LabelSettings
		if ls == null or ls.font == null:
			print("[FONT-FINAL] FAIL %s → %s 载入失败" % [role, file])
			ok = false
			continue
		var family := ls.font.get_font_name()
		var style := ls.font.get_font_style_name()
		var family_ok := family.begins_with(want_family)
		if not family_ok:
			ok = false
		print("[FONT-FINAL] %s %-6s %-26s %-20s %-10s %2dpx 描边%d" % [
			"OK  " if family_ok else "FAIL", role, file, family, style,
			ls.font_size, ls.outline_size,
		])

	# 数值列：同一固定盒内右对齐，位数不同也不推动左侧
	print("[FONT-FINAL] ==== 数值列（盒宽 80px，右缘对齐）====")
	var value_font: LabelSettings = load("%s/f_value_serif_14.tres" % DIR)
	for s in SAMPLES:
		var w: float = value_font.font.get_string_size(
			s, HORIZONTAL_ALIGNMENT_LEFT, -1, value_font.font_size).x
		# 右对齐时左缘 = 盒右缘 - 文本宽；右缘恒为盒右缘
		print("[FONT-FINAL]   %-8s 文本宽 %5.1fpx → 左缘 %5.1f  右缘 80.0（不变）" % [s, w, 80.0 - w])

	# 面板占位样式：确认是深灰半透明，将来换成冰霜 PNG 时只换底图
	var panel := _theme.get_stylebox("panel", "Panel") as StyleBoxFlat
	if panel == null:
		print("[FONT-FINAL] FAIL 主题里没有 Panel/styles/panel")
		ok = false
	else:
		print("[FONT-FINAL] 面板占位：bg=%s a=%.2f 边=%s 圆角=%d" % [
			panel.bg_color.to_html(false), panel.bg_color.a,
			panel.border_color.to_html(false), panel.corner_radius_top_left])

	print("[FONT-FINAL] ==== %s ====" % ("全部通过" if ok else "有失败项"))
	return ok
