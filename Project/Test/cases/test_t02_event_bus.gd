extends RefCounted
## T02 测试：EventBus 全局事件总线


func run(t) -> void:
	t.assert_file_exists("res://autoloads/event_bus.gd")

	# --- Tick Lifecycle signals ---
	t.assert_has_signal(EventBus, "tick_pre_process")
	t.assert_has_signal(EventBus, "tick_input_collected")
	t.assert_has_signal(EventBus, "tick_post_process")

	# --- Snake signals ---
	t.assert_has_signal(EventBus, "snake_moved")
	t.assert_has_signal(EventBus, "snake_turned")
	t.assert_has_signal(EventBus, "snake_hit_boundary")
	t.assert_has_signal(EventBus, "snake_hit_self")
	t.assert_has_signal(EventBus, "snake_hit_enemy")
	t.assert_has_signal(EventBus, "snake_food_eaten")
	t.assert_has_signal(EventBus, "snake_died")

	# --- Length signals ---
	t.assert_has_signal(EventBus, "snake_length_increased")
	t.assert_has_signal(EventBus, "snake_length_decreased")
	t.assert_has_signal(EventBus, "length_decrease_requested")
	t.assert_has_signal(EventBus, "length_grow_requested")

	# --- Enemy signals ---
	t.assert_has_signal(EventBus, "enemy_killed")
	t.assert_has_signal(EventBus, "enemy_spawned")

	# --- GridWorld signals ---
	t.assert_has_signal(EventBus, "entity_moved")
	t.assert_has_signal(EventBus, "entity_placed")
	t.assert_has_signal(EventBus, "entity_removed")

	# --- Game Flow signals ---
	t.assert_has_signal(EventBus, "game_started")
	t.assert_has_signal(EventBus, "game_over")
	t.assert_has_signal(EventBus, "game_restart_requested")

	# --- 功能测试：connect + emit ---
	var received := []
	var callback := func(data: Dictionary) -> void:
		received.append(data)
	EventBus.snake_moved.connect(callback)
	EventBus.snake_moved.emit({"test": true})
	t.assert_eq(received.size(), 1, "signal emit/connect works")
	t.assert_eq(received[0].get("test"), true, "signal data passed correctly")
	EventBus.snake_moved.disconnect(callback)
