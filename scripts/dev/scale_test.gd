extends Node2D
## SCALE-001 · 世界比例与物件尺寸验证场景（**纯占位，不含任何玩法**）
##
## 目的：在 960×540 逻辑分辨率下，用占位矩形 / 网格 / 标尺比较
## 人物身高、住宅门、超市入口、货架、商品包装与购物车的尺寸组合，
## 并输出**可复算**的净宽与层高表。
##
## 明确不做：行走 / 碰撞 / 购物 / 建造 / 动画 / TileSet / 存档。
## 本场景只由命令行进入（SceneRouter 的 dev 入口），不挂在主菜单上。
##
## 命令行（写在 `--` 之后，须同时带 --dev-scene=scale）：
##   --scale-state=grid|chars|doors|shelter_a|shelter_b|market_a|market_b
##   --scale-tour        依次渲染全部状态、各截一张图、打印计算表后退出
##   --shot=name.png     单状态截图文件名
##   --quit              完成后退出
##
## 例：godot --path . -- --dev-scene=scale --scale-tour --quit
##
## 几何模型是本文件的唯一来源：绘制与计算表共用同一组常量与函数，
## 因此截图里量到的数与 tests/scale_001_metrics.txt 里的数必然一致。

const VIEW_W := 960.0
const VIEW_H := 540.0
const TILE := 32
## 地面线（人物脚底所在 y）。取 13×32 = 416，既是整格又留在 HUD 之上，
## 避免脚被底部 UI 遮住，也让后续 TileSet 的地面行可以直接对齐。
const FLOOR_Y := 416.0
## 底部 HUD 占位高度（960×540 下常见的快捷栏高度）
const HUD_H := 74.0
## 人物真实身高，仅用于把像素换算成物理尺寸做合理性交叉校验
const PERSON_M := 1.72
## 住宅层高，用于判断一屏能看到几层楼（安全屋是两层小楼剖面）
const STOREY_M := 2.70

const SHOT_DIR := "res://tests/screenshots"
const METRICS_PATH := "res://tests/scale_001_metrics.txt"
const FONT_PATH := "res://assets/ui/fonts/NotoSansSC-Variable.ttf"

const BG := Color(0.078, 0.094, 0.106)
const WALL := Color(0.129, 0.145, 0.161)
const FLOORC := Color(0.212, 0.196, 0.180)
const GRID_MINOR := Color(0.165, 0.180, 0.192, 0.9)
const GRID_MAJOR := Color(0.239, 0.263, 0.282, 0.95)
const INK := Color(0.906, 0.925, 0.941)
const MUTED := Color(0.576, 0.627, 0.678)
const DIM := Color(0.412, 0.455, 0.498)
const AMBER := Color(0.941, 0.659, 0.290)
const BODY := Color(0.788, 0.847, 0.906)
const COLLIDE := Color(0.886, 0.341, 0.302)
const DOORC := Color(0.373, 0.455, 0.533)
const SHELFC := Color(0.431, 0.490, 0.545)
const CARTC := Color(0.561, 0.651, 0.722)
const OKC := Color(0.455, 0.761, 0.525)
const WARNC := Color(0.878, 0.706, 0.353)
const BADC := Color(0.886, 0.341, 0.302)
const GOODSC := Color(0.725, 0.639, 0.494)
const HEATC := Color(0.612, 0.545, 0.478)

## 人物占位规格：画布宽 / 可见身体宽（含手臂轮廓）/ 碰撞盒宽，三者**互不相等**。
## 画布宽只是绘图留白，身体宽是剪影，碰撞盒宽才是引擎里真正参与通行的数。
const CHAR_SPEC := {
	144: {"canvas": 64, "body": 40, "collide": 24},
	160: {"canvas": 72, "body": 46, "collide": 28},
	192: {"canvas": 96, "body": 56, "collide": 32},
}

## 门：w/h 是洞口外框；jamb 是左右门框内凸，head 是上门楣内凸。
## 净宽 = w - 2*jamb；净高 = h - head。**净宽 ≠ 外框宽**，这是本轮要报告的核心量。
const DOORS := [
	{"key": "96x192", "w": 96, "h": 192, "jamb": 8, "head": 8},
	{"key": "96x224", "w": 96, "h": 224, "jamb": 8, "head": 8},
	{"key": "128x192", "w": 128, "h": 192, "jamb": 8, "head": 8},
	{"key": "128x224", "w": 128, "h": 224, "jamb": 8, "head": 8},
]

## 超市入口收边（玻璃门扇折叠 + 门套），比住宅门薄。
const ENTRY_REVEAL := 4

## 货架：post 立柱、top 顶板、base 底座、beam 层间横梁。
## 每层净高 = (h - top - base - (layers-1)*beam) / layers
const SHELVES := {
	"A": {"key": "A", "w": 96, "h": 192, "layers": 4, "post": 6, "top": 8, "base": 16, "beam": 6},
	"B": {"key": "B", "w": 96, "h": 224, "layers": 4, "post": 6, "top": 8, "base": 16, "beam": 6},
}

## 商品候选（w×h，像素）。大包落地、小规格上架，是本轮要给出的结论之一。
const GOODS := [
	{"name": "瓶装水 大包", "w": 64, "h": 48},
	{"name": "瓶装水 小包", "w": 48, "h": 32},
	{"name": "食品箱 大", "w": 64, "h": 64},
	{"name": "食品箱 小", "w": 32, "h": 32},
	{"name": "电暖器", "w": 64, "h": 96},
]

## 每个状态 = 一张验收截图 + 一组被比较的参数
const STATES := [
	{
		"key": "grid", "zone": "grid",
		"title": "① 960×540 逻辑分辨率 · 32px 世界网格 · 标尺",
	},
	{
		"key": "chars", "zone": "chars",
		"title": "② 人物身高对比 144 / 160 / 192（同一门 128×192 与货架 A 作参照）",
		"char": 160, "door": [128, 192], "shelf": "A",
	},
	{
		"key": "doors", "zone": "doors",
		"title": "③ 门框组合 96×192 / 96×224 / 128×192 / 128×224",
		"char": 160, "door": [128, 192], "shelf": "A",
	},
	{
		"key": "shelter_a", "zone": "shelter",
		"title": "④ 安全屋 · 组合 A：人物 160 / 门 96×192 / 货架 96×192",
		"char": 160, "door": [96, 192], "shelf": "A",
	},
	{
		"key": "shelter_b", "zone": "shelter",
		"title": "⑤ 安全屋 · 组合 B：人物 192 / 门 128×224 / 货架 96×224",
		"char": 192, "door": [128, 224], "shelf": "B",
	},
	{
		"key": "market_a", "zone": "market",
		"title": "⑥ 超市 · 通道 160 / 购物车 96 / 入口 160",
		"char": 160, "aisle": 160, "cart": 96, "entry": 160,
	},
	{
		"key": "market_b", "zone": "market",
		"title": "⑦ 超市 · 通道 192 / 购物车 128 / 入口 192",
		"char": 192, "aisle": 192, "cart": 128, "entry": 192,
	},
]

