extends Node
## 状态效果全局管理器
## 追踪所有活跃的状态效果实例，处理叠层、过期和载体销毁。
## 使用 JSON 定义的原子链驱动所有效果行为。

# 存储: { instance_id: int → { type: String → StatusEffectData } }
var _statuses: Dictionary = {}
# 反查: { instance_id: int → Object }
var _id_to_target: Dictionary = {}

# 火焰蔓延需要 tile_manager 引用
var tile_manager: StatusTileManager = null:
	set(value):
		tile_manager = value
		if _trigger_manager:
			_trigger_manager.tile_mgr = value

# === Atom 系统 ===
var _atom_registry: AtomRegistry = null
var _chain_resolver: EffectChainResolver = null
var _trigger_manager: TriggerManager = null
# 活跃修改器: { "growth" → { target_instance_id → multiplier }, "speed" → ..., ... }
var _active_modifiers: Dictionary = {
	"growth": {},
	"speed": {},
	"hit_threshold": {},
	"food_drop": {},
}


func _ready() -> void:
	_init_atom_system()


func _init_atom_system() -> void:
	_atom_registry = AtomRegistry.new()
	_chain_resolver = EffectChainResolver.new(_atom_registry)
	# TriggerManager 是 Node，需加入场景树
	_trigger_manager = TriggerManager.new()
	_trigger_manager.name = "TriggerManager"
	_trigger_manager.effect_mgr = self
	_trigger_manager.tile_mgr = tile_manager
	_trigger_manager.tick_mgr = TickManager
	add_child(_trigger_manager)


func _process(delta: float) -> void:
	_tick_update(delta)


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
		# 先触发 on_removed 链（在注销前）
		if target_effects.has(effect_type):
			var expiring_effect: StatusEffectData = target_effects[effect_type]
			if _trigger_manager and expiring_effect.chains.size() > 0:
				_trigger_manager.fire_on_removed(expiring_effect)
			_unregister_effect_chains(expiring_effect)
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

	# === Atom 链解析与注册 ===
	_resolve_and_register_chains(effect)

	EventBus.status_applied.emit({
		"target": target,
		"type": type,
		"layer": effect.layer,
		"source": source,
	})

	# 触发 on_applied 链
	if _trigger_manager and effect.chains.size() > 0:
		_trigger_manager.fire_on_applied(effect)

	return effect


func remove_status(target: Object, type: String, source: String = "manual") -> void:
	var target_id: int = target.get_instance_id()
	if not _statuses.has(target_id):
		return
	if not _statuses[target_id].has(type):
		return

	var effect: StatusEffectData = _statuses[target_id][type]

	# 先触发 on_removed 链（在注销前，否则链已被移除）
	if _trigger_manager and effect.chains.size() > 0:
		_trigger_manager.fire_on_removed(effect)

	_unregister_effect_chains(effect)

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
		var effect: StatusEffectData = _statuses[target_id][type]
		_unregister_effect_chains(effect)
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
	# 注销所有原子链
	if _trigger_manager:
		_trigger_manager.clear_all()
	_active_modifiers = { "growth": {}, "speed": {}, "hit_threshold": {}, "food_drop": {} }

	# 断开所有载体信号
	for target_id in _id_to_target:
		var target: Object = _id_to_target[target_id]
		_disconnect_carrier(target, target_id)
	_statuses.clear()
	_id_to_target.clear()


## 获取活跃修改器值（供 LengthSystem 等外部系统查询）
func get_modifier(modifier_type: String, target: Object, default_value: float = 1.0) -> float:
	if not _active_modifiers.has(modifier_type):
		return default_value
	var tid: int = target.get_instance_id()
	return _active_modifiers[modifier_type].get(tid, default_value)


## 设置活跃修改器值（供原子调用）
func set_modifier(modifier_type: String, target: Object, value: float) -> void:
	if not _active_modifiers.has(modifier_type):
		_active_modifiers[modifier_type] = {}
	_active_modifiers[modifier_type][target.get_instance_id()] = value


## 清除活跃修改器值（供原子调用）
func clear_modifier(modifier_type: String, target: Object) -> void:
	if _active_modifiers.has(modifier_type):
		_active_modifiers[modifier_type].erase(target.get_instance_id())


# === 内部方法 ===

func _resolve_and_register_chains(effect: StatusEffectData) -> void:
	if _chain_resolver == null or _trigger_manager == null:
		return
	var cfg_data: Dictionary = ConfigManager.get_status_effect(effect.type)
	# 只有配置中有 entity_effects/tile_effects/trail_effects 时才解析
	if not cfg_data.has("entity_effects") and not cfg_data.has("tile_effects") and not cfg_data.has("trail_effects"):
		return

	var chains: Array = _chain_resolver.resolve_all(cfg_data)
	if chains.is_empty():
		return

	effect.chains = chains
	_trigger_manager.register_chains(effect, chains)


func _unregister_effect_chains(effect: StatusEffectData) -> void:
	if effect == null:
		return
	if _trigger_manager and effect.chains.size() > 0:
		_trigger_manager.unregister_chains(effect)
	# 清理该 effect carrier 的修改器
	if effect.carrier and is_instance_valid(effect.carrier):
		var tid: int = effect.carrier.get_instance_id()
		for mod_type in _active_modifiers:
			_active_modifiers[mod_type].erase(tid)

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
