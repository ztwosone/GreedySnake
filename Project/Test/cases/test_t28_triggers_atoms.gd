extends RefCounted
## T28 测试：T28A 新触发器 + T28B 新原子


func run(t) -> void:
	_test_atom_registration(t)
	_test_modify_food_drop(t)
	_test_direct_grow(t)
	_test_steal_status(t)
	_test_modify_hit_threshold(t)
	_test_trigger_signals(t)


func _test_atom_registration(t) -> void:
	# --- T28B 原子注册 ---
	var registry := AtomRegistry.new()
	t.assert_true(registry.has_atom("modify_food_drop"), "modify_food_drop registered")
	t.assert_true(registry.has_atom("direct_grow"), "direct_grow registered")
	t.assert_true(registry.has_atom("steal_status"), "steal_status registered")
	t.assert_true(registry.has_atom("modify_hit_threshold"), "modify_hit_threshold registered")

	# --- 新文件存在性 ---
	t.assert_file_exists("res://systems/atoms/atoms/value/modify_food_drop_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/value/direct_grow_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/status/steal_status_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/value/modify_hit_threshold_atom.gd")

	# --- 原子总数检查 ---
	var names: Array = registry.get_atom_names()
	t.assert_true(names.size() >= 55, "total atoms >= 55 (49 + 6 new), got %d" % names.size())


func _test_modify_food_drop(t) -> void:
	var registry := AtomRegistry.new()
	var atom = registry.create("modify_food_drop", { "amount": 2 })
	var ctx := AtomContext.new()
	atom.execute(ctx)
	t.assert_eq(ctx.results.get("food_drop_modifier"), 2, "modify_food_drop: +2")

	# 叠加
	var atom2 = registry.create("modify_food_drop", { "amount": -1 })
	atom2.execute(ctx)
	t.assert_eq(ctx.results.get("food_drop_modifier"), 1, "modify_food_drop: +2-1=1")


func _test_direct_grow(t) -> void:
	# Snake.request_grow 存在性检查
	var snake := Snake.new()
	Engine.get_main_loop().root.add_child(snake)
	snake.init_snake(Vector2i(5, 5), 3, Vector2i(1, 0))

	t.assert_true(snake.has_method("request_grow"), "Snake has request_grow()")
	var old_pending: int = snake.grow_pending
	snake.request_grow(2)
	t.assert_eq(snake.grow_pending, old_pending + 2, "request_grow adds to grow_pending")

	snake._clear_segments()
	GridWorld.clear_all()
	snake.queue_free()


func _test_steal_status(t) -> void:
	var registry := AtomRegistry.new()
	var atom = registry.create("steal_status", {})

	# source 和 target 都需要 StatusCarrier 接口
	var seg := SnakeSegment.new()
	Engine.get_main_loop().root.add_child(seg)

	var enemy := Enemy.new()
	Engine.get_main_loop().root.add_child(enemy)
	enemy.add_status("fire")

	var ctx := AtomContext.new()
	ctx.source = seg
	ctx.target = enemy
	atom.execute(ctx)

	t.assert_true(seg.has_status("fire"), "steal: source got fire")
	t.assert_true(not enemy.has_status("fire"), "steal: target lost fire")

	# 无状态时无效果
	seg.clear_all_statuses()
	enemy.clear_all_statuses()
	atom.execute(ctx)
	t.assert_eq(seg.get_statuses().size(), 0, "steal: no effect when target empty")

	seg.queue_free()
	enemy.queue_free()


func _test_modify_hit_threshold(t) -> void:
	var registry := AtomRegistry.new()
	var atom = registry.create("modify_hit_threshold", { "value": -1 })
	var ctx := AtomContext.new()
	atom.execute(ctx)
	t.assert_eq(ctx.results.get("hit_threshold_modifier"), -1, "modify_hit_threshold: -1")

	var atom2 = registry.create("modify_hit_threshold", { "value": 2 })
	atom2.execute(ctx)
	t.assert_eq(ctx.results.get("hit_threshold_modifier"), 1, "modify_hit_threshold: -1+2=1")


func _test_trigger_signals(t) -> void:
	# T28A 触发器所需信号存在性
	t.assert_has_signal(EventBus, "snake_length_increased")
	t.assert_has_signal(EventBus, "snake_length_decreased")
	t.assert_has_signal(EventBus, "snake_turned")
	t.assert_has_signal(EventBus, "status_added_to_carrier")
	t.assert_has_signal(EventBus, "status_tile_placed")
	t.assert_has_signal(EventBus, "enemy_killed")
	t.assert_has_signal(EventBus, "entity_moved")

	# TriggerManager 有新处理方法
	var tm := TriggerManager.new()
	t.assert_true(tm.has_method("_on_length_increased"), "TM has _on_length_increased")
	t.assert_true(tm.has_method("_on_length_decreased"), "TM has _on_length_decreased")
	t.assert_true(tm.has_method("_on_snake_turned"), "TM has _on_snake_turned")
	t.assert_true(tm.has_method("_on_status_gained"), "TM has _on_status_gained")
	t.assert_true(tm.has_method("_on_tile_placed"), "TM has _on_tile_placed")
	t.assert_true(tm.has_method("_check_near_death"), "TM has _check_near_death")
	t.assert_true(tm.has_method("_check_enemy_approach"), "TM has _check_enemy_approach")

	# window_mgr 字段
	t.assert_true("window_mgr" in tm, "TM has window_mgr field")

	# T28A state 字段
	t.assert_true("_turn_count" in tm, "TM has _turn_count")
	t.assert_true("_kill_streak" in tm, "TM has _kill_streak")
	t.assert_true("_near_death_fired" in tm, "TM has _near_death_fired")
	t.assert_true("_current_tick_index" in tm, "TM has _current_tick_index")

	tm.queue_free()
