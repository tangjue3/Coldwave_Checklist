extends Control
## TASK-UI-004 字体效果预览 / 校验场景
##
## 目的：把「ChatGPT 生成的《寒潮清单》HUD 概念图」里的文字效果，用**真实 Godot 文字渲染**
## 复现一遍，逐项比对字形、描边、颜色、字重与阴影。概念图里的文字是位图，本场景里全是
## Label + LabelSettings —— 没有任何一张把文字烘焙进去的 PNG。
##
## 两个页面：
##   hud  —— 按概念图 1:1 还原的 HUD 排版（真实室内背景 + 半透明面板 + 五个字号层级）
##   spec —— 参数对照页：同一句话在三种字体下的字形对比、字号阶梯、描边档、阴影档、色板
##
## 命令行（写在 `--` 之后，须带 --dev-scene=fontprev）：
##   --dev-scene=fontprev --shot=ui004_hud.png --quit
##   --dev-scene=fontprev --font-page=spec --shot=ui004_spec.png --quit
##   --dev-scene=fontprev --font-check --quit     只跑资源校验，不截图
##
## 本场景是**视觉预览**，不参与正式玩法，也不改主菜单与正式 HUD。

const FONT_DIR := "res://assets/ui/fonts"
const VARIATION_DIR := "res://assets/ui/fonts/variations"
const LS_DIR := "res://assets/ui/labelsettings"
const THEME_PATH := "res://assets/ui/themes/font_theme.tres"

## 全部 LabelSettings 预设：文件名 → 用途说明
const LS_PRESETS := {
	"ls_title_wenkai_28.tres": "画面标题（楷 28px，手写感）",
	"ls_h2_serif_21.tres": "面板标题（宋 600 21px）",
	"ls_section_serif_13.tres": "栏目小标签（宋 600 加字距）",
	"ls_label_serif_16.tres": "正文 / 状态标签（宋 400）",
	"ls_value_serif_17.tres": "数值（宋 600，高光金）",
	"ls_value_serif_15.tres": "长数值（宋 600 15px）",
	"ls_task_wenkai_17.tres": "任务行（楷）",
	"ls_task_done_wenkai_17.tres": "任务已完成（楷，降亮度）",
	"ls_small_wenkai_12.tres": "小字号提示（楷 12）",
	"ls_button_serif_15.tres": "按钮 / 快捷键提示（宋 400）",
	"ls_number_serif_11.tres": "格位序号 / 数量（宋 600 11）",
}

const PALETTE := {
	"米白 ink": Color(0.949, 0.910, 0.839),
	"次要 dim": Color(0.788, 0.737, 0.643),
	"禁用 mute": Color(0.557, 0.510, 0.443),
	"浅金 gold": Color(0.851, 0.663, 0.431),
	"高光金 hi": Color(0.941, 0.796, 0.573),
	"描边 outline": Color(0.071, 0.063, 0.047),
}

var _rows: Control
var _font_theme: Theme


func _ready() -> void:
	_rows = $PageSpec/Rows
	_font_theme = load(THEME_PATH) as Theme
	_build_spec_page()
	var args: Dictionary = SceneRouter.dev_args
	var page := String(args.get("font_page", "hud"))
	$PageHud.visible = page != "spec"
	$PageSpec.visible = page == "spec"
	$Bg.visible = page != "spec"
	$Scrim.visible = page != "spec"
	var ok := _report()
	if args.has("font_check"):
		get_tree().quit(0 if ok else 1)
		return
	_keep_own_theme()


## 场景切换后，UiTheme 会把 main_theme 逐个挂到"自己没有 theme"的 Control 上
## （见 ui_theme.gd 的 apply_to）。本场景要的是 font_theme，所以要在那之后把自己这一份
## 重新压回去。它是一次性写入，等两帧就够，重复几帧只是防竞态。
func _keep_own_theme() -> void:
	for i in 4:
		await get_tree().process_frame
		_stamp_theme(self)


func _stamp_theme(node: Node) -> void:
	var c := node as Control
	if c != null:
		c.theme = _font_theme
	for child in node.get_children():
		_stamp_theme(child)


# ---------------------------------------------------------------- 校验

