extends Node2D
## ART-RIG-001 · 许知夏 2D 骨骼动画技术验证场景（独立、隔离、可整目录删除）
##
## 不依赖 PlayerController / PushableCart / 任何正式玩法代码；
## 不改 r09 默认动画、不改购物车逻辑与冻结物理参数。
##
## 命令行（写在 `--` 之后）：
##   --dev-scene=rig001                 交互预览：1 idle / 2 walk / F1 骨骼 / F2 三倍放大 / 空格 播放暂停
##   --dev-scene=rig001 --rig001-test   跑技术验收用例（约 34 条）
##   --dev-scene=rig001 --rig001-tour   出检查点截图（原始对照/骨骼图/关键姿势/放大）
##   --dev-scene=rig001 --rig001-gif    出 40 帧行走连拍（供 GIF 组装）
##   --dev-scene=rig001 --rig001-world  出 8 帧世界坐标移动连拍（固定地面刻度）
##   --rig001-seams                     只跑关节裂缝检测
##
## 坐标：本场景是独立画布，角色脚底落在 GROUND_Y 线上。

const SHOT_DIR := "res://tests/screenshots"
const FONT_PATH := "res://assets/ui/fonts/NotoSansSC-Variable.ttf"
const SOURCE_PNG := "res://assets/characters/ART_CHAR_001_r02_walk_right_00_contactA.png"
const SPEC_PATH := "res://assets/dev/rig001_proto/rig001_spec.json"

## 屏幕布局
const GROUND_Y := 420.0
const CHAR_X := 200.0
## 骨骼步态设计速度（由 spec 的 step/(duty*cycle) 推出，70 px/s）
const SPEED := 70.0

## 关键姿势相位（接触 / 下沉 / 经过 / 抬升）
const KEY_PHASES := [0.0, 0.15, 0.30, 0.45]

var _rig: Rig001Character
var _args: Dictionary = {}
var _font: Font
var _anim: StringName = &"walk_right"
var _t: float = 0.0
var _playing: bool = true
var _show_bones: bool = false
var _zoom3: bool = false
var _travel_x: float = 0.0

var _pass: int = 0
var _fail: int = 0
var _fail_msgs: Array[String] = []


func _ready() -> void:
	_args = SceneRouter.dev_args if SceneRouter else {}
	_font = load(FONT_PATH)
	if _font == null:
		_font = ThemeDB.fallback_font
	_build_rig()
	_apply_layout()

	if _args.has("rig001_test"):
		await _run_tests()
	elif _args.has("rig001_tour"):
		await _run_tour()
	elif _args.has("rig001_gif"):
		await _run_gif()
	elif _args.has("rig001_idle"):
		await _run_idle()
	elif _args.has("rig001_world"):
		await _run_world()
	elif _args.has("rig001_seams"):
		await _run_seams()
	elif _args.has("rig001_bones"):
		# 三倍放大 + 骨骼线 + 关节名：给美术看的"骨骼位置示意图"
		_show_bones = true
		_zoom3 = true
		_apply_layout()
		_anim = &"idle"
		_set_pose(0.0)
		await _capture("rig001_bones_debug.png")
		if _args.has("quit"):
			get_tree().quit(0)
	elif _args.has("quit"):
		get_tree().quit(0)


func _build_rig() -> void:
	_rig = Rig001Character.new()
	_rig.name = "Rig001"
	add_child(_rig)
	if not _rig.build():
		push_error("[RIG001] 构建失败：%s" % _rig.load_error)


func _apply_layout() -> void:
	if _zoom3:
		# 三倍放大时把脚底放到画面下部，保证整个人物在画面内
		_rig.scale = Vector2(3, 3)
		_rig.position = Vector2(320.0, 522.0)
	else:
		_rig.scale = Vector2.ONE
		_rig.position = Vector2(CHAR_X, GROUND_Y)


func _process(delta: float) -> void:
	if _playing and _rig and _rig.player:
		_t += delta
		_rig.player.seek(fmod(_t, _cycle()), true)
	queue_redraw()


func _cycle() -> float:
	return float(_rig.spec["gait"]["cycle_seconds"]) if _rig else 1.0


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_1:
			_anim = &"idle"
			_t = 0.0
			_rig.play(_anim)
		KEY_2:
			_anim = &"walk_right"
			_t = 0.0
			_rig.play(_anim)
		KEY_F1:
			_show_bones = not _show_bones
		KEY_F2:
			_zoom3 = not _zoom3
			_apply_layout()
		KEY_SPACE:
			_playing = not _playing