var _font: Font
var _args: Dictionary = {}
var _state: String = "chars"
var _cfg: Dictionary = {}
var _metric_lines: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_parse_args()
	_font = load(FONT_PATH)
	if _font == null:
		_font = ThemeDB.fallback_font
		push_warning("[SCALE] 字体加载失败，回退到内置字体（中文可能缺失）")

	_emit_metrics()

	_state = String(_args.get("scale_state", "chars"))
	_cfg = _find_state(_state)
	queue_redraw()

	if _args.has("scale_tour"):
		await _run_tour()
	elif _args.has("shot"):
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_capture(String(_args["shot"]))

	if _args.has("quit"):
		get_tree().quit(0)


func _parse_args() -> void:
	for raw in OS.get_cmdline_user_args():
		var a: String = raw
		if not a.begins_with("--"):
			continue
		var kv := a.substr(2).split("=", true, 1)
		_args[kv[0].replace("-", "_")] = kv[1] if kv.size() > 1 else true


func _find_state(key: String) -> Dictionary:
	for s in STATES:
		if String(s["key"]) == key:
			return s
	push_warning("[SCALE] 未知状态 %s，回退到 chars" % key)
	_state = "chars"
	return STATES[1]


func _run_tour() -> void:
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var fails := 0
	for s in STATES:
		_state = String(s["key"])
		_cfg = s
		queue_redraw()
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var name := "scale_001_%s.png" % _state
		var err := get_viewport().get_texture().get_image().save_png("%s/%s" % [SHOT_DIR, name])
		if err != OK:
			fails += 1
		print("[SCALE] 截图 %-22s err=%d  %s" % [name, err, String(s["title"])])
	print("[SCALE] 共 %d 张，失败 %d 张" % [STATES.size(), fails])


func _capture(filename: String) -> void:
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var path := "%s/%s" % [SHOT_DIR, filename]
	var err := get_viewport().get_texture().get_image().save_png(path)
	print("[SCALE] 截图 ", ProjectSettings.globalize_path(path), " err=", err)


# ------------------------------------------------------------------ 几何模型
## 下面这些函数既被 _draw() 调用，也被 _emit_metrics() 调用，
## 保证「图上画的」和「表里算的」是同一条公式。

func char_spec(h: int) -> Dictionary:
	return CHAR_SPEC.get(h, CHAR_SPEC[160])


func char_canvas_w(h: int) -> int:
	return int(char_spec(h)["canvas"])


func char_body_w(h: int) -> int:
	return int(char_spec(h)["body"])


func char_collide_w(h: int) -> int:
	return int(char_spec(h)["collide"])


func door_by_key(key: String) -> Dictionary:
	for d in DOORS:
		if String(d["key"]) == key:
			return d
	return DOORS[0]


func door_find(w: int, h: int) -> Dictionary:
	for d in DOORS:
		if int(d["w"]) == w and int(d["h"]) == h:
			return d
	return DOORS[0]


func door_net_w(d: Dictionary) -> int:
	return int(d["w"]) - 2 * int(d["jamb"])


func door_net_h(d: Dictionary) -> int:
	return int(d["h"]) - int(d["head"])


func entry_net_w(open_w: int) -> int:
	return open_w - 2 * ENTRY_REVEAL


func shelf_usable_w(s: Dictionary) -> int:
	return int(s["w"]) - 2 * int(s["post"])


func shelf_inner_h(s: Dictionary) -> int:
	return int(s["h"]) - int(s["top"]) - int(s["base"]) - (int(s["layers"]) - 1) * int(s["beam"])


func shelf_layer_h(s: Dictionary) -> float:
	return float(shelf_inner_h(s)) / float(s["layers"])


## 每层实际净高取整（向下），余下的几像素分给底座，不改结构
func shelf_layer_floor(s: Dictionary) -> int:
	return int(floor(shelf_layer_h(s)))


func mm_per_px(h: int) -> float:
	return PERSON_M * 1000.0 / float(h)


func screen_width_m(h: int) -> float:
	return VIEW_W * mm_per_px(h) / 1000.0


func screen_height_m(h: int) -> float:
	return VIEW_H * mm_per_px(h) / 1000.0


## 门高判定：净高 − 身高 ≥ 24 为合格，8–23 为偏紧，< 0 为穿不过
func headroom_verdict(net_h: int, body_h: int) -> String:
	var d := net_h - body_h
	if d < 0:
		return "穿不过"
	if d < 8:
		return "紧"
	if d < 24:
		return "偏紧"
	return "合格"


func verdict_color(net_h: int, body_h: int) -> Color:
	var d := net_h - body_h
	if d < 8:
		return BADC
	if d < 24:
		return WARNC
	return OKC


