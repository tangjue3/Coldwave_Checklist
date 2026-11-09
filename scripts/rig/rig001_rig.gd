class_name Rig001Character
extends Node2D
## ART-RIG-001：许知夏 2D 骨骼角色（技术原型 / 待美术审核）
##
## 定位：**隔离的技术验证件**，不参与正式玩法，不进素材台账与运行时白名单，
## 不替换 PlayerController 的 r09 扶车动画，也不改动任何冻结物理参数。
##
## 结构：Node2D(本节点，原点=脚底) → Skeleton2D(平移到 -画布锚点) → Bone2D 树 → 每骨一个 Sprite2D。
## 所有骨骼/图层/关节坐标都来自 `rig001_spec.json`（tools/make_rig001_layers.py 生成），
## 换正式分层素材时只改 spec 里的 layer 文件名，骨骼树不用重建。
##
## 坐标约定（与全项目一致）：
##   - 本节点原点 = 角色脚底；画布 128×176，锚点 (64,168)；
##   - spec 里的 origin/tip 都是画布像素坐标，y 向下；
##   - 贴图 1:1、Nearest，禁止缩放。
##
## 旋转约定（刚性 Cutout，不做网格变形）：
##   - 骨骼静止角 = 骨轴方向 atan2(tip-origin)；
##   - Sprite2D 作为骨骼子节点，用 rotation = -静止角 抵消父链旋转，
##     所以静止时图层保持画布朝向；骨骼转动 δ 时图层跟着转 δ，绕关节旋转；
##   - 因此**静止姿态下合成结果 == 源图逐像素相等**（由 rig001 用例断言）。

const SPEC_PATH := "res://assets/dev/rig001_proto/rig001_spec.json"
const ANCHOR := Vector2(64.0, 168.0)

## 播放的动画名（与 AnimationLibrary 里的键一致）
const ANIM_IDLE := &"idle"
const ANIM_WALK := &"walk_right"

var spec: Dictionary = {}
var skeleton: Skeleton2D
var player: AnimationPlayer

var bones: Dictionary = {}     # name -> Bone2D
var layers: Dictionary = {}    # layer -> Sprite2D
var rest_abs: Dictionary = {}  # name -> 静止绝对角（弧度，画布系）
var origin: Dictionary = {}    # name -> 画布坐标 Vector2
var bone_parent: Dictionary = {}

var load_error: String = ""


## 构建整棵树 + 动画。autoplay=false 时停在静止姿态（分层还原度比对用）。
func build(autoplay := true) -> bool:
	var text := FileAccess.get_file_as_string(SPEC_PATH)
	if text.is_empty():
		load_error = "读不到 %s" % SPEC_PATH
		push_error("[RIG001] " + load_error)
		return false
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		load_error = "spec JSON 解析失败"
		push_error("[RIG001] " + load_error)
		return false
	spec = parsed
	if int(spec.get("canvas", {}).get("w", 0)) != 128 or int(spec.get("canvas", {}).get("h", 0)) != 176:
		load_error = "spec 画布尺寸不是 128×176"
		push_error("[RIG001] " + load_error)
		return false

	skeleton = Skeleton2D.new()
	skeleton.name = "Skeleton2D"
	skeleton.position = -ANCHOR
	add_child(skeleton)

	# --- 1) 先记录每根骨的静止绝对角与画布原点 ---
	for b in spec["bones"]:
		var name := String(b["name"])
		origin[name] = Vector2(b["origin"][0], b["origin"][1])
		rest_abs[name] = deg_to_rad(float(b["rest_rot_deg"]))
		bone_parent[name] = String(b["parent"]) if b["parent"] != null else ""

	# --- 2) 建骨骼（spec 已保证父在子前）---
	for b in spec["bones"]:
		var name := String(b["name"])
		var parent := String(bone_parent[name])
		var bone := Bone2D.new()
		bone.name = name
		# 关闭"按子骨自动长度/角度"，我们要用 spec 里实测的关节角
		if bone.has_method("set_autocalculate_length_and_angle"):
			bone.set_autocalculate_length_and_angle(false)
		var pa: float = rest_abs[parent] if parent != "" else 0.0
		var po: Vector2 = origin[parent] if parent != "" else Vector2.ZERO
		bone.position = (origin[name] - po).rotated(-pa)
		bone.rotation = rest_abs[name] - pa
		bone.set_meta("rest_abs", rest_abs[name])
		if parent == "":
			skeleton.add_child(bone)
		else:
			(bones[parent] as Bone2D).add_child(bone)
		bones[name] = bone

	# --- 3) 有图层的骨挂 Sprite2D ---
	for b in spec["bones"]:
		if not b.has("layer"):
			continue
		var layer := String(b["layer"])
		var tex_path := String(spec["layer_dir"]) + layer + ".png"
		var tex := load(tex_path) as Texture2D
		if tex == null:
			load_error = "贴图缺失 %s" % tex_path
			push_error("[RIG001] " + load_error)
			return false
		var spr := Sprite2D.new()
		spr.name = layer
		spr.texture = tex
		spr.centered = false
		spr.offset = -origin[String(b["name"])]
		spr.rotation = -rest_abs[String(b["name"])]
		spr.z_index = int(b.get("z", 0))
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		(bones[String(b["name"])] as Bone2D).add_child(spr)
		layers[layer] = spr

	# --- 4) 动画 ---
	player = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	add_child(player)
	player.root_node = player.get_path_to(self)
	var lib := AnimationLibrary.new()
	lib.add_animation(ANIM_IDLE, Rig001Gait.bake(self, ANIM_IDLE))
	lib.add_animation(ANIM_WALK, Rig001Gait.bake(self, ANIM_WALK))
	player.add_animation_library(&"", lib)
	if autoplay:
		player.play(ANIM_WALK)
	return true


