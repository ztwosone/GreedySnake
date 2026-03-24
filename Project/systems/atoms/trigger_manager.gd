class_name TriggerManager
extends Node
## 触发器管理器
## 监听 EventBus 信号和内部计时器，触发匹配的 EffectChain。

var atom_executor: AtomExecutor = AtomExecutor.new()

# === 活跃链注册表 ===
# { StatusEffectData.get_instance_id() → { "effect": StatusEffectData, "chains": Array[EffectChain] } }
var _active_entries: Dictionary = {}

# === 延迟执行队列 ===
var _delayed_queue: Array = []  # [{ "chain": EffectChain, "ctx": AtomContext, "delay": float }]

# === 系统引用 ===
var effect_mgr: Node = null
var tile_mgr = null
var tick_mgr: Node = null
var enemy_mgr: Node = null
var food_mgr: Node = null


func _ready() -> void:
	_connect_signals()


func _process(delta: float) -> void:
	_process_interval_chains(delta)
	_process_delayed_queue(delta)


# === 链注册/注销 ===

func register_chains(effect: Object, chains: Array) -> void:
	if chains.is_empty():
		return
	var eid: int = effect.get_instance_id()
	_active_entries[eid] = {
		"effect": effect,
		"chains": chains,
	}
	# 设置 owner 引用
	for chain in chains:
		chain._owner_effect = effect


func unregister_chains(effect: Object) -> void:
	var eid: int = effect.get_instance_id()
	_active_entries.erase(eid)


func clear_all() -> void:
	_active_entries.clear()
	_delayed_queue.clear()


# === 内部：信号连接 ===

func _connect_signals() -> void:
	var eb = EventBus
	if eb == null:
		return

	# 安全连接辅助
	var signals_to_connect := {
		"tick_post_process": "_on_tick",
		"status_applied": "_on_status_applied",
		"status_removed": "_on_status_removed",
		"status_expired": "_on_status_expired",
		"status_layer_changed": "_on_layer_changed",
		"entity_entered_status_tile": "_on_entity_enter_tile",
		"snake_food_eaten": "_on_food_eaten",
		"enemy_killed": "_on_enemy_killed",
		"snake_died": "_on_snake_died",
		"snake_hit_enemy": "_on_head_hit",
		"length_decrease_requested": "_on_length_decrease",
		"snake_moved": "_on_snake_moved",
		"entity_moved": "_on_entity_moved",
		"reaction_triggered": "_on_reaction_triggered",
	}

	for sig_name in signals_to_connect:
		if eb.has_signal(sig_name):
			var method_name: String = signals_to_connect[sig_name]
			if has_method(method_name) and not eb.is_connected(sig_name, Callable(self, method_name)):
				eb.connect(sig_name, Callable(self, method_name))


# === 内部：interval 链处理 ===

func _process_interval_chains(delta: float) -> void:
	for eid in _active_entries:
		var entry: Dictionary = _active_entries[eid]
		var effect = entry["effect"]
		if not is_instance_valid(effect):
			continue
		var chains: Array = entry["chains"]
		for chain in chains:
			if chain.trigger == "on_interval" and chain._active:
				if chain.advance_interval(delta):
					var ctx := _build_context(effect)
					ctx.delta = delta
					atom_executor.execute_chain(chain, ctx)


# === 内部：延迟队列处理 ===

func _process_delayed_queue(delta: float) -> void:
	var remaining: Array = []
	for item in _delayed_queue:
		item["delay"] -= delta
		if item["delay"] <= 0.0:
			atom_executor.execute_chain(item["chain"], item["ctx"])
		else:
			remaining.append(item)
	_delayed_queue = remaining


## 添加延迟执行
func queue_delayed(chain: EffectChain, ctx: AtomContext, delay: float) -> void:
	_delayed_queue.append({ "chain": chain, "ctx": ctx, "delay": delay })


# === 事件处理：按触发器类型匹配链 ===

func _fire_trigger(trigger_name: String, data: Dictionary, filter_fn: Callable = Callable()) -> void:
	for eid in _active_entries:
		var entry: Dictionary = _active_entries[eid]
		var effect = entry["effect"]
		if not is_instance_valid(effect):
			continue
		for chain in entry["chains"]:
			if chain.trigger == trigger_name and chain._active:
				if filter_fn.is_valid() and not filter_fn.call(chain, effect, data):
					continue
				var ctx := _build_context(effect)
				ctx.params.merge(data, true)
				atom_executor.execute_chain(chain, ctx)