# ------------------------------------------------------------------ 计算表
func _emit_metrics() -> void:
	var L := PackedStringArray()
	L.append("# SCALE-001 尺寸计算表（运行时由 scripts/dev/scale_test.gd 生成，勿手改）")
	L.append("# 单位 px；人物真实身高假设 %.2f m、住宅层高 %.2f m，仅用于物理合理性交叉校验" % [PERSON_M, STOREY_M])
	L.append("")

	L.append("## T1 人物")
	L.append("身高|画布宽|可见身体宽|碰撞宽|占屏高|mm每px|屏宽m|屏高m|屏高除层高|tile数")
	for h in PackedInt32Array([144, 160, 192]):
		L.append("%d|%d|%d|%d|%.1f%%|%.2f|%.2f|%.2f|%.2f|%.1f" % [
			h, char_canvas_w(h), char_body_w(h), char_collide_w(h),
			100.0 * h / VIEW_H, mm_per_px(h), screen_width_m(h), screen_height_m(h),
			screen_height_m(h) / STOREY_M, float(h) / TILE,
		])
	L.append("")

	L.append("## T2 门（净宽 = 外框 − 2×门框内凸 8；净高 = 门高 − 门楣 8）")
	L.append("组合|外框宽|门高|净宽|净高|对144余量|对160余量|对192余量|对144判定|对160判定|对192判定|净宽减碰撞160")
	for d in DOORS:
		var nw := door_net_w(d)
		var nh := door_net_h(d)
		L.append("%s|%d|%d|%d|%d|%+d|%+d|%+d|%s|%s|%s|%d" % [
			String(d["key"]), int(d["w"]), int(d["h"]), nw, nh,
			nh - 144, nh - 160, nh - 192,
			headroom_verdict(nh, 144), headroom_verdict(nh, 160), headroom_verdict(nh, 192),
			nw - char_collide_w(160),
		])
	L.append("")

	L.append("## T3 超市入口（净宽 = 开口 − 2×收边 4）")
	L.append("开口|净宽|净高224减收边|购物车96余量|购物车128余量")
	for e in PackedInt32Array([160, 192]):
		var nw := entry_net_w(e)
		L.append("%d|%d|%d|%d|%d" % [e, nw, 224 - 8, nw - 96, nw - 128])
	L.append("")

	L.append("## T4 货架（可用净宽 = 外宽 − 2×立柱 6；每层净高 = (高 − 顶板8 − 底座16 − 3×横梁6) / 4）")
	L.append("方案|外宽|外高|层数|可用净宽|可用净高合计|每层净高|每层取整|tile宽|tile高")
	for k in ["A", "B"]:
		var s: Dictionary = SHELVES[k]
		L.append("%s|%d|%d|%d|%d|%d|%.1f|%d|%.1f|%.1f" % [
			k, int(s["w"]), int(s["h"]), int(s["layers"]),
			shelf_usable_w(s), shelf_inner_h(s), shelf_layer_h(s), shelf_layer_floor(s),
			float(s["w"]) / TILE, float(s["h"]) / TILE,
		])
	L.append("")

	L.append("## T5 商品与货架适配（层高余量 = 每层净高 − 物件高；每层可放 = 可用净宽 / 物件宽 向下取整）")
	L.append("物件|宽|高|A层余量|B层余量|A每层可放|B每层可放|A判定|B判定")
	for g in GOODS:
		var gw: int = int(g["w"])
		var gh: int = int(g["h"])
		var sa: Dictionary = SHELVES["A"]
		var sb: Dictionary = SHELVES["B"]
		var ra := shelf_layer_floor(sa) - gh
		var rb := shelf_layer_floor(sb) - gh
		L.append("%s|%d|%d|%+d|%+d|%d|%d|%s|%s" % [
			String(g["name"]), gw, gh, ra, rb,
			shelf_usable_w(sa) / gw, shelf_usable_w(sb) / gw,
			"可上架" if ra >= 4 else "落地",
			"可上架" if rb >= 4 else "落地",
		])
	L.append("")

	L.append("## T6 通道（余量 = 通道净宽 − 购物车宽 − 人物碰撞宽；≥8 视为可错身）")
	L.append("通道|购物车|人物144|人物160|人物192|余量144|余量160|余量192|两车错身")
	for aisle in PackedInt32Array([160, 192]):
		for cart in PackedInt32Array([96, 128]):
			var r144: int = aisle - cart - char_collide_w(144)
			var r160: int = aisle - cart - char_collide_w(160)
			var r192: int = aisle - cart - char_collide_w(192)
			L.append("%d|%d|%d|%d|%d|%+d|%+d|%+d|%s" % [
				aisle, cart, char_collide_w(144), char_collide_w(160), char_collide_w(192),
				r144, r160, r192,
				"可" if aisle >= cart * 2 else "不可",
			])
	L.append("")

	L.append("## T7 屏幕视野（960×540 在不同人物身高的物理尺度）")
	L.append("身高|mm每px|屏宽m|屏高m|可容纳层高数|货架A宽折算m|住宅门净宽折算m")
	for h in PackedInt32Array([144, 160, 192]):
		var s: Dictionary = SHELVES["A"]
		var d: Dictionary = door_find(96, 192)
		var m := mm_per_px(h) / 1000.0
		L.append("%d|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f" % [
			h, mm_per_px(h), screen_width_m(h), screen_height_m(h),
			screen_height_m(h) / STOREY_M,
			int(s["w"]) * m, door_net_w(d) * m,
		])
	L.append("")

	_metric_lines = L
	for line in L:
		if line == "" or line.begins_with("#"):
			print("[SCALE] ", line)
		else:
			print("[SCALE]   ", line)
	var f := FileAccess.open(METRICS_PATH, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(L) + "\n")
		f.close()
		print("[SCALE] 计算表已写入 ", ProjectSettings.globalize_path(METRICS_PATH))


# ------------------------------------------------------------------ 绘制入口
func _draw() -> void:
	_rect(0, 0, VIEW_W, VIEW_H, BG)
	match String(_cfg.get("zone", "grid")):
		"grid":
			_draw_zone_grid()
		"chars":
			_draw_zone_chars()
		"doors":
			_draw_zone_doors()
		"shelter":
			_draw_zone_shelter()
		"market":
			_draw_zone_market()
	_draw_frame()
	_draw_title()


func _draw_frame() -> void:
	# 一屏边界 + 四角标记，用于确认截图就是 960×540 原始逻辑分辨率
	_box(0.5, 0.5, VIEW_W - 1, VIEW_H - 1, Color(0.30, 0.34, 0.38))
	var c := AMBER
	draw_line(Vector2(0, 0), Vector2(18, 0), c, 1.0)
	draw_line(Vector2(0, 0), Vector2(0, 18), c, 1.0)
	draw_line(Vector2(VIEW_W, 0), Vector2(VIEW_W - 18, 0), c, 1.0)
	draw_line(Vector2(VIEW_W, 0), Vector2(VIEW_W, 18), c, 1.0)
	draw_line(Vector2(0, VIEW_H), Vector2(18, VIEW_H), c, 1.0)
	draw_line(Vector2(0, VIEW_H), Vector2(0, VIEW_H - 18), c, 1.0)
	draw_line(Vector2(VIEW_W, VIEW_H), Vector2(VIEW_W - 18, VIEW_H), c, 1.0)
	draw_line(Vector2(VIEW_W, VIEW_H), Vector2(VIEW_W, VIEW_H - 18), c, 1.0)


func _draw_title() -> void:
	var t := String(_cfg.get("title", _state))
	_rect(0, 0, VIEW_W, 34, Color(0.04, 0.05, 0.06, 0.86))
	_rect(0, 33, VIEW_W, 1, Color(0.28, 0.31, 0.34))
	_text(16, 9, t, 14, INK)
	_text(VIEW_W - 190, 10, "SCALE-001 · 仅尺寸验证，不含玩法", 11, DIM)
	# 右下角常驻水印
	_text(VIEW_W - 250, VIEW_H - 20, "1 tile = 32×32 px · 960×540 · Nearest", 10, DIM)


