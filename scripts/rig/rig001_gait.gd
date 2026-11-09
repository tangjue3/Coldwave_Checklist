class_name Rig001Gait
extends RefCounted
## ART-RIG-001：骨骼步态模型 + 动画烘焙（技术原型）
##
## 这不是"逐帧画出来的动作"，而是**由骨骼系统解算出来的动作**：
##   1) 先定义脚掌在世界（画布）里的轨迹：支撑相沿 -x 匀速后退（等价于身体前进），
##      摆动相沿 +x 抬脚前摆；
##   2) 髋/膝用**解析二骨 IK** 反解，支撑相脚掌世界坐标恒定 → 不滑步；
##   3) 骨盆上下起伏、躯干反向平衡、手臂与腿反相摆动、马尾跟随延迟，都写成相位函数；
##   4) 再按 30Hz 采样成 AnimationPlayer 关键帧（骨骼 rotation 曲线 + 骨盆 position 曲线）。
##
## 因此"脚底不滑"是**可算的**：支撑相脚踝目标世界坐标恒定，
## 画面上的滑移只来自像素取整与脚掌刚体旋转，量级 1–2px。
##
## 步态参数（来自 rig001_spec.json 的 gait 段，改 spec 即可，不用改代码）：
##   循环 1.0s、支撑相 60%、步距 42px → 步速 70 px/s。
##   注意：现有 PlayerController.move_speed = 100 px/s，与骨骼步态不匹配，
##   正式接入时必须二选一（见交付报告"待裁定"）。

const SAMPLES_PER_SEC := 30.0
const IDLE_SECONDS := 2.4
const ANIM_WALK_NAME := &"walk_right"

## 脚踝静止位置取自 spec 里的 foot 骨 origin
static func _ankle_rest(rig: Rig001Character, side: String) -> Vector2:
	return rig.origin["foot_" + side]


static func _leg_len(rig: Rig001Character, side: String) -> Vector2:
	var l1 := 0.0
	var l2 := 0.0
	for b in rig.spec["bones"]:
		if String(b["name"]) == "leg_%s_upper" % side:
			l1 = float(b["length"])
		elif String(b["name"]) == "leg_%s_lower" % side:
			l2 = float(b["length"])
	return Vector2(l1, l2)


## 脚掌在画布系里的目标位置（相对 base_x 的偏移）
static func foot_offset(phase: float, step: float, duty: float, lift: float) -> Vector2:
	var p := fposmod(phase, 1.0)
	if p < duty:
		# 支撑相：从 +S/2 匀速退到 -S/2（身体在前进，脚相对身体反向移动）
		var u := p / duty
		return Vector2(step * 0.5 - step * u, 0.0)
	# 摆动相：从 -S/2 平滑前摆到 +S/2，中途抬脚
	var u2 := (p - duty) / (1.0 - duty)
	var e := u2 * u2 * (3.0 - 2.0 * u2)  # smoothstep
	return Vector2(-step * 0.5 + step * e, -lift * sin(PI * u2))


## 解析二骨 IK：给定髋 H、踝 A、两段长 l1/l2，求膝位置（膝关节朝前 = +x）
static func solve_knee(h: Vector2, a: Vector2, l1: float, l2: float) -> Vector2:
	var d := h.distance_to(a)
	var dmax := l1 + l2 - 0.001
	if d > dmax:
		a = h + (a - h).normalized() * dmax
		d = dmax
	d = maxf(d, absf(l1 - l2) + 0.001)
	var u := (a - h).normalized()
	var along := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var hgt := sqrt(maxf(0.0, l1 * l1 - along * along))
	# 法线取 +x 一侧，膝盖朝前弯
	var n := Vector2(u.y, -u.x)
	if n.x < 0.0:
		n = -n
	return h + u * along + n * hgt


