class_name FloorRewardPanel
extends PanelContainer

var _floor_reward_system: Node = null
var _title_label: Label
var _options_box: VBoxContainer
var _options: Array = []


func _ready() -> void:
	_build_ui()
	_connect_events()
	visible = false


func setup(system: Node) -> void:
	_floor_reward_system = system


func get_visible_option_count() -> int:
	return _options.size()


func choose_by_index(index: int) -> bool:
	if _floor_reward_system == null:
		return false
	return _floor_reward_system.choose_floor_reward(index)


func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.08, 0.92)
	style.border_color = Color(0.8, 0.6, 1.0, 0.5)
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)

	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -220
	offset_right = 220
	offset_top = 60
	offset_bottom = 300
	mouse_filter = Control.MOUSE_FILTER_STOP

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)

	_title_label = Label.new()
	_title_label.text = "楼层奖励"
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title_label)

	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 4)
	column.add_child(_options_box)


func _connect_events() -> void:
	if not EventBus.floor_reward_presented.is_connected(_on_reward_presented):
		EventBus.floor_reward_presented.connect(_on_reward_presented)
	if not EventBus.floor_reward_chosen.is_connected(_on_reward_chosen):
		EventBus.floor_reward_chosen.connect(_on_reward_chosen)
	if not EventBus.game_over.is_connected(_on_game_over):
		EventBus.game_over.connect(_on_game_over)


func _on_reward_presented(data: Dictionary) -> void:
	_options = data.get("options", []).duplicate(true)
	_title_label.text = "楼层 %d 奖励" % int(data.get("floor_index", 1))
	_refresh()
	visible = true


func _on_reward_chosen(data: Dictionary) -> void:
	_options.clear()
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

	var desc_label := Label.new()
	desc_label.text = option.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info.add_child(desc_label)

	row.add_child(info)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var button := Button.new()
	button.text = "选择"
	button.pressed.connect(Callable(self, "_on_option_pressed").bind(index))
	row.add_child(button)

	return row


func _on_option_pressed(index: int) -> void:
	choose_by_index(index)