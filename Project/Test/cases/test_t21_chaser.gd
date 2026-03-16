extends RefCounted
## T21 测试：追踪者（Chaser）行为


func run(t) -> void:
	# --- 文件存在性 ---
	t.assert_file_exists("res://entities/enemies/brains/chaser_brain.gd")

	# --- ChaserBrain 基本检查 ---
	var cb := ChaserBrain.new()
	t.assert_true(cb is EnemyBrain, "ChaserBrain extends EnemyBrain")
	t.assert_true(cb.has_method("evaluate_self_preservation"), "has evaluate_self_preservation")
	t.assert_true(cb.has_method("evaluate_threat_response"), "has evaluate_threat_response")
	t.assert_true(cb.has_method("evaluate_tracking"), "has evaluate_tracking")
	t.assert_true(cb.has_method("evaluate_default"), "has evaluate_default")

	# --- 准备 ---
	GridWorld.init_grid(40, 22)

	# 放置蛇段用于上下文
	var snake_seg := SnakeSegment.new()
	snake_seg.segment_type = SnakeSegment.HEAD
	snake_seg.place_on_grid(Vector2i(5, 10))

	# === 追踪行为：向蛇头移动 ===
	var chaser := Enemy.new()
	chaser.setup_from_config("chaser")
	chaser.place_on_grid(Vector2i(10, 10))

	t.assert_true(chaser.brain is ChaserBrain, "chaser has ChaserBrain")
	t.assert_eq(chaser.enemy_type, "chaser", "enemy_type == chaser")

	var ctx := EnemyBrain.build_context(chaser)
	t.assert_eq(ctx.get("snake_head"), Vector2i(5, 10), "context has correct snake_head")

	var decision := chaser.brain.decide(chaser, ctx)
	t.assert_eq(decision.get("action"), "move", "chaser decides to move")
	# 从(10,10)向(5,10)追踪，应该向左移动
	t.assert_eq(decision.get("direction"), Vector2i(-1, 0), "chaser moves towards snake head (left)")

	# === 多步追踪 ===
	var start_pos := chaser.grid_position
	chaser._execute_decision(decision)
	t.assert_eq(chaser.grid_position, Vector2i(9, 10), "chaser moved to (9,10)")

	# === config 检查 ===
	var cfg_node = Engine.get_main_loop().root.get_node_or_null("ConfigManager")
	if cfg_node:
		var cfg: Dictionary = cfg_node.get_enemy_type("chaser")
		t.assert_eq(cfg.get("hp"), 1, "config: hp == 1")
		t.assert_eq(cfg.get("attack_cost"), 1, "config: attack_cost == 1")
		t.assert_eq(cfg.get("threat_range"), 3, "config: threat_range == 3")
		t.assert_eq(cfg.get("threat_speed_bonus"), 1, "config: threat_speed_bonus == 1")
		var expected_color := Color.from_string(cfg.get("color", "#FF3366"), Color.WHITE)
		t.assert_eq(chaser.enemy_color, expected_color, "chaser color from config")

	# === 威胁响应：蛇头在3格内时 threat_active ===
	# 从(9,10)到蛇头(5,10)距离=4，不在范围内
	ctx = EnemyBrain.build_context(chaser)
	var threat_decision := chaser.brain.evaluate_threat_response(chaser, ctx)
	t.assert_true(threat_decision.is_empty(), "dist=4: no threat response (range=3)")

	# 移到(8,10)距离=3，在范围内
	chaser.remove_from_grid()
	chaser.place_on_grid(Vector2i(8, 10))
	ctx = EnemyBrain.build_context(chaser)
	threat_decision = chaser.brain.evaluate_threat_response(chaser, ctx)
	t.assert_true(not threat_decision.is_empty(), "dist=3: threat response active")
	t.assert_true(threat_decision.get("threat_active", false), "threat_active == true")
	t.assert_eq(threat_decision.get("direction"), Vector2i(-1, 0), "threat: still moves towards snake")

	# === 回避状态格 ===
	var tile_mgr := StatusTileManager.new()
	Engine.get_main_loop().root.add_child(tile_mgr)
	var sem = Engine.get_main_loop().root.get_node_or_null("StatusEffectManager")
	var old_tile_mgr = null
	if sem:
		old_tile_mgr = sem.tile_manager
		sem.tile_manager = tile_mgr

	chaser.remove_from_grid()
	chaser.place_on_grid(Vector2i(10, 10))

	# 在追踪方向(左)放火焰格
	tile_mgr.place_tile(Vector2i(9, 10), "fire")

	ctx = EnemyBrain.build_context(chaser)
	decision = chaser.brain.decide(chaser, ctx)
	t.assert_eq(decision.get("action"), "move", "avoidance: still moves")
	# 应避开(9,10)的火焰格，选择绕行方向
	var avoid_dir: Vector2i = decision.get("direction", Vector2i.ZERO)
	t.assert_true(avoid_dir != Vector2i(-1, 0), "avoidance: does not move into fire tile")
	# 应选择上或下（次优绕行方向）
	t.assert_true(avoid_dir == Vector2i(0, -1) or avoid_dir == Vector2i(0, 1) or avoid_dir == Vector2i(1, 0),
		"avoidance: picks alternate direction")

	# === 自保：当前格有状态格 → 逃离 ===
	tile_mgr.clear_all()
	tile_mgr.place_tile(Vector2i(10, 10), "poison")  # 在当前格放毒

	ctx = EnemyBrain.build_context(chaser)
	var self_pres := chaser.brain.evaluate_self_preservation(chaser, ctx)
	t.assert_true(not self_pres.is_empty(), "self-preservation: triggered on dangerous tile")
	t.assert_eq(self_pres.get("action"), "move", "self-preservation: action == move")

	# === 被堵住时随机移动 ===
	tile_mgr.clear_all()
	chaser.remove_from_grid()
	chaser.place_on_grid(Vector2i(1, 1))

	# 堵住3个方向
	var blockers: Array = []
	for bpos in [Vector2i(2, 1), Vector2i(0, 1), Vector2i(1, 2)]:
		var b := GridEntity.new()
		b.blocks_movement = true
		b.place_on_grid(bpos)
		blockers.append(b)

	ctx = EnemyBrain.build_context(chaser)
	decision = chaser.brain.decide(chaser, ctx)
	t.assert_eq(decision.get("action"), "move", "blocked chaser still moves (one dir open)")
	t.assert_eq(decision.get("direction"), Vector2i(0, -1), "only open direction: up")

	for b in blockers:
		b.remove_from_grid()

	# === EnemyManager 生成 chaser ===
	var em := EnemyManager.new()
	var mock_snake := Snake.new()
	Engine.get_main_loop().root.add_child(mock_snake)
	mock_snake.init_snake(Vector2i(5, 5), 3, Constants.DIR_VECTORS[Constants.Direction.RIGHT])
	em.snake = mock_snake

	em.spawn_enemy("chaser")
	if em.current_enemies.size() > 0:
		t.assert_eq(em.current_enemies[0].enemy_type, "chaser", "spawn chaser: type == chaser")
		t.assert_true(em.current_enemies[0].brain is ChaserBrain, "spawn chaser: has ChaserBrain")
	em.clear_enemies()

	# === 清理 ===
	if sem and old_tile_mgr != null:
		sem.tile_manager = old_tile_mgr
	tile_mgr.clear_all()
	tile_mgr.queue_free()
	chaser.remove_from_grid()
	snake_seg.remove_from_grid()
	GridWorld.clear_all()
	mock_snake._clear_segments()
	mock_snake.queue_free()
	em.queue_free()
