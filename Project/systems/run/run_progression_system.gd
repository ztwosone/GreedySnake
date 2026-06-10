class_name RunProgressionSystem
extends Node

const FloorMapGeneratorScript = preload("res://systems/rooms/floor_map_generator.gd")

var current_run_state: Dictionary = {}
var current_floor_map: Dictionary = {}

var _generator = FloorMapGeneratorScript.new()

## FR-015 模态门控（spec 002 T007）：任一 *_presented 未决时忽略推进请求。
## 按 offer 家族登记（reward / scale_reward / floor_reward），各 offer 系统单 offer 在飞，
## 家族键足够；shop 进出流由 T014 卡接入。
var _pending_offers: Dictionary = {}


func _ready() -> void:
	connect_events()


func _exit_tree() -> void:
	disconnect_events()


func connect_events() -> void:
	if not EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.connect(_on_room_completed)
	if not EventBus.snake_died.is_connected(_on_snake_died):
		EventBus.snake_died.connect(_on_snake_died)
	if not EventBus.room_advance_requested.is_connected(_on_room_advance_requested):
		EventBus.room_advance_requested.connect(_on_room_advance_requested)
	if not EventBus.reward_presented.is_connected(_on_reward_presented):
		EventBus.reward_presented.connect(_on_reward_presented)
	if not EventBus.reward_chosen.is_connected(_on_reward_chosen):
		EventBus.reward_chosen.connect(_on_reward_chosen)
	if not EventBus.scale_reward_presented.is_connected(_on_scale_reward_presented):
		EventBus.scale_reward_presented.connect(_on_scale_reward_presented)
	if not EventBus.scale_reward_chosen.is_connected(_on_scale_reward_chosen):
		EventBus.scale_reward_chosen.connect(_on_scale_reward_chosen)
	if not EventBus.scale_option_discarded.is_connected(_on_scale_option_discarded):
		EventBus.scale_option_discarded.connect(_on_scale_option_discarded)
	if not EventBus.floor_reward_presented.is_connected(_on_floor_reward_presented):
		EventBus.floor_reward_presented.connect(_on_floor_reward_presented)
	if not EventBus.floor_reward_chosen.is_connected(_on_floor_reward_chosen):
		EventBus.floor_reward_chosen.connect(_on_floor_reward_chosen)


func disconnect_events() -> void:
	if EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.disconnect(_on_room_completed)
	if EventBus.snake_died.is_connected(_on_snake_died):
		EventBus.snake_died.disconnect(_on_snake_died)
	if EventBus.room_advance_requested.is_connected(_on_room_advance_requested):
		EventBus.room_advance_requested.disconnect(_on_room_advance_requested)
	if EventBus.reward_presented.is_connected(_on_reward_presented):
		EventBus.reward_presented.disconnect(_on_reward_presented)
	if EventBus.reward_chosen.is_connected(_on_reward_chosen):
		EventBus.reward_chosen.disconnect(_on_reward_chosen)
	if EventBus.scale_reward_presented.is_connected(_on_scale_reward_presented):
		EventBus.scale_reward_presented.disconnect(_on_scale_reward_presented)
	if EventBus.scale_reward_chosen.is_connected(_on_scale_reward_chosen):
		EventBus.scale_reward_chosen.disconnect(_on_scale_reward_chosen)
	if EventBus.scale_option_discarded.is_connected(_on_scale_option_discarded):
		EventBus.scale_option_discarded.disconnect(_on_scale_option_discarded)
	if EventBus.floor_reward_presented.is_connected(_on_floor_reward_presented):
		EventBus.floor_reward_presented.disconnect(_on_floor_reward_presented)
	if EventBus.floor_reward_chosen.is_connected(_on_floor_reward_chosen):
		EventBus.floor_reward_chosen.disconnect(_on_floor_reward_chosen)


