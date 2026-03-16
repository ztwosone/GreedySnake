class_name FireEffect
extends RefCounted

## 火焰状态效果处理器
## 实体效果：周期性扣长度/伤害（层数倍增）
## 空间效果：火焰格蔓延到相邻格

# 实体效果追踪: { instance_id → elapsed_since_last_damage }
var _damage_timers: Dictionary = {}

# 蔓延追踪: { Vector2i → elapsed_since_last_spread }
var _spread_timers: Dictionary = {}


func process_entity_effects(delta: float, effect_mgr: Node) -> void:
	## 处理所有火焰实体效果（每帧调用）
	var cfg_node = Engine.get_main_loop().root.get_node_or_null("ConfigManager")
	var cfg: Dictionary = {}
	if cfg_node:
		cfg = cfg_node.get_status_effect("fire")

	var damage_interval: float = float(cfg.get("entity_damage_interval", 2.0))
	var damage_amount: int = int(cfg.get("entity_damage_amount", 1))

	# 遍历所有有 fire 状态的目标
	var targets_with_fire: Array = _get_targets_with_fire(effect_mgr)

	for entry in targets_with_fire:
		var target: Object = entry["target"]
		var effect: StatusEffectData = entry["effect"]
		var tid: int = target.get_instance_id()

		if not _damage_timers.has(tid):
			_damage_timers[tid] = 0.0

		_damage_timers[tid] += delta
		if _damage_timers[tid] >= damage_interval:
			_damage_timers[tid] -= damage_interval
			var total_damage: int = damage_amount * effect.layer
			_apply_fire_damage(target, total_damage)

	# 清理已不存在的 timer
	_cleanup_timers(targets_with_fire)


func process_tile_spread(delta: float, tile_mgr: StatusTileManager) -> void:
	## 处理火焰格蔓延（每帧调用）
	if tile_mgr == null:
		return

	var cfg_node = Engine.get_main_loop().root.get_node_or_null("ConfigManager")
	var cfg: Dictionary = {}
	if cfg_node:
		cfg = cfg_node.get_status_effect("fire")

	var spread_interval: float = float(cfg.get("spread_interval", 1.0))
	var spread_chance: float = float(cfg.get("spread_chance", 0.2))

	# 收集当前所有火焰格位置（snapshot 避免迭代中修改）
	var fire_positions: Array = []
	for pos in tile_mgr._tiles:
		if tile_mgr._tiles[pos].has("fire"):
			fire_positions.append(pos)

	for pos in fire_positions:
		if not _spread_timers.has(pos):
			_spread_timers[pos] = 0.0

		_spread_timers[pos] += delta
		if _spread_timers[pos] >= spread_interval:
			_spread_timers[pos] -= spread_interval
			_try_spread(pos, spread_chance, tile_mgr)

	# 清理已消失的火焰格 timer
	var to_erase: Array = []
	for pos in _spread_timers:
		if not tile_mgr.has_tile(pos, "fire"):
			to_erase.append(pos)
	for pos in to_erase:
		_spread_timers.erase(pos)


func _try_spread(pos: Vector2i, chance: float, tile_mgr: StatusTileManager) -> void:
	var neighbors: Array[Vector2i] = GridWorld.get_neighbors(pos)
	for n_pos in neighbors:
		if not GridWorld.is_within_bounds(n_pos):
			continue
		# 不蔓延到已有火焰格的位置
		if tile_mgr.has_tile(n_pos, "fire"):
			continue
		# 不蔓延到有障碍物的位置
		if GridWorld.is_cell_blocked(n_pos):
			continue
		# 概率检查
		if randf() < chance:
			tile_mgr.place_tile(n_pos, "fire")


func _apply_fire_damage(target: Object, amount: int) -> void:
	# 蛇：通过 EventBus 请求扣长度
	if target is Node:
		EventBus.length_decrease_requested.emit({
			"amount": amount,
			"source": "fire",
		})


func _get_targets_with_fire(effect_mgr: Node) -> Array:
	var result: Array = []
	if not effect_mgr.has_method("has_status"):
		return result
	# 遍历 StatusEffectManager 内部数据
	for target_id in effect_mgr._statuses:
		var target_effects: Dictionary = effect_mgr._statuses[target_id]
		if target_effects.has("fire"):
			var target: Object = effect_mgr._id_to_target.get(target_id)
			if is_instance_valid(target):
				result.append({
					"target": target,
					"effect": target_effects["fire"],
				})
	return result


func _cleanup_timers(active_targets: Array) -> void:
	var active_ids: Dictionary = {}
	for entry in active_targets:
		active_ids[entry["target"].get_instance_id()] = true
	var to_erase: Array = []
	for tid in _damage_timers:
		if not active_ids.has(tid):
			to_erase.append(tid)
	for tid in to_erase:
		_damage_timers.erase(tid)