# ------------------------------------------------------------------ ① 网格
func _draw_zone_grid() -> void:
	_draw_grid(1.0)
	_draw_rulers()

	# 一格实样
	var tx := 48.0
	var ty := 96.0
	_rect(tx, ty, TILE, TILE, Color(0.941, 0.659, 0.290, 0.22))
	_box(tx, ty, TILE, TILE, AMBER, 1)
	_text(tx - 6, ty - 26, "1 tile", 11, AMBER)
	_text(tx - 6, ty - 12, "32×32", 11, AMBER)

	# 高度阶梯：直接给出各候选值的视觉量感
	_text(48, 168, "高度阶梯（同一地面线 y=%d）" % int(FLOOR_Y), 12, AMBER)
	var hs := PackedInt32Array([32, 64, 96, 128, 144, 160, 192, 224])
	var bx := 48.0
	var labels := PackedStringArray(["32", "64", "96", "128", "144", "160", "192", "224"])
	for i in hs.size():
		var h: int = hs[i]
		var w := 56.0
		var col := Color(0.42, 0.47, 0.52) if i < 4 else BODY
		if h == 144 or h == 160 or h == 192:
			col = AMBER
		_rect(bx, FLOOR_Y - h, w, h, Color(col.r, col.g, col.b, 0.22))
		_box(bx, FLOOR_Y - h, w, h, col)
		_text_center(bx + w * 0.5, FLOOR_Y - h - 16, labels[i], 12, col)
		bx += w + 10

	# HUD 占位
	_hatch_band(0, VIEW_H - HUD_H, VIEW_W, HUD_H, Color(0.10, 0.12, 0.14, 0.9))
	_text(48, VIEW_H - HUD_H + 6, "底部 HUD 占位 %d px（%d..%d）" % [int(HUD_H), int(VIEW_H - HUD_H), int(VIEW_H)], 11, MUTED)
	_text(48, VIEW_H - HUD_H + 22, "地面线 y=%d（第 %d 格）→ 地面到 HUD 顶有 %d px" % [
		int(FLOOR_Y), int(FLOOR_Y / TILE), int(VIEW_H - HUD_H - FLOOR_Y)
	], 11, MUTED)

	# 右侧：把 960×540 与 32px 格的整除关系说清楚
	var px := 612.0
	_rect(px - 14, 96, 336, 250, Color(0.05, 0.06, 0.07, 0.86))
	_box(px - 14, 96, 336, 250, Color(0.26, 0.29, 0.32))
	_text(px, 106, "960×540 与 32px 世界格的整除关系", 12, AMBER)
	var lines := PackedStringArray([
		"宽 960 ÷ 32 = 30.00 格　　整格",
		"高 540 ÷ 32 = 16.88 格　　非整格（差 %.0f px 到 17 格）" % (17.0 * TILE - VIEW_H),
		"顶部标题条 34 px　　　　 1.06 格",
		"地面线 %d = 13 格　　　　 整格" % int(FLOOR_Y),
		"地面 → HUD 顶 = %d px　　　 %.1f 格" % [int(VIEW_H - HUD_H - FLOOR_Y), (VIEW_H - HUD_H - FLOOR_Y) / TILE],
		"",
		"结论：屏幕高不是整格，任何贴地的物件",
		"都要靠地面线对齐，不能靠屏幕底边对齐。",
		"本轮统一取地面线 y=%d（13 格）。" % int(FLOOR_Y),
	])
	var ly := 128.0
	for ln in lines:
		_text(px, ly, ln, 11, INK if not ln.begins_with("结论") else AMBER)
		ly += 20


# ------------------------------------------------------------------ ② 人物
func _draw_zone_chars() -> void:
	_draw_scene_base()
	_draw_grid(0.35)

	# 参照门：128×192（净 112×184）
	var d := door_find(128, 192)
	_draw_door(56, FLOOR_Y, d, "参照门 128×192")
	# 参照货架：A 96×192
	_draw_shelf(748, FLOOR_Y, SHELVES["A"], 0.5, GOODS[3], "货架 A 96×192")

	# 门净高参考线：一眼看出谁的头越过了门楣
	var net_top := FLOOR_Y - door_net_h(d)
	_dash_h(56, VIEW_W - 16, net_top, Color(AMBER.r, AMBER.g, AMBER.b, 0.55), 6, 6)
	_plate_text(866, net_top - 19, "门净高 %d" % door_net_h(d), 11, AMBER)

	var xs := PackedFloat32Array([232.0, 420.0, 612.0])
	var heights := PackedInt32Array([144, 160, 192])
	for idx in heights.size():
		var cx: float = xs[idx]
		var h: int = heights[idx]
		_draw_char(cx, FLOOR_Y, h, BODY, "%d px" % h)
		var top := FLOOR_Y - h
		# 身高标注
		_plate_text_center(cx, top - 38, "%d px" % h, 15, INK)
		_plate_text_center(cx, top - 20, "%.1f tile" % (float(h) / TILE), 11, MUTED)
		# 三宽标注
		_plate_text_center(cx, FLOOR_Y + 6, "画布 %d" % char_canvas_w(h), 11, DIM)
		_plate_text_center(cx, FLOOR_Y + 19, "身体 %d" % char_body_w(h), 11, BODY)
		_plate_text_center(cx, FLOOR_Y + 32, "碰撞 %d" % char_collide_w(h), 11, COLLIDE)
		# 头部越过门净高时标出
		if top < net_top:
			_plate_text_center(cx, top - 58, "头顶高于门净高 %d px" % (net_top - top), 10, BADC)

	# 图例
	var ly := 472.0
	_text(48, ly, "图例：  细框=画布（含挥臂留白）   实心=可见身体轮廓   红色虚线=碰撞盒（真正参与通行）", 11, MUTED)
	_text(48, ly + 18, "三者宽度不同：画布 %d/%d/%d，身体 %d/%d/%d，碰撞 %d/%d/%d（144/160/192）" % [
		char_canvas_w(144), char_canvas_w(160), char_canvas_w(192),
		char_body_w(144), char_body_w(160), char_body_w(192),
		char_collide_w(144), char_collide_w(160), char_collide_w(192),
	], 11, MUTED)
	_text(48, ly + 36, "注意：192 px 的头（y=%d）已经高过 128×192 门的净高线（y=%d）—— 该组合直接不成立" % [
		int(FLOOR_Y - 192), int(net_top)
	], 11, BADC)