func start_run(seed: int = 0) -> void:
	cleanup()
	connect_events()

	var run_cfg: Dictionary = ConfigManager.get_run_config()
	var floor_cfg: Dictionary = ConfigManager.get_floor_config()
	var floor_index: int = int(run_cfg.get("start_floor", 1))
	var floor_seed: int = seed
	if floor_seed == 0:
		floor_seed = int(floor_cfg.get("default_seed", 0))

	current_floor_map = _generator.generate_floor(floor_index, floor_seed)
	var start_room_id: String = current_floor_map.get("start_room_id", "")
	current_run_state = {
		"run_id": "run_%d_%d" % [floor_index, floor_seed],
		"floor_index": floor_index,
		"current_room_id": start_room_id,
		"completed_room_ids": [],
		"available_room_ids": [start_room_id] if start_room_id != "" else [],
		"pending_reward": {},
		"outcome": "running",
	}

	EventBus.run_started.emit({
		"run_id": current_run_state.get("run_id", ""),
		"floor_index": floor_index,
		"seed": floor_seed,
	})
	EventBus.floor_generated.emit(current_floor_map.duplicate(true))


func mark_victory(endpoint_room_id: String = "") -> void:
	if current_run_state.is_empty() or current_run_state.get("outcome", "") == "victory":
		return
	current_run_state["outcome"] = "victory"
	EventBus.run_victory.emit({
		"run_id": current_run_state.get("run_id", ""),
		"floor_index": current_run_state.get("floor_index", 0),
		"endpoint_room_id": endpoint_room_id,
		"completed_room_ids": current_run_state.get("completed_room_ids", []).duplicate(),
	})


func mark_death(cause: String = "death") -> void:
	if current_run_state.is_empty() or not is_running():
		return
	current_run_state["outcome"] = "death"
	current_run_state["death_cause"] = cause


func cleanup() -> void:
	current_run_state.clear()
	current_floor_map.clear()
	_pending_offers.clear()
	disconnect_events()


## FR-015：是否有未决 offer（任一 *_presented 未配对 chosen/discarded）
func has_pending_offer() -> bool:
	return not _pending_offers.is_empty()


func is_running() -> bool:
	return current_run_state.get("outcome", "") == "running"


func get_state() -> Dictionary:
	return current_run_state.duplicate(true)


func get_floor_map() -> Dictionary:
	return current_floor_map.duplicate(true)


func get_current_room() -> Dictionary:
	var current_room_id: String = current_run_state.get("current_room_id", "")
	for room in current_floor_map.get("rooms", []):
		if room is Dictionary and room.get("room_id", "") == current_room_id:
			return room.duplicate(true)
	return {}


func get_available_room_ids() -> Array:
	return current_run_state.get("available_room_ids", []).duplicate()


func advance_to_room(room_id: String) -> bool:
	if current_run_state.is_empty():
		return false
	var available: Array = current_run_state.get("available_room_ids", [])
	var completed: Array = current_run_state.get("completed_room_ids", [])
	if not available.has(room_id) or completed.has(room_id):
		return false

	current_run_state["current_room_id"] = room_id
	var room: Dictionary = _get_room_by_id(room_id)
	if room.is_empty():
		return false
	EventBus.room_entered.emit(room.duplicate(true))
	return true


func get_progress_summary() -> Dictionary:
	var rooms: Array = current_floor_map.get("rooms", [])
	var current_room_id: String = current_run_state.get("current_room_id", "")
	var current_index: int = 0
	for index in range(rooms.size()):
		if rooms[index] is Dictionary and rooms[index].get("room_id", "") == current_room_id:
			current_index = index + 1
			break
	return {
		"current_index": current_index,
		"total_rooms": rooms.size(),
		"current_room_id": current_room_id,
		"completed_room_ids": current_run_state.get("completed_room_ids", []).duplicate(),
		"available_room_ids": current_run_state.get("available_room_ids", []).duplicate(),
	}


