class_name HudSourceMock
extends HudSource
## 测试数据源（TASK-UI-009）
##
## **这里的所有数字都不是玩法系统产出的。** 时间 / 天气 / 生存 / 物资 / 任务
## 五套系统在工程里都还没有实现，本文件只是把「HUD 长什么样」验证完，
## 好让美术总监先看视觉。等对应系统做出来后，改由 HudSourceLive 直接读正式数据，
## 本文件随之下线或只留在开发预览里。
##
## 改这里的数值不会影响任何玩法结果，反之亦然——这是刻意的隔离。

const TASKS := [
	{"text": "检查壁炉燃料", "done": true},
	{"text": "整理厨房物资", "done": false},
	{"text": "前往社区超市", "done": false},
	{"text": "给水箱包保温层", "done": false},
]

const STATUS := [
	{"icon": "temperature", "label": "体温", "value": "36.4°C", "ratio": 0.92},
	{"icon": "hunger", "label": "饥饿", "value": "72%", "ratio": 0.72},
	{"icon": "thirst", "label": "口渴", "value": "64%", "ratio": 0.64},
	{"icon": "fatigue", "label": "疲劳", "value": "46%", "ratio": 0.46},
	{"icon": "weight", "label": "负重", "value": "28.4/40", "ratio": 0.71},
]

const RESOURCES := [
	{"icon": "cash", "text": "现金 126"},
	{"icon": "firewood", "text": "木材 8"},
	{"icon": "cloth", "text": "布料 3"},
]

const HOTBAR := [
	{"icon": "flashlight", "qty": ""},
	{"icon": "water", "qty": "2"},
	{"icon": "bread", "qty": "3"},
	{"icon": "firewood", "qty": "8"},
	{"icon": "pliers", "qty": ""},
	{"icon": "key", "qty": "1"},
]

const MOCK_FIELDS := ["datetime", "weather", "tasks", "status", "resources", "hotbar"]


func snapshot() -> Dictionary:
	return {
		"location": "—",
		"datetime": "第 1 天 06:35",
		"weather": "-18°C 小雪",
		"tasks": TASKS.duplicate(true),
		"status": STATUS.duplicate(true),
		"resources": RESOURCES.duplicate(true),
		"hotbar": HOTBAR.duplicate(true),
		"mock": PackedStringArray(MOCK_FIELDS),
	}


func describe() -> String:
	return "mock"