# ------------------------------------------------------------------ ③ 门框
func _draw_zone_doors() -> void:
	_draw_scene_base()
	_draw_grid(0.3)

	# 每扇门里都站一个人：第一扇故意放 192 —— 它会被门楣直接切断，示范"穿不过"
	var layout := [
		{"d": door_find(96, 192), "x": 56.0, "cx": 104.0, "ch": 192},
		{"d": door_find(96, 224), "x": 192.0, "cx": 240.0, "ch": 192},
		{"d": door_find(128, 192), "x": 336.0, "cx": 400.0, "ch": 160},
		{"d": door_find(128, 224), "x": 504.0, "cx": 568.0, "ch": 160},
	]
	for item in layout:
		var d: Dictionary = item["d"]
		_draw_door(float(item["x"]), FLOOR_Y, d, "")
		# 净宽括号
		_bracket_h(float(item["x"]) + int(d["jamb"]), float(item["x"]) + int(d["w"]) - int(d["jamb"]),
			FLOOR_Y + 10, "净 %d" % door_net_w(d))
		_text(float(item["x"]) + 2, FLOOR_Y - int(d["h"]) - 64, String(d["key"]), 12, INK)
		_text(float(item["x"]) + 2, FLOOR_Y - int(d["h"]) - 50, "净 %d×%d" % [door_net_w(d), door_net_h(d)], 11, MUTED)
		# 净高括号（画在门外侧，不压门框）
		_v_bracket(float(item["x"]) + int(d["w"]) + 4, FLOOR_Y - door_net_h(d), FLOOR_Y,
			"%d" % door_net_h(d), AMBER)
		# 站在门里的角色
		var cx: float = float(item["cx"])
		var chh: int = int(item["ch"])
		_draw_char(cx, FLOOR_Y, chh, BODY, "")
		if door_net_h(d) < chh:
			_plate_text_center(cx, FLOOR_Y - chh - 34,
				"头顶超出 %d px" % (chh - door_net_h(d)), 10, BADC)

	# 余量矩阵
	var mx := 672.0
	var my := 74.0
	_text(mx, my, "净高余量 = 门净高 − 身高", 12, AMBER)
	var cols := PackedInt32Array([144, 160, 192])
	var cxs := PackedFloat32Array([mx + 96, mx + 152, mx + 208])
	for i in cols.size():
		_text_center(cxs[i], my + 22, "%d" % cols[i], 11, MUTED)
	var rows: Array = [door_find(96, 192), door_find(96, 224)]
	for ri in 2:
		var d2: Dictionary = rows[ri]
		var ry := my + 40 + ri * 20
		_text(mx - 2, ry, "%d×%d" % [int(d2["w"]), int(d2["h"])], 10, MUTED)
		for ci in cols.size():
			var v: int = door_net_h(d2) - cols[ci]
			_text_center(cxs[ci], ry, "%+d" % v, 10, verdict_color(door_net_h(d2), cols[ci]))
	var note_y := my + 92
	_text(mx, note_y, "判定：≥+24 合格 · +8~+23 偏紧 · <0 穿不过", 10, DIM)
	_text(mx, note_y + 16, "同一列对 96 宽与 128 宽门相同（高度才是卡点）", 10, DIM)

	# 净宽矩阵
	_text(mx, note_y + 46, "净宽 vs 碰撞盒（160 / 192）", 12, AMBER)
	_text(mx, note_y + 64, "96 门净 80：160 余 %+d，192 余 %+d" % [
		door_net_w(door_find(96, 192)) - char_collide_w(160),
		door_net_w(door_find(96, 192)) - char_collide_w(192),
	], 10, MUTED)
	_text(mx, note_y + 80, "128 门净 112：160 余 %+d，192 余 %+d" % [
		door_net_w(door_find(128, 192)) - char_collide_w(160),
		door_net_w(door_find(128, 192)) - char_collide_w(192),
	], 10, MUTED)
	_text(mx, note_y + 100, "侧视里门的宽度主要是视觉贴合；", 10, DIM)
	_text(mx, note_y + 114, "真正卡通行的是货架间隙与入口开口。", 10, DIM)


# ------------------------------------------------------------------ ④⑤ 安全屋
func _draw_zone_shelter() -> void:
	_draw_scene_base()
	_draw_grid(0.4)
	_draw_hud_band()

	var dh: int = int(_cfg.get("door", [96, 192])[1])
	var dw: int = int(_cfg.get("door", [96, 192])[0])
	var d := door_find(dw, dh)
	var sh: Dictionary = SHELVES[String(_cfg.get("shelf", "A"))]
	var ch: int = int(_cfg.get("char", 160))

	# 门
	_draw_door(56, FLOOR_Y, d, "")
	_text(20, FLOOR_Y - dh - 40, "住宅门 %d×%d" % [dw, dh], 12, INK)
	_text(20, FLOOR_Y - dh - 26, "净 %d×%d" % [door_net_w(d), door_net_h(d)], 11, MUTED)
	_bracket_h(56 + int(d["jamb"]), 56 + dw - int(d["jamb"]), FLOOR_Y + 12, "净宽 %d" % door_net_w(d))
	_v_bracket(56 + dw + 6, FLOOR_Y - door_net_h(d), FLOOR_Y, "%d" % door_net_h(d), AMBER)

	# 人物
	var ccx := 262.0
	_draw_char(ccx, FLOOR_Y, ch, BODY, "")
	_text(ccx - 30, FLOOR_Y - ch - 34, "人物 %d px" % ch, 12, INK)
	_text(ccx - 30, FLOOR_Y - ch - 19, "身体 %d / 碰撞 %d" % [char_body_w(ch), char_collide_w(ch)], 11, MUTED)

	# 地面物件
	var hx := 340.0
	_draw_heater(hx, FLOOR_Y, 64, 96)
	_text(hx - 4, FLOOR_Y - 96 - 32, "电暖器 64×96", 11, MUTED)
	_text(hx - 4, FLOOR_Y - 96 - 18, "落地，不上架", 10, DIM)

	var wx := 424.0
	_draw_box(wx, FLOOR_Y, GOODS[0]["w"], GOODS[0]["h"], GOODS[0]["name"])
	_text(wx - 12, FLOOR_Y - 48 - 32, "水 64×48", 11, MUTED)
	_text(wx - 12, FLOOR_Y - 48 - 18, "落地", 10, DIM)

	var bx2 := 500.0
	_draw_box(bx2, FLOOR_Y, GOODS[2]["w"], GOODS[2]["h"], GOODS[2]["name"])
	_text(bx2 - 8, FLOOR_Y - 64 - 32, "食品箱 64×64", 11, MUTED)
	_text(bx2 - 8, FLOOR_Y - 64 - 18, "落地", 10, DIM)

	# 三种装载状态：同一结构、不同内容
	var fills := PackedFloat32Array([0.0, 0.5, 1.0])
	var tags := PackedStringArray(["空载", "半满", "满载"])
	var sxs := PackedFloat32Array([604.0, 716.0, 828.0])
	for i in 3:
		_draw_shelf(sxs[i], FLOOR_Y, sh, fills[i], GOODS[3], "")
		_text_center(sxs[i] + 48, FLOOR_Y + 10, tags[i], 11, MUTED)
	_text(604, FLOOR_Y - int(sh["h"]) - 34, "货架 %s %d×%d · 每层净高 %.1f→%d" % [
		String(sh["key"]), int(sh["w"]), int(sh["h"]), shelf_layer_h(sh), shelf_layer_floor(sh)
	], 11, INK)
	_text(604, FLOOR_Y - int(sh["h"]) - 19, "可用净宽 %d · %d 层 · 同一结构三态" % [shelf_usable_w(sh), int(sh["layers"])], 10, MUTED)

	# 关键结论条
	var cy := 56.0
	_rect(560, cy, 384, 58, Color(0.05, 0.06, 0.07, 0.8))
	_box(560, cy, 384, 58, Color(0.28, 0.31, 0.34))
	_text(570, cy + 6, "门净高 %d − 身高 %d = %+d　%s" % [
		door_net_h(d), ch, door_net_h(d) - ch, headroom_verdict(door_net_h(d), ch)
	], 11, verdict_color(door_net_h(d), ch))
	_text(570, cy + 22, "货架层高 %d − 小包装 32 = %+d" % [
		shelf_layer_floor(sh), shelf_layer_floor(sh) - 32
	], 11, OKC if shelf_layer_floor(sh) - 32 >= 4 else BADC)
	_text(570, cy + 38, "货架层高 %d − 大包装 48 = %+d → 大包落地" % [
		shelf_layer_floor(sh), shelf_layer_floor(sh) - 48
	], 11, MUTED)


