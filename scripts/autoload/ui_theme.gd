extends Node
## 全局 UI Theme 挂载（PREP-003 修复首次导入错误 / CORE-001B 修复换场景丢主题）
##
## 原因：Godot 4.7 的 ThemeDB 在**资源导入之前**就读取 project.godot 的
## `gui/theme/custom` 并加载项目主题。全新 .godot/ 里字体还没被导入成
## .fontdata，主题又通过 .ttf 引用它，于是第一次 --headless --import 报
## 「Failed loading resource / Error loading custom project theme」。
##
## 解决：不在 project.godot 里设项目级主题，改为运行时由本 autoload 把
## 同一个 main_theme.tres 挂到根窗口。资源导入阶段完全不触碰主题，
## 字体 / 主题内容 / 显示效果不变。
##
## 注意：这里必须用 load() 而不是 preload()，否则脚本被扫描时又会提前解析主题。
##
## CORE-001B 补的第二个坑：`Window.theme` 只对**当时已在树上**的节点完成传播，
## 之后用 `change_scene_to_file` 载入的新场景拿不到主题。桌面端有系统字体兜底，
## 中文看起来正常，所以这个问题一直没被发现；**Web 端没有系统字体兜底**，
## 换场景后的占位页整页变成方块（□）。因此每次场景切换后必须重新挂一次主题。
## 重新赋值同一个 Theme 资源会被 Window 的相等判断吃掉，所以先置空再赋。

const THEME_PATH := "res://assets/ui/themes/main_theme.tres"

var is_ready: bool = false
var theme: Theme


func _ready() -> void:
	theme = load(THEME_PATH) as Theme
	if theme == null:
		push_error("[UiTheme] 无法加载 UI Theme: %s" % THEME_PATH)
		return
	get_tree().root.theme = theme
	is_ready = true


## 场景切换后调用：强制把主题重新传播到整棵树（含刚载入的新场景）
func force_reapply() -> void:
	if not is_ready or theme == null or not is_inside_tree():
		return
	var root := get_tree().root
	if root == null:
		return
	root.theme = null
	root.theme = theme


## 场景切换后重挂主题。
## 注意 change_scene_to_file 至少要跨两帧：先释放旧场景（这期间 current_scene 为 null），
## 下一帧才把新场景挂上。所以这里必须**轮询**到新场景出现，固定等一帧是拿不到的。
func reapply_after_scene_change() -> void:
	if not is_ready:
		return
	for i in 40:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene == null:
			continue
		force_reapply()
		var n := apply_to(scene)
		# 同一次切换可能触发多条重挂协程，已经挂过的第二次会得到 0，不必再打日志
		if n > 0:
			print("[THEME] 已重挂主题到 %s（%d 个 Control）" % [scene.scene_file_path, n])
		return


## 递归把主题挂到场景里所有"没有自己的 theme"的 Control 上（共用同一份资源，不复制）。
## 只重挂 Window 级主题是不够的：已经在树上的 Control 在进入树时就绑定了 theme owner，
## 之后 Window 换主题不会让它们重新解析字体，Web 端就会一直用过时的内置字体（方块）。
func apply_to(node: Node) -> int:
	if theme == null or node == null:
		return 0
	var n := 0
	var c := node as Control
	if c != null and c.theme == null:
		c.theme = theme
		n += 1
	for child in node.get_children():
		n += apply_to(child)
	return n
