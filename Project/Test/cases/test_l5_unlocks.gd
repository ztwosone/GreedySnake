extends RefCounted

const UNLOCK_PATH: String = "res://systems/meta_growth/unlock_system.gd"
const MetaSaveSystemScript := preload("res://systems/meta_growth/meta_save_system.gd")


func run(t) -> void:
	_test_unlock_conditions(t)


func _test_unlock_conditions(t) -> void:
	t.assert_file_exists(UNLOCK_PATH)
	if not FileAccess.file_exists(UNLOCK_PATH):
		return

	var conditions: Array = ConfigManager.get_unlock_conditions()
	t.assert_true(conditions.size() >= 2, "[L5-US1] at least 2 unlock conditions")

	var meta = MetaSaveSystemScript.new()
	meta.reset()

	var unlock: Node = load(UNLOCK_PATH).new()
	unlock.setup(meta)
	t.add_child(unlock)

	var stats: Dictionary = {
		"total_turns": 250,
		"total_kills": 10,
		"reaction_kills": 0,
	}
	var unlocked: Array = unlock.check_unlocks(stats)
	t.assert_true(unlocked.size() >= 1, "[L5-US1] turns_200 unlocks ungud")
	t.assert_true(meta.is_head_unlocked("ungud"), "[L5-US1] ungud head persisted in meta_save")

	unlocked = unlock.check_unlocks(stats)
	t.assert_eq(unlocked.size(), 0, "[L5-US1] no duplicate unlock on same stats")

	unlock.cleanup()
	unlock.queue_free()