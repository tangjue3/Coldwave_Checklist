class_name Season1Layout
extends RefCounted
## TASK-SCENE-002 · 第一季横版场景白盒工程集中配置表
##
## 作用：
##   1) 严格依据《第一季横版场景设计与提示词.md》与《第一季完整剧本.md》，
##      集中定义室外主地图（15,360 px 三段连续长街）及全部 11 张室内场景的
##      世界坐标、建筑外框、楼层高度、门窗尺寸、出入口对应关系、楼梯连接、
##      真实运行时道具落位与开发预览快速跳转点。
##   2) 后续正式美术切片（TileSet / 建筑立面 / 室内墙板 / 门窗 / 家具道具）到位时，
##      只需按 `art_slot` 替换对应节点外观或在此处微调坐标，无需重写场景逻辑。
##
## 冻结工程尺寸基线（SCALE-001）：
##   - 逻辑视口：960 × 540
##   - 世界格网：32 × 32 px
##   - 角色可见高度：160 px（5 tile），碰撞盒：28 × 160 px
##   - 住宅/普通商铺门：外框 96 × 192 px（净洞 80 × 184 px，门框 8 px）
##   - 超市/大型仓储入口：外框 192 × 224 px（净洞 184 × 216 px，收边 4 px）
##   - 四层金属货架（ART_FURN_101）：可见 96 × 192 px（画布 128 × 208 px）
##   - 购物车（ART_FURN_103 r03）：逻辑车长 96 × 96 px（可见 96 × 90 px）
##   - 超市主通道净宽：192 px（6 tile）
##   - 一层地面基线：GROUND_Y = 416.0（13 tile）
##   - 二层地面基线：FLOOR2_Y = 128.0（4 tile，1F 净高 256 px + 楼板厚 32 px = 288 px）

const VIEWPORT_SIZE := Vector2(960, 540)
const TILE_SIZE := 32
const CHAR_VISIBLE_H := 160.0
const CHAR_COLLIDE_W := 28.0

const GROUND_Y := 416.0
const FLOOR2_Y := 128.0
const SLAB_THICKNESS := 32.0

const DOOR_STD_W := 96.0
const DOOR_STD_H := 192.0
const DOOR_WIDE_W := 192.0
const DOOR_WIDE_H := 224.0
const SHELF_W := 96.0
const SHELF_H := 192.0
const CART_W := 96.0
const AISLE_MAIN_W := 192.0

## 场景预览切换顺序（供开发预览顶栏使用）
const SCENE_ORDER: Array[StringName] = [
	&"outdoor_street",
	&"shelter",
	&"equipment_room",
	&"apartment_hallway",
	&"zhao_home",
	&"repair_corner",
	&"convenience_store",
	&"pharmacy",
	&"supermarket",
	&"hardware_store",
	&"wholesale_warehouse",
	&"logistics_hub",
	&"past_corridor",
]

## 场景简短按钮标签
const SCENE_SHORT_NAMES: Dictionary = {
	&"outdoor_street": "室外长街(主图)",
	&"shelter": "A/B安全屋(2层)",
	&"equipment_room": "C设备区",
	&"apartment_hallway": "G居民楼道(2层)",
	&"zhao_home": "P赵阿姨家",
	&"repair_corner": "Q维修角",
	&"convenience_store": "J便利店",
	&"pharmacy": "N药店",
	&"supermarket": "H/S超市",
	&"hardware_store": "I五金店",
	&"wholesale_warehouse": "K批发仓",
	&"logistics_hub": "L中转口",
	&"past_corridor": "G0前世走廊",
}


static func get_scene_spec(key: StringName) -> Dictionary:
	match key:
		&"outdoor_street":
			return _spec_outdoor_street()
		&"shelter":
			return _spec_shelter()
		&"equipment_room":
			return _spec_equipment_room()
		&"apartment_hallway":
			return _spec_apartment_hallway()
		&"zhao_home":
			return _spec_zhao_home()
		&"repair_corner":
			return _spec_repair_corner()
		&"convenience_store":
			return _spec_convenience_store()
		&"pharmacy":
			return _spec_pharmacy()
		&"supermarket":
			return _spec_supermarket()
		&"hardware_store":
			return _spec_hardware_store()
		&"wholesale_warehouse":
			return _spec_wholesale_warehouse()
		&"logistics_hub":
			return _spec_logistics_hub()
		&"past_corridor":
			return _spec_past_corridor()
		_:
			return _spec_outdoor_street()


