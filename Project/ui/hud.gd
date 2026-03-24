extends Control

const _HealthBarScript = preload("res://ui/health_bar.gd")
const _HitCounterScript = preload("res://ui/hit_counter.gd")
const _TickPulseScript = preload("res://ui/tick_pulse.gd")

@onready var length_label: Label = $LengthLabel
@onready var status_label: Label = $StatusLabel
var _pause_label: Label
var _countdown_label: Label
var _health_bar: Node
var _hit_counter: Node
var _tick_pulse: Node
var _is_paused: bool = false


func _ready() -> void:
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

	# 蛇段长度条（紧跟在 LengthLabel 下方）
	_health_bar = _HealthBarScript.new()
	_health_bar.position = Vector2(16, 56)
	add_child(_health_bar)

	# 受击计数器（长度条右侧）
	_hit_counter = _HitCounterScript.new()
	_hit_counter.position = Vector2(220, 56)
	add_child(_hit_counter)

	# Tick 脉搏线
	_tick_pulse = _TickPulseScript.new()
	add_child(_tick_pulse)

	# 暂停提示标签
	_pause_label = Label.new()
	_pause_label.text = "PAUSED"
	_pause_label.add_theme_font_size_override("font_size", 48)
	_pause_label.add_theme_color_override("font_color", Color(1, 1, 0))
	_pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pause_label.set_anchors_preset(PRESET_CENTER)
	_pause_label.visible = false
	add_child(_pause_label)

	# 无身体倒计时标签
	_countdown_label = Label.new()
	_countdown_label.add_theme_font_size_override("font_size", 32)
	_countdown_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.set_anchors_preset(PRESET_CENTER_TOP)
	_countdown_label.position.y = 40
	_countdown_label.visible = false
	add_child(_countdown_label)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()


func _update_length(data: Dictionary) -> void:
	length_label.text = "Length: %d" % data.get("new_length", 0)


func _on_game_started() -> void:
	length_label.text = "Length: %d" % Constants.INITIAL_SNAKE_LENGTH
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
	_countdown_label.text = "EAT OR DIE: %.1fs" % remaining
	# 颜色从黄→红
	_countdown_label.add_theme_color_override("font_color", Color(1.0, lerpf(0.1, 0.9, ratio), 0.1))


func _on_countdown_cancelled() -> void:
	_countdown_label.visible = false


func _toggle_pause() -> void:
	_is_paused = not _is_paused
	if _is_paused:
		TickManager.pause()
		_pause_label.visible = true
	else:
		TickManager.resume()
		_pause_label.visible = false
