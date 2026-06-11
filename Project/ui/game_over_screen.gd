extends Control
## 局后屏（SpecKit 004 T013：kit 样式迁移；完整局后总结仪式属 Phase P T103）
## 设计: Designs/Interactive/presentation_design.md §3（角括号框菜单）/§4（字号阶梯）/
## §11.7（测试模式按钮与 T 捷径属 debug UI，收进 presentation.debug_ui 开关）。
## 公共契约不变（main.gd 依赖）：restart_pressed / test_mode_pressed 信号 +
## show_results(data) + 场景节点路径 VBoxContainer/*（test_t11 打包结构）。
## spec 003 M2 结算数据通路：set_summary_source(obj)（duck-typed，
## MetaGrowthRoot.get_last_run_summary）→ 本局统计 + 新解锁 + 铸石以 kit 文本行呈现
## （零仪式；RunSummaryScreen 视觉编排归 S4 Phase P）。

signal restart_pressed
signal test_mode_pressed

const _KitPanelScript := preload("res://ui/kit/kit_panel.gd")

@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var cause_label: Label = $VBoxContainer/CauseLabel
@onready var restart_button: Button = $VBoxContainer/RestartButton
@onready var menu_box: VBoxContainer = $VBoxContainer

var _test_button: Button
var _frame_panel: PanelContainer
## spec 003 M2：结算数据源（duck-typed get_last_run_summary；未注入零行为）
var _summary_source = null
var _summary_box: VBoxContainer


func _ready() -> void:
	# §2/§4：共享 kit Theme（palette/typography 单一事实源）
	theme = _KitPanelScript._get_shared_theme()
	cause_label.add_theme_color_override(
		"font_color", ConfigManager.get_palette_color("text_dim"))
	restart_button.pressed.connect(_on_restart_pressed)
	_build_summary_box()
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
	# spec 003 M2 结算行：同步刷一次（测试/布景直驱）；再延迟刷一次——生产时序里
	# game_over（GameManager autoload 先连 snake_died）先于 run_ended 抵达，
	# 结算缓存在同一派发稍后才写入（M1 事实：finalize 在 RunProgression 的 snake_died handler）
	_refresh_summary()
	call_deferred("_refresh_summary")
	show()


## spec 003 M2：结算数据源注入（main.gd 接 MetaGrowthRoot；未注入零行为）
func set_summary_source(source) -> void:
	_summary_source = source


## 结算文本行快照（测试契约；空 = 无本局结算数据）
func get_summary_lines() -> Array:
	var lines: Array = []
	if _summary_box == null:
		return lines
	for child in _summary_box.get_children():
		if child is Label:
			lines.append(child.text)
	return lines


func _build_summary_box() -> void:
	_summary_box = VBoxContainer.new()
	_summary_box.name = "SummaryRows"
	menu_box.add_child(_summary_box)
	menu_box.move_child(_summary_box, cause_label.get_index() + 1)


## 重建结算行（幂等）：统计一行 + 每个新解锁一行 + 铸石一行；无数据零行
func _refresh_summary() -> void:
	if _summary_box == null or not is_instance_valid(_summary_box):
		return
	for child in _summary_box.get_children():
		_summary_box.remove_child(child)
		child.free()
	if _summary_source == null or not is_instance_valid(_summary_source):
		return
	if not _summary_source.has_method("get_last_run_summary"):
		return
	var summary: Dictionary = _summary_source.get_last_run_summary()
	if summary.is_empty():
		return

	var stats: Dictionary = summary.get("stats", {})
	_add_summary_row("击杀 %d（反应 %d）｜楼层 %d｜历时 %d tick" % [
		int(stats.get("total_kills", 0)),
		int(stats.get("reaction_kills", 0)),
		int(stats.get("floors_completed", 0)),
		int(stats.get("duration_ticks", 0)),
	], "text_dim")
	for unlock in summary.get("unlocks", []):
		if unlock is Dictionary:
			_add_summary_row("解锁 %s" % str(unlock.get("display_name",
				unlock.get("content_id", ""))), "accent_shedskin")
	var stone: Dictionary = summary.get("stone", {})
	if not stone.is_empty():
		_add_summary_row("传承石 「%s」" % str(stone.get("display_name", "")),
			"accent_resonance")


func _add_summary_row(text: String, palette_token: String) -> void:
	var label := Label.new()
	label.theme_type_variation = "BodyLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override(
		"font_color", ConfigManager.get_palette_color(palette_token))
	label.text = text
	_summary_box.add_child(label)


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
