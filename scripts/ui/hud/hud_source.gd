class_name HudSource
extends RefCounted
## HUD 数据源接口（TASK-UI-009）
##
## 正式 HUD 只认这一个契约：谁实现 `snapshot()`，谁就能给 HUD 喂数据。
## 目的：把「已经在跑的正式数据」和「还没做、只能先拿测试数据顶」的东西
## **在代码层面分开**，避免以后有人把测试数值当成已经实现的功能。
##
## 返回的字典字段：
##   location  : String   当前地点显示名（正式数据：GameState.location）
##   datetime  : String   「第 N 天 HH:MM」
##   weather   : String   「-18°C 小雪」
##   tasks     : Array[{ text: String, done: bool }]
##   status    : Array[{ icon: String, label: String, value: String, ratio: float(0–1) }]
##   resources : Array[{ icon: String, text: String }]
##   hotbar    : Array[{ icon: String, qty: String }]
##   mock      : PackedStringArray  上面哪些字段是**测试数据**（不是正式系统产出）
##
## 实现者必须老实填 `mock`：HUD 会把它显示在右上角，不许冒充已实现玩法。


func snapshot() -> Dictionary:
	return {
		"location": "",
		"datetime": "",
		"weather": "",
		"tasks": [],
		"status": [],
		"resources": [],
		"hotbar": [],
		"mock": PackedStringArray(),
	}


## 日志用：数据源自称
func describe() -> String:
	return "empty"
