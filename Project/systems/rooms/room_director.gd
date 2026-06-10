extends Node
## RoomDirector（spec 002 T021，2026-06-11 重验收新增）：房间布场编排器。
## 监听 floor_generated / room_entered（FR-011 EventBus-only）：
## - floor_generated → 缓存楼层号与主题，主题非空时发 floor_theme_set
##   （生成器保持纯函数，主题事件由本节点发射）；
## - room_entered → 清场（clear_enemies/clear_foods）→ 按房型 + 主题权重 +
##   难度修正重新布怪布食：
##   * 仅 clear_enemies 目标房有敌人，预算 = 房 dict enemy_count + 难度 delta，
##     且永不低于 required_count（目标必须可达成）；
##   * EnemyManager 切 room_budget 档（击杀不补怪，房间可被清空，T020 契约）；
##   * 主题敌池经 set_spawn_weights 注入（floor_themes.<id>.enemy_pool_weights，
##     空主题 = 回退 enemy.spawn_weights）；
##   * elite 房 / is_boss 房把敌池映射为 elite_* 变体（enemy_types.elite_*；
##     无变体配置时回退基础型——spec 边界「boss 未配置 → 精英回退」）；
##   * 食物数 = difficulty.floor_table[楼层].food_count + 难度 delta（钳 >= 0）。
## 难度修正钩子（T6 前为零桩）：set_difficulty_scaler() 注入 duck-typed 对象，
## 读 get_enemy_count_delta()/get_food_count_delta()；唯一消费者契约见 plan.md。
## 修饰符注入点（T031 消费）：set_modifier_system() 注入后，布场完成把房 dict
## 转交 apply_modifiers(room)。
## L1/L2 验收场景不含本节点（game_world.gd 以 get_node_or_null 守护），行为不变。

var _enemy_manager: Node = null
var _food_manager: Node = null
var _difficulty_scaler: Object = null
var _modifier_system: Object = null
var _floor_index: int = 1
var _theme_id: String = ""


func _ready() -> void:
	connect_events()


func _exit_tree() -> void:
	disconnect_events()


func setup(enemy_mgr: Node, food_mgr: Node) -> void:
	_enemy_manager = enemy_mgr
	_food_manager = food_mgr


func set_difficulty_scaler(scaler: Object) -> void:
	_difficulty_scaler = scaler


func set_modifier_system(system: Object) -> void:
	_modifier_system = system


func connect_events() -> void:
	if not EventBus.floor_generated.is_connected(_on_floor_generated):
		EventBus.floor_generated.connect(_on_floor_generated)
	if not EventBus.room_entered.is_connected(_on_room_entered):
		EventBus.room_entered.connect(_on_room_entered)


func disconnect_events() -> void:
	if EventBus.floor_generated.is_connected(_on_floor_generated):
		EventBus.floor_generated.disconnect(_on_floor_generated)
	if EventBus.room_entered.is_connected(_on_room_entered):
		EventBus.room_entered.disconnect(_on_room_entered)


func cleanup() -> void:
	disconnect_events()
	_difficulty_scaler = null
	_modifier_system = null
	_floor_index = 1
	_theme_id = ""


func _on_floor_generated(data: Dictionary) -> void:
	_floor_index = int(data.get("floor_index", _floor_index))
	_theme_id = str(data.get("theme_id", ""))
	if _theme_id == "":
		return
	var theme_cfg: Dictionary = ConfigManager.get_floor_theme(_theme_id)
	EventBus.floor_theme_set.emit({
		"theme": _theme_id,
		"pressure": str(theme_cfg.get("pressure", "")),
		"floor_index": _floor_index,
	})


func _on_room_entered(room: Dictionary) -> void:
	if _enemy_manager == null or _food_manager == null:
		return
	if str(room.get("room_id", "")) == "":
		return

	var room_type: String = str(room.get("room_type", ""))
	var room_cfg: Dictionary = ConfigManager.get_room_type(room_type)
	var budget: int = _enemy_budget(room, room_cfg)

	_enemy_manager.respawn_policy = "room_budget"
	_enemy_manager.set_spawn_weights(_spawn_weights_for(room_type, room_cfg))
	_enemy_manager.clear_enemies()
	_enemy_manager.spawn_budget = budget
	_enemy_manager.init_enemies(budget)

	_food_manager.clear_foods()
	_food_manager.init_foods(_food_count())

	if _modifier_system != null and _modifier_system.has_method("apply_modifiers"):
		_modifier_system.apply_modifiers(room)


## 敌人预算：仅 clear_enemies 目标房布敌；难度 delta 后钳到 >= required_count
func _enemy_budget(room: Dictionary, room_cfg: Dictionary) -> int:
	var objective: Dictionary = room.get("objective", {})
	var objective_type: String = str(objective.get("objective_type", room_cfg.get("objective_type", "")))
	if objective_type != "clear_enemies":
		return 0
	var budget: int = int(room.get("enemy_count", room_cfg.get("enemy_count", 0)))
	budget += _scaler_delta("get_enemy_count_delta")
	return maxi(budget, int(objective.get("required_count", room_cfg.get("required_count", 1))))


## 主题敌池（空主题/空池 = 空表回退 enemy.spawn_weights）；精英/boss 房映射 elite_* 变体
func _spawn_weights_for(room_type: String, room_cfg: Dictionary) -> Dictionary:
	var weights: Dictionary = {}
	if _theme_id != "":
		weights = ConfigManager.get_floor_theme(_theme_id).get("enemy_pool_weights", {})
	if room_type == "elite" or bool(room_cfg.get("is_boss", false)):
		var base: Dictionary = weights
		if base.is_empty():
			base = ConfigManager.enemy.get("spawn_weights", {})
		return _elite_variant_weights(base)
	return weights


func _elite_variant_weights(base_weights: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for type_id in base_weights:
		var elite_id: String = "elite_%s" % type_id
		if not ConfigManager.get_enemy_type(elite_id).is_empty():
			result[elite_id] = base_weights[type_id]
	if result.is_empty():
		return base_weights  # 无精英变体配置 → 回退基础型（spec 边界）
	return result


func _food_count() -> int:
	var food_count: int = int(ConfigManager.get_difficulty_floor_params(_floor_index).get("food_count", 3))
	food_count += _scaler_delta("get_food_count_delta")
	return maxi(0, food_count)


func _scaler_delta(method: String) -> int:
	if _difficulty_scaler != null and _difficulty_scaler.has_method(method):
		return int(_difficulty_scaler.call(method))
	return 0