# ==============================================================================
# 1. 室外主地图：第一季长街（15,360 px = 480 tiles = 16 视口，三段无缝连续）
# ==============================================================================
static func _spec_outdoor_street() -> Dictionary:
	return {
		"key": &"outdoor_street",
		"title": "第一季室外主地图 · 临江市梧桐里长街",
		"doc_code": "D/E/F/O/U/M/T/W",
		"is_outdoor": true,
		"width": 15360.0,
		"ground_y": GROUND_Y,
		"sky_color": Color(0.24, 0.28, 0.33, 1.0),
		"ground_color": Color(0.30, 0.32, 0.35, 1.0),
		"road_top_color": Color(0.44, 0.47, 0.51, 1.0),
		"default_spawn": &"spawn_home_gate",
		"floors": [
			{"floor": 1, "name": "1F 沿街连续行走地面", "ground_y": GROUND_Y, "ceiling_y": -160.0, "x0": 0.0, "x1": 15360.0},
		],
		"segments": [
			{
				"index": 1,
				"title": "第一段：家门—梧桐里社区",
				"doc_code": "C/D/E/F/Q/R/O/T/W",
				"x0": 0.0,
				"x1": 5120.0,
				"color": Color(0.27, 0.31, 0.36, 1.0),
				"summary": "小楼设备区 → 小楼正门与巷口 → 公告栏(含W住处门窗) → 居民楼单元门(含T遮棚屋顶) → 维修角 → 物业门岗 → 公交站",
			},
			{
				"index": 2,
				"title": "第二段：街角—商业街",
				"doc_code": "J/N/H/I/U",
				"x0": 5120.0,
				"x1": 10240.0,
				"color": Color(0.25, 0.29, 0.35, 1.0),
				"summary": "公交站街角之后 → 唐宁便利店 → 社区药店门口 → 灾前连锁超市入口 → 五金家电店 → 临时管制路口",
			},
			{
				"index": 3,
				"title": "第三段：批发仓—中转点",
				"doc_code": "K/L",
				"x0": 10240.0,
				"x1": 15360.0,
				"color": Color(0.22, 0.26, 0.31, 1.0),
				"summary": "管制路口之后 → 独立批发仓入口及装卸区 → 物流中转取货口 → 城市边缘右侧边界",
			},
		],
		"spawns": {
			&"spawn_equip_gate": {"x": 384.0, "floor": 1, "ground_y": GROUND_Y, "facing": 1, "label": "小楼设备区门外"},
			&"spawn_home_gate": {"x": 912.0, "floor": 1, "ground_y": GROUND_Y, "facing": 1, "label": "小楼正门巷口"},
			&"spawn_unit_gate": {"x": 3008.0, "floor": 1, "ground_y": GROUND_Y, "facing": 1, "label": "居民楼单元门外"},
			&"spawn_repair_gate": {"x": 3856.0, "floor": 1, "ground_y": GROUND_Y, "facing": 1, "label": "陈叔维修角门外"},
			&"spawn_conv_gate": {"x": 5568.0, "floor": 1, "ground_y": GROUND_Y, "facing": 1, "label": "唐宁便利店门外"},
			&"spawn_pharm_gate": {"x": 6432.0, "floor": 1, "ground_y": GROUND_Y, "facing": 1, "label": "社区药店门外"},
			&"spawn_market_gate": {"x": 7552.0, "floor": 1, "ground_y": GROUND_Y, "facing": 1, "label": "连锁超市入口外"},
			&"spawn_hardware_gate": {"x": 8784.0, "floor": 1, "ground_y": GROUND_Y, "facing": 1, "label": "五金家电店门外"},
			&"spawn_warehouse_gate": {"x": 10880.0, "floor": 1, "ground_y": GROUND_Y, "facing": 1, "label": "批发仓正门外"},
			&"spawn_warehouse_dock": {"x": 12096.0, "floor": 1, "ground_y": GROUND_Y, "facing": -1, "label": "批发仓装卸门外"},
			&"spawn_logistics_gate": {"x": 13440.0, "floor": 1, "ground_y": GROUND_Y, "facing": -1, "label": "物流中转口外"},
		},
		"buildings": [
			# ---- 第一段：家门—梧桐里社区 ----
			{
				"id": "b01_equip_bay",
				"doc_code": "C",
				"title": "① 小楼设备区",
				"subtitle": "外置独立通风设备间 (160..640, 宽480×高256)",
				"x": 160.0,
				"w": 480.0,
				"h": 256.0,
				"floor": 1,
				"floors_count": 1,
				"wall_color": Color(0.32, 0.35, 0.37, 1.0),
				"roof_color": Color(0.22, 0.25, 0.27, 1.0),
				"accent_color": Color(0.52, 0.58, 0.62, 1.0),
				"roof_style": "flat_vent",
				"art_slot": "SLOT_EXT_B01_EQUIP_BAY",
				"registry_id": "ART_SCENE_107 (预留:安全设备区)",
				"windows": [
					{"x": 496.0, "y_off": 112.0, "w": 96.0, "h": 64.0, "kind": "louver", "label": "外墙通风格栅"},
				],
				"notes": ["与生活区隔离通风", "独立门进设备间 C"],
			},
			{
				"id": "b02_protagonist_house",
				"doc_code": "A/B/D/M",
				"title": "② 外婆旧两层小楼与正门巷口",
				"subtitle": "主角住处立面 1F+2F (640..1472, 宽832×高480) + 巷口收货区 (1472..1856)",
				"x": 640.0,
				"w": 832.0,
				"h": 480.0,
				"floor": 1,
				"floors_count": 2,
				"wall_color": Color(0.42, 0.37, 0.34, 1.0),
				"roof_color": Color(0.27, 0.23, 0.22, 1.0),
				"accent_color": Color(0.83, 0.64, 0.42, 1.0),
				"roof_style": "pitched_antenna",
				"art_slot": "SLOT_EXT_B02_SAFEHOUSE",
				"registry_id": "ART_SCENE_102 (已用:安全屋概念) + ART_SCENE_103 (已用:街道概念)",
				"windows": [
					{"x": 704.0, "y_off": 96.0, "w": 96.0, "h": 80.0, "kind": "warm_plant", "label": "1F窗(绿植/暖光)"},
					{"x": 1248.0, "y_off": 96.0, "w": 112.0, "h": 80.0, "kind": "warm", "label": "1F起居窗"},
					{"x": 736.0, "y_off": 336.0, "w": 112.0, "h": 80.0, "kind": "dark_2f", "label": "2F旧储物窗"},
					{"x": 1184.0, "y_off": 336.0, "w": 128.0, "h": 80.0, "kind": "warm_2f", "label": "2F临街窗"},
				],
				"notes": ["正门 96×192 @x=912", "右侧临时收货位 + 巷口路灯与车架", "屋顶含 M 电台天线位"],
			},
			{
				"id": "b03_notice_and_meng",
				"doc_code": "F/R/W",
				"title": "③ 社区公告栏 & W 孟雨薇住处外观",
				"subtitle": "主公告栏 (1920..2176) + W 普通住户门窗模块 (2240..2528)",
				"x": 1920.0,
				"w": 608.0,
				"h": 320.0,
				"floor": 1,
				"floors_count": 1,
				"wall_color": Color(0.36, 0.38, 0.41, 1.0),
				"roof_color": Color(0.25, 0.27, 0.30, 1.0),
				"accent_color": Color(0.76, 0.71, 0.62, 1.0),
				"roof_style": "low_wall",
				"art_slot": "SLOT_EXT_B03_NOTICE_MENG",
				"registry_id": "ART_SCENE_103 (已用:街道概念) + ART_SCENE_105 (预留:街角与路牌)",
				"windows": [
					{"x": 1952.0, "y_off": 88.0, "w": 192.0, "h": 96.0, "kind": "board", "label": "社区主公告板"},
					{"x": 2272.0, "y_off": 208.0, "w": 88.0, "h": 64.0, "kind": "cold", "label": "W 住处窗"},
				],
				"notes": ["主公告栏始终在居民楼左侧", "W 为可选住处外观模块(装饰门)"],
			},
			{
				"id": "b04_apartment_building",
				"doc_code": "F/T",
				"title": "④ 梧桐里居民楼 & T 遮棚屋顶",
				"subtitle": "多户住宅楼立面 (2560..3584, 宽1024×高512) + 单元门 + 遮棚屋顶小狗观察位",
				"x": 2560.0,
				"w": 1024.0,
				"h": 512.0,
				"floor": 1,
				"floors_count": 2,
				"wall_color": Color(0.38, 0.41, 0.45, 1.0),
				"roof_color": Color(0.26, 0.29, 0.33, 1.0),
				"accent_color": Color(0.68, 0.74, 0.80, 1.0),
				"roof_style": "apartment_awning",
				"art_slot": "SLOT_EXT_B04_APARTMENT",
				"registry_id": "ART_SCENE_103 (已用:街道概念，待自 ART_SCENE_113 起立项独立立面)",
				"windows": [
					{"x": 2656.0, "y_off": 96.0, "w": 112.0, "h": 80.0, "kind": "warm", "label": "1F 王秀琴家窗"},
					{"x": 3200.0, "y_off": 96.0, "w": 112.0, "h": 80.0, "kind": "cold", "label": "1F 邻户窗"},
					{"x": 2656.0, "y_off": 336.0, "w": 112.0, "h": 80.0, "kind": "warm_2f", "label": "2F 赵阿姨/小满窗"},
					{"x": 2960.0, "y_off": 336.0, "w": 96.0, "h": 80.0, "kind": "cold", "label": "2F 楼道采光窗"},
					{"x": 3232.0, "y_off": 336.0, "w": 112.0, "h": 80.0, "kind": "cold", "label": "2F 住户窗"},
				],
				"notes": ["单元门 @x=3008 进 G 公共楼道", "右侧低遮棚屋顶 T 预留 S04 小狗站立位与排水管"],
			},
			{
				"id": "b05_repair_corner",
				"doc_code": "Q",
				"title": "⑤ 陈叔维修角",
				"subtitle": "半开旧卷帘门面 (3648..4064, 宽416×高256)",
				"x": 3648.0,
				"w": 416.0,
				"h": 256.0,
				"floor": 1,
				"floors_count": 1,
				"wall_color": Color(0.31, 0.36, 0.39, 1.0),
				"roof_color": Color(0.22, 0.26, 0.29, 1.0),
				"accent_color": Color(0.56, 0.67, 0.72, 1.0),
				"roof_style": "shutter_shop",
				"art_slot": "SLOT_EXT_B05_REPAIR_CORNER",
				"registry_id": "ART_SCENE_103 (已用:街道概念，待自 ART_SCENE_113 起立项维修角)",
				"windows": [
					{"x": 3680.0, "y_off": 96.0, "w": 96.0, "h": 80.0, "kind": "shutter", "label": "工具展示窗"},
				],
				"notes": ["位于居民楼与物业门岗之间", "门 @x=3856 进 Q 维修角内景"],
			},
			{
				"id": "b06_guard_booth",
				"doc_code": "F/R",
				"title": "⑥ 物业门岗 & R 临时信息/交换点",
				"subtitle": "门岗岗亭 + 小纸条夹 + 折叠交接桌 (4128..4544, 宽416×高256)",
				"x": 4128.0,
				"w": 416.0,
				"h": 256.0,
				"floor": 1,
				"floors_count": 1,
				"wall_color": Color(0.29, 0.34, 0.40, 1.0),
				"roof_color": Color(0.20, 0.24, 0.29, 1.0),
				"accent_color": Color(0.85, 0.68, 0.42, 1.0),
				"roof_style": "booth",
				"art_slot": "SLOT_EXT_B06_GUARD_BOOTH",
				"registry_id": "ART_SCENE_103 (已用:老小区入口与街道概念)",
				"windows": [
					{"x": 4192.0, "y_off": 96.0, "w": 128.0, "h": 88.0, "kind": "warm", "label": "门岗值班小窗"},
					{"x": 4352.0, "y_off": 104.0, "w": 64.0, "h": 64.0, "kind": "board", "label": "求助纸条夹"},
				],
				"notes": ["李建国值班岗亭", "旁设 R 折叠交接桌与纸条夹"],
			},
			{
				"id": "b07_bus_stop",
				"doc_code": "O",
				"title": "⑦ 公交站与街角",
				"subtitle": "简易候车亭 + 空白站牌 + 候车长椅 (4608..5056, 宽448×高224)",
				"x": 4608.0,
				"w": 448.0,
				"h": 224.0,
				"floor": 1,
				"floors_count": 1,
				"wall_color": Color(0.30, 0.35, 0.38, 0.85),
				"roof_color": Color(0.21, 0.26, 0.30, 1.0),
				"accent_color": Color(0.72, 0.78, 0.84, 1.0),
				"roof_style": "canopy",
				"art_slot": "SLOT_EXT_B07_BUS_STOP",
				"registry_id": "ART_SCENE_103 (已用:街道概念) + ART_SCENE_105 (预留:街角与路牌)",
				"windows": [
					{"x": 4672.0, "y_off": 80.0, "w": 160.0, "h": 112.0, "kind": "board", "label": "候车亭信息板"},
				],
				"notes": ["第一段与第二段交界地标", "预留王秀琴等待与道路停运公告位"],
			},
			# ---- 第二段：街角—商业街 ----
			{
				"id": "b08_convenience_store",
				"doc_code": "J",
				"title": "⑧ 唐宁的街角便利店",
				"subtitle": "一层便利店 + 二层唐母休养窗 (5248..5952, 宽704×高448)",
				"x": 5248.0,
				"w": 704.0,
				"h": 448.0,
				"floor": 1,
				"floors_count": 2,
				"wall_color": Color(0.38, 0.36, 0.33, 1.0),
				"roof_color": Color(0.26, 0.24, 0.22, 1.0),
				"accent_color": Color(0.84, 0.64, 0.42, 1.0),
				"roof_style": "shop_sign",
				"art_slot": "SLOT_EXT_B08_CONVENIENCE",
				"registry_id": "ART_SCENE_103 (已用:街道店铺概念，待自 ART_SCENE_113 起立项便利店)",
				"windows": [
					{"x": 5664.0, "y_off": 88.0, "w": 192.0, "h": 104.0, "kind": "warm", "label": "便利店橱窗(可换卷帘)"},
					{"x": 5440.0, "y_off": 320.0, "w": 128.0, "h": 80.0, "kind": "warm_2f", "label": "2F 唐母房间窗"},
				],
				"notes": ["门 @x=5568 进 J 便利店内景", "灾后可切半拉卷帘与门口交易状态"],
			},
			{
				"id": "b09_pharmacy",
				"doc_code": "N",
				"title": "⑨ 社区药店门口",
				"subtitle": "空白十字灯箱 + 玻璃门 + 橱窗 (6080..6784, 宽704×高288)",
				"x": 6080.0,
				"w": 704.0,
				"h": 288.0,
				"floor": 1,
				"floors_count": 1,
				"wall_color": Color(0.35, 0.40, 0.38, 1.0),
				"roof_color": Color(0.24, 0.29, 0.27, 1.0),
				"accent_color": Color(0.60, 0.78, 0.68, 1.0),
				"roof_style": "shop_sign",
				"art_slot": "SLOT_EXT_B09_PHARMACY",
				"registry_id": "ART_SCENE_103 (已用:街道店铺概念，待自 ART_SCENE_113 起立项药店)",
				"windows": [
					{"x": 6144.0, "y_off": 96.0, "w": 160.0, "h": 96.0, "kind": "warm", "label": "药店左橱窗"},
					{"x": 6528.0, "y_off": 96.0, "w": 160.0, "h": 96.0, "kind": "board", "label": "营业告示与右橱窗"},
				],
				"notes": ["位于便利店与超市之间", "门 @x=6432 进 N 药店内景(扩展建议)"],
			},
			{
				"id": "b10_supermarket",
				"doc_code": "H",
				"title": "⑩ 灾前连锁超市",
				"subtitle": "大型平价超市门面 + 192×224 自动门入口 (6912..8192, 宽1280×高352)",
				"x": 6912.0,
				"w": 1280.0,
				"h": 352.0,
				"floor": 1,
				"floors_count": 1,
				"wall_color": Color(0.40, 0.34, 0.29, 1.0),
				"roof_color": Color(0.28, 0.22, 0.18, 1.0),
				"accent_color": Color(0.90, 0.66, 0.38, 1.0),
				"roof_style": "supermarket_fascia",
				"art_slot": "SLOT_EXT_B10_SUPERMARKET",
				"registry_id": "ART_SCENE_101 (已用:灾前超市概念)",
				"windows": [
					{"x": 7008.0, "y_off": 96.0, "w": 320.0, "h": 112.0, "kind": "warm", "label": "超市左侧展示窗"},
					{"x": 7744.0, "y_off": 96.0, "w": 320.0, "h": 112.0, "kind": "warm", "label": "超市右侧促销与限购告示窗"},
				],
				"notes": ["入口 192×224 @x=7552 进 H 超市内景", "含推车停放廊与限购告示牌位"],
			},
			{
				"id": "b11_hardware_store",
				"doc_code": "I",
				"title": "⑪ 五金 / 家电店",
				"subtitle": "门窗密封、取暖与发电设备商店 (8320..9344, 宽1024×高320)",
				"x": 8320.0,
				"w": 1024.0,
				"h": 320.0,
				"floor": 1,
				"floors_count": 1,
				"wall_color": Color(0.34, 0.37, 0.34, 1.0),
				"roof_color": Color(0.23, 0.26, 0.23, 1.0),
				"accent_color": Color(0.78, 0.65, 0.44, 1.0),
				"roof_style": "shop_sign",
				"art_slot": "SLOT_EXT_B11_HARDWARE",
				"registry_id": "ART_SCENE_112 (预留:五金/家电店)",
				"windows": [
					{"x": 8416.0, "y_off": 96.0, "w": 224.0, "h": 96.0, "kind": "warm", "label": "工具与门窗样板橱窗"},
					{"x": 8928.0, "y_off": 96.0, "w": 288.0, "h": 112.0, "kind": "shutter", "label": "取暖器展示与大件出货卷帘"},
				],
				"notes": ["门 @x=8784 进 I 五金家电店", "右侧附带大件装货卷帘口"],
			},
			{
				"id": "b12_traffic_checkpoint",
				"doc_code": "U",
				"title": "⑫ 临时管制路口",
				"subtitle": "空白路牌 + 可移动护栏 + 道路公告 + 停靠位 (9472..10176, 宽704×高256)",
				"x": 9472.0,
				"w": 704.0,
				"h": 256.0,
				"floor": 1,
				"floors_count": 1,
				"wall_color": Color(0.28, 0.32, 0.36, 0.80),
				"roof_color": Color(0.20, 0.23, 0.27, 1.0),
				"accent_color": Color(0.86, 0.56, 0.38, 1.0),
				"roof_style": "gantry",
				"art_slot": "SLOT_EXT_B12_CHECKPOINT",
				"registry_id": "ART_SCENE_103 (已用:街道概念) + ART_SCENE_105 (预留:街角与路牌)",
				"windows": [
					{"x": 9600.0, "y_off": 80.0, "w": 224.0, "h": 80.0, "kind": "board", "label": "道路管制公告牌"},
				],
				"notes": ["第二段商业街与第三段仓储区分界节点", "护栏与积雪分层，不永久封死合法取货路径"],
			},
			# ---- 第三段：批发仓—中转点 ----
			{
				"id": "b13_wholesale_warehouse",
				"doc_code": "K",
				"title": "⑬ 独立批发仓与装卸区",
				"subtitle": "城市边缘大宗批发仓库 (10432..12480, 宽2048×高384)",
				"x": 10432.0,
				"w": 2048.0,
				"h": 384.0,
				"floor": 1,
				"floors_count": 1,
				"wall_color": Color(0.33, 0.35, 0.38, 1.0),
				"roof_color": Color(0.22, 0.24, 0.27, 1.0),
				"accent_color": Color(0.74, 0.62, 0.42, 1.0),
				"roof_style": "industrial_warehouse",
				"art_slot": "SLOT_EXT_B13_WAREHOUSE",
				"registry_id": "ART_SCENE_104 (预留:批发仓库)",
				"windows": [
					{"x": 11200.0, "y_off": 240.0, "w": 256.0, "h": 64.0, "kind": "louver", "label": "高窗采光带 A"},
					{"x": 11584.0, "y_off": 240.0, "w": 256.0, "h": 64.0, "kind": "louver", "label": "高窗采光带 B"},
				],
				"notes": ["正门 @x=10880 进 K 批发仓左入口", "装卸门 @x=12096 进 K 批发仓右装卸区（双门独立对应）"],
			},
			{
				"id": "b14_logistics_hub",
				"doc_code": "L",
				"title": "⑭ 物流中转口 / 大件取货区",
				"subtitle": "简易中转雨棚 + 待领货架区 + 交接窗口 (12736..14592, 宽1856×高320)",
				"x": 12736.0,
				"w": 1856.0,
				"h": 320.0,
				"floor": 1,
				"floors_count": 1,
				"wall_color": Color(0.30, 0.34, 0.38, 1.0),
				"roof_color": Color(0.20, 0.24, 0.28, 1.0),
				"accent_color": Color(0.68, 0.74, 0.80, 1.0),
				"roof_style": "canopy",
				"art_slot": "SLOT_EXT_B14_LOGISTICS",
				"registry_id": "待立项 (自 ART_SCENE_113 起顺延，注:109受保护为电台/手机特写)",
				"windows": [
					{"x": 13760.0, "y_off": 96.0, "w": 256.0, "h": 96.0, "kind": "board", "label": "大件订单牌与交接窗"},
				],
				"notes": ["取货口门 @x=13440 进 L 中转点内景", "右侧 14592..15360 为城市边缘边界"],
			},
		],
		"doors": [
			{
				"id": "door_equip_bay",
				"label": "① 小楼设备区门",
				"prompt": "小楼外置设备区 (C)",
				"x": 384.0,
				"floor": 1,
				"w": DOOR_STD_W,
				"h": DOOR_STD_H,
				"target_scene": &"equipment_room",
				"target_spawn": &"spawn_entrance",
				"interactive": true,
				"style": "metal",
			},
			{
				"id": "door_safe_house",
				"label": "② 小楼正门",
				"prompt": "主角安全屋一层 (A)",
				"x": 912.0,
				"floor": 1,
				"w": DOOR_STD_W,
				"h": DOOR_STD_H,
				"target_scene": &"shelter",
				"target_spawn": &"spawn_front_door",
				"interactive": true,
				"style": "reinforced_home",
			},
			{
				"id": "door_meng_ facade",
				"label": "W 孟雨薇住处门(外观装饰)",
				"prompt": "",
				"x": 2384.0,
				"floor": 1,
				"w": DOOR_STD_W,
				"h": DOOR_STD_H,
				"target_scene": &"",
				"target_spawn": &"",
				"interactive": false,
				"style": "deco",
			},
			{
				"id": "door_apartment_unit",
				"label": "④ 居民楼单元门",
				"prompt": "居民楼公共楼道 (G)",
				"x": 3008.0,
				"floor": 1,
				"w": DOOR_STD_W,
				"h": DOOR_STD_H,
				"target_scene": &"apartment_hallway",
				"target_spawn": &"spawn_unit_door",
				"interactive": true,
				"style": "unit_gate",
			},
			{
				"id": "door_repair_corner",
				"label": "⑤ 陈叔维修角门",
				"prompt": "陈叔维修角 (Q)",
				"x": 3856.0,
				"floor": 1,
				"w": DOOR_STD_W,
				"h": DOOR_STD_H,
				"target_scene": &"repair_corner",
				"target_spawn": &"spawn_entrance",
				"interactive": true,
				"style": "shutter",
			},
			{
				"id": "door_convenience",
				"label": "⑧ 便利店门",
				"prompt": "唐宁的便利店 (J)",
				"x": 5568.0,
				"floor": 1,
				"w": DOOR_STD_W,
				"h": DOOR_STD_H,
				"target_scene": &"convenience_store",
				"target_spawn": &"spawn_entrance",
				"interactive": true,
				"style": "glass",
			},
			{
				"id": "door_pharmacy",
				"label": "⑨ 药店门",
				"prompt": "社区药店内景 (N)",
				"x": 6432.0,
				"floor": 1,
				"w": DOOR_STD_W,
				"h": DOOR_STD_H,
				"target_scene": &"pharmacy",
				"target_spawn": &"spawn_entrance",
				"interactive": true,
				"style": "glass",
			},
			{
				"id": "door_supermarket",
				"label": "⑩ 超市入口",
				"prompt": "灾前连锁超市 (H)",
				"x": 7552.0,
				"floor": 1,
				"w": DOOR_WIDE_W,
				"h": DOOR_WIDE_H,
				"target_scene": &"supermarket",
				"target_spawn": &"spawn_entrance",
				"interactive": true,
				"style": "wide_glass",
			},
			{
				"id": "door_hardware",
				"label": "⑪ 五金店门",
				"prompt": "五金 / 家电店 (I)",
				"x": 8784.0,
				"floor": 1,
				"w": DOOR_STD_W,
				"h": DOOR_STD_H,
				"target_scene": &"hardware_store",
				"target_spawn": &"spawn_entrance",
				"interactive": true,
				"style": "glass",
			},
			{
				"id": "door_warehouse_main",
				"label": "⑬ 批发仓入口",
				"prompt": "独立批发仓正门 (K)",
				"x": 10880.0,
				"floor": 1,
				"w": DOOR_WIDE_W,
				"h": DOOR_WIDE_H,
				"target_scene": &"wholesale_warehouse",
				"target_spawn": &"spawn_entrance",
				"interactive": true,
				"style": "wide_industrial",
			},
			{
				"id": "door_warehouse_dock",
				"label": "⑬b 批发仓装卸门",
				"prompt": "批发仓装卸区 (K右端)",
				"x": 12096.0,
				"floor": 1,
				"w": DOOR_WIDE_W,
				"h": DOOR_WIDE_H,
				"target_scene": &"wholesale_warehouse",
				"target_spawn": &"spawn_loading_bay",
				"interactive": true,
				"style": "wide_industrial",
			},
			{
				"id": "door_logistics_hub",
				"label": "⑭ 物流中转口",
				"prompt": "中转点取货区 (L)",
				"x": 13440.0,
				"floor": 1,
				"w": DOOR_STD_W,
				"h": DOOR_STD_H,
				"target_scene": &"logistics_hub",
				"target_spawn": &"spawn_entrance",
				"interactive": true,
				"style": "metal",
			},
		],
		"stairs": [],
		"shelves": [],
		"carts": [],
		"props": [
			{"id": "p_delivery_zone", "label": "D 门前收货箱放置位", "kind": "delivery_pad", "x": 1152.0, "floor": 1, "w": 160.0, "h": 64.0, "spot_detail": "D 主角门外临时收货位（S10 保留门口通路，不封死正门 x=912）"},
			{"id": "p_alley_lamp", "label": "巷口路灯与旧车架", "kind": "lamp_bike", "x": 1664.0, "floor": 1, "w": 128.0, "h": 224.0, "spot_detail": ""},
			{"id": "p_notice_board", "label": "社区主公告栏", "kind": "notice_board", "x": 2048.0, "floor": 1, "w": 160.0, "h": 160.0, "spot_detail": "F/R 社区主公告栏（位于居民楼左侧，展示天气预警与邻里通知）"},
			{"id": "p_roof_dog_spot", "label": "T 遮棚屋顶与小狗观察位", "kind": "awning_marker", "x": 3360.0, "floor": 1, "w": 160.0, "h": 96.0, "spot_detail": "T 居民楼低遮棚屋顶（S04 屋顶小狗站立位与排水管，从地面观察，无需攀爬）"},
			{"id": "p_guard_exchange", "label": "物业门岗信息/交换点 (R)", "kind": "guard_table", "x": 4336.0, "floor": 1, "w": 160.0, "h": 96.0, "spot_detail": "F/R 物业门岗窗口、求助纸条夹与折叠交接桌（D01B 登记 / D03B 交易 / D07 点名）"},
			{"id": "p_bus_stop", "label": "公交站牌与候车凳 (O)", "kind": "bus_sign", "x": 4864.0, "floor": 1, "w": 160.0, "h": 192.0, "spot_detail": "O 梧桐里公交站（第一、二段交界，王秀琴等待家人与交通停运公告位）"},
			{"id": "p_checkpoint", "label": "临时管制路口护栏与公告 (U)", "kind": "barrier", "x": 9856.0, "floor": 1, "w": 256.0, "h": 128.0, "spot_detail": "U 临时管制路口（五金店与批发仓之间，护栏与积雪分层，保留合法取货通路）"},
			{"id": "p_warehouse_truck", "label": "批发仓装卸停靠车位", "kind": "dock_pad", "x": 12320.0, "floor": 1, "w": 224.0, "h": 96.0, "spot_detail": ""},
		],
		"landmarks": [
			{"id": "lm01", "label": "1.设备区(C)", "x": 384.0, "floor": 1, "doc_code": "C"},
			{"id": "lm02", "label": "2.正门巷口(D)", "x": 912.0, "floor": 1, "doc_code": "A/D"},
			{"id": "lm03", "label": "3.公告栏/W", "x": 2048.0, "floor": 1, "doc_code": "F/W"},
			{"id": "lm04", "label": "4.居民楼/T", "x": 3008.0, "floor": 1, "doc_code": "F/T"},
			{"id": "lm05", "label": "5.维修角(Q)", "x": 3856.0, "floor": 1, "doc_code": "Q"},
			{"id": "lm06", "label": "6.物业门岗(R)", "x": 4336.0, "floor": 1, "doc_code": "F/R"},
			{"id": "lm07", "label": "7.公交站(O)", "x": 4864.0, "floor": 1, "doc_code": "O"},
			{"id": "lm08", "label": "8.便利店(J)", "x": 5568.0, "floor": 1, "doc_code": "J"},
			{"id": "lm09", "label": "9.药店(N)", "x": 6432.0, "floor": 1, "doc_code": "N"},
			{"id": "lm10", "label": "10.超市入口(H)", "x": 7552.0, "floor": 1, "doc_code": "H"},
			{"id": "lm11", "label": "11.五金店(I)", "x": 8784.0, "floor": 1, "doc_code": "I"},
			{"id": "lm12", "label": "12.管制路口(U)", "x": 9856.0, "floor": 1, "doc_code": "U"},
			{"id": "lm13", "label": "13.批发仓(K)", "x": 10880.0, "floor": 1, "doc_code": "K"},
			{"id": "lm14", "label": "14.物流中转口(L)", "x": 13440.0, "floor": 1, "doc_code": "L"},
		],
	}


