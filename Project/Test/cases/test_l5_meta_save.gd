extends RefCounted
## spec 003 M1（T001 Red 卡重写）：meta 存档硬化 + run stats 补全 + run_ended 链路。
## 存档卫生（不可妥协）：所有用例注入临时 save_path（user:// 临时文件，测后删除），
## 绝不触碰生产存档 user://meta_save.json、绝不依赖其先验状态。
## run_ended 冻结契约 = spec FR-016；唯一发射点 = RunStatsTracker.finalize_run（FR-013）。

const META_SAVE_PATH: String = "res://systems/meta_growth/meta_save_system.gd"
const RUN_STATS_PATH: String = "res://systems/meta_growth/run_stats_tracker.gd"
const RUN_PROGRESSION_PATH: String = "res://systems/run/run_progression_system.gd"
const ROOM_FLOW_PATH: String = "res://systems/rooms/room_flow_system.gd"
const MetaSaveSystemScript := preload(META_SAVE_PATH)
const RunStatsTrackerScript := preload(RUN_STATS_PATH)

const TEMP_SAVE_PATH: String = "user://test_l5_meta_save_tmp.json"

## spec FR-016 冻结 stats 字段集（十字段，顶层 outcome 为准，无 run_outcome 冗余）
const FROZEN_STATS_KEYS: Array = [
	"total_turns", "total_kills", "reaction_kills", "near_death_count",
	"survival_low_length_ticks", "floors_completed", "max_reaction_chain",
	"damage_taken", "max_length", "duration_ticks",
]

var _run_ended_events: Array = []


func run(t) -> void:
	_test_save_path_injection_roundtrip(t)
	_test_default_path_comes_from_json(t)
	_test_tolerant_reset_on_bad_files(t)
	_test_reset_defaults_from_json(t)
	_test_stats_metric_sources(t)
	_test_finalize_contract_and_once_guard(t)
	_test_run_progression_victory_exit(t)
	_test_run_progression_death_exit(t)
	_remove_temp_save()


# === T002：save_path 注入缝 + schema_version 写入/读回 ===

func _test_save_path_injection_roundtrip(t) -> void:
	_remove_temp_save()
	var meta = MetaSaveSystemScript.new(TEMP_SAVE_PATH)
	t.assert_eq(meta.get_save_path(), TEMP_SAVE_PATH,
		"[L5-M1] injected save_path is used")

	meta.reset()
	meta.unlock_head("bai_she")
	t.assert_true(meta.save_to_disk(), "[L5-M1] save_to_disk writes injected path")
	t.assert_true(FileAccess.file_exists(TEMP_SAVE_PATH),
		"[L5-M1] temp save file created at injected path")

	var raw: Dictionary = _read_save_file_raw()
	t.assert_eq(int(raw.get("schema_version", -1)), ConfigManager.get_meta_schema_version(),
		"[L5-M1] save file carries current schema_version")

	var meta2 = MetaSaveSystemScript.new(TEMP_SAVE_PATH)
	t.assert_true(meta2.load_from_disk(), "[L5-M1] reload from same temp path succeeds")
	t.assert_true(meta2.is_head_unlocked("bai_she"),
		"[L5-M1] unlocked head persisted through save/load roundtrip")
	t.assert_true(meta2.is_tail_unlocked("salamander"),
		"[L5-M1] default unlocked tail survives roundtrip")
	_remove_temp_save()


func _test_default_path_comes_from_json(t) -> void:
	# 缺省路径出自 meta_growth.save_path（FR-009）；构造不再隐式读盘，
	# 仅构造默认实例不触碰生产存档。
	var meta = MetaSaveSystemScript.new()
	t.assert_eq(meta.get_save_path(),
		str(ConfigManager.get_meta_growth_config().get("save_path", "")),
		"[L5-M1] default save_path comes from JSON config")


# === T002：坏档 / 形状不符 / 缺档 / 未知版本 → 容错重置（FR-014） ===

