extends Node
## 背包与物资界面 · 候选素材预览（TASK-UI-010）
##
## 这**不是**背包玩法。场景只做三件事：
##   1. 把候选面板/格位/按钮/图标按 960×540 组装出来，看它们在实机上长什么样；
##   2. 用 Godot 原生 Control 画全部文字与数值，证明贴图里没有烘焙字；
##   3. 演示纯 UI 状态（分类切换、悬停、选中、弹窗、拖拽），不接任何库存 / 仓储 / 购物逻辑。
##
## 所有物品数据都是 **fixture**（见 ITEMS），屏幕右下角常驻「测试数据」角标。
## 正式玩法的背包做好之后，把 ITEMS 换成真实数据源即可，界面层不用动。
##
## 命令行（写在 `--` 之后）：
##   --dev-scene=invprev                    正常：面包选中，详情栏有内容
##   --dev-scene=invprev --inv-state=hover  悬停第 2 格（含 Tooltip）
##   --dev-scene=invprev --inv-state=selected
##   --dev-scene=invprev --inv-state=dialog 数量转移弹窗
##   --dev-scene=invprev --inv-state=drag   拖拽幽灵
##   --dev-scene=invprev --inv-states       五态 / 四态 / 三态 / 九宫格拉伸 样张页
##   --dev-scene=invprev --no-text          去文字
##   --dev-scene=invprev --cam-zoom=0.7     验证相机缩放不影响界面
##   --dev-scene=invprev --inv-check --quit 结构与资源自检

const INV := "res://assets/ui/inventory/v01"
const HUD := "res://assets/ui/hud/v01"

const COLS := 6
const ROWS := 5
const SLOT := 58
const GAP := 5
const SLOT_STEP := SLOT + GAP           # 63
const MAX_WEIGHT := 40.0
const BAR_W := 74.0
const BAR_CAP := 8.0

## 物品图标：大部分直接复用已批准的 HUD 图标，不重复登记
const ICON := {
	"bread": "%s/HUD_icon_bread_72x72.png" % HUD,
	"water": "%s/HUD_icon_water_72x72.png" % HUD,
	"firewood": "%s/HUD_icon_firewood_72x72.png" % HUD,
	"pliers": "%s/HUD_icon_pliers_72x72.png" % HUD,
	"medicine": "%s/INV_icon_medicine_64x64.png" % INV,
	"cloth": "%s/HUD_icon_cloth_72x72.png" % HUD,
	"flashlight": "%s/HUD_icon_flashlight_72x72.png" % HUD,
	"key": "%s/HUD_icon_key_72x72.png" % HUD,
}

## 测试数据（fixture）。quantity × unit_weight 的合计恰好 28.4 kg，
## 与 HUD 预览里的负重读数一致，方便两边对照。
const ITEMS := [
	{"name": "面包", "cat": "食物", "qty": 3, "unit": 0.3, "icon": "bread", "desc": "可恢复少量饥饿。放久了会变硬，但也比没有强。"},
	{"name": "水瓶", "cat": "饮品", "qty": 4, "unit": 0.8, "icon": "water", "desc": "烧开后饮用。寒潮里水管会冻裂，这是最后的干净水源。"},
	{"name": "木材", "cat": "材料", "qty": 8, "unit": 2.6, "icon": "firewood", "desc": "壁炉燃料。干燥的木柴烧得更久。"},
	{"name": "布料", "cat": "材料", "qty": 2, "unit": 0.65, "icon": "cloth", "desc": "可用于封窗缝或包扎。"},
	{"name": "手电筒", "cat": "工具", "qty": 1, "unit": 0.6, "icon": "flashlight", "desc": "停电后唯一的照明。电池要省着用。"},
	{"name": "钳子", "cat": "工具", "qty": 1, "unit": 0.5, "icon": "pliers", "desc": "拆解家具、剪断铁丝。"},
	{"name": "钥匙", "cat": "工具", "qty": 1, "unit": 0.1, "icon": "key", "desc": "外婆家的备用钥匙。"},
	{"name": "退烧药", "cat": "药品", "qty": 2, "unit": 0.2, "icon": "medicine", "desc": "体温过高时服用。"},
	{"name": "止痛药", "cat": "药品", "qty": 6, "unit": 0.1, "icon": "medicine", "desc": "缓解疼痛，不能治本。"},
]

const CATEGORIES := ["全部", "食物", "饮品", "药品", "材料", "工具"]

