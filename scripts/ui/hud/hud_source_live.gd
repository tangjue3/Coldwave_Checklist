class_name HudSourceLive
extends HudSource
## 正式数据源（TASK-UI-009）
##
## 现在能接的真数据只有**地点**：`GameState.location` 由 SceneRouter 在切场景时写入，
## 是全工程唯一已实现的玩家状态。这里把它翻成 HUD 上的短名字。
##
## 其余字段（时间 / 天气 / 生存 / 物资 / 任务）目前**没有正式系统**，
## 一律由 `HudSourceMock` 提供，并在 `mock` 里如实列出——HUD 右上角会显示出来。
## 以后某个系统做完了，就把对应字段改成读正式数据，并从 `mock` 里删掉，
## 不需要动 HUD 场景本身。

## 地点短名：都是「场景自己的 display_name 缩写」，不是新编的世界观设定。
## 室内场景里，宿主会用 `interior_room.display_name` 覆盖掉这张表（见 interior_room.gd）。
const LOCATION_LABELS := {
	&"season1_map": "梧桐里 · 长街",
	&"int_a": "外婆老宅",
	&"int_b2": "居民楼 2 单元",
	&"int_c": "C 设备区",
	&"int_ft": "梧桐里居民楼",
	&"int_fw": "公告栏住处",
	&"int_h": "灾前连锁超市",
	&"int_i": "五金家电店",
	&"int_j": "唐宁便利店",
	&"int_k": "批发仓",
	&"int_l": "物流中转",
	&"int_n": "社区药店",
	&"int_q": "陈叔维修角",
}

var _mock := HudSourceMock.new()


func snapshot() -> Dictionary:
	var d := _mock.snapshot()
	d["location"] = _location_text()
	var still_mock := PackedStringArray()
	for f in d["mock"]:
		if f != "location":
			still_mock.append(f)
	d["mock"] = still_mock
	return d


func _location_text() -> String:
	var key: StringName = GameState.location
	if LOCATION_LABELS.has(key):
		return String(LOCATION_LABELS[key])
	# 没登记的地点：不要把内部标识当成世界观名字，退回一个明确的占位
	return String(key).replace("_", " ")


func describe() -> String:
	return "live(location=GameState.location + mock=5 systems)"
