extends Node
## 邻接共鸣管理器
## 监听鳞片装备/卸载事件，自动激活/停用 tag-pair 共鸣效果链。
## 优先检查 scale-pair override，否则走 tag-pair 匹配。

var snake: Node = null
var _trigger_manager: Node = null
var _chain_resolver: RefCounted = null
var _scale_slot_manager: Node = null

var PartDataScript: GDScript = load("res://systems/snake_parts/snake_part_data.gd")

# 活跃共鸣: { unique_key → SnakePartData }
var _active_resonances: Dictionary = {}

# 已发现共鸣（首次激活标记，用于 UI 提示）
var _discovered_resonances: Dictionary = {}  # resonance_id → true


func init_manager(p_snake: Node, p_trigger_mgr: Node, p_chain_resolver: RefCounted, p_scale_slot_mgr: Node) -> void:
	snake = p_snake
	_trigger_manager = p_trigger_mgr
	_chain_resolver = p_chain_resolver
	_scale_slot_manager = p_scale_slot_mgr
	EventBus.snake_scale_equipped.connect(_on_scale_changed)
	EventBus.snake_scale_unequipped.connect(_on_scale_changed)


func _on_scale_changed(_data: Dictionary) -> void:
	_recalculate_resonances()


func _recalculate_resonances() -> void:
	var desired: Dictionary = {}  # unique_key → { "config": Dictionary, "res_id": String }
	var all_scales: Array = _scale_slot_manager.get_all_scales()

	for i in range(all_scales.size()):
		for j in range(i + 1, all_scales.size()):
			var a = all_scales[i]
			var b = all_scales[j]
			if not _are_adjacent(a.position, b.position):
				continue

			var pair_key: String = _make_pair_key(a.part_id, b.part_id)

			# 1. Check scale-pair override
			var override: Dictionary = ConfigManager.find_scale_resonance_override(a.part_id, b.part_id)
			if not override.is_empty():
				var res_id: String = override.get("resonance_id", pair_key)
				var key: String = res_id + ":" + pair_key
				desired[key] = { "config": override, "res_id": res_id }
				continue

			# 2. Tag-pair: enumerate all cross-tag combinations
			var tags_a: Array = ConfigManager.get_scale_tags(a.part_id)
			var tags_b: Array = ConfigManager.get_scale_tags(b.part_id)
			for tag_a in tags_a:
				for tag_b in tags_b:
					if tag_a == tag_b and tag_a != "physical":
						continue  # 同 tag 不共鸣（physical 除外）
					var res_cfg: Dictionary = ConfigManager.find_tag_resonance(tag_a, tag_b)
					if res_cfg.is_empty():
						continue
					var res_id: String = res_cfg.get("resonance_id", tag_a + "+" + tag_b)
					var key: String = res_id + ":" + pair_key
					if not desired.has(key):
						desired[key] = { "config": res_cfg, "res_id": res_id }

	# Deactivate resonances no longer desired
	for key in _active_resonances.keys():
		if not desired.has(key):
			_deactivate_resonance(key)

	# Activate new resonances
	for key in desired:
		if not _active_resonances.has(key):
			_activate_resonance(key, desired[key]["config"], desired[key]["res_id"])


func _are_adjacent(pos_a: String, pos_b: String) -> bool:
	if pos_a == pos_b:
		return true
	if (pos_a == "front" and pos_b == "middle") or (pos_a == "middle" and pos_b == "front"):
		return true
	if (pos_a == "middle" and pos_b == "back") or (pos_a == "back" and pos_b == "middle"):
		return true
	return false


func _activate_resonance(key: String, config: Dictionary, res_id: String) -> void:
	if not snake or not _trigger_manager or not _chain_resolver:
		return

	var chains: Array = _chain_resolver.resolve_all(config)
	if chains.is_empty():
		return

	var part_data: RefCounted = PartDataScript.new()
	part_data.init_data("resonance", res_id, 1, snake, chains)
	part_data.position = "resonance"

	_trigger_manager.register_chains(part_data, chains)
	_trigger_manager.fire_on_applied(part_data)
	_active_resonances[key] = part_data

	# Discovery mechanic
	var is_new: bool = not _discovered_resonances.has(res_id)
	_discovered_resonances[res_id] = true

	EventBus.resonance_activated.emit({
		"resonance_id": res_id,
		"display_name": config.get("display_name", ""),
		"is_new_discovery": is_new,
	})


func _deactivate_resonance(key: String) -> void:
	if not _active_resonances.has(key):
		return
	var part_data = _active_resonances[key]
	var res_id: String = part_data.part_id

	_trigger_manager.fire_on_removed(part_data)
	_trigger_manager.unregister_chains(part_data)
	_active_resonances.erase(key)

	EventBus.resonance_deactivated.emit({
		"resonance_id": res_id,
	})


func _make_pair_key(a: String, b: String) -> String:
	if a < b:
		return a + "+" + b
	return b + "+" + a


## 获取所有活跃共鸣 ID
func get_active_resonances() -> Array:
	var ids: Array = []
	for key in _active_resonances:
		var part_data = _active_resonances[key]
		if not ids.has(part_data.part_id):
			ids.append(part_data.part_id)
	return ids


## 指定共鸣是否已被发现过
func is_resonance_discovered(res_id: String) -> bool:
	return _discovered_resonances.has(res_id)


## 清除所有活跃共鸣
func clear_all() -> void:
	for key in _active_resonances.keys():
		_deactivate_resonance(key)
	_active_resonances.clear()
