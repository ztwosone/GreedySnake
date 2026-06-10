class_name PickupSystem
extends Node

var _active_pickups: Array = []


func _ready() -> void:
	connect_events()


func connect_events() -> void:
	if not EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.connect(_on_enemy_killed)
	if not EventBus.floor_completed.is_connected(_on_floor_completed):
		EventBus.floor_completed.connect(_on_floor_completed)


func disconnect_events() -> void:
	if EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.disconnect(_on_enemy_killed)
	if EventBus.floor_completed.is_connected(_on_floor_completed):
		EventBus.floor_completed.disconnect(_on_floor_completed)


func try_drop_pickup(enemy_type: String, position: Vector2i) -> String:
	var cfg: Dictionary = ConfigManager.get_event_pickups_config()
	if not cfg.get("enabled", false):
		return ""

	var drop_chance: float = float(cfg.get("drop_chance", 0.5))
	if randf() > drop_chance:
		return ""

	if enemy_type != "elite":
		return ""

	var pickups_cfg: Dictionary = cfg.get("pickups", {})
	var pickup_ids: Array = pickups_cfg.keys()
	if pickup_ids.size() == 0:
		return ""

	var pickup_id: String = pickup_ids[randi() % pickup_ids.size()]
	var pickup: Dictionary = pickups_cfg.get(pickup_id, {})
	if not pickup.get("enabled", false):
		return ""

	_active_pickups.append({
		"pickup_id": pickup_id,
		"display_name": pickup.get("display_name", ""),
		"description": pickup.get("description", ""),
		"position": position,
		"duration_rooms": int(pickup.get("duration_rooms", 2)),
		"rooms_remaining": int(pickup.get("duration_rooms", 2)),
		"active": false,
	})

	EventBus.pickup_dropped.emit({
		"pickup_id": pickup_id,
		"position": position,
		"display_name": pickup.get("display_name", ""),
	})
	return pickup_id


func activate_pickup(pickup_id: String) -> bool:
	for pickup in _active_pickups:
		if pickup.get("pickup_id", "") == pickup_id and not bool(pickup.get("active", false)):
			pickup["active"] = true
			EventBus.pickup_activated.emit({"pickup_id": pickup_id})
			return true
	return false


func get_active_pickups() -> Array:
	return _active_pickups.duplicate()


func has_pickup(pickup_id: String) -> bool:
	for pickup in _active_pickups:
		if pickup.get("pickup_id", "") == pickup_id:
			return true
	return false


func cleanup() -> void:
	_active_pickups.clear()
	disconnect_events()


func _on_enemy_killed(data: Dictionary) -> void:
	var enemy_def = data.get("enemy_def")
	var enemy_type: String = ""
	if enemy_def is Dictionary:
		enemy_type = enemy_def.get("enemy_type", "")
	elif enemy_def is String:
		enemy_type = enemy_def
	var position: Vector2i = data.get("position", Vector2i.ZERO)
	try_drop_pickup(enemy_type, position)


func _on_floor_completed(data: Dictionary) -> void:
	_active_pickups.clear()