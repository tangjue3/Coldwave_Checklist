class_name GameHud
extends CanvasLayer
## 正式游戏 HUD（TASK-UI-009）
##
## 结构：`CanvasLayer(layer=20) → Root(Control 960×540)`。
## **屏幕空间**：CanvasLayer 不参与相机变换，所以角色移动、相机缩放（街道 0.7×）
## 都不会让 HUD 跟着缩放或抖动——这一点由 tools/hud_e2e.gd 逐项断言。
##
## 图形：素材包 v01 的透明 PNG（assets/ui/hud/v01/）。
## 文字：TASK-UI-006 定稿的 LabelSettings（final/）——标题/正文/数值用思源宋体，
##       今日清单的任务正文用霞鹜文楷。判断栏挂在 Label 上，换面板底图不影响文字。
##
## 数据：`HudSource` 接口。默认 HudSourceLive（地点=真数据，其余=测试数据）。
##       测试数据会在右上角标出来，不冒充已实现玩法。
##
## 快捷键：1–6 切快捷栏，T 展开/收起今日清单，点击今日清单标题同样可切换。

const THEME_PATH := "res://assets/ui/themes/font_theme.tres"
const TEX_DIR := "res://assets/ui/hud/v01"

const SLOT_COUNT := 6
const TASK_ROWS := 4
const BAR_W := 74.0      ## 轨道内宽（78 − 左右各 2px 定位）
const BAR_CAP := 8.0     ## 左右各 4px 端帽，窄于此九宫格会塌
const TASKS_FULL_SIZE := Vector2(216, 152)
const TASKS_HEAD_SIZE := Vector2(216, 35)

const PANEL_FILES := {
	"location": "HUD_panel_location_432x70.png",
	"datetime": "HUD_panel_datetime_272x70.png",
	"weather": "HUD_panel_weather_260x70.png",
	"tasks": "HUD_panel_tasks_432x304.png",
	"status": "HUD_panel_status_432x328.png",
	"resource": "HUD_panel_resource_484x70.png",
	"interact": "HUD_panel_interact_356x70.png",
}
const ICON_NAMES := ["home", "calendar", "snowflake", "checklist", "chevron_up", "chevron_down",
	"checkbox_empty", "checkbox_checked", "temperature", "hunger", "thirst", "fatigue",
	"weight", "cash", "firewood", "cloth", "flashlight", "water", "bread", "pliers", "key"]

const MOCK_LABELS := {
	"datetime": "时间", "weather": "天气", "tasks": "任务",
	"status": "生存", "resources": "物资", "hotbar": "快捷栏",
}

signal slot_selected(index: int)
signal tasks_collapsed_changed(collapsed: bool)

@export var show_mock_badge: bool = true
@export var start_collapsed: bool = false

var source: HudSource
var selected_slot: int = 1
var tasks_collapsed: bool = false
var mock_fields := PackedStringArray()
## 宿主场景可以覆盖地点名（室内用自己 display_name 的缩写，比查表更准）
var location_override: String = ""

var _root: Control
var _theme: Theme
var _panels := {}
var _icons := {}
var _slot_tex := {}
var _ls := {}


func _ready() -> void:
	layer = 20
	_root = $Root
	_theme = load(THEME_PATH) as Theme
	_load_assets()
	source = HudSourceLive.new()
	_connect_tasks_hit()
	refresh()
	select_slot(1)
	set_tasks_collapsed(start_collapsed, false)
	($Root/InteractPanel as Control).visible = false
	_keep_theme()
	print("[GAME-HUD] ready source=%s mock=%s" % [source.describe(), ", ".join(mock_fields)])


func _load_assets() -> void:
	for key in PANEL_FILES:
		_panels[key] = load("%s/%s" % [TEX_DIR, PANEL_FILES[key]])
	for n in ICON_NAMES:
		_icons[n] = load("%s/HUD_icon_%s_72x72.png" % [TEX_DIR, n])
	_slot_tex["normal"] = load("%s/HUD_slot_normal_90x90.png" % TEX_DIR)
	_slot_tex["selected"] = load("%s/HUD_slot_selected_90x90.png" % TEX_DIR)
	for n in ["f_title_serif_18", "f_body_serif_14", "f_value_serif_12",
			"f_task_wenkai_14", "f_task_done_wenkai_14", "f_small_serif_11"]:
		_ls[n] = load("res://assets/ui/labelsettings/final/%s.tres" % n)


# ------------------------------------------------------------------ 数据

## 换数据源（开发预览 / 测试用），随后立刻刷新一次
func set_source(src: HudSource) -> void:
	source = src
	refresh()


func refresh() -> void:
	if source == null:
		return
	var d := source.snapshot()
	var loc := String(d.get("location", ""))
	if location_override != "":
		loc = location_override
	(_root.get_node("LocationPanel/LocationText") as Label).text = loc
	(_root.get_node("DateTimePanel/DateText") as Label).text = String(d.get("datetime", ""))
	(_root.get_node("WeatherPanel/WeatherText") as Label).text = String(d.get("weather", ""))
	mock_fields = d.get("mock", PackedStringArray())
	_apply_mock_badge()
	_apply_tasks(d.get("tasks", []))
	_apply_status(d.get("status", []))
	_apply_resources(d.get("resources", []))
	_apply_hotbar(d.get("hotbar", []))


