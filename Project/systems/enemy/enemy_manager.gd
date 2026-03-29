class_name EnemyManager
extends Node

var max_enemy_count: int = 3
var current_enemies: Array[Enemy] = []
var enemy_container: Node2D
var snake: Snake
var food_manager: FoodManager = null
const SPAWN_SAFE_DISTANCE: int = 3


func _ready() -> void:
	EventBus.snake_hit_enemy.connect(_on_snake_hit_enemy)
	EventBus.enemy_killed.connect(_on_enemy_killed)


func init_enemies(count: int) -> void:
	max_enemy_count = count
	for i in range(count):
		spawn_enemy(_pick_random_type())


func spawn_enemy(type_id: String = "wanderer") -> void:
	var empty_cells: Array[Vector2i] = GridWorld.get_empty_cells()
	if empty_cells.is_empty():
		return

	# Filter out cells too close to snake head
	var safe_cells: Array[Vector2i] = []
	var snake_head: Vector2i = snake.body[0] if snake and not snake.body.is_empty() else Vector2i(-100, -100)
	for cell in empty_cells:
		var dist: int = abs(cell.x - snake_head.x) + abs(cell.y - snake_head.y)
		if dist > SPAWN_SAFE_DISTANCE:
			safe_cells.append(cell)

	# Fall back to all empty cells if no safe cells
	var candidates: Array[Vector2i] = safe_cells if not safe_cells.is_empty() else empty_cells
	var pos: Vector2i = candidates[randi() % candidates.size()]

	var enemy := Enemy.new()
	enemy.setup_from_config(type_id)
	enemy.place_on_grid(pos)
	if enemy_container:
		enemy_container.add_child(enemy)
	current_enemies.append(enemy)
	EventBus.enemy_spawned.emit({"enemy_def": enemy, "position": pos, "type": type_id})


func _on_snake_hit_enemy(data: Dictionary) -> void:
	var enemy = data.get("enemy")
	if not enemy or not is_instance_valid(enemy):
		return

	# === 吞噬状态反应 ===
	if snake and not snake.segments.is_empty() and is_instance_valid(snake.segments[0]):
		var head_seg: SnakeSegment = snake.segments[0]
		var head_status: String = head_seg.carried_status
		var enemy_status: String = enemy.carried_status if enemy.carried_status else ""
		if head_status != "" and enemy_status != "" and head_status != enemy_status:
			var reaction_id: String = Enemy._get_reaction_id(head_status, enemy_status)
			if reaction_id != "":
				EventBus.reaction_triggered.emit({
					"reaction_id": reaction_id,
					"position": enemy.grid_position,
					"type_a": head_status,
					"type_b": enemy_status,
				})
			head_seg.clear_carried_status()
			enemy.clear_carried_status()

	# === 吞噬 VFX ===
	# 蛇头 scale bounce
	if snake and not snake.segments.is_empty() and is_instance_valid(snake.segments[0]):
		VFXManager.scale_bounce(snake.segments[0], 1.3, 0.15)
	# 极短暂停（打击感）
	VFXManager.hit_stop(0.02)

	# Snake eats enemy
	enemy.take_damage(enemy.hp)



func _spawn_food_drops(center: Vector2i, count: int) -> void:
	## 在 center 及其周围空格生成食物
	var candidates: Array[Vector2i] = []
	# 中心优先
	if GridWorld.is_within_bounds(center) and GridWorld.get_entities_at(center).is_empty():
		candidates.append(center)
	# 四邻
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var pos: Vector2i = center + dir
		if GridWorld.is_within_bounds(pos) and GridWorld.get_entities_at(pos).is_empty():
			candidates.append(pos)
	# 对角
	for dir in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var pos: Vector2i = center + dir
		if GridWorld.is_within_bounds(pos) and GridWorld.get_entities_at(pos).is_empty():
			candidates.append(pos)
	# 打乱顺序
	candidates.shuffle()
	var spawned: int = 0
	for pos in candidates:
		if spawned >= count:
			break
		food_manager.spawn_food_at(pos)
		spawned += 1


func _on_enemy_killed(data: Dictionary) -> void:
	var enemy = data.get("enemy_def")
	var pos: Vector2i = data.get("position", Vector2i.ZERO)
	# 掉落食物（无论何种方式击杀）
	_drop_food_for_enemy(enemy, pos)
	if enemy and enemy in current_enemies:
		current_enemies.erase(enemy)
	# Respawn to maintain count
	if current_enemies.size() < max_enemy_count:
		spawn_enemy(_pick_random_type())


func _drop_food_for_enemy(enemy: Node, pos: Vector2i) -> void:
	if not food_manager or enemy == null:
		return
	var type_id: String = enemy.get("enemy_type") if enemy.get("enemy_type") else "wanderer"
	var cfg: Dictionary = ConfigManager.get_enemy_type(type_id)
	var drop_count: int = int(cfg.get("drop_food_count", 0))
	if drop_count <= 0:
		return
	_spawn_food_drops(pos, drop_count)


func _pick_random_type() -> String:
	var enemy_cfg: Dictionary = ConfigManager.enemy
	var weights: Dictionary = enemy_cfg.get("spawn_weights", {})
	if weights.is_empty():
		return "wanderer"
	var total: int = 0
	for w in weights.values():
		total += int(w)
	var roll: int = randi() % total
	var accum: int = 0
	for type_id in weights:
		accum += int(weights[type_id])
		if roll < accum:
			return type_id
	return "wanderer"


func spawn_enemy_at(type_id: String, pos: Vector2i) -> Enemy:
	var enemy := Enemy.new()
	enemy.setup_from_config(type_id)
	enemy.place_on_grid(pos)
	if enemy_container:
		enemy_container.add_child(enemy)
	current_enemies.append(enemy)
	EventBus.enemy_spawned.emit({"enemy_def": enemy, "position": pos, "type": type_id})
	return enemy


func clear_enemies() -> void:
	for enemy in current_enemies:
		if is_instance_valid(enemy):
			enemy.remove_from_grid()
			enemy.queue_free()
	current_enemies.clear()