func _on_room_completed(data: Dictionary) -> void:
	if current_run_state.is_empty() or not is_running():
		return
	var room_id: String = data.get("room_id", "")
	if room_id == "" or not _room_exists(room_id):
		return
	if room_id != current_run_state.get("current_room_id", ""):
		return
	if not current_run_state.get("available_room_ids", []).has(room_id):
		return

	var completed: Array = current_run_state.get("completed_room_ids", [])
	if not completed.has(room_id):
		completed.append(room_id)
	current_run_state["completed_room_ids"] = completed

	for room in current_floor_map.get("rooms", []):
		if not (room is Dictionary):
			continue
		if room.get("room_id", "") == room_id:
			room["completed"] = true
			room["available"] = false
		if _get_exit_ids(room_id).has(room.get("room_id", "")):
			room["available"] = true

	var available: Array = []
	for available_id in current_run_state.get("available_room_ids", []):
		if available_id != room_id and not completed.has(available_id):
			available.append(available_id)
	for next_id in _get_exit_ids(room_id):
		if not available.has(next_id):
			available.append(next_id)
	current_run_state["available_room_ids"] = available

	var completed_room: Dictionary = _get_room_by_id(room_id)
	if _is_endpoint_completion(data, completed_room):
		_emit_floor_completed(room_id)
		mark_victory(room_id)


func _get_room_by_id(room_id: String) -> Dictionary:
	for room in current_floor_map.get("rooms", []):
		if room is Dictionary and room.get("room_id", "") == room_id:
			return room
	return {}


func _room_exists(room_id: String) -> bool:
	return not _get_room_by_id(room_id).is_empty()


func _get_exit_ids(room_id: String) -> Array:
	var room: Dictionary = _get_room_by_id(room_id)
	return room.get("exit_room_ids", []).duplicate() if not room.is_empty() else []


func _is_endpoint_completion(data: Dictionary, room: Dictionary) -> bool:
	var objective: Dictionary = data.get("objective", {})
	return (
		room.get("room_type", data.get("room_type", "")) == "endpoint"
		or objective.get("objective_type", "") == "reach_endpoint"
		or room.get("room_id", "") == current_floor_map.get("endpoint_room_id", "")
	)


func _emit_floor_completed(endpoint_room_id: String) -> void:
	EventBus.floor_completed.emit({
		"run_id": current_run_state.get("run_id", ""),
		"floor_index": current_run_state.get("floor_index", 0),
		"floor_id": current_floor_map.get("floor_id", ""),
		"endpoint_room_id": endpoint_room_id,
		"completed_room_ids": current_run_state.get("completed_room_ids", []).duplicate(),
	})


func _on_snake_died(data: Dictionary) -> void:
	mark_death(data.get("cause", "unknown"))


func _set_offer_pending(family: String, pending: bool) -> void:
	if pending:
		_pending_offers[family] = true
	else:
		_pending_offers.erase(family)


func _on_reward_presented(_data: Dictionary) -> void:
	_set_offer_pending("reward", true)


func _on_reward_chosen(_data: Dictionary) -> void:
	_set_offer_pending("reward", false)


func _on_scale_reward_presented(_data: Dictionary) -> void:
	_set_offer_pending("scale_reward", true)


func _on_scale_reward_chosen(_data: Dictionary) -> void:
	_set_offer_pending("scale_reward", false)


func _on_scale_option_discarded(_data: Dictionary) -> void:
	_set_offer_pending("scale_reward", false)


func _on_floor_reward_presented(_data: Dictionary) -> void:
	_set_offer_pending("floor_reward", true)


func _on_floor_reward_chosen(_data: Dictionary) -> void:
	_set_offer_pending("floor_reward", false)


func _on_room_advance_requested(data: Dictionary) -> void:
	if has_pending_offer():
		return
	var room_id: String = data.get("room_id", "")
	if room_id == "":
		room_id = _get_first_enterable_room_id()
	if room_id != "":
		advance_to_room(room_id)


func _get_first_enterable_room_id() -> String:
	var completed: Array = current_run_state.get("completed_room_ids", [])
	var current_room_id: String = current_run_state.get("current_room_id", "")
	for room_id in current_run_state.get("available_room_ids", []):
		if room_id != current_room_id and not completed.has(room_id):
			return room_id
	return ""
