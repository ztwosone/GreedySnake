class_name RewardFlowSystem
extends Node

var _snake_parts_mgr: Node = null
var _scale_slot_mgr: Node = null
var _current_offer: Dictionary = {}


func _ready() -> void:
	connect_events()


func _exit_tree() -> void:
	disconnect_events()


func setup(parts_mgr: Node, scale_mgr: Node) -> void:
	_snake_parts_mgr = parts_mgr
	_scale_slot_mgr = scale_mgr


func connect_events() -> void:
	if not EventBus.room_entered.is_connected(_on_room_entered):
		EventBus.room_entered.connect(_on_room_entered)


func disconnect_events() -> void:
	if EventBus.room_entered.is_connected(_on_room_entered):
		EventBus.room_entered.disconnect(_on_room_entered)


func present_offer(source_room: Dictionary = {}, pool_id: String = "starter_build") -> Dictionary:
	if has_pending_offer():
		return _current_offer.duplicate(true)

	var rewards_cfg: Dictionary = ConfigManager.get_reward_config()
	var offer_count: int = min(3, int(rewards_cfg.get("offer_count", 3)))
	var pool: Array = ConfigManager.get_reward_pool(pool_id)
	var options: Array = _get_visible_options(pool, offer_count)

	if options.is_empty():
		# FR-014（spec 002 T007 回补）：零可应用选项自动决议——不弹模态，
		# 仍走合成 room_completed（L3 奖励房唯一完成通路，FR-018 显式保留契约）
		EventBus.reward_chosen.emit({
			"offer_id": "reward_%s" % source_room.get("room_id", "manual"),
			"source_room_id": source_room.get("room_id", ""),
			"source_room_type": source_room.get("room_type", ""),
			"chosen_option_id": "",
			"option": {},
			"skipped": true,
		})
		_emit_synthetic_room_completed(
			source_room.get("room_id", ""), source_room.get("room_type", ""))
		return {}

	_current_offer = {
		"offer_id": "reward_%s" % source_room.get("room_id", "manual"),
		"source_room_id": source_room.get("room_id", ""),
		"source_room_type": source_room.get("room_type", ""),
		"options": options,
		"chosen_option_id": "",
		"complete": false,
	}

	EventBus.reward_presented.emit(_current_offer.duplicate(true))
	return _current_offer.duplicate(true)


func choose_reward(option_id: String) -> bool:
	if _current_offer.is_empty() or bool(_current_offer.get("complete", false)):
		return false

	var option: Dictionary = _find_option(option_id)
	if option.is_empty():
		return false
	if not _apply_option(option):
		return false

	# 先取值清状态再发事件（防监听方再触发 offer 时被误清的重入模式，对齐 spec 002 T005 裁定）
	var offer_id: String = _current_offer.get("offer_id", "")
	var source_room_id: String = _current_offer.get("source_room_id", "")
	var source_room_type: String = _current_offer.get("source_room_type", "")
	_current_offer.clear()
	EventBus.reward_chosen.emit({
		"offer_id": offer_id,
		"source_room_id": source_room_id,
		"source_room_type": source_room_type,
		"chosen_option_id": option_id,
		"option": option.duplicate(true),
	})
	_emit_synthetic_room_completed(source_room_id, source_room_type)
	return true


## 合成 room_completed：L3 奖励房唯一完成通路（FR-018 显式保留，仅限本系统）
func _emit_synthetic_room_completed(room_id: String, room_type: String) -> void:
	EventBus.room_completed.emit({
		"room_id": room_id,
		"room_type": room_type,
		"intent_label": "选择奖励",
		"objective": {
			"objective_type": "claim_reward",
			"required_count": 1,
			"current_count": 1,
			"complete": true,
		},
		"exit_room_ids": [],
	})


func has_pending_offer() -> bool:
	return not _current_offer.is_empty() and not bool(_current_offer.get("complete", false))


func get_current_offer() -> Dictionary:
	return _current_offer.duplicate(true)


func cleanup() -> void:
	_current_offer.clear()
	disconnect_events()


func _get_visible_options(pool: Array, offer_count: int) -> Array:
	var result: Array = []
	for option in pool:
		if not (option is Dictionary):
			continue
		var option_copy: Dictionary = option.duplicate(true)
		if not _can_apply_option(option_copy):
			continue
		result.append(option_copy)
		if result.size() >= offer_count:
			break
	return result


func _find_option(option_id: String) -> Dictionary:
	for option in _current_offer.get("options", []):
		if option is Dictionary and option.get("option_id", "") == option_id:
			return option
	return {}


func _can_apply_option(option: Dictionary) -> bool:
	var reward_type: String = option.get("reward_type", "")
	var target_id: String = option.get("target_id", "")
	var level: int = _get_reward_level(option)
	match reward_type:
		"head":
			return _snake_parts_mgr != null and not ConfigManager.get_snake_head(target_id, level).is_empty()
		"tail":
			return _snake_parts_mgr != null and not ConfigManager.get_snake_tail(target_id, level).is_empty()
		"scale":
			var slot: String = option.get("target_slot", "middle")
			return _scale_slot_mgr != null and _scale_slot_mgr.has_open_slot(slot) and not ConfigManager.get_snake_scale(target_id, level).is_empty()
		_:
			return false


func _apply_option(option: Dictionary) -> bool:
	var reward_type: String = option.get("reward_type", "")
	var target_id: String = option.get("target_id", "")
	var level: int = _get_reward_level(option)
	match reward_type:
		"head":
			return _snake_parts_mgr != null and _snake_parts_mgr.equip_head(target_id, level)
		"tail":
			return _snake_parts_mgr != null and _snake_parts_mgr.equip_tail(target_id, level)
		"scale":
			var slot: String = option.get("target_slot", "middle")
			return _scale_slot_mgr != null and _scale_slot_mgr.equip_scale(slot, target_id, level)
	return false


func _get_reward_level(option: Dictionary) -> int:
	return max(1, int(option.get("level", 1)) + int(option.get("level_delta", 0)))


func _on_room_entered(data: Dictionary) -> void:
	if has_pending_offer():
		return
	var rewards_cfg: Dictionary = ConfigManager.get_reward_config()
	var trigger_room_types: Array = rewards_cfg.get("trigger_room_types", [])
	if not trigger_room_types.has(data.get("room_type", "")):
		return
	present_offer(data)
