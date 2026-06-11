class_name ScaleRewardSystem
extends Node
## 鳞片奖励系统（spec 002 T005 重写，2026-06-11 修订版 spec）
## 战斗房 room_completed（trigger_room_types，JSON）→ 恰 offer_count 选项（FR-001）；
## 选择经 ScaleSlotManager 装备，满槽替换（US1 场景 3）；放弃 → scale_option_discarded 蜕皮补偿；
## 空池/零合格选项自动决议（FR-014：chosen 带 skipped=true，不弹模态）；
## 绝不发合成 room_completed（FR-018——拆除范围仅此系统，RewardFlowSystem 的合成发射保留）。
## 决议顺序先清状态再发事件：草稿在发事件后清状态，监听方再触发 offer 时新 offer 被误清
## （草稿 :85/:98 幻影二次 offer + 软锁根因）。
## 传承石抽样偏置钩子：set_sampling_bias(Callable)——接收合格选项 Array、返回重排后 Array，
## L5 传承石按此注入抽样加权，无需改本系统。

var _scale_slot_mgr: Object = null
var _current_offer: Dictionary = {}
var _offer_seq: int = 0
var _sampling_bias: Callable = Callable()


func _ready() -> void:
	connect_events()


func _exit_tree() -> void:
	disconnect_events()


func setup(scale_mgr: Object) -> void:
	_scale_slot_mgr = scale_mgr


func set_sampling_bias(bias: Callable) -> void:
	_sampling_bias = bias


## spec 003 M3（T014）：bias 生命周期可观测——传承石 bias 恰一局有效（FR-015），
## game_world.start_game(run_options) 每局显式 set-or-clear（空 Callable = 清除）
func has_sampling_bias() -> bool:
	return _sampling_bias.is_valid()


func connect_events() -> void:
	if not EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.connect(_on_room_completed)


func disconnect_events() -> void:
	if EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.disconnect(_on_room_completed)


func present_offer(source_room: Dictionary, pool_id: String = "") -> Dictionary:
	if has_pending_offer():
		return _current_offer.duplicate(true)

	var cfg: Dictionary = ConfigManager.get_scale_reward_config()
	if pool_id == "":
		pool_id = str(cfg.get("default_pool", ""))
	var offer_count: int = int(cfg.get("offer_count", 0))
	var pool: Array = ConfigManager.get_scale_reward_pool(pool_id)
	var options: Array = _pick_options(pool, offer_count)
	var room_id: String = str(source_room.get("room_id", "manual"))

	_offer_seq += 1
	var offer_id: String = "scale_%s_%d" % [room_id, _offer_seq]

	if options.is_empty():
		# FR-014：空池/零合格选项自动决议——不弹模态，流程不依赖玩家输入
		EventBus.scale_reward_chosen.emit({
			"offer_id": offer_id,
			"option_id": "",
			"scale_id": "",
			"position": "",
			"level": 0,
			"skipped": true,
		})
		return {}

	_current_offer = {
		"offer_id": offer_id,
		"room_id": room_id,
		"pool_id": pool_id,
		"options": options,
	}
	EventBus.scale_reward_presented.emit(_current_offer.duplicate(true))
	return _current_offer.duplicate(true)


func choose_scale(index: int) -> bool:
	if not has_pending_offer() or _scale_slot_mgr == null:
		return false
	var options: Array = _current_offer.get("options", [])
	if index < 0 or index >= options.size():
		return false

	var option: Dictionary = options[index]
	var scale_id: String = str(option.get("target_id", ""))
	var slot: String = str(option.get("target_slot", ""))
	var level: int = _get_reward_level(option)
	if not _equip_with_replacement(slot, scale_id, level):
		return false

	var offer_id: String = str(_current_offer.get("offer_id", ""))
	var discarded_ids: Array = []
	for i in range(options.size()):
		if i != index:
			discarded_ids.append(str(options[i].get("option_id", "")))
	_current_offer.clear()

	EventBus.scale_reward_chosen.emit({
		"offer_id": offer_id,
		"option_id": str(option.get("option_id", "")),
		"scale_id": scale_id,
		"position": slot,
		"level": level,
		"skipped": false,
	})
	# US2 场景 2：未选中的选项视为放弃，逐项补偿蜕皮
	if not discarded_ids.is_empty():
		EventBus.scale_option_discarded.emit({
			"offer_id": offer_id,
			"discarded_ids": discarded_ids,
			"shedskin_gained": discarded_ids.size() * _discard_unit(),
		})
	return true


