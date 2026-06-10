class_name ScaleChoicePanel
extends PanelContainer

var _scale_reward_system: Node = null
var _title_label: Label
var _options_box: VBoxContainer
var _options: Array = []
var _status_text: String = ""


func _ready() -> void:
	_build_ui()
	_connect_events()
	visible = false


func _exit_tree() -> void:
	_disconnect_events()


func setup(system: Node) -> void:
	_scale_reward_system = system


func get_visible_option_count() -> int:
	return _options.size()


func get_option_labels() -> Array:
	var labels: Array = []
	for option in _options:
		if option is Dictionary:
			labels.append(option.get("display_name", ""))
	return labels


func get_status_text() -> String:
	return _status_text


func choose_option_by_index(index: int) -> bool:
	if _scale_reward_system == null:
		return false
	return _scale_reward_system.choose_scale(index)


func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.06, 0.9)
	style.border_color = Color(0.42, 0.78, 1.0, 0.4)
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)

	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -200
	offset_right = 200
	offset_top = 100
	offset_bottom = 320
	mouse_filter = Control.MOUSE_FILTER_STOP

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)

	_title_label = Label.new()
	_title_label.text = "选择鳞片"
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title_label)

	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 4)
	column.add_child(_options_box)


func _connect_events() -> void:
	if not EventBus.scale_reward_presented.is_connected(_on_scale_reward_presented):
		EventBus.scale_reward_presented.connect(_on_scale_reward_presented)
	if not EventBus.scale_reward_chosen.is_connected(_on_scale_reward_chosen):
		EventBus.scale_reward_chosen.connect(_on_scale_reward_chosen)
	if not EventBus.game_over.is_connected(_on_game_over):
		EventBus.game_over.connect(_on_game_over)


func _disconnect_events() -> void:
	if EventBus.scale_reward_presented.is_connected(_on_scale_reward_presented):
		EventBus.scale_reward_presented.disconnect(_on_scale_reward_presented)
	if EventBus.scale_reward_chosen.is_connected(_on_scale_reward_chosen):
		EventBus.scale_reward_chosen.disconnect(_on_scale_reward_chosen)
	if EventBus.game_over.is_connected(_on_game_over):
		EventBus.game_over.disconnect(_on_game_over)


func _on_scale_reward_presented(data: Dictionary) -> void:
	_options = data.get("options", []).duplicate(true)
	_status_text = "选择 1 个鳞片"
	_refresh()
	visible = true


func _on_scale_reward_chosen(data: Dictionary) -> void:
	_status_text = "已选择: %s" % data.get("scale_id", "")
	_options.clear()
	_refresh()
	visible = false


func _on_game_over(data: Dictionary) -> void:
	_options.clear()
	visible = false


func _refresh() -> void:
	if _options_box == null:
		return
	for child in _options_box.get_children():
		child.queue_free()
	for index in range(_options.size()):
		_options_box.add_child(_make_option_row(_options[index], index))


func _make_option_row(option: Dictionary, index: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(20, 36)
	swatch.color = Color.html(option.get("placeholder_color", "#FFFFFF"))
	row.add_child(swatch)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)

	var name_label := Label.new()
	name_label.text = option.get("display_name", "")
	name_label.add_theme_font_size_override("font_size", 15)
	info.add_child(name_label)

	var slot_label := Label.new()
	slot_label.text = "位置: %s Lv.%d" % [_slot_name(option.get("target_slot", "")), int(option.get("level", 1))]
	slot_label.add_theme_font_size_override("font_size", 12)
	slot_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info.add_child(slot_label)

	row.add_child(info)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var button := Button.new()
	button.text = "选择"
	button.pressed.connect(Callable(self, "_on_option_pressed").bind(index))
	row.add_child(button)

	return row


func _slot_name(slot: String) -> String:
	match slot:
		"front": return "前段"
		"middle": return "中段"
		"back": return "后段"
	return slot


func _on_option_pressed(index: int) -> void:
	choose_option_by_index(index)