func _on_tick(tick_index: int) -> void:
	_fire_trigger("on_tick", { "tick_index": tick_index })


func _on_status_applied(data: Dictionary) -> void:
	# on_applied 链在 register_chains 时立即触发，不在这里
	pass


func _on_status_removed(data: Dictionary) -> void:
	_fire_trigger("on_removed", data, func(chain, effect, d):
		return effect.get("type") == d.get("type") and effect.get("carrier") == d.get("target")
	)


func _on_status_expired(data: Dictionary) -> void:
	_fire_trigger("on_removed", data, func(chain, effect, d):
		return effect.get("type") == d.get("type") and effect.get("carrier") == d.get("target")
	)


func _on_layer_changed(data: Dictionary) -> void:
	var new_layer: int = int(data.get("new_layer", 0))
	for eid in _active_entries:
		var entry: Dictionary = _active_entries[eid]
		var effect = entry["effect"]
		if not is_instance_valid(effect):
			continue
		if effect.get("type") != data.get("type"):
			continue
		if effect.get("carrier") != data.get("target"):
			continue
		for chain in entry["chains"]:
			if chain.trigger == "on_layer_reach" and chain._active:
				if chain.check_layer_reach(new_layer):
					var ctx := _build_context(effect)
					ctx.params.merge(data, true)
					atom_executor.execute_chain(chain, ctx)


func _on_entity_enter_tile(data: Dictionary) -> void:
	_fire_trigger("on_entity_enter", data)


func _on_food_eaten(data: Dictionary) -> void:
	_fire_trigger("on_food_eaten", data)


func _on_enemy_killed(data: Dictionary) -> void:
	_fire_trigger("on_death", data)
	_fire_trigger("on_kill", data)


func _on_snake_died(data: Dictionary) -> void:
	_fire_trigger("on_death", data)


func _on_head_hit(data: Dictionary) -> void:
	_fire_trigger("on_head_hit", data)


func _on_length_decrease(data: Dictionary) -> void:
	_fire_trigger("on_length_decrease", data)
	_fire_trigger("on_take_damage", data)


func _on_snake_moved(data: Dictionary) -> void:
	_fire_trigger("on_move", data)


func _on_entity_moved(data: Dictionary) -> void:
	_fire_trigger("on_move", data)


func _on_reaction_triggered(data: Dictionary) -> void:
	_fire_trigger("on_status_react", data)


# === 上下文构建 ===

func _build_context(effect) -> AtomContext:
	var ctx := AtomContext.new()
	ctx.effect_data = effect
	ctx.effect_mgr = effect_mgr
	ctx.tile_mgr = tile_mgr
	ctx.tick_mgr = tick_mgr
	ctx.enemy_mgr = enemy_mgr
	ctx.food_mgr = food_mgr

	# 从 effect 获取 carrier 信息
	var carrier = effect.get("carrier") if effect else null
	if is_instance_valid(carrier):
		ctx.source = carrier
		ctx.target = carrier  # 实体效果中，carrier 既是 source 也是 target
		if carrier.get("grid_position") != null:
			ctx.source_position = carrier.grid_position
			ctx.target_position = carrier.grid_position

	# layer 信息
	if effect and effect.get("layer") != null:
		ctx.layer_a = effect.layer

	return ctx


## 立即触发指定 effect 的 on_removed 链（在注销前调用）
func fire_on_removed(effect: Object) -> void:
	var eid: int = effect.get_instance_id()
	if not _active_entries.has(eid):
		return
	var entry: Dictionary = _active_entries[eid]
	for chain in entry["chains"]:
		if chain.trigger == "on_removed" and chain._active:
			var ctx := _build_context(effect)
			atom_executor.execute_chain(chain, ctx)


## 立即触发指定 effect 的 on_applied 链
func fire_on_applied(effect: Object) -> void:
	var eid: int = effect.get_instance_id()
	if not _active_entries.has(eid):
		return
	var entry: Dictionary = _active_entries[eid]
	for chain in entry["chains"]:
		if chain.trigger == "on_applied" and chain._active:
			var ctx := _build_context(effect)
			atom_executor.execute_chain(chain, ctx)
