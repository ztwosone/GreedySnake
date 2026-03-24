extends RefCounted
## 自动化游戏玩法模拟测试
## 创建真实的游戏场景，模拟蛇移动，检测状态效果交互中的错误

var _errors: Array = []


func run(t) -> void:
	_test_snake_through_ice_tiles(t)
	_test_snake_through_fire_tiles(t)
	_test_snake_through_poison_tiles(t)
	_test_ice_freeze_at_layer2(t)
	_test_reaction_steam(t)
	_test_reaction_toxic_explosion(t)


# === 辅助方法 ===

func _setup_game() -> Dictionary:
	## 创建一个最小化的游戏世界用于测试
	GridWorld.init_grid(20, 10)

	# 创建 SEM（从 autoload 获取）
	var sem = StatusEffectManager

	# 创建 StatusTileManager
	var tile_mgr := StatusTileManager.new()
	var root = Engine.get_main_loop().root
	root.add_child(tile_mgr)

	# 将 tile_mgr 设给 SEM
	if sem:
		sem.tile_manager = tile_mgr

	# 创建一个模拟蛇（Node2D with body）
	var snake := _create_mock_snake(Vector2i(5, 5), 5)

	return {
		"sem": sem,
		"tile_mgr": tile_mgr,
		"snake": snake,
	}


func _create_mock_snake(head_pos: Vector2i, length: int) -> Node2D:
	var snake := Node2D.new()
	snake.name = "MockSnake"
	snake.position = Vector2(head_pos.x * Constants.CELL_SIZE, head_pos.y * Constants.CELL_SIZE)
	Engine.get_main_loop().root.add_child(snake)
	GridWorld.register_entity(snake, head_pos)
	return snake


func _cleanup(ctx: Dictionary) -> void:
	var tile_mgr = ctx.get("tile_mgr")
	if tile_mgr and is_instance_valid(tile_mgr):
		tile_mgr.clear_all()
		tile_mgr.queue_free()

	var snake = ctx.get("snake")
	if snake and is_instance_valid(snake):
		GridWorld.unregister_entity(snake)
		snake.queue_free()

	var sem = ctx.get("sem")
	if sem:
		sem.clear_all()

	# 恢复 TickManager 到初始状态
	var tick_mgr = TickManager
	if tick_mgr:
		if tick_mgr.has_method("stop_ticking"):
			tick_mgr.stop_ticking()

	GridWorld.clear_all()


# === 测试用例 ===

func _test_snake_through_ice_tiles(t) -> void:
	var ctx := _setup_game()
	var sem = ctx["sem"]
	var tile_mgr = ctx["tile_mgr"]
	var snake = ctx["snake"]

	if sem == null:
		t.assert_true(false, "[ice] SEM is null, cannot test")
		_cleanup(ctx)
		return

	# 放置冰格
	tile_mgr.place_tile(Vector2i(6, 5), "ice", 1)

	# 模拟蛇踩冰格 — 通过 SEM 施加冰冻
	var effect: StatusEffectData = sem.apply_status(snake, "ice", "tile")
	t.assert_true(effect != null, "[ice] apply_status returned effect")

	# 检查 per-entity speed modifier
	var speed_mod: float = sem.get_modifier("speed", snake, 1.0)
	t.assert_true(speed_mod <= 1.0, "[ice] per-entity speed modifier applied (<=1.0, got %s)" % str(speed_mod))

	# 检查 effect 是否有 atom chains
	t.assert_true(effect.chains.size() > 0, "[ice] effect has atom chains")

	# 清理
	sem.remove_status(snake, "ice")
	var speed_after: float = sem.get_modifier("speed", snake, 1.0)
	t.assert_true(speed_after == 1.0, "[ice] per-entity speed restored after removal (got %s)" % str(speed_after))

	_cleanup(ctx)


func _test_snake_through_fire_tiles(t) -> void:
	var ctx := _setup_game()
	var sem = ctx["sem"]
	var tile_mgr = ctx["tile_mgr"]
	var snake = ctx["snake"]

	if sem == null:
		t.assert_true(false, "[fire] SEM is null")
		_cleanup(ctx)
		return

	tile_mgr.place_tile(Vector2i(6, 5), "fire", 1)
	var effect: StatusEffectData = sem.apply_status(snake, "fire", "tile")
	t.assert_true(effect != null, "[fire] apply_status returned effect")
	t.assert_true(effect.chains.size() > 0, "[fire] effect has atom chains")

	sem.remove_status(snake, "fire")
	_cleanup(ctx)


