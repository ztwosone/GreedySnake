class_name RewardChoicePanel
extends PanelContainer

var _reward_flow: Node = null
var _title_label: Label
var _status_label: Label
var _options_box: VBoxContainer
var _options: Array = []
var _status_text: String = ""


func _ready() -> void:
	_build_ui()
	_connect_events()
	visible = false


func _exit_tree() -> void:
	_disconnect_events()


func setup(reward_flow: Node) -> void:
	_reward_flow = reward_flow


func get_visible_option_count() -> int:
	return _options.size()


func get_option_labels() -> Array:
	var labels: Array = []
	for option in _options:
		if option is Dictionary:
			labels.append(option.get("display_name", option.get("option_id", "")))
	return labels


func get_status_text() -> String:
	return _status_text


func choose_option_by_index(index: int) -> bool:
	if index < 0 or index >= _options.size() or _reward_flow == null:
		return false
	var option: Dictionary = _options[index]
	return _reward_flow.choose_reward(option.get("option_id", ""))


func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.04, 0.035, 0.9)
	style.border_color = Color(1.0, 0.82, 0.36, 0.45)
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)

	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -300
	offset_right = -12
	offset_top = 172
	offset_bottom = 360
	mouse_filter = Control.MOUSE_FILTER_STOP

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)

	_title_label = Label.new()
	_title_label.text = "选择奖励"
	_title_label.add_theme_font_size_override("font_size", 18)
	column.add_child(_title_label)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 13)
	column.add_child(_status_label)

	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 4)
	column.add_child(_options_box)


func _connect_events() -> void:
	if not EventBus.reward_presented.is_connected(_on_reward_presented):
		EventBus.reward_presented.connect(_on_reward_presented)
	if not EventBus.reward_chosen.is_connected(_on_reward_chosen):
		EventBus.reward_chosen.connect(_on_reward_chosen)


func _disconnect_events() -> void:
	if EventBus.reward_presented.is_connected(_on_reward_presented):
		EventBus.reward_presented.disconnect(_on_reward_presented)
	if EventBus.reward_chosen.is_connected(_on_reward_chosen):
		EventBus.reward_chosen.disconnect(_on_reward_chosen)


func _on_reward_presented(data: Dictionary) -> void:
	_options = data.get("options", []).duplicate(true)
	_status_text = "选择 1 个"
	_refresh()
	visible = true


func _on_reward_chosen(data: Dictionary) -> void:
	var option: Dictionary = data.get("option", {})
	_status_text = "已选择: %s" % option.get("display_name", data.get("chosen_option_id", ""))
	_options.clear()
	_refresh()


func _refresh() -> void:
	if _status_label:
		_status_label.text = _status_text
	if _options_box == null:
		return

	for child in _options_box.get_children():
		child.queue_free()

	for index in range(_options.size()):
		var option: Dictionary = _options[index]
		_options_box.add_child(_make_option_row(option, index))


func _make_option_row(option: Dictionary, index: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(16, 28)
	swatch.color = Color.html(option.get("placeholder_color", "#FFFFFF"))
	row.add_child(swatch)

	var button := Button.new()
	button.text = option.get("display_name", option.get("option_id", ""))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(Callable(self, "_on_option_pressed").bind(index))
	row.add_child(button)

	return row


func _on_option_pressed(index: int) -> void:
	choose_option_by_index(index)
