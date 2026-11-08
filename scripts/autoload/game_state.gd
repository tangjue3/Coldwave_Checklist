extends Node
## GameState · 最小接口契约（PREP-003）
##
## 本轮**只**保存工程级的「当前所在场景」标识，用于场景切换与调试。
## 明确不保存：现金 / AP / 食物 / 水 / 燃料 / 电力 / 生命 / 抗寒 / 日期 /
## 库存 / pending_delivery / 设施 / 剧情 flag / 结局 / 存档内容。
## 第一季经济平衡、购物数据、剧情条件、存档 schema 一律等待总策划单独审核，
## 不得在本文件里提前设计或硬编码。

signal location_changed(from: StringName, to: StringName)

## 允许的位置标识由 SceneRouter.PATHS 定义；这里不重复一份数值表
var location: StringName = &"main_menu"


func set_location(next_location: StringName) -> void:
	if next_location == location:
		return
	var previous := location
	location = next_location
	location_changed.emit(previous, next_location)


## 供自检调用：确认本对象没有越界保存玩法状态
func contract_version() -> String:
	return "PREP-003/minimal-location-only"
