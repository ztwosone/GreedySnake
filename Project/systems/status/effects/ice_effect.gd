class_name IceEffect
extends RefCounted

## 冰冻状态效果处理器
## 实体效果：1层减速（tick_speed_modifier *= speed_modifier），2层冻结（暂停ticking）
## 冻结结束后回退到1层

# 当前是否处于冻结状态
var _is_frozen: bool = false
var _freeze_timer: float = 0.0
# 当前是否在减速
var _is_slowed: bool = false


func process_entity_effects(delta: float, effect_mgr: Node) -> void:
	var cfg_node = Engine.get_main_loop().root.get_node_or_null("ConfigManager")
	var cfg: Dictionary = {}
	if cfg_node:
		cfg = cfg_node.get_status_effect("ice")

	var speed_modifier: float = float(cfg.get("speed_modifier", 0.5))
	var freeze_at_layer: int = int(cfg.get("freeze_at_layer", 2))
	var freeze_duration: float = float(cfg.get("freeze_duration", 2.0))

	var tick_mgr = Engine.get_main_loop().root.get_node_or_null("TickManager")

	# 查找有冰冻状态的目标
	var targets_with_ice: Array = _get_targets_with_ice(effect_mgr)
	var has_any_ice: bool = targets_with_ice.size() > 0

	# 处理冻结状态
	if _is_frozen:
		_freeze_timer += delta
		if _freeze_timer >= freeze_duration:
			_end_freeze(effect_mgr, tick_mgr, speed_modifier)
		return  # 冻结期间不做其他处理

	if not has_any_ice:
		# 没有冰冻目标，恢复速度
		if _is_slowed:
			_remove_slow(tick_mgr)
		return

	# 检查是否触发冻结
	for entry in targets_with_ice:
		var effect: StatusEffectData = entry["effect"]
		if effect.layer >= freeze_at_layer:
			_start_freeze(tick_mgr)
			return

	# 1层：应用减速
	if not _is_slowed:
		_apply_slow(tick_mgr, speed_modifier)


func _start_freeze(tick_mgr: Node) -> void:
	_is_frozen = true
	_freeze_timer = 0.0
	if _is_slowed:
		# 先恢复减速再暂停
		_is_slowed = false
		if tick_mgr:
			tick_mgr.tick_speed_modifier = 1.0
	if tick_mgr:
		tick_mgr.pause()
	EventBus.ice_freeze_started.emit({})


func _end_freeze(effect_mgr: Node, tick_mgr: Node, speed_modifier: float) -> void:
	_is_frozen = false
	_freeze_timer = 0.0
	if tick_mgr:
		tick_mgr.resume()

	# 冻结结束后层数重置为1，继续减速
	var targets_with_ice: Array = _get_targets_with_ice(effect_mgr)
	for entry in targets_with_ice:
		var effect: StatusEffectData = entry["effect"]
		if effect.layer > 1:
			effect.layer = 1

	# 重新应用减速（如果还有冰冻状态）
	if targets_with_ice.size() > 0:
		_apply_slow(tick_mgr, speed_modifier)

	EventBus.ice_freeze_ended.emit({})


func _apply_slow(tick_mgr: Node, speed_modifier: float) -> void:
	_is_slowed = true
	if tick_mgr:
		tick_mgr.tick_speed_modifier = speed_modifier
		# 更新 timer 的 wait_time
		if tick_mgr.has_method("get_effective_interval") and tick_mgr.get("_timer"):
			tick_mgr._timer.wait_time = tick_mgr.get_effective_interval()


func _remove_slow(tick_mgr: Node) -> void:
	_is_slowed = false
	if tick_mgr:
		tick_mgr.tick_speed_modifier = 1.0
		if tick_mgr.has_method("get_effective_interval") and tick_mgr.get("_timer"):
			tick_mgr._timer.wait_time = tick_mgr.get_effective_interval()


func _get_targets_with_ice(effect_mgr: Node) -> Array:
	var result: Array = []
	if not effect_mgr.has_method("has_status"):
		return result
	for target_id in effect_mgr._statuses:
		var target_effects: Dictionary = effect_mgr._statuses[target_id]
		if target_effects.has("ice"):
			var target: Object = effect_mgr._id_to_target.get(target_id)
			if is_instance_valid(target):
				result.append({
					"target": target,
					"effect": target_effects["ice"],
				})
	return result
