extends RefCounted
## T14 测试：状态转化系统（逐段检测版）
## 蛇身段踩入状态格：无状态→获得、同类→无事发生、异类→反应+清除段状态
## 敌人踩格子仍走 StatusEffectManager


func run(t) -> void:
	# --- 文件存在性 ---
	t.assert_file_exists("res://systems/status/status_transfer_system.gd")

	# --- StatusTransferSystem 基本检查 ---
	var sts := StatusTransferSystem.new()
	t.assert_true(sts is Node, "StatusTransferSystem is Node")
	t.assert_true(sts.has_method("_on_snake_moved"), "has _on_snake_moved")
	t.assert_true(sts.has_method("_on_entity_moved"), "has _on_entity_moved")
	t.assert_true(sts.has_method("_check_segment_tile"), "has _check_segment_tile")
	sts.queue_free()

	# --- 集成测试准备 ---
	GridWorld.init_grid(40, 22)

	var mock_game_world := Node2D.new()
	mock_game_world.name = "MockGameWorld"
	Engine.get_main_loop().root.add_child(mock_game_world)

	var tile_mgr := StatusTileManager.new()
	mock_game_world.add_child(tile_mgr)

	# T27A: 注入 ReactionResolver + CollisionHandler（手动初始化）
	var ResolverScript: GDScript = preload("res://systems/status/reaction_resolver.gd")
	var resolver: Node = ResolverScript.new()
	resolver._build_reaction_map()
	tile_mgr.reaction_resolver = resolver

	var HandlerScript: GDScript = preload("res://systems/status/collision_handler.gd")
	var col_handler: Node = HandlerScript.new()
	col_handler.reaction_resolver = resolver
	col_handler.tile_manager = tile_mgr
	col_handler._collision_rules = ConfigManager._data.get("collision_rules", {})

	var mock_snake := Snake.new()
	mock_game_world.add_child(mock_snake)
	mock_snake.init_snake(Vector2i(10, 10), 4, Vector2i(1, 0))

	var transfer := StatusTransferSystem.new()
	transfer.tile_manager = tile_mgr
	transfer.snake = mock_snake
	transfer.collision_handler = col_handler
	mock_game_world.add_child(transfer)

	# === 空间→段：无状态段踩火格 → 获得火 ===

	tile_mgr.place_tile(Vector2i(10, 10), "fire")

	transfer._on_snake_moved({
		"body": mock_snake.body.duplicate(),
		"direction": Vector2i(1, 0),
		"head_pos": mock_snake.body[0],
		"old_tail_pos": mock_snake.body[-1],
		"vacated_pos": Vector2i(-1, -1),
	})

	t.assert_eq(mock_snake.segments[0].carried_status, "fire", "segment on fire tile gets fire status")

	# === 同类：火段踩火格 → 无事发生 ===

	# 段已经有 fire，再次走不会改变
	transfer._on_snake_moved({
		"body": mock_snake.body.duplicate(),
		"direction": Vector2i(1, 0),
		"head_pos": mock_snake.body[0],
		"old_tail_pos": mock_snake.body[-1],
		"vacated_pos": Vector2i(-1, -1),
	})
	t.assert_eq(mock_snake.segments[0].carried_status, "fire", "same type: fire segment on fire tile stays fire")

	# === 异类：火段踩冰格 → 反应+段清除 ===

	tile_mgr.clear_all()
	tile_mgr.place_tile(Vector2i(10, 10), "ice")
	# 段仍然有 fire
	t.assert_eq(mock_snake.segments[0].carried_status, "fire", "segment still has fire before cross-type")

	var reaction_events: Array = []
	var _on_reaction := func(data: Dictionary) -> void:
		reaction_events.append(data)
	EventBus.reaction_triggered.connect(_on_reaction)

	transfer._on_snake_moved({
		"body": mock_snake.body.duplicate(),
		"direction": Vector2i(1, 0),
		"head_pos": mock_snake.body[0],
		"old_tail_pos": mock_snake.body[-1],
		"vacated_pos": Vector2i(-1, -1),
	})

	t.assert_eq(mock_snake.segments[0].carried_status, "", "cross-type: segment status cleared")
	t.assert_true(reaction_events.size() >= 1, "cross-type: reaction_triggered emitted")
	if reaction_events.size() > 0:
		t.assert_eq(reaction_events[0].get("reaction_id"), "steam", "cross-type: reaction_id == steam")

	EventBus.reaction_triggered.disconnect(_on_reaction)

	# === 不同段可独立携带不同状态 ===

	tile_mgr.clear_all()
	for seg in mock_snake.segments:
		seg.clear_carried_status()

	# 在不同位置放不同格
	tile_mgr.place_tile(mock_snake.segments[0].grid_position, "fire")
	tile_mgr.place_tile(mock_snake.segments[1].grid_position, "ice")

	transfer._on_snake_moved({
		"body": mock_snake.body.duplicate(),
		"direction": Vector2i(1, 0),
		"head_pos": mock_snake.body[0],
		"old_tail_pos": mock_snake.body[-1],
		"vacated_pos": Vector2i(-1, -1),
	})

	t.assert_eq(mock_snake.segments[0].carried_status, "fire", "seg0 gets fire")
	t.assert_eq(mock_snake.segments[1].carried_status, "ice", "seg1 gets ice")

	# === 状态格永久存在 ===

	t.assert_true(tile_mgr.has_tile(mock_snake.segments[0].grid_position, "fire"), "fire tile still exists after interaction")
	t.assert_true(tile_mgr.has_tile(mock_snake.segments[1].grid_position, "ice"), "ice tile still exists after interaction")

	# === entity_moved 空间→实体（敌人走 StatusEffectManager）===

	var effect_mgr = StatusEffectManager
	effect_mgr.clear_all()
	tile_mgr.clear_all()

	var enemy_pos := Vector2i(5, 5)
	tile_mgr.place_tile(enemy_pos, "ice")

	var dummy_enemy := Node2D.new()
	Engine.get_main_loop().root.add_child(dummy_enemy)

	transfer._on_entity_moved({
		"entity": dummy_enemy,
		"from": Vector2i(4, 5),
		"to": enemy_pos,
	})

	t.assert_true(effect_mgr.has_status(dummy_enemy, "ice"), "entity_moved: enemy got ice from tile")
	dummy_enemy.queue_free()

	# === game_world 集成检查 ===
	t.assert_file_exists("res://scenes/game_world.tscn")
	t.assert_file_exists("res://scenes/game_world.gd")

	# === 清理 ===
	effect_mgr.clear_all()
	tile_mgr.clear_all()
	mock_snake._clear_segments()
	GridWorld.clear_all()
	mock_game_world.queue_free()
