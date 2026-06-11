extends RefCounted
## spec 003 M4（T020 重写）：L5 验收套件——修订版 spec SC-001..SC-008 逐条映射。
## SC-001 v1 双解锁条件 + 默认解锁集；SC-002 存档跨重启（同路径新实例重载代理，
## 跨进程重启 = Gate-H 人工项）；SC-003 每局必铸石；SC-004 选石 bias 定种子分布偏移；
## SC-005 broken_eye 精英掉落网格实体 + DangerIndicator 携带效果；SC-006 层末未激活清除；
## SC-007 严格门禁装置存在性；SC-008 全环冒烟套件存在性（实跑在 test_l5_full_loop.gd）。
## 存档卫生（不可妥协）：临时 save_path + 测后删除，绝不触碰生产存档。

const MetaSaveSystemScript := preload("res://systems/meta_growth/meta_save_system.gd")

const TRACKER_PATH: String = "res://systems/meta_growth/run_stats_tracker.gd"
const UNLOCK_PATH: String = "res://systems/meta_growth/unlock_system.gd"
const LEGACY_PATH: String = "res://systems/meta_growth/legacy_stone_system.gd"
const PICKUP_PATH: String = "res://systems/events/pickup_system.gd"
const STONE_BIAS_PATH: String = "res://systems/meta_growth/stone_bias.gd"
const INDICATOR_PATH: String = "res://systems/vfx/danger_indicator.gd"

const TEMP_SAVE_PATH: String = "user://test_l5_acceptance_tmp.json"


func run(t) -> void:
	_remove_temp_save()
	_test_sc001_unlock_conditions(t)
	_test_sc002_save_persistence(t)
	_test_sc003_stone_every_run(t)
	_test_sc004_bias_distribution_shift(t)
	_test_sc005_sc006_pickup_loop(t)
	_test_sc007_strict_gate_device(t)
	_test_sc008_full_loop_suite(t)
	_remove_temp_save()


# === SC-001：v1 双条件（bai_she/lag_tail）按 run 末统计触发；新档默认解锁集 ===

func _test_sc001_unlock_conditions(t) -> void:
	var saved_gm: Dictionary = _save_game_manager()
	_remove_temp_save()
	var meta = MetaSaveSystemScript.new(TEMP_SAVE_PATH)
	meta.reset()

	t.assert_true(meta.is_head_unlocked("hydra"), "[SC-001] hydra unlocked by default")
	t.assert_true(meta.is_tail_unlocked("salamander"), "[SC-001] salamander unlocked by default")
	t.assert_false(meta.is_head_unlocked("bai_she"), "[SC-001] bai_she locked on a fresh save")
	t.assert_false(meta.is_tail_unlocked("lag_tail"), "[SC-001] lag_tail locked on a fresh save")

	var tracker: Node = load(TRACKER_PATH).new()
	t.add_child(tracker)
	var unlock: Node = load(UNLOCK_PATH).new()
	unlock.setup(meta)
	t.add_child(unlock)

	# run A：反应击杀 ≥ 10 → bai_she（floors 0 → lag_tail 不触发）
	EventBus.run_started.emit({"run_id": "acc_run_a", "floor_index": 1, "seed": 1})
	for _i in range(10):
		EventBus.enemy_killed.emit(
			{"enemy_def": null, "position": Vector2i.ZERO, "method": "reaction_steam"})
	tracker.finalize_run("death")
	t.assert_true(meta.is_head_unlocked("bai_she"),
		"[SC-001] reaction_kills >= 10 unlocks bai_she")
	t.assert_false(meta.is_tail_unlocked("lag_tail"),
		"[SC-001] lag_tail untouched by the reaction condition")

	# run B：完成 ≥ 2 层 → lag_tail
	EventBus.run_started.emit({"run_id": "acc_run_b", "floor_index": 1, "seed": 2})
	EventBus.floor_completed.emit({"floor_index": 1, "floor_id": "acc_f1"})
	EventBus.floor_completed.emit({"floor_index": 2, "floor_id": "acc_f2"})
	tracker.finalize_run("victory")
	t.assert_true(meta.is_tail_unlocked("lag_tail"),
		"[SC-001] floors_completed >= 2 unlocks lag_tail")

	unlock.cleanup()
	unlock.queue_free()
	tracker.cleanup()
	tracker.queue_free()
	_restore_game_manager(saved_gm)
	_remove_temp_save()


