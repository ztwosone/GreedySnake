extends RefCounted
## 草稿套件（M2 T006 对照 v1 映射重写）。
## M1 已补存档卫生：注入临时 save_path，绝不触碰生产存档 user://meta_save.json。

const UNLOCK_PATH: String = "res://systems/meta_growth/unlock_system.gd"
const MetaSaveSystemScript := preload("res://systems/meta_growth/meta_save_system.gd")

const TEMP_SAVE_PATH: String = "user://test_l5_unlocks_tmp.json"


func run(t) -> void:
	_test_unlock_conditions(t)
	_remove_temp_save()


func _test_unlock_conditions(t) -> void:
	t.assert_file_exists(UNLOCK_PATH)
	if not FileAccess.file_exists(UNLOCK_PATH):
		return

	var conditions: Array = ConfigManager.get_unlock_conditions()
	t.assert_true(conditions.size() >= 2, "[L5-US1] at least 2 unlock conditions")

	_remove_temp_save()
	var meta = MetaSaveSystemScript.new(TEMP_SAVE_PATH)
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


func _remove_temp_save() -> void:
	if FileAccess.file_exists(TEMP_SAVE_PATH):
		DirAccess.remove_absolute(TEMP_SAVE_PATH)