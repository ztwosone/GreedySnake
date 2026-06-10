class_name FloorProgressPanel
extends PanelContainer

var _path: Array = []
var _current_room_id: String = ""
var _completed_room_ids: Array = []
var _available_room_ids: Array = []
var _progress_text: String = ""
var _status_text: String = ""
var _progress_label: Label
var _status_label: Label
var _path_row: HBoxContainer
var _next_button: Button


func _ready() -> void:
	_build_ui()
	_connect_events()
	visible = false


func _exit_tree() -> void:
	_disconnect_events()


func get_progress_text() -> String:
	return _progress_text


func get_status_text() -> String:
	return _status_text


func request_next_room() -> bool:
	var room_id: String = _get_next_available_room_id()
	if room_id == "":
		return false
	EventBus.room_advance_requested.emit({"room_id": room_id})
	return true


func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.055, 0.86)
	style.border_color = Color(0.42, 0.78, 1.0, 0.35)
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)

	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = 16
	offset_right = 300
	offset_top = 124
	offset_bottom = 240
	mouse_filter = Control.MOUSE_FILTER_STOP

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)

	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 16)
	column.add_child(_progress_label)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 13)
	column.add_child(_status_label)

	_path_row = HBoxContainer.new()
	_path_row.add_theme_constant_override("separation", 4)
	column.add_child(_path_row)

	_next_button = Button.new()
	_next_button.text = "Next"
	_next_button.disabled = true
	_next_button.pressed.connect(_on_next_pressed)
	column.add_child(_next_button)


func _connect_events() -> void:
	if not EventBus.floor_generated.is_connected(_on_floor_generated):
		EventBus.floor_generated.connect(_on_floor_generated)
	if not EventBus.room_entered.is_connected(_on_room_entered):
		EventBus.room_entered.connect(_on_room_entered)
	if not EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.connect(_on_room_completed)


func _disconnect_events() -> void:
	if EventBus.floor_generated.is_connected(_on_floor_generated):
		EventBus.floor_generated.disconnect(_on_floor_generated)
	if EventBus.room_entered.is_connected(_on_room_entered):
		EventBus.room_entered.disconnect(_on_room_entered)
	if EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.disconnect(_on_room_completed)


func _on_floor_generated(data: Dictionary) -> void:
	_path.clear()
	for room in data.get("rooms", []):
		if room is Dictionary:
			_path.append(room.duplicate(true))
	_current_room_id = data.get("start_room_id", "")
	_completed_room_ids.clear()
	_available_room_ids = [_current_room_id] if _current_room_id != "" else []
	_status_text = "当前房间"
	_refresh()
	visible = true


func _on_room_entered(data: Dictionary) -> void:
	_current_room_id = data.get("room_id", _current_room_id)
	_available_room_ids.erase(_current_room_id)
	_status_text = data.get("intent_label", data.get("room_type", ""))
	_refresh()


func _on_room_completed(data: Dictionary) -> void:
	var room_id: String = data.get("room_id", "")
	if room_id != "" and not _completed_room_ids.has(room_id):
		_completed_room_ids.append(room_id)
	_available_room_ids.erase(room_id)
	for exit_id in _get_exit_ids(room_id):
		if not _available_room_ids.has(exit_id):
			_available_room_ids.append(exit_id)
	_status_text = "房间完成，可进入下一房间" if _get_exit_ids(room_id).size() > 0 else "房间完成"
	_refresh()


func _refresh() -> void:
	var current_index: int = 0
	for index in range(_path.size()):
		if _path[index].get("room_id", "") == _current_room_id:
			current_index = index + 1
			break
	var total: int = _path.size()
	_progress_text = "%d/%d" % [current_index, total]
	if _progress_label:
		_progress_label.text = _progress_text
	if _status_label:
		_status_label.text = _status_text
	_refresh_path_row()
	_refresh_next_button()


func _refresh_path_row() -> void:
	if _path_row == null:
		return
	for child in _path_row.get_children():
		_path_row.remove_child(child)
		child.free()
	for room in _path:
		var block := ColorRect.new()
		block.custom_minimum_size = Vector2(28, 10)
		var base_color := Color.html(room.get("placeholder_color", "#FFFFFF"))
		if _completed_room_ids.has(room.get("room_id", "")):
			block.color = base_color.darkened(0.45)
		elif room.get("room_id", "") == _current_room_id:
			block.color = base_color
		elif _available_room_ids.has(room.get("room_id", "")):
			block.color = base_color.lightened(0.2)
		else:
			block.color = base_color.darkened(0.72)
		_path_row.add_child(block)


func _refresh_next_button() -> void:
	if _next_button == null:
		return
	var room_id: String = _get_next_available_room_id()
	_next_button.disabled = room_id == ""


func _get_exit_ids(room_id: String) -> Array:
	for room in _path:
		if room is Dictionary and room.get("room_id", "") == room_id:
			return room.get("exit_room_ids", []).duplicate()
	return []


func _get_next_available_room_id() -> String:
	for room_id in _available_room_ids:
		if room_id != _current_room_id and not _completed_room_ids.has(room_id):
			return room_id
	return ""


func _on_next_pressed() -> void:
	request_next_room()