func _test_tolerant_reset_on_bad_files(t) -> void:
	# 坏 JSON
	_write_temp_save("{{{ not valid json")
	var meta = MetaSaveSystemScript.new(TEMP_SAVE_PATH)
	t.assert_false(meta.load_from_disk(), "[L5-M1] corrupt JSON load returns false")
	_assert_default_state(t, meta, "corrupt JSON")

	# 合法 JSON 但非 Dictionary 形状
	_write_temp_save("[1, 2, 3]")
	var meta_shape = MetaSaveSystemScript.new(TEMP_SAVE_PATH)
	t.assert_false(meta_shape.load_from_disk(), "[L5-M1] non-Dictionary save load returns false")
	_assert_default_state(t, meta_shape, "non-Dictionary shape")

	# 未知 schema_version：绝不带病加载（medusa 不得泄入解锁集）
	_write_temp_save(JSON.stringify({
		"schema_version": 9999,
		"unlocked_heads": ["medusa"],
		"unlocked_tails": [],
		"legacy_stones": [],
	}))
	var meta_version = MetaSaveSystemScript.new(TEMP_SAVE_PATH)
	t.assert_false(meta_version.load_from_disk(),
		"[L5-M1] unknown schema_version load returns false")
	_assert_default_state(t, meta_version, "unknown schema_version")
	t.assert_false(meta_version.is_head_unlocked("medusa"),
		"[L5-M1] unknown-version content never half-loaded")

	# 缺档：重置默认、不崩溃
	_remove_temp_save()
	var meta_missing = MetaSaveSystemScript.new(TEMP_SAVE_PATH)
	t.assert_false(meta_missing.load_from_disk(), "[L5-M1] missing file load returns false")
	_assert_default_state(t, meta_missing, "missing file")


func _test_reset_defaults_from_json(t) -> void:
	var default_heads: Array = ConfigManager.get_default_unlocked_heads()
	var default_tails: Array = ConfigManager.get_default_unlocked_tails()
	t.assert_true(default_heads.has("hydra"), "[L5-M1] JSON default unlocked heads include hydra")
	t.assert_true(default_tails.has("salamander"),
		"[L5-M1] JSON default unlocked tails include salamander")

	var meta = MetaSaveSystemScript.new(TEMP_SAVE_PATH)
	meta.reset()
	t.assert_eq(meta.get_unlocked_heads(), default_heads,
		"[L5-M1] reset unlocked heads == JSON default set")
	t.assert_eq(meta.get_unlocked_tails(), default_tails,
		"[L5-M1] reset unlocked tails == JSON default set")
	t.assert_eq(meta.get_legacy_stones().size(), 0, "[L5-M1] reset clears legacy stones")


# === T003：度量源补全（damage / near_death / low_length / max_length / duration） ===