# ==============================================================================
# 2. A/B 外婆旧两层小楼 · 安全屋（真实上下两层结构：1F y=416 + 2F y=128）
# ==============================================================================
static func _spec_shelter() -> Dictionary:
	return {
		"key": &"shelter",
		"title": "旧两层小楼 · 安全屋（A 一层 + B 二层 真实双层剖面）",
		"doc_code": "A/B/M/V",
		"is_outdoor": false,
		"width": 3200.0,
		"ground_y": GROUND_Y,
		"sky_color": Color(0.16, 0.15, 0.14, 1.0),
		"ground_color": Color(0.27, 0.22, 0.18, 1.0),
		"road_top_color": Color(0.46, 0.36, 0.27, 1.0),
		"default_spawn": &"spawn_front_door",
		"floors": [
			{"floor": 1, "name": "1F 安全屋一层（A 主体生活与储物层）", "ground_y": GROUND_Y, "ceiling_y": 160.0, "x0": 128.0, "x1": 3072.0},
			{"floor": 2, "name": "2F 小楼二层（B 旧储物室与扩建层）", "ground_y": FLOOR2_Y, "ceiling_y": -96.0, "x0": 320.0, "x1": 2880.0},
		],
		"segments": [
			{"index": 1, "title": "1F 卧室与清单区", "doc_code": "A/V", "x0": 128.0, "x1": 1152.0, "color": Color(0.32, 0.26, 0.22, 1.0), "summary": "卧床/外婆照片 → 清单桌/维修手册/绿植"},
			{"index": 2, "title": "1F 储物货架区", "doc_code": "A", "x0": 1152.0, "x1": 1984.0, "color": Color(0.29, 0.24, 0.20, 1.0), "summary": "四层金属货架阵列 + 地面堆箱区"},
			{"index": 3, "title": "1F 厨房/楼梯/玄关门", "doc_code": "A/B", "x0": 1984.0, "x1": 3072.0, "color": Color(0.34, 0.27, 0.22, 1.0), "summary": "简易厨房 → 通往二层楼梯 → 玄关与临街安全门"},
		],
		"spawns": {
			&"spawn_bed": {"x": 384.0, "floor": 1, "ground_y": GROUND_Y, "facing": 1, "label": "1F 卧床旁(P00醒来位)"},
			&"spawn_front_door": {"x": 2848.0, "floor": 1, "ground_y": GROUND_Y, "facing": -1, "label": "1F 玄关安全门内"},
			&"spawn_2f_stair": {"x": 2496.0, "floor": 2, "ground_y": FLOOR2_Y, "facing": -1, "label": "2F 楼梯口"},
		},
		"buildings": [
			{
				"id": "room_1f_main",
				"doc_code": "A/M/V",
				"title": "A 安全屋一层剖面 (1F, y=416, 净高256)",
				"subtitle": "卧床/外婆照片 → 清单桌/绿植(V) → 储物墙货架 → 厨房/暖气 → 楼梯口 → 玄关与临街安全门",
				"x": 128.0,
				"w": 2944.0,
				"h": 256.0,
				"floor": 1,
				"floors_count": 1,
				"wall_color": Color(0.33, 0.27, 0.22, 1.0),
				"roof_color": Color(0.24, 0.19, 0.16, 1.0),
				"accent_color": Color(0.86, 0.66, 0.42, 1.0),
				"roof_style": "interior_room",
				"art_slot": "SLOT_INT_SHELTER_1F",
				"registry_id": "ART_SCENE_102 (已用:v01-base/v01-upgraded 概念) + ART_SCENE_111 (预留:暴雪窗外)",
				"windows": [
					{"x": 832.0, "y_off": 96.0, "w": 160.0, "h": 96.0, "kind": "window_m", "label": "1F 窗外远景 M + 外婆绿植窗台"},
					{"x": 2112.0, "y_off": 96.0, "w": 160.0, "h": 96.0, "kind": "window_m", "label": "1F 生活区保温窗"},
				],
				"notes": ["与升级态共用固定墙/门/窗/楼梯坐标", "燃油发电机严禁入室（置于室外设备区 C）"],
			},
			{
				"id": "room_2f_upper",
				"doc_code": "B/M",
				"title": "B 小楼二层剖面 (2F, y=128, 净高224, 位于 1F 正上方)",
				"subtitle": "备用卧室/扩建空位 (320..1024) ← 旧家具与临街窗 (1024..1664) ← 封存旧储物室 (1664..2336) ← 2F楼梯口 (2336..2880)",
				"x": 320.0,
				"w": 2560.0,
				"h": 224.0,
				"floor": 2,
				"floors_count": 1,
				"wall_color": Color(0.28, 0.24, 0.21, 1.0),
				"roof_color": Color(0.20, 0.17, 0.15, 1.0),
				"accent_color": Color(0.74, 0.60, 0.44, 1.0),
				"roof_style": "attic_roof",
				"art_slot": "SLOT_INT_SHELTER_2F",
				"registry_id": "ART_SCENE_106 (预留:小楼楼上旧房间) + ART_SCENE_111 (预留:暴雪窗外)",
				"windows": [
					{"x": 640.0, "y_off": 80.0, "w": 160.0, "h": 88.0, "kind": "window_m", "label": "2F 备用室窗(M远景)"},
					{"x": 1312.0, "y_off": 80.0, "w": 192.0, "h": 88.0, "kind": "window_m", "label": "2F 朝街观察窗(可见屋顶天线M)"},
				],
				"notes": ["2F 与 1F 通过 x=2496 楼梯真实上下连通", "初始封条/清理中/修复后三态同坐标"],
			},
		],
		"doors": [
			{
				"id": "door_shelter_exit",
				"label": "玄关临街安全门",
				"prompt": "小楼正门巷口 (D/E)",
				"x": 2848.0,
				"floor": 1,
				"w": DOOR_STD_W,
				"h": DOOR_STD_H,
				"target_scene": &"outdoor_street",
				"target_spawn": &"spawn_home_gate",
				"interactive": true,
				"style": "reinforced_home",
			},
		],
		"stairs": [
			{
				"id": "stair_1f_to_2f",
				"label": "小楼室内木楼梯",
				"x": 2496.0,
				"w": 128.0,
				"from_floor": 1,
				"to_floor": 2,
				"from_y": GROUND_Y,
				"to_y": FLOOR2_Y,
				"target_x": 2496.0,
			},
			{
				"id": "stair_2f_to_1f",
				"label": "小楼室内木楼梯",
				"x": 2496.0,
				"w": 128.0,
				"from_floor": 2,
				"to_floor": 1,
				"from_y": FLOOR2_Y,
				"to_y": GROUND_Y,
				"target_x": 2496.0,
			},
		],
		"shelves": [
			{"id": "sh_home_1", "label": "安全屋储物架 A", "x": 1280.0, "floor": 1, "note": "安全屋 1F 储物架 A · 四层 96×192（ART_FURN_101 r01）", "items": ["water", "food"]},
			{"id": "sh_home_2", "label": "安全屋储物架 B", "x": 1472.0, "floor": 1, "note": "安全屋 1F 储物架 B · 四层 96×192（ART_FURN_101 r01）", "items": ["food", "water"]},
			{"id": "sh_home_3", "label": "安全屋储物架 C", "x": 1664.0, "floor": 1, "note": "安全屋 1F 储物架 C · 四层 96×192（预留空位）", "items": []},
		],
		"carts": [],
		"props": [
			{"id": "p_bed", "label": "1F 卧床与外婆旧照片", "kind": "bed", "x": 384.0, "floor": 1, "w": 224.0, "h": 96.0, "spot_detail": "P00/P00B 主角重生醒来床位，墙挂外婆旧相框（S07）"},
			{"id": "p_checklist_desk", "label": "清单桌、维修手册与绿植 (V)", "kind": "desk_plant", "x": 864.0, "floor": 1, "w": 192.0, "h": 96.0, "spot_detail": "V 纸质采购清单、外婆旧屋维修手册、收音机位与窗台绿植（SYS-00 / S02 / D06）"},
			{"id": "p_floor_stock", "label": "落地饮用水与食品箱", "kind": "floor_items", "x": 1840.0, "floor": 1, "w": 128.0, "h": 64.0, "spot_detail": ""},
			{"id": "p_kitchen", "label": "简易厨房与电暖器/储能位", "kind": "kitchen", "x": 2112.0, "floor": 1, "w": 256.0, "h": 112.0, "spot_detail": "1F 厨房灶台、室内电暖器（ART_FURN_102 64×96 占位）与储能电控柜位（D00B / S03 热火锅）"},
			{"id": "p_2f_storage", "label": "2F 封存旧储物室", "kind": "storage_2f", "x": 1920.0, "floor": 2, "w": 288.0, "h": 128.0, "spot_detail": "B 小楼二层旧储物室（P00B 初始封存，D04B 清理修复后开放扩建）"},
			{"id": "p_2f_furniture", "label": "2F 旧家具与天线检修窗", "kind": "furniture_2f", "x": 1312.0, "floor": 2, "w": 224.0, "h": 112.0, "spot_detail": "B 二层旧椅、被单覆盖家具及朝街窗户（可观察 M 屋顶天线）"},
			{"id": "p_2f_spare_room", "label": "2F 备用卧室/扩建空位", "kind": "spare_2f", "x": 640.0, "floor": 2, "w": 256.0, "h": 112.0, "spot_detail": "B 二层左侧可清理扩建空间"},
		],
		"landmarks": [
			{"id": "lm_1f_bed", "label": "1F 卧床/相框", "x": 384.0, "floor": 1, "doc_code": "A"},
			{"id": "lm_1f_desk", "label": "1F 清单桌/绿植(V)", "x": 864.0, "floor": 1, "doc_code": "A/V"},
			{"id": "lm_1f_shelf", "label": "1F 储物货架区", "x": 1472.0, "floor": 1, "doc_code": "A"},
			{"id": "lm_1f_kitchen", "label": "1F 厨房/电暖器", "x": 2112.0, "floor": 1, "doc_code": "A"},
			{"id": "lm_1f_stair", "label": "1F 楼梯口", "x": 2496.0, "floor": 1, "doc_code": "A/B"},
			{"id": "lm_1f_door", "label": "1F 玄关安全门", "x": 2848.0, "floor": 1, "doc_code": "A/D"},
			{"id": "lm_2f_stair", "label": "2F 楼梯口", "x": 2496.0, "floor": 2, "doc_code": "B"},
			{"id": "lm_2f_store", "label": "2F 旧储物室", "x": 1920.0, "floor": 2, "doc_code": "B"},
			{"id": "lm_2f_win", "label": "2F 临街窗/天线位", "x": 1312.0, "floor": 2, "doc_code": "B/M"},
			{"id": "lm_2f_spare", "label": "2F 备用扩建室", "x": 640.0, "floor": 2, "doc_code": "B"},
		],
	}