# ------------------------------------------------------------------ ⑥⑦ 超市
func _draw_zone_market() -> void:
	_draw_scene_base()
	_draw_grid(0.35)
	_draw_hud_band()

	var open_w: int = int(_cfg.get("entry", 160))
	var aisle: int = int(_cfg.get("aisle", 160))
	var cw: int = int(_cfg.get("cart", 96))
	var ch: int = int(_cfg.get("char", 160))
	var net := entry_net_w(open_w)
	var sh: Dictionary = SHELVES["A"]
	var sh_h := int(sh["h"])
	var sh_w := int(sh["w"])
	var shelf_top := FLOOR_Y - sh_h

	# ---------------- 入口
	var ex := 40.0
	var eh := 224.0
	_rect(ex, FLOOR_Y - eh, open_w, eh, Color(0.055, 0.065, 0.075))
	_box(ex, FLOOR_Y - eh, open_w, eh, DOORC, 3)
	# 玻璃门扇向两侧折叠，占掉的正是收边
	_rect(ex, FLOOR_Y - eh, ENTRY_REVEAL, eh, Color(0.45, 0.58, 0.66, 0.5))
	_rect(ex + open_w - ENTRY_REVEAL, FLOOR_Y - eh, ENTRY_REVEAL, eh, Color(0.45, 0.58, 0.66, 0.5))
	_rect(ex + ENTRY_REVEAL, FLOOR_Y - eh * 0.55, net, 2, Color(0.55, 0.66, 0.74, 0.45))
	_text(ex - 2, FLOOR_Y - eh - 42, "超市入口 开口 %d" % open_w, 12, INK)
	_text(ex - 2, FLOOR_Y - eh - 27, "净宽 %d（−2×收边 %d）" % [net, ENTRY_REVEAL], 11, AMBER)
	_text(ex - 2, FLOOR_Y - eh - 13, "高 224 / 净高 216", 10, MUTED)
	_bracket_h(ex + ENTRY_REVEAL, ex + open_w - ENTRY_REVEAL, FLOOR_Y + 8, "入口净 %d" % net)

	# ---------------- 两段货架 + 中间通道
	var a1 := 300.0 + float(sh_w)
	var a2 := a1 + float(aisle)
	var s1 := 300.0
	var s2 := a2
	_draw_shelf(s1, FLOOR_Y, sh, 1.0, GOODS[3], "")
	_draw_shelf(s2, FLOOR_Y, sh, 1.0, GOODS[3], "")

	# 通道尺寸线画在货架顶上（建筑制图式），不占地面，也不与 HUD 打架
	var dim_y := shelf_top - 34.0
	_dash_v(dim_y, shelf_top, a1, Color(AMBER.r, AMBER.g, AMBER.b, 0.45), 4, 4)
	_dash_v(dim_y, shelf_top, a2, Color(AMBER.r, AMBER.g, AMBER.b, 0.45), 4, 4)
	_bracket_h(a1, a2, dim_y, "净 %d" % aisle, AMBER)
	_text_center((a1 + a2) * 0.5, dim_y - 18, "通道 %d px（%.2f tile）" % [aisle, float(aisle) / TILE], 11, AMBER)

	# ---------------- 购物车 + 人物
	# 按**可见身体宽**摆放，而不是碰撞盒：碰撞盒只决定能不能过，
	# 画面上挤不挤要看身体轮廓，两者相差 body−collide 像素。
	var pcol := float(char_collide_w(ch))
	var pvis := float(char_body_w(ch))
	var slack := float(aisle) - float(cw) - pvis
	var gap := maxf(4.0, slack)
	var group_w := float(cw) + gap + pvis
	var gx := a1 + maxf(0.0, (float(aisle) - group_w) * 0.5)
	_draw_cart(gx, FLOOR_Y, cw)
	_bracket_h(gx, gx + float(cw), FLOOR_Y + 8, "车 %d" % cw, CARTC)
	_text(gx + 4, FLOOR_Y - 108, "购物车 %d×96" % cw, 11, CARTC)

	var pcx := gx + float(cw) + gap + pvis * 0.5
	_draw_char(pcx, FLOOR_Y, ch, BODY, "")
	_plate_text_center(pcx, shelf_top - 13, "人物 %d / 碰撞 %d" % [ch, int(pcol)], 10, INK)

	# ---------------- 抬头数字
	var total := cw + int(pcol)
	var rest := aisle - total
	_text(48, 58, "车 %d + 人碰撞 %d = %d ／ 通道 %d → 余 %+d" % [cw, int(pcol), total, aisle, rest], 13,
		OKC if rest >= 8 else BADC)
	_text(48, 78, "两车错身需 %d，本通道 %d → %s" % [cw * 2, aisle, "可" if aisle >= cw * 2 else "不可"], 11,
		OKC if aisle >= cw * 2 else WARNC)
	_text(48, 96, "入口净 %d：装车 %d 余 %+d，装车 128 余 %+d" % [net, 96, net - 96, net - 128], 11, MUTED)
	_text(48, 116, "视觉余量（按身体宽 %d）= 通道 − 车 %d − 身体 %d = %+.0f px" % [int(pvis), cw, int(pvis), slack], 11,
		OKC if slack >= 12 else WARNC)

	# ---------------- 图例（放右侧空白，别压地面括号）
	var lx := a2 + float(sh_w) + 18.0
	_rect(lx - 8, 150, 246, 112, Color(0.05, 0.06, 0.07, 0.85))
	_box(lx - 8, 150, 246, 112, Color(0.26, 0.29, 0.32))
	_text(lx, 158, "读图", 11, AMBER)
	_text(lx, 176, "浅蓝=购物车　白色=人物", 10, MUTED)
	_text(lx, 192, "灰蓝=货架　琥珀=被测量的净宽", 10, MUTED)
	_text(lx, 208, "货架 %d×%d，四层，每层净高 %d" % [sh_w, sh_h, shelf_layer_floor(sh)], 10, DIM)
	_text(lx, 224, "地面线 y=%d　HUD 顶 y=%d" % [int(FLOOR_Y), int(VIEW_H - HUD_H)], 10, DIM)


