class_name CoreOverlay
extends Node2D
## CORE-001A 开发用叠加层：把「碰撞盒 / 可见包围盒 / 脚底锚点 / 净宽余量」画出来。
##
## 只存在于开发实验场景，不进入正式玩法。画在世界坐标里，相机 zoom = 1 时与游戏像素 1:1。

@export var player_path: NodePath
@export var show_overlay: bool = true

const COL_COLLIDE := Color(0.886, 0.341, 0.302)
const COL_VISIBLE := Color(0.941, 0.659, 0.290)
const COL_FOOT := Color(0.455, 0.761, 0.525)
const COL_TEXT := Color(0.95, 0.96, 0.97)
const FONT_PATH := "res://assets/ui/fonts/NotoSansSC-Variable.ttf"

var _player: CharacterBody2D
var _font: Font


func _ready() -> void:
	_player = get_node_or_null(player_path) as CharacterBody2D
	_font = load(FONT_PATH)
	if _font == null:
		_font = ThemeDB.fallback_font
	z_index = 10


func _process(_delta: float) -> void:
	if show_overlay:
		queue_redraw()


func _draw() -> void:
	if _player == null:
		return
	var origin := _player.global_position
	var coll: Rect2 = _player.collision_rect()
	var vis: Rect2 = _player.visible_bbox()

	var coll_w := Rect2(coll.position + origin, coll.size)
	var vis_w := Rect2(vis.position + origin, vis.size)

	# 碰撞盒
	_rect_fill(coll_w, Color(COL_COLLIDE.r, COL_COLLIDE.g, COL_COLLIDE.b, 0.14))
	_box(coll_w, COL_COLLIDE, 1.0)
	# 可见包围盒（虚线）
	_dash_box(vis_w, COL_VISIBLE)
	# 脚底锚点
	draw_line(Vector2(origin.x - 8, origin.y), Vector2(origin.x + 8, origin.y), COL_FOOT, 3.0)
	draw_line(Vector2(origin.x, origin.y - 8), Vector2(origin.x, origin.y + 8), COL_FOOT, 3.0)

	# 尺寸标注：两条横线叠在脚下，文字跟在线的右端，避免与人物和标尺抢位
	var y1 := origin.y + 40.0
	var x1 := origin.x + coll.position.x
	_hline(Vector2(x1, y1), coll.size.x, COL_COLLIDE)
	_plate_text(x1 + coll.size.x + 6.0, y1 - 2.0, "碰撞 %d" % int(coll.size.x), 9, COL_COLLIDE)

	var y2 := origin.y + 56.0
	var x2 := origin.x + vis.position.x
	_hline(Vector2(x2, y2), vis.size.x, COL_VISIBLE)
	_plate_text(x2 + vis.size.x + 6.0, y2 - 2.0, "可见 %d×%d" % [int(vis.size.x), int(vis.size.y)], 9, COL_VISIBLE)

	# 画布与锚点说明放到画布上方，别压到头发；加深色底板，压在货架上也读得清
	_plate_text(origin.x - 152.0, origin.y - 200.0, "画布 128×176", 9, Color(0.80, 0.84, 0.88))
	_plate_text(origin.x - 152.0, origin.y - 186.0, "锚点 (64,168)", 9, Color(0.80, 0.84, 0.88))


## 带深色底板的文字
func _plate_text(x: float, y: float, s: String, size: int, c: Color) -> void:
	if _font == null:
		return
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_rect(Rect2(x - 2.0, y - size, w + 4.0, size + 3.0), Color(0.04, 0.05, 0.06, 0.72), true, -1.0, false)
	_text(x, y, s, size, c)


func _hline(a: Vector2, w: float, c: Color) -> void:
	draw_line(a, Vector2(a.x + w, a.y), c, 1.0)
	draw_line(Vector2(a.x, a.y - 3), Vector2(a.x, a.y + 3), c, 1.0)
	draw_line(Vector2(a.x + w, a.y - 3), Vector2(a.x + w, a.y + 3), c, 1.0)


func _rect_fill(r: Rect2, c: Color) -> void:
	draw_rect(r, c, true, -1.0, false)


func _box(r: Rect2, c: Color, w: float) -> void:
	draw_rect(r, c, false, w, false)


func _dash_box(r: Rect2, c: Color) -> void:
	var step := 6.0
	var gap := 4.0
	var x := r.position.x
	while x < r.position.x + r.size.x:
		draw_line(Vector2(x, r.position.y), Vector2(minf(x + step, r.position.x + r.size.x), r.position.y), c, 1.0)
		draw_line(Vector2(x, r.position.y + r.size.y),
			Vector2(minf(x + step, r.position.x + r.size.x), r.position.y + r.size.y), c, 1.0)
		x += step + gap
	var y := r.position.y
	while y < r.position.y + r.size.y:
		draw_line(Vector2(r.position.x, y), Vector2(r.position.x, minf(y + step, r.position.y + r.size.y)), c, 1.0)
		draw_line(Vector2(r.position.x + r.size.x, y),
			Vector2(r.position.x + r.size.x, minf(y + step, r.position.y + r.size.y)), c, 1.0)
		y += step + gap


func _text(x: float, y: float, s: String, size: int, c: Color) -> void:
	if _font == null:
		return
	draw_string(_font, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


func _text_center(cx: float, y: float, s: String, size: int, c: Color) -> void:
	if _font == null:
		return
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(_font, Vector2(cx - w * 0.5, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