# ==============================================================================
# 3. C 外置独立设备区（1,920 px，与生活空间隔离通风）
# ==============================================================================
static func _spec_equipment_room() -> Dictionary:
	return {
		"key": &"equipment_room",
		"title": "外置独立设备区（C 小楼外侧独立通风设备间）",
		"doc_code": "C",
		"is_outdoor": false,
		"width": 1920.0,
		"ground_y": GROUND_Y,
		"sky_color": Color(0.14, 0.16, 0.18, 1.0),
		"ground_color": Color(0.24, 0.26, 0.28, 1.0),
		"road_top_color": Color(0.38, 0.41, 0.44, 1.0),
		"default_spawn": &"spawn_entrance",
		"floors": [
			{"floor": 1, "name": "1F 独立通风设备间", "ground_y": GROUND_Y, "ceiling_y": 160.0, "x0": 96.0, "x1": 1824.0},
		],
		"segments": [
			{"index": 1, "title": "安全出入口与通风区", "doc_code": "C", "x0": 96.0, "x1": 800.0, "color": Color(0.25, 0.28, 0.31, 1.0), "summary": "独立门 → 外墙百叶通风格栅"},
			{"index": 2, "title": "发电机底座与断路器检修区", "doc_code": "C", "x0": 800.0, "x1": 1824.0, "color": Color(0.28, 0.31, 0.34, 1.0), "summary": "发电设备留空底座 → 断路器配电箱与沿墙电缆 → 检修站位"},
		],
		"spawns": {
			&"spawn_entrance": {"x": 256.0, "floor": 1, "ground_y": GROUND_Y, "facing": 1, "label": "设备区安全门内"},
		},
		"buildings": [
			{
				"id": "room_equip_bay",
				"doc_code": "C",
				"title": "C 外置独立设备间剖面 (96..1824, 宽1728×高256)",
				"subtitle": "安全出入口 → 外墙通风格栅 → 发电机底座(空位/停机/运行三态) → 断路器与电缆接口 → 检修站位",
				"x": 96.0,
				"w": 1728.0,
				"h": 256.0,
				"floor": 1,
				"floors_count": 1,
				"wall_color": Color(0.27, 0.30, 0.33, 1.0),
				"roof_color": Color(0.19, 0.22, 0.25, 1.0),
				"accent_color": Color(0.62, 0.72, 0.78, 1.0),
				"roof_style": "interior_room",
				"art_slot": "SLOT_INT_EQUIP_ROOM",
				"registry_id": "ART_SCENE_107 (预留:安全设备区)",
				"windows": [
					{"x": 512.0, "y_off": 96.0, "w": 224.0, "h": 96.0, "kind": "louver", "label": "外墙独立通风格栅"},
				],
				"notes": ["与起居室严格隔开并通风", "燃油发电机仅允许在此安装运行"],
			},
		],
		"doors": [
			{
				"id": "door_equip_exit",
				"label": "设备区安全门",
				"prompt": "室外小楼设备区门外",
				"x": 256.0,
				"floor": 1,
				"w": DOOR_STD_W,
				"h": DOOR_STD_H,
				"target_scene": &"outdoor_street",
				"target_spawn": &"spawn_equip_gate",
				"interactive": true,
				"style": "metal",
			},
		],
		"stairs": [],
		"shelves": [],
		"carts": [],
		"props": [
			{"id": "p_gen_pad", "label": "发电设备固定底座（留空位）", "kind": "generator_pad", "x": 1024.0, "floor": 1, "w": 224.0, "h": 112.0, "spot_detail": "C 发电机安装底座（预留无设备 / 停机 / 正常运行三态，P03B / D03）"},
			{"id": "p_breaker_box", "label": "断路器配电箱与电缆接口", "kind": "breaker", "x": 1440.0, "floor": 1, "w": 160.0, "h": 144.0, "spot_detail": "C 老房子总闸、断路器与穿墙供电电缆接口（P03B 陈叔检查线路）"},
			{"id": "p_tool_rack", "label": "检修站位与应急照明灯", "kind": "work_bench", "x": 1664.0, "floor": 1, "w": 112.0, "h": 96.0, "spot_detail": ""},
		],
		"landmarks": [
			{"id": "lm_eq_door", "label": "1.设备区出入口", "x": 256.0, "floor": 1, "doc_code": "C"},
			{"id": "lm_eq_vent", "label": "2.外墙通风格栅", "x": 624.0, "floor": 1, "doc_code": "C"},
			{"id": "lm_eq_gen", "label": "3.发电机底座", "x": 1024.0, "floor": 1, "doc_code": "C"},
			{"id": "lm_eq_breaker", "label": "4.断路器与电缆", "x": 1440.0, "floor": 1, "doc_code": "C"},
		],
	}