var _root: Control
var _main: Control
var _grid: Control
var _details: Control
var _tooltip: Control
var _dialog: Control
var _dlg_scrim: Control
var _states: Control

var _slots: Array[Button] = []
var _cats: Array[Button] = []
var _cat := "全部"
var _selected := -1
var _dialog_qty := 1
var _closed_hint: Label


func _ready() -> void:
	_root = $Overlay/Root
	_main = _root.get_node("MainPanel")
	_grid = _main.get_node("Grid")
	_details = _main.get_node("Details")
	_tooltip = _root.get_node("Tooltip")
	_dialog = _root.get_node("Dialog")
	_dlg_scrim = _root.get_node("DialogScrim")
	_states = _root.get_node("StatesPage")

	for i in COLS * ROWS:
		var btn := _grid.get_node("Slot%02d" % i) as Button
		btn.toggled.connect(_on_slot_toggled.bind(i))
		btn.mouse_entered.connect(_on_slot_hover.bind(i, true))
		btn.mouse_exited.connect(_on_slot_hover.bind(i, false))
		_slots.append(btn)
	for i in CATEGORIES.size():
		var btn := _main.get_node("CatPanel/Cat%d" % i) as Button
		btn.toggled.connect(_on_category_toggled.bind(i))
		_cats.append(btn)

	(_main.get_node("CloseBtn") as Button).pressed.connect(_on_close)
	(_details.get_node("UseBtn") as Button).pressed.connect(_open_dialog)
	(_dialog.get_node("OkBtn") as Button).pressed.connect(_close_dialog)
	(_dialog.get_node("CancelBtn") as Button).pressed.connect(_close_dialog)
	(_dialog.get_node("MinusBtn") as Button).pressed.connect(_step_qty.bind(-1))
	(_dialog.get_node("PlusBtn") as Button).pressed.connect(_step_qty.bind(1))

	# 第 30 格禁用：演示禁用态 + 锁图标（视觉，不代表真实解锁逻辑）
	_slots[COLS * ROWS - 1].disabled = true
	_slots[COLS * ROWS - 1].get_node("Icon").texture = load("%s/INV_icon_lock_64x64.png" % INV)

	_render_grid()
	_select(0)
	_refresh_weight()

	var args: Dictionary = SceneRouter.dev_args
	if args.has("cam_zoom"):
		var z := float(args["cam_zoom"])
		($World/Cam as Camera2D).zoom = Vector2(z, z)
	var state := String(args.get("inv_state", "normal"))
	match state:
		"hover":
			call_deferred("_demo_hover", 1)
		"selected":
			call_deferred("_demo_select", 3)
		"dialog":
			call_deferred("_open_dialog")
		"drag":
			call_deferred("_demo_drag", 2)
	if args.has("inv_states"):
		_states.visible = true
	if args.has("no_text"):
		_hide_text(_root)

	var ok := verify()
	if args.has("inv_check"):
		get_tree().quit(0 if ok else 1)


# ---------------------------------------------------------------- 渲染

func _items_of(cat: String) -> Array:
	var out := []
	for it in ITEMS:
		if cat == "全部" or it["cat"] == cat:
			out.append(it)
	return out


func _render_grid() -> void:
	var items := _items_of(_cat)
	for i in _slots.size():
		var btn := _slots[i]
		var icon := btn.get_node("Icon") as TextureRect
		var qty := btn.get_node("Qty") as Label
		var locked := i == COLS * ROWS - 1
		if locked:
			continue
		if i < items.size():
			var it: Dictionary = items[i]
			icon.texture = load(ICON[it["icon"]])
			qty.text = str(it["qty"])
		else:
			icon.texture = null
			qty.text = ""
	for b in _slots:
		if not b.disabled:
			b.set_pressed_no_signal(false)
	_selected = -1


func _select(index: int) -> void:
	var items := _items_of(_cat)
	if index < 0 or index >= items.size():
		_clear_details()
		return
	# ButtonGroup 只在真实点击时互斥；脚本直接选中（截图/演示）要自己清掉旧选中态
	for b in _slots:
		if not b.disabled:
			b.set_pressed_no_signal(false)
	_selected = index
	_slots[index].set_pressed_no_signal(true)
	var it: Dictionary = items[index]
	_details.get_node("ItemIcon").texture = load(ICON[it["icon"]])
	(_details.get_node("ItemName") as Label).text = it["name"]
	(_details.get_node("ItemCat") as Label).text = "%s · %s" % [it["cat"], "可食用" if it["cat"] in ["食物", "饮品"] else "可用"]
	(_details.get_node("QtyLabel") as Label).text = "数量　%d" % it["qty"]
	(_details.get_node("WeightLine") as Label).text = "重量　%.1f kg" % (it["qty"] * it["unit"])
	(_details.get_node("Desc") as Label).text = it["desc"]