# ------------------------------------------------------------------ 基础绘制
func _draw_scene_base() -> void:
	# 墙面 / 地面
	_rect(0, 34, VIEW_W, FLOOR_Y - 34, WALL)
	_rect(0, FLOOR_Y, VIEW_W, VIEW_H - FLOOR_Y, FLOORC)
	draw_line(Vector2(0, FLOOR_Y), Vector2(VIEW_W, FLOOR_Y), Color(0.36, 0.33, 0.30), 1.0)
	_text(6, FLOOR_Y - 13, "%d" % int(FLOOR_Y), 9, Color(0.47, 0.43, 0.39))
	draw_line(Vector2(0, FLOOR_Y), Vector2(26, FLOOR_Y), Color(0.55, 0.50, 0.45), 1.0)


func _draw_grid(alpha: float) -> void:
	var x := 0
	while x <= int(VIEW_W):
		var major := (x % (TILE * 4)) == 0
		var c: Color = GRID_MAJOR if major else GRID_MINOR
		draw_line(Vector2(x + 0.5, 34), Vector2(x + 0.5, VIEW_H), Color(c.r, c.g, c.b, c.a * alpha), 1.0)
		x += TILE
	var y := 34
	while y <= int(VIEW_H):
		var major := (y % (TILE * 4)) == 0
		var c: Color = GRID_MAJOR if major else GRID_MINOR
		draw_line(Vector2(0, y + 0.5), Vector2(VIEW_W, y + 0.5), Color(c.r, c.g, c.b, c.a * alpha), 1.0)
		y += TILE


func _draw_rulers() -> void:
	# 顶部横向标尺
	for x in range(0, 961, 32):
		var long := (x % 128) == 0
		draw_line(Vector2(x, 34), Vector2(x, 34 + (12 if long else 6)), Color(0.6, 0.65, 0.70, 0.8), 1.0)
		if long and x > 0:
			_text(x - 12, 34 + 14, "%d" % x, 9, MUTED)
	# 左侧纵向标尺
	for y in range(64, 541, 32):
		var long := ((y - 64) % 128) == 0
		draw_line(Vector2(0, y), Vector2(6 if long else 4, y), Color(0.6, 0.65, 0.70, 0.8), 1.0)
		if long:
			_text(8, y - 6, "%d" % y, 9, MUTED)


func _draw_hud_band() -> void:
	var y := VIEW_H - HUD_H
	_hatch_band(0, y, VIEW_W, HUD_H, Color(0.09, 0.11, 0.13, 0.94))
	draw_line(Vector2(0, y), Vector2(VIEW_W, y), Color(0.28, 0.31, 0.34), 1.0)
	_text(12, y + 4, "HUD 占位 %d px · 人物脚底 y=%d 必须在其上方（余 %d px）" % [
		int(HUD_H), int(FLOOR_Y), int(y - FLOOR_Y)
	], 10, MUTED)


func _draw_char(cx: float, feet_y: float, h: int, tone: Color, tag: String) -> void:
	var body := float(char_body_w(h))
	var canvas := float(char_canvas_w(h))
	var coll := float(char_collide_w(h))
	var top := feet_y - h

	# 画布（含挥臂留白）
	_box(cx - canvas * 0.5, top, canvas, h, Color(0.56, 0.62, 0.68, 0.65))
	# 碰撞盒
	_dash_box(cx - coll * 0.5, top, coll, h, COLLIDE)

	# 头
	var head_h := roundf(float(h) * 0.22)
	var head_w := roundf(body * 0.56)
	_rect(cx - head_w * 0.5, top, head_w, head_h, tone)
	_box(cx - head_w * 0.5, top, head_w, head_h, tone.darkened(0.45))

	# 躯干 + 手臂（手臂包含在 body 宽度内）
	var aw := maxf(3.0, roundf(body * 0.16))
	var torso_w := body - 2 * aw
	var torso_y := top + head_h
	var torso_h := roundf(float(h) * 0.36)
	_rect(cx - torso_w * 0.5, torso_y, torso_w, torso_h, tone)
	_box(cx - torso_w * 0.5, torso_y, torso_w, torso_h, tone.darkened(0.45))
	_rect(cx - body * 0.5, torso_y + 2, aw, torso_h - 4, tone.darkened(0.18))
	_rect(cx + body * 0.5 - aw, torso_y + 2, aw, torso_h - 4, tone.darkened(0.18))

	# 腿
	var leg_y := torso_y + torso_h
	var leg_h := feet_y - leg_y
	var lw := maxf(4.0, roundf(body * 0.32))
	var gap := maxf(2.0, roundf(body * 0.14))
	_rect(cx - gap * 0.5 - lw, leg_y, lw, leg_h, tone.darkened(0.3))
	_rect(cx + gap * 0.5, leg_y, lw, leg_h, tone.darkened(0.3))

	if tag != "":
		_text_center(cx, top - 16, tag, 11, MUTED)


func _draw_door(x: float, feet_y: float, d: Dictionary, tag: String) -> void:
	var w := float(d["w"])
	var h := float(d["h"])
	var jamb := float(d["jamb"])
	var net_w := float(door_net_w(d))
	var net_h := float(door_net_h(d))
	var top := feet_y - h

	# 外框
	_rect(x, top, w, h, DOORC)
	_box(x, top, w, h, DOORC.darkened(0.45), 1)
	# 开口（近黑，读作“洞”）
	_rect(x + jamb, top + (h - net_h), net_w, net_h, Color(0.055, 0.065, 0.075))
	_box(x + jamb, top + (h - net_h), net_w, net_h, DOORC.lightened(0.2))
	# 地面门槛
	_rect(x + jamb, feet_y - 2, net_w, 2, DOORC.lightened(0.35))

	if tag != "":
		_text(x + 2, top - 18, tag, 10, MUTED)


func _draw_shelf(x: float, feet_y: float, s: Dictionary, fill: float, item: Dictionary, tag: String) -> void:
	var w := float(s["w"])
	var h := float(s["h"])
	var post := float(s["post"])
	var top := feet_y - h
	var usable := w - 2 * post
	var per := shelf_layer_h(s)
	var beam := float(s["beam"])

	# 立柱 / 顶板 / 底座
	_rect(x, top, post, h, SHELFC)
	_rect(x + w - post, top, post, h, SHELFC)
	_rect(x, top, w, float(s["top"]), SHELFC.lightened(0.08))
	_rect(x, feet_y - float(s["base"]), w, float(s["base"]), SHELFC.darkened(0.2))

	var y := top + float(s["top"])
	for i in int(s["layers"]):
		# 空腔
		_rect(x + post, y, usable, per, Color(0.06, 0.07, 0.09, 0.9))
		# 装载
		var iw := float(item["w"])
		var ih := float(item["h"])
		var per_row := int(floor(usable / iw))
		var placed := int(round(per_row * fill))
		for k in placed:
			var ix := x + post + k * iw + 1
			var iy := y + per - ih
			if ih < per:
				_rect(ix, iy, iw - 2, ih - 1, GOODSC)
				_box(ix, iy, iw - 2, ih - 1, GOODSC.darkened(0.4))
		# 层间横梁
		if i < int(s["layers"]) - 1:
			_rect(x + post, y + per, usable, beam, SHELFC.lightened(0.05))
			draw_line(Vector2(x + post, y + per), Vector2(x + post + usable, y + per), SHELFC.darkened(0.3), 1.0)
		y += per + beam

	if tag != "":
		_text_center(x + w * 0.5, top - 14, tag, 10, MUTED)