# === SC-002：存档跨重启（同路径新实例重载 = 跨进程代理；真重启 = Gate-H） ===

func _test_sc002_save_persistence(t) -> void:
	_remove_temp_save()
	var meta = MetaSaveSystemScript.new(TEMP_SAVE_PATH)
	meta.reset()
	meta.unlock_head("bai_she")
	meta.add_legacy_stone({"display_name": "验收石", "highlight_type": "high_kills",
		"description": "d", "bias_config": {}, "created_at": 1})
	t.assert_true(meta.save_to_disk(), "[SC-002] save written")

	var reloaded = MetaSaveSystemScript.new(TEMP_SAVE_PATH)
	t.assert_true(reloaded.load_from_disk(), "[SC-002] fresh instance loads the same path")
	t.assert_true(reloaded.is_head_unlocked("bai_she"), "[SC-002] unlock restored")
	t.assert_true(reloaded.is_head_unlocked("hydra"), "[SC-002] default unlock kept")
	t.assert_eq(reloaded.get_legacy_stones().size(), 1, "[SC-002] stones restored")
	_remove_temp_save()


# === SC-003：每个完结的 run 都铸一块石（含无高光 default 石） ===

func _test_sc003_stone_every_run(t) -> void:
	var saved_gm: Dictionary = _save_game_manager()
	_remove_temp_save()
	var meta = MetaSaveSystemScript.new(TEMP_SAVE_PATH)
	meta.reset()
	var tracker: Node = load(TRACKER_PATH).new()
	t.add_child(tracker)
	var legacy: Node = load(LEGACY_PATH).new()
	legacy.setup(meta)
	t.add_child(legacy)

	# run 1：零高光 → default「旅者」石
	EventBus.run_started.emit({"run_id": "acc_stone_1", "floor_index": 1, "seed": 3})
	tracker.finalize_run("death")
	t.assert_eq(legacy.get_available_stones().size(), 1,
		"[SC-003] a stone is forged after every completed run")
	t.assert_eq(str(legacy.get_available_stones()[0].get("highlight_type", "")), "default",
		"[SC-003] no-highlight run forges the default survival stone (Edge Case)")

	# run 2：胜利路径同样铸石
	EventBus.run_started.emit({"run_id": "acc_stone_2", "floor_index": 1, "seed": 4})
	tracker.finalize_run("victory")
	t.assert_eq(legacy.get_available_stones().size(), 2,
		"[SC-003] victory runs forge a stone too")

	legacy.cleanup()
	legacy.queue_free()
	tracker.cleanup()
	tracker.queue_free()
	_restore_game_manager(saved_gm)
	_remove_temp_save()


# === SC-004：选石 bias 定种子分布偏移（stone_bias 加权重排，消费端实跑在 legacy/loop 套件） ===

func _test_sc004_bias_distribution_shift(t) -> void:
	t.assert_file_exists(STONE_BIAS_PATH)
	if not FileAccess.file_exists(STONE_BIAS_PATH):
		return
	var BiasScript: GDScript = load(STONE_BIAS_PATH)
	var options: Array = [
		_scale_option("toxin_scale", "middle"),
		_scale_option("frost_scale", "middle"),
		_scale_option("regen_scale", "back"),
		_scale_option("thorn_scale", "back"),
		_scale_option("flame_scale", "middle"),
	]
	var uniform_first: int = 0
	var biased_first: int = 0
	for i in range(24):
		var uniform_out: Array = BiasScript.make_bias({}, 6000 + i).call(options)
		if str(uniform_out[0].get("target_id", "")) == "flame_scale":
			uniform_first += 1
		var biased_out: Array = BiasScript.make_bias({"fire": 6.0}, 6000 + i).call(options)
		if str(biased_out[0].get("target_id", "")) == "flame_scale":
			biased_first += 1
	t.assert_true(biased_first > uniform_first,
		"[SC-004] fire-stone weights shift the deterministic-seed first-pick distribution (%d > %d)"
		% [biased_first, uniform_first])


