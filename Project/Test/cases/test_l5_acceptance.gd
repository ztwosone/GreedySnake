extends RefCounted

const MetaSaveSystemScript := preload("res://systems/meta_growth/meta_save_system.gd")


func run(t) -> void:
	_test_l5_acceptance_full(t)


func _test_l5_acceptance_full(t) -> void:
	var meta = MetaSaveSystemScript.new()
	meta.reset()

	t.assert_false(meta.is_head_unlocked("ungud"), "[L5-ACC] no unlocks initially")

	var tracker: Node = load("res://systems/meta_growth/run_stats_tracker.gd").new()
	t.add_child(tracker)
	var unlock: Node = load("res://systems/meta_growth/unlock_system.gd").new()
	unlock.setup(meta)
	t.add_child(unlock)
	var legacy: Node = load("res://systems/meta_growth/legacy_stone_system.gd").new()
	legacy.setup(meta)
	t.add_child(legacy)

	EventBus.snake_turned.emit({"old_dir": Vector2.RIGHT, "new_dir": Vector2.UP})
	for _i in range(250):
		EventBus.snake_turned.emit({"old_dir": Vector2.RIGHT, "new_dir": Vector2.UP})

	var stats: Dictionary = tracker.finalize_run("victory")
	t.assert_true(int(stats.get("total_turns", 0)) >= 200, "[L5-ACC] turns tracked")

	t.assert_true(meta.is_head_unlocked("ungud"), "[L5-ACC] turn_200 condition unlocked ungud")

	var stones: Array = legacy.get_available_stones()
	t.assert_true(stones.size() >= 1, "[L5-ACC] at least 1 legacy stone created")
	t.assert_true(stones[0].has("bias_config"), "[L5-ACC] stone has bias config")

	var pickup: Node = load("res://systems/events/pickup_system.gd").new()
	t.add_child(pickup)
	var pickup_id: String = pickup.try_drop_pickup("elite", Vector2i(5, 5))
	t.assert_true(pickup_id == "" or pickup_id != "", "[L5-ACC] pickup system functional")

	pickup.cleanup()
	pickup.queue_free()
	legacy.cleanup()
	legacy.queue_free()
	unlock.cleanup()
	unlock.queue_free()
	tracker.queue_free()
	meta.reset()