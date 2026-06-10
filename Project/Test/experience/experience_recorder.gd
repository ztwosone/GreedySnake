extends RefCounted
## 体验录制器（SpecKit 004 T008，设计文档 presentation_design.md §12.1 机器层契约）
## 三通道时间线：event（EventBus 反射全量）/ vfx（VFXManager 仪表缝）/ ui（面板 getter 差分）
## + pending modal 集（*_presented 压栈，*_chosen|_discarded|_skipped 按前缀弹栈）。
## 只听不驱动（§11.1）：录制器不发任何游戏事件。
## 非套件 harness 文件：不得命名 test_*.gd、不得放进 Test/cases/（runner 套件数核对）。

const MODAL_PUSH_SUFFIX: String = "_presented"
const MODAL_POP_SUFFIXES: Array = ["_chosen", "_discarded", "_skipped"]

var _entries: Array = []
var _pending: Array = []
var _observed: Array = []
var _event_bus: Object = null
var _vfx: Object = null
var _tick_source: Object = null
var _event_connections: Array = []
var _vfx_callable: Callable = Callable()


func attach(targets: Dictionary = {}) -> void:
	## targets 注入缝：{event_bus, vfx, tick} 全部可换，默认接全局单例。
	## 0/1 参信号反射捕获；多参信号只有 vfx_invoked（单独走 vfx 通道），其余跳过。
	detach()
	_event_bus = targets.get("event_bus", EventBus)
	_vfx = targets.get("vfx", VFXManager)
	_tick_source = targets.get("tick", TickManager)
	for signal_info in _event_bus.get_signal_list():
		var signal_name: String = str(signal_info.get("name", ""))
		var arg_count: int = (signal_info.get("args", []) as Array).size()
		var callback: Callable
		if arg_count == 0:
			callback = func() -> void:
				_record("event", signal_name, {})
		elif arg_count == 1:
			callback = func(payload: Variant) -> void:
				_record("event", signal_name, payload)
		else:
			continue
		_event_bus.connect(signal_name, callback)
		_event_connections.append({"name": signal_name, "callable": callback})
	if _vfx != null and _vfx.has_signal("vfx_invoked"):
		_vfx_callable = func(fx_name: String, args: Dictionary) -> void:
			_record("vfx", fx_name, args)
		_vfx.connect("vfx_invoked", _vfx_callable)


func detach() -> void:
	## 镜像断连：只断自己连过的连接，已录条目保留
	if _event_bus != null:
		for item in _event_connections:
			var callback: Callable = item.get("callable")
			var signal_name: String = str(item.get("name", ""))
			if _event_bus.is_connected(signal_name, callback):
				_event_bus.disconnect(signal_name, callback)
	_event_connections.clear()
	if _vfx != null and _vfx_callable.is_valid() and _vfx.is_connected("vfx_invoked", _vfx_callable):
		_vfx.disconnect("vfx_invoked", _vfx_callable)
	_vfx_callable = Callable()
	_event_bus = null
	_vfx = null


func observe_panel(panel: Control, getters: Array) -> void:
	## 面板观察：每条已录事件后做 getter+visible 快照差分 → ui 通道条目
	## {tick, channel:"ui", name:"<panel>.<getter> changed", data:{from, to}}
	_observed.append({
		"panel": panel,
		"getters": getters.duplicate(),
		"snapshot": _take_snapshot(panel, getters),
	})


func pending_modals() -> Array:
	return _pending.duplicate(true)


func entries() -> Array:
	return _entries.duplicate()


func slice(from_tick: int, to_tick: int) -> Array:
	## 闭区间 [from_tick, to_tick] 内的条目
	var out: Array = []
	for entry in _entries:
		var tick: int = int(entry.get("tick", 0))
		if tick >= from_tick and tick <= to_tick:
			out.append(entry)
	return out


# ── 内部 ─────────────────────────────────────────────────────────────

func _record(channel: String, entry_name: String, data: Variant) -> void:
	var tick: int = _current_tick()
	_entries.append({"tick": tick, "channel": channel, "name": entry_name, "data": data})
	if channel == "event":
		_update_pending(entry_name, data, tick)
	# ui 差分只跟在 event/vfx 条目后做（ui 条目直接 append，不递归触发扫描）
	_scan_observed(tick)


func _current_tick() -> int:
	if _tick_source != null:
		return int(_tick_source.get("current_tick"))
	return TickManager.current_tick


func _update_pending(event_name: String, data: Variant, tick: int) -> void:
	if event_name.ends_with(MODAL_PUSH_SUFFIX):
		_pending.append({
			"prefix": event_name.trim_suffix(MODAL_PUSH_SUFFIX),
			"name": event_name,
			"data": data,
			"tick": tick,
		})
		return
	for suffix in MODAL_POP_SUFFIXES:
		if event_name.ends_with(suffix):
			_pop_pending(event_name.trim_suffix(suffix))
			return


func _pop_pending(pop_prefix: String) -> void:
	# 精确前缀优先（reward_chosen ↔ reward_presented）
	for i in range(_pending.size() - 1, -1, -1):
		if str(_pending[i].get("prefix", "")) == pop_prefix:
			_pending.remove_at(i)
			return
	# 宽松回退：首 token 相同（如 scale_option_discarded ↔ scale_reward_presented）
	var pop_head: String = pop_prefix.get_slice("_", 0)
	for i in range(_pending.size() - 1, -1, -1):
		if str(_pending[i].get("prefix", "")).get_slice("_", 0) == pop_head:
			_pending.remove_at(i)
			return


func _take_snapshot(panel: Control, getters: Array) -> Dictionary:
	var snapshot: Dictionary = {"visible": panel.visible}
	for getter in getters:
		var getter_name: String = str(getter)
		if panel.has_method(getter_name):
			snapshot[getter_name] = panel.call(getter_name)
	return snapshot


func _scan_observed(tick: int) -> void:
	for obs in _observed:
		var panel: Variant = obs.get("panel")
		if not is_instance_valid(panel):
			continue
		var before: Dictionary = obs.get("snapshot", {})
		var after: Dictionary = _take_snapshot(panel, obs.get("getters", []))
		for key in after:
			if before.has(key) and before[key] == after[key]:
				continue
			_entries.append({
				"tick": tick,
				"channel": "ui",
				"name": "%s.%s changed" % [panel.name, key],
				"data": {"from": before.get(key), "to": after[key]},
			})
		obs["snapshot"] = after
