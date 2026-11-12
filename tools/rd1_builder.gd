extends SceneTree
## 第一季地图 · 站位规范版生成器
##
## 运行：
##   Godot_v4.7.2-stable_win64_console.exe --headless --path <项目根> --script res://tools/rd1_builder.gd
##
## 这个文件只产出**站位**，不产出画面：
##   - 一条地面线（世界 y=416）+ 坐标标尺
##   - 每个建筑一个标准方框，框上写名称 / 世界尺寸 / 起点 x / 层数 / 门洞尺寸
##   - 每框左下角一个 Anchor（Marker2D），把生成好的图拖到 Anchor 下、position 归零即可对齐
##   - 角色、相机、交互传感器、调试网格保留，用来验比例
##
## 不要在这里加色块、天空、地下层、路灯、标注等任何画面元素 —— 那些由美术图承担。

const OUT_DIR := "res://scenes/world"
const ART_DIR := "res://assets/scenes/season1"   # 已接入的场景图（按 代号_EXT/INT_宽x高_vNN.png 命名）
const GROUND_ART_H := 0.0                        # 0 = 图片 1:1 落地；填数字则压到该世界高度
const S_WORLD := "res://scripts/world/rd1_world.gd"
const S_CAMERA := "res://scripts/characters/follow_camera.gd"
const S_SENSOR := "res://scripts/interaction/interaction_sensor.gd"
const P_PLAYER := "res://scenes/characters/player.tscn"

# ------------------------------------------------ 冻结基准（不要改）
const GROUND := 0.0          # 地面线世界 y（基准原点）
const FLOOR_H := 312.0       # 层高（2.8m，人物 160px ≈ 1.7m）
const DOOR_W := 96.0         # 住宅门
const DOOR_H := 192.0
const DOOR_W_BIG := 192.0    # 商超 / 仓库门
const DOOR_H_BIG := 224.0

# ------------------------------------------------ 配色（深底浅线）
const C_FILL := Color(0.55, 0.70, 0.85, 0.14)
const C_LINE := Color(0.62, 0.74, 0.86, 0.80)
const C_GROUND := Color(0.96, 0.74, 0.38, 0.95)
const C_RULER := Color(0.55, 0.66, 0.76, 0.45)
const C_TEXT := Color(0.90, 0.94, 0.97)
const C_SUB := Color(0.62, 0.71, 0.79)
const C_DOOR := Color(0.96, 0.74, 0.38, 0.55)
const C_ANCHOR := Color(0.96, 0.74, 0.38)

# ------------------------------------------------ 站位数据（唯一来源）
# w/h = 世界尺寸；gap = 与下一栋之间的空档；f = 层数；dw = 门宽（0 表示无门）
# short = 方框里显示的名字
var EXT := [
	{"id":"lane0","short":"","w":480,"h":0,"gap":0,"f":0,"dw":0},
	{"id":"b01","code":"C","short":"C  外置设备区","w":630,"h":350,"gap":180,"f":1,"dw":96},
	{"id":"b02","code":"A/B","art":"A","short":"A/B  外婆旧两层小楼","w":1575,"h":680,"gap":520,"f":2,"dw":96},
	{"id":"b03","code":"F/W","art":"FW","short":"F/W  公告栏 · 住处","w":720,"h":680,"gap":180,"f":2,"dw":0},
	{"id":"b15","code":"","tag":"院墙","short":"小区院墙 · 大门","w":340,"h":300,"gap":140,"f":0,"dw":192},
	{"id":"b04","code":"F/T","art":"FT","short":"F/T  居民楼 1 单元","w":1575,"h":1340,"gap":220,"f":4,"dw":96},
	{"id":"b16","code":"","tag":"楼2","short":"居民楼 2 单元","w":1240,"h":1340,"gap":200,"f":4,"dw":96},
	{"id":"b17","code":"","tag":"车棚","short":"小区车棚","w":790,"h":280,"gap":220,"f":0,"dw":0},
	{"id":"b05","code":"Q","short":"Q  陈叔维修角","w":540,"h":350,"gap":160,"f":1,"dw":96},
	{"id":"b06","code":"R","short":"R  物业门岗","w":540,"h":350,"gap":240,"f":1,"dw":0},
	{"id":"b18","code":"","tag":"垃圾站","short":"垃圾站 · 绿化带","w":560,"h":235,"gap":260,"f":0,"dw":0},
	{"id":"b07","code":"O","short":"O  公交站 · 街角","w":630,"h":260,"gap":340,"f":0,"dw":0},
	{"id":"b08","code":"J","short":"J  唐宁便利店","w":1010,"h":680,"gap":220,"f":2,"dw":96},
	{"id":"b09","code":"N","short":"N  社区药店","w":900,"h":395,"gap":300,"f":1,"dw":96},
	{"id":"b10","code":"H","short":"H  灾前连锁超市","w":1800,"h":520,"gap":240,"f":1,"dw":192},
	{"id":"b11","code":"I","short":"I  五金 · 家电店","w":1350,"h":470,"gap":280,"f":1,"dw":96},
	{"id":"b12","code":"U","short":"U  临时管制路口","w":900,"h":300,"gap":420,"f":0,"dw":0},
	{"id":"b13","code":"K","short":"K  独立批发仓","w":2475,"h":610,"gap":380,"f":1,"dw":192},
	{"id":"b14","code":"L","short":"L  物流中转口","w":1800,"h":505,"gap":260,"f":1,"dw":96},
	{"id":"lane4","short":"","w":480,"h":0,"gap":0,"f":0,"dw":0},
]

