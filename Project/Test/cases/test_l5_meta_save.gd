extends RefCounted

const META_SAVE_PATH: String = "res://systems/meta_growth/meta_save_system.gd"
const RUN_STATS_PATH: String = "res://systems/meta_growth/run_stats_tracker.gd"
const MetaSaveSystemScript := preload(META_SAVE_PATH)


func run(t) -> void:
	_test_meta_save_basic(t)
	_test_run_stats_tracking(t)


func _test_meta_save_basic(t) -> void:
	t.assert_file_exists(META_SAVE_PATH)
	if not FileAccess.file_exists(META_SAVE_PATH):
		return

	var meta = MetaSaveSystemScript.new()

	t.assert_false(meta.is_head_unlocked("ungud"), "[L5] starts with no head unlocks")
	meta.unlock_head("ungud")
	t.assert_true(meta.is_head_unlocked("ungud"), "[L5] head unlocked")
	meta.unlock_head("ungud")
	t.assert_eq(meta.get_unlocked_heads().size(), 1, "[L5] no duplicate unlock")

	meta.unlock_tail("salamander")
	t.assert_true(meta.is_tail_unlocked("salamander"), "[L5] tail unlocked")

	var stone: Dictionary = {"description": "test stone", "highlight_type": "test"}
	meta.add_legacy_stone(stone)
	t.assert_eq(meta.get_legacy_stones().size(), 1, "[L5] legacy stone added")

	for i in range(6):
		meta.add_legacy_stone({"description": "stone_%d" % i})
	t.assert_eq(meta.get_legacy_stones().size(), 5, "[L5] legacy stones capped at 5")

	var removed: Dictionary = meta.remove_legacy_stone(0)
	t.assert_eq(meta.get_legacy_stones().size(), 4, "[L5] stone removed")

	meta.reset()
	t.assert_eq(meta.get_legacy_stones().size(), 0, "[L5] reset clears stones")
	t.assert_false(meta.is_head_unlocked("ungud"), "[L5] reset clears unlocks")


func _test_run_stats_tracking(t) -> void:
	t.assert_file_exists(RUN_STATS_PATH)
	if not FileAccess.file_exists(RUN_STATS_PATH):
		return

	var tracker: Node = load(RUN_STATS_PATH).new()
	t.add_child(tracker)

	var stats: Dictionary = tracker.get_stats()
	t.assert_eq(int(stats.get("total_turns", 0)), 0, "[L5] starts at 0 turns")
	t.assert_eq(int(stats.get("total_kills", 0)), 0, "[L5] starts at 0 kills")

	EventBus.snake_turned.emit({"old_dir": Vector2.RIGHT, "new_dir": Vector2.UP})
	t.assert_eq(int(tracker.get_stats().get("total_turns", 0)), 1, "[L5] turn tracked")

	EventBus.enemy_killed.emit({"method": "reaction", "position": Vector2i.ZERO})
	t.assert_eq(int(tracker.get_stats().get("total_kills", 0)), 1, "[L5] kill tracked")
	t.assert_eq(int(tracker.get_stats().get("reaction_kills", 0)), 1, "[L5] reaction kill tracked")

	EventBus.floor_completed.emit({"floor_index": 1})
	t.assert_eq(int(tracker.get_stats().get("floors_completed", 0)), 1, "[L5] floor tracked")

	tracker.cleanup()
	tracker.queue_free()