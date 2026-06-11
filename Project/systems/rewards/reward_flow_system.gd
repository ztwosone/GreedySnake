class_name RewardFlowSystem
extends Node

var _snake_parts_mgr: Node = null
var _scale_slot_mgr: Node = null
var _current_offer: Dictionary = {}

## spec 003 M2（T010）：解锁过滤注入缝（口径同 ScaleRewardSystem.set_sampling_bias）——
## Callable(content_type: String, content_id: String) -> bool；MetaGrowthRoot.attach_world
## 在开局接线（is_content_unlocked）。未注入全量回退（L3 既有测试零破坏）。
## v1 仅过滤 head/tail（Designs §12.3 附录：鳞片不门控）；过滤后零选项走既有
## FR-014 自动决议（合成 room_completed 保留，不死锁）。
var _unlock_query: Callable = Callable()

## spec 003 M3（T014）：传承石抽样偏置注入缝（口径同 ScaleRewardSystem.set_sampling_bias）
## ——收合格选项 Array、返回加权重排 Array，取前 offer_count 即偏置后 offer。
## 未注入零行为：保持 L3 first-N 池序确定性（既有测试零破坏）。
## bias 恰一局有效（FR-015）：game_world.start_game(run_options) 每局显式 set-or-clear。
var _sampling_bias: Callable = Callable()


func _ready() -> void:
	connect_events()


func _exit_tree() -> void:
	disconnect_events()


func setup(parts_mgr: Node, scale_mgr: Node) -> void:
	_snake_parts_mgr = parts_mgr
	_scale_slot_mgr = scale_mgr


func set_unlock_query(query: Callable) -> void:
	_unlock_query = query


func set_sampling_bias(bias: Callable) -> void:
	_sampling_bias = bias


func has_sampling_bias() -> bool:
	return _sampling_bias.is_valid()


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
	var eligible: Array = []
	for option in pool:
		if not (option is Dictionary):
			continue
		var option_copy: Dictionary = option.duplicate(true)
		if not _is_option_unlocked(option_copy):
			continue
		if not _can_apply_option(option_copy):
			continue
		eligible.append(option_copy)
	# M3（T014）：传承石偏置重排（未注入 = 原池序，first-N 行为与 L3 全等）
	if _sampling_bias.is_valid():
		var biased: Variant = _sampling_bias.call(eligible)
		if biased is Array:
			eligible = biased
	var result: Array = []
	for i in range(mini(offer_count, eligible.size())):
		result.append(eligible[i])
	return result


## 解锁门控（spec 003 FR-003：锁定内容绝不进 offer）；未注入查询 = 全量回退
func _is_option_unlocked(option: Dictionary) -> bool:
	var reward_type: String = option.get("reward_type", "")
	if reward_type != "head" and reward_type != "tail":
		return true
	if not _unlock_query.is_valid():
		return true
	return bool(_unlock_query.call(reward_type, option.get("target_id", "")))


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