func _test_stats_metric_sources(t) -> void:
	var tracker: Node = RunStatsTrackerScript.new()
	t.add_child(tracker)

	EventBus.run_started.emit({"run_id": "run_m1_stats", "floor_index": 1, "seed": 7})

	# damage_taken：snake_hit_boundary + snake_body_attacked 双源（草稿仅 boundary）
	EventBus.snake_hit_boundary.emit({"position": Vector2i.ZERO, "direction": Vector2.RIGHT})
	EventBus.snake_body_attacked.emit({
		"position": Vector2i.ZERO, "segment": null, "enemy": null, "status_transferred": false,
	})
	t.assert_eq(int(tracker.get_stats().get("damage_taken", -1)), 2,
		"[L5-M1] damage_taken counts boundary hit + body attack")

	# near_death_count：无身体倒计时进入
	EventBus.no_body_countdown_started.emit({"total_seconds": 5})
	EventBus.no_body_countdown_started.emit({"total_seconds": 5})
	t.assert_eq(int(tracker.get_stats().get("near_death_count", -1)), 2,
		"[L5-M1] near_death_count counts no_body_countdown_started")

	# survival_low_length_ticks：tick_post_process + JSON 阈值（meta_growth.stats）
	var threshold: int = int(ConfigManager.get_meta_stats_config().get("low_length_threshold", 0))
	t.assert_true(threshold > 2, "[L5-M1] low_length_threshold defined in JSON (> 2)")

	EventBus.snake_length_increased.emit({"amount": 1, "source": "test", "new_length": threshold - 1})
	EventBus.tick_post_process.emit(1)
	EventBus.tick_post_process.emit(2)
	t.assert_eq(int(tracker.get_stats().get("survival_low_length_ticks", -1)), 2,
		"[L5-M1] low-length ticks counted while length < threshold")
	t.assert_eq(int(tracker.get_stats().get("duration_ticks", -1)), 2,
		"[L5-M1] duration_ticks counts run ticks")

	EventBus.snake_length_increased.emit({"amount": 5, "source": "test", "new_length": threshold + 3})
	EventBus.tick_post_process.emit(3)
	t.assert_eq(int(tracker.get_stats().get("survival_low_length_ticks", -1)), 2,
		"[L5-M1] low-length ticks stop above threshold")
	t.assert_eq(int(tracker.get_stats().get("max_length", -1)), threshold + 3,
		"[L5-M1] max_length tracks length peak")

	EventBus.snake_length_decreased.emit({"amount": 5, "source": "test", "new_length": threshold - 2})
	EventBus.tick_post_process.emit(4)
	t.assert_eq(int(tracker.get_stats().get("survival_low_length_ticks", -1)), 3,
		"[L5-M1] low-length ticks resume after shrink below threshold")
	t.assert_eq(int(tracker.get_stats().get("max_length", -1)), threshold + 3,
		"[L5-M1] max_length keeps peak after shrink")

	# 阈值 JSON 反证：调低阈值后同长度不再算低长度（运行时读 JSON，非硬编码）
	var stats_cfg: Dictionary = ConfigManager.get_meta_stats_config()
	stats_cfg["low_length_threshold"] = threshold - 2
	EventBus.tick_post_process.emit(5)
	t.assert_eq(int(tracker.get_stats().get("survival_low_length_ticks", -1)), 3,
		"[L5-M1] lowered JSON threshold stops low-length counting (data-driven proof)")
	stats_cfg["low_length_threshold"] = threshold
	t.assert_eq(int(tracker.get_stats().get("duration_ticks", -1)), 5,
		"[L5-M1] duration_ticks keeps counting regardless of threshold")

	# run_started 重置（FR-013）
	EventBus.run_started.emit({"run_id": "run_m1_stats2", "floor_index": 1, "seed": 8})
	var stats: Dictionary = tracker.get_stats()
	for key in FROZEN_STATS_KEYS:
		t.assert_eq(int(stats.get(key, -1)), 0, "[L5-M1] run_started resets %s" % key)

	tracker.cleanup()
	tracker.queue_free()


# === T003：finalize_run 冻结契约 + once-guard（FR-013/FR-016） ===

func _test_finalize_contract_and_once_guard(t) -> void:
	var tracker: Node = RunStatsTrackerScript.new()
	t.add_child(tracker)

	EventBus.run_started.emit({"run_id": "run_m1_contract", "floor_index": 1, "seed": 1})
	EventBus.floor_generated.emit({"floor_id": "floor_2_1", "floor_index": 2, "rooms": []})
	EventBus.enemy_killed.emit({"enemy_def": null, "position": Vector2i.ZERO, "method": "head_eat"})
	EventBus.enemy_killed.emit({"enemy_def": null, "position": Vector2i.ZERO, "method": "reaction_steam"})

	_collect_run_ended()
	var returned: Dictionary = tracker.finalize_run("death")
	t.assert_eq(_run_ended_events.size(), 1, "[L5-M1] finalize_run emits run_ended exactly once")

	var payload: Dictionary = _run_ended_events[0] if _run_ended_events.size() > 0 else {}
	t.assert_eq(payload.get("outcome", ""), "death", "[L5-M1] payload outcome is top-level")
	t.assert_eq(payload.get("run_id", ""), "run_m1_contract",
		"[L5-M1] payload run_id cached from run_started")
	t.assert_eq(int(payload.get("floor_index", -1)), 2,
		"[L5-M1] payload floor_index follows floor_generated")
	t.assert_eq(payload.size(), 4,
		"[L5-M1] payload has exactly outcome/run_id/floor_index/stats (frozen)")

	var stats: Dictionary = payload.get("stats", {})
	for key in FROZEN_STATS_KEYS:
		t.assert_true(stats.has(key), "[L5-M1] frozen stats key present: %s" % key)
	t.assert_eq(stats.size(), FROZEN_STATS_KEYS.size(),
		"[L5-M1] stats carries exactly the ten frozen keys")
	t.assert_false(stats.has("run_outcome"),
		"[L5-M1] stats.run_outcome duplication dropped (top-level outcome canonical)")
	t.assert_eq(int(stats.get("total_kills", -1)), 2, "[L5-M1] kills tracked into payload")
	t.assert_eq(int(stats.get("reaction_kills", -1)), 1,
		"[L5-M1] reaction kills tracked into payload")
	t.assert_eq(returned, stats, "[L5-M1] finalize_run returns the frozen stats")

	# once-guard：双 finalize 第二次零发射
	tracker.finalize_run("victory")
	t.assert_eq(_run_ended_events.size(), 1, "[L5-M1] second finalize_run rejected by once-guard")

	# 新 run 解除 guard
	EventBus.run_started.emit({"run_id": "run_m1_contract2", "floor_index": 1, "seed": 2})
	tracker.finalize_run("victory")
	t.assert_eq(_run_ended_events.size(), 2, "[L5-M1] run_started re-arms finalize guard")
	if _run_ended_events.size() >= 2:
		t.assert_eq(_run_ended_events[1].get("outcome", ""), "victory",
			"[L5-M1] second run payload outcome correct")
		t.assert_eq(_run_ended_events[1].get("run_id", ""), "run_m1_contract2",
			"[L5-M1] second run payload run_id correct")

	_stop_collect_run_ended()
	tracker.cleanup()
	tracker.queue_free()


