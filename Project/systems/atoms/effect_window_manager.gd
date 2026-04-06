extends Node
## 效果窗口管理器
## 管理持续 N tick 的效果窗口，提供规则查询接口。

var atom_executor: AtomExecutor = null
var atom_registry: Node = null  ## AtomRegistry
var effect_mgr: Node = null    ## StatusEffectManager
var enemy_mgr: Node = null     ## EnemyManager

# === 内部状态 ===
var _active_windows: Dictionary = {}       # { window_id -> EffectWindow }
var _cancel_connections: Dictionary = {}   # { window_id -> Callable }


func _ready() -> void:
	EventBus.tick_post_process.connect(_on_tick)


## 开启/刷新窗口
func open_window(window_id: String, config: Dictionary, owner: Object) -> void:
	# 如果已存在同 id 窗口，刷新 remaining_ticks
	if _active_windows.has(window_id):
		var existing: RefCounted = _active_windows[window_id]
		existing.remaining_ticks = int(config.get("duration_ticks", existing.duration_ticks))
		existing.owner = owner
		return

	var WindowScript: GDScript = load("res://systems/atoms/effect_window.gd")
	var window: RefCounted = WindowScript.new()
	window.init_from_config(window_id, config, owner)
	_active_windows[window_id] = window

	# cancel_on 动态信号连接
	if window.cancel_on != "":
		var cancel_callable := func(_d = null) -> void:
			cancel_window(window_id, "signal")
		if EventBus.has_signal(window.cancel_on):
			EventBus.connect(window.cancel_on, cancel_callable)
			_cancel_connections[window_id] = cancel_callable

	EventBus.window_opened.emit({
		"window_id": window_id,
		"duration_ticks": window.duration_ticks,
		"owner": owner,
	})


## 取消窗口（不触发 on_expire，但触发 on_cancel）
func cancel_window(window_id: String, reason: String = "manual") -> void:
	if not _active_windows.has(window_id):
		return
	var window: RefCounted = _active_windows[window_id]
	_disconnect_cancel(window_id, window)
	_active_windows.erase(window_id)

	# 执行 on_cancel 原子链（信号触发的取消才执行，手动/原子取消不执行）
	if window.on_cancel.size() > 0 and reason == "signal" and atom_executor != null and atom_registry != null:
		_execute_cancel_chain(window)

	EventBus.window_cancelled.emit({
		"window_id": window_id,
		"owner": window.owner,
		"reason": reason,
	})


## 查询窗口是否活跃
func is_active(window_id: String) -> bool:
	return _active_windows.has(window_id)


## 查询规则值（扫描所有活跃窗口，返回第一个匹配的）
func get_rule(rule_name: String, default_value = null):
	for wid in _active_windows:
		var window: RefCounted = _active_windows[wid]
		if window.rules.has(rule_name):
			return window.rules[rule_name]
	return default_value


## 查询指定窗口的规则值
func get_window_rule(window_id: String, rule_name: String, default_value = null):
	if not _active_windows.has(window_id):
		return default_value
	return _active_windows[window_id].rules.get(rule_name, default_value)


## 清理所有窗口
func clear_all() -> void:
	for wid in _active_windows.keys():
		var window: RefCounted = _active_windows[wid]
		_disconnect_cancel(wid, window)
	_active_windows.clear()
	_cancel_connections.clear()


# === Tick 处理 ===

func _on_tick(_tick_index: int) -> void:
	var expired_ids: Array = []
	for wid in _active_windows:
		var window: RefCounted = _active_windows[wid]
		# owner 失效 → 安全清理
		if window.owner != null and not is_instance_valid(window.owner):
			expired_ids.append(wid)
			continue
		window.remaining_ticks -= 1
		if window.remaining_ticks <= 0:
			expired_ids.append(wid)

	for wid in expired_ids:
		_expire_window(wid)


func _expire_window(window_id: String) -> void:
	if not _active_windows.has(window_id):
		return
	var window: RefCounted = _active_windows[window_id]
	_disconnect_cancel(window_id, window)
	_active_windows.erase(window_id)

	# 执行 on_expire 原子列表
	if window.on_expire.size() > 0 and atom_executor != null and atom_registry != null:
		_execute_expire_chain(window)

	EventBus.window_expired.emit({
		"window_id": window_id,
		"owner": window.owner,
	})


func _execute_expire_chain(window: RefCounted) -> void:
	var ctx := AtomContext.new()
	ctx.source = window.owner if is_instance_valid(window.owner) else null
	ctx.target = ctx.source
	if ctx.source and ctx.source.get("grid_position") != null:
		ctx.source_position = ctx.source.grid_position
		ctx.target_position = ctx.source.grid_position
	# 系统引用（burst_carried_status 等原子需要）
	ctx.effect_mgr = effect_mgr
	ctx.enemy_mgr = enemy_mgr
	ctx.window_mgr = self

	for atom_def in window.on_expire:
		if atom_def is not Dictionary:
			continue
		var atom_name: String = atom_def.get("atom", "")
		if atom_name.is_empty():
			continue
		var params: Dictionary = atom_def.duplicate()
		params.erase("atom")
		var atom: AtomBase = atom_registry.create(atom_name, params)
		if atom == null:
			continue
		atom.execute(ctx)


func _execute_cancel_chain(window: RefCounted) -> void:
	var ctx := AtomContext.new()
	ctx.source = window.owner if is_instance_valid(window.owner) else null
	ctx.target = ctx.source
	if ctx.source and ctx.source.get("grid_position") != null:
		ctx.source_position = ctx.source.grid_position
		ctx.target_position = ctx.source.grid_position
	ctx.effect_mgr = effect_mgr
	ctx.enemy_mgr = enemy_mgr
	ctx.window_mgr = self

	for atom_def in window.on_cancel:
		if atom_def is not Dictionary:
			continue
		var atom_name: String = atom_def.get("atom", "")
		if atom_name.is_empty():
			continue
		var params: Dictionary = atom_def.duplicate()
		params.erase("atom")
		var atom: AtomBase = atom_registry.create(atom_name, params)
		if atom == null:
			continue
		atom.execute(ctx)


func _disconnect_cancel(window_id: String, window: RefCounted) -> void:
	if _cancel_connections.has(window_id):
		var callable: Callable = _cancel_connections[window_id]
		if window.cancel_on != "" and EventBus.has_signal(window.cancel_on):
			if EventBus.is_connected(window.cancel_on, callable):
				EventBus.disconnect(window.cancel_on, callable)
		_cancel_connections.erase(window_id)
