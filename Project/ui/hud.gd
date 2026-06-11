extends Control
## HUD（SpecKit 004 T013：kit 样式迁移）
## 设计: Designs/Interactive/presentation_design.md §6 布局图（左下 [长度/受击] chip）/
## §4（字号阶梯 + 文本必须有 bg_panel 底）/§1（tick 脉搏线保留）。
## 场景节点契约：UI/HUD/LengthLabel 留在打包结构（test_t10），运行时收编进 kit 面板。
## 小地图/Build 状态条属 Phase P T104，本层不建。

const _HealthBarScript = preload("res://ui/health_bar.gd")
const _HitCounterScript = preload("res://ui/hit_counter.gd")
const _TickPulseScript = preload("res://ui/tick_pulse.gd")
const _KitPanelScript = preload("res://ui/kit/kit_panel.gd")

@onready var length_label: Label = $LengthLabel
@onready var status_label: Label = $StatusLabel
var _stats_panel: PanelContainer
var _pause_label: Label
var _countdown_label: Label
var _health_bar: Node
var _hit_counter: Node
var _tick_pulse: Node
var _is_paused: bool = false


func _ready() -> void:
	# §2/§4：共享 kit Theme（palette/typography 单一事实源）
	theme = _KitPanelScript._get_shared_theme()

	EventBus.snake_length_increased.connect(_update_length)
	EventBus.snake_length_decreased.connect(_update_length)
	EventBus.game_started.connect(_on_game_started)
	EventBus.status_applied.connect(_on_status_changed)
	EventBus.status_removed.connect(_on_status_changed)
	EventBus.status_layer_changed.connect(_on_status_changed)
	EventBus.status_expired.connect(_on_status_changed)
	EventBus.no_body_countdown_tick.connect(_on_countdown_tick)
	EventBus.no_body_countdown_started.connect(_on_countdown_started)
	EventBus.no_body_countdown_cancelled.connect(_on_countdown_cancelled)

	_build_stats_panel()

	# Tick 脉搏线（§1：0.25s 心跳的底缘 2px 可视化，保留）
	_tick_pulse = _TickPulseScript.new()
	add_child(_tick_pulse)

	# 暂停提示标签（§4 display 级）
	_pause_label = Label.new()
	_pause_label.text = "已暂停"
	_pause_label.theme_type_variation = "DisplayLabel"
	_pause_label.add_theme_color_override(
		"font_color", ConfigManager.get_palette_color("accent_shedskin"))
	_pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pause_label.set_anchors_preset(PRESET_CENTER)
	_pause_label.visible = false
	add_child(_pause_label)

	# 无身体倒计时标签（§4 title 级；色随剩余时间金→危险红）
	_countdown_label = Label.new()
	_countdown_label.theme_type_variation = "TitleLabel"
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.set_anchors_preset(PRESET_CENTER_TOP)
	_countdown_label.position.y = float(ConfigManager.get_layout_config().get("base_unit", 0)) * 2.5
	_countdown_label.visible = false
	add_child(_countdown_label)


## §6 布局图：左下 [长度/受击] chip——kit 面板从左下角随内容向右上生长，
## 场景里的长度/状态标签收编进面板（§4：文本必须有 bg_panel 底）
func _build_stats_panel() -> void:
	var layout: Dictionary = ConfigManager.get_layout_config()
	var base_unit: float = float(layout.get("base_unit", 0))
	var screen_margin: float = float(layout.get("screen_margin", 0))

	_stats_panel = _KitPanelScript.new()
	_stats_panel.name = "StatsPanel"
	_stats_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_stats_panel.grow_horizontal = Control.GROW_DIRECTION_END
	_stats_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_stats_panel.offset_left = screen_margin
	_stats_panel.offset_right = screen_margin
	_stats_panel.offset_top = -screen_margin
	_stats_panel.offset_bottom = -screen_margin
	add_child(_stats_panel)
	move_child(_stats_panel, 0)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(base_unit * 0.25))
	_stats_panel.add_child(column)

	length_label.remove_theme_font_size_override("font_size")
	length_label.theme_type_variation = "HeadingLabel"
	length_label.get_parent().remove_child(length_label)
	column.add_child(length_label)

	# 蛇段长度条 + 受击计数器（§6 长度/受击同 chip）
	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", int(base_unit * 0.5))
	column.add_child(stat_row)
	_health_bar = _HealthBarScript.new()
	stat_row.add_child(_health_bar)
	_hit_counter = _HitCounterScript.new()
	_hit_counter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stat_row.add_child(_hit_counter)

	status_label.remove_theme_font_size_override("font_size")
	status_label.theme_type_variation = "CaptionLabel"
	status_label.add_theme_color_override(
		"font_color", ConfigManager.get_palette_color("text_dim"))
	status_label.get_parent().remove_child(status_label)
	column.add_child(status_label)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()


func _update_length(data: Dictionary) -> void:
	length_label.text = "长度 %d" % data.get("new_length", 0)


func _on_game_started() -> void:
	length_label.text = "长度 %d" % Constants.INITIAL_SNAKE_LENGTH
	_update_status_display()


func _on_status_changed(_data: Dictionary) -> void:
	_update_status_display()


func _update_status_display() -> void:
	if status_label == null:
		return
	var sem = StatusEffectManager
	# 找到 Snake 节点
	var snake_node = get_tree().get_first_node_in_group("snake") if is_inside_tree() else null
	if snake_node == null:
		# 尝试从场景树中查找
		var gw = get_parent().get_parent() if get_parent() else null
		if gw and gw.has_node("EntityContainer/Snake"):
			snake_node = gw.get_node("EntityContainer/Snake")
	if snake_node == null:
		status_label.text = ""
		return
	var statuses: Array = sem.get_statuses(snake_node)
	if statuses.is_empty():
		status_label.text = ""
		return
	var parts: Array = []
	for effect in statuses:
		var remaining: float = maxf(effect.duration - effect.elapsed, 0.0)
		parts.append("%s x%d (%.1fs)" % [effect.type.to_upper(), effect.layer, remaining])
	status_label.text = " | ".join(parts)


func _on_countdown_started(_data: Dictionary) -> void:
	_countdown_label.visible = true


func _on_countdown_tick(data: Dictionary) -> void:
	var remaining: float = data.get("remaining_seconds", 0.0)
	var ratio: float = data.get("ratio", 1.0)
	_countdown_label.text = "进食或死亡：%.1fs" % remaining
	# §2.1：色随剩余时间 accent_shedskin 金 → accent_danger 危险红
	var warn: Color = ConfigManager.get_palette_color("accent_shedskin")
	var danger: Color = ConfigManager.get_palette_color("accent_danger")
	_countdown_label.add_theme_color_override("font_color", danger.lerp(warn, ratio))


func _on_countdown_cancelled() -> void:
	_countdown_label.visible = false


func _toggle_pause() -> void:
	# §11.2 reason-token：手动暂停持 &"manual"，仪式 resume 不会吞掉玩家暂停
	_is_paused = not _is_paused
	if _is_paused:
		TickManager.pause(&"manual")
		_pause_label.visible = true
	else:
		TickManager.resume(&"manual")
		_pause_label.visible = false
