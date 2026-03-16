class_name EnemyManager
extends Node

var max_enemy_count: int = 3
var current_enemies: Array[Enemy] = []
var enemy_container: Node2D
var snake: Snake
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

	# Snake pays attack cost
	var cost: int = enemy.attack_cost if enemy.get("attack_cost") else 1
	EventBus.length_decrease_requested.emit({"amount": cost, "source": "enemy_combat"})

	# Enemy takes damage
	enemy.take_damage(1)


func _on_enemy_killed(data: Dictionary) -> void:
	var enemy = data.get("enemy_def")
	if enemy and enemy in current_enemies:
		current_enemies.erase(enemy)
	# Respawn to maintain count
	if current_enemies.size() < max_enemy_count:
		spawn_enemy(_pick_random_type())


func _pick_random_type() -> String:
	var cfg_node = Engine.get_main_loop().root.get_node_or_null("ConfigManager")
	if cfg_node == null:
		return "wanderer"
	var enemy_cfg: Dictionary = cfg_node.enemy
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


func clear_enemies() -> void:
	for enemy in current_enemies:
		if is_instance_valid(enemy):
			enemy.remove_from_grid()
			enemy.queue_free()
	current_enemies.clear()