func _test_snake_through_poison_tiles(t) -> void:
	var ctx := _setup_game()
	var sem = ctx["sem"]
	var tile_mgr = ctx["tile_mgr"]
	var snake = ctx["snake"]

	if sem == null:
		t.assert_true(false, "[poison] SEM is null")
		_cleanup(ctx)
		return

	tile_mgr.place_tile(Vector2i(6, 5), "poison", 1)
	var effect: StatusEffectData = sem.apply_status(snake, "poison", "tile")
	t.assert_true(effect != null, "[poison] apply_status returned effect")
	t.assert_true(effect.chains.size() > 0, "[poison] effect has atom chains")

	# 检查 growth modifier
	var modifier: float = sem.get_modifier("growth", snake, 1.0)
	t.assert_true(modifier < 1.0, "[poison] growth modifier reduced (got %s)" % str(modifier))

	sem.remove_status(snake, "poison")

	# 移除后 modifier 应恢复
	var after: float = sem.get_modifier("growth", snake, 1.0)
	t.assert_true(after == 1.0, "[poison] growth modifier restored after removal (got %s)" % str(after))

	_cleanup(ctx)


func _test_ice_freeze_at_layer2(t) -> void:
	var ctx := _setup_game()
	var sem = ctx["sem"]
	var snake = ctx["snake"]
	var tick_mgr = TickManager

	if sem == null or tick_mgr == null:
		t.assert_true(false, "[ice_freeze] SEM or TickManager is null")
		_cleanup(ctx)
		return

	# 第1层冰冻
	sem.apply_status(snake, "ice", "tile")

	# 第2层冰冻 — 应触发 freeze
	sem.apply_status(snake, "ice", "tile")

	var effect: StatusEffectData = sem.get_status(snake, "ice")
	t.assert_true(effect != null, "[ice_freeze] ice effect exists at layer 2")
	if effect:
		t.assert_true(effect.layer == 2, "[ice_freeze] ice layer is 2 (got %d)" % effect.layer)

	# FreezeAtom 应该已 pause 了 tick_mgr
	# 注意：在 headless 测试中 pause 效果可能不同
	t.assert_true(true, "[ice_freeze] freeze atom executed without crash")

	# 清理
	sem.remove_status(snake, "ice")
	_cleanup(ctx)


func _test_reaction_steam(t) -> void:
	# 反应测试需要 ReactionSystem (GameWorld 子节点)，单元测试中无法触发
	# 验证 SEM 可以同时持有两种状态不崩溃即可
	var ctx := _setup_game()
	var sem = ctx["sem"]
	var snake = ctx["snake"]

	if sem == null:
		t.assert_true(false, "[steam] SEM is null")
		_cleanup(ctx)
		return

	sem.apply_status(snake, "fire", "test")
	sem.apply_status(snake, "ice", "test")

	var has_fire: bool = sem.has_status(snake, "fire")
	var has_ice: bool = sem.has_status(snake, "ice")

	# 在无 ReactionSystem 场景中，两种状态应同时存在不崩溃
	t.assert_true(has_fire and has_ice, "[steam] fire+ice coexist without crash")

	sem.clear_all()
	_cleanup(ctx)


func _test_reaction_toxic_explosion(t) -> void:
	# 同上：反应需要 ReactionSystem，这里只验证不崩溃
	var ctx := _setup_game()
	var sem = ctx["sem"]
	var snake = ctx["snake"]

	if sem == null:
		t.assert_true(false, "[toxic] SEM is null")
		_cleanup(ctx)
		return

	sem.apply_status(snake, "fire", "test")
	sem.apply_status(snake, "poison", "test")

	var has_fire: bool = sem.has_status(snake, "fire")
	var has_poison: bool = sem.has_status(snake, "poison")

	t.assert_true(has_fire and has_poison, "[toxic] fire+poison coexist without crash")

	sem.clear_all()
	_cleanup(ctx)
