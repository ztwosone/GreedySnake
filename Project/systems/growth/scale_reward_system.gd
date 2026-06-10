class_name ScaleRewardSystem
extends Node

var _scale_slot_mgr: Node = null
var _scale_reward_panel: Control = null
var _current_offer: Dictionary = {}


func _ready() -> void:
	connect_events()


func _exit_tree() -> void:
	disconnect_events()


func setup(scale_mgr: Node, panel: Control) -> void:
	_scale_slot_mgr = scale_mgr
	_scale_reward_panel = panel


func connect_events() -> void:
	if not EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.connect(_on_room_completed)


func disconnect_events() -> void:
	if EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.disconnect(_on_room_completed)


func present_offer(source_room: Dictionary, pool_id: String = "l1_basic") -> Dictionary:
	if has_pending_offer():
		return _current_offer.duplicate(true)

	var cfg: Dictionary = ConfigManager.get_scale_reward_config()
	var offer_count: int = min(3, int(cfg.get("offer_count", 3)))
	var pool: Array = ConfigManager.get_scale_reward_pool(pool_id)
	var options: Array = _pick_random_options(pool, offer_count)

	_current_offer = {
		"offer_id": "scale_%s" % source_room.get("room_id", "manual"),
		"source_room_id": source_room.get("room_id", ""),
		"source_room_type": source_room.get("room_type", ""),
		"pool_id": pool_id,
		"options": options,
		"chosen_index": -1,
		"complete": false,
	}

	EventBus.scale_reward_presented.emit(_current_offer.duplicate(true))
	return _current_offer.duplicate(true)


func choose_scale(index: int) -> bool:
	if _current_offer.is_empty() or bool(_current_offer.get("complete", false)):
		return false
	if _scale_slot_mgr == null:
		return false

	var options: Array = _current_offer.get("options", [])
	if index < 0 or index >= options.size():
		return false

	var option: Dictionary = options[index]
	var scale_id: String = option.get("target_id", "")
	var slot: String = option.get("target_slot", "middle")
	var level: int = _get_reward_level(option)

	var success: bool = _scale_slot_mgr.equip_scale(slot, scale_id, level)
	if not success:
		return false

	_current_offer["chosen_index"] = index
	_current_offer["complete"] = true

	EventBus.scale_reward_chosen.emit({
		"offer_id": _current_offer.get("offer_id", ""),
		"option_id": option.get("option_id", ""),
		"scale_id": scale_id,
		"position": slot,
		"level": level,
	})

	EventBus.room_completed.emit({
		"room_id": _current_offer.get("source_room_id", ""),
		"room_type": _current_offer.get("source_room_type", ""),
		"intent_label": "获得鳞片",
		"objective": {
			"objective_type": "claim_scale_reward",
			"required_count": 1,
			"current_count": 1,
			"complete": true,
		},
		"exit_room_ids": [],
	})

	_current_offer.clear()
	return true


func has_pending_offer() -> bool:
	return not _current_offer.is_empty() and not bool(_current_offer.get("complete", false))


func get_current_offer() -> Dictionary:
	return _current_offer.duplicate(true)


func cleanup() -> void:
	_current_offer.clear()
	disconnect_events()


func _pick_random_options(pool: Array, count: int) -> Array:
	var available: Array = pool.duplicate()
	available.shuffle()
	var result: Array = []
	for i in range(min(count, available.size())):
		result.append(available[i].duplicate(true))
	return result


func _get_reward_level(option: Dictionary) -> int:
	return max(1, int(option.get("level", 1)) + int(option.get("level_delta", 0)))


func _on_room_completed(data: Dictionary) -> void:
	if has_pending_offer():
		return
	var cfg: Dictionary = ConfigManager.get_scale_reward_config()
	var trigger_types: Array = cfg.get("trigger_room_types", [])
	if not trigger_types.has(data.get("room_type", "")):
		return
	present_offer(data)