# ------------------------------------------------------------------ 绘制

func _screen_of(canvas: Vector2) -> Vector2:
	return _rig.position + (canvas - Rig001Character.ANCHOR) * _rig.scale.x


func _draw() -> void:
	# 地面 + 固定刻度（世界坐标参照，用来目视检查脚滑）
	var gy: float = _rig.position.y if _rig else GROUND_Y
	draw_line(Vector2(0, gy), Vector2(960, gy), Color(0.42, 0.46, 0.5), 1.0)
	for i in range(0, 960, 16):
		var major := (i % 80) == 0
		var h := 10.0 if major else 4.0
		draw_line(Vector2(i, gy), Vector2(i, gy + h),
			Color(0.55, 0.6, 0.65) if major else Color(0.36, 0.39, 0.43), 1.0)
		if major:
			_text("x=%d" % int(i - CHAR_X), Vector2(i + 2, gy + 24), 10, Color(0.5, 0.55, 0.6))

	if _rig == null:
		return
	if _show_bones:
		_draw_bones()
	_draw_hud()


func _draw_bones() -> void:
	var cols := {
		"pelvis": Color(0.95, 0.75, 0.2), "chest": Color(0.95, 0.55, 0.2),
		"neck": Color(0.9, 0.9, 0.3), "head": Color(0.35, 0.85, 0.45),
		"hair_tail": Color(0.8, 0.45, 0.9),
	}
	for name in _rig.bones.keys():
		var b: Bone2D = _rig.bones[name]
		var o := _screen_of(_rig.bone_canvas_pos(String(name)))
		# 骨段画到子骨原点（没有子骨就按 spec 的 tip 方向补一段）
		var children: Array = []
		for other in _rig.bones.keys():
			if String(_rig.bone_parent[String(other)]) == String(name):
				children.append(other)
		var col: Color = cols.get(String(name), Color(0.3, 0.65, 0.95))
		if children.is_empty():
			var ang := _abs_now(String(name))
			var base := _rig.bone_canvas_pos(String(name))
			draw_line(o, _screen_of(base + Vector2(cos(ang), sin(ang)) * 10.0),
				Color(col.r, col.g, col.b, 0.55), 1.0)
		for c in children:
			var co := _screen_of(_rig.bone_canvas_pos(String(c)))
			draw_line(o, co, col, 2.0)
		draw_circle(o, 3.0, Color(1, 1, 1, 0.95))
		draw_circle(o, 1.6, col)
		if _zoom3:
			_text(String(name), o + Vector2(5, -4), 10, Color(0.95, 0.85, 0.3))


## 当前骨骼链的绝对角（画布系，弧度）：逐级累加局部旋转
func _abs_now(name: String) -> float:
	var a: float = (_rig.bones[name] as Bone2D).rotation
	var p := String(_rig.bone_parent[name])
	while p != "":
		a += (_rig.bones[p] as Bone2D).rotation
		p = String(_rig.bone_parent[p])
	return a


func _draw_hud() -> void:
	if _font == null:
		return
	var spec := _rig.spec
	var lines := [
		"ART-RIG-001  许知夏 骨骼技术原型（技术验证 / 待美术审核）",
		"Godot %s · Skeleton2D + Bone2D ×%d · 图层 ×%d · 1:1 Nearest" % [
			Engine.get_version_info()["string"], _rig.bones.size(), _rig.layer_count()],
		"动画 %s · t=%.2fs · 步态循环 %.1fs · 设计步速 %.0f px/s" % [
			String(_anim), fmod(_t, _cycle()), _cycle(), SPEED],
		"F1 骨骼  F2 三倍放大  空格 暂停  1 待机  2 行走",
	]
	for i in lines.size():
		_text(lines[i], Vector2(16, 24 + i * 16), 12 if i == 0 else 11,
			Color(0.92, 0.94, 0.96) if i == 0 else Color(0.66, 0.7, 0.75))
	if _show_bones:
		_text("骨骼调试：白点=关节原点（Bone2D origin），彩线=骨骼父子关系", Vector2(16, 96), 11, Color(0.6, 0.85, 1.0))


func _text(s: String, pos: Vector2, size: int, c: Color) -> void:
	if _font == null:
		return
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


# ------------------------------------------------------------------ 截图

