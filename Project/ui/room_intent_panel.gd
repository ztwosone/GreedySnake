class_name RoomIntentPanel
extends PanelContainer

var _color_block: ColorRect
var _intent_label: Label
var _progress_label: Label
var _status_label: Label
var _current_room_id: String = ""
var _intent_text: String = ""
var _progress_text: String = ""
var _status_text: String = ""
var _placeholder_color: Color = Color.WHITE


func _ready() -> void:
	_build_ui()
	_connect_events()
	visible = false


func _exit_tree() -> void:
	_disconnect_events()


func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.045, 0.05, 0.82)
	style.border_color = Color(1, 1, 1, 0.16)
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)

	set_anchors_preset(Control.PRESET_TOP_WIDE)
	offset_left = 320
	offset_right = -320
	offset_top = 12
	offset_bottom = 76
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)

	_color_block = ColorRect.new()
	_color_block.custom_minimum_size = Vector2(18, 40)
	row.add_child(_color_block)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	row.add_child(column)

	_intent_label = Label.new()
	_intent_label.add_theme_font_size_override("font_size", 18)
	column.add_child(_intent_label)

	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 14)
	column.add_child(_progress_label)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 13)
	column.add_child(_status_label)


func _connect_events() -> void:
	if not EventBus.room_entered.is_connected(_on_room_entered):
		EventBus.room_entered.connect(_on_room_entered)
	if not EventBus.room_objective_progressed.is_connected(_on_room_objective_progressed):
		EventBus.room_objective_progressed.connect(_on_room_objective_progressed)
	if not EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.connect(_on_room_completed)


func _disconnect_events() -> void:
	if EventBus.room_entered.is_connected(_on_room_entered):
		EventBus.room_entered.disconnect(_on_room_entered)
	if EventBus.room_objective_progressed.is_connected(_on_room_objective_progressed):
		EventBus.room_objective_progressed.disconnect(_on_room_objective_progressed)
	if EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.disconnect(_on_room_completed)


func get_intent_text() -> String:
	return _intent_text


func get_progress_text() -> String:
	return _progress_text


func get_status_text() -> String:
	return _status_text


func get_placeholder_color() -> Color:
	return _placeholder_color


func _on_room_entered(data: Dictionary) -> void:
	_current_room_id = data.get("room_id", "")
	_intent_text = data.get("intent_label", data.get("room_type", ""))
	_status_text = "进行中"

	var objective: Dictionary = data.get("objective", {})
	var current: int = int(objective.get("current_count", 0))
	var required: int = int(objective.get("required_count", 1))
	_progress_text = "%d/%d" % [current, required]

	var color_text: String = data.get("placeholder_color", "#FFFFFF")
	_placeholder_color = Color.html(color_text)
	_refresh()
	visible = true


func _on_room_objective_progressed(data: Dictionary) -> void:
	if data.get("room_id", "") != _current_room_id:
		return
	_progress_text = "%d/%d" % [int(data.get("current", 0)), int(data.get("required", 1))]
	_status_text = "进行中"
	_refresh()


func _on_room_completed(data: Dictionary) -> void:
	if data.get("room_id", "") != _current_room_id:
		return
	_status_text = "完成"
	_refresh()


func _refresh() -> void:
	if _color_block:
		_color_block.color = _placeholder_color
	if _intent_label:
		_intent_label.text = _intent_text
	if _progress_label:
		_progress_label.text = _progress_text
	if _status_label:
		_status_label.text = _status_text
