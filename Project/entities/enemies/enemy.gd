class_name Enemy
extends GridEntity

var hp: int = 1
var attack_cost: int = 1
var enemy_type: String = "wanderer"
var brain: EnemyBrain = EnemyBrain.new()
var enemy_color: Color = Color(0.8, 0.1, 0.3)
var _color_rect: ColorRect
var _tick_connected: bool = false
var _move_accumulator: float = 0.0


func _init() -> void:
	entity_type = Constants.EntityType.ENEMY
	blocks_movement = false
	is_solid = true
	cell_layer = 1


func _ready() -> void:
	var s: float = Constants.CELL_SIZE * 0.75
	_color_rect = ColorRect.new()
	_color_rect.size = Vector2(s, s)
	_color_rect.position = Vector2(-s / 2, -s / 2)
	_color_rect.color = enemy_color
	add_child(_color_rect)

	if not _tick_connected:
		EventBus.tick_post_process.connect(_on_tick_post_process)
		_tick_connected = true


func setup_from_config(type_id: String) -> void:
	enemy_type = type_id
	brain = _create_brain(type_id)
	var cfg_node = Engine.get_main_loop().root.get_node_or_null("ConfigManager")
	if cfg_node == null:
		return
	var cfg: Dictionary = cfg_node.get_enemy_type(type_id)
	if cfg.is_empty():
		return
	hp = int(cfg.get("hp", 1))
	attack_cost = int(cfg.get("attack_cost", 1))
	var color_hex: String = cfg.get("color", "#CC1A4D")
	enemy_color = Color.from_string(color_hex, Color(0.8, 0.1, 0.3))
	if _color_rect:
		_color_rect.color = enemy_color


func _create_brain(type_id: String) -> EnemyBrain:
	match type_id:
		"wanderer":
			return WandererBrain.new()
		"chaser":
			return ChaserBrain.new()
		"bog_crawler":
			return BogCrawlerBrain.new()
		_:
			return EnemyBrain.new()


func _on_tick_post_process(_tick_index: int) -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return

	# 计算本 tick 有效速度
	var effective_speed: float = _get_effective_speed()

	# 累加器模式：支持小数速度（0.5 = 每 2 tick 移动一次）
	_move_accumulator += effective_speed
	while _move_accumulator >= 1.0:
		_move_accumulator -= 1.0
		if not is_instance_valid(self) or not is_inside_tree():
			break
		var context: Dictionary = EnemyBrain.build_context(self)
		var decision: Dictionary = brain.decide(self, context)
		_execute_decision(decision)


func _get_effective_speed() -> float:
	## 计算本 tick 的有效速度（基础 + 威胁加速 + 毒液加速）
	var cfg_node = Engine.get_main_loop().root.get_node_or_null("ConfigManager")
	if cfg_node == null:
		return 1.0
	var cfg: Dictionary = cfg_node.get_enemy_type(enemy_type)
	var base_speed: float = cfg.get("speed", 1.0)

	# 威胁加速：检查蛇头是否在 threat_range 内
	var threat_bonus: float = float(cfg.get("threat_speed_bonus", 0))
	if threat_bonus > 0.0:
		var threat_range: int = int(cfg.get("threat_range", 3))
		var context: Dictionary = EnemyBrain.build_context(self)
		var snake_head: Vector2i = context.get("snake_head", Vector2i(-1, -1))
		if snake_head != Vector2i(-1, -1):
			var dist: int = Pathfinding.manhattan_distance(grid_position, snake_head)
			if dist <= threat_range:
				base_speed += threat_bonus

	# 毒液格加速
	var poison_bonus := _get_poison_speed_bonus()
	if poison_bonus > 0:
		base_speed += float(poison_bonus)

	return base_speed


func _execute_decision(decision: Dictionary) -> void:
	var action: String = decision.get("action", "idle")
	var dir: Vector2i = decision.get("direction", Vector2i.ZERO)

	if action == "move" and dir != Vector2i.ZERO:
		var new_pos: Vector2i = grid_position + dir
		if GridWorld.is_within_bounds(new_pos) and not GridWorld.is_cell_blocked(new_pos) and not _is_occupied_for_enemy(new_pos):
			var old_pos: Vector2i = grid_position
			remove_from_grid()
			place_on_grid(new_pos)
			EventBus.entity_moved.emit({
				"entity": self,
				"from": old_pos,
				"to": new_pos,
			})

	EventBus.enemy_action_decided.emit({
		"enemy": self,
		"action": action,
		"direction": dir,
	})


func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		die()


func die() -> void:
	if _tick_connected:
		EventBus.tick_post_process.disconnect(_on_tick_post_process)
		_tick_connected = false
	_on_death_effect()
	EventBus.enemy_killed.emit({
		"enemy_def": self,
		"position": grid_position,
		"method": "snake_collision",
	})
	remove_from_grid()
	queue_free()


func _on_death_effect() -> void:
	## 死亡时特殊效果（子类行为通过 config 驱动）
	var cfg_node = Engine.get_main_loop().root.get_node_or_null("ConfigManager")
	if cfg_node == null:
		return
	var cfg: Dictionary = cfg_node.get_enemy_type(enemy_type)
	var death_tiles: int = int(cfg.get("death_poison_tiles", 0))
	if death_tiles <= 0:
		return

	var sem = Engine.get_main_loop().root.get_node_or_null("StatusEffectManager")
	if sem == null or sem.tile_manager == null:
		return
	var tile_mgr: StatusTileManager = sem.tile_manager
	var pos: Vector2i = grid_position

	# 在死亡位置放第一格毒
	tile_mgr.place_tile(pos, "poison")
	var placed: int = 1

	# 在相邻格随机放剩余毒液格
	var neighbors: Array[Vector2i] = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var np: Vector2i = pos + d
		if GridWorld.is_within_bounds(np):
			neighbors.append(np)
	neighbors.shuffle()
	for np in neighbors:
		if placed >= death_tiles:
			break
		tile_mgr.place_tile(np, "poison")
		placed += 1


func _get_poison_speed_bonus() -> int:
	## 检查是否在毒液格上并返回额外移动次数
	var cfg_node = Engine.get_main_loop().root.get_node_or_null("ConfigManager")
	if cfg_node == null:
		return 0
	var cfg: Dictionary = cfg_node.get_enemy_type(enemy_type)
	var bonus: int = int(cfg.get("poison_speed_bonus", 0))
	if bonus <= 0:
		return 0

	var sem = Engine.get_main_loop().root.get_node_or_null("StatusEffectManager")
	if sem == null or sem.tile_manager == null:
		return 0
	if sem.tile_manager.has_tile(grid_position, "poison"):
		return bonus
	return 0


static func _is_occupied_for_enemy(pos: Vector2i) -> bool:
	var entities: Array = GridWorld.get_entities_at(pos)
	for e in entities:
		if e is Enemy or e is Food:
			return true
	return false