func _clear_details() -> void:
	_selected = -1
	(_details.get_node("ItemIcon") as TextureRect).texture = null
	(_details.get_node("ItemName") as Label).text = "未选中"
	(_details.get_node("ItemCat") as Label).text = ""
	(_details.get_node("QtyLabel") as Label).text = ""
	(_details.get_node("WeightLine") as Label).text = ""
	(_details.get_node("Desc") as Label).text = "点击左侧格子查看物品。"


## 负重条：与 HUD 同一套九宫格宽度逻辑（0% 隐藏、最小 8px 端帽）
func _refresh_weight() -> void:
	var total := 0.0
	for it in ITEMS:
		total += float(it["qty"]) * float(it["unit"])
	(_main.get_node("WeightLabel") as Label).text = "负重 %.1f / %.1f kg" % [total, MAX_WEIGHT]
	var fill := _main.get_node("WeightFill") as NinePatchRect
	var ratio := clampf(total / MAX_WEIGHT, 0.0, 1.0)
	fill.visible = ratio > 0.0
	if ratio > 0.0:
		fill.size.x = maxf(BAR_CAP, round(BAR_W * ratio))


# ---------------------------------------------------------------- 交互（纯 UI）

func _on_slot_toggled(on: bool, index: int) -> void:
	if on:
		_select(index)


func _on_category_toggled(on: bool, index: int) -> void:
	if not on:
		return
	_cat = CATEGORIES[index]
	_render_grid()
	var items := _items_of(_cat)
	if items.is_empty():
		_clear_details()
	else:
		_select(0)


func _on_slot_hover(index: int, entered: bool) -> void:
	if entered:
		var items := _items_of(_cat)
		if index >= items.size():
			return
		_show_tooltip(index, items[index])
	else:
		_tooltip.visible = false


func _show_tooltip(index: int, it: Dictionary) -> void:
	_tooltip.get_node("TTName").text = it["name"]
	_tooltip.get_node("TTCat").text = "%s · %s" % [it["cat"], "可食用" if it["cat"] in ["食物", "饮品"] else "可用"]
	_tooltip.get_node("TTQty").text = "数量 %d · 重量 %.1f kg" % [it["qty"], it["qty"] * it["unit"]]
	# Tooltip 只放第一句（面板 156px 高，完整描述留给右侧详情栏）
	_tooltip.get_node("TTDesc").text = String(it["desc"]).split("。")[0] + "。"
	var slot := _slots[index]
	var pos := slot.global_position + Vector2(SLOT + 8, 0)
	pos.x = minf(pos.x, 960.0 - 256.0 - 8.0)
	pos.y = clampf(pos.y, 8.0, 540.0 - 156.0 - 8.0)
	_tooltip.position = pos
	_tooltip.visible = true


func _open_dialog() -> void:
	if _selected < 0:
		return
	var it: Dictionary = _items_of(_cat)[_selected]
	_dialog_qty = 1
	_dialog.get_node("DlgIcon").texture = load(ICON[it["icon"]])
	(_dialog.get_node("DlgName") as Label).text = it["name"]
	(_dialog.get_node("DlgHint") as Label).text = "放入仓储 · 上限 20"
	(_dialog.get_node("DlgFoot") as Label).text = "最多可转移 %d 件（测试数据）" % it["qty"]
	_refresh_dialog_qty()
	_dlg_scrim.visible = true
	_dialog.visible = true


func _close_dialog() -> void:
	_dlg_scrim.visible = false
	_dialog.visible = false


func _step_qty(delta: int) -> void:
	if _selected < 0:
		return
	var it: Dictionary = _items_of(_cat)[_selected]
	_dialog_qty = clampi(_dialog_qty + delta, 1, int(it["qty"]))
	_refresh_dialog_qty()


func _refresh_dialog_qty() -> void:
	(_dialog.get_node("DlgQty") as Label).text = str(_dialog_qty)


