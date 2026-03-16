extends RefCounted
## T20 测试：游荡者（Wanderer）行为


func run(t) -> void:
	# --- 文件存在性 ---
	t.assert_file_exists("res://entities/enemies/brains/wanderer_brain.gd")

	# --- WandererBrain 基本检查 ---
	var wb := WandererBrain.new()
	t.assert_true(wb is EnemyBrain, "WandererBrain extends EnemyBrain")
	t.assert_true(wb is RefCounted, "WandererBrain is RefCounted")
	t.assert_true(wb.has_method("evaluate_default"), "has evaluate_default")

	# --- 准备 ---
	GridWorld.init_grid(40, 22)

	# === 基本移动测试 ===
	var enemy := Enemy.new()
	enemy.setup_from_config("wanderer")
	enemy.place_on_grid(Vector2i(20, 10))

	t.assert_true(enemy.brain is WandererBrain, "wanderer has WandererBrain")

	var ctx := EnemyBrain.build_context(enemy)
	var decision := enemy.brain.decide(enemy, ctx)
	t.assert_eq(decision.get("action"), "move", "wanderer default action == move")
	var dir: Vector2i = decision.get("direction", Vector2i.ZERO)
	t.assert_true(dir != Vector2i.ZERO, "wanderer moves (direction != ZERO)")

	# 方向必须是合法的4方向之一
	var valid_dirs: Array[Vector2i] = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	t.assert_true(valid_dirs.has(dir), "direction is a valid cardinal direction")

	# === 多次移动：位置变化 ===
	var start_pos := enemy.grid_position
	var positions: Array[Vector2i] = [start_pos]
	for i in range(10):
		ctx = EnemyBrain.build_context(enemy)
		decision = enemy.brain.decide(enemy, ctx)
		enemy._execute_decision(decision)
		positions.append(enemy.grid_position)

	# 至少有一次位置变化（极小概率全部原地不动）
	var moved: bool = false
	for pos in positions:
		if pos != start_pos:
			moved = true
			break
	t.assert_true(moved, "wanderer moved at least once in 10 ticks")

	# 所有位置都在边界内
	var all_in_bounds: bool = true
	for pos in positions:
		if not GridWorld.is_within_bounds(pos):
			all_in_bounds = false
			break
	t.assert_true(all_in_bounds, "all positions within bounds")

	enemy.remove_from_grid()

	# === 碰壁反弹 ===
	var corner_enemy := Enemy.new()
	corner_enemy.setup_from_config("wanderer")
	corner_enemy.place_on_grid(Vector2i(0, 0))

	ctx = EnemyBrain.build_context(corner_enemy)
	decision = corner_enemy.brain.decide(corner_enemy, ctx)
	t.assert_eq(decision.get("action"), "move", "corner enemy still moves")
	var corner_dir: Vector2i = decision.get("direction", Vector2i.ZERO)
	# 在(0,0)只有右和下可走
	t.assert_true(corner_dir == Vector2i(1, 0) or corner_dir == Vector2i(0, 1),
		"corner (0,0): direction is right or down")

	corner_enemy.remove_from_grid()

	# === 不移动到被阻挡的格子 ===
	var blocked_enemy := Enemy.new()
	blocked_enemy.setup_from_config("wanderer")
	blocked_enemy.place_on_grid(Vector2i(10, 10))

	# 堵住3个方向
	var blockers: Array = []
	for bpos in [Vector2i(11, 10), Vector2i(9, 10), Vector2i(10, 11)]:
		var b := GridEntity.new()
		b.blocks_movement = true
		b.place_on_grid(bpos)
		blockers.append(b)

	ctx = EnemyBrain.build_context(blocked_enemy)
	decision = blocked_enemy.brain.decide(blocked_enemy, ctx)
	t.assert_eq(decision.get("direction"), Vector2i(0, -1), "only unblocked direction: up (0,-1)")

	for b in blockers:
		b.remove_from_grid()
	blocked_enemy.remove_from_grid()

	# === 完全被堵时 idle ===
	var trapped_enemy := Enemy.new()
	trapped_enemy.setup_from_config("wanderer")
	trapped_enemy.place_on_grid(Vector2i(10, 10))

	var trap_blockers: Array = []
	for bpos in [Vector2i(11, 10), Vector2i(9, 10), Vector2i(10, 11), Vector2i(10, 9)]:
		var b := GridEntity.new()
		b.blocks_movement = true
		b.place_on_grid(bpos)
		trap_blockers.append(b)

	ctx = EnemyBrain.build_context(trapped_enemy)
	decision = trapped_enemy.brain.decide(trapped_enemy, ctx)
	t.assert_eq(decision.get("action"), "idle", "fully trapped: action == idle")

	for b in trap_blockers:
		b.remove_from_grid()
	trapped_enemy.remove_from_grid()

	# === EnemyManager 默认生成 wanderer ===
	var em := EnemyManager.new()
	var mock_snake := Snake.new()
	Engine.get_main_loop().root.add_child(mock_snake)
	mock_snake.init_snake(Vector2i(5, 5), 3, Constants.DIR_VECTORS[Constants.Direction.RIGHT])
	em.snake = mock_snake

	em.spawn_enemy()
	if em.current_enemies.size() > 0:
		t.assert_eq(em.current_enemies[0].enemy_type, "wanderer", "default spawn: wanderer")
		t.assert_true(em.current_enemies[0].brain is WandererBrain, "default spawn: has WandererBrain")

	em.clear_enemies()

	# === 无视状态格（ignore 类型）===
	var cfg_node = Engine.get_main_loop().root.get_node_or_null("ConfigManager")
	if cfg_node:
		var wcfg: Dictionary = cfg_node.get_enemy_type("wanderer")
		t.assert_eq(wcfg.get("status_response"), "ignore", "wanderer config: status_response == ignore")

	# === 清理 ===
	GridWorld.clear_all()
	mock_snake._clear_segments()
	mock_snake.queue_free()
	em.queue_free()
