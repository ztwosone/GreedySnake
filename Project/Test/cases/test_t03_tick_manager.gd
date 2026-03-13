extends RefCounted
## T03 测试：TickManager 节拍管理器


func run(t) -> void:
	t.assert_file_exists("res://autoloads/tick_manager.gd")

	# --- Method existence ---
	t.assert_true(TickManager.has_method("start_ticking"), "has start_ticking()")
	t.assert_true(TickManager.has_method("stop_ticking"), "has stop_ticking()")
	t.assert_true(TickManager.has_method("pause"), "has pause()")
	t.assert_true(TickManager.has_method("resume"), "has resume()")
	t.assert_true(TickManager.has_method("get_effective_interval"), "has get_effective_interval()")

	# --- Default property values ---
	t.assert_eq(TickManager.base_tick_interval, 0.25, "base_tick_interval == 0.25")
	t.assert_eq(TickManager.tick_speed_modifier, 1.0, "tick_speed_modifier == 1.0")
	t.assert_eq(TickManager.is_ticking, false, "is_ticking default == false")

	# --- Effective interval calculation ---
	t.assert_eq(TickManager.get_effective_interval(), 0.25, "effective interval at 1x == 0.25")
	TickManager.tick_speed_modifier = 2.0
	t.assert_eq(TickManager.get_effective_interval(), 0.125, "effective interval at 2x == 0.125")
	TickManager.tick_speed_modifier = 1.0  # reset

	# --- Tick event emission (quick sync test) ---
	var ticks_received := []
	var on_post := func(tick_index: int) -> void:
		ticks_received.append(tick_index)
	EventBus.tick_post_process.connect(on_post)

	TickManager.start_ticking()
	t.assert_eq(TickManager.is_ticking, true, "is_ticking == true after start")
	t.assert_eq(TickManager.current_tick, 0, "current_tick reset to 0 on start")

	TickManager.stop_ticking()
	t.assert_eq(TickManager.is_ticking, false, "is_ticking == false after stop")

	EventBus.tick_post_process.disconnect(on_post)
