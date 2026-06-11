extends "res://ui/kit/chip.gd"
## spec 003 M2（T011）：解锁 toast——kit chip 基座，ui_layer = "toast"
## （§11.5 层矩阵：toast 可压 hud、同层 ≤1；进 ui_kit/ui_chip 组即被几何探测自动覆盖）。
## 数据通路 only：content_unlocked → 顶中显示「解锁 <display_name>」+ 组件级 bounce；
## 重复解锁原地更新文本（同屏恒 ≤1 件）；下个 run_started 收起。
## 停留时长 / 飞行 / 仪式编排归 S4（004 Phase P CeremonyLayer）。
## 无 class_name：消费方（main.gd / 测试）一律 preload 本文件。


func _init() -> void:
	super()
	set_ui_layer("toast")
	visible = false


func _ready() -> void:
	connect_events()


func _exit_tree() -> void:
	disconnect_events()


func connect_events() -> void:
	if not EventBus.content_unlocked.is_connected(_on_content_unlocked):
		EventBus.content_unlocked.connect(_on_content_unlocked)
	if not EventBus.run_started.is_connected(_on_run_started):
		EventBus.run_started.connect(_on_run_started)


func disconnect_events() -> void:
	if EventBus.content_unlocked.is_connected(_on_content_unlocked):
		EventBus.content_unlocked.disconnect(_on_content_unlocked)
	if EventBus.run_started.is_connected(_on_run_started):
		EventBus.run_started.disconnect(_on_run_started)


func _on_content_unlocked(data: Dictionary) -> void:
	var display: String = str(data.get("display_name", data.get("content_id", "")))
	set_content(_glyph_for(str(data.get("content_type", ""))),
		"解锁 %s" % display,
		ConfigManager.get_palette_color("accent_shedskin"))
	visible = true
	_snap_top_center()
	bounce()


func _on_run_started(_data: Dictionary) -> void:
	visible = false


func _glyph_for(content_type: String) -> String:
	match content_type:
		"head":
			return "head"
		"tail":
			return "tail"
	return "reward"


## 顶中停靠（§6 布局：screen_margin 内缩；最小尺寸居中，内容驱动宽度）
func _snap_top_center() -> void:
	var margin: int = int(ConfigManager.get_layout_config().get("screen_margin", 0))
	set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, margin)
