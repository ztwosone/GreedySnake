extends Node
## 状态效果全局管理器
## 追踪所有活跃的状态效果实例，处理叠层、过期和载体销毁。

# 存储: { instance_id: int → { type: String → StatusEffectData } }
var _statuses: Dictionary = {}
# 反查: { instance_id: int → Object }
var _id_to_target: Dictionary = {}

# 效果处理器（可插拔）
var fire_effect: FireEffect = FireEffect.new()
var ice_effect: IceEffect = IceEffect.new()
var poison_effect: PoisonEffect = PoisonEffect.new()

# 火焰蔓延需要 tile_manager 引用
var tile_manager: StatusTileManager = null


func _process(delta: float) -> void:
	_tick_update(delta)
	_process_effects(delta)


func _process_effects(delta: float) -> void:
	fire_effect.process_entity_effects(delta, self)
	if tile_manager:
		fire_effect.process_tile_spread(delta, tile_manager)
	ice_effect.process_entity_effects(delta, self)
	poison_effect.process_entity_effects(delta, self)


func _tick_update(delta: float) -> void:
	var expired_list: Array = []

	for target_id in _statuses:
		var target_effects: Dictionary = _statuses[target_id]
		var target: Object = _id_to_target.get(target_id)

		# 载体已销毁 → 标记全部清理
		if not is_instance_valid(target):
			for effect_type in target_effects:
				expired_list.append({ "target_id": target_id, "type": effect_type, "reason": "carrier_destroyed" })
			continue

		for effect_type in target_effects:
			var effect: StatusEffectData = target_effects[effect_type]
			effect.elapsed += delta
			effect.duration -= delta
			if effect.duration <= 0.0:
				expired_list.append({ "target_id": target_id, "type": effect_type, "reason": "expired" })

	# 处理过期/失效
	for entry in expired_list:
		var target_id: int = entry["target_id"]
		var effect_type: String = entry["type"]
		var reason: String = entry["reason"]

		if not _statuses.has(target_id):
			continue
		var target_effects: Dictionary = _statuses[target_id]
		if not target_effects.has(effect_type):
			continue

		var target: Object = _id_to_target.get(target_id)
		target_effects.erase(effect_type)

		if target_effects.is_empty():
			_statuses.erase(target_id)
			_id_to_target.erase(target_id)
			_disconnect_carrier(target, target_id)

		if reason == "expired" and is_instance_valid(target):
			EventBus.status_expired.emit({
				"target": target,
				"type": effect_type,
			})


# === 公共 API ===

func apply_status(target: Object, type: String, source: String) -> StatusEffectData:
	var target_id: int = target.get_instance_id()

	# 已有同类状态 → 叠层或刷新
	if _statuses.has(target_id) and _statuses[target_id].has(type):
		var existing: StatusEffectData = _statuses[target_id][type]
		if existing.layer < existing.max_layers:
			var old_layer: int = existing.layer
			existing.layer += 1
			existing.duration = existing.max_duration
			existing.elapsed = 0.0
			EventBus.status_layer_changed.emit({
				"target": target,
				"type": type,
				"old_layer": old_layer,
				"new_layer": existing.layer,
			})
		else:
			# 已满层，只刷新时间
			existing.duration = existing.max_duration
			existing.elapsed = 0.0
		return existing

	# 新状态
	var effect := StatusEffectData.create(type, target, _detect_carrier_type(target), source)

	if not _statuses.has(target_id):
		_statuses[target_id] = {}
		_id_to_target[target_id] = target
		_connect_carrier(target, target_id)

	_statuses[target_id][type] = effect

	EventBus.status_applied.emit({
		"target": target,
		"type": type,
		"layer": effect.layer,
		"source": source,
	})

	return effect


func remove_status(target: Object, type: String, source: String = "manual") -> void:
	var target_id: int = target.get_instance_id()
	if not _statuses.has(target_id):
		return
	if not _statuses[target_id].has(type):
		return

	_statuses[target_id].erase(type)

	EventBus.status_removed.emit({
		"target": target,
		"type": type,
		"source": source,
	})

	if _statuses[target_id].is_empty():
		_statuses.erase(target_id)
		_id_to_target.erase(target_id)
		_disconnect_carrier(target, target_id)


func remove_all_statuses(target: Object) -> void:
	var target_id: int = target.get_instance_id()
	if not _statuses.has(target_id):
		return

	var types_to_remove: Array = _statuses[target_id].keys()
	for type in types_to_remove:
		_statuses[target_id].erase(type)
		if is_instance_valid(target):
			EventBus.status_removed.emit({
				"target": target,
				"type": type,
				"source": "clear_all",
			})

	_statuses.erase(target_id)
	_id_to_target.erase(target_id)
	_disconnect_carrier(target, target_id)


func get_statuses(target: Object) -> Array:
	var target_id: int = target.get_instance_id()
	if not _statuses.has(target_id):
		return []
	return _statuses[target_id].values()


func get_status(target: Object, type: String) -> StatusEffectData:
	var target_id: int = target.get_instance_id()
	if not _statuses.has(target_id):
		return null
	return _statuses[target_id].get(type, null)


func has_status(target: Object, type: String) -> bool:
	var target_id: int = target.get_instance_id()
	if not _statuses.has(target_id):
		return false
	return _statuses[target_id].has(type)


func clear_all() -> void:
	# 断开所有载体信号
	for target_id in _id_to_target:
		var target: Object = _id_to_target[target_id]
		_disconnect_carrier(target, target_id)
	_statuses.clear()
	_id_to_target.clear()


# === 内部方法 ===

func _detect_carrier_type(target: Object) -> String:
	# 简单判断：如果有 grid_position 属性则视为 spatial（StatusTile），否则 entity
	if target.get("grid_position") != null and target is not Node2D:
		return "spatial"
	return "entity"


func _connect_carrier(target: Object, _target_id: int) -> void:
	if target is Node and is_instance_valid(target):
		if not target.tree_exiting.is_connected(_on_carrier_tree_exiting):
			target.tree_exiting.connect(_on_carrier_tree_exiting.bind(target))


func _disconnect_carrier(target: Object, _target_id: int) -> void:
	if target is Node and is_instance_valid(target):
		if target.tree_exiting.is_connected(_on_carrier_tree_exiting):
			target.tree_exiting.disconnect(_on_carrier_tree_exiting)


func _on_carrier_tree_exiting(target: Object) -> void:
	remove_all_statuses(target)
