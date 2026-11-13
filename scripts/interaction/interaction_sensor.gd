class_name InteractionSensor
extends Node2D
## CORE-001B · 近距离热点探测 + E 单次派发 + 中文提示
##
## 职责只有三件：
##   1) 每物理帧问一遍「玩家现在压着哪些能交互的热点」（用 Area2D.overlaps_body）；
##   2) 从中选**唯一**一个目标，选择规则固定且可复现（见 `_pick`）；
##   3) 按 E 时只向这一个目标派发一次 `interact(actor)`，同一帧不会派发第二次。
##
## 提示框由本节点自己画在世界坐标里：它属于**正式 UI**（玩家要看得到），
## 因此不受开发叠加层 F3 开关影响。字体取主工程主题的默认字体，不引入新字体。

signal target_changed(target: Interactable)
signal interacted(target: Interactable)

## 玩家节点路径；留空则用 group "player" 的第一个节点
@export var actor_path: NodePath
@export var enabled: bool = true
## 提示框相对锚点的偏移（负 y = 往上）
@export var prompt_offset: Vector2 = Vector2(0, -14)
## 是否由本节点在世界坐标里画提示框。
## TASK-UI-009 之后，正式玩法场景改由 CanvasLayer 里的 GameHud 画屏幕空间提示
## （世界坐标画法会跟着相机缩放，街道 0.7× 时 13px 字实际只有 9px），
## 这种情况下宿主把它关掉；门/室内的老场景默认保持原样。
@export var draw_world_prompt: bool = true:
	set(value):
		draw_world_prompt = value
		if is_inside_tree():
			queue_redraw()

const THEME_PATH := "res://assets/ui/themes/main_theme.tres"
const FALLBACK_FONT := "res://assets/ui/fonts/NotoSansSC-Variable.ttf"

var actor: Node2D
## 当前锁定目标，null 表示附近没有可交互对象
var current: Interactable
## 诊断用：本次运行累计派发次数与最后一次派发的目标
var interact_count: int = 0
var last_target: Interactable

var _font: Font
var _prompt_bg := Color(0.05, 0.06, 0.07, 0.88)
var _prompt_line := Color(0.96, 0.72, 0.35, 0.95)
var _prompt_text_c := Color(0.97, 0.97, 0.96)


func _ready() -> void:
	z_index = 20
	_resolve_actor()
	_load_font()


func _resolve_actor() -> void:
	if actor_path != NodePath() and actor_path != NodePath(""):
		actor = get_node_or_null(actor_path) as Node2D
	if actor == null:
		var ps := get_tree().get_nodes_in_group(&"player")
		if ps.size() > 0:
			actor = ps[0] as Node2D


## 字体优先取主工程主题；主题里没有才退回字体文件本身
func _load_font() -> void:
	var th := load(THEME_PATH) as Theme
	if th != null and th.default_font != null:
		_font = th.default_font
		return
	var f := load(FALLBACK_FONT) as Font
	_font = f if f != null else ThemeDB.fallback_font


func _physics_process(_delta: float) -> void:
	# 场景切换时本节点会短暂脱离树，此时 get_tree() 为 null
	if not is_inside_tree() or get_tree() == null:
		return
	if actor == null:
		_resolve_actor()
		return
	if not enabled:
		_set_target(null)
		return
	_set_target(_pick())
	# 提示文案会随状态变（购物车「推」→「停车」），而 CanvasItem 的 draw 指令是**保留**的：
	# 只靠 target_changed 重绘会让旧文案一直留在屏幕上。目标存在时每帧重绘一次。
	if current != null and draw_world_prompt:
		queue_redraw()


## 当前压在玩家身上的可交互热点（已按 can_interact 过滤）
func candidates() -> Array[Interactable]:
	var out: Array[Interactable] = []
	if actor == null or not is_inside_tree() or get_tree() == null:
		return out
	for n in get_tree().get_nodes_in_group(&"interactable"):
		var it := n as Interactable
		if it == null:
			continue
		if not it.can_interact(actor):
			continue
		if not it.overlaps_body(actor):
			continue
		out.append(it)
	return out


## 选择规则（必须稳定，不能逐帧抖）：
##   1. priority 大者优先；
##   2. 同优先级比水平距离，近者优先；
##   3. 距离差 < 1px 时**不掉进浮点抖动的坑**，改用实例顺序兜底，保证同一帧/相邻帧结果一致。
func _pick() -> Interactable:
	var best: Interactable = null
	var best_d := 0.0
	for it in candidates():
		var d := absf(it.global_position.x - actor.global_position.x)
		if best == null:
			best = it
			best_d = d
			continue
		if it.interact_priority != best.interact_priority:
			if it.interact_priority > best.interact_priority:
				best = it
				best_d = d
			continue
		if absf(d - best_d) > 1.0:
			if d < best_d:
				best = it
				best_d = d
		elif it.get_instance_id() < best.get_instance_id():
			best = it
			best_d = d
	return best


## 主动派发一次交互（键盘 E 与自动化测试共用同一入口）。
## 返回实际被触发的热点；附近没有可用热点时返回 null 且不产生任何副作用。
func request_interact() -> Interactable:
	if not enabled or actor == null:
		return null
	# 重新取一次，避免用上一物理帧缓存的目标（热点可能刚被禁用 / 玩家刚走开）
	var target := _pick()
	_set_target(target)
	if target == null:
		return null
	target.interact(actor)
	interact_count += 1
	last_target = target
	interacted.emit(target)
	return target


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event.is_action_pressed(&"interact"):
		request_interact()
		# 门会在 request_interact() 内部切场景，本节点可能已经脱树；
		# 脱树后调用 get_viewport() 会报 "Condition !is_inside_tree() is true"。
		if is_inside_tree():
			get_viewport().set_input_as_handled()


func _set_target(t: Interactable) -> void:
	if t == current:
		return
	current = t
	queue_redraw()
	# 打日志：桌面端与 Web 端都靠这行断言「提示出现了 / 消失了」，因为提示是画在画布里的
	print("[HINT] 目标=%s 提示=%s" % [t.name if t else "无", t.prompt_text() if t else "-"])
	target_changed.emit(t)


# ------------------------------------------------------------------ 提示框

func _draw() -> void:
	if not enabled or not draw_world_prompt or current == null or _font == null:
		return
	var anchor := current.prompt_anchor() + prompt_offset
	# 换成局部坐标：本节点放在场景原点，相机缩放 1:1
	var p := to_local(anchor + Vector2(0, -26))
	var text := current.prompt_text()
	var fs := 13
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var box := Rect2(p.x - tw * 0.5 - 9.0, p.y, tw + 18.0, 25.0)
	draw_rect(box, _prompt_bg, true, -1.0, false)
	draw_rect(box, _prompt_line, false, 1.0, false)
	# 指向热点的小三角，避免提示看起来属于旁边的物件
	draw_colored_polygon(PackedVector2Array([
		Vector2(p.x - 5.0, box.position.y + box.size.y),
		Vector2(p.x + 5.0, box.position.y + box.size.y),
		Vector2(p.x, box.position.y + box.size.y + 6.0),
	]), _prompt_line)
	draw_string(_font, Vector2(box.position.x + 9.0, box.position.y + 17.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _prompt_text_c)