# ==============================================================================
# 4. G 居民楼公共楼道（2,400 px，真实 1F/2F 双层楼道，2F 设赵阿姨家门进 P）
# ==============================================================================
static func _spec_apartment_hallway() -> Dictionary:
	return {
		"key": &"apartment_hallway",
		"title": "梧桐里居民楼公共楼道（G 1F 门厅走廊 + 2F 住户走廊）",
		"doc_code": "G/P",
		"is_outdoor": false,
		"width": 2400.0,
		"ground_y": GROUND_Y,
		"sky_color": Color(0.15, 0.17, 0.20, 1.0),
		"ground_color": Color(0.26, 0.28, 0.31, 1.0),
		"road_top_color": Color(0.42, 0.45, 0.48, 1.0),
		"default_spawn": &"spawn_unit_door",
		"floors": [
			{"floor": 1, "name": "1F 居民楼一层公共走廊", "ground_y": GROUND_Y, "ceiling_y": 160.0, "x0": 96.0, "x1": 2304.0},
			{"floor": 2, "name": "2F 居民楼二层住户走廊（赵阿姨家所在层）", "ground_y": FLOOR2_Y, "ceiling_y": -96.0, "x0": 256.0, "x1": 2240.0},
		],
		"segments": [
			{"index": 1, "title": "单元门与公共楼梯间", "doc_code": "G", "x0": 96.0, "x1": 864.0, "color": Color(0.27, 0.30, 0.34, 1.0), "summary": "1F 单元门入口 → 1F/2F 公共楼梯口"},
			{"index": 2, "title": "楼道采光窗与各户门", "doc_code": "G/P", "x0": 864.0, "x1": 2304.0, "color": Color(0.25, 0.28, 0.32, 1.0), "summary": "楼道窗 → 住户门(2F 201 为赵阿姨家门，可进入 P) → 走廊端头"},
		],
		"spawns": {
			&"spawn_unit_door": {"x": 256.0, "floor": 1, "ground_y": GROUND_Y, "facing": 1, "label": "1F 单元门入口内"},
			&"spawn_zhao_door": {"x": 1408.0, "floor": 2, "ground_y": FLOOR2_Y, "facing": -1, "label": "2F 201 赵阿姨家门外"},
		},
		"buildings": [
			{
				"id": "hall_1f",
				"doc_code": "G",
				"title": "G 居民楼 1F 公共走廊 (96..2304, 宽2208×高256)",
				"subtitle": "单元门入口 → 1F楼梯口(x=608) → 楼道窗与应急灯 → 101住户门(王秀琴家) → 公共配电箱与走廊端头",
				"x": 96.0,
				"w": 2208.0,
				"h": 256.0,
				"floor": 1,
				"floors_count": 1,
				"wall_color": Color(0.29, 0.32, 0.36, 1.0),
				"roof_color": Color(0.20, 0.23, 0.26, 1.0),
				"accent_color": Color(0.66, 0.72, 0.78, 1.0),
				"roof_style": "interior_room",
				"art_slot": "SLOT_INT_HALL_1F",
				"registry_id": "ART_SCENE_108 (预留:门外楼道)",
				"windows": [
					{"x": 928.0, "y_off": 96.0, "w": 192.0, "h": 96.0, "kind": "cold", "label": "1F 楼道采光窗"},
				],
				"notes": ["与 P00 前世主角门外走廊区分，不混成同一扇门"],
			},
			{
				"id": "hall_2f",
				"doc_code": "G/P",
				"title": "G 居民楼 2F 住户走廊 (256..2240, 宽1984×高224, 位于 1F 正上方)",
				"subtitle": "2F楼梯口(x=608) → 2F楼道窗 → 201赵阿姨与小满家门(x=1408, 可进入P) → 202住户门",
				"x": 256.0,
				"w": 1984.0,
				"h": 224.0,
				"floor": 2,
				"floors_count": 1,
				"wall_color": Color(0.27, 0.30, 0.34, 1.0),
				"roof_color": Color(0.19, 0.21, 0.24, 1.0),
				"accent_color": Color(0.78, 0.66, 0.48, 1.0),
				"roof_style": "interior_room",
				"art_slot": "SLOT_INT_HALL_2F",
				"registry_id": "ART_SCENE_108 (预留:门外楼道)",
				"windows": [
					{"x": 928.0, "y_off": 80.0, "w": 192.0, "h": 88.0, "kind": "cold", "label": "2F 楼道采光窗"},
				],
				"notes": ["201 住户门进入 P 赵阿姨家内景", "门边预留 S12 求助纸条位"],
			},
		],
		"doors": [
			{
				"id": "door_hall_exit",
				"label": "1F 居民楼单元门",
				"prompt": "室外居民楼单元门外",
				"x": 256.0,
				"floor": 1,
				"w": DOOR_STD_W,
				"h": DOOR_STD_H,
				"target_scene": &"outdoor_street",
				"target_spawn": &"spawn_unit_gate",
				"interactive": true,
				"style": "unit_gate",
			},
			{
				"id": "door_101_deco",
				"label": "101 住户门(王秀琴家·装饰门)",
				"prompt": "",
				"x": 1408.0,
				"floor": 1,
				"w": DOOR_STD_W,
				"h": DOOR_STD_H,
				"target_scene": &"",
				"target_spawn": &"",
				"interactive": false,
				"style": "deco",
			},
			{
				"id": "door_102_deco",
				"label": "102 住户门(装饰门)",
				"prompt": "",
				"x": 1920.0,
				"floor": 1,
				"w": DOOR_STD_W,
				"h": DOOR_STD_H,
				"target_scene": &"",
				"target_spawn": &"",
				"interactive": false,
				"style": "deco",
			},
			{
				"id": "door_201_zhao",
				"label": "201 赵阿姨与小满家门",
				"prompt": "赵阿姨家室内 (P)",
				"x": 1408.0,
				"floor": 2,
				"w": DOOR_STD_W,
				"h": DOOR_STD_H,
				"target_scene": &"zhao_home",
				"target_spawn": &"spawn_entrance",
				"interactive": true,
				"style": "wood_home",
			},
			{
				"id": "door_202_deco",
				"label": "202 邻户门(装饰门)",
				"prompt": "",
				"x": 1920.0,
				"floor": 2,
				"w": DOOR_STD_W,
				"h": DOOR_STD_H,
				"target_scene": &"",
				"target_spawn": &"",
				"interactive": false,
				"style": "deco",
			},
		],
		"stairs": [
			{
				"id": "stair_hall_1f_2f",
				"label": "居民楼公共楼梯",
				"x": 608.0,
				"w": 128.0,
				"from_floor": 1,
				"to_floor": 2,
				"from_y": GROUND_Y,
				"to_y": FLOOR2_Y,
				"target_x": 608.0,
			},
			{
				"id": "stair_hall_2f_1f",
				"label": "居民楼公共楼梯",
				"x": 608.0,
				"w": 128.0,
				"from_floor": 2,
				"to_floor": 1,
				"from_y": FLOOR2_Y,
				"to_y": GROUND_Y,
				"target_x": 608.0,
			},
		],
		"shelves": [],
		"carts": [],
		"props": [
			{"id": "p_hall_meter", "label": "1F 公共配电柜", "kind": "breaker", "x": 2144.0, "floor": 1, "w": 96.0, "h": 128.0, "spot_detail": "G 居民楼公共配电柜（P03B 李建国登记，与主角家独立设备区分开）"},
			{"id": "p_zhao_note", "label": "2F 门边求助纸条位 (S12)", "kind": "notice_board", "x": 1280.0, "floor": 2, "w": 64.0, "h": 80.0, "spot_detail": "S12 楼道里的纸条：小满留在 201 门边的求助信息"},
		],
		"landmarks": [
			{"id": "lm_g_unit", "label": "1F 单元门", "x": 256.0, "floor": 1, "doc_code": "G"},
			{"id": "lm_g_st1", "label": "1F 公共楼梯", "x": 608.0, "floor": 1, "doc_code": "G"},
			{"id": "lm_g_101", "label": "1F 101住户门", "x": 1408.0, "floor": 1, "doc_code": "G"},
			{"id": "lm_g_st2", "label": "2F 公共楼梯", "x": 608.0, "floor": 2, "doc_code": "G"},
			{"id": "lm_g_zhao", "label": "2F 赵阿姨家门(P)", "x": 1408.0, "floor": 2, "doc_code": "G/P"},
		],
	}


# ==============================================================================
# 5. P 赵阿姨家室内（1,920 px，从居民楼 2F 201 住户门进入）
# ==============================================================================
static func _spec_zhao_home() -> Dictionary:
	return {
		"key": &"zhao_home",
		"title": "赵阿姨与小满家室内（P 居民楼住户内景 · 扩展建议）",
		"doc_code": "P",
		"is_outdoor": false,
		"width": 1920.0,
		"ground_y": GROUND_Y,
		"sky_color": Color(0.16, 0.16, 0.17, 1.0),
		"ground_color": Color(0.28, 0.24, 0.21, 1.0),
		"road_top_color": Color(0.45, 0.38, 0.32, 1.0),
		"default_spawn": &"spawn_entrance",
		"floors": [
			{"floor": 1, "name": "赵阿姨家室内（居民楼 201 室）", "ground_y": GROUND_Y, "ceiling_y": 160.0, "x0": 96.0, "x1": 1824.0},
		],
		"segments": [
			{"index": 1, "title": "玄关鞋架与简桌药单", "doc_code": "P", "x0": 96.0, "x1": 960.0, "color": Color(0.32, 0.28, 0.24, 1.0), "summary": "入户门 → 小鞋架 → 简桌与手写药单"},
			{"index": 2, "title": "老人座椅、小满铺位与临街窗", "doc_code": "P", "x0": 960.0, "x1": 1824.0, "color": Color(0.30, 0.26, 0.23, 1.0), "summary": "老人座椅与水杯 → 小满折叠铺位 → 临街窗"},
		],
		"spawns": {
			&"spawn_entrance": {"x": 256.0, "floor": 1, "ground_y": GROUND_Y, "facing": 1, "label": "201 入户门内"},
		},
		"buildings": [
			{
				"id": "room_zhao",
				"doc_code": "P",
				"title": "P 赵阿姨家狭长房间剖面 (96..1824, 宽1728×高256)",
				"subtitle": "入户门 → 入口小鞋架 → 旧桌与手写药单 → 老人座椅与普通水杯 → 小满临时折叠铺位 → 临街窗口",
				"x": 96.0,
				"w": 1728.0,
				"h": 256.0,
				"floor": 1,
				"floors_count": 1,
				"wall_color": Color(0.34, 0.30, 0.26, 1.0),
				"roof_color": Color(0.24, 0.20, 0.18, 1.0),
				"accent_color": Color(0.80, 0.66, 0.46, 1.0),
				"roof_style": "interior_room",
				"art_slot": "SLOT_INT_ZHAO_HOME",
				"registry_id": "待立项 (自 ART_SCENE_113 起顺延·赵阿姨与小满家内景)",
				"windows": [
					{"x": 1536.0, "y_off": 88.0, "w": 192.0, "h": 96.0, "kind": "warm", "label": "临街窗(可与街道隔窗呼应)"},
				],
				"notes": ["与主角小楼不共享门窗坐标或库存", "离开返回居民楼 2F 201 门外"],
			},
		],
		"doors": [
			{
				"id": "door_zhao_exit",
				"label": "201 入户门",
				"prompt": "居民楼 2F 走廊 (G)",
				"x": 256.0,
				"floor": 1,
				"w": DOOR_STD_W,
				"h": DOOR_STD_H,
				"target_scene": &"apartment_hallway",
				"target_spawn": &"spawn_zhao_door",
				"interactive": true,
				"style": "wood_home",
			},
		],
		"stairs": [],
		"shelves": [],
		"carts": [],
		"props": [
			{"id": "p_shoe_rack", "label": "入口小鞋架", "kind": "cabinet", "x": 448.0, "floor": 1, "w": 96.0, "h": 72.0, "spot_detail": ""},
			{"id": "p_med_table", "label": "简桌、手写药单与水杯", "kind": "desk_plant", "x": 736.0, "floor": 1, "w": 160.0, "h": 88.0, "spot_detail": "P 简桌上的空白手写药单与水杯（P06B / D02B 邻居饮水求助）"},
			{"id": "p_elder_chair", "label": "老人座椅", "kind": "chair", "x": 1024.0, "floor": 1, "w": 96.0, "h": 88.0, "spot_detail": ""},
			{"id": "p_folding_bed", "label": "小满临时折叠铺位", "kind": "bed", "x": 1312.0, "floor": 1, "w": 192.0, "h": 80.0, "spot_detail": "P 周小满暂住外婆家的折叠床铺"},
		],
		"landmarks": [
			{"id": "lm_p_door", "label": "1.入户门/鞋架", "x": 256.0, "floor": 1, "doc_code": "P"},
			{"id": "lm_p_table", "label": "2.简桌与药单", "x": 736.0, "floor": 1, "doc_code": "P"},
			{"id": "lm_p_bed", "label": "3.小满折叠铺", "x": 1312.0, "floor": 1, "doc_code": "P"},
			{"id": "lm_p_win", "label": "4.临街窗口", "x": 1632.0, "floor": 1, "doc_code": "P"},
		],
	}


# ==============================================================================
# 6. Q 陈叔维修角室内（1,920 px）
# ==============================================================================
static func _spec_repair_corner() -> Dictionary:
	return {
		"key": &"repair_corner",
		"title": "陈叔维修角（Q 社区电工与设备维修空间 · 扩展建议）",
		"doc_code": "Q",
		"is_outdoor": false,
		"width": 1920.0,
		"ground_y": GROUND_Y,
		"sky_color": Color(0.14, 0.16, 0.18, 1.0),
		"ground_color": Color(0.25, 0.27, 0.29, 1.0),
		"road_top_color": Color(0.39, 0.42, 0.45, 1.0),
		"default_spawn": &"spawn_entrance",
		"floors": [
			{"floor": 1, "name": "1F 陈叔维修角", "ground_y": GROUND_Y, "ceiling_y": 160.0, "x0": 96.0, "x1": 1824.0},
		],
		"segments": [
			{"index": 1, "title": "半开旧卷帘与工具挂板", "doc_code": "Q", "x0": 96.0, "x1": 960.0, "color": Color(0.26, 0.30, 0.33, 1.0), "summary": "旧卷帘门 → 工具挂板墙"},
			{"index": 2, "title": "磨损工作台与零件抽屉柜", "doc_code": "Q", "x0": 960.0, "x1": 1824.0, "color": Color(0.28, 0.32, 0.35, 1.0), "summary": "磨损工作台 → 空白零件柜 → 旧椅与交谈站位"},
		],
		"spawns": {
			&"spawn_entrance": {"x": 256.0, "floor": 1, "ground_y": GROUND_Y, "facing": 1, "label": "维修角卷帘门内"},
		},
		"buildings": [
			{
				"id": "room_repair",
				"doc_code": "Q",
				"title": "Q 陈叔维修角内景剖面 (96..1824, 宽1728×高256)",
				"subtitle": "半开旧卷帘出入口 → 工具挂板墙 → 磨损工作台 → 零件抽屉柜 → 旧椅与可交谈站位",
				"x": 96.0,
				"w": 1728.0,
				"h": 256.0,
				"floor": 1,
				"floors_count": 1,
				"wall_color": Color(0.28, 0.32, 0.35, 1.0),
				"roof_color": Color(0.19, 0.22, 0.25, 1.0),
				"accent_color": Color(0.64, 0.74, 0.78, 1.0),
				"roof_style": "interior_room",
				"art_slot": "SLOT_INT_REPAIR_CORNER",
				"registry_id": "待立项 (自 ART_SCENE_113 起顺延·陈叔维修角内景)",
				"windows": [
					{"x": 544.0, "y_off": 88.0, "w": 256.0, "h": 96.0, "kind": "board", "label": "电工工具挂板墙"},
				],
				"notes": ["不替代主角家的外置设备区 C", "零件与修理结果不画死在背景里"],
			},
		],
		"doors": [
			{
				"id": "door_repair_exit",
				"label": "维修角旧卷帘门",
				"prompt": "室外维修角门外",
				"x": 256.0,
				"floor": 1,
				"w": DOOR_STD_W,
				"h": DOOR_STD_H,
				"target_scene": &"outdoor_street",
				"target_spawn": &"spawn_repair_gate",
				"interactive": true,
				"style": "shutter",
			},
		],
		"stairs": [],
		"shelves": [],
		"carts": [],
		"props": [
			{"id": "p_workbench", "label": "磨损维修工作台", "kind": "work_bench", "x": 1024.0, "floor": 1, "w": 224.0, "h": 96.0, "spot_detail": "Q 陈叔整理老化线缆与检修工具的工作台（P03 / D03）"},
			{"id": "p_parts_cabinet", "label": "空白零件抽屉柜", "kind": "cabinet", "x": 1376.0, "floor": 1, "w": 160.0, "h": 160.0, "spot_detail": "Q 零件分类抽屉柜"},
			{"id": "p_old_chair", "label": "旧工作椅与交谈位", "kind": "chair", "x": 1632.0, "floor": 1, "w": 96.0, "h": 88.0, "spot_detail": ""},
		],
		"landmarks": [
			{"id": "lm_q_door", "label": "1.旧卷帘门", "x": 256.0, "floor": 1, "doc_code": "Q"},
			{"id": "lm_q_wall", "label": "2.工具挂板墙", "x": 672.0, "floor": 1, "doc_code": "Q"},
			{"id": "lm_q_bench", "label": "3.磨损工作台", "x": 1024.0, "floor": 1, "doc_code": "Q"},
			{"id": "lm_q_cab", "label": "4.零件柜与交谈位", "x": 1440.0, "floor": 1, "doc_code": "Q"},
		],
	}


