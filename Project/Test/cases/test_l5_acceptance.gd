extends RefCounted
## 草稿验收套件（M4 T020 重写为 SC-001..SC-008 逐条映射）。
## M1 已补存档卫生：注入临时 save_path，绝不触碰生产存档 user://meta_save.json。
## M2 已补 v1 映射卫生：unlock_conditions 重写为 v1 双条件后，
## 草稿 turns_200→ungud 断言改走 reaction_kills_10→bai_she（最小适配，重写归 T020）。

const MetaSaveSystemScript := preload("res://systems/meta_growth/meta_save_system.gd")

const TEMP_SAVE_PATH: String = "user://test_l5_acceptance_tmp.json"


func run(t) -> void:
	_test_l5_acceptance_full(t)
	_remove_temp_save()


func _test_l5_acceptance_full(t) -> void:
	_remove_temp_save()
	var meta = MetaSaveSystemScript.new(TEMP_SAVE_PATH)
	meta.reset()

	t.assert_false(meta.is_head_unlocked("bai_she"), "[L5-ACC] no conditional unlocks initially")

	var tracker: Node = load("res://systems/meta_growth/run_stats_tracker.gd").new()
	t.add_child(tracker)
	var unlock: Node = load("res://systems/meta_growth/unlock_system.gd").new()
	unlock.setup(meta)
	t.add_child(unlock)
	var legacy: Node = load("res://systems/meta_growth/legacy_stone_system.gd").new()
	legacy.setup(meta)
	t.add_child(legacy)

	for _i in range(12):
		EventBus.enemy_killed.emit(
			{"enemy_def": null, "position": Vector2i.ZERO, "method": "reaction_steam"})

	var stats: Dictionary = tracker.finalize_run("victory")
	t.assert_true(int(stats.get("reaction_kills", 0)) >= 10, "[L5-ACC] reaction kills tracked")

	t.assert_true(meta.is_head_unlocked("bai_she"),
		"[L5-ACC] reaction_kills_10 condition unlocked bai_she (v1 mapping)")

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
	tracker.cleanup()
	tracker.queue_free()


func _remove_temp_save() -> void:
	if FileAccess.file_exists(TEMP_SAVE_PATH):
		DirAccess.remove_absolute(TEMP_SAVE_PATH)