var SEGMENTS := [
	{"x":0, "t":"第一段 · 家门 — 梧桐里社区"},
	{"x":11940, "t":"第二段 · 街角 — 商业街"},
	{"x":19280, "t":"第三段 · 批发仓 — 中转点"},
]


func _initialize() -> void:
	print("[MAP] 站位场景生成开始")
	_build()
	print("[MAP] 完成")
	quit(0)


# ============================================================ 主构建
func _build() -> void:
	var total := 0.0
	for b in EXT:
		total += float(b.w) + float(b.gap)

	var root := Node2D.new()
	root.name = "Season1Map"
	root.set_script(load(S_WORLD))
	root.set("location_key", &"season1_map")
	root.set("location_display_name", "第一季 · 梧桐里长街（站位规范）")
	root.set("world_width", total)
	root.set("is_exterior", true)

	var ground := _group(root, "00_Ground")
	var frames := _group(root, "01_Placeholders")
	var art := _group(root, "02_Art")

	_build_ground(ground, total)
	_build_ground_art(ground, total)
	_build_frames(frames, art)
	_build_art_from_disk(art)
	_common_nodes(root, total)
	_save(root, OUT_DIR + "/season1_map.tscn")


# ============================================================ 地面线 + 标尺
func _build_ground(g: Node2D, total: float) -> void:
	var left := -480.0
	var right := total + 480.0
	_line(g, "GroundLine", [Vector2(left, GROUND), Vector2(right, GROUND)], color_alpha(C_GROUND, 0.28), 2.0, 1)
	_label(g, "GroundTag", "地面线  y = 0   ← 所有建筑与美术图的底边必须压在这条线上，向上为负",
		left + 24.0, GROUND + 12.0, 900.0, 16, C_GROUND)

	# 人物标尺（160px）
	_line(g, "BodyRuler", [Vector2(left + 160, GROUND), Vector2(left + 160, GROUND - 160.0)],
		C_GROUND, 2.0, 2)
	_line(g, "BodyRulerTop", [Vector2(left + 140, GROUND - 160.0), Vector2(left + 180, GROUND - 160.0)],
		C_GROUND, 2.0, 2)
	_label(g, "BodyRulerTag", "人物 160px", left + 196.0, GROUND - 172.0, 200.0, 14, C_GROUND)

	# 坐标标尺：每 1000px 一档
	var x := 0.0
	while x <= total:
		var major := fmod(x, 5000.0) < 0.5
		var tick := 26.0 if major else 12.0
		_line(g, "Tick_%d" % int(x), [Vector2(x, GROUND), Vector2(x, GROUND - tick)],
			C_RULER, 1.0 if not major else 2.0, 0)
		if major:
			_label(g, "TickTag_%d" % int(x), "%d" % int(x), x + 6.0, GROUND + 34.0, 120.0, 13, C_SUB)
		x += 1000.0

	# 三段分界（虚线）
	for s in SEGMENTS:
		var sx: float = float(s.x) + 0.0
		var yy := GROUND
		while yy > GROUND - 900.0:
			_line(g, "Seg_%d_%d" % [int(s.x), int(yy)], [Vector2(sx, yy), Vector2(sx, yy - 18.0)],
				color_alpha(C_RULER, 0.55), 1.0, 0)
			yy -= 34.0
		if float(s.x) > 0.0:
			_label(g, "SegTag_%d" % int(s.x), String(s.t), sx + 12.0, GROUND - 930.0, 520.0, 18, C_SUB)