func _capture(filename: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s" % [SHOT_DIR, filename]
	var err := img.save_png(path)
	print("[SHOT] %s err=%d" % [filename, err])


func _set_pose(t: float) -> void:
	_t = t
	_playing = false
	if _rig and _rig.player:
		_rig.player.play(_anim)
		_rig.player.speed_scale = 0.0
		_rig.player.seek(t, true)


# ------------------------------------------------------------------ 各模式

func _run_tour() -> void:
	# 静止姿态直出（与源图逐像素比对的原始证据，带透明背景）
	var still: Image = await _render_still()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	still.save_png("%s/rig001_rest_render.png" % SHOT_DIR)
	print("[SHOT] rig001_rest_render.png")

	_anim = &"idle"
	_set_pose(0.0)
	await _capture("rig001_scene_idle.png")

	_anim = &"walk_right"
	for i in KEY_PHASES.size():
		_set_pose(float(KEY_PHASES[i]))
		await _capture("rig001_pose_%d.png" % i)

	_show_bones = true
	_set_pose(0.0)
	await _capture("rig001_bones_debug.png")
	_show_bones = false

	_zoom3 = true
	_apply_layout()
	_set_pose(0.15)
	await _capture("rig001_zoom3.png")
	_zoom3 = false
	_apply_layout()
	_set_pose(0.0)
	print("[RIG001] tour 完成")
	if _args.has("quit"):
		get_tree().quit(0)


func _run_gif() -> void:
	# 25 帧 = 一个 1.0s 循环；GIF 用 40ms/帧 组装即真实速度。
	# 角色同时按 70px/s 前进，地面刻度固定不动 —— 这样 GIF 本身就是"脚不滑"的证据。
	_anim = &"walk_right"
	var frames := 25
	for i in frames:
		var t := float(i) / float(frames)
		_rig.position.x = CHAR_X + SPEED * t
		_set_pose(t)
		await _capture("rig001_walk_%02d.png" % i)
	_rig.position.x = CHAR_X
	print("[RIG001] gif 帧 %d 张" % frames)
	if _args.has("quit"):
		get_tree().quit(0)


func _run_idle() -> void:
	# 20 帧 = 一个 2.4s 待机循环；GIF 用 120ms/帧 组装即真实速度
	_anim = &"idle"
	var frames := 20
	for i in frames:
		_set_pose(Rig001Gait.IDLE_SECONDS * float(i) / float(frames))
		await _capture("rig001_idle_%02d.png" % i)
	print("[RIG001] idle 帧 %d 张" % frames)
	if _args.has("quit"):
		get_tree().quit(0)


func _run_world() -> void:
	# 固定地面刻度 + 角色按 70px/s 前进，动画相位与位移严格同步（等价于正式游戏里的移动）
	_anim = &"walk_right"
	var frames := 8
	var dx := 70.0 / float(frames)  # 一整个步态循环走 70px
	for i in frames:
		var t := float(i) / float(frames)
		_rig.position.x = CHAR_X + 70.0 * t
		_set_pose(t)
		await _capture("rig001_world_%02d.png" % i)
	_rig.position.x = CHAR_X
	print("[RIG001] world 帧 %d 张" % frames)
	if _args.has("quit"):
		get_tree().quit(0)


# ------------------------------------------------------------------ 用例

func _ok(label: String, cond: bool, detail := "") -> int:
	if cond:
		_pass += 1
		print("[T] 通过  %s%s" % [label, "" if detail == "" else "（%s）" % detail])
		return 0
	_fail += 1
	_fail_msgs.append(label)
	print("[T] 失败  %s%s" % [label, "" if detail == "" else "（%s）" % detail])
	return 1


func _near(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func _sha256_file(path: String) -> String:
	var ctx := HashingContext.new()
	if ctx.start(HashingContext.HASH_SHA256) != OK:
		return ""
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return ""
	ctx.update(bytes)
	return ctx.finish().hex_encode()


## 渲染一份静止姿态的骨骼角色到独立视口，返回图像（用于像素级还原比对）
func _render_still() -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(128, 176)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.disable_3d = true
	add_child(vp)
	# 先让视口完成一次布局，否则首帧画布变换退化（affine_invert 会刷 det==0 告警）
	await get_tree().process_frame
	var r := Rig001Character.new()
	vp.add_child(r)
	r.build(false)
	r.position = Rig001Character.ANCHOR
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img


## 渲染指定动画相位，返回图像（关节裂缝检测用）
func _render_pose(t: float) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(128, 176)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.disable_3d = true
	add_child(vp)
	# 先让视口完成一次布局，否则首帧画布变换退化（affine_invert 会刷 det==0 告警）
	await get_tree().process_frame
	var r := Rig001Character.new()
	vp.add_child(r)
	r.build(true)
	r.position = Rig001Character.ANCHOR
	r.player.play(&"walk_right")
	r.player.seek(t, true)
	r.player.pause()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img


## 图像内部是否出现被不透明像素包围的透明孔（关节裂缝）
func _hole_stats(img: Image) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var bg := {}
	var q: Array[Vector2i] = []
	for x in w:
		q.append(Vector2i(x, 0))
		q.append(Vector2i(x, h - 1))
	for y in h:
		q.append(Vector2i(0, y))
		q.append(Vector2i(w - 1, y))
	while not q.is_empty():
		var p: Vector2i = q.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			continue
		if bg.has(p):
			continue
		if img.get_pixel(p.x, p.y).a > 0.5:
			continue
		bg[p] = true
		q.append(p + Vector2i(1, 0))
		q.append(p + Vector2i(-1, 0))
		q.append(p + Vector2i(0, 1))
		q.append(p + Vector2i(0, -1))
	# 上体（y<110）的封闭孔才算"关节露缝"；y≥110 的孔是两条大腿之间的正常背景缝，
	# 腿交叉时会短暂闭合，不属于分层缺陷。
	var box := Rect2i()
	var upper := 0
	var lower := 0
	var first := true
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a <= 0.5 and not bg.has(Vector2i(x, y)):
				if y < 110:
					upper += 1
				else:
					lower += 1
				if first:
					box = Rect2i(x, y, 1, 1)
					first = false
				else:
					box = box.expand(Vector2i(x, y)).expand(Vector2i(x + 1, y + 1))
	return {"upper": upper, "lower": lower, "bbox": box}


func _run_seams() -> void:
	print("========== ART-RIG-001 关节裂缝检测 ==========")
	var total := 0
	for i in 12:
		var t := float(i) / 12.0
		var img: Image = await _render_pose(t)
		var st := _hole_stats(img)
		total += int(st["upper"])
		print("[SEAM] t=%.2f 上体封闭孔 %d px / 腿间缝 %d px bbox=%s"
			% [t, int(st["upper"]), int(st["lower"]), str(st["bbox"])])
		if int(st["upper"]) + int(st["lower"]) > 0:
			img.save_png("%s/rig001_seam_%02d.png" % [SHOT_DIR, i])
	print("[SEAM] 上体封闭孔合计 %d px" % total)
	if _args.has("quit"):
		get_tree().quit(0)


func _run_tests() -> void:
	print("========== ART-RIG-001 骨骼技术验证 ==========")
	_playing = false
	_rig.player.speed_scale = 0.0
	var spec := _rig.spec

	# --- A. 资源与层级 ---
	_ok("spec 载入，骨骼 18 根", _rig.bones.size() == 18, "%d 根" % _rig.bones.size())
	_ok("spec 画布 128×176 锚点 (64,168)",
		int(spec["canvas"]["w"]) == 128 and int(spec["canvas"]["h"]) == 176
		and Vector2(spec["canvas"]["anchor"][0], spec["canvas"]["anchor"][1]) == Rig001Character.ANCHOR)
	_ok("图层 16 张全部载入", _rig.layer_count() == 16, "%d 张" % _rig.layer_count())
	var size_ok := true
	for layer in _rig.layers.keys():
		var tex: Texture2D = (_rig.layers[layer] as Sprite2D).texture
		if tex.get_width() != 128 or tex.get_height() != 176:
			size_ok = false
	_ok("16 张图层均为 128×176", size_ok)
	var alpha_ok := true
	for layer in _rig.layers.keys():
		var img := (_rig.layers[layer] as Sprite2D).texture.get_image()
		for y in range(0, 176, 3):
			for x in range(0, 128, 3):
				var a := img.get_pixel(x, y).a
				if a > 0.02 and a < 0.98:
					alpha_ok = false
	_ok("图层 alpha 只有全透明/全不透明两档（无羽化）", alpha_ok)

	var chain_ok := true
	for b in spec["bones"]:
		var name := String(b["name"])
		var parent := String(b["parent"]) if b["parent"] != null else ""
		var bone: Bone2D = _rig.bones[name]
		if parent == "":
			if bone.get_parent() != _rig.skeleton:
				chain_ok = false
		elif bone.get_parent() != _rig.bones[parent]:
			chain_ok = false
	_ok("骨骼父子层级与 spec 完全一致", chain_ok)

	var ang_ok := true
	for b in spec["bones"]:
		var name := String(b["name"])
		var bone: Bone2D = _rig.bones[name]
		var parent := String(b["parent"]) if b["parent"] != null else ""
		var pa: float = _rig.rest_abs[parent] if parent != "" else 0.0
		if not _near(bone.rotation + pa, deg_to_rad(float(b["rest_rot_deg"])), 1e-4):
			ang_ok = false
	_ok("每根骨静止角 = spec 实测关节角", ang_ok)

	var z_ok := true
	for b in spec["bones"]:
		if b.has("layer"):
			var spr: Sprite2D = _rig.layers[String(b["layer"])]
			if spr.z_index != int(b["z"]):
				z_ok = false
			if spr.offset != -Vector2(b["origin"][0], b["origin"][1]):
				z_ok = false
	_ok("图层 z 序与原点偏移与 spec 一致", z_ok)

	# --- B. 分层还原度（最关键的一条）---
	var still: Image = await _render_still()
	var src := (load(SOURCE_PNG) as Texture2D).get_image()
	var diff := 0
	var first_diff := Vector2i(-1, -1)
	for y in 176:
		for x in 128:
			if still.get_pixel(x, y) != src.get_pixel(x, y):
				diff += 1
				if first_diff.x < 0:
					first_diff = Vector2i(x, y)
	_ok("静止姿态渲染 == r02_00 源图（逐像素）", diff == 0,
		"差异 %d px%s" % [diff, "" if diff == 0 else "，首个差异 %s" % first_diff])

	# --- C. 动画结构 ---
	var has_idle := _rig.player.has_animation(&"idle")
	var has_walk := _rig.player.has_animation(&"walk_right")
	_ok("AnimationPlayer 含 idle / walk_right", has_idle and has_walk)
	var idle_anim := _rig.player.get_animation(&"idle")
	var walk_anim := _rig.player.get_animation(&"walk_right")
	_ok("两条动画均设为循环（LOOP_LINEAR）",
		idle_anim.loop_mode == Animation.LOOP_LINEAR and walk_anim.loop_mode == Animation.LOOP_LINEAR)
	_ok("walk 时长 = 1.00s，与步态循环一致", _near(walk_anim.length, 1.0, 1e-4),
		"%.3fs" % walk_anim.length)
	var expect_tracks := 0
	for b in spec["bones"]:
		expect_tracks += 1
	expect_tracks += 2  # 骨盆位置轨 + 颈部平移补偿轨
	_ok("walk 轨道数 = 骨骼数 + 骨盆位置轨 + 颈部补偿轨", walk_anim.get_track_count() == expect_tracks,
		"%d / %d" % [walk_anim.get_track_count(), expect_tracks])

	_rig.player.speed_scale = 1.0
	_rig.play(&"idle")
	await get_tree().process_frame
	var a1: StringName = _rig.current_animation()
	_rig.play(&"walk_right")
	await get_tree().process_frame
	var a2: StringName = _rig.current_animation()
	_rig.player.speed_scale = 0.0
	_ok("动画可切换 idle → walk_right", a1 == &"idle" and a2 == &"walk_right", "%s → %s" % [a1, a2])

	# --- D0. 动画首帧的骨骼画布坐标必须等于 spec 关节坐标（抓坐标系错配）---
	_rig.player.play(&"walk_right")
	_rig.player.seek(0.0, true)
	# 只查脊柱链：四肢在 t=0 本就处在迈步姿态，不该等于静止关节。
	# 这条能抓住"骨盆坐标被父骨坐标系旋转"这类整身位移错误。
	var max_off := 0.0
	var worst_bone := ""
	for name in ["root", "pelvis", "chest", "neck", "head"]:
		var want: Vector2 = _rig.origin[name]
		var off := _rig.bone_canvas_pos(name).distance_to(want)
		if off > max_off:
			max_off = off
			worst_bone = name
	_ok("动画首帧脊柱链坐标 == spec 关节坐标（偏差 ≤ 2px）", max_off <= 2.0,
		"最大偏差 %.2f px @ %s" % [max_off, worst_bone])

	# --- D. 循环首尾连续 ---
	var max_delta := 0.0
	for b in spec["bones"]:
		var name := String(b["name"])
		_rig.player.play(&"walk_right")
		_rig.player.seek(0.0, true)
		var r0: float = (_rig.bones[name] as Bone2D).rotation
		_rig.player.seek(1.0, true)
		var r1: float = (_rig.bones[name] as Bone2D).rotation
		max_delta = maxf(max_delta, absf(r0 - r1))
	_ok("循环首尾姿势连续（各骨角度差 < 0.01 rad）", max_delta < 0.01,
		"最大差 %.5f rad" % max_delta)

	# --- E. 动作真实发生 ---
	var ankle_span := 0.0
	var knee_span := {"near": 0.0, "far": 0.0}
	for i in 41:
		var t := float(i) / 40.0
		_rig.player.play(&"walk_right")
		_rig.player.seek(t, true)
		var an := _rig.bone_canvas_pos("foot_near").x
		var af := _rig.bone_canvas_pos("foot_far").x
		ankle_span = maxf(ankle_span, absf(an - af))
		for side in ["near", "far"]:
			var k: float = (_rig.bones["leg_%s_lower" % side] as Bone2D).rotation
			knee_span[side] = maxf(knee_span[side], k)
	_ok("两脚踝水平间距在循环内 ≥ 30px（真的在迈步）", ankle_span >= 30.0,
		"最大间距 %.1f px" % ankle_span)

	# --- F. 比例稳定 ---
	var hmin := 1e9
	var hmax := -1e9
	var axis_min := 1e9
	var axis_max := -1e9
	for i in 25:
		var t := float(i) / 24.0
		_rig.player.play(&"walk_right")
		_rig.player.seek(t, true)
		var bb := _rig.composed_bbox()
		hmin = minf(hmin, bb.size.y)
		hmax = maxf(hmax, bb.size.y)
		# 头部中轴：用 head 骨原点的 x 近似
		var hx := _rig.bone_canvas_pos("head").x
		axis_min = minf(axis_min, hx)
		axis_max = maxf(axis_max, hx)
	_ok("全身高度在循环内波动 ≤ 3px", (hmax - hmin) <= 3.0, "%.1f → %.1f px" % [hmin, hmax])
	_ok("头部关节水平漂移 ≤ 2px", (axis_max - axis_min) <= 2.0,
		"%.2f px" % (axis_max - axis_min))

	# --- G. 支撑脚世界滑移（物理帧连跑 2 个循环）---
	var frames := 240
	var slip := {"near": [], "far": []}
	var last := {}
	var t_elapsed := 0.0
	_rig.player.play(&"walk_right")
	_rig.player.speed_scale = 0.0
	_rig.position = Vector2(0, GROUND_Y)
	for i in frames:
		# 身体以 70px/s 前进，动画相位与位移同步（= 正式游戏里"移动速度与动画匹配"）
		var ph := fposmod(t_elapsed, 1.0)
		_rig.player.seek(ph, true)
		await get_tree().physics_frame
		var now := {
			"near": _rig.bones["foot_near"].global_position,
			"far": _rig.bones["foot_far"].global_position,
		}
		var duty := float(spec["gait"]["duty"])
		var stance := {}
		stance["near"] = ph < duty
		stance["far"] = fposmod(ph + 0.5, 1.0) < duty
		for side in ["near", "far"]:
			# 只有"上一帧也在支撑相"才算支撑段内部，避免把离地瞬间算成滑移
			if last.has(side) and stance[side] and bool(last[side + "_stance"]):
				slip[side].append(absf(now[side].x - last[side].x))
		last["near"] = now["near"]
		last["far"] = now["far"]
		last["near_stance"] = stance["near"]
		last["far_stance"] = stance["far"]
		t_elapsed += 1.0 / 60.0
		_rig.position.x += SPEED / 60.0
	var all_slip: Array = slip["near"] + slip["far"]
	var mean_slip := 0.0
	var max_slip := 0.0
	for v in all_slip:
		mean_slip += float(v)
		max_slip = maxf(max_slip, float(v))
	if not all_slip.is_empty():
		mean_slip /= float(all_slip.size())
	_ok("支撑脚世界滑移：均值 ≤ 1.0 px/帧", mean_slip <= 1.0 and all_slip.size() > 100,
		"均值 %.3f px/帧，最大 %.2f，样本 %d" % [mean_slip, max_slip, all_slip.size()])
	_ok("支撑相占空比符合设计（约 60%）", _near(float(spec["gait"]["duty"]), 0.6, 1e-6))

	# --- H. 关节裂缝 ---
	var holes_total := 0
	var worst := 0
	var leg_gap := 0
	for i in 8:
		var img: Image = await _render_pose(float(i) / 8.0)
		var st := _hole_stats(img)
		holes_total += int(st["upper"])
		leg_gap += int(st["lower"])
		worst = maxi(worst, int(st["upper"]))
	_ok("8 个相位上体封闭孔合计 ≤ 20px（颈/肩/腋/肘无露缝）", holes_total <= 20,
		"合计 %d px，单帧最差 %d px；腿间背景缝 %d px（正常）" % [holes_total, worst, leg_gap])

	# --- I. 保护性断言：正式资源一点没动 ---
	_ok("r02 源图 SHA256 与 spec 记录一致（未被覆盖）",
		_sha256_file(SOURCE_PNG) == String(spec["source_sha256"]))
	var frames_res := load("res://assets/characters/player_sprite_frames.tres") as SpriteFrames
	_ok("正式 SpriteFrames 仍含 r09 扶车十六帧（16 帧 / 10 FPS）",
		frames_res.has_animation(&"r09_push_walk_right")
		and frames_res.get_frame_count(&"r09_push_walk_right") == 16
		and _near(frames_res.get_animation_speed(&"r09_push_walk_right"), 10.0, 1e-6),
		"%d 帧" % frames_res.get_frame_count(&"r09_push_walk_right"))
	_ok("r09 / r04 / r03 动画全部保留（回退能力完整）",
		frames_res.has_animation(&"r09_push_idle") and frames_res.has_animation(&"push_idle")
		and frames_res.has_animation(&"push_walk_right"))

	var player_scene: Variant = load("res://scenes/characters/player.tscn").instantiate()
	_ok("PlayerController 默认扶车动画仍是 r09",
		String(player_scene.push_anim_variant) == "r09",
		String(player_scene.push_anim_variant))
	_ok("PlayerController 移动速度 100 / r09 帧率 10 未被改动",
		_near(player_scene.move_speed, 100.0, 1e-6) and _near(player_scene.push_walk_r09_fps, 10.0, 1e-6))
	var col: CollisionShape2D = player_scene.get_node("Collision")
	var shape := col.shape as RectangleShape2D
	_ok("角色碰撞盒仍为 28×160", shape != null and shape.size == Vector2(28, 160),
		str(shape.size) if shape else "无")
	player_scene.free()

	var cart: Variant = load("res://scripts/objects/pushable_cart.gd").new()
	_ok("购物车冻结参数未变（车长 96 / 间距 80 / 推 80 / 拉 40）",
		_near(cart.cart_width, 96.0, 1e-6) and _near(cart.side_offset, 80.0, 1e-6)
		and _near(cart.push_speed, 80.0, 1e-6) and _near(cart.pull_speed, 40.0, 1e-6),
		"%.0f / %.0f / %.0f / %.0f" % [cart.cart_width, cart.side_offset, cart.push_speed, cart.pull_speed])
	cart.free()

	_ok("视口仍为 960×540", get_viewport().get_visible_rect().size == Vector2(960, 540),
		str(get_viewport().get_visible_rect().size))

	var whitelist := FileAccess.get_file_as_string("res://tools/check_artlib_page.mjs")
	_ok("rig001 未进入运行时白名单", not whitelist.contains("RIG_001") and not whitelist.contains("rig001_proto"))
	# 台账登记状态由构建期工具校验（tools/make_rig001_layers.py 的隔离检查）：
	# 运行时脚本不写素材目录的路径字面量，否则会被打进 PCK、影响既有包体体检。
	_ok("spec 状态仍为「技术验证 / 待美术审核」",
		String(spec.get("status", "")).begins_with("技术验证"))
	_ok("r03/r04 专项验证场景文件仍在（回退链未断）",
		FileAccess.file_exists("res://scenes/dev/art005_verify.tscn")
		and FileAccess.file_exists("res://scenes/dev/art005e_verify.tscn"))

	print("========== 结果：通过 %d 项，失败 %d 项 ==========" % [_pass, _fail])
	if _fail > 0:
		for m in _fail_msgs:
			print("  ! %s" % m)
	if _args.has("quit"):
		get_tree().quit(0 if _fail == 0 else 1)