## 把每个预设的实际字体名、字号、颜色打出来，并检查资源是否真的加载到了字形。
## 返回 false 表示有任一预设缺字体——这种情况下截图没有参考价值。
func _report() -> bool:
	var ok := true
	print("[FONT] ==== 字体样式校验 ====")
	for file_name in LS_PRESETS:
		var path := "%s/%s" % [LS_DIR, file_name]
		var ls := load(path) as LabelSettings
		if ls == null:
			print("[FONT] FAIL 无法加载 %s" % path)
			ok = false
			continue
		if ls.font == null:
			print("[FONT] FAIL %s 的 font 为空（字体资源没导入？）" % file_name)
			ok = false
			continue
		var face := ls.font.get_font_name()
		var style := ls.font.get_font_style_name()
		# 用实际测量字形宽度，验证字体确实带中文字形（宽度为 0 就是回退失败）
		var w := ls.font.get_string_size("寒潮清单", HORIZONTAL_ALIGNMENT_LEFT, -1, ls.font_size).x
		var flag := "OK  " if w > 10.0 else "FAIL"
		if w <= 10.0:
			ok = false
		print("[FONT] %s %-28s %s/%s %2dpx 描边%d 阴影%d 宽%.0f  %s" % [
			flag, file_name, face, style, ls.font_size, ls.outline_size, ls.shadow_size,
			w, LS_PRESETS[file_name],
		])

	for f in DirAccess.get_files_at(VARIATION_DIR):
		if not f.ends_with(".tres"):
			continue
		var fv := load("%s/%s" % [VARIATION_DIR, f]) as FontVariation
		if fv == null or fv.base_font == null:
			print("[FONT] FAIL 字重实例 %s 载入失败" % f)
			ok = false

	var th := load(THEME_PATH) as Theme
	if th == null:
		print("[FONT] FAIL 主题载入失败 %s" % THEME_PATH)
		ok = false
	else:
		var base := th.get_type_variation_base(&"HotbarSlot")
		print("[FONT] OK   主题默认字体=%s 字号=%d；类型变体 HotbarSlot 基类=%s" % [
			th.default_font.get_font_name() if th.default_font else "<空>",
			th.default_font_size, base,
		])
		if base == &"":
			print("[FONT] FAIL 类型变体 HotbarSlot 未生效（.tres 里 base_type 写法不对？）")
			ok = false

	print("[FONT] ==== %s ====" % ("全部通过" if ok else "有失败项"))
	return ok


# ---------------------------------------------------------------- 对照页