# === T004：RunProgressionSystem victory 出口接线（注入 tracker，恰一次） ===

func _test_run_progression_victory_exit(t) -> void:
	var saved_state: int = GameManager.current_state
	var saved_score: int = GameManager.current_score
	var saved_best: int = GameManager.best_score

	var tracker: Node = RunStatsTrackerScript.new()
	t.add_child(tracker)
	var run_system: Node = load(RUN_PROGRESSION_PATH).new()
	t.add_child(run_system)
	var flow: Node = load(ROOM_FLOW_PATH).new()
	t.add_child(flow)
	run_system.set_stats_tracker(tracker)

	_collect_run_ended()
	run_system.start_run(1001)
	flow.enter_room(run_system.get_current_room())
	var path: Array = ConfigManager.get_floor_config().get("fixed_v1_path", [])
	_walk_fixed_path_to_endpoint(run_system, flow, path)

	t.assert_eq(run_system.get_state().get("outcome", ""), "victory",
		"[L5-M1] endpoint completion reaches victory exit")
	t.assert_eq(_run_ended_events.size(), 1,
		"[L5-M1] victory exit emits run_ended exactly once")
	var payload: Dictionary = _run_ended_events[0] if _run_ended_events.size() > 0 else {}
	t.assert_eq(payload.get("outcome", ""), "victory", "[L5-M1] victory payload outcome")
	t.assert_eq(payload.get("run_id", ""), "run_1_1001", "[L5-M1] victory payload run_id")
	t.assert_eq(int(payload.get("floor_index", -1)), 1, "[L5-M1] victory payload floor_index")
	t.assert_eq(int(payload.get("stats", {}).get("floors_completed", -1)), 1,
		"[L5-M1] victory payload stats include floors_completed")

	# 双出口防护：胜利后重复 mark_victory / 迟到 snake_died 均不再发射
	run_system.mark_victory("endpoint_01")
	EventBus.snake_died.emit({"cause": "late_after_victory"})
	t.assert_eq(_run_ended_events.size(), 1,
		"[L5-M1] no second run_ended after victory (double-exit guard)")

	_stop_collect_run_ended()
	flow.cleanup()
	flow.queue_free()
	run_system.cleanup()
	run_system.queue_free()
	tracker.cleanup()
	tracker.queue_free()
	GameManager.current_state = saved_state
	GameManager.current_score = saved_score
	GameManager.best_score = saved_best


# === T004：RunProgressionSystem death 出口接线 + 未注入零行为 ===