# ==============================================================================
# 7. J 唐宁的街角便利店（2,400 px）
# ==============================================================================
static func _spec_convenience_store() -> Dictionary:
	return {
		"key": &"convenience_store",
		"title": "唐宁的街角便利店（J 便利店内景）",
		"doc_code": "J",
		"is_outdoor": false,
		"width": 2400.0,
		"ground_y": GROUND_Y,
		"sky_color": Color(0.16, 0.15, 0.14, 1.0),
		"ground_color": Color(0.30, 0.25, 0.21, 1.0),
		"road_top_color": Color(0.48, 0.39, 0.31, 1.0),
		"default_spawn": &"spawn_entrance",
		"floors": [
			{"floor": 1, "name": "1F 街角便利店内景", "ground_y": GROUND_Y, "ceiling_y": 160.0, "x0": 96.0, "x1": 2304.0},
		],
		"segments": [
			{"index": 1, "title": "入口与货架冷柜区", "doc_code": "J", "x0": 96.0, "x1": 1344.0, "color": Color(0.33, 0.28, 0.23, 1.0), "summary": "玻璃门入口 → 便利店货架与饮料冷柜"},
			{"index": 2, "title": "收银柜台与后方隔门", "doc_code": "J", "x0": 1344.0, "x1": 2304.0, "color": Color(0.35, 0.29, 0.24, 1.0), "summary": "收银小柜台(含旧电台位) → 通往店内后方/楼上休息室门"},
		],
		"spawns": {
			&"spawn_entrance": {"x": 256.0, "floor": 1, "ground_y": GROUND_Y, "facing": 1, "label": "便利店玻璃门内"},
		},
		"buildings": [
			{
				"id": "room_convenience",
				"doc_code": "J",
				"title": "J 唐宁的街角便利店剖面 (96..2304, 宽2208×高256)",
				"subtitle": "街角玻璃门入口 → 小型货架与饮料冷柜 → 小收银柜台(旧电台与赊账纸) → 通往店内后方的门(装饰门)",
				"x": 96.0,
				"w": 2208.0,
				"h": 256.0,
				"floor": 1,
				"floors_count": 1,
				"wall_color": Color(0.35, 0.29, 0.24, 1.0),
				"roof_color": Color(0.24, 0.20, 0.17, 1.0),
				"accent_color": Color(0.88, 0.68, 0.42, 1.0),
				"roof_style": "interior_room",
				"art_slot": "SLOT_INT_CONVENIENCE",
				"registry_id": "待立项 (自 ART_SCENE_113 起顺延·唐宁便利店内景)",
				"windows": [
					{"x": 448.0, "y_off": 88.0, "w": 224.0, "h": 96.0, "kind": "warm", "label": "临街橱窗(可叠卷帘)"},
				],
				"notes": ["后方门通往唐母休息处，按文档设定为装饰门，不开放病房探索"],
			},
		],
		"doors": [
			{
				"id": "door_conv_exit",
				"label": "便利店玻璃门",
				"prompt": "室外便利店门外",
				"x": 256.0,
				"floor": 1,
				"w": DOOR_STD_W,
				"h": DOOR_STD_H,
				"target_scene": &"outdoor_street",
				"target_spawn": &"spawn_conv_gate",
				"interactive": true,
				"style": "glass",
			},
			{
				"id": "door_conv_back_deco",
				"label": "店内后方门(唐母休息室方向·装饰门)",
				"prompt": "",
				"x": 2048.0,
				"floor": 1,
				"w": DOOR_STD_W,
				"h": DOOR_STD_H,
				"target_scene": &"",
				"target_spawn": &"",
				"interactive": false,
				"style": "deco",
			},
		],
		"stairs": [],
		"shelves": [
			{"id": "sh_conv_1", "label": "便利店货架 A", "x": 768.0, "floor": 1, "note": "便利店货架 A · 饮水与速食（ART_FURN_101 r01）", "items": ["water", "food"]},
			{"id": "sh_conv_2", "label": "便利店货架 B", "x": 960.0, "floor": 1, "note": "便利店货架 B · 日用与电池（ART_FURN_101 r01）", "items": ["food"]},
		],
		"carts": [],
		"props": [
			{"id": "p_conv_cooler", "label": "饮料冷藏柜", "kind": "cooler", "x": 1184.0, "floor": 1, "w": 128.0, "h": 176.0, "spot_detail": "J 便利店立式饮料冷柜"},
			{"id": "p_conv_counter", "label": "唐宁收银柜台与旧电台位", "kind": "counter", "x": 1600.0, "floor": 1, "w": 224.0, "h": 96.0, "spot_detail": "J 收银柜台（P06 唐宁求助、P06B 旧电台与赊账条、S05 物资交换）"},
		],
		"landmarks": [
			{"id": "lm_j_door", "label": "1.街角入口", "x": 256.0, "floor": 1, "doc_code": "J"},
			{"id": "lm_j_shelf", "label": "2.货架与冷柜", "x": 960.0, "floor": 1, "doc_code": "J"},
			{"id": "lm_j_counter", "label": "3.收银柜台", "x": 1600.0, "floor": 1, "doc_code": "J"},
			{"id": "lm_j_back", "label": "4.后方隔门", "x": 2048.0, "floor": 1, "doc_code": "J"},
		],
	}


# ==============================================================================
# 8. N 社区药店内景（1,920 px，扩展建议）
# ==============================================================================
static func _spec_pharmacy() -> Dictionary:
	return {
		"key": &"pharmacy",
		"title": "社区药店内景（N 选看内景 · 扩展建议）",
		"doc_code": "N",
		"is_outdoor": false,
		"width": 1920.0,
		"ground_y": GROUND_Y,
		"sky_color": Color(0.15, 0.18, 0.17, 1.0),
		"ground_color": Color(0.26, 0.30, 0.29, 1.0),
		"road_top_color": Color(0.42, 0.48, 0.46, 1.0),
		"default_spawn": &"spawn_entrance",
		"floors": [
			{"floor": 1, "name": "1F 社区药店内景", "ground_y": GROUND_Y, "ceiling_y": 160.0, "x0": 96.0, "x1": 1824.0},
		],
		"segments": [
			{"index": 1, "title": "入口与等候位", "doc_code": "N", "x0": 96.0, "x1": 896.0, "color": Color(0.28, 0.33, 0.31, 1.0), "summary": "入口门 → 等候椅"},
			{"index": 2, "title": "非处方陈列与药师柜台", "doc_code": "N", "x0": 896.0, "x1": 1824.0, "color": Color(0.30, 0.35, 0.33, 1.0), "summary": "非处方陈列架 → 药师服务柜台"},
		],
		"spawns": {
			&"spawn_entrance": {"x": 256.0, "floor": 1, "ground_y": GROUND_Y, "facing": 1, "label": "药店玻璃门内"},
		},
		"buildings": [
			{
				"id": "room_pharmacy",
				"doc_code": "N",
				"title": "N 社区药店内景剖面 (96..1824, 宽1728×高256)",
				"subtitle": "入口门 → 等候椅位 → 非处方普通商品架 → 药师咨询与服务柜台",
				"x": 96.0,
				"w": 1728.0,
				"h": 256.0,
				"floor": 1,
				"floors_count": 1,
				"wall_color": Color(0.29, 0.34, 0.32, 1.0),
				"roof_color": Color(0.20, 0.24, 0.23, 1.0),
				"accent_color": Color(0.62, 0.80, 0.72, 1.0),
				"roof_style": "interior_room",
				"art_slot": "SLOT_INT_PHARMACY",
				"registry_id": "待立项 (自 ART_SCENE_113 起顺延·社区药店内景)",
				"windows": [
					{"x": 480.0, "y_off": 88.0, "w": 224.0, "h": 96.0, "kind": "warm", "label": "生活化药店橱窗"},
				],
				"notes": ["扩展选看场景，不额外增加独立药品商店结算系统"],
			},
		],
		"doors": [
			{
				"id": "door_pharm_exit",
				"label": "药店玻璃门",
				"prompt": "室外社区药店门外",
				"x": 256.0,
				"floor": 1,
				"w": DOOR_STD_W,
				"h": DOOR_STD_H,
				"target_scene": &"outdoor_street",
				"target_spawn": &"spawn_pharm_gate",
				"interactive": true,
				"style": "glass",
			},
		],
		"stairs": [],
		"shelves": [
			{"id": "sh_pharm_1", "label": "非处方陈列架", "x": 1024.0, "floor": 1, "note": "药店非处方陈列架 · 96×192（ART_FURN_101 r01）", "items": []},
		],
		"carts": [],
		"props": [
			{"id": "p_pharm_bench", "label": "等候排椅", "kind": "chair", "x": 640.0, "floor": 1, "w": 160.0, "h": 72.0, "spot_detail": "N 药店等候椅位"},
			{"id": "p_pharm_counter", "label": "药师服务柜台", "kind": "counter", "x": 1472.0, "floor": 1, "w": 256.0, "h": 112.0, "spot_detail": "N 药师咨询柜台（P01B / P06B 小满询问常用药配药流程）"},
		],
		"landmarks": [
			{"id": "lm_n_door", "label": "1.药店入口", "x": 256.0, "floor": 1, "doc_code": "N"},
			{"id": "lm_n_wait", "label": "2.等候位", "x": 640.0, "floor": 1, "doc_code": "N"},
			{"id": "lm_n_shelf", "label": "3.非处方陈列", "x": 1024.0, "floor": 1, "doc_code": "N"},
			{"id": "lm_n_counter", "label": "4.药师柜台", "x": 1472.0, "floor": 1, "doc_code": "N"},
		],
	}