func _draw_cart(x: float, feet_y: float, w: int) -> void:
	var cw := float(w)
	var top := feet_y - 96.0
	var basket_w := cw - 12.0
	var basket_h := 48.0
	var by := top + 12.0
	var bx := x + 4.0

	# 篮体
	_rect(bx, by, basket_w, basket_h, Color(CARTC.r, CARTC.g, CARTC.b, 0.22))
	_box(bx, by, basket_w, basket_h, CARTC, 2)
	for i in range(1, 5):
		var lx := bx + basket_w * float(i) / 5.0
		draw_line(Vector2(lx, by + 2), Vector2(lx, by + basket_h - 2), Color(CARTC.r, CARTC.g, CARTC.b, 0.55), 1.0)
	# 推杆
	_rect(x + cw - 6, top, 4, basket_h + 12, CARTC)
	# 轮架 + 轮
	draw_line(Vector2(bx + 8, by + basket_h), Vector2(bx + 8, feet_y - 7), CARTC, 2.0)
	draw_line(Vector2(bx + basket_w - 8, by + basket_h), Vector2(bx + basket_w - 8, feet_y - 7), CARTC, 2.0)
	draw_circle(Vector2(bx + 8, feet_y - 7), 7.0, CARTC.darkened(0.35))
	draw_circle(Vector2(bx + basket_w - 8, feet_y - 7), 7.0, CARTC.darkened(0.35))


func _draw_box(x: float, feet_y: float, w: int, h: int, tag: String) -> void:
	var top := feet_y - h
	_rect(x, top, float(w), float(h), GOODSC)
	_box(x, top, float(w), float(h), GOODSC.darkened(0.4))
	draw_line(Vector2(x + float(w) * 0.5, top), Vector2(x + float(w) * 0.5, feet_y), GOODSC.darkened(0.25), 1.0)
	draw_line(Vector2(x, top + float(h) * 0.45), Vector2(x + float(w), top + float(h) * 0.45), GOODSC.darkened(0.25), 1.0)


func _draw_heater(x: float, feet_y: float, w: int, h: int) -> void:
	var top := feet_y - h
	_rect(x, top, float(w), float(h), HEATC)
	_box(x, top, float(w), float(h), HEATC.darkened(0.45))
	# 防护栅
	for i in range(1, 5):
		var lx := x + float(w) * float(i) / 5.0
		draw_line(Vector2(lx, top + 10), Vector2(lx, feet_y - 18), HEATC.darkened(0.35), 1.0)
	# 通电指示（琥珀光，非明火）
	_rect(x + 6, top + float(h) - 16, float(w) - 12, 6, Color(0.94, 0.66, 0.29, 0.85))
	draw_circle(Vector2(x + float(w) * 0.5, top + float(h) - 13), 10.0, Color(0.94, 0.66, 0.29, 0.16))


# ------------------------------------------------------------------ 绘图工具
func _rect(x: float, y: float, w: float, h: float, c: Color) -> void:
	if w <= 0.0 or h <= 0.0:
		return
	draw_rect(Rect2(x, y, w, h), c, true, -1.0, false)


func _box(x: float, y: float, w: float, h: float, c: Color, lw: float = 1.0) -> void:
	if w <= 0.0 or h <= 0.0:
		return
	draw_rect(Rect2(x, y, w, h), c, false, lw, false)


func _dash_h(x1: float, x2: float, y: float, c: Color, dash: float = 5.0, gap: float = 4.0) -> void:
	var x := x1
	while x < x2:
		draw_line(Vector2(x, y), Vector2(minf(x + dash, x2), y), c, 1.0)
		x += dash + gap


func _dash_v(y1: float, y2: float, x: float, c: Color, dash: float = 5.0, gap: float = 4.0) -> void:
	var y := y1
	while y < y2:
		draw_line(Vector2(x, y), Vector2(x, minf(y + dash, y2)), c, 1.0)
		y += dash + gap


func _dash_box(x: float, y: float, w: float, h: float, c: Color) -> void:
	_dash_h(x, x + w, y, c)
	_dash_h(x, x + w, y + h, c)
	_dash_v(y, y + h, x, c)
	_dash_v(y, y + h, x + w, c)


func _hatch_band(x: float, y: float, w: float, h: float, c: Color) -> void:
	_rect(x, y, w, h, c)


func _bracket_h(x1: float, x2: float, y: float, label: String, c: Color = AMBER) -> void:
	draw_line(Vector2(x1, y), Vector2(x2, y), c, 1.0)
	draw_line(Vector2(x1, y - 5), Vector2(x1, y + 5), c, 1.0)
	draw_line(Vector2(x2, y - 5), Vector2(x2, y + 5), c, 1.0)
	var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	_rect((x1 + x2) * 0.5 - w * 0.5 - 3, y + 4, w + 6, 13, Color(0.05, 0.06, 0.07, 0.85))
	_text_center((x1 + x2) * 0.5, y + 5, label, 10, c)


func _v_bracket(x: float, y1: float, y2: float, label: String, c: Color = AMBER) -> void:
	draw_line(Vector2(x, y1), Vector2(x, y2), c, 1.0)
	draw_line(Vector2(x - 4, y1), Vector2(x + 4, y1), c, 1.0)
	draw_line(Vector2(x - 4, y2), Vector2(x + 4, y2), c, 1.0)
	_text(x + 6, (y1 + y2) * 0.5 - 8, label, 10, c)


func _text(x: float, y: float, s: String, size: int, c: Color) -> void:
	if _font == null:
		return
	draw_string(_font, Vector2(x, y + size * 0.82), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


func _text_center(cx: float, y: float, s: String, size: int, c: Color) -> void:
	if _font == null:
		return
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(_font, Vector2(cx - w * 0.5, y + size * 0.82), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


## 带深色底板的文字：压在网格/虚线上也读得清
func _plate_text(x: float, y: float, s: String, size: int, c: Color) -> void:
	if _font == null:
		return
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_rect(x - 3, y - 1, w + 6, size + 4, Color(0.05, 0.06, 0.07, 0.82))
	_text(x, y, s, size, c)


func _plate_text_center(cx: float, y: float, s: String, size: int, c: Color) -> void:
	if _font == null:
		return
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_plate_text(cx - w * 0.5, y, s, size, c)