func _test_run_progression_death_exit(t) -> void:
	var saved_state: int = GameManager.current_state
	var saved_score: int = GameManager.current_score
	var saved_best: int = GameManager.best_score

	var tracker: Node = RunStatsTrackerScript.new()
	t.add_child(tracker)
	var run_system: Node = load(RUN_PROGRESSION_PATH).new()
	t.add_child(run_system)
	run_system.set_stats_tracker(tracker)

	_collect_run_ended()
	run_system.start_run(1001)
	EventBus.snake_died.emit({"cause": "m1_test_death"})

	t.assert_eq(_run_ended_events.size(), 1, "[L5-M1] death exit emits run_ended exactly once")
	var payload: Dictionary = _run_ended_events[0] if _run_ended_events.size() > 0 else {}
	t.assert_eq(payload.get("outcome", ""), "death", "[L5-M1] death payload outcome")
	t.assert_eq(payload.get("run_id", ""), "run_1_1001", "[L5-M1] death payload run_id")

	EventBus.snake_died.emit({"cause": "second_death"})
	t.assert_eq(_run_ended_events.size(), 1,
		"[L5-M1] repeated snake_died emits no second run_ended")

	# 新 run 解除双侧 guard：死亡后重开 → 胜利出口照常发射
	run_system.start_run(2002)
	run_system.mark_victory()
	t.assert_eq(_run_ended_events.size(), 2,
		"[L5-M1] start_run re-arms run-end emission for next run")
	if _run_ended_events.size() >= 2:
		t.assert_eq(_run_ended_events[1].get("outcome", ""), "victory",
			"[L5-M1] restarted run victory payload outcome")
		t.assert_eq(_run_ended_events[1].get("run_id", ""), "run_1_2002",
			"[L5-M1] restarted run payload run_id")

	# 未注入 tracker 的系统零行为（L3 既有测试零破坏）
	var bare: Node = load(RUN_PROGRESSION_PATH).new()
	t.add_child(bare)
	bare.start_run(3003)
	EventBus.snake_died.emit({"cause": "bare_death"})
	t.assert_eq(_run_ended_events.size(), 2,
		"[L5-M1] uninjected RunProgressionSystem emits no run_ended")
	bare.cleanup()
	bare.queue_free()

	_stop_collect_run_ended()
	run_system.cleanup()
	run_system.queue_free()
	tracker.cleanup()
	tracker.queue_free()
	GameManager.current_state = saved_state
	GameManager.current_score = saved_score
	GameManager.best_score = saved_best


# === helpers ===

func _assert_default_state(t, meta, label: String) -> void:
	t.assert_true(meta.is_head_unlocked("hydra"),
		"[L5-M1] %s -> default head hydra unlocked" % label)
	t.assert_true(meta.is_tail_unlocked("salamander"),
		"[L5-M1] %s -> default tail salamander unlocked" % label)
	t.assert_eq(meta.get_legacy_stones().size(), 0,
		"[L5-M1] %s -> legacy stones reset empty" % label)


func _walk_fixed_path_to_endpoint(run_system: Node, flow: Node, path: Array) -> void:
	flow.record_objective_progress(3, {"method": "m1_combat_01"})
	run_system.advance_to_room(path[1])
	flow.record_objective_progress(1, {"method": "m1_reward"})
	run_system.advance_to_room(path[2])
	flow.record_objective_progress(3, {"method": "m1_combat_02"})
	run_system.advance_to_room(path[3])  # shop_01（auto_complete_on_enter）
	run_system.advance_to_room(path[4])  # rest_01
	run_system.advance_to_room(path[5])  # endpoint_01


func _collect_run_ended() -> void:
	_run_ended_events.clear()
	if not EventBus.run_ended.is_connected(_on_run_ended):
		EventBus.run_ended.connect(_on_run_ended)


func _stop_collect_run_ended() -> void:
	if EventBus.run_ended.is_connected(_on_run_ended):
		EventBus.run_ended.disconnect(_on_run_ended)


func _on_run_ended(data: Dictionary) -> void:
	_run_ended_events.append(data)


func _write_temp_save(text: String) -> void:
	var file := FileAccess.open(TEMP_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(text)
		file.close()


func _read_save_file_raw() -> Dictionary:
	if not FileAccess.file_exists(TEMP_SAVE_PATH):
		return {}
	var file := FileAccess.open(TEMP_SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	return json.data if json.data is Dictionary else {}


func _remove_temp_save() -> void:
	if FileAccess.file_exists(TEMP_SAVE_PATH):
		DirAccess.remove_absolute(TEMP_SAVE_PATH)
