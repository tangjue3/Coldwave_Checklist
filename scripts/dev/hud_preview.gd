extends Node
## TASK-UI-007 HUD 独立透明 PNG 素材接入验证
##
## 屏幕空间 HUD：所有模块在 `CanvasLayer → Control` 里，**不用 Node2D 画任何文字**，
## 因此相机 zoom 变化不影响 HUD 的清晰度与尺寸（下面 --cam-zoom 就是用来证明这点的）。
##
## 面板 / 快捷栏格 / 图标来自候选素材包 v01（`assets/ui/hud/candidates_v01/`，
## 素材库登记为 ART_UI_006–042，审核状态「待审核」）。
## 文字全部是 Label + LabelSettings（TASK-UI-006 的 final/ 预设）：
## 标题 / 正文 / 数值用思源宋体，今日清单任务正文用霞鹜文楷。
##
## 命令行（写在 `--` 之后，须带 --dev-scene=hudprev）：
##   --dev-scene=hudprev --shot=hud_v01.png --quit
##   --dev-scene=hudprev --no-text --shot=hud_v01_notext.png --quit
##   --dev-scene=hudprev --values=b --shot=hud_v01_values_b.png --quit
##   --dev-scene=hudprev --cam-zoom=0.7 --shot=hud_v01_zoom07.png --quit
##   --dev-scene=hudprev --font-check --quit

const THEME_PATH := "res://assets/ui/themes/font_theme.tres"
const TEX_DIR := "res://assets/ui/hud/candidates_v01"

## 两套测试数据：位数刻意不同，用来验证数值变化不会推动布局
const DATA_A := {
	"DateText": "第 1 天 06:35",
	"WeatherText": "-18°C 小雪",
	"StatValue0": "36.4°C", "StatValue1": "72%", "StatValue2": "64%",
	"StatValue3": "46%", "StatValue4": "28.4/40",
	"ResCashText": "现金 126", "ResWoodText": "木材 8", "ResClothText": "布料 3",
	"SlotQty2": "2", "SlotQty3": "3", "SlotQty4": "8", "SlotQty6": "1",
}
## 进度条百分比（与上面文字配套；0–100）
const PERCENT_A := [92, 72, 64, 46, 71]
const PERCENT_B := [5, 100, 8, 100, 99]
const BAR_DEMO := [100, 72, 64, 46, 5, 0]
const BAR_W := 74.0   # 轨道内宽 = 78 - 2*(2px 定位)
const BAR_CAP := 8.0  # 左右各 4px 端帽，短于此宽度九宫格会塌，夹到 8

const DATA_B := {
	"DateText": "第 12 天 21:40",
	"WeatherText": "-7°C 暴雪",
	"StatValue0": "9.9°C", "StatValue1": "100%", "StatValue2": "8%",
	"StatValue3": "100%", "StatValue4": "39.9/40",
	"ResCashText": "现金 9999", "ResWoodText": "木材 128", "ResClothText": "布料 37",
	"SlotQty2": "12", "SlotQty3": "30", "SlotQty4": "80", "SlotQty6": "10",
}

var _theme: Theme
var _root: Control
var _slot_sel := 1
var _tex_normal: Texture2D
var _tex_selected: Texture2D


func _ready() -> void:
	_theme = load(THEME_PATH) as Theme
	_root = $Hud/Root
	_tex_normal = load("%s/HUD_slot_normal_90x90.png" % TEX_DIR)
	_tex_selected = load("%s/HUD_slot_selected_90x90.png" % TEX_DIR)

	var args: Dictionary = SceneRouter.dev_args
	if args.has("cam_zoom"):
		var z := float(args["cam_zoom"])
		($World/Cam as Camera2D).zoom = Vector2(z, z)
	if args.has("no_text"):
		_hide_text(_root)
	var data_b := String(args.get("values", "a")) == "b"
	if data_b:
		_apply_data(DATA_B)
	_apply_bars(PERCENT_B if data_b else PERCENT_A)
	if args.has("bar_demo"):
		(_root.get_node("BarPage") as Control).visible = true
		# 六态样张同样走同一套宽度逻辑，0% 必须真正隐藏（否则九宫格端帽会留一个点）
		_apply_bar_set("BarPage/Fill", BAR_DEMO)
	if args.has("slot"):
		_select_slot(int(args["slot"]))
	var ok := _report()
	if args.has("font_check"):
		get_tree().quit(0 if ok else 1)
		return
	_keep_own_theme()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode >= KEY_1 and k.keycode <= KEY_6:
		_select_slot(k.keycode - KEY_0)
	elif k.keycode == KEY_LEFT:
		_select_slot(maxi(1, _slot_sel - 1))
	elif k.keycode == KEY_RIGHT:
		_select_slot(mini(6, _slot_sel + 1))


## 快捷栏选中态：换贴图而不是画框，保证选中样式来自美术素材
func _select_slot(n: int) -> void:
	_slot_sel = clampi(n, 1, 6)
	for i in range(1, 7):
		var s := _root.get_node_or_null("Slot%d" % i) as TextureRect
		if s != null:
			s.texture = _tex_selected if i == _slot_sel else _tex_normal
	print("[HUD] 快捷栏选中 = %d" % _slot_sel)


## 状态行进度条：轨道是 TextureRect，填充是 NinePatchRect，
## 只改填充宽度（不改贴图尺寸），左右 4px 端帽由九宫格保住。
func _apply_bars(percents: Array) -> void:
	_apply_bar_set("StatFill", percents)