## 骨骼在画布坐标下的当前世界位置（把骨骼原点点变换回画布系）
func bone_canvas_pos(name: String) -> Vector2:
	var b: Bone2D = bones[name]
	var xf := get_global_transform_with_canvas()
	# 场景刚进树 / 视口还没尺寸时画布变换可能是退化的，这里直接退化为"按 rig 局部算"
	if absf(xf.determinant()) < 1e-6:
		return ANCHOR + (b.get_global_transform().origin - get_global_transform().origin)
	var local: Vector2 = xf.affine_inverse() * b.get_global_transform().origin
	return local + ANCHOR


## 当前播放动画与时间
func current_animation() -> StringName:
	return player.current_animation if player else &""


func play(anim: StringName) -> void:
	if player and player.has_animation(anim):
		player.play(anim)


## 定格在某个动画的某一时刻（截图/姿势检查用）
func freeze(anim: StringName, t: float) -> void:
	if player == null or not player.has_animation(anim):
		return
	player.play(anim)
	player.seek(t, true)
	player.pause()


## 把当前骨骼姿态写成一串可读文本（用例对断言"首尾连续"用）
func pose_snapshot() -> Dictionary:
	var out := {}
	for name in bones.keys():
		out[name] = (bones[name] as Bone2D).rotation
	return out


## 分层素材是否齐全（用例用）
func layer_count() -> int:
	return layers.size()


## 单个图层按当前骨骼变换后的画布系包围盒（把图层四角真正变换过去，不再忽略旋转）
func layer_canvas_bbox(layer: String) -> Rect2:
	var spr: Sprite2D = layers[layer]
	if spr == null or spr.texture == null:
		return Rect2()
	var img := spr.texture.get_image()
	if img == null:
		return Rect2()
	var used := img.get_used_rect()
	var gt := get_global_transform()
	if absf(gt.determinant()) < 1e-6:
		return Rect2()
	var xf: Transform2D = gt.affine_inverse() * spr.get_global_transform()
	var pts: Array[Vector2] = []
	for corner in [Vector2(used.position), Vector2(used.position.x + used.size.x, used.position.y),
			Vector2(used.position.x, used.position.y + used.size.y),
			Vector2(used.position.x + used.size.x, used.position.y + used.size.y)]:
		pts.append(xf * (corner + spr.offset) + ANCHOR)
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r


## 所有图层的画布系包围盒并集，用来验证"人物比例稳定"
func composed_bbox() -> Rect2:
	var r := Rect2()
	var first := true
	for layer in layers.keys():
		var rect := layer_canvas_bbox(String(layer))
		if rect.size == Vector2.ZERO:
			continue
		r = rect if first else r.merge(rect)
		first = false
	return r