## 测试数据必须露在外面：右上角常驻一行 11px 说明，不给「已经实现」的错觉
func _apply_mock_badge() -> void:
	var badge := _root.get_node_or_null("MockBadge") as Label
	if badge == null:
		return
	var names := PackedStringArray()
	for f in mock_fields:
		if MOCK_LABELS.has(f):
			names.append(String(MOCK_LABELS[f]))
	badge.visible = show_mock_badge and names.size() > 0
	if badge.visible:
		badge.text = "测试数据 · " + " / ".join(names)


func _apply_tasks(tasks: Array) -> void:
	for i in TASK_ROWS:
		var row := _root.get_node_or_null("TasksPanel/TaskList/TaskRow%d" % (i + 1)) as Control
		if row == null:
			continue
		if i >= tasks.size():
			row.visible = false
			continue
		row.visible = true
		var d: Dictionary = tasks[i]
		var done := bool(d.get("done", false))
		(row.get_node("Box") as TextureRect).texture = _icons["checkbox_checked" if done else "checkbox_empty"]
		var txt := row.get_node("Text") as Label
		txt.text = String(d.get("text", ""))
		txt.label_settings = _ls["f_task_done_wenkai_14"] if done else _ls["f_task_wenkai_14"]
		var strike := row.get_node("Strike") as ColorRect
		strike.visible = done
		if done:
			strike.size.x = minf(_text_width(txt), txt.size.x)


func _apply_status(rows: Array) -> void:
	for i in 5:
		var d: Dictionary = rows[i] if i < rows.size() else {}
		var icon := _root.get_node("StatusPanel/StatIcon%d" % i) as TextureRect
		icon.texture = _icon(String(d.get("icon", "")))
		(_root.get_node("StatusPanel/StatLabel%d" % i) as Label).text = String(d.get("label", ""))
		(_root.get_node("StatusPanel/StatValue%d" % i) as Label).text = String(d.get("value", ""))
		_set_bar("StatusPanel/StatFill%d" % i, float(d.get("ratio", 0.0)))


func _apply_resources(items: Array) -> void:
	var keys := [["ResCashIcon", "ResCashText"], ["ResWoodIcon", "ResWoodText"],
		["ResClothIcon", "ResClothText"]]
	for i in keys.size():
		var d: Dictionary = items[i] if i < items.size() else {}
		(_root.get_node("ResourcePanel/" + keys[i][0]) as TextureRect).texture = _icon(String(d.get("icon", "")))
		(_root.get_node("ResourcePanel/" + keys[i][1]) as Label).text = String(d.get("text", ""))


func _apply_hotbar(items: Array) -> void:
	for i in SLOT_COUNT:
		var d: Dictionary = items[i] if i < items.size() else {}
		var slot := _root.get_node_or_null("Slot%d" % (i + 1)) as TextureRect
		if slot == null:
			continue
		(slot.get_node("SlotIcon") as TextureRect).texture = _icon(String(d.get("icon", "")))
		var qty := slot.get_node("SlotQty") as Label
		qty.text = String(d.get("qty", ""))
		qty.visible = qty.text != ""


# ------------------------------------------------------------------ 进度条

## 只改九宫格宽度，不动贴图尺寸：左右 4px 端帽由 patch_margin 保住。
func _set_bar(fill_path: String, ratio: float) -> void:
	var fill := _root.get_node_or_null(fill_path) as NinePatchRect
	if fill == null:
		return
	var r := clampf(ratio, 0.0, 1.0)
	fill.visible = r > 0.0
	if r > 0.0:
		fill.size.x = maxf(BAR_CAP, round(BAR_W * r))


# ------------------------------------------------------------------ 快捷栏

func select_slot(index: int) -> void:
	selected_slot = clampi(index, 1, SLOT_COUNT)
	for i in SLOT_COUNT:
		var slot := _root.get_node_or_null("Slot%d" % (i + 1)) as TextureRect
		if slot != null:
			slot.texture = _slot_tex["selected"] if i + 1 == selected_slot else _slot_tex["normal"]
	slot_selected.emit(selected_slot)


# ------------------------------------------------------------------ 今日清单展开 / 收起

## 收起时换成同宽度的短面板贴图（432×70），不缩放、不裁切，圆角完整。
func set_tasks_collapsed(collapsed: bool, notify: bool = true) -> void:
	tasks_collapsed = collapsed
	var panel := _root.get_node("TasksPanel") as TextureRect
	var list := _root.get_node("TasksPanel/TaskList") as Control
	var divider := _root.get_node("TasksPanel/TasksDivider") as ColorRect
	var chevron := _root.get_node("TasksPanel/TasksChevron") as TextureRect
	list.visible = not collapsed
	divider.visible = not collapsed
	panel.texture = _panels["location"] if collapsed else _panels["tasks"]
	panel.size = TASKS_HEAD_SIZE if collapsed else TASKS_FULL_SIZE
	chevron.texture = _icons["chevron_down" if collapsed else "chevron_up"]
	if notify:
		tasks_collapsed_changed.emit(collapsed)