## 放弃整个 offer：全部选项转化为蜕皮补偿
func discard_offer() -> bool:
	if not has_pending_offer():
		return false
	var offer_id: String = str(_current_offer.get("offer_id", ""))
	var discarded_ids: Array = []
	for option in _current_offer.get("options", []):
		discarded_ids.append(str(option.get("option_id", "")))
	_current_offer.clear()
	EventBus.scale_option_discarded.emit({
		"offer_id": offer_id,
		"discarded_ids": discarded_ids,
		"shedskin_gained": discarded_ids.size() * _discard_unit(),
	})
	return true


## 当前 offer 全放弃可得的蜕皮（UI 放弃入口标注用）
func get_discard_reward() -> int:
	return _current_offer.get("options", []).size() * _discard_unit()


func has_pending_offer() -> bool:
	return not _current_offer.is_empty()


func get_current_offer() -> Dictionary:
	return _current_offer.duplicate(true)


func cleanup() -> void:
	_current_offer.clear()
	disconnect_events()


func _discard_unit() -> int:
	return int(ConfigManager.get_shedskin_config().get("scale_discard", 0))


func _pick_options(pool: Array, offer_count: int) -> Array:
	var eligible: Array = []
	for option in pool:
		if option is Dictionary and _is_option_eligible(option):
			eligible.append(option.duplicate(true))
	eligible.shuffle()
	if _sampling_bias.is_valid():
		var biased: Variant = _sampling_bias.call(eligible)
		if biased is Array:
			eligible = biased
	var result: Array = []
	for i in range(mini(offer_count, eligible.size())):
		result.append(eligible[i])
	return result


## 合格 = scale 类型 + 配置存在 + 目标位置可承载（有空开放槽，或已有鳞片可替换）
func _is_option_eligible(option: Dictionary) -> bool:
	if str(option.get("reward_type", "")) != "scale":
		return false
	if _scale_slot_mgr == null:
		return false
	var slot: String = str(option.get("target_slot", ""))
	var can_host: bool = _scale_slot_mgr.has_open_slot(slot) \
		or not _scale_slot_mgr.get_scales(slot).is_empty()
	if not can_host:
		return false
	var scale_cfg: Dictionary = ConfigManager.get_snake_scale(
		str(option.get("target_id", "")), _get_reward_level(option))
	return not scale_cfg.is_empty()


## 满槽替换（US1 场景 3）：无空开放槽时卸下该位置首槽旧鳞再装新鳞
func _equip_with_replacement(slot: String, scale_id: String, level: int) -> bool:
	if not _scale_slot_mgr.has_open_slot(slot):
		if _scale_slot_mgr.get_scales(slot).is_empty():
			return false
		_scale_slot_mgr.unequip_scale(slot, 0)
	return _scale_slot_mgr.equip_scale(slot, scale_id, level)


func _get_reward_level(option: Dictionary) -> int:
	return maxi(1, int(option.get("level", 1)) + int(option.get("level_delta", 0)))


func _on_room_completed(data: Dictionary) -> void:
	if has_pending_offer():
		return
	var cfg: Dictionary = ConfigManager.get_scale_reward_config()
	if not cfg.get("trigger_room_types", []).has(str(data.get("room_type", ""))):
		return
	present_offer(data)