# === SC-005/SC-006：broken_eye 精英掉落网格实体 + 携带效果可观测 + 层末未激活清除 ===

func _test_sc005_sc006_pickup_loop(t) -> void:
	var saved_chance: float = float(ConfigManager.event_pickups.get("drop_chance", 0.5))
	ConfigManager.event_pickups["drop_chance"] = 1.0

	var pickup: Node = load(PICKUP_PATH).new()
	t.add_child(pickup)
	var indicator: Node2D = load(INDICATOR_PATH).new()
	t.add_child(indicator)

	var pos := Vector2i(18, 9)
	t.assert_eq(pickup.try_drop_pickup("elite_wanderer", pos), "broken_eye",
		"[SC-005] elite kill drops broken_eye")
	t.assert_true(
		GridWorld.get_first_entity_of_type(pos, Constants.EntityType.PICKUP) != null,
		"[SC-005] fragment lands as a grid entity")
	t.assert_eq(pickup.collect_pickup_at(pos), "broken_eye", "[SC-005] head entry collects it")
	t.assert_true(indicator.is_intent_display_enabled(),
		"[SC-005] carry effect observable via the DangerIndicator data path")

	EventBus.floor_completed.emit({"floor_index": 1, "floor_id": "acc_pickup_floor"})
	t.assert_false(pickup.has_carried("broken_eye"),
		"[SC-006] non-activated fragment cleared on floor transition")
	t.assert_false(indicator.is_intent_display_enabled(),
		"[SC-006] carry effect ends with the fragment")

	indicator.queue_free()
	pickup.cleanup()
	pickup.queue_free()
	ConfigManager.event_pickups["drop_chance"] = saved_chance


# === SC-007：严格门禁装置存在（全量回归 + Godot 输出扫描在 CI 命令层执行） ===

func _test_sc007_strict_gate_device(t) -> void:
	t.assert_file_exists("res://Test/test_runner.tscn")
	var strict_path: String = (ProjectSettings.globalize_path("res://")
		+ "/../Tools/run_tests_strict.ps1").simplify_path()
	t.assert_true(FileAccess.file_exists(strict_path),
		"[SC-007] strict gate wrapper exists (Tools/run_tests_strict.ps1)")


# === SC-008：全环冒烟套件存在（实跑在该套件内：死 → 元 → 二局 bias） ===

func _test_sc008_full_loop_suite(t) -> void:
	t.assert_file_exists("res://test/cases/test_l5_full_loop.gd")


# === helpers ===

func _scale_option(target_id: String, slot: String) -> Dictionary:
	return {
		"option_id": "opt_%s" % target_id,
		"display_name": target_id,
		"reward_type": "scale",
		"target_id": target_id,
		"target_slot": slot,
		"level_delta": 0,
	}


func _save_game_manager() -> Dictionary:
	return {
		"state": GameManager.current_state,
		"score": GameManager.current_score,
		"best": GameManager.best_score,
	}


func _restore_game_manager(saved: Dictionary) -> void:
	GameManager.current_state = int(saved.get("state", GameManager.GameState.TITLE))
	GameManager.current_score = int(saved.get("score", 0))
	GameManager.best_score = int(saved.get("best", 0))


func _remove_temp_save() -> void:
	if FileAccess.file_exists(TEMP_SAVE_PATH):
		DirAccess.remove_absolute(TEMP_SAVE_PATH)
