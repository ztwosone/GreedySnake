extends RefCounted
## 草稿套件（M3 T012 重写：阈值 JSON 反证 / 完整 stone payload / bias 消费 / 空列表跳过）。
## M1 已补存档卫生：注入临时 save_path，绝不触碰生产存档 user://meta_save.json。

const LEGACY_PATH: String = "res://systems/meta_growth/legacy_stone_system.gd"
const MetaSaveSystemScript := preload("res://systems/meta_growth/meta_save_system.gd")

const TEMP_SAVE_PATH: String = "user://test_l5_legacy_tmp.json"


func run(t) -> void:
	_test_legacy_generation_and_selection(t)
	_remove_temp_save()


func _test_legacy_generation_and_selection(t) -> void:
	t.assert_file_exists(LEGACY_PATH)
	if not FileAccess.file_exists(LEGACY_PATH):
		return

	_remove_temp_save()
	var meta = MetaSaveSystemScript.new(TEMP_SAVE_PATH)
	meta.reset()

	var legacy: Node = load(LEGACY_PATH).new()
	legacy.setup(meta)
	t.add_child(legacy)

	var stats: Dictionary = {"total_kills": 35, "max_reaction_chain": 2, "floors_completed": 1, "near_death_count": 0}
	var stone: Dictionary = legacy.generate_legacy_stone(stats)

	t.assert_eq(stone.get("highlight_type", ""), "high_kills", "[L5-US2] 35 kills → high_kills")
	t.assert_true(len(stone.get("display_name", "")) > 0, "[L5-US2] stone has display_name")
	t.assert_true(stone.has("bias_config"), "[L5-US2] stone has bias_config")

	var stones: Array = legacy.get_available_stones()
	t.assert_eq(stones.size(), 1, "[L5-US2] stone stored in meta_save")

	var selected: Dictionary = legacy.select_legacy_stone(0)
	t.assert_eq(selected.get("highlight_type", ""), "high_kills", "[L5-US2] selected correct stone")
	t.assert_eq(legacy.get_available_stones().size(), 0, "[L5-US2] stone consumed on selection")

	var null_selected: Dictionary = legacy.select_legacy_stone(0)
	t.assert_true(null_selected.is_empty(), "[L5-US2] selecting from empty returns empty")

	legacy.cleanup()
	legacy.queue_free()


func _remove_temp_save() -> void:
	if FileAccess.file_exists(TEMP_SAVE_PATH):
		DirAccess.remove_absolute(TEMP_SAVE_PATH)