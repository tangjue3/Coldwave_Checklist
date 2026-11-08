extends Node
## SaveManager · 最小接口契约（PREP-003）
##
## 存档系统**尚未实现**。本轮只固定方法名与返回边界，供主菜单的
## 「继续游戏」按钮判断可不可用；不写任何存档内容、路径、格式或 schema。
## 正式方案（存档槽、自动存档、失败重试、schema_version 迁移等）
## 需总策划审核后单独下发任务。

const STATUS_UNAVAILABLE := "存档系统未实现：等待存档方案审核"


## 是否存在可继续的存档。实现前恒为 false。
func has_save() -> bool:
	return false


## 「继续游戏」是否可用。实现前恒为 false。
func can_continue() -> bool:
	return false


## 空实现：不写文件、不返回成功。
func save_game(_payload: Dictionary) -> bool:
	push_warning("[SaveManager] save_game() 尚未实现，已拒绝调用")
	return false


## 空实现：不读文件、不返回任何存档数据。
func load_game() -> Dictionary:
	push_warning("[SaveManager] load_game() 尚未实现，已拒绝调用")
	return {}


func status() -> String:
	return STATUS_UNAVAILABLE
