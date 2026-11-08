class_name WindowFit
extends RefCounted
## 初始窗口自适应（工程底座工具，不含玩法逻辑）
##
## 规则：内部逻辑分辨率固定 960×540；窗口尺寸只允许整数倍，
## 并取「能放进当前显示器可用区域」的最大倍数，避免超出桌面或出现非整数倍模糊。
## 发布版不写死 1920×1080，由新机器的实际屏幕决定。
##
## 注意多显示器：screen_get_usable_rect() 返回的是**虚拟桌面坐标**（含 position），
## 居中必须用 rect.position 作为原点，否则窗口会被摆到另一块屏幕上。

const BASE := Vector2i(960, 540)
const MAX_SCALE := 3
## 给标题栏、任务栏和窗口边框预留的余量
const MARGIN := 64


static func best_scale(usable_size: Vector2i) -> int:
	var sx: int = maxi(0, usable_size.x - MARGIN) / BASE.x
	var sy: int = maxi(0, usable_size.y - MARGIN) / BASE.y
	return clampi(mini(sx, sy), 1, MAX_SCALE)


static func recommended_window_size(usable_size: Vector2i) -> Vector2i:
	return BASE * best_scale(usable_size)


static func centered_position(usable_rect: Rect2i, window_size: Vector2i) -> Vector2i:
	return usable_rect.position + (usable_rect.size - window_size) / 2


static func fits_in(usable_rect: Rect2i, window_size: Vector2i, window_pos: Vector2i) -> bool:
	var origin := usable_rect.position
	var end := usable_rect.position + usable_rect.size
	return (
		window_pos.x >= origin.x and window_pos.y >= origin.y
		and window_pos.x + window_size.x <= end.x
		and window_pos.y + window_size.y <= end.y
	)


static func comparison_rect(usable: Rect2i, screen_pos: Vector2i, screen_size: Vector2i, fullscreen: bool) -> Rect2i:
	## 全屏时窗口本来就会盖住任务栏，不能拿可用区域去判定「超屏」
	return Rect2i(screen_pos, screen_size) if fullscreen else usable


static func is_fullscreen(mode: DisplayServer.WindowMode) -> bool:
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


static func describe_mode(mode: DisplayServer.WindowMode) -> String:
	match mode:
		DisplayServer.WINDOW_MODE_WINDOWED: return "windowed"
		DisplayServer.WINDOW_MODE_MINIMIZED: return "minimized"
		DisplayServer.WINDOW_MODE_MAXIMIZED: return "maximized"
		DisplayServer.WINDOW_MODE_FULLSCREEN: return "fullscreen"
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN: return "exclusive_fullscreen"
	return "unknown(%d)" % mode
