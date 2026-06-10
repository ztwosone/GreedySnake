extends Control
## 局后屏（SpecKit 004 T013：kit 样式迁移；完整局后总结仪式属 Phase P T103）
## 设计: Designs/Interactive/presentation_design.md §3（角括号框菜单）/§4（字号阶梯）/
## §11.7（测试模式按钮与 T 捷径属 debug UI，收进 presentation.debug_ui 开关）。
## 公共契约不变（main.gd 依赖）：restart_pressed / test_mode_pressed 信号 +
## show_results(data) + 场景节点路径 VBoxContainer/*（test_t11 打包结构）。

signal restart_pressed
signal test_mode_pressed

const _KitPanelScript := preload("res://ui/kit/kit_panel.gd")

@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var cause_label: Label = $VBoxContainer/CauseLabel
@onready var restart_button: Button = $VBoxContainer/RestartButton
@onready var menu_box: VBoxContainer = $VBoxContainer

var _test_button: Button
var _frame_panel: PanelContainer


func _ready() -> void:
	# §2/§4：共享 kit Theme（palette/typography 单一事实源）
	theme = _KitPanelScript._get_shared_theme()
	cause_label.add_theme_color_override(
		"font_color", ConfigManager.get_palette_color("text_dim"))
	restart_button.pressed.connect(_on_restart_pressed)
	_build_frame()

	# §11.7：测试模式按钮属 debug UI，开关关闭时不创建（信号契约保留）
	if ConfigManager.is_debug_ui_enabled():
		_test_button = Button.new()
		_test_button.text = "测试模式 (T)"
		_test_button.pressed.connect(_on_test_mode_pressed)
		menu_box.add_child(_test_button)
		_frame_panel.register_hit_target(_test_button)


## §3 签名母题：菜单坐在 bg_panel 底 + 四角括号（kit_panel）上，矩形跟随菜单尺寸
func _build_frame() -> void:
	_frame_panel = _KitPanelScript.new()
	_frame_panel.name = "MenuFrame"
	_frame_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame_panel)
	move_child(_frame_panel, 0)
	# §6/§12.1：交互件入 ui_hit 组并保证最小命中目标
	_frame_panel.register_hit_target(restart_button)
	menu_box.item_rect_changed.connect(_sync_frame)
	_sync_frame()


func _sync_frame() -> void:
	if _frame_panel == null:
		return
	var pad: float = float(ConfigManager.get_layout_config().get("panel_padding", 0))
	_frame_panel.position = menu_box.position - Vector2(pad, pad)
	_frame_panel.size = menu_box.size + Vector2(pad, pad) * 2.0


func show_results(data: Dictionary) -> void:
	var score: int = data.get("score", 0)
	var best: int = data.get("best_score", 0)
	var cause: String = data.get("cause", "unknown")
	score_label.text = "得分 %d ／ 最佳 %d" % [score, best]
	# 死因 cause→中文映射（presentation.death_causes）随 Phase P 死亡仪式落地（§7）
	cause_label.text = "死因：%s" % cause
	show()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# §11.7：T 捷径属 debug UI，开关关闭时 no-op
	if not ConfigManager.is_debug_ui_enabled():
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		_on_test_mode_pressed()


func _on_restart_pressed() -> void:
	restart_pressed.emit()


func _on_test_mode_pressed() -> void:
	test_mode_pressed.emit()