# ============================================================ 地面条带（横向平铺）
# 扫描 ART_DIR 里第一张 GND_*.png，压到 GROUND_ART_H 高，沿地面线横向重复铺满全街。
func _build_ground_art(parent: Node2D, total: float) -> void:
	var dir := DirAccess.open(ART_DIR)
	if dir == null:
		return
	var path := ""
	for f in dir.get_files():
		if f.begins_with("GND_") and f.ends_with(".png"):
			path = ART_DIR + "/" + f
			break
	if path == "":
		print("[MAP] 没有地面图，跳过")
		return
	var tex := load(path) as Texture2D
	if tex == null:
		push_warning("[MAP] 地面图载入失败 " + path)
		return
	var sc := 1.0 if GROUND_ART_H <= 0.0 else GROUND_ART_H / float(tex.get_height())
	var world_w := total + 960.0
	var sp := Sprite2D.new()
	sp.name = "GroundArt"
	sp.texture = tex
	sp.centered = false
	sp.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sp.region_enabled = true
	sp.region_rect = Rect2(0.0, 0.0, world_w / sc, float(tex.get_height()))
	sp.scale = Vector2(sc, sc)
	sp.position = Vector2(-480.0, 0.0)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sp.z_index = -2
	parent.add_child(sp)
	print("[MAP] 地面 %s  scale=%.4f  世界高 %.0f  皮带宽 %.0f" % [
		path.get_file(), sc, float(tex.get_height()) * sc, float(tex.get_width()) * sc])


# ============================================================ 建筑站位方框
func _build_frames(parent: Node2D, art: Node2D) -> void:
	var have := _scan_art()
	var x := 0.0
	var idx := 0
	for b in EXT:
		var w := float(b.w)
		var h := float(b.h)
		var gap := float(b.gap)
		if h > 0.0:
			idx += 1
			_build_one(parent, art, b, x, idx, w, h, have)
		x += w + gap


