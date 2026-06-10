class_name RoomFlowSystem
extends Node

var _current_room: Dictionary = {}


func _ready() -> void:
	connect_events()


func _exit_tree() -> void:
	disconnect_events()


func connect_events() -> void:
	if not EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.connect(_on_enemy_killed)
	if not EventBus.room_entered.is_connected(_on_room_entered):
		EventBus.room_entered.connect(_on_room_entered)
	if not EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.connect(_on_room_completed)


func disconnect_events() -> void:
	if EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.disconnect(_on_enemy_killed)
	if EventBus.room_entered.is_connected(_on_room_entered):
		EventBus.room_entered.disconnect(_on_room_entered)
	if EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.disconnect(_on_room_completed)


func enter_room(room: Dictionary) -> void:
	_set_current_room(room)
	EventBus.room_entered.emit(_current_room.duplicate(true))


func _set_current_room(room: Dictionary) -> void:
	_current_room = room.duplicate(true)
	var objective: Dictionary = _current_room.get("objective", {})
	objective["current_count"] = int(objective.get("current_count", 0))
	objective["required_count"] = int(objective.get("required_count", 1))
	objective["complete"] = false
	_current_room["objective"] = objective
	_current_room["completed"] = false


func record_objective_progress(amount: int = 1, source_data: Dictionary = {}) -> void:
	if _current_room.is_empty() or is_current_room_complete():
		return

	var objective: Dictionary = _current_room.get("objective", {})
	var required: int = max(1, int(objective.get("required_count", 1)))
	var current: int = clampi(int(objective.get("current_count", 0)) + amount, 0, required)
	objective["current_count"] = current
	_current_room["objective"] = objective

	EventBus.room_objective_progressed.emit({
		"room_id": _current_room.get("room_id", ""),
		"room_type": _current_room.get("room_type", ""),
		"objective_type": objective.get("objective_type", ""),
		"current": current,
		"required": required,
		"source": source_data,
	})

	if current >= required:
		complete_current_room()


func complete_current_room() -> void:
	if _current_room.is_empty() or is_current_room_complete():
		return

	var objective: Dictionary = _current_room.get("objective", {})
	objective["complete"] = true
	_current_room["objective"] = objective
	_current_room["completed"] = true

	EventBus.room_completed.emit({
		"room_id": _current_room.get("room_id", ""),
		"room_type": _current_room.get("room_type", ""),
		"intent_label": _current_room.get("intent_label", ""),
		"objective": objective.duplicate(true),
		"exit_room_ids": _current_room.get("exit_room_ids", []).duplicate(),
	})


func cleanup() -> void:
	_current_room.clear()
	disconnect_events()


func get_current_room() -> Dictionary:
	return _current_room.duplicate(true)


func is_current_room_complete() -> bool:
	if _current_room.is_empty():
		return false
	return bool(_current_room.get("completed", false))


func get_objective_progress() -> Dictionary:
	if _current_room.is_empty():
		return {}
	var objective: Dictionary = _current_room.get("objective", {})
	return {
		"current": int(objective.get("current_count", 0)),
		"required": int(objective.get("required_count", 1)),
		"complete": bool(objective.get("complete", false)),
	}


func _on_enemy_killed(data: Dictionary) -> void:
	if _current_room.is_empty() or is_current_room_complete():
		return
	var objective: Dictionary = _current_room.get("objective", {})
	if objective.get("objective_type", "") != "clear_enemies":
		return
	record_objective_progress(1, data)


func _on_room_entered(data: Dictionary) -> void:
	_set_current_room(data)
	_complete_on_enter_if_configured()


func _on_room_completed(data: Dictionary) -> void:
	if _current_room.is_empty() or data.get("room_id", "") != _current_room.get("room_id", ""):
		return
	var objective: Dictionary = _current_room.get("objective", {})
	var completed_objective: Dictionary = data.get("objective", {})
	if completed_objective is Dictionary and not completed_objective.is_empty():
		objective = completed_objective.duplicate(true)
	objective["complete"] = true
	objective["current_count"] = int(objective.get("required_count", 1))
	_current_room["objective"] = objective
	_current_room["completed"] = true


func _complete_on_enter_if_configured() -> void:
	if _current_room.is_empty() or is_current_room_complete():
		return
	if not bool(_current_room.get("auto_complete_on_enter", false)):
		return
	var objective: Dictionary = _current_room.get("objective", {})
	var required: int = max(1, int(objective.get("required_count", 1)))
	record_objective_progress(required, {"method": "auto_complete_on_enter"})