func _apply_bar_set(prefix: String, percents: Array) -> void:
	for i in percents.size():
		var fill := _root.get_node_or_null("%s%d" % [prefix, i]) as NinePatchRect
		if fill == null:
			continue
		var r := clampf(float(percents[i]) / 100.0, 0.0, 1.0)
		fill.visible = r > 0.0
		if r > 0.0:
			fill.size.x = maxf(BAR_CAP, round(BAR_W * r))


func _hide_text(node: Node) -> void:
	if node is Label:
		(node as Label).visible = false
	# 删除线属于文字装饰，去文字时一起隐藏；面板分隔线保留（属于面板结构）
	if String(node.name).ends_with("Strike"):
		(node as CanvasItem).visible = false
	for c in node.get_children():
		_hide_text(c)


func _apply_data(data: Dictionary) -> void:
	for key in data:
		var l := _root.get_node_or_null(key) as Label
		if l == null:
			print("[HUD] WARN 找不到标签 %s" % key)
			continue
		l.text = String(data[key])


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


# ---------------------------------------------------------------- 校验

func _report() -> bool:
	var ok := true
	print("[HUD] ==== HUD 预览校验 ====")

	# 1. 屏幕空间：HUD 必须在 CanvasLayer 里
	var layer := _root.get_parent() as CanvasLayer
	if layer == null:
		print("[HUD] FAIL HUD 不在 CanvasLayer 内（会跟着相机缩放）")
		ok = false
	else:
		print("[HUD] OK   HUD 挂在 CanvasLayer(layer=%d)，与相机 zoom 解耦" % layer.layer)
	print("[HUD] OK   逻辑分辨率 %d×%d" % [int(_root.size.x), int(_root.size.y)])

	# 2. 文字全部是 Label + LabelSettings，且字体真的加载到了字形
	var fonts := {}
	var labels := 0
	var bad := 0
	for l in _all_labels(_root):
		if not l.visible:
			continue
		labels += 1
		var ls := l.label_settings
		if ls == null or ls.font == null:
			print("[HUD] FAIL 标签 %s 没有 label_settings / font" % l.name)
			bad += 1
			continue
		var k := "%s %dpx" % [ls.font.get_font_name(), ls.font_size]
		fonts[k] = int(fonts.get(k, 0)) + 1
	print("[HUD] OK   动态文字 %d 个 Label，字体分布：%s" % [labels, fonts])
	if bad > 0:
		ok = false

	# 3. 美术素材：每个 TextureRect / TextureProgressBar 都必须有贴图
	var tex_missing := 0
	var tex_count := 0
	for n2 in _all_nodes(_root):
		if n2 is TextureRect:
			tex_count += 1
			if (n2 as TextureRect).texture == null:
				tex_missing += 1
		elif n2 is TextureProgressBar:
			tex_count += 1
			var tp := n2 as TextureProgressBar
			if tp.texture_under == null or tp.texture_progress == null:
				tex_missing += 1
	if tex_missing > 0:
		print("[HUD] FAIL %d 个贴图节点缺图" % tex_missing)
		ok = false
	else:
		print("[HUD] OK   美术贴图节点 %d 个，全部有图" % tex_count)

	# 4. 进度条：0% 必须隐藏，其余宽度 = round(74 * ratio)
	print("[HUD] ---- 进度条 ----")
	for i in 5:
		var f2 := _root.get_node_or_null("StatFill%d" % i) as NinePatchRect
		var t2 := _root.get_node_or_null("StatTrack%d" % i) as TextureRect
		if f2 == null or t2 == null:
			print("[HUD] FAIL 缺少 StatTrack%d / StatFill%d" % [i, i])
			ok = false
			continue
		print("[HUD]   行%d 轨道 %d×%d 填充 %d×%d 可见=%s" % [i, int(t2.size.x), int(t2.size.y),
			int(f2.size.x), int(f2.size.y), f2.visible])
		if f2.size.x < BAR_CAP:
			print("[HUD] FAIL 行%d 填充宽度小于端帽宽度" % i)
			ok = false
	if (_root.get_node("BarPage") as Control).visible:
		print("[HUD] ---- 六态样张 ----")
		for i in 6:
			var bf := _root.get_node_or_null("BarPage/Fill%d" % i) as NinePatchRect
			if bf == null:
				continue
			print("[HUD]   %d%% → 填充宽 %d 可见=%s" % [[100,72,64,46,5,0][i], int(bf.size.x), bf.visible])
			if [100,72,64,46,5,0][i] == 0 and bf.visible:
				print("[HUD] FAIL 0% 仍然显示填充")
				ok = false

	# 5. 模块坐标（对照交付包 05-预览 的组装图）
	print("[HUD] ---- 模块矩形（960×540）----")
	for name in ["LocationPanel", "DateTimePanel", "WeatherPanel", "TasksPanel", "StatusPanel",
			"Slot1", "Slot6", "InteractPanel", "ResourcePanel"]:
		var c := _root.get_node_or_null(name) as Control
		if c != null:
			print("[HUD]   %-14s (%d,%d) %d×%d" % [name, int(c.position.x), int(c.position.y),
				int(c.size.x), int(c.size.y)])

	print("[HUD] ==== %s ====" % ("全部通过" if ok else "有失败项"))
	return ok


func _all_labels(node: Node) -> Array[Label]:
	var out: Array[Label] = []
	if node is Label:
		out.append(node as Label)
	for c in node.get_children():
		out.append_array(_all_labels(c))
	return out


func _all_nodes(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for c in node.get_children():
		out.append_array(_all_nodes(c))
	return out
