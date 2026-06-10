class_name FloorRewardSystem
extends Node
## 楼层奖励系统（spec 002 T025 重写，2026-06-11 修订版 spec FR-007/US3/US5，Designs §10.3-10.5）
## 判决：重写——草稿是假实现（expansion 硬编码 equip flame_scale、correction 是 pass）。
## Boss 结算两段式：
##   ① 固定槽位解锁步骤（玩家选前/中/后，经 SlotExpansionSystem.unlock_slot(position, source)，
##      新槽在 3 选 1 呈现之前开放——US3 场景 1）；全位置满级时自动跳过。
##   ② 独立 3 选 1（每类恰一个，Designs §10.4）：扩展=随机高级鳞（advanced_level，JSON）/
##      强化=当前最低等级鳞片免费升一级 / 修正=同 tag 换鳞（保级保槽位）。
##      无合格目标的类别以「随机高级鳞」替补，尽量保持 3 选项（spec Edge Cases）。
## 呈现门槛（_on_floor_completed 自守门）：floor_index < run.max_floors（终层直达胜利路径，
## US5 场景 4）且 floor.generator == "pcg"（T5a 裁定：fixed_v1 = 单层 MDE 回退档，终点即胜利，
## 结算无后续楼层可用）。present_settlement 公共方法本身不设门槛（测试/布景直驱）。
## FR-014：全空自动决议（floor_reward_chosen 带 skipped=true，不发 presented）；
## FR-015：floor_reward_presented（两段各发一次，step 字段）→ RunProgression 挂起切层，
## floor_reward_chosen 才解除——决议先于 advance_floor/floor_generated（US5 场景 5）。
## 抽样种子 = hash(run_id:floor_reward:floor_index:source_room_id)（同 run 同层确定性）。
## 决议顺序先清状态再发事件（与 ScaleRewardSystem 同一软锁防护模式）。

var _scale_slot_mgr: Object = null
var _slot_expansion: Object = null
var _current_offer: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	connect_events()


func _exit_tree() -> void:
	disconnect_events()


func setup(scale_mgr: Object, slot_expansion: Object) -> void:
	_scale_slot_mgr = scale_mgr
	_slot_expansion = slot_expansion


func connect_events() -> void:
	if not EventBus.floor_completed.is_connected(_on_floor_completed):
		EventBus.floor_completed.connect(_on_floor_completed)
	if not EventBus.run_started.is_connected(_on_run_started):
		EventBus.run_started.connect(_on_run_started)


func disconnect_events() -> void:
	if EventBus.floor_completed.is_connected(_on_floor_completed):
		EventBus.floor_completed.disconnect(_on_floor_completed)
	if EventBus.run_started.is_connected(_on_run_started):
		EventBus.run_started.disconnect(_on_run_started)


## Boss 结算入口：先固定槽位解锁步骤，无合格位置则直入 3 选 1，全空自动决议（FR-014）
func present_settlement(floor_index: int, source_room_id: String, salt: String = "") -> Dictionary:
	if has_pending_offer():
		return get_current_offer()

	_rng.seed = hash("%s:floor_reward:%d:%s" % [salt, floor_index, source_room_id])
	var slot_options: Array = _eligible_slot_positions()
	var options: Array = []
	if slot_options.is_empty():
		options = _build_choice_options()
		if options.is_empty():
			_emit_skipped(floor_index)
			return {}

	_current_offer = {
		"reward_id": "floor_reward_%d" % floor_index,
		"floor_index": floor_index,
		"source_room_id": source_room_id,
		"step": "slot_unlock" if not slot_options.is_empty() else "choice",
		"slot_options": slot_options,
		"options": options,
	}
	EventBus.floor_reward_presented.emit(get_current_offer())
	return get_current_offer()


## 槽位解锁步骤决议：真开槽（经薄适配器）→ 进入 3 选 1（或空选项自动决议）
func choose_slot_position(position: String) -> bool:
	if str(_current_offer.get("step", "")) != "slot_unlock":
		return false
	if not _current_offer.get("slot_options", []).has(position):
		return false
	var source: String = str(ConfigManager.get_floor_reward_config().get("slot_unlock_source", "boss"))
	if _slot_expansion == null or not _slot_expansion.unlock_slot(position, source):
		return false

	var options: Array = _build_choice_options()
	if options.is_empty():
		var floor_index: int = int(_current_offer.get("floor_index", 1))
		_current_offer.clear()
		_emit_skipped(floor_index)
		return true

	_current_offer["step"] = "choice"
	_current_offer["slot_options"] = []
	_current_offer["options"] = options
	EventBus.floor_reward_presented.emit(get_current_offer())
	return true