# ==============================================================================
# 9. H 灾前超市（含 S 临时批发预约区与后仓门，5,760 px = 6 视口）
# ==============================================================================
static func _spec_supermarket() -> Dictionary:
	return {
		"key": &"supermarket",
		"title": "灾前连锁超市（H 超市主卖场 + S 临时批发预约区）",
		"doc_code": "H/S",
		"is_outdoor": false,
		"width": 5760.0,
		"ground_y": GROUND_Y,
		"sky_color": Color(0.18, 0.15, 0.12, 1.0),
		"ground_color": Color(0.34, 0.27, 0.20, 1.0),
		"road_top_color": Color(0.56, 0.45, 0.33, 1.0),
		"default_spawn": &"spawn_entrance",
		"floors": [
			{"floor": 1, "name": "1F 连锁超市横版卖场（全长 5,760 px）", "ground_y": GROUND_Y, "ceiling_y": 96.0, "x0": 96.0, "x1": 5664.0},
		],
		"segments": [
			{"index": 1, "title": "入口推车区与饮水食品货架", "doc_code": "H", "x0": 96.0, "x1": 3264.0, "color": Color(0.36, 0.28, 0.21, 1.0), "summary": "入口自动门 → 推车停放区 → 饮水货架 → 食品与日用品货架（主通道 192 px）"},
			{"index": 2, "title": "S 临时批发预约区与后仓门", "doc_code": "S", "x0": 3264.0, "x1": 4288.0, "color": Color(0.33, 0.26, 0.20, 1.0), "summary": "临时预约登记桌 → 后仓门(装饰门) → 待交接整托纸箱位"},
			{"index": 3, "title": "冷藏柜区与收银出口", "doc_code": "H", "x0": 4288.0, "x1": 5664.0, "color": Color(0.35, 0.28, 0.22, 1.0), "summary": "冷藏冷柜组 → 收银结账台 → 右侧出口(对应室外超市入口)"},
		],
		"spawns": {
			&"spawn_entrance": {"x": 320.0, "floor": 1, "ground_y": GROUND_Y, "facing": 1, "label": "超市入口门内"},
			&"spawn_checkout": {"x": 5376.0, "floor": 1, "ground_y": GROUND_Y, "facing": -1, "label": "超市收银出口内"},
		},
		"buildings": [
			{
				"id": "room_supermarket",
				"doc_code": "H/S",
				"title": "H 灾前超市与 S 预约区剖面 (96..5664, 宽5568×高320)",
				"subtitle": "入口/推车 → 饮水与食品货架(主通道净宽192) → S 后仓预约位 → 冷柜 → 收银与出口",
				"x": 96.0,
				"w": 5568.0,
				"h": 320.0,
				"floor": 1,
				"floors_count": 1,
				"wall_color": Color(0.36, 0.28, 0.21, 1.0),
				"roof_color": Color(0.25, 0.19, 0.14, 1.0),
				"accent_color": Color(0.92, 0.68, 0.36, 1.0),
				"roof_style": "supermarket_interior",
				"art_slot": "SLOT_INT_SUPERMARKET",
				"registry_id": "ART_SCENE_101 (已用:v01 灾前超市横版概念)",
				"windows": [
					{"x": 640.0, "y_off": 96.0, "w": 256.0, "h": 96.0, "kind": "warm", "label": "超市临街采光窗"},
					{"x": 3456.0, "y_off": 112.0, "w": 192.0, "h": 80.0, "kind": "board", "label": "S 临时批发预约告示牌"},
				],
				"notes": ["S 预约区属于超市内部连续区段，不另造店外仓库", "左右两扇进出门均明确对应室外超市入口 x=7552"],
			},
		],
		"doors": [
			{
				"id": "door_market_in",
				"label": "超市自动门入口 (192×224)",
				"prompt": "室外连锁超市入口外",
				"x": 320.0,
				"floor": 1,
				"w": DOOR_WIDE_W,
				"h": DOOR_WIDE_H,
				"target_scene": &"outdoor_street",
				"target_spawn": &"spawn_market_gate",
				"interactive": true,
				"style": "wide_glass",
			},
			{
				"id": "door_market_backroom_deco",
				"label": "S 超市后仓门(背景装饰门)",
				"prompt": "",
				"x": 3904.0,
				"floor": 1,
				"w": DOOR_WIDE_W,
				"h": DOOR_WIDE_H,
				"target_scene": &"",
				"target_spawn": &"",
				"interactive": false,
				"style": "deco",
			},
			{
				"id": "door_market_out",
				"label": "超市收银出口 (192×224)",
				"prompt": "室外连锁超市入口外",
				"x": 5376.0,
				"floor": 1,
				"w": DOOR_WIDE_W,
				"h": DOOR_WIDE_H,
				"target_scene": &"outdoor_street",
				"target_spawn": &"spawn_market_gate",
				"interactive": true,
				"style": "wide_glass",
			},
		],
		"stairs": [],
		"shelves": [
			# 货架宽 96，相邻两组之间留足 192 px 主通道净宽（x2 = x1 + 96 + 192 = x1 + 288）
			{"id": "sh_mkt_1", "label": "饮用水货架 A", "x": 1152.0, "floor": 1, "note": "超市饮水区货架 A · 四层 96×192（主通道净宽 192px）", "items": ["water", "water"]},
			{"id": "sh_mkt_2", "label": "饮用水货架 B", "x": 1440.0, "floor": 1, "note": "超市饮水区货架 B · 四层 96×192（主通道净宽 192px）", "items": ["water", "water"]},
			{"id": "sh_mkt_3", "label": "速食与米面货架 A", "x": 2016.0, "floor": 1, "note": "超市食品区货架 A · 四层 96×192（S01 最后一包泡面）", "items": ["food", "food"]},
			{"id": "sh_mkt_4", "label": "速食与零食货架 B", "x": 2304.0, "floor": 1, "note": "超市食品区货架 B · 四层 96×192（S08 零食的价格）", "items": ["food", "water"]},
			{"id": "sh_mkt_5", "label": "日用百货货架 C", "x": 2880.0, "floor": 1, "note": "超市日用品货架 C · 四层 96×192", "items": ["food"]},
		],
		"carts": [
			{"id": "cart_market_1", "x": 768.0, "floor": 1, "load_state": &"half"},
		],
		"props": [
			{"id": "p_mkt_floor_stack", "label": "促销整箱饮水堆头", "kind": "floor_items", "x": 1824.0, "floor": 1, "w": 128.0, "h": 64.0, "spot_detail": ""},
			{"id": "p_mkt_reserve_desk", "label": "S 临时批发预约登记桌", "kind": "counter", "x": 3552.0, "floor": 1, "w": 192.0, "h": 96.0, "spot_detail": "S 超市内部临时批发预约窗口（P02B D-6 预约整托配送，不等于 D-4 独立批发仓 K）"},
			{"id": "p_mkt_pallets", "label": "S 待交接整托纸箱位", "kind": "pallet_stack", "x": 4128.0, "floor": 1, "w": 160.0, "h": 112.0, "spot_detail": ""},
			{"id": "p_mkt_coolers", "label": "冷藏冷柜阵列", "kind": "cooler", "x": 4544.0, "floor": 1, "w": 320.0, "h": 192.0, "spot_detail": "H 超市右侧冷藏冷柜区"},
			{"id": "p_mkt_checkout", "label": "超市收银结账台", "kind": "counter", "x": 5024.0, "floor": 1, "w": 224.0, "h": 96.0, "spot_detail": "H 超市收银台（P01 结账与限购核验）"},
		],
		"landmarks": [
			{"id": "lm_h_in", "label": "1.入口与推车", "x": 320.0, "floor": 1, "doc_code": "H"},
			{"id": "lm_h_water", "label": "2.饮水货架区", "x": 1296.0, "floor": 1, "doc_code": "H"},
			{"id": "lm_h_food", "label": "3.食品日用区", "x": 2160.0, "floor": 1, "doc_code": "H"},
			{"id": "lm_s_resv", "label": "4.S后仓预约区", "x": 3680.0, "floor": 1, "doc_code": "S"},
			{"id": "lm_h_cool", "label": "5.冷藏冷柜区", "x": 4608.0, "floor": 1, "doc_code": "H"},
			{"id": "lm_h_out", "label": "6.收银与出口", "x": 5184.0, "floor": 1, "doc_code": "H"},
		],
	}


# ==============================================================================
# 10. I 五金 / 家电店（4,320 px）
# ==============================================================================
static func _spec_hardware_store() -> Dictionary:
	return {
		"key": &"hardware_store",
		"title": "五金 / 家电店（I 门窗密封、取暖与发电设备商店）",
		"doc_code": "I",
		"is_outdoor": false,
		"width": 4320.0,
		"ground_y": GROUND_Y,
		"sky_color": Color(0.15, 0.17, 0.15, 1.0),
		"ground_color": Color(0.28, 0.30, 0.27, 1.0),
		"road_top_color": Color(0.44, 0.47, 0.42, 1.0),
		"default_spawn": &"spawn_entrance",
		"floors": [
			{"floor": 1, "name": "1F 五金与家电商店", "ground_y": GROUND_Y, "ceiling_y": 128.0, "x0": 96.0, "x1": 4224.0},
		],
		"segments": [
			{"index": 1, "title": "入口与工具展示墙", "doc_code": "I", "x0": 96.0, "x1": 1536.0, "color": Color(0.30, 0.33, 0.30, 1.0), "summary": "入口门 → 促销板 → 工具展示墙"},
			{"index": 2, "title": "门窗密封与取暖/发电设备陈列", "doc_code": "I", "x0": 1536.0, "x1": 3328.0, "color": Color(0.32, 0.35, 0.31, 1.0), "summary": "密封条与加固门样板 → 电暖器与未运行发电机样机"},
			{"index": 3, "title": "收银台与装货口", "doc_code": "I", "x0": 3328.0, "x1": 4224.0, "color": Color(0.29, 0.32, 0.29, 1.0), "summary": "收银台 → 大件装货口"},
		],
		"spawns": {
			&"spawn_entrance": {"x": 288.0, "floor": 1, "ground_y": GROUND_Y, "facing": 1, "label": "五金店入口门内"},
		},
		"buildings": [
			{
				"id": "room_hardware",
				"doc_code": "I",
				"title": "I 五金 / 家电店内景剖面 (96..4224, 宽4128×高288)",
				"subtitle": "入口 → 工具展示墙 → 门窗密封样板 → 取暖器/未运行发电机样机 → 收银与装货口",
				"x": 96.0,
				"w": 4128.0,
				"h": 288.0,
				"floor": 1,
				"floors_count": 1,
				"wall_color": Color(0.31, 0.34, 0.31, 1.0),
				"roof_color": Color(0.21, 0.24, 0.21, 1.0),
				"accent_color": Color(0.84, 0.66, 0.40, 1.0),
				"roof_style": "interior_room",
				"art_slot": "SLOT_INT_HARDWARE",
				"registry_id": "ART_SCENE_112 (预留:五金/家电店)",
				"windows": [
					{"x": 864.0, "y_off": 96.0, "w": 384.0, "h": 96.0, "kind": "board", "label": "五金工具挂墙陈列板"},
				],
				"notes": ["店内发电机为未运行样机展示，不暗示室内安全运行"],
			},
		],
		"doors": [
			{
				"id": "door_hw_exit",
				"label": "五金店玻璃门",
				"prompt": "室外五金家电店门外",
				"x": 288.0,
				"floor": 1,
				"w": DOOR_STD_W,
				"h": DOOR_STD_H,
				"target_scene": &"outdoor_street",
				"target_spawn": &"spawn_hardware_gate",
				"interactive": true,
				"style": "glass",
			},
			{
				"id": "door_hw_loading",
				"label": "大件装货口门",
				"prompt": "室外五金家电店门外",
				"x": 3968.0,
				"floor": 1,
				"w": DOOR_WIDE_W,
				"h": DOOR_WIDE_H,
				"target_scene": &"outdoor_street",
				"target_spawn": &"spawn_hardware_gate",
				"interactive": true,
				"style": "wide_industrial",
			},
		],
		"stairs": [],
		"shelves": [
			{"id": "sh_hw_1", "label": "维修零件与耗材货架", "x": 1344.0, "floor": 1, "note": "五金店零件与密封胶条货架 · 96×192", "items": []},
		],
		"carts": [],
		"props": [
			{"id": "p_hw_door_sample", "label": "门窗密封条与加固门样板架", "kind": "door_sample", "x": 1920.0, "floor": 1, "w": 288.0, "h": 192.0, "spot_detail": "I 保温密封套件、加固门板与门口提示铃展示位（P02 / P04B / P07）"},
			{"id": "p_hw_heater_sample", "label": "取暖器与未运行发电机样机台", "kind": "generator_pad", "x": 2752.0, "floor": 1, "w": 320.0, "h": 112.0, "spot_detail": "I 电暖器（ART_FURN_102 规格）与未运行发电机样机展示台（P02 / P03）"},
			{"id": "p_hw_counter", "label": "五金店收银与大件订单台", "kind": "counter", "x": 3520.0, "floor": 1, "w": 224.0, "h": 96.0, "spot_detail": "I 收银与大件配送登记台（P07B D-1 延迟大件订单起点）"},
		],
		"landmarks": [
			{"id": "lm_i_in", "label": "1.入口与促销板", "x": 288.0, "floor": 1, "doc_code": "I"},
			{"id": "lm_i_tools", "label": "2.工具墙与货架", "x": 1152.0, "floor": 1, "doc_code": "I"},
			{"id": "lm_i_seal", "label": "3.门窗密封样板", "x": 1920.0, "floor": 1, "doc_code": "I"},
			{"id": "lm_i_equip", "label": "4.取暖/发电样机", "x": 2752.0, "floor": 1, "doc_code": "I"},
			{"id": "lm_i_out", "label": "5.收银与装货口", "x": 3680.0, "floor": 1, "doc_code": "I"},
		],
	}


