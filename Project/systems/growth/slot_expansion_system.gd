class_name SlotExpansionSystem
extends Node

var _slots_front: int = 1
var _slots_middle: int = 1
var _slots_back: int = 1
var _unlock_history: Array = []


func _ready() -> void:
	connect_events()


func _exit_tree() -> void:
	disconnect_events()


func connect_events() -> void:
	if not EventBus.floor_reward_chosen.is_connected(_on_floor_reward_chosen):
		EventBus.floor_reward_chosen.connect(_on_floor_reward_chosen)
	if not EventBus.shop_purchase.is_connected(_on_shop_purchase):
		EventBus.shop_purchase.connect(_on_shop_purchase)


func disconnect_events() -> void:
	if EventBus.floor_reward_chosen.is_connected(_on_floor_reward_chosen):
		EventBus.floor_reward_chosen.disconnect(_on_floor_reward_chosen)
	if EventBus.shop_purchase.is_connected(_on_shop_purchase):
		EventBus.shop_purchase.disconnect(_on_shop_purchase)


func get_slot_count(position: String) -> int:
	match position:
		"front": return _slots_front
		"middle": return _slots_middle
		"back": return _slots_back
	return 0


func get_total_slots() -> int:
	return _slots_front + _slots_middle + _slots_back


func can_unlock(position: String) -> bool:
	var cfg: Dictionary = ConfigManager.get_slot_expansion_config()
	var max_slots: Dictionary = cfg.get("max", {})
	var current: int = get_slot_count(position)
	var max_count: int = int(max_slots.get(position, 1))
	return current < max_count


func unlock_slot(position: String, source: String = "boss") -> bool:
	if not can_unlock(position):
		return false

	match position:
		"front": _slots_front += 1
		"middle": _slots_middle += 1
		"back": _slots_back += 1

	_unlock_history.append({
		"position": position,
		"source": source,
		"total_slots": get_total_slots(),
	})

	EventBus.slot_unlocked.emit({
		"position": position,
		"total_slots": get_total_slots(),
		"source": source,
	})
	return true


func get_unlock_history() -> Array:
	return _unlock_history.duplicate()


func reset() -> void:
	var cfg: Dictionary = ConfigManager.get_slot_expansion_config()
	var initial: Dictionary = cfg.get("initial", {})
	_slots_front = int(initial.get("front", 1))
	_slots_middle = int(initial.get("middle", 1))
	_slots_back = int(initial.get("back", 1))
	_unlock_history.clear()


func cleanup() -> void:
	reset()
	disconnect_events()


func _on_floor_reward_chosen(data: Dictionary) -> void:
	var category: String = data.get("category", "")
	if category != "expansion":
		return


func _on_shop_purchase(data: Dictionary) -> void:
	var category: String = data.get("category", "")
	if category != "slot":
		return
	var target_id: String = data.get("item_id", "")
	var position: String = _slot_position_from_id(target_id)
	if position != "":
		unlock_slot(position, "shop")


func _slot_position_from_id(item_id: String) -> String:
	if item_id.find("front") >= 0:
		return "front"
	if item_id.find("middle") >= 0:
		return "middle"
	if item_id.find("back") >= 0:
		return "back"
	return ""