## 3 选 1 决议：应用奖励 → 先清状态再发 floor_reward_chosen（解除门控，FR-015）
func choose_floor_reward(index: int) -> bool:
	if str(_current_offer.get("step", "")) != "choice":
		return false
	var options: Array = _current_offer.get("options", [])
	if index < 0 or index >= options.size():
		return false
	var option: Dictionary = options[index]
	if not _apply_option(option):
		return false

	var floor_index: int = int(_current_offer.get("floor_index", 1))
	_current_offer.clear()
	EventBus.floor_reward_chosen.emit({
		"floor_index": floor_index,
		"category": str(option.get("category", "")),
		"option_id": str(option.get("option_id", "")),
		"skipped": false,
	})
	return true


func has_pending_offer() -> bool:
	return not _current_offer.is_empty()


func get_current_offer() -> Dictionary:
	return _current_offer.duplicate(true)


func cleanup() -> void:
	_current_offer.clear()
	disconnect_events()


func _on_floor_completed(data: Dictionary) -> void:
	if has_pending_offer():
		return
	var floor_index: int = int(data.get("floor_index", 1))
	# US5 场景 4：终层不弹，直达胜利路径
	if floor_index >= ConfigManager.get_max_floors():
		return
	# T5a 裁定：多层结算仅 pcg 档；fixed_v1 终点完成即胜利（MDE 单层闭环）
	if ConfigManager.get_floor_generator() != "pcg":
		return
	present_settlement(floor_index, str(data.get("endpoint_room_id", "")), str(data.get("run_id", "")))


## FR-013：run 重启清空成长流程状态（残留 offer 不得带入新 run）
func _on_run_started(_data: Dictionary) -> void:
	_current_offer.clear()


func _emit_skipped(floor_index: int) -> void:
	EventBus.floor_reward_chosen.emit({
		"floor_index": floor_index,
		"category": "",
		"option_id": "",
		"skipped": true,
	})


## 槽位解锁候选：JSON 序（growth.slot_expansion.max 键序）过滤未满位置
func _eligible_slot_positions() -> Array:
	var cfg: Dictionary = ConfigManager.get_slot_expansion_config()
	if not bool(cfg.get("boss_unlock_enabled", false)) or _slot_expansion == null:
		return []
	var positions: Array = []
	for position in cfg.get("max", {}):
		if _slot_expansion.can_unlock(str(position)):
			positions.append(str(position))
	return positions


## 三类各一（config 序）；无合格目标类别以高级鳞替补（去重），仍为空则丢弃该项
func _build_choice_options() -> Array:
	var cfg: Dictionary = ConfigManager.get_floor_reward_config()
	var options: Array = []
	var used_scale_ids: Array = []
	for category in cfg.get("categories", []):
		var option: Dictionary = {}
		match str(category):
			"expansion":
				option = _build_expansion_option(used_scale_ids)
			"reinforcement":
				option = _build_reinforcement_option()
			"correction":
				option = _build_correction_option()
		if option.is_empty() and str(category) != "expansion":
			option = _build_expansion_option(used_scale_ids)
		if option.is_empty():
			continue
		if str(option.get("category", "")) == "expansion":
			used_scale_ids.append(str(option.get("target_id", "")))
		options.append(option)
	return options


## 扩展类：随机高级鳞（advanced_level，按位置可承载过滤；exclude 防替补重复）
func _build_expansion_option(exclude_ids: Array) -> Dictionary:
	var cat_cfg: Dictionary = ConfigManager.get_floor_reward_config().get("expansion", {})
	var level: int = int(cat_cfg.get("advanced_level", 0))
	var pool: Array = ConfigManager.get_scale_reward_pool(str(cat_cfg.get("scale_pool", "")))
	var candidates: Array = _expansion_candidates(pool, level, exclude_ids)
	if candidates.is_empty() and not exclude_ids.is_empty():
		candidates = _expansion_candidates(pool, level, [])
	if candidates.is_empty():
		return {}
	var pick: Dictionary = candidates[_rng.randi_range(0, candidates.size() - 1)]
	var scale_id: String = str(pick.get("target_id", ""))
	return {
		"option_id": "expansion_%s" % scale_id,
		"category": "expansion",
		"display_name": str(cat_cfg.get("display_name", "expansion")),
		"description": str(cat_cfg.get("description", "")),
		"detail": "获得 %s Lv.%d" % [str(pick.get("display_name", scale_id)), level],
		"target_id": scale_id,
		"position": str(pick.get("target_slot", "")),
		"level": level,
		"placeholder_color": str(pick.get("placeholder_color", "")),
	}


func _expansion_candidates(pool: Array, level: int, exclude_ids: Array) -> Array:
	if _scale_slot_mgr == null:
		return []
	var candidates: Array = []
	for entry in pool:
		if not (entry is Dictionary) or str(entry.get("reward_type", "")) != "scale":
			continue
		var scale_id: String = str(entry.get("target_id", ""))
		if exclude_ids.has(scale_id):
			continue
		if ConfigManager.get_snake_scale(scale_id, level).is_empty():
			continue
		if not _can_host(str(entry.get("target_slot", ""))):
			continue
		candidates.append(entry)
	return candidates


