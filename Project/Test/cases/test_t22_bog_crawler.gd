extends RefCounted
## T22 测试：毒沼匍匐者（Bog Crawler）行为


func run(t) -> void:
	# --- 文件存在性 ---
	t.assert_file_exists("res://entities/enemies/brains/bog_crawler_brain.gd")

	# --- BogCrawlerBrain 基本检查 ---
	var bcb := BogCrawlerBrain.new()
	t.assert_true(bcb is EnemyBrain, "BogCrawlerBrain extends EnemyBrain")
	t.assert_true(bcb.has_method("evaluate_self_preservation"), "has evaluate_self_preservation")
	t.assert_true(bcb.has_method("evaluate_status_response"), "has evaluate_status_response")
	t.assert_true(bcb.has_method("evaluate_default"), "has evaluate_default")

	# --- 准备 ---
	GridWorld.init_grid(40, 22)

	var snake_seg := SnakeSegment.new()
	snake_seg.segment_type = SnakeSegment.HEAD
	snake_seg.place_on_grid(Vector2i(5, 5))

	# === 基本设置 ===
	var bc := Enemy.new()
	bc.setup_from_config("bog_crawler")
	bc.place_on_grid(Vector2i(20, 10))

	t.assert_true(bc.brain is BogCrawlerBrain, "bog_crawler has BogCrawlerBrain")
	t.assert_eq(bc.enemy_type, "bog_crawler", "enemy_type == bog_crawler")
	t.assert_eq(bc.hp, 1, "bog_crawler hp == 1")

	# === config 检查 ===
	var cfg_node = ConfigManager
	if cfg_node:
		var cfg: Dictionary = cfg_node.get_enemy_type("bog_crawler")
		t.assert_eq(cfg.get("hp"), 1, "config: hp == 1")
		t.assert_eq(cfg.get("attack_cost"), 1, "config: attack_cost == 1")
		t.assert_eq(cfg.get("poison_speed_bonus"), 2, "config: poison_speed_bonus == 2")
		t.assert_eq(cfg.get("death_poison_tiles"), 3, "config: death_poison_tiles == 3")
		var expected_color := Color.from_string(cfg.get("color", "#2D5A27"), Color.WHITE)
		t.assert_eq(bc.enemy_color, expected_color, "bog_crawler color from config")

	# === 无毒液格时随机移动 ===
	var ctx := EnemyBrain.build_context(bc)
	var decision := bc.brain.decide(bc, ctx)
	t.assert_eq(decision.get("action"), "move", "no poison tiles: still moves")
	var dir: Vector2i = decision.get("direction", Vector2i.ZERO)
	t.assert_true(dir != Vector2i.ZERO, "no poison tiles: direction != ZERO")

	# === 趋向毒液格 ===
	var tile_mgr := StatusTileManager.new()
	Engine.get_main_loop().root.add_child(tile_mgr)
	var sem = StatusEffectManager
	var old_tile_mgr = null
	if sem:
		old_tile_mgr = sem.tile_manager
		sem.tile_manager = tile_mgr

	# 在(15, 10)放毒液格，bog_crawler在(20, 10)，应向左移动
	tile_mgr.place_tile(Vector2i(15, 10), "poison")

	ctx = EnemyBrain.build_context(bc)
	decision = bc.brain.decide(bc, ctx)
	t.assert_eq(decision.get("action"), "move", "seek poison: action == move")
	t.assert_eq(decision.get("direction"), Vector2i(-1, 0), "seek poison: moves left towards poison tile")

	# === 已在毒液格上时回退到默认移动 ===
	tile_mgr.clear_all()
	bc.remove_from_grid()
	bc.place_on_grid(Vector2i(15, 10))
	tile_mgr.place_tile(Vector2i(15, 10), "poison")

	ctx = EnemyBrain.build_context(bc)
	decision = bc.brain.decide(bc, ctx)
	t.assert_eq(decision.get("action"), "move", "on poison: still moves (default)")
	# 不再趋向自己当前格，用默认随机移动

	# === 火焰格自保 ===
	tile_mgr.clear_all()
	bc.remove_from_grid()
	bc.place_on_grid(Vector2i(10, 10))
	tile_mgr.place_tile(Vector2i(10, 10), "fire")  # 当前格有火

	ctx = EnemyBrain.build_context(bc)
	var self_pres := bc.brain.evaluate_self_preservation(bc, ctx)
	t.assert_true(not self_pres.is_empty(), "self-preservation: triggered on fire tile")
	t.assert_eq(self_pres.get("action"), "move", "self-preservation: action == move")
	# 应该逃离火焰格
	var escape_dir: Vector2i = self_pres.get("direction", Vector2i.ZERO)
	var escape_target: Vector2i = Vector2i(10, 10) + escape_dir
	t.assert_true(not tile_mgr.has_tile(escape_target, "fire"), "self-preservation: escapes to non-fire tile")

	# === 非火焰格不触发自保 ===
	tile_mgr.clear_all()
	tile_mgr.place_tile(Vector2i(10, 10), "poison")  # 毒液格不触发自保
	ctx = EnemyBrain.build_context(bc)
	self_pres = bc.brain.evaluate_self_preservation(bc, ctx)
	t.assert_true(self_pres.is_empty(), "self-preservation: NOT triggered on poison tile")

	# === HP 为 1：一击必杀 ===
	tile_mgr.clear_all()
	bc.remove_from_grid()
	bc.place_on_grid(Vector2i(10, 10))
	t.assert_eq(bc.hp, 1, "hp starts at 1")

	# === 死亡爆裂：留下毒液格 ===
	# 创建新的 bog_crawler 来测试死亡效果
	var bc2 := Enemy.new()
	bc2.setup_from_config("bog_crawler")
	bc2.place_on_grid(Vector2i(20, 10))

	# 先断开tick连接避免干扰
	if bc2._tick_connected:
		EventBus.tick_post_process.disconnect(bc2._on_tick_post_process)
		bc2._tick_connected = false

	tile_mgr.clear_all()
	var death_pos := bc2.grid_position

	# 记录死亡前的毒液格数量
	var poison_count_before: int = 0
	for pos in tile_mgr._tiles:
		if tile_mgr._tiles[pos].has("poison"):
			poison_count_before += 1

	bc2.take_damage(2)  # 直接打死

	# 检查死亡位置附近出现了毒液格
	var poison_count_after: int = 0
	var poison_positions: Array[Vector2i] = []
	for pos in tile_mgr._tiles:
		if tile_mgr._tiles[pos].has("poison"):
			poison_count_after += 1
			poison_positions.append(pos)

	t.assert_eq(poison_count_after, 3, "death: spawned 3 poison tiles")
	t.assert_true(tile_mgr.has_tile(death_pos, "poison"), "death: poison at death position")

	# 其余毒液格在相邻位置
	for pos in poison_positions:
		if pos != death_pos:
			var dist: int = abs(pos.x - death_pos.x) + abs(pos.y - death_pos.y)
			t.assert_eq(dist, 1, "death: extra poison tile is adjacent (dist=1)")

	# === 毒液格加速：_get_poison_speed_bonus ===
	var bc3 := Enemy.new()
	bc3.setup_from_config("bog_crawler")
	bc3.place_on_grid(Vector2i(25, 10))
	tile_mgr.clear_all()

	# 不在毒液格上 → bonus = 0
	var bonus_off: int = bc3._get_poison_speed_bonus()
	t.assert_eq(bonus_off, 0, "no poison tile: speed bonus == 0")

	# 在毒液格上 → bonus = 2
	tile_mgr.place_tile(Vector2i(25, 10), "poison")
	var bonus_on: int = bc3._get_poison_speed_bonus()
	t.assert_eq(bonus_on, 2, "on poison tile: speed bonus == 2")

	# 非 bog_crawler 在毒液格上不加速
	var wanderer := Enemy.new()
	wanderer.setup_from_config("wanderer")
	wanderer.place_on_grid(Vector2i(25, 11))
	tile_mgr.place_tile(Vector2i(25, 11), "poison")
	var wanderer_bonus: int = wanderer._get_poison_speed_bonus()
	t.assert_eq(wanderer_bonus, 0, "wanderer on poison: no speed bonus")
	wanderer.remove_from_grid()

	# === 被堵时 idle ===
	tile_mgr.clear_all()
	bc3.remove_from_grid()
	bc3.place_on_grid(Vector2i(10, 10))
	var blockers: Array = []
	for bpos in [Vector2i(11, 10), Vector2i(9, 10), Vector2i(10, 11), Vector2i(10, 9)]:
		var b := GridEntity.new()
		b.blocks_movement = true
		b.place_on_grid(bpos)
		blockers.append(b)

	ctx = EnemyBrain.build_context(bc3)
	decision = bc3.brain.decide(bc3, ctx)
	t.assert_eq(decision.get("action"), "idle", "fully trapped: action == idle")

	for b in blockers:
		b.remove_from_grid()

	# === EnemyManager 生成 bog_crawler ===
	var em := EnemyManager.new()
	var mock_snake := Snake.new()
	Engine.get_main_loop().root.add_child(mock_snake)
	mock_snake.init_snake(Vector2i(5, 5), 3, Constants.DIR_VECTORS[Constants.Direction.RIGHT])
	em.snake = mock_snake

	em.spawn_enemy("bog_crawler")
	if em.current_enemies.size() > 0:
		t.assert_eq(em.current_enemies[0].enemy_type, "bog_crawler", "spawn: type == bog_crawler")
		t.assert_true(em.current_enemies[0].brain is BogCrawlerBrain, "spawn: has BogCrawlerBrain")
	em.clear_enemies()

	# === 清理 ===
	if sem and old_tile_mgr != null:
		sem.tile_manager = old_tile_mgr
	tile_mgr.clear_all()
	tile_mgr.queue_free()
	bc.remove_from_grid()
	bc3.remove_from_grid()
	snake_seg.remove_from_grid()
	GridWorld.clear_all()
	mock_snake._clear_segments()
	mock_snake.queue_free()
	em.queue_free()