## 求某个相位下的完整姿态
## 返回 { "pelvis_pos": Vector2(画布系绝对位置), "abs": {骨名: 绝对角(弧度)} }
static func evaluate(rig: Rig001Character, t: float, clip: StringName) -> Dictionary:
	var g: Dictionary = rig.spec["gait"]
	var step := float(g["step_px"])
	var duty := float(g["duty"])
	var lift := float(g["lift_px"])
	var bob := float(g["bob_px"])
	var sway := deg_to_rad(float(g["hip_sway_deg"]))
	var counter := deg_to_rad(float(g["chest_counter_deg"]))
	var arm_swing := deg_to_rad(float(g["arm_swing_deg"]))
	var hair_swing := deg_to_rad(float(g["hair_swing_deg"]))

	var abs := {}
	for name in rig.rest_abs.keys():
		abs[name] = rig.rest_abs[name]

	var pelvis_origin: Vector2 = rig.origin["pelvis"]
	var pelvis_offset := Vector2.ZERO
	var pelvis_rot := 0.0
	var phase_n := 0.0
	var phase_f := 0.0
	var foot_target := {}

	if clip == ANIM_WALK_NAME:
		phase_n = fposmod(t, 1.0)
		phase_f = fposmod(t + 0.5, 1.0)
		# 骨盆：每循环两次起伏（触地最低、支撑中期最高）+ 轻微摆动
		pelvis_offset.y = bob * 0.5 * cos(TAU * 2.0 * phase_n)
		pelvis_rot = sway * sin(TAU * phase_n)
		var base_x := (_ankle_rest(rig, "near").x + _ankle_rest(rig, "far").x) * 0.5
		for side in ["near", "far"]:
			var ph: float = phase_n if side == "near" else phase_f
			var off := foot_offset(ph, step, duty, lift)
			foot_target[side] = Vector2(base_x + off.x, _ankle_rest(rig, side).y + off.y)
	else:
		# idle：只做呼吸，双脚钉在原地（仍然走 IK，保证 0 滑移）
		var breath := sin(TAU * t)
		pelvis_offset.y = -0.5 * breath
		pelvis_rot = deg_to_rad(0.4) * breath
		foot_target["near"] = _ankle_rest(rig, "near")
		foot_target["far"] = _ankle_rest(rig, "far")

	# --- 骨盆 ---
	abs["pelvis"] = rig.rest_abs["pelvis"] + pelvis_rot
	var pelvis_pos := pelvis_origin + pelvis_offset
	# 骨盆的父级是 root 骨（rest 旋转 -90°，坐标系是"向上"），
	# 画布坐标必须转进父级坐标系，否则整身会绕着脚底被转 90°。
	# 这个错误静态姿态查不出来（静止时走 rig.gd 的建树逻辑），只有播动画才会暴露。
	var root_origin: Vector2 = rig.origin["root"]
	var root_rot: float = rig.rest_abs["root"]
	var pelvis_local: Vector2 = (pelvis_pos - root_origin).rotated(-root_rot)

	# --- 躯干反向平衡 / 头稳定 ---
	var chest_delta := -counter * sin(TAU * (phase_n if clip == ANIM_WALK_NAME else t))
	abs["chest"] = rig.rest_abs["chest"] + chest_delta + deg_to_rad(0.6) * sin(TAU * t)
	abs["neck"] = rig.rest_abs["neck"] - chest_delta * 0.5
	abs["head"] = rig.rest_abs["head"] - chest_delta * 0.5 + deg_to_rad(0.4) * sin(TAU * t + 0.6)
	abs["hair_tail"] = rig.rest_abs["hair_tail"] + hair_swing * sin(
		TAU * (phase_n if clip == ANIM_WALK_NAME else t) - 0.5) + deg_to_rad(1.0) * sin(TAU * t + 0.9)

	# --- 颈/头稳定：胸部反向平衡会把头甩出去（66px 力臂 × 3° ≈ 3.5px），
	#     用颈部平移补偿把头部关节锁回静止 x，这就是骨骼方案相对逐帧绘制的优势之一。
	var chest_pos: Vector2 = pelvis_pos + (Vector2(rig.origin["chest"]) - pelvis_origin).rotated(pelvis_rot)
	var neck_rest: Vector2 = rig.origin["neck"]
	var neck_desired := Vector2(neck_rest.x, neck_rest.y + (chest_pos.y - Vector2(rig.origin["chest"]).y))
	var neck_local: Vector2 = (neck_desired - chest_pos).rotated(-float(abs["chest"]))

	# --- 腿：IK 反解 ---
	for side in ["near", "far"]:
		var lens := _leg_len(rig, side)
		var hip_rest: Vector2 = rig.origin["leg_%s_upper" % side]
		var hip := pelvis_pos + (hip_rest - pelvis_origin).rotated(pelvis_rot)
		var ankle: Vector2 = foot_target[side]
		var knee := solve_knee(hip, ankle, lens.x, lens.y)
		var thigh_abs := (knee - hip).angle()
		var shin_abs := (ankle - knee).angle()
		abs["leg_%s_upper" % side] = thigh_abs
		abs["leg_%s_lower" % side] = shin_abs
		# 脚掌保持水平（sole level）：绝对角锁死在静止角，不随小腿转
		abs["foot_%s" % side] = rig.rest_abs["foot_%s" % side]

	# --- 手臂：与同侧腿反相；近臂对应近腿 ---
	for side in ["near", "far"]:
		var ph: float = phase_n if side == "near" else phase_f
		var delta := arm_swing * cos(TAU * ph) if clip == ANIM_WALK_NAME else deg_to_rad(0.8) * sin(TAU * t)
		abs["arm_%s_upper" % side] = rig.rest_abs["arm_%s_upper" % side] + delta
		# 前臂在摆动末端多一点弯（跟随延迟）
		var bend := deg_to_rad(6.0) + deg_to_rad(4.0) * maxf(0.0, sin(TAU * ph))
		abs["arm_%s_fore" % side] = abs["arm_%s_upper" % side] + (
			rig.rest_abs["arm_%s_fore" % side] - rig.rest_abs["arm_%s_upper" % side]) + bend * 0.4
		abs["hand_%s" % side] = abs["arm_%s_fore" % side] + (
			rig.rest_abs["hand_%s" % side] - rig.rest_abs["arm_%s_fore" % side])

	return {"pelvis_pos": pelvis_pos, "pelvis_local": pelvis_local,
		"neck_local": neck_local, "abs": abs, "foot_target": foot_target}