func _build_spec_page() -> void:
	# 左栏 ---------------------------------------------------------- 字形 / 字重 / 字号 / 颜色
	_heading(Vector2(24, 14), "字形对照 · 同一句话三种字体")
	var sentence := "寒潮清单 第5天 存货37件"
	_sample(Vector2(24, 38), sentence, "serif_w600", 20, "思源宋体 600")
	_sample(Vector2(24, 68), sentence, "wenkai_w400", 20, "霞鹜文楷 Screen 400")
	_sample(Vector2(24, 98), sentence, "sans_w500", 20, "思源黑体 500（现工程默认，作对照）")

	_heading(Vector2(24, 136), "字重阶梯 · 思源宋体静态字重（Regular / SemiBold / Black）")
	var weights := ["serif_w400", "serif_w600", "serif_w900"]
	var tags := ["400 Regular", "600 SemiBold", "900 Black"]
	var wy := 158.0
	for i in weights.size():
		_mk_label(Vector2(24, wy), "寒潮清单 37 件 %s" % tags[i], weights[i], 22,
			Color(0.949, 0.910, 0.839), 0, 0, Vector2.ZERO)
		wy += 28.0

	_heading(Vector2(24, 252), "字号阶梯 · 思源宋体 400")
	var sizes := [12, 14, 16, 18, 22, 28]
	var x := 24.0
	for sz in sizes:
		var l := _mk_label(Vector2(x, 274), "%d 寒潮" % sz, "serif_w400", sz,
			Color(0.949, 0.910, 0.839), 0, 0, Vector2.ZERO)
		x += l.get_minimum_size().x + 14.0

	_heading(Vector2(24, 312), "颜色 · 取自概念图与主菜单插画")
	var cy := 332.0
	for name in PALETTE:
		var c: Color = PALETTE[name]
		var sw := ColorRect.new()
		sw.position = Vector2(24, cy)
		sw.size = Vector2(26, 16)
		sw.color = c
		_rows.add_child(sw)
		_mk_label(Vector2(58, cy - 4), "%s   #%s" % [name, c.to_html(false)], "wenkai_w400", 13,
			Color(0.788, 0.737, 0.643), 0, 0, Vector2.ZERO)
		cy += 20.0

	# 右栏 ---------------------------------------------------------- 描边 / 阴影 / 结论
	_heading(Vector2(500, 14), "描边档 · 20px 宋 600，描边色 #12100C")
	var oy := 38.0
	for osize in [0, 1, 2, 3]:
		_mk_label(Vector2(500, oy), "寒潮清单 描边 %dpx" % osize, "serif_w600", 20,
			Color(0.949, 0.910, 0.839), osize, 0, Vector2.ZERO)
		oy += 29.0

	_heading(Vector2(500, 166), "阴影档 · 20px 宋 600（衬浅色底才看得见）")
	var plate := ColorRect.new()
	plate.position = Vector2(500, 188)
	plate.size = Vector2(436, 126)
	plate.color = Color(0.616, 0.561, 0.475, 0.55)
	_rows.add_child(plate)
	var sy := 196.0
	var shadows := [
		["无阴影", 0, Vector2.ZERO],
		["偏移(0,1)", 0, Vector2(0, 1)],
		["偏移(0,2) 模糊2", 2, Vector2(0, 2)],
		["偏移(1,3) 模糊4", 4, Vector2(1, 3)],
	]
	for sh in shadows:
		_mk_label(Vector2(512, sy), "寒潮清单 %s" % sh[0], "serif_w600", 20,
			Color(0.949, 0.910, 0.839), 2, int(sh[1]), sh[2])
		sy += 29.0

	_heading(Vector2(500, 330), "与概念图对照后的小结")
	var notes := [
		"① 概念图文字是宋体（笔画有顿角），思源宋体 600 最接近",
		"② 标题的手写感用霞鹜文楷替代，宋体做不出这个笔势",
		"③ 字号换算：正文 12–17px、面板标题 24px、画面标题 26px",
		"④ 分工：宋体读信息，楷体读人写的东西（清单/剧情）",
	]
	var ny := 354.0
	for n in notes:
		_mk_label(Vector2(500, ny), n, "wenkai_w400", 12, Color(0.788, 0.737, 0.643), 0, 0, Vector2.ZERO)
		ny += 20.0

	# 底部 ---------------------------------------------------------- 参数
	_heading(Vector2(24, 458), "参数（本页全部由 Label + LabelSettings 渲染，没有一张位图文字）")
	_mk_label(Vector2(24, 480), "字号档 11 / 12 / 13 / 15 / 16 / 17 / 24 / 26；描边 #12100C 正文 2px、标题 3–4px；阴影 #000 @35%，偏移 (0,1)–(0,2)",
		"wenkai_w400", 13, Color(0.788, 0.737, 0.643), 0, 0, Vector2.ZERO)
	_mk_label(Vector2(24, 500), "字体：Noto Serif SC 400 / 600 / 900（OFL 1.1）· LXGW WenKai Screen v1.530（OFL 1.1），均随工程分发、不依赖系统字体",
		"wenkai_w400", 13, Color(0.788, 0.737, 0.643), 0, 0, Vector2.ZERO)
	_mk_label(Vector2(24, 520), "概念图为 1672×941（1.74×），其字号换算到本工程须 ×0.574；本页按 960×540 逻辑像素 1:1 出字",
		"wenkai_w400", 13, Color(0.788, 0.737, 0.643), 0, 0, Vector2.ZERO)


func _heading(pos: Vector2, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.label_settings = load("%s/ls_section_serif_13.tres" % LS_DIR)
	_rows.add_child(l)


func _sample(pos: Vector2, text: String, variation: String, size: int, tag: String) -> void:
	var label := _mk_label(pos, text, variation, size, Color(0.949, 0.910, 0.839), 2, 1, Vector2(0, 1))
	var tip := Label.new()
	tip.text = "← " + tag
	# size 要等布局，这里直接用最小尺寸，同一帧就能定位
	tip.position = Vector2(pos.x + label.get_minimum_size().x + 12.0, pos.y + 4.0)
	tip.label_settings = load("%s/ls_small_wenkai_12.tres" % LS_DIR)
	_rows.add_child(tip)


## 造一个临时 Label（不进 .tscn，纯代码）：对照页里每一行参数都不同，用预设反而不直观。
func _mk_label(pos: Vector2, text: String, variation: String, size: int, color: Color,
		outline: int, shadow: int, shadow_off: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	var ls := LabelSettings.new()
	var path := ""
	if variation == "sans_w500":
		path = "%s/NotoSansSC-Variable.ttf" % FONT_DIR
		ls.font = load(path)
	else:
		path = "%s/%s.tres" % [VARIATION_DIR, variation]
		ls.font = load(path)
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = Color(0.071, 0.063, 0.047, 0.85)
	ls.shadow_size = shadow
	ls.shadow_color = Color(0, 0, 0, 0.45)
	ls.shadow_offset = shadow_off
	l.label_settings = ls
	_rows.add_child(l)
	return l