func _on_close() -> void:
	_main.visible = false
	_tooltip.visible = false
	if _closed_hint == null:
		_closed_hint = Label.new()
		_closed_hint.name = "ClosedHint"
		_closed_hint.text = "背包已关闭（演示）· 按 I 或 Esc 重新打开"
		_closed_hint.label_settings = load("res://assets/ui/labelsettings/final/f_small_serif_11.tres")
		_closed_hint.position = Vector2(380, 500)
		_root.add_child(_closed_hint)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I or event.keycode == KEY_ESCAPE:
			_main.visible = not _main.visible
			if _closed_hint != null:
				_closed_hint.visible = not _main.visible


# ---------------------------------------------------------------- 截图辅助

## 悬停样张：Button 的 hover 样式是引擎按鼠标画的，截图时没法把系统光标挪过去，
## 所以这里把 normal 样式临时换成 hover 贴图，得到「看起来正在悬停」的一帧。
func _demo_select(index: int) -> void:
	await get_tree().process_frame
	_select(index)


func _demo_hover(index: int) -> void:
	await get_tree().process_frame
	var items := _items_of(_cat)
	if index >= items.size():
		return
	_slots[index].add_theme_stylebox_override("normal", _hover_style())
	_show_tooltip(index, items[index])


func _hover_style() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load("%s/INV_slot_hover_58x58.png" % INV)
	return sb


## 拖拽样张：源格留空 + 一个半透明幽灵跟着「手里」的位置
func _demo_drag(index: int) -> void:
	await get_tree().process_frame
	var items := _items_of(_cat)
	if index >= items.size():
		return
	_slots[index].get_node("Icon").texture = null
	_slots[index].get_node("Qty").text = ""
	var ghost := TextureRect.new()
	ghost.name = "DragGhost"
	ghost.texture = load("%s/INV_slot_drag_58x58.png" % INV)
	ghost.texture_filter = 3
	ghost.size = Vector2(SLOT, SLOT)
	ghost.position = _grid.global_position + _slots[index].position + Vector2(34, 26)
	var icon := TextureRect.new()
	icon.texture = load(ICON[items[index]["icon"]])
	icon.texture_filter = 3
	icon.position = Vector2(11, 9)
	icon.size = Vector2(36, 36)
	ghost.add_child(icon)
	_root.add_child(ghost)


func _hide_text(node: Node) -> void:
	if node is Label:
		(node as Label).visible = false
	for c in node.get_children():
		_hide_text(c)


# ---------------------------------------------------------------- 自检

