extends Control
## TASK-UI-005 A/B 字体方案对照场景
##
## 只做两块面板：今日清单 + 生存状态，按游戏里的真实位置与真实尺寸摆。
## 其余 HUD 元素本轮不做。面板是 StyleBox（Theme 里的 Panel），没有任何美术 PNG。
##
## 方案 A：宋体 600 标题 + 宋体 400 正文 / 数值，克制米白，1–2px 细描边
## 方案 B：宋体 600 标题 + 霞鹜文楷 400 正文 / 数值
##
## 命令行（写在 `--` 之后，须带 --dev-scene=fontab）：
##   --dev-scene=fontab --shot=ui005_ab.png --quit     两张方案同时出图
##   --dev-scene=fontab --font-scheme=a --shot=ui005_a.png --quit
##   --dev-scene=fontab --font-scheme=b --shot=ui005_b.png --quit
##   --dev-scene=fontab --font-check --quit            只校验样式，不截图

const THEME_PATH := "res://assets/ui/themes/font_theme.tres"
const AB_DIR := "res://assets/ui/labelsettings/ab"

## 方案 → 各层级用的预设。校验与说明都读这张表，改样式只改这里。
const SCHEMES := {
	"a": {
		"title": "x_title_serif_18.tres",
		"body": "a_body_serif_14.tres",
		"value": "a_value_serif_14.tres",
		"done": "a_done_serif_14.tres",
		"small": "a_small_serif_11.tres",
	},
	"b": {
		"title": "b_title_serif_18.tres",
		"body": "b_body_wenkai_14.tres",
		"value": "b_value_wenkai_14.tres",
		"done": "b_done_wenkai_14.tres",
		"small": "b_small_wenkai_11.tres",
	},
}

var _theme: Theme


func _ready() -> void:
	_theme = load(THEME_PATH) as Theme
	var args: Dictionary = SceneRouter.dev_args
	var ok := _report()
	if args.has("font_check"):
		get_tree().quit(0 if ok else 1)
		return
	var scheme := String(args.get("font_scheme", "both"))
	$RowA.visible = scheme != "b"
	$RowB.visible = scheme != "a"
	# 只拍 B 时把 B 行整体上移，和 A 的取景一致（两行之间差 252px）
	if scheme == "b":
		$RowB.offset_top = -252.0
		$RowB.offset_bottom = 288.0
	_keep_own_theme()


## 场景切换后 UiTheme 会把 main_theme 挂到每个没有 theme 的 Control 上，
## 这里要把自己的 font_theme 重新压回去（同 font_preview.gd 的做法）。
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
	print("[FONT-AB] ==== A/B 方案样式 ====")
	for scheme in SCHEMES:
		print("[FONT-AB] 方案 %s" % scheme.to_upper())
		for role in SCHEMES[scheme]:
			var path := "%s/%s" % [AB_DIR, SCHEMES[scheme][role]]
			var ls := load(path) as LabelSettings
			if ls == null or ls.font == null:
				print("[FONT-AB]   FAIL %s → %s" % [role, path])
				ok = false
				continue
			var w := ls.font.get_string_size("寒潮清单", HORIZONTAL_ALIGNMENT_LEFT, -1, ls.font_size).x
			if w <= 10.0:
				ok = false
			print("[FONT-AB]   %-6s %-24s %s/%s %2dpx 描边%d 阴影%d 宽%.0f" % [
				role, SCHEMES[scheme][role], ls.font.get_font_name(), ls.font.get_font_style_name(),
				ls.font_size, ls.outline_size, ls.shadow_size, w,
			])
	print("[FONT-AB] ==== %s ====" % ("全部通过" if ok else "有失败项"))
	return ok
