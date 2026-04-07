extends Node
## 蛇鳞槽位管理器
## 管理 front/middle/back 三个位置的鳞片槽位，通过 Atom Chain 驱动效果。

var snake: Node = null
var _trigger_manager: Node = null
var _chain_resolver: RefCounted = null

var PartDataScript: GDScript = load("res://systems/snake_parts/snake_part_data.gd")

# 每个位置的最大槽位数
const MAX_SLOTS: Dictionary = { "front": 2, "middle": 3, "back": 2 }

# 已开放槽位数
var _open_slots: Dictionary = { "front": 1, "middle": 1, "back": 1 }

# 已装备鳞片: { "front": [ScaleData, null], "middle": [null, null, null], "back": [null, null] }
var _slots: Dictionary = {}


func init_manager(p_snake: Node, p_trigger_mgr: Node, p_chain_resolver: RefCounted) -> void:
	snake = p_snake
	_trigger_manager = p_trigger_mgr
	_chain_resolver = p_chain_resolver
	# 初始化空槽位
	for pos in MAX_SLOTS:
		_slots[pos] = []
		for i in range(MAX_SLOTS[pos]):
			_slots[pos].append(null)


## 装备鳞片到指定位置
func equip_scale(position: String, scale_id: String, level: int = 1) -> bool:
	if not snake or not _trigger_manager or not _chain_resolver:
		return false
	if not _slots.has(position):
		return false

	# 找第一个空槽位（在已开放范围内）
	var slot_index: int = -1
	var open_count: int = _open_slots.get(position, 0)
	for i in range(open_count):
		if _slots[position][i] == null:
			slot_index = i
			break
	if slot_index < 0:
		return false  # 没有空槽位

	# 读取配置
	var cfg: Dictionary = ConfigManager.get_snake_scale(scale_id, level)
	if cfg.is_empty():
		return false

	# 解析效果链
	var chains: Array = _chain_resolver.resolve_all(cfg)
	if chains.is_empty():
		return false

	# 创建 SnakePartData
	var part_data: RefCounted = PartDataScript.new()
	part_data.init_data("scale", scale_id, level, snake, chains)
	part_data.position = position

	# 注册到 TriggerManager
	_trigger_manager.register_chains(part_data, chains)
	_slots[position][slot_index] = part_data

	# 触发 on_applied 链
	_trigger_manager.fire_on_applied(part_data)

	EventBus.emit_signal("snake_scale_equipped", {
		"scale_id": scale_id,
		"level": level,
		"position": position,
		"slot_index": slot_index,
	})
	return true


## 卸载指定位置的鳞片
func unequip_scale(position: String, slot_index: int) -> void:
	if not _slots.has(position):
		return
	if slot_index < 0 or slot_index >= _slots[position].size():
		return
	var part_data: RefCounted = _slots[position][slot_index]
	if part_data == null:
		return

	_trigger_manager.fire_on_removed(part_data)
	_trigger_manager.unregister_chains(part_data)

	var old_id: String = part_data.part_id
	_slots[position][slot_index] = null

	EventBus.emit_signal("snake_scale_unequipped", {
		"scale_id": old_id,
		"position": position,
	})


## 升级鳞片（卸载旧等级，装备新等级）
func upgrade_scale(position: String, slot_index: int, new_level: int) -> bool:
	if not _slots.has(position):
		return false
	if slot_index < 0 or slot_index >= _slots[position].size():
		return false
	var old: RefCounted = _slots[position][slot_index]
	if old == null:
		return false

	var scale_id: String = old.part_id
	# 卸载旧
	unequip_scale(position, slot_index)
	# 装备新等级到同一槽位
	var cfg: Dictionary = ConfigManager.get_snake_scale(scale_id, new_level)
	if cfg.is_empty():
		return false
	var chains: Array = _chain_resolver.resolve_all(cfg)
	if chains.is_empty():
		return false

	var part_data: RefCounted = PartDataScript.new()
	part_data.init_data("scale", scale_id, new_level, snake, chains)
	part_data.position = position
	_trigger_manager.register_chains(part_data, chains)
	_slots[position][slot_index] = part_data
	_trigger_manager.fire_on_applied(part_data)

	EventBus.emit_signal("snake_scale_equipped", {
		"scale_id": scale_id,
		"level": new_level,
		"position": position,
		"slot_index": slot_index,
	})
	return true


## 获取指定位置所有鳞片
func get_scales(position: String) -> Array:
	if not _slots.has(position):
		return []
	var result: Array = []
	for s in _slots[position]:
		if s != null:
			result.append(s)
	return result


## 获取所有已装备鳞片
func get_all_scales() -> Array:
	var result: Array = []
	for pos in _slots:
		for s in _slots[pos]:
			if s != null:
				result.append(s)
	return result


## 指定位置是否有空槽位
func has_open_slot(position: String) -> bool:
	if not _slots.has(position):
		return false
	var open_count: int = _open_slots.get(position, 0)
	for i in range(open_count):
		if _slots[position][i] == null:
			return true
	return false


## 开放新槽位
func open_slot(position: String) -> bool:
	if not _slots.has(position):
		return false
	var current: int = _open_slots.get(position, 0)
	if current >= MAX_SLOTS.get(position, 0):
		return false
	_open_slots[position] = current + 1
	return true


## 卸载所有鳞片
func clear_all() -> void:
	for pos in _slots:
		for i in range(_slots[pos].size()):
			if _slots[pos][i] != null:
				unequip_scale(pos, i)
