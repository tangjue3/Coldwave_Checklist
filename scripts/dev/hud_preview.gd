extends Node
## HUD 开发预览场景（TASK-UI-009 重构）
##
## 这里**不再自己摆一套 HUD**：直接实例 `scenes/ui/hud/game_hud.tscn`，
## 用不同的数据源喂它，所以预览看到的就是正式 HUD 本身。
## 场景只多两样东西：一张背景图（验证半透明面板）和一块进度条六态样张。
##
## 命令行（写在 `--` 之后，须带 --dev-scene=hudprev）：
##   --dev-scene=hudprev                         正常预览
##   --dev-scene=hudprev --values=b              换一套位数不同 / 极端比例的数据
##   --dev-scene=hudprev --no-text               只留面板与图标
##   --dev-scene=hudprev --bar-demo              显示进度条六态样张（100/72/64/46/5/0%）
##   --dev-scene=hudprev --cam-zoom=0.7          验证相机缩放不影响 HUD
##   --dev-scene=hudprev --font-check --quit     结构与数据自检

const TEX_DIR := "res://assets/ui/hud/v01"
const BAR_DEMO := [100, 72, 64, 46, 5, 0]
const BAR_W := 74.0
const BAR_CAP := 8.0

## 开发预览用的第二套数据（正式 HUD 不接受「运行时随便改数」，
## 这里通过 HudSource 契约换数据源，和正式数据走同一条路）
class VariantSource extends HudSource:
	var _data: Dictionary

	func _init(d: Dictionary) -> void:
		_data = d

	func snapshot() -> Dictionary:
		return _data.duplicate(true)

	func describe() -> String:
		return "preview-variant"


const DATA_B := {
	"location": "梧桐里 · 长街",
	"datetime": "第 12 天 21:40",
	"weather": "-7°C 暴雪",
	"tasks": [
		{"text": "把水箱搬进厨房", "done": true},
		{"text": "封窗缝（剩余 3 扇）", "done": true},
		{"text": "清点药品库存", "done": false},
		{"text": "给外婆打电话", "done": false},
	],
	"status": [
		{"icon": "temperature", "label": "体温", "value": "9.9°C", "ratio": 0.05},
		{"icon": "hunger", "label": "饥饿", "value": "100%", "ratio": 1.0},
		{"icon": "thirst", "label": "口渴", "value": "8%", "ratio": 0.08},
		{"icon": "fatigue", "label": "疲劳", "value": "100%", "ratio": 1.0},
		{"icon": "weight", "label": "负重", "value": "39.9/40", "ratio": 0.99},
	],
	"resources": [
		{"icon": "cash", "text": "现金 9999"},
		{"icon": "firewood", "text": "木材 128"},
		{"icon": "cloth", "text": "布料 37"},
	],
	"hotbar": [
		{"icon": "flashlight", "qty": ""},
		{"icon": "water", "qty": "12"},
		{"icon": "bread", "qty": "30"},
		{"icon": "firewood", "qty": "80"},
		{"icon": "pliers", "qty": ""},
		{"icon": "key", "qty": "10"},
	],
	"mock": ["datetime", "weather", "tasks", "status", "resources", "hotbar"],
}

var _hud: GameHud
var _root: Control


func _ready() -> void:
	_hud = $Hud as GameHud
	_root = _hud.get_node("Root") as Control
	_hud.location_override = "梧桐里 · 长街"

	var args: Dictionary = SceneRouter.dev_args
	if args.has("cam_zoom"):
		var z := float(args["cam_zoom"])
		($World/Cam as Camera2D).zoom = Vector2(z, z)
	if String(args.get("values", "a")) == "b":
		_hud.set_source(VariantSource.new(DATA_B))
	else:
		_hud.refresh()
	if args.has("bar_demo"):
		_build_bar_demo()
	if args.has("no_text"):
		_hide_text(_root)
	if args.has("slot"):
		_hud.select_slot(int(args["slot"]))

	var ok := _report()
	if args.has("font_check"):
		get_tree().quit(0 if ok else 1)


## 进度条六态样张：用正式 HUD 同一套九宫格宽度逻辑，验证 0% 真正隐藏
func _build_bar_demo() -> void:
	var page := Control.new()
	page.name = "BarPage"
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(page)

	var bg := ColorRect.new()
	bg.color = Color(0.078, 0.086, 0.102, 0.94)
	bg.position = Vector2(300, 40)
	bg.size = Vector2(400, 412)
	page.add_child(bg)

	var track_tex: Texture2D = load("%s/HUD_progress_track_r02_78x12.png" % TEX_DIR)
	var fill_tex: Texture2D = load("%s/HUD_progress_fill_r02_74x8.png" % TEX_DIR)
	var title := Label.new()
	title.text = "进度条 r02 六态（轨道 78×12 / 填充 74×8）"
	title.position = Vector2(320, 56)
	title.label_settings = load("res://assets/ui/labelsettings/final/f_title_serif_18.tres")
	page.add_child(title)

	for i in BAR_DEMO.size():
		var y := 110 + i * 60
		var track := TextureRect.new()
		track.texture = track_tex
		track.texture_filter = 3
		track.position = Vector2(320, y)
		track.size = Vector2(78, 12)
		page.add_child(track)

		var fill := NinePatchRect.new()
		fill.texture = fill_tex
		fill.texture_filter = 3
		fill.patch_margin_left = 4
		fill.patch_margin_top = 3
		fill.patch_margin_right = 4
		fill.patch_margin_bottom = 3
		fill.position = Vector2(322, y + 2)
		var r := float(BAR_DEMO[i]) / 100.0
		fill.size = Vector2(maxf(BAR_CAP, round(BAR_W * r)) if r > 0.0 else 0.0, 8)
		fill.visible = r > 0.0
		page.add_child(fill)

		var pct := Label.new()
		pct.text = "%d%%" % BAR_DEMO[i]
		pct.position = Vector2(412, y - 6)
		pct.size = Vector2(80, 22)
		pct.label_settings = load("res://assets/ui/labelsettings/final/f_value_serif_12.tres")
		page.add_child(pct)


func _hide_text(node: Node) -> void:
	if node is Label:
		(node as Label).visible = false
	if String(node.name).ends_with("Strike"):
		(node as CanvasItem).visible = false
	for c in node.get_children():
		_hide_text(c)


func _report() -> bool:
	var ok := _hud.verify()
	print("[HUD-PREVIEW] ---- 预览附加检查 ----")
	var bars := 0
	for i in 5:
		if _root.get_node_or_null("StatusPanel/StatFill%d" % i) != null:
			bars += 1
	if bars != 5:
		print("[HUD-PREVIEW] FAIL 状态进度条不足 5 条（%d）" % bars)
		ok = false
	else:
		print("[HUD-PREVIEW] OK   状态进度条 5 条，轨道 78×12 / 填充 74×8")
	var slots := 0
	for i in 6:
		if _root.get_node_or_null("Slot%d" % (i + 1)) != null:
			slots += 1
	print("[HUD-PREVIEW] %s 快捷栏格 %d 个" % ["OK  " if slots == 6 else "FAIL", slots])
	if slots != 6:
		ok = false
	print("[HUD-PREVIEW] ==== %s ====" % ("全部通过" if ok else "有失败项"))
	return ok