func _build_one(parent: Node2D, art: Node2D, b: Dictionary, x: float, idx: int,
		w: float, h: float, have: Dictionary = {}) -> void:
	# 组：position = 方框左下角（正好压在地面线上）
	var g := Node2D.new()
	var tag := String(b.get("art", ""))
	if tag == "":
		tag = String(b.get("code", ""))
	if tag == "":
		tag = String(b.get("tag", ""))
	if tag == "":
		tag = String(b.id)
	var node_name := "%02d_%s_%dx%d" % [idx, _slug(tag), int(w), int(h)]
	g.name = node_name
	g.position = Vector2(x, GROUND - h)
	parent.add_child(g)

	# 填充 + 四边线
	var fill := Polygon2D.new()
	fill.name = "Frame"
	fill.polygon = PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)])
	fill.color = C_FILL
	fill.z_index = -1
	g.add_child(fill)
	_line(g, "Edge", [Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h), Vector2(0, 0)],
		C_LINE, 2.0, 2)

	# 落地线（与地面线重合，加粗提示）
	_line(g, "Footprint", [Vector2(0, h), Vector2(w, h)], C_GROUND, 4.0, 3)

	# 门洞位置（底部居中）
	var dw := float(b.dw)
	var has_art := have.has("%s_%dx%d" % [tag, int(w), int(h)])
	if dw > 0.0 and not has_art:
		var big := dw >= 192.0
		var dh := DOOR_H_BIG if big else DOOR_H
		var dx := (w - dw) * 0.5
		_line(g, "DoorSlot", [
			Vector2(dx, h), Vector2(dx, h - dh), Vector2(dx + dw, h - dh), Vector2(dx + dw, h)],
			C_DOOR, 2.0, 3)
		_label(g, "DoorTag", "门 %d×%d" % [int(dw), int(dh)], dx, h - dh - 20.0, dw + 40.0, 12, C_DOOR)

	# 名称 + 规格
	var fs := 28 if w >= 1600.0 else (24 if w >= 900.0 else (20 if w >= 540.0 else 16))
	_label(g, "Name", String(b.short), 10.0, 8.0, w - 20.0, fs, C_TEXT)
	var floors := int(b.f)
	var spec := "%d × %d    x %d – %d" % [int(w), int(h), int(x), int(x + w)]
	if floors > 0:
		spec += "    %dF × %d" % [floors, int(FLOOR_H)]
	_label(g, "Spec", spec, 10.0, 8.0 + fs + 6.0, w - 20.0, 16, C_SUB)
	# 贴地小标：高建筑顶部标在正常镜头里看不见，地面再标一次
	_label(g, "FootTag", "%s   %d×%d   x %d" % [String(b.get("code", b.get("tag", b.id))),
		int(w), int(h), int(x)], 10.0, h - 34.0, w - 20.0, 15, C_GROUND)

	# 对齐锚点：把生成好的图拖到这里，position 归零即可对齐
	var anchor := Marker2D.new()
	anchor.name = "GroundCorner"
	anchor.position = Vector2(0, h)
	anchor.gizmo_extents = 24.0
	g.add_child(anchor)
	_line(g, "AnchorCrossH", [Vector2(-18, h), Vector2(18, h)], C_ANCHOR, 2.0, 4)
	_line(g, "AnchorCrossV", [Vector2(0, h - 18), Vector2(0, h + 18)], C_ANCHOR, 2.0, 4)

	# 02_Art 下预留同名空组，图放这里
	var slot := Node2D.new()
	slot.name = node_name
	slot.position = Vector2(x, GROUND - h)
	art.add_child(slot)


# ============================================================ 已接入的场景图
# 扫描 res://assets/scenes/season1 下按 代号_EXT/INT_宽x高_vNN.png 命名的图，
# 自动挂到同名的 02_Art 插槽里：等比缩放到框宽、底边贴地。
func _scan_art() -> Dictionary:
	var files := {}
	var dir := DirAccess.open(ART_DIR)
	if dir == null:
		return files
	var re := RegEx.new()
	re.compile("^(.+)_(EXT|INT)_(\\d+)x(\\d+)_v\\d+$")
	for f in dir.get_files():
		if not f.ends_with(".png"):
			continue
		var m := re.search(f.get_basename())
		if m == null:
			continue
		files["%s_%sx%s" % [m.get_string(1), m.get_string(3), m.get_string(4)]] = ART_DIR + "/" + f
	return files


func _build_art_from_disk(parent: Node2D) -> void:
	var files := _scan_art()
	if files.is_empty():
		print("[MAP] 没有已接入的图，只出站位")
		return
	var n := 0
	for slot in parent.get_children():
		var key: String = String(slot.name).substr(3)
		if not files.has(key):
			continue
		var dims: PackedStringArray = key.rsplit("_", 1)[1].split("x")
		var bw := float(dims[0])
		var bh := float(dims[1])
		var tex := load(String(files[key])) as Texture2D
		if tex == null:
			push_warning("[MAP] 载入失败 " + String(files[key]))
			continue
		var sc := bw / float(tex.get_width())
		# 图片底部常有透明行，按"内容底边"贴地，而不是按画布底边
		var bottom := float(tex.get_height())
		var im := tex.get_image()
		if im != null:
			if im.is_compressed():
				im.decompress()
			var y0: int = maxi(0, im.get_height() - 160)
			for y in range(im.get_height() - 1, y0 - 1, -1):
				var hit := false
				var x := 0
				while x < im.get_width():
					if im.get_pixel(x, y).a > 0.08:
						hit = true
						break
					x += 6
				if hit:
					bottom = float(y + 1)
					break
		var hh := bottom * sc
		var sp := Sprite2D.new()
		sp.name = "Art"
		sp.texture = tex
		sp.centered = false
		sp.scale = Vector2(sc, sc)
		sp.position = Vector2(0.0, bh - hh)
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sp.z_index = 0
		slot.add_child(sp)
		n += 1
		print("[MAP] 接图 %s  scale=%.4f  在框内高 %.0f/%.0f" % [key, sc, hh, bh])
	print("[MAP] 已接入 %d 张场景图" % n)