## 烘焙成 Animation：按 30Hz 采样 evaluate()
static func bake(rig: Rig001Character, clip: StringName) -> Animation:
	var dur := 1.0 if clip == ANIM_WALK_NAME else IDLE_SECONDS
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_LINEAR
	anim.length = dur
	anim.step = 1.0 / SAMPLES_PER_SEC

	var n := int(round(dur * SAMPLES_PER_SEC))
	var times: Array[float] = []
	for i in n + 1:
		times.append(float(i) / SAMPLES_PER_SEC)

	# 先把每个采样时刻的姿态算好，避免重复解算
	var samples: Array[Dictionary] = []
	for i in times.size():
		samples.append(evaluate(rig, times[i], clip))

	# 每根骨一条 rotation 轨；骨盆额外一条 position 轨
	for b in rig.spec["bones"]:
		var name := String(b["name"])
		var parent := String(b["parent"]) if b["parent"] != null else ""
		var bone: Bone2D = rig.bones[name]
		var path := String(rig.get_path_to(bone))
		var track := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track, NodePath("%s:rotation" % path))
		anim.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
		for i in times.size():
			var a: float = samples[i]["abs"][name]
			var pa: float = samples[i]["abs"][parent] if parent != "" else 0.0
			anim.track_insert_key(track, times[i], a - pa)

	# 骨盆位置（画布系绝对坐标，父为 Skeleton2D，其坐标系 = 画布系）
	var pelvis: Bone2D = rig.bones["pelvis"]
	var ptrack := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(ptrack, NodePath("%s:position" % String(rig.get_path_to(pelvis))))
	anim.track_set_interpolation_type(ptrack, Animation.INTERPOLATION_LINEAR)
	for i in times.size():
		anim.track_insert_key(ptrack, times[i], samples[i]["pelvis_local"])

	# 颈骨平移：头部稳定补偿（局部坐标 = 相对胸骨的偏移）
	var neck: Bone2D = rig.bones["neck"]
	var ntrack := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(ntrack, NodePath("%s:position" % String(rig.get_path_to(neck))))
	anim.track_set_interpolation_type(ntrack, Animation.INTERPOLATION_LINEAR)
	for i in times.size():
		anim.track_insert_key(ntrack, times[i], samples[i]["neck_local"])

	# 图层可见性轨道不需要；动画只驱动骨骼，像素由 Sprite2D 跟随
	return anim


## 支撑相内脚踝世界坐标的理论滑移（0 表示模型本身完全不打滑）
static func stance_slip(step: float, duty: float, cycle: float, speed: float) -> float:
	return absf(step / (duty * cycle) - speed)
