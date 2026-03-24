extends Node

var _runner: Node
var _pass_count: int = 0
var _fail_count: int = 0


func run(runner: Node) -> void:
	_runner = runner

	# --- Enemy entity tests ---
	_runner.assert_file_exists("res://entities/enemies/enemy.gd")

	var enemy = Enemy.new()
	_runner.assert_true(enemy is GridEntity, "Enemy extends GridEntity")
	_runner.assert_true(enemy is Node2D, "Enemy extends Node2D")
	_runner.assert_eq(enemy.entity_type, Constants.EntityType.ENEMY, "entity_type == ENEMY")
	_runner.assert_eq(enemy.blocks_movement, false, "blocks_movement == false")
	_runner.assert_eq(enemy.is_solid, true, "is_solid == true")
	_runner.assert_eq(enemy.cell_layer, 1, "cell_layer == 1")
	_runner.assert_eq(enemy.hp, 1, "hp default == 1")
	_runner.assert_eq(enemy.attack_cost, 1, "attack_cost default == 1")
	_runner.assert_true(enemy.has_method("take_damage"), "has take_damage()")
	_runner.assert_true(enemy.has_method("die"), "has die()")
	enemy.queue_free()

	# --- EnemyManager tests ---
	_runner.assert_file_exists("res://systems/enemy/enemy_manager.gd")

	var em = EnemyManager.new()
	_runner.assert_true(em.has_method("init_enemies"), "has init_enemies()")
	_runner.assert_true(em.has_method("spawn_enemy"), "has spawn_enemy()")
	_runner.assert_true(em.has_method("clear_enemies"), "has clear_enemies()")
	_runner.assert_eq(em.max_enemy_count, 3, "max_enemy_count default == 3")

	# --- Spawn test ---
	GridWorld.clear_all()
	GridWorld.init_grid(20, 11)

	# Create a mock snake for spawn safety distance check
	var tree_root: Node = _runner.get_tree().root
	var snake = Snake.new()
	tree_root.add_child(snake)
	snake.init_snake(Vector2i(5, 5), 3, Constants.DIR_VECTORS[Constants.Direction.RIGHT])

	em.snake = snake
	em.spawn_enemy()
	_runner.assert_eq(em.current_enemies.size(), 1, "spawn_enemy: 1 enemy in list")

	var spawned_enemy: Enemy = em.current_enemies[0]
	_runner.assert_true(
		GridWorld.is_within_bounds(spawned_enemy.grid_position),
		"enemy spawned within bounds"
	)

	# Check spawn safety distance
	var dist: int = abs(spawned_enemy.grid_position.x - 5) + abs(spawned_enemy.grid_position.y - 5)
	_runner.assert_true(dist > 3, "enemy spawned > 3 Manhattan distance from snake head")

	# --- Enemy registered in GridWorld ---
	var entities = GridWorld.get_entities_at(spawned_enemy.grid_position)
	var found_enemy: bool = false
	for e in entities:
		if e == spawned_enemy:
			found_enemy = true
			break
	_runner.assert_true(found_enemy, "enemy registered in GridWorld")

	# --- take_damage and die ---
	var killed_events := []
	var _on_killed = func(data: Dictionary) -> void:
		killed_events.append(data)
	EventBus.enemy_killed.connect(_on_killed)

	var test_enemy = Enemy.new()
	test_enemy.place_on_grid(Vector2i(15, 8))
	test_enemy.take_damage(1)

	_runner.assert_eq(killed_events.size(), 1, "enemy_killed emitted on death")
	_runner.assert_eq(killed_events[0].get("method") if killed_events.size() > 0 else null, "snake_collision", "kill method == snake_collision")

	EventBus.enemy_killed.disconnect(_on_killed)

	# --- Combat: snake_hit_enemy triggers length_decrease_requested ---
	var decrease_events := []
	var _on_decrease = func(data: Dictionary) -> void:
		decrease_events.append(data)
	EventBus.length_decrease_requested.connect(_on_decrease)

	# Manually connect since em not in tree (_ready not called)
	EventBus.snake_hit_enemy.connect(em._on_snake_hit_enemy)
	EventBus.enemy_killed.connect(em._on_enemy_killed)

	var combat_enemy = Enemy.new()
	combat_enemy.place_on_grid(Vector2i(12, 5))
	em.current_enemies.append(combat_enemy)

	EventBus.snake_hit_enemy.emit({"enemy": combat_enemy, "position": Vector2i(12, 5)})

	# 新机制：蛇头吃敌人无消耗，不应发出 length_decrease_requested
	_runner.assert_eq(decrease_events.size(), 0, "no length_decrease on eating enemy (new mechanic)")

	# Enemy should be removed from list (killed) and a new one spawned
	_runner.assert_true(not (combat_enemy in em.current_enemies), "killed enemy removed from list")

	EventBus.length_decrease_requested.disconnect(_on_decrease)
	EventBus.snake_hit_enemy.disconnect(em._on_snake_hit_enemy)
	EventBus.enemy_killed.disconnect(em._on_enemy_killed)

	# --- init_enemies ---
	em.clear_enemies()
	GridWorld.clear_all()
	GridWorld.init_grid(20, 11)
	# Reinit snake (grid was cleared)
	snake.init_snake(Vector2i(5, 5), 3, Constants.DIR_VECTORS[Constants.Direction.RIGHT])
	em.init_enemies(3)
	_runner.assert_eq(em.current_enemies.size(), 3, "init_enemies(3): 3 enemies spawned")

	# All enemies at different positions
	var positions: Array[Vector2i] = []
	for e in em.current_enemies:
		positions.append(e.grid_position)
	var unique: bool = true
	for i in range(positions.size()):
		for j in range(i + 1, positions.size()):
			if positions[i] == positions[j]:
				unique = false
				break
	_runner.assert_true(unique, "all enemies at unique positions")

	# --- clear_enemies ---
	em.clear_enemies()
	_runner.assert_eq(em.current_enemies.size(), 0, "clear_enemies: list empty")

	# Cleanup
	snake._clear_segments()
	snake.queue_free()
	em.queue_free()
	GridWorld.clear_all()
