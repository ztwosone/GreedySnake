extends RefCounted
## T14 测试：实体↔空间状态转化系统
## 注意：由于 headless 测试中 add_child 在 _ready 阶段延迟，
## 直接调用处理方法而非依赖信号连接。
## 状态施加在 Snake 节点上（非单个 segment），模拟用 mock snake 结构。


func run(t) -> void:
	# --- 文件存在性 ---
	t.assert_file_exists("res://systems/status/status_transfer_system.gd")

	# --- StatusTransferSystem 基本检查 ---
	var sts := StatusTransferSystem.new()
	t.assert_true(sts is Node, "StatusTransferSystem is Node")
	t.assert_true(sts.has_method("_on_snake_moved"), "has _on_snake_moved")
	t.assert_true(sts.has_method("_on_entity_moved"), "has _on_entity_moved")
	t.assert_true(sts.has_method("_transfer_spatial_to_entity"), "has _transfer_spatial_to_entity")
	t.assert_true(sts.has_method("_transfer_entity_to_spatial"), "has _transfer_entity_to_spatial")
	t.assert_true(sts.has_method("_should_transfer_to_spatial"), "has _should_transfer_to_spatial")
	sts.queue_free()

	# --- 集成测试准备 ---
	GridWorld.init_grid(40, 22)

	# 构建 mock GameWorld 结构：parent/EntityContainer/Snake/HeadSegment
	var mock_game_world := Node2D.new()
	mock_game_world.name = "MockGameWorld"
	Engine.get_main_loop().root.add_child(mock_game_world)

	var entity_container := Node2D.new()
	entity_container.name = "EntityContainer"
	mock_game_world.add_child(entity_container)

	var mock_snake := Node2D.new()
	mock_snake.name = "Snake"
	entity_container.add_child(mock_snake)

	var tile_mgr := StatusTileManager.new()
	mock_game_world.add_child(tile_mgr)

	var transfer := StatusTransferSystem.new()
	transfer.tile_manager = tile_mgr
	mock_game_world.add_child(transfer)
	# _get_snake_node() looks for get_parent().get_node("EntityContainer/Snake")

	var effect_mgr = Engine.get_main_loop().root.get_node_or_null("StatusEffectManager")
	t.assert_true(effect_mgr != null, "StatusEffectManager autoload exists")
	if effect_mgr == null:
		mock_game_world.queue_free()
		return
	effect_mgr.clear_all()

	# === 空间→实体转化测试 ===

	var tile_pos := Vector2i(10, 10)
	var fire_tile: StatusTile = tile_mgr.place_tile(tile_pos, "fire")
	t.assert_true(fire_tile != null, "fire tile placed at (10,10)")

	# 蛇头 segment
	var dummy_head := SnakeSegment.new()
	dummy_head.segment_type = SnakeSegment.HEAD
	mock_snake.add_child(dummy_head)
	dummy_head.place_on_grid(tile_pos)

	var applied_events: Array = []
	var _on_applied := func(data: Dictionary) -> void:
		applied_events.append(data)
	EventBus.status_applied.connect(_on_applied)

	# 直接调用 _on_snake_moved — 状态施加到 Snake 节点
	transfer._on_snake_moved({
		"body": [tile_pos, Vector2i(9, 10), Vector2i(8, 10)],
		"direction": Vector2i(1, 0),
		"head_pos": tile_pos,
		"old_tail_pos": Vector2i(8, 10),
		"vacated_pos": Vector2i(7, 10),
	})

	# 验证 Snake 节点获得了火焰状态
	t.assert_true(effect_mgr.has_status(mock_snake, "fire"), "spatial→entity: snake got fire status")
	t.assert_true(applied_events.size() >= 1, "status_applied emitted for spatial→entity")
	var found_fire_apply: bool = false
	for ev in applied_events:
		if ev.get("type") == "fire" and ev.get("source") == "tile":
			found_fire_apply = true
			break
	t.assert_true(found_fire_apply, "status_applied source == 'tile'")

	EventBus.status_applied.disconnect(_on_applied)

	# === 实体→空间转化测试 ===

	effect_mgr.clear_all()
	transfer._freshly_applied.clear()
	effect_mgr.apply_status(mock_snake, "fire", "test")
	t.assert_true(effect_mgr.has_status(mock_snake, "fire"), "snake has fire for entity→spatial test")

	var tile_placed_events: Array = []
	var _on_tile_placed := func(data: Dictionary) -> void:
		tile_placed_events.append(data)
	EventBus.status_tile_placed.connect(_on_tile_placed)

	tile_mgr.clear_all()

	var vacated := Vector2i(7, 10)
	transfer._on_snake_moved({
		"body": [tile_pos, Vector2i(9, 10), Vector2i(8, 10)],
		"direction": Vector2i(1, 0),
		"head_pos": tile_pos,
		"old_tail_pos": Vector2i(8, 10),
		"vacated_pos": vacated,
	})

	t.assert_true(tile_mgr.has_tile(vacated, "fire"), "entity→spatial: fire tile placed at vacated pos")
	t.assert_true(tile_placed_events.size() >= 1, "status_tile_placed emitted for entity→spatial")

	EventBus.status_tile_placed.disconnect(_on_tile_placed)

	# === 防循环测试 ===

	effect_mgr.clear_all()
	tile_mgr.clear_all()
	transfer._freshly_applied.clear()
	transfer._transfer_counters.clear()

	var loop_pos := Vector2i(15, 10)
	tile_mgr.place_tile(loop_pos, "fire")

	dummy_head.remove_from_grid()
	dummy_head.place_on_grid(loop_pos)

	var loop_vacated := Vector2i(14, 10)
	transfer._on_snake_moved({
		"body": [loop_pos, Vector2i(16, 10), Vector2i(17, 10)],
		"direction": Vector2i(-1, 0),
		"head_pos": loop_pos,
		"old_tail_pos": Vector2i(17, 10),
		"vacated_pos": loop_vacated,
	})

	t.assert_true(effect_mgr.has_status(mock_snake, "fire"), "anti-loop: snake got fire from tile")
	t.assert_true(not tile_mgr.has_tile(loop_vacated, "fire"), "anti-loop: no fire tile at vacated (freshly applied)")

	# === trail_interval 测试（毒每 3 格留 1 格）===

	effect_mgr.clear_all()
	tile_mgr.clear_all()
	transfer._freshly_applied.clear()
	transfer._transfer_counters.clear()

	effect_mgr.apply_status(mock_snake, "poison", "test")
	t.assert_true(effect_mgr.has_status(mock_snake, "poison"), "snake has poison for trail_interval test")

	var trail_placed: Array = []
	for i in range(3):
		var vpos := Vector2i(20 + i, 10)
		dummy_head.remove_from_grid()
		dummy_head.place_on_grid(Vector2i(20 + i + 1, 10))
		transfer._on_snake_moved({
			"body": [Vector2i(20 + i + 1, 10)],
			"direction": Vector2i(1, 0),
			"head_pos": Vector2i(20 + i + 1, 10),
			"old_tail_pos": Vector2i(20 + i + 1, 10),
			"vacated_pos": vpos,
		})
		if tile_mgr.has_tile(vpos, "poison"):
			trail_placed.append(vpos)

	t.assert_eq(trail_placed.size(), 1, "trail_interval=3: 1 poison tile in 3 moves")

	# === entity_moved 空间→实体（非蛇实体）===

	effect_mgr.clear_all()
	tile_mgr.clear_all()
	transfer._freshly_applied.clear()

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
	GridWorld.clear_all()
	mock_game_world.queue_free()