# ============================================================ 角色 / 相机 / UI
func _common_nodes(root: Node2D, width: float) -> void:
	root.set("spawn_x", 1480.0)
	root.set("spawn_y", GROUND)
	var actors := _group(root, "Actors")
	var ps := load(P_PLAYER) as PackedScene
	var pl := ps.instantiate()
	pl.name = "Player"
	pl.set("z_index", 5)
	actors.add_child(pl)

	var interact := _group(root, "Interaction")
	var sensor := Node2D.new()
	sensor.name = "InteractionSensor"
	sensor.set_script(load(S_SENSOR))
	sensor.set("actor_path", NodePath("../Actors/Player"))
	sensor.z_index = 20
	interact.add_child(sensor)

	var cam := Camera2D.new()
	cam.name = "Camera2D"
	cam.set_script(load(S_CAMERA))
	cam.set("target_path", NodePath("../Actors/Player"))
	cam.set("look_offset", Vector2(0, -210))
	cam.set("dead_zone", Vector2(56, 48))
	cam.limit_left = -480
	cam.limit_right = int(width) + 480
	cam.limit_top = -1500
	cam.limit_bottom = 900
	root.add_child(cam)

	var ui := CanvasLayer.new()
	ui.name = "UI"
	root.add_child(ui)

	var guides := _group(root, "DebugGuides")
	guides.visible = false
	var gx := 0.0
	while gx <= width:
		_line(guides, "GridV_%d" % int(gx), [Vector2(gx, -1500), Vector2(gx, 200)],
			Color(0.95, 0.45, 0.35, 0.22), 1.0, 60)
		gx += 320.0
	for gy in [0, -312, -624, -936, -1248]:
		_line(guides, "GridH_%d" % int(gy), [Vector2(0, gy), Vector2(width, gy)],
			Color(0.95, 0.45, 0.35, 0.22), 1.0, 60)


# ============================================================ 工具
func _group(parent: Node, n: String) -> Node2D:
	var g := Node2D.new()
	g.name = n
	parent.add_child(g)
	return g


func _line(parent: Node, n: String, pts: Array, c: Color, w: float = 2.0, z: int = 1) -> Line2D:
	var l := Line2D.new()
	l.name = n
	l.width = w
	l.default_color = c
	l.z_index = z
	var arr := PackedVector2Array()
	for p in pts:
		arr.append(Vector2(p))
	l.points = arr
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	parent.add_child(l)
	return l


func _label(parent: Node, n: String, txt: String, x: float, y: float,
		w: float, fs: int, c: Color) -> Label:
	var l := Label.new()
	l.name = n
	l.position = Vector2(x, y)
	l.size = Vector2(w, float(fs) + 8.0)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.08, 0.10, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 10
	l.text = txt
	l.add_to_group(&"layout_label")
	parent.add_child(l)
	return l


func color_alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


func _slug(id: String) -> String:
	return id.replace("/", "-")


func _save(root: Node2D, path: String) -> void:
	_own(root, root)
	var ps := PackedScene.new()
	var e := ps.pack(root)
	if e != OK:
		push_error("[MAP] pack failed err=%d" % e)
		return
	var e2 := ResourceSaver.save(ps, path)
	print("[MAP] saved %s err=%d nodes=%d w=%.0f" % [
		path.get_file(), e2, _count(root), float(root.get("world_width"))])
	root.free()


func _own(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		if c.scene_file_path == "":
			_own(c, root)


func _count(n: Node) -> int:
	var k := 1
	for c in n.get_children():
		k += _count(c)
	return k