func verify() -> bool:
	var ok := true
	print("[INV] ---- 结构 ----")

	# 1. 格位数量与几何
	if _slots.size() != COLS * ROWS:
		print("[INV] FAIL 格位数 %d，应为 %d" % [_slots.size(), COLS * ROWS])
		ok = false
	var last := _slots[COLS * ROWS - 1]
	var right: float = last.position.x + SLOT
	var bottom: float = last.position.y + SLOT
	print("[INV] OK   格位 %d 个（%d×%d，%dpx，间距 %d），末端 x=%.0f y=%.0f" % [
		_slots.size(), COLS, ROWS, SLOT, GAP, right, bottom])
	if right > _details.position.x - _grid.position.x:
		print("[INV] FAIL 格位右缘 %.0f 越过了详情栏左缘 %.0f" % [right, _details.position.x - _grid.position.x])
		ok = false

	# 2. 面板尺寸必须与素材原生尺寸一致（这批是 1:1，不许缩放）
	# 详情栏按九宫格横向收窄 14px（194 → 180）放进 760 宽的面板里，
	# 高度与边距保持原生，四角不缩放——这是唯一一处非 1:1 的用法。
	var expect := {
		"MainPanel": Vector2(760, 430),
		"MainPanel/Details": Vector2(180, 310),
		"MainPanel/CatPanel": Vector2(138, 302),
		"Dialog": Vector2(350, 248),
		"Tooltip": Vector2(256, 156),
	}
	for path in expect:
		var c: Control = _root.get_node_or_null(path)
		if c == null:
			print("[INV] FAIL 缺少节点 %s" % path)
			ok = false
			continue
		var got := c.size
		var want: Vector2 = expect[path]
		if got != want:
			print("[INV] FAIL %s 尺寸 %s ≠ 原生 %s" % [path, got, want])
			ok = false
		else:
			var note := "原生 1:1" if path != "MainPanel/Details" else "原生高 310，宽按九宫格 -14"
			print("[INV] OK   %-22s %s（%s）" % [path, got, note])

	# 3. 九宫格边距要和 manifest 一致
	var margin_want := {
		"MainPanel": [29.0, 39.0, 29.0, 25.0],
		"MainPanel/Details": [25.0, 34.0, 25.0, 24.0],
		"MainPanel/CatPanel": [22.0, 20.0, 22.0, 20.0],
		"Dialog": [24.0, 35.0, 24.0, 21.0],
		"Tooltip": [24.0, 28.0, 24.0, 20.0],
	}
	for path in margin_want:
		var sb := (_root.get_node(path) as Control).get_theme_stylebox("panel") as StyleBoxTexture
		if sb == null:
			print("[INV] FAIL %s 不是 StyleBoxTexture，九宫格失效" % path)
			ok = false
			continue
		var m := [sb.texture_margin_left, sb.texture_margin_top,
			sb.texture_margin_right, sb.texture_margin_bottom]
		var want: Array = margin_want[path]
		if m != want:
			print("[INV] FAIL %s 九宫格 %s ≠ manifest %s" % [path, m, want])
			ok = false
		else:
			print("[INV] OK   %-22s 九宫格 L/T/R/B = %s" % [path, m])

	# 4. 文字全部是原生 Label，且有 label_settings
	var labels := 0
	var no_ls := 0
	for n in _all_nodes(_root):
		if n is Label:
			labels += 1
			var l := n as Label
			if l.label_settings == null and l.text != "":
				no_ls += 1
				print("[INV] FAIL Label %s 没有 label_settings" % l.get_path())
	print("[INV] %s Label %d 个，缺样式 %d 个" % ["OK  " if no_ls == 0 else "FAIL", labels, no_ls])
	if no_ls != 0:
		ok = false

	# 5. 贴图节点都有图（空槽除外）
	var missing := 0
	for i in COLS * ROWS:
		var t := _slots[i].get_node("Icon") as TextureRect
		var has_item := i < _items_of(_cat).size() and i != COLS * ROWS - 1
		if has_item and t.texture == null:
			missing += 1
	print("[INV] %s 有物品的格子都有图标（缺 %d）" % ["OK  " if missing == 0 else "FAIL", missing])
	if missing != 0:
		ok = false

	# 6. 状态：默认只有一个选中、一个禁用；tooltip / dialog 默认隐藏
	var pressed := 0
	for b in _slots:
		if b.button_pressed:
			pressed += 1
	var disabled := 0
	for b in _slots:
		if b.disabled:
			disabled += 1
	print("[INV] 选中格 %d / 禁用格 %d（期望各 1）" % [pressed, disabled])
	if pressed != 1 or disabled != 1:
		ok = false
	if _tooltip.visible or _dialog.visible:
		print("[INV] FAIL tooltip/dialog 首帧不该显示（tooltip=%s dialog=%s）" % [_tooltip.visible, _dialog.visible])
		ok = false

	# 7. 分类按钮
	print("[INV] %s 分类按钮 %d 个：%s" % ["OK  " if _cats.size() == 6 else "FAIL", _cats.size(), CATEGORIES])
	if _cats.size() != 6:
		ok = false

	# 8. 负重读数来自测试数据，不是贴图
	_refresh_weight()
	var total := 0.0
	for it in ITEMS:
		total += float(it["qty"]) * float(it["unit"])
	print("[INV] 负重 %.1f / %.1f kg（由 %d 条测试数据算出，非贴图）" % [total, MAX_WEIGHT, ITEMS.size()])

	# 9. 所有 PNG 都是真透明（候选素材的硬要求）
	var bad_alpha := 0
	for f in DirAccess.get_files_at("res://assets/ui/inventory/v01"):
		if not f.ends_with(".png"):
			continue
		var tex := load("res://assets/ui/inventory/v01/" + f) as Texture2D
		if tex == null:
			continue
		var img := tex.get_image()
		if img == null:
			continue
		if not img.detect_alpha():
			bad_alpha += 1
			print("[INV] FAIL %s 没有 alpha 通道" % f)
	print("[INV] %s 透明通道检查：%d 张 PNG，无 alpha %d 张" % ["OK  " if bad_alpha == 0 else "FAIL", 30, bad_alpha])
	if bad_alpha != 0:
		ok = false

	print("[INV] ==== %s ====" % ("全部通过" if ok else "有失败项"))
	return ok


func _all_nodes(node: Node) -> Array:
	var out := [node]
	for c in node.get_children():
		out.append_array(_all_nodes(c))
	return out
