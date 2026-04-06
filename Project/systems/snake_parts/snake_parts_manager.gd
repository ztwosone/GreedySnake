extends Node
## 蛇部件管理器
## 管理蛇头/蛇尾的装备/卸载，通过 JSON + Atom Chain 驱动所有行为。

var snake: Node = null                     # Snake 引用
var _trigger_manager: Node = null          # 共用 TriggerManager
var _chain_resolver: Node = null           # 共用 EffectChainResolver

var _active_head: RefCounted = null        # SnakePartData
var _active_tail: RefCounted = null        # SnakePartData (T30)

var PartDataScript: GDScript = load("res://systems/snake_parts/snake_part_data.gd")


func init_manager(p_snake: Node, p_trigger_mgr: Node, p_chain_resolver: Node) -> void:
	snake = p_snake
	_trigger_manager = p_trigger_mgr
	_chain_resolver = p_chain_resolver


## 装备蛇头
func equip_head(head_id: String, level: int = 1) -> bool:
	if not snake or not _trigger_manager or not _chain_resolver:
		return false

	# 先卸载旧蛇头
	if _active_head != null:
		unequip_head()

	# 读取配置
	var cfg: Dictionary = ConfigManager.get_snake_head(head_id, level)
	if cfg.is_empty():
		return false

	# 解析效果链
	var chains: Array = _chain_resolver.resolve_all(cfg)
	if chains.is_empty():
		return false

	# 创建 SnakePartData
	var part_data: RefCounted = PartDataScript.new()
	part_data.init_data("head", head_id, level, snake, chains)

	# 注册到 TriggerManager
	_trigger_manager.register_chains(part_data, chains)
	_active_head = part_data

	# 立即触发 on_applied 链
	_trigger_manager.fire_on_applied(part_data)

	EventBus.emit_signal("snake_head_equipped", {
		"head_id": head_id,
		"level": level,
	})
	return true


## 卸载蛇头
func unequip_head() -> void:
	if _active_head == null:
		return

	# 先触发 on_removed 链（恢复修改器）
	_trigger_manager.fire_on_removed(_active_head)
	# 注销链
	_trigger_manager.unregister_chains(_active_head)

	var old_id: String = _active_head.part_id
	_active_head = null

	EventBus.emit_signal("snake_head_unequipped", {
		"head_id": old_id,
	})


## 获取当前蛇头
func get_active_head() -> RefCounted:
	return _active_head


## 当前是否装备了蛇头
func has_head() -> bool:
	return _active_head != null


## 装备蛇尾
func equip_tail(tail_id: String, level: int = 1) -> bool:
	if not snake or not _trigger_manager or not _chain_resolver:
		return false

	# 先卸载旧蛇尾
	if _active_tail != null:
		unequip_tail()

	# 读取配置
	var cfg: Dictionary = ConfigManager.get_snake_tail(tail_id, level)
	if cfg.is_empty():
		return false

	# 解析效果链
	var chains: Array = _chain_resolver.resolve_all(cfg)
	if chains.is_empty():
		return false

	# 创建 SnakePartData
	var part_data: RefCounted = PartDataScript.new()
	part_data.init_data("tail", tail_id, level, snake, chains)

	# 注册到 TriggerManager
	_trigger_manager.register_chains(part_data, chains)
	_active_tail = part_data

	# 立即触发 on_applied 链
	_trigger_manager.fire_on_applied(part_data)

	EventBus.emit_signal("snake_tail_equipped", {
		"tail_id": tail_id,
		"level": level,
	})
	return true


## 卸载蛇尾
func unequip_tail() -> void:
	if _active_tail == null:
		return

	# 先触发 on_removed 链
	_trigger_manager.fire_on_removed(_active_tail)
	# 注销链
	_trigger_manager.unregister_chains(_active_tail)

	var old_id: String = _active_tail.part_id
	_active_tail = null

	EventBus.emit_signal("snake_tail_unequipped", {
		"tail_id": old_id,
	})


## 获取当前蛇尾
func get_active_tail() -> RefCounted:
	return _active_tail


## 当前是否装备了蛇尾
func has_tail() -> bool:
	return _active_tail != null
