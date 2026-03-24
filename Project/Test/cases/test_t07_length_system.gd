extends RefCounted
## T07 测试：LengthSystem 长度系统


func run(t) -> void:
	t.assert_file_exists("res://systems/length/length_system.gd")

	# --- Method / property checks ---
	var ls := LengthSystem.new()
	t.assert_true(ls.has_method("get_current_length"), "has get_current_length()")
	t.assert_true(ls.has_method("_on_food_eaten"), "has _on_food_eaten()")
	t.assert_true(ls.has_method("_on_decrease_requested"), "has _on_decrease_requested()")
	t.assert_true(ls.has_method("_on_death_collision"), "has _on_death_collision()")
	t.assert_true(ls.has_method("_on_tick"), "has _on_tick()")
	t.assert_true(ls.has_method("get_no_body_ticks_remaining"), "has get_no_body_ticks_remaining()")
	ls.free()

	# --- Integration test ---
	GridWorld.clear_all()
	GridWorld.init_grid(20, 11)

	var tree_root = Engine.get_main_loop().root

	var snake := Snake.new()
	tree_root.call_deferred("add_child", snake)
	snake.init_snake(Vector2i(10, 5), 4, Constants.DIR_VECTORS[Constants.Direction.RIGHT])

	var length_sys := LengthSystem.new()
	length_sys.snake = snake
	# Manually connect signals (not in tree so _ready won't fire)
	EventBus.snake_food_eaten.connect(length_sys._on_food_eaten)
	EventBus.length_decrease_requested.connect(length_sys._on_decrease_requested)
	EventBus.snake_hit_boundary.connect(length_sys._on_death_collision)
	EventBus.snake_hit_self.connect(length_sys._on_death_collision)

	t.assert_eq(length_sys.get_current_length(), 4, "initial length == 4")

	# --- Food eaten → grow_pending increases ---
	var increase_events := []
	var on_increase := func(data: Dictionary) -> void:
		increase_events.append(data)
	EventBus.snake_length_increased.connect(on_increase)

	EventBus.snake_food_eaten.emit({"food": null, "position": Vector2i.ZERO, "food_type": "basic"})
	t.assert_eq(snake.grow_pending, 1, "grow_pending == 1 after food eaten")
	t.assert_eq(increase_events.size(), 1, "snake_length_increased emitted")
	t.assert_eq(increase_events[0].get("amount"), 1, "increase amount == 1")
	t.assert_eq(increase_events[0].get("source"), "food", "increase source == food")

	EventBus.snake_length_increased.disconnect(on_increase)

	# --- Decrease requested → tail removed ---
	snake.grow_pending = 0  # reset
	var decrease_events := []
	var on_decrease := func(data: Dictionary) -> void:
		decrease_events.append(data)
	EventBus.snake_length_decreased.connect(on_decrease)

	var old_size: int = snake.body.size()
	EventBus.length_decrease_requested.emit({"amount": 1, "source": "combat"})
	t.assert_eq(snake.body.size(), old_size - 1, "body shrunk by 1 after decrease")
	t.assert_eq(decrease_events.size(), 1, "snake_length_decreased emitted")
	t.assert_eq(decrease_events[0].get("new_length"), snake.body.size(), "new_length correct")

	EventBus.snake_length_decreased.disconnect(on_decrease)

	# --- Decrease to head-only → countdown starts (not immediate death) ---
	var death_events := []
	var on_death := func(data: Dictionary) -> void:
		death_events.append(data)
	EventBus.snake_died.connect(on_death)

	# Also connect tick signal for countdown
	EventBus.tick_post_process.connect(length_sys._on_tick)
	EventBus.snake_length_increased.connect(length_sys._on_length_increased)

	# body is now 3, shrink by 2 → size 1 (head only), countdown starts
	EventBus.length_decrease_requested.emit({"amount": 2, "source": "lethal"})
	t.assert_eq(snake.body.size(), 1, "body shrunk to head only")
	t.assert_eq(snake.is_alive, true, "snake alive during no-body countdown")
	t.assert_true(length_sys.get_no_body_ticks_remaining() > 0, "countdown started")

	# Simulate ticks until death
	var countdown: int = length_sys.get_no_body_ticks_remaining()
	for i in range(countdown):
		EventBus.tick_post_process.emit(i)
	t.assert_eq(snake.is_alive, false, "snake dead after no-body timeout")
	t.assert_true(death_events.size() >= 1, "snake_died emitted on no-body timeout")

	EventBus.tick_post_process.disconnect(length_sys._on_tick)
	EventBus.snake_length_increased.disconnect(length_sys._on_length_increased)

	# --- Boundary death ---
	death_events.clear()
	snake.is_alive = true  # reset for test
	EventBus.snake_hit_boundary.emit({"position": Vector2i(20, 5), "direction": Vector2i(1, 0)})
	t.assert_eq(snake.is_alive, false, "snake dead after boundary hit")
	t.assert_true(death_events.size() >= 1, "snake_died emitted on boundary")

	# --- Self-collision death ---
	death_events.clear()
	snake.is_alive = true
	EventBus.snake_hit_self.emit({"position": Vector2i(10, 5), "segment_index": 2})
	t.assert_eq(snake.is_alive, false, "snake dead after self hit")
	t.assert_true(death_events.size() >= 1, "snake_died emitted on self hit")

	# Clean up
	EventBus.snake_died.disconnect(on_death)
	EventBus.snake_food_eaten.disconnect(length_sys._on_food_eaten)
	EventBus.length_decrease_requested.disconnect(length_sys._on_decrease_requested)
	EventBus.snake_hit_boundary.disconnect(length_sys._on_death_collision)
	EventBus.snake_hit_self.disconnect(length_sys._on_death_collision)
	length_sys.free()
	snake.queue_free()
	GridWorld.clear_all()
	GridWorld.init_grid(20, 11)
