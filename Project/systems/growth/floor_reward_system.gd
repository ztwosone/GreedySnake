class_name FloorRewardSystem
extends Node

var _scale_slot_mgr: Node = null
var _snake_parts_mgr: Node = null
var _current_offer: Dictionary = {}


func _ready() -> void:
	connect_events()


func _exit_tree() -> void:
	disconnect_events()


func setup(scale_mgr: Node, parts_mgr: Node) -> void:
	_scale_slot_mgr = scale_mgr
	_snake_parts_mgr = parts_mgr


func connect_events() -> void:
	if not EventBus.floor_completed.is_connected(_on_floor_completed):
		EventBus.floor_completed.connect(_on_floor_completed)


func disconnect_events() -> void:
	if EventBus.floor_completed.is_connected(_on_floor_completed):
		EventBus.floor_completed.disconnect(_on_floor_completed)


func present_floor_reward(floor_index: int, source_room_id: String) -> Dictionary:
	if has_pending_offer():
		return _current_offer.duplicate(true)

	var cfg: Dictionary = ConfigManager.get_floor_reward_config()
	var categories: Array = cfg.get("categories", [])

	var options: Array = []
	for category in categories:
		options.append(_make_category_option(category))

	_current_offer = {
		"reward_id": "floor_reward_%d" % floor_index,
		"floor_index": floor_index,
		"source_room_id": source_room_id,
		"options": options,
		"chosen_index": -1,
		"complete": false,
	}

	EventBus.floor_reward_presented.emit(_current_offer.duplicate(true))
	return _current_offer.duplicate(true)


func choose_floor_reward(index: int) -> bool:
	if _current_offer.is_empty() or bool(_current_offer.get("complete", false)):
		return false

	var options: Array = _current_offer.get("options", [])
	if index < 0 or index >= options.size():
		return false

	var option: Dictionary = options[index]
	_current_offer["chosen_index"] = index
	_current_offer["complete"] = true

	EventBus.floor_reward_chosen.emit({
		"reward_id": _current_offer.get("reward_id", ""),
		"floor_index": _current_offer.get("floor_index", 0),
		"category": option.get("category", ""),
		"option_id": option.get("option_id", ""),
	})

	_apply_floor_reward(option)
	_current_offer.clear()
	return true


func has_pending_offer() -> bool:
	return not _current_offer.is_empty() and not bool(_current_offer.get("complete", false))


func get_current_offer() -> Dictionary:
	return _current_offer.duplicate(true)


func cleanup() -> void:
	_current_offer.clear()
	disconnect_events()


func _make_category_option(category: String) -> Dictionary:
	var cfg: Dictionary = ConfigManager.get_floor_reward_config()
	var cat_cfg: Dictionary = cfg.get(category, {})
	return {
		"option_id": "%s_%d" % [category, randi()],
		"category": category,
		"reward_type": category,
		"target_id": "",
		"display_name": cat_cfg.get("display_name", category),
		"description": cat_cfg.get("description", ""),
		"placeholder_color": _color_for_category(category),
	}


func _apply_floor_reward(option: Dictionary) -> void:
	var category: String = option.get("category", "")
	match category:
		"expansion":
			if _scale_slot_mgr != null:
				_scale_slot_mgr.equip_scale("middle", "flame_scale", 2)
		"reinforcement":
			if _snake_parts_mgr != null and _snake_parts_mgr.has_head():
				_snake_parts_mgr.upgrade_head()
		"correction":
			pass


func _color_for_category(category: String) -> String:
	match category:
		"expansion": return "#FF7043"
		"reinforcement": return "#42A5F5"
		"correction": return "#66BB6A"
	return "#FFFFFF"


func _on_floor_completed(data: Dictionary) -> void:
	var floor_index: int = int(data.get("floor_index", 1))
	present_floor_reward(floor_index, data.get("endpoint_room_id", ""))