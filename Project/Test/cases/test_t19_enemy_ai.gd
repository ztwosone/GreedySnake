extends RefCounted
## T19 测试：敌人 AI 行为框架


func run(t) -> void:
	# --- 文件存在性 ---
	t.assert_file_exists("res://entities/enemies/enemy_brain.gd")
	t.assert_file_exists("res://core/helpers/pathfinding.gd")

	# --- Pathfinding 基本检查 ---
	t.assert_eq(Pathfinding.manhattan_distance(Vector2i(0, 0), Vector2i(3, 4)), 7, "manhattan_distance((0,0),(3,4)) == 7")
	t.assert_eq(Pathfinding.manhattan_distance(Vector2i(5, 5), Vector2i(5, 5)), 0, "manhattan_distance same point == 0")

	GridWorld.init_grid(40, 22)

	# get_valid_moves — 中间位置应有4个方向
	var valid := Pathfinding.get_valid_moves(Vector2i(10, 10))
	t.assert_eq(valid.size(), 4, "get_valid_moves mid-grid: 4 directions")

	# get_valid_moves — 角落
	var corner_valid := Pathfinding.get_valid_moves(Vector2i(0, 0))
	t.assert_eq(corner_valid.size(), 2, "get_valid_moves corner (0,0): 2 directions")

	# get_direction_towards
	var dir_towards := Pathfinding.get_direction_towards(Vector2i(5, 5), Vector2i(10, 5))
	t.assert_eq(dir_towards, Vector2i(1, 0), "get_direction_towards: east towards (10,5)")

	var dir_towards_north := Pathfinding.get_direction_towards(Vector2i(5, 5), Vector2i(5, 0))
	t.assert_eq(dir_towards_north, Vector2i(0, -1), "get_direction_towards: north towards (5,0)")

	# get_direction_away
	var dir_away := Pathfinding.get_direction_away(Vector2i(5, 5), Vector2i(6, 5))
	t.assert_eq(dir_away, Vector2i(-1, 0), "get_direction_away: west away from (6,5)")

	# get_valid_moves with blocked cell
	var blocker := GridEntity.new()
	blocker.blocks_movement = true
	blocker.place_on_grid(Vector2i(11, 10))
	var blocked_valid := Pathfinding.get_valid_moves(Vector2i(10, 10))
	t.assert_eq(blocked_valid.size(), 3, "get_valid_moves with 1 blocked neighbor: 3 directions")
	t.assert_true(not blocked_valid.has(Vector2i(1, 0)), "blocked direction excluded")
	blocker.remove_from_grid()

	# --- EnemyBrain 基本检查 ---
	var brain := EnemyBrain.new()
	t.assert_true(brain is RefCounted, "EnemyBrain is RefCounted")
	t.assert_true(brain.has_method("decide"), "has decide")
	t.assert_true(brain.has_method("evaluate_self_preservation"), "has evaluate_self_preservation")
	t.assert_true(brain.has_method("evaluate_threat_response"), "has evaluate_threat_response")
	t.assert_true(brain.has_method("evaluate_status_response"), "has evaluate_status_response")
	t.assert_true(brain.has_method("evaluate_tracking"), "has evaluate_tracking")
	t.assert_true(brain.has_method("evaluate_default"), "has evaluate_default")
	t.assert_true(brain.has_method("build_context"), "has build_context (static)")

	# 基类默认行为 = idle
	var mock_enemy := Enemy.new()
	mock_enemy.place_on_grid(Vector2i(15, 10))
	var ctx := EnemyBrain.build_context(mock_enemy)
	var decision := brain.decide(mock_enemy, ctx)
	t.assert_eq(decision.get("action"), "idle", "base brain decide: action == idle")
	t.assert_eq(decision.get("direction"), Vector2i.ZERO, "base brain decide: direction == ZERO")

	# --- Enemy 重构检查 ---
	t.assert_true(mock_enemy.has_method("setup_from_config"), "Enemy has setup_from_config")
	t.assert_eq(mock_enemy.enemy_type, "wanderer", "default enemy_type == wanderer")
	t.assert_true(mock_enemy.brain != null, "Enemy has brain")
	t.assert_true(mock_enemy.brain is EnemyBrain, "brain is EnemyBrain")

	# setup_from_config 读取配置
	mock_enemy.setup_from_config("wanderer")
	t.assert_eq(mock_enemy.enemy_type, "wanderer", "setup wanderer: type == wanderer")
	t.assert_eq(mock_enemy.hp, 1, "setup wanderer: hp == 1")
	t.assert_eq(mock_enemy.attack_cost, 1, "setup wanderer: attack_cost == 1")

	# 颜色从config读取
	var cfg_node = Engine.get_main_loop().root.get_node_or_null("ConfigManager")
	if cfg_node:
		var wanderer_cfg: Dictionary = cfg_node.get_enemy_type("wanderer")
		var expected_color := Color.from_string(wanderer_cfg.get("color", "#CC1A4D"), Color.WHITE)
		t.assert_eq(mock_enemy.enemy_color, expected_color, "wanderer color from config")

	mock_enemy.remove_from_grid()

	# --- EnemyManager 多类型生成 ---
	var em := EnemyManager.new()
	var mock_snake := Snake.new()
	Engine.get_main_loop().root.add_child(mock_snake)
	mock_snake.init_snake(Vector2i(5, 5), 3, Constants.DIR_VECTORS[Constants.Direction.RIGHT])
	em.snake = mock_snake

	em.spawn_enemy("wanderer")
	t.assert_eq(em.current_enemies.size(), 1, "spawn_enemy('wanderer'): 1 enemy")
	if em.current_enemies.size() > 0:
		t.assert_eq(em.current_enemies[0].enemy_type, "wanderer", "spawned enemy type == wanderer")

	# 默认参数向后兼容
	em.spawn_enemy()
	t.assert_eq(em.current_enemies.size(), 2, "spawn_enemy() default: 2 enemies")
	if em.current_enemies.size() > 1:
		t.assert_eq(em.current_enemies[1].enemy_type, "wanderer", "default spawn type == wanderer")

	em.clear_enemies()

	# --- enemy_action_decided 信号 ---
	t.assert_has_signal(EventBus, "enemy_action_decided")

	# --- _execute_decision 移动测试 ---
	var move_enemy := Enemy.new()
	move_enemy.place_on_grid(Vector2i(20, 10))

	var action_events: Array = []
	var _on_action := func(data: Dictionary) -> void:
		action_events.append(data)
	EventBus.enemy_action_decided.connect(_on_action)

	var moved_events: Array = []
	var _on_moved := func(data: Dictionary) -> void:
		moved_events.append(data)
	EventBus.entity_moved.connect(_on_moved)

	move_enemy._execute_decision({ "action": "move", "direction": Vector2i(1, 0) })
	t.assert_eq(move_enemy.grid_position, Vector2i(21, 10), "enemy moved to (21,10)")
	t.assert_true(action_events.size() >= 1, "enemy_action_decided emitted on move")
	t.assert_true(moved_events.size() >= 1, "entity_moved emitted on enemy move")
	if moved_events.size() > 0:
		t.assert_eq(moved_events[0].get("from"), Vector2i(20, 10), "entity_moved from correct")
		t.assert_eq(moved_events[0].get("to"), Vector2i(21, 10), "entity_moved to correct")

	EventBus.enemy_action_decided.disconnect(_on_action)
	EventBus.entity_moved.disconnect(_on_moved)

	# idle 不移动
	var idle_pos := move_enemy.grid_position
	move_enemy._execute_decision({ "action": "idle", "direction": Vector2i.ZERO })
	t.assert_eq(move_enemy.grid_position, idle_pos, "idle: position unchanged")

	move_enemy.remove_from_grid()

	# --- get_nearest_tile_of_type ---
	var tile_mgr := StatusTileManager.new()
	Engine.get_main_loop().root.add_child(tile_mgr)
	tile_mgr.place_tile(Vector2i(5, 5), "fire")
	tile_mgr.place_tile(Vector2i(15, 15), "fire")

	var nearest := Pathfinding.get_nearest_tile_of_type(Vector2i(6, 5), "fire", tile_mgr)
	t.assert_eq(nearest, Vector2i(5, 5), "nearest fire tile from (6,5) is (5,5)")

	var no_ice := Pathfinding.get_nearest_tile_of_type(Vector2i(6, 5), "ice", tile_mgr)
	t.assert_eq(no_ice, Vector2i(-1, -1), "no ice tile: returns (-1,-1)")

	tile_mgr.clear_all()
	tile_mgr.queue_free()

	# === 清理 ===
	GridWorld.clear_all()
	mock_snake._clear_segments()
	mock_snake.queue_free()
	em.queue_free()