# ==============================================================================
# 11. K 独立批发仓与装卸区（5,120 px，双门分别对应室外正门与装卸门）
# ==============================================================================
static func _spec_wholesale_warehouse() -> Dictionary:
	return {
		"key": &"wholesale_warehouse",
		"title": "独立批发仓与装卸区（K D-4 后大宗采购仓库）",
		"doc_code": "K",
		"is_outdoor": false,
		"width": 5120.0,
		"ground_y": GROUND_Y,
		"sky_color": Color(0.14, 0.16, 0.19, 1.0),
		"ground_color": Color(0.26, 0.28, 0.31, 1.0),
		"road_top_color": Color(0.41, 0.44, 0.48, 1.0),
		"default_spawn": &"spawn_entrance",
		"floors": [
			{"floor": 1, "name": "1F 独立批发仓与装卸平台（全长 5,120 px）", "ground_y": GROUND_Y, "ceiling_y": 64.0, "x0": 96.0, "x1": 5024.0},
		],
		"segments": [
			{"index": 1, "title": "仓门入口与空托盘区", "doc_code": "K", "x0": 96.0, "x1": 1536.0, "color": Color(0.27, 0.30, 0.34, 1.0), "summary": "正门入口 → 空托盘与推车区"},
			{"index": 2, "title": "大宗纸箱堆与工业货架区", "doc_code": "K", "x0": 1536.0, "x1": 3392.0, "color": Color(0.29, 0.32, 0.36, 1.0), "summary": "整托饮水与大宗食品纸箱堆 → 工业货架阵列"},
			{"index": 3, "title": "订单交接台与装卸门", "doc_code": "K", "x0": 3392.0, "x1": 5024.0, "color": Color(0.26, 0.29, 0.33, 1.0), "summary": "订单交接台 → 装卸平台 → 右侧装卸门(对应室外 x=12096)"},
		],
		"spawns": {
			&"spawn_entrance": {"x": 320.0, "floor": 1, "ground_y": GROUND_Y, "facing": 1, "label": "批发仓正门内"},
			&"spawn_loading_bay": {"x": 4736.0, "floor": 1, "ground_y": GROUND_Y, "facing": -1, "label": "批发仓装卸门内"},
		},
		"buildings": [
			{
				"id": "room_warehouse",
				"doc_code": "K",
				"title": "K 独立批发仓与装卸区剖面 (96..5024, 宽4928×高352)",
				"subtitle": "入口 → 空托盘区 → 大宗纸箱堆与工业货架 → 订单交接台 → 装卸门(双门独立对应室外)",
				"x": 96.0,
				"w": 4928.0,
				"h": 352.0,
				"floor": 1,
				"floors_count": 1,
				"wall_color": Color(0.28, 0.31, 0.35, 1.0),
				"roof_color": Color(0.19, 0.21, 0.24, 1.0),
				"accent_color": Color(0.80, 0.64, 0.40, 1.0),
				"roof_style": "industrial_warehouse",
				"art_slot": "SLOT_INT_WAREHOUSE",
				"registry_id": "ART_SCENE_104 (预留:批发仓库)",
				"windows": [
					{"x": 1408.0, "y_off": 224.0, "w": 320.0, "h": 64.0, "kind": "louver", "label": "仓库高侧采光窗 A"},
					{"x": 2880.0, "y_off": 224.0, "w": 320.0, "h": 64.0, "kind": "louver", "label": "仓库高侧采光窗 B"},
				],
				"notes": ["左门对应室外 x=10880，右装卸门对应室外 x=12096"],
			},
		],
		"doors": [
			{
				"id": "door_wh_main_out",
				"label": "批发仓正门 (192×224)",
				"prompt": "室外批发仓正门外 (x=10880)",
				"x": 320.0,
				"floor": 1,
				"w": DOOR_WIDE_W,
				"h": DOOR_WIDE_H,
				"target_scene": &"outdoor_street",
				"target_spawn": &"spawn_warehouse_gate",
				"interactive": true,
				"style": "wide_industrial",
			},
			{
				"id": "door_wh_dock_out",
				"label": "批发仓装卸门 (192×224)",
				"prompt": "室外批发仓装卸门外 (x=12096)",
				"x": 4736.0,
				"floor": 1,
				"w": DOOR_WIDE_W,
				"h": DOOR_WIDE_H,
				"target_scene": &"outdoor_street",
				"target_spawn": &"spawn_warehouse_dock",
				"interactive": true,
				"style": "wide_industrial",
			},
		],
		"stairs": [],
		"shelves": [
			{"id": "sh_wh_1", "label": "批发仓工业货架 A", "x": 1920.0, "floor": 1, "note": "批发仓重型货架 A · 整箱饮用水", "items": ["water", "water"]},
			{"id": "sh_wh_2", "label": "批发仓工业货架 B", "x": 2208.0, "floor": 1, "note": "批发仓重型货架 B · 整箱食品", "items": ["food", "food"]},
			{"id": "sh_wh_3", "label": "批发仓工业货架 C", "x": 2784.0, "floor": 1, "note": "批发仓重型货架 C · 大宗储备", "items": ["food", "water"]},
		],
		"carts": [
			{"id": "cart_wh_1", "x": 864.0, "floor": 1, "load_state": &"full"},
		],
		"props": [
			{"id": "p_wh_pallets_empty", "label": "空木托盘整理区", "kind": "pallet_stack", "x": 1152.0, "floor": 1, "w": 224.0, "h": 64.0, "spot_detail": ""},
			{"id": "p_wh_crates", "label": "大宗纸箱与饮水整托堆", "kind": "floor_items", "x": 2560.0, "floor": 1, "w": 160.0, "h": 96.0, "spot_detail": ""},
			{"id": "p_wh_order_desk", "label": "批发订单交接台", "kind": "counter", "x": 3680.0, "floor": 1, "w": 256.0, "h": 96.0, "spot_detail": "K 独立批发仓订单交接台（P04 D-4 后开放大宗采购与运力调度）"},
			{"id": "p_wh_dock_pad", "label": "装卸平台缓冲位", "kind": "dock_pad", "x": 4288.0, "floor": 1, "w": 256.0, "h": 80.0, "spot_detail": ""},
		],
		"landmarks": [
			{"id": "lm_k_in", "label": "1.仓门入口", "x": 320.0, "floor": 1, "doc_code": "K"},
			{"id": "lm_k_pallet", "label": "2.托盘与推车", "x": 960.0, "floor": 1, "doc_code": "K"},
			{"id": "lm_k_shelves", "label": "3.工业货架群", "x": 2208.0, "floor": 1, "doc_code": "K"},
			{"id": "lm_k_order", "label": "4.订单交接台", "x": 3680.0, "floor": 1, "doc_code": "K"},
			{"id": "lm_k_dock", "label": "5.右侧装卸门", "x": 4736.0, "floor": 1, "doc_code": "K"},
		],
	}


# ==============================================================================
# 12. L 物流中转点 / 大件取货口（2,880 px）
# ==============================================================================
static func _spec_logistics_hub() -> Dictionary:
	return {
		"key": &"logistics_hub",
		"title": "物流中转点 / 大件取货口（L P07B 延迟订单自取点）",
		"doc_code": "L",
		"is_outdoor": false,
		"width": 2880.0,
		"ground_y": GROUND_Y,
		"sky_color": Color(0.17, 0.20, 0.24, 1.0),
		"ground_color": Color(0.28, 0.31, 0.35, 1.0),
		"road_top_color": Color(0.45, 0.49, 0.54, 1.0),
		"default_spawn": &"spawn_entrance",
		"floors": [
			{"floor": 1, "name": "1F 物流中转取货区（全长 2,880 px）", "ground_y": GROUND_Y, "ceiling_y": 128.0, "x0": 96.0, "x1": 2784.0},
		],
		"segments": [
			{"index": 1, "title": "街道入口与积雪通道", "doc_code": "L", "x0": 96.0, "x1": 1152.0, "color": Color(0.28, 0.32, 0.37, 1.0), "summary": "返回街道的门 → 临时路障 → 等候与积雪通道"},
			{"index": 2, "title": "中转雨棚与交接窗口", "doc_code": "L", "x0": 1152.0, "x1": 2784.0, "color": Color(0.26, 0.30, 0.35, 1.0), "summary": "简易中转棚 → 待领货架 → 手推车位 → 工作人员交接窗口"},
		],
		"spawns": {
			&"spawn_entrance": {"x": 288.0, "floor": 1, "ground_y": GROUND_Y, "facing": 1, "label": "中转点街道入口内"},
		},
		"buildings": [
			{
				"id": "room_logistics",
				"doc_code": "L",
				"title": "L 物流中转点取货区剖面 (96..2784, 宽2688×高288)",
				"subtitle": "街道出入口 → 等候区与积雪通道 → 简易中转棚与待领货架 → 手推车位 → 交接窗口",
				"x": 96.0,
				"w": 2688.0,
				"h": 288.0,
				"floor": 1,
				"floors_count": 1,
				"wall_color": Color(0.29, 0.33, 0.38, 1.0),
				"roof_color": Color(0.20, 0.23, 0.27, 1.0),
				"accent_color": Color(0.72, 0.78, 0.86, 1.0),
				"roof_style": "canopy",
				"art_slot": "SLOT_INT_LOGISTICS",
				"registry_id": "待立项 (自 ART_SCENE_113 起顺延·物流中转点，注:109受保护为电台特写)",
				"windows": [
					{"x": 2208.0, "y_off": 96.0, "w": 256.0, "h": 96.0, "kind": "board", "label": "订单牌位与工作人员交接窗口"},
				],
				"notes": ["未发生 P07B 延迟订单时不预设玩家已获得大件物资"],
			},
		],
		"doors": [
			{
				"id": "door_log_exit",
				"label": "返回街道的出入口",
				"prompt": "室外物流中转口外",
				"x": 288.0,
				"floor": 1,
				"w": DOOR_STD_W,
				"h": DOOR_STD_H,
				"target_scene": &"outdoor_street",
				"target_spawn": &"spawn_logistics_gate",
				"interactive": true,
				"style": "metal",
			},
		],
		"stairs": [],
		"shelves": [
			{"id": "sh_log_1", "label": "中转待领货架", "x": 1536.0, "floor": 1, "note": "中转棚待领货架 · 96×192（独立层，按实际订单状态显示）", "items": []},
		],
		"carts": [],
		"props": [
			{"id": "p_log_barrier", "label": "临时路障与等候区", "kind": "barrier", "x": 768.0, "floor": 1, "w": 160.0, "h": 80.0, "spot_detail": ""},
			{"id": "p_log_handcart", "label": "手推车停靠位", "kind": "dock_pad", "x": 1920.0, "floor": 1, "w": 160.0, "h": 72.0, "spot_detail": ""},
			{"id": "p_log_window", "label": "中转点工作人员交接窗口", "kind": "counter", "x": 2336.0, "floor": 1, "w": 256.0, "h": 112.0, "spot_detail": "L 物流中转点交接窗口（P07B D-1 五金大件延迟订单自取/专车/退款互斥）"},
		],
		"landmarks": [
			{"id": "lm_l_in", "label": "1.街道出入口", "x": 288.0, "floor": 1, "doc_code": "L"},
			{"id": "lm_l_wait", "label": "2.等候与路障", "x": 768.0, "floor": 1, "doc_code": "L"},
			{"id": "lm_l_shelf", "label": "3.中转棚货架", "x": 1536.0, "floor": 1, "doc_code": "L"},
			{"id": "lm_l_win", "label": "4.交接窗口", "x": 2336.0, "floor": 1, "doc_code": "L"},
		],
	}


# ==============================================================================
# 13. G0 序章 P00 前世门外冰封走廊（1,920 px，与居民楼公共楼道区分）
# ==============================================================================
static func _spec_past_corridor() -> Dictionary:
	return {
		"key": &"past_corridor",
		"title": "序章 P00 前世门外冰封走廊（G0 独立回忆地点）",
		"doc_code": "G(P00)",
		"is_outdoor": false,
		"width": 1920.0,
		"ground_y": GROUND_Y,
		"sky_color": Color(0.08, 0.11, 0.16, 1.0),
		"ground_color": Color(0.18, 0.22, 0.28, 1.0),
		"road_top_color": Color(0.32, 0.39, 0.48, 1.0),
		"default_spawn": &"spawn_corridor_left",
		"floors": [
			{"floor": 1, "name": "1F 前世冰封走廊（P00 冻死回忆 / D05B 闪回）", "ground_y": GROUND_Y, "ceiling_y": 160.0, "x0": 96.0, "x1": 1824.0},
		],
		"segments": [
			{"index": 1, "title": "应急红灯与冰霜楼道窗", "doc_code": "G(P00)", "x0": 96.0, "x1": 1152.0, "color": Color(0.14, 0.19, 0.26, 1.0), "summary": "走廊端头应急红灯 → 冰霜窗与风雪透光"},
			{"index": 2, "title": "前世被反锁的自家安全门", "doc_code": "G(P00)", "x0": 1152.0, "x1": 1824.0, "color": Color(0.16, 0.21, 0.28, 1.0), "summary": "前世自家门(底部透微弱暖光) → 走廊尽头"},
		],
		"spawns": {
			&"spawn_corridor_left": {"x": 320.0, "floor": 1, "ground_y": GROUND_Y, "facing": 1, "label": "前世走廊起点"},
		},
		"buildings": [
			{
				"id": "room_past_corridor",
				"doc_code": "G(P00)",
				"title": "G0 前世门外冰封走廊剖面 (96..1824, 宽1728×高256)",
				"subtitle": "红色应急灯 → 冰霜楼道窗 → 前世被孟雨薇反锁的自家门(门缝透暖光) → 封闭端头",
				"x": 96.0,
				"w": 1728.0,
				"h": 256.0,
				"floor": 1,
				"floors_count": 1,
				"wall_color": Color(0.16, 0.21, 0.28, 1.0),
				"roof_color": Color(0.10, 0.14, 0.20, 1.0),
				"accent_color": Color(0.82, 0.36, 0.34, 1.0),
				"roof_style": "interior_room",
				"art_slot": "SLOT_INT_PAST_CORRIDOR",
				"registry_id": "ART_SCENE_108 (预留:门外楼道·前世冰封走廊变体)",
				"windows": [
					{"x": 640.0, "y_off": 88.0, "w": 224.0, "h": 96.0, "kind": "cold", "label": "结霜走廊窗(窗外暴雪)"},
				],
				"notes": ["与居民楼公共楼道属于不同具体地点，不混成同一扇门"],
			},
		],
		"doors": [
			{
				"id": "door_past_to_present",
				"label": "重生转场口(返回现世安全屋)",
				"prompt": "现世安全屋一层 (A)",
				"x": 256.0,
				"floor": 1,
				"w": DOOR_STD_W,
				"h": DOOR_STD_H,
				"target_scene": &"shelter",
				"target_spawn": &"spawn_bed",
				"interactive": true,
				"style": "metal",
			},
			{
				"id": "door_past_locked",
				"label": "前世被反锁的自家门(装饰门·门内暖光)",
				"prompt": "",
				"x": 1440.0,
				"floor": 1,
				"w": DOOR_STD_W,
				"h": DOOR_STD_H,
				"target_scene": &"",
				"target_spawn": &"",
				"interactive": false,
				"style": "locked_warm_seam",
			},
		],
		"stairs": [],
		"shelves": [],
		"carts": [],
		"props": [
			{"id": "p_past_locked_spot", "label": "前世反锁的家门 (P00)", "kind": "notice_board", "x": 1440.0, "floor": 1, "w": 112.0, "h": 192.0, "spot_detail": "P00 前世的最后一夜：备用钥匙被孟雨薇反锁在门内，门缝底部透出微弱暖光"},
		],
		"landmarks": [
			{"id": "lm_g0_start", "label": "1.应急灯起点", "x": 320.0, "floor": 1, "doc_code": "P00"},
			{"id": "lm_g0_win", "label": "2.冰霜走廊窗", "x": 752.0, "floor": 1, "doc_code": "P00"},
			{"id": "lm_g0_door", "label": "3.前世反锁家门", "x": 1440.0, "floor": 1, "doc_code": "P00"},
		],
	}
