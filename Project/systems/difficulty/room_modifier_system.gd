class_name RoomModifierSystem
extends Node

var _active_modifiers: Array = []


func _ready() -> void:
	connect_events()


func _exit_tree() -> void:
	disconnect_events()


func connect_events() -> void:
	if not EventBus.room_entered.is_connected(_on_room_entered):
		EventBus.room_entered.connect(_on_room_entered)
	if not EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.connect(_on_room_completed)


func disconnect_events() -> void:
	if EventBus.room_entered.is_connected(_on_room_entered):
		EventBus.room_entered.disconnect(_on_room_entered)
	if EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.disconnect(_on_room_completed)


func apply_modifier(modifier_id: String, room_id: String) -> bool:
	var mod: Dictionary = ConfigManager.get_room_modifier(modifier_id)
	if mod.is_empty() or not bool(mod.get("enabled", false)):
		return false

	_active_modifiers.append({
		"modifier_id": modifier_id,
		"room_id": room_id,
		"config": mod.duplicate(true),
	})

	EventBus.room_modifier_applied.emit({
		"room_id": room_id,
		"modifier_id": modifier_id,
	})
	return true


func remove_modifiers(room_id: String) -> void:
	var to_remove: Array = []
	for mod in _active_modifiers:
		if mod.get("room_id", "") == room_id:
			to_remove.append(mod)
	for mod in to_remove:
		_active_modifiers.erase(mod)


func get_active_modifiers() -> Array:
	return _active_modifiers.duplicate()


func has_modifier(room_id: String, modifier_id: String) -> bool:
	for mod in _active_modifiers:
		if mod.get("room_id", "") == room_id and mod.get("modifier_id", "") == modifier_id:
			return true
	return false


func cleanup() -> void:
	_active_modifiers.clear()
	disconnect_events()


func _on_room_entered(data: Dictionary) -> void:
	var room_id: String = data.get("room_id", "")
	if room_id == "":
		return


func _on_room_completed(data: Dictionary) -> void:
	remove_modifiers(data.get("room_id", ""))