func toggle_tasks() -> void:
	set_tasks_collapsed(not tasks_collapsed)


func _connect_tasks_hit() -> void:
	var hit := _root.get_node_or_null("TasksPanel/TasksHit") as Button
	if hit != null and not hit.pressed.is_connected(toggle_tasks):
		hit.pressed.connect(toggle_tasks)


# ------------------------------------------------------------------ 交互提示

## 把场景里的 InteractionSensor 接进来：由 HUD 统一在屏幕空间显示提示，
## 关掉传感器原本画在世界坐标里的提示框（那套会跟着相机缩放，街道 0.7× 时只有 9px）。
func bind_sensor(sensor: Node) -> void:
	if sensor == null:
		return
	if "draw_world_prompt" in sensor:
		sensor.set("draw_world_prompt", false)
	if not sensor.is_connected("target_changed", _on_target_changed):
		sensor.connect("target_changed", _on_target_changed)
	_on_target_changed(sensor.get("current"))


func _on_target_changed(target) -> void:
	if target == null:
		hide_prompt()
		return
	var text: String = target.prompt_text()
	# 传感器的文案自带「E 」前缀，而 HUD 有独立键帽，去掉重复
	if text.begins_with("E "):
		text = text.substr(2)
	# 门只在场景里填了 door_label，没填 prompt_subject，提示会退化成「进入」；
	# 这里用门自带的标签补出目的地。纯显示层，不改门的行为，也不动老场景。
	if text == "进入" and "door_label" in target:
		var door_label := String(target.get("door_label"))
		if door_label != "":
			text = "进入 %s" % door_label
	show_prompt(text)


func show_prompt(text: String) -> void:
	var panel := _root.get_node("InteractPanel") as Control
	(_root.get_node("InteractPanel/InteractText") as Label).text = text
	panel.visible = true


func hide_prompt() -> void:
	(_root.get_node("InteractPanel") as Control).visible = false


# ------------------------------------------------------------------ 输入

func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode >= KEY_1 and k.keycode <= KEY_6:
		select_slot(k.keycode - KEY_0)
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_T:
		toggle_tasks()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ 工具

func _icon(name: String) -> Texture2D:
	if _icons.has(name):
		return _icons[name]
	return _icons["checklist"]


func _text_width(label: Label) -> float:
	if label.label_settings == null or label.label_settings.font == null:
		return label.size.x
	return label.label_settings.font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT,
		-1, label.label_settings.font_size).x


## UiTheme autoload 会把 main_theme 盖到没有 theme 的 Control 上；
## HUD 有自己的字体主题，开局几帧反复压回去（和 font_preview 同一处理）。
func _keep_theme() -> void:
	for i in 4:
		await get_tree().process_frame
		_stamp(self)


func _stamp(node: Node) -> void:
	var c := node as Control
	if c != null:
		c.theme = _theme
	for child in node.get_children():
		_stamp(child)


# ------------------------------------------------------------------ 自检

## 供 tools/hud_e2e.gd 调用：结构、数据绑定、进度条、快捷栏、展开收起
func verify() -> bool:
	var ok := true
	print("[GAME-HUD] ==== 结构自检 ====")
	var layer_ok := _root.get_parent() is CanvasLayer
	print("[GAME-HUD] %s CanvasLayer(layer=%d) → Control %d×%d" % [
		"OK  " if layer_ok else "FAIL", layer, int(_root.size.x), int(_root.size.y)])
	if not layer_ok:
		ok = false

	var labels := 0
	var bad := 0
	for l in _all_labels(_root):
		if not l.visible:
			continue
		labels += 1
		if l.label_settings == null or l.label_settings.font == null:
			print("[GAME-HUD] FAIL 标签 %s 没有 label_settings" % l.name)
			bad += 1
	print("[GAME-HUD] %s 动态文字 %d 个 Label，全部由 LabelSettings 渲染" % ["OK  " if bad == 0 else "FAIL", labels])
	if bad > 0:
		ok = false

	var tex_bad := 0
	for n in _all_nodes(_root):
		if n is TextureRect and (n as TextureRect).texture == null and (n as CanvasItem).visible:
			tex_bad += 1
	print("[GAME-HUD] %s 贴图节点缺失 %d 个" % ["OK  " if tex_bad == 0 else "FAIL", tex_bad])
	if tex_bad > 0:
		ok = false

	print("[GAME-HUD] 地点=%s / 时间=%s / 天气=%s / 测试字段=%s" % [
		(_root.get_node("LocationPanel/LocationText") as Label).text,
		(_root.get_node("DateTimePanel/DateText") as Label).text,
		(_root.get_node("WeatherPanel/WeatherText") as Label).text,
		", ".join(mock_fields)])
	print("[GAME-HUD] 快捷栏选中=%d / 今日清单收起=%s / 提示可见=%s" % [
		selected_slot, tasks_collapsed, (_root.get_node("InteractPanel") as Control).visible])
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
