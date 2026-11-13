extends SceneTree
## 背包候选素材预览 · 交互端到端测试（TASK-UI-010）
##
## 只验证「界面层」：结构、五态、分类切换、点击格子、悬停详情、弹窗、
## 关闭/重开、相机缩放不耦合、透明通道。**不验证任何库存/仓储/购物逻辑**——
## 那些系统尚未开发，本场景也没有实现。
##
##   Godot_v4.7.2-stable_win64_console.exe --headless --path <项目根> --script res://tools/inventory_e2e.gd

const SCENE := "res://scenes/dev/inventory_preview.tscn"

var fails := 0


func _initialize() -> void:
	_run()


func _wait(n: int = 4) -> void:
	for i in n:
		await process_frame
	for i in n:
		await physics_frame


func _ok(msg: String) -> void:
	print("[INV-E2E] OK   %s" % msg)


func _fail(msg: String) -> void:
	fails += 1
	print("[INV-E2E] FAIL %s" % msg)


func _check(cond: bool, msg: String) -> void:
	if cond:
		_ok(msg)
	else:
		_fail(msg)


func _press(code: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	await _wait(2)


## 真鼠标：把系统光标移到控件中心，送 motion + down + up 进视口
func _click(ctl: Control) -> void:
	var center: Vector2 = ctl.global_position + ctl.size / 2.0
	get_root().warp_mouse(center)
	var move := InputEventMouseMotion.new()
	move.position = center
	move.global_position = center
	Input.parse_input_event(move)
	await _wait(2)
	for on in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = on
		ev.position = center
		ev.global_position = center
		Input.parse_input_event(ev)
		await _wait(2)


func _run() -> void:
	await _wait(3)
	change_scene_to_file(SCENE)
	await _wait(8)

	var s := current_scene
	if s == null or s.get_node_or_null("Overlay") == null:
		_fail("预览场景未加载")
		quit(1)
		return

	var layer := s.get_node("Overlay") as CanvasLayer
	var root := layer.get_node("Root") as Control
	var main := root.get_node("MainPanel") as Control
	var details := main.get_node("Details") as Control
	var grid := main.get_node("Grid") as Control
	var tooltip := root.get_node("Tooltip") as Control
	var dialog := root.get_node("Dialog") as Control
	var name_label := details.get_node("ItemName") as Label

	# 1) 结构自检（复用场景自带的 verify）
	_check(bool(s.call("verify")), "场景 verify() 全部通过")

	# 2) 屏幕空间 HUD
	_check(layer is CanvasLayer and root.size == Vector2(960, 540),
		"CanvasLayer + Control 960×540（实际 %s）" % root.size)
	_check(s.get_node("World") is Node2D, "背景在 World(Node2D)，与 UI 分离")

	# 3) 真鼠标点分类按钮 → 分类切换（纯 UI 演示，数据仍是 fixture）
	var cat3 := main.get_node("CatPanel/Cat3") as Button
	await _click(cat3)
	_check(name_label.text == "退烧药", "点「药品」后详情首项 = %s" % name_label.text)
	_check(cat3.button_pressed and not (main.get_node("CatPanel/Cat0") as Button).button_pressed,
		"分类按钮互斥：Cat3 选中、Cat0 取消")

	# 4) 弹窗与数量步进（此时选中「退烧药」，qty=2）
	s.call("_open_dialog")
	await _wait(2)
	_check(dialog.visible and (root.get_node("DialogScrim") as Control).visible, "弹窗 + 遮罩打开")
	var qty := dialog.get_node("DlgQty") as Label
	_check(qty.text == "1", "初始数量 1")
	for i in 3:
		s.call("_step_qty", 1)
	await _wait(2)
	_check(qty.text == "2", "加号夹到该物品上限 2（实际 %s）" % qty.text)
	s.call("_step_qty", -1)
	await _wait(2)
	_check(qty.text == "1", "减号回到 1")
	s.call("_close_dialog")
	await _wait(2)
	_check(not dialog.visible, "确认/取消后弹窗关闭")

	# 5) 点击格子
	s.call("_on_slot_toggled", true, 1)
	await _wait(2)
	_check(name_label.text == "止痛药", "点第 2 格后详情 = %s" % name_label.text)
	var pressed := 0
	for b in grid.get_children():
		if b is Button and (b as Button).button_pressed:
			pressed += 1
	_check(pressed == 1, "同时只有 1 个格子选中（实际 %d）" % pressed)

	# 6) 悬停详情
	s.call("_on_slot_hover", 0, true)
	await _wait(2)
	_check(tooltip.visible and String((tooltip.get_node("TTName") as Label).text) == "退烧药",
		"悬停第 1 格弹出 Tooltip：%s" % (tooltip.get_node("TTName") as Label).text)
	_check(tooltip.position.x >= 0.0 and tooltip.position.x + tooltip.size.x <= 960.0,
		"Tooltip 完整落在 960 宽内（x=%.0f..%.0f）" % [tooltip.position.x, tooltip.position.x + tooltip.size.x])
	s.call("_on_slot_hover", 0, false)
	await _wait(2)
	_check(not tooltip.visible, "移开后 Tooltip 隐藏")

	# 7) 真键盘：I / Esc 关闭与重开
	await _press(KEY_I)
	_check(not main.visible, "按 I 关闭背包")
	await _press(KEY_ESCAPE)
	_check(main.visible, "按 Esc 重新打开背包")

	# 8) 真鼠标点第 1 格 → 选中并更新详情
	var target := grid.get_node("Slot00") as Button
	await _click(target)
	_check(name_label.text == "退烧药" and target.button_pressed,
		"真鼠标点击第 1 格 → 选中并更新详情（%s / pressed=%s）" % [name_label.text, target.button_pressed])

	# 9) 相机缩放不改变 UI
	var before_pos := main.global_position
	var before_size := main.size
	var cam := s.get_node("World/Cam") as Camera2D
	for z in [0.7, 1.6]:
		cam.zoom = Vector2(z, z)
		await _wait(4)
		_check(main.global_position == before_pos and main.size == before_size,
			"相机 zoom %.1f 后面板位置 %s 尺寸 %s 不变" % [z, main.global_position, main.size])

	# 弹窗按钮都用九宫格贴图（四态齐全）
	var dlg_bad := 0
	for nm in ["MinusBtn", "PlusBtn", "OkBtn", "CancelBtn"]:
		var b := dialog.get_node(nm) as Button
		for st in ["normal", "hover", "pressed", "disabled"]:
			if not (b.get_theme_stylebox(st) is StyleBoxTexture):
				dlg_bad += 1
	_check(dlg_bad == 0, "弹窗 4 个按钮的 normal/hover/pressed/disabled 均为九宫格贴图")

	# 10) 测试数据被如实标出
	var badge := main.get_node("MockBadge") as Label
	_check(badge.visible and badge.text.find("测试数据") >= 0, "测试数据角标常驻：%s" % badge.text)

	# 11) 九宫格：小按钮裁掉透明边后边距之和 < 控件宽
	var minus := dialog.get_node("MinusBtn") as Button
	var sb := minus.get_theme_stylebox("normal") as StyleBoxTexture
	_check(sb != null and sb.region_rect.size.x > 0.0
		and sb.texture_margin_left + sb.texture_margin_right < minus.size.x,
		"小按钮用 region_rect 裁透明边，边距之和 < 控件宽（%s）" % [
			sb.region_rect if sb != null else "null"])

	# 12) TASK-UI-011：详情栏不拥挤、Tooltip 动态高度、占位图与状态一致性
	var desc_l := details.get_node("Desc") as Label
	var use_b := details.get_node("UseBtn") as Button
	_check(use_b.position.y - (desc_l.position.y + desc_l.size.y) >= 8.0,
		"详情栏描述与按钮间距 ≥8px（实际 %.0f）" % [use_b.position.y - (desc_l.position.y + desc_l.size.y)])
	var sb_dbtn := use_b.get_theme_stylebox("normal") as StyleBoxTexture
	_check(sb_dbtn != null and sb_dbtn.region_rect.size.x > 0.0,
		"详情按钮用 region_rect 裁透明边，九宫格不塌")

	var items_all: Array = s.call("_items_of", "全部")
	s.call("_show_tooltip", 1, items_all[1])
	_check(tooltip.size.y > 156.0, "长描述 Tooltip 自动增高到 %.0f" % tooltip.size.y)
	_check(String((tooltip.get_node("TTDesc") as Label).text) == String(items_all[1]["desc"]),
		"Tooltip 显示完整描述（不是第一句）")
	_check(tooltip.position.y + tooltip.size.y <= 540.0, "长描述 Tooltip 底部不出屏")
	s.call("_on_slot_hover", 1, false)

	# 最底行格子：Tooltip 应被顶回屏幕内
	s.call("_show_tooltip", 26, items_all[1])
	_check(tooltip.position.y >= 0.0 and tooltip.position.y + tooltip.size.y <= 540.0,
		"底行格子 Tooltip 被夹紧到 y=%.0f..%.0f" % [tooltip.position.y, tooltip.position.y + tooltip.size.y])
	s.call("_on_slot_hover", 26, false)
	# 最右列格子：Tooltip 应被夹回屏幕内
	s.call("_show_tooltip", 5, items_all[1])
	_check(tooltip.position.x >= 0.0 and tooltip.position.x + tooltip.size.x <= 960.0,
		"右列格子 Tooltip 被夹紧到 x=%.0f..%.0f" % [tooltip.position.x, tooltip.position.x + tooltip.size.x])
	s.call("_on_slot_hover", 5, false)
	s.call("_show_tooltip", 0, items_all[5])
	_check(tooltip.size.y == 156.0, "单句描述 Tooltip 回到原生 156px（实际 %.0f）" % tooltip.size.y)
	s.call("_on_slot_hover", 0, false)

	# 图标映射与明确占位图
	var icon_audit: Dictionary = s.get("ICON_AUDIT")
	_check(icon_audit.size() == 9 and String(icon_audit["布料"]) == "cloth"
		and String(icon_audit["退烧药"]) == "", "图标映射审计表：7 专图 / 2 占位，无错误映射")
	var slot0 := grid.get_node("Slot00") as Button
	var slot1 := grid.get_node("Slot01") as Button
	s.call("_on_category_toggled", true, 3)
	await _wait(2)
	for sl in [slot0, slot1]:
		_check((sl.get_node("Icon") as TextureRect).texture == null
			and (sl.get_node("Ph") as Control).visible,
			"无正式图标的 %s 槽位显示明确占位图" % sl.name)
	_check(String((details.get_node("ItemCat") as Label).text).find("图标待补") >= 0,
		"详情栏如实标注「图标待补」：%s" % (details.get_node("ItemCat") as Label).text)

	# 悬停已选中格子：仍保持选中贴图，不出现两种高亮
	s.call("_on_slot_hover", 0, true)
	var hsb := slot0.get_theme_stylebox("hover") as StyleBoxTexture
	_check(hsb != null and String(hsb.texture.resource_path).ends_with("INV_slot_selected_58x58.png"),
		"选中格被悬停时 hover 仍用选中贴图（视觉一致）")
	s.call("_on_slot_hover", 0, false)

	print("[INV-E2E] ==== %d 项失败 ====" % fails)
	quit(0 if fails == 0 else 1)