## 强化类：当前最低等级已装鳞片免费升一级（同级并列取遍历序首个；满级件不可升）
func _build_reinforcement_option() -> Dictionary:
	var best: Dictionary = {}
	for slot in _equipped_slots():
		var part: Object = slot["part"]
		if ConfigManager.get_snake_scale(str(part.part_id), int(part.level) + 1).is_empty():
			continue
		if best.is_empty() or int(part.level) < int(best["part"].level):
			best = slot
	if best.is_empty():
		return {}
	var cat_cfg: Dictionary = ConfigManager.get_floor_reward_config().get("reinforcement", {})
	var part: Object = best["part"]
	return {
		"option_id": "reinforcement_%s" % str(part.part_id),
		"category": "reinforcement",
		"display_name": str(cat_cfg.get("display_name", "reinforcement")),
		"description": str(cat_cfg.get("description", "")),
		"detail": "升级 %s -> Lv.%d" % [str(part.part_id), int(part.level) + 1],
		"target_id": str(part.part_id),
		"position": str(best["position"]),
		"slot_index": int(best["slot_index"]),
		"level": int(part.level) + 1,
	}


## 修正类：随机已装鳞片换同 tag 随机鳞（保级保槽位；候选 = 存在同级同 tag 异件）
func _build_correction_option() -> Dictionary:
	var candidates: Array = []
	for slot in _equipped_slots():
		var part: Object = slot["part"]
		var alts: Array = _same_tag_alternatives(str(part.part_id), int(part.level))
		if not alts.is_empty():
			var enriched: Dictionary = slot.duplicate()
			enriched["alts"] = alts
			candidates.append(enriched)
	if candidates.is_empty():
		return {}
	var pick: Dictionary = candidates[_rng.randi_range(0, candidates.size() - 1)]
	var part: Object = pick["part"]
	var alts: Array = pick["alts"]
	var swap_id: String = str(alts[_rng.randi_range(0, alts.size() - 1)])
	var cat_cfg: Dictionary = ConfigManager.get_floor_reward_config().get("correction", {})
	return {
		"option_id": "correction_%s_%s" % [str(part.part_id), swap_id],
		"category": "correction",
		"display_name": str(cat_cfg.get("display_name", "correction")),
		"description": str(cat_cfg.get("description", "")),
		"detail": "%s -> %s" % [str(part.part_id), swap_id],
		"target_id": swap_id,
		"replace_id": str(part.part_id),
		"position": str(pick["position"]),
		"slot_index": int(pick["slot_index"]),
		"level": int(part.level),
	}


func _same_tag_alternatives(scale_id: String, level: int) -> Array:
	var tags: Array = ConfigManager.get_scale_tags(scale_id)
	var alts: Array = []
	for alt_id in ConfigManager.get_snake_scale_ids():
		if str(alt_id) == scale_id:
			continue
		if ConfigManager.get_snake_scale(str(alt_id), level).is_empty():
			continue
		for tag in ConfigManager.get_scale_tags(str(alt_id)):
			if tags.has(tag):
				alts.append(str(alt_id))
				break
	return alts


## 全部已装鳞片的 (position, slot_index, part) 视图——槽位号取自原始布局（含空槽索引不漂移）
func _equipped_slots() -> Array:
	if _scale_slot_mgr == null:
		return []
	var slots: Array = []
	for position in ConfigManager.get_slot_expansion_config().get("max", {}):
		var layout: Array = _scale_slot_mgr.get_slot_layout(str(position))
		for slot_index in range(layout.size()):
			if layout[slot_index] != null:
				slots.append({
					"position": str(position),
					"slot_index": slot_index,
					"part": layout[slot_index],
				})
	return slots


func _can_host(position: String) -> bool:
	if _scale_slot_mgr == null:
		return false
	return _scale_slot_mgr.has_open_slot(position) \
		or not _scale_slot_mgr.get_scales(position).is_empty()


func _apply_option(option: Dictionary) -> bool:
	if _scale_slot_mgr == null:
		return false
	var position: String = str(option.get("position", ""))
	var target_id: String = str(option.get("target_id", ""))
	var level: int = int(option.get("level", 1))
	match str(option.get("category", "")):
		"expansion":
			return _equip_with_replacement(position, target_id, level)
		"reinforcement":
			return _scale_slot_mgr.upgrade_scale(position, int(option.get("slot_index", 0)), level)
		"correction":
			_scale_slot_mgr.unequip_scale(position, int(option.get("slot_index", 0)))
			return _scale_slot_mgr.equip_scale(position, target_id, level)
	return false


## 满槽替换（与 ScaleRewardSystem 同语义）：无空开放槽时卸该位置首槽旧鳞再装新鳞
func _equip_with_replacement(position: String, scale_id: String, level: int) -> bool:
	if not _scale_slot_mgr.has_open_slot(position):
		if _scale_slot_mgr.get_scales(position).is_empty():
			return false
		_scale_slot_mgr.unequip_scale(position, 0)
	return _scale_slot_mgr.equip_scale(position, scale_id, level)
