extends RefCounted
## spec 003 M2（T006 Red 卡重写）：解锁门控对照 Designs §12.3 附录「v1 内容映射」。
## 覆盖：v1 双条件 JSON（reaction_kills_10 → bai_she / floors_2 → lag_tail）+ 数据互证
## （target_id 必须存在于 snake_heads/snake_tails 内容池）；UnlockSystem 幂等/落盘/事件路径；
## MetaGrowthRoot 装配（main.tscn 常驻、GameWorldContainer 外、跨 run 存续）；
## RewardFlow 解锁过滤（锁定不进 offer、解锁后进入、未注入全量回退、滤空自动决议 FR-014）；
## 解锁 toast 数据通路（toast 层 ≤1）；game_over 结算数据通路（统计/解锁/铸石文本行）。
## 存档卫生（不可妥协）：全部用例注入临时 save_path 并测后删除，
## 绝不触碰生产存档 user://meta_save.json、绝不依赖其先验状态。

const UNLOCK_PATH: String = "res://systems/meta_growth/unlock_system.gd"
const META_ROOT_PATH: String = "res://systems/meta_growth/meta_growth_root.gd"
const TOAST_PATH: String = "res://ui/unlock_toast.gd"
const REWARD_FLOW_PATH: String = "res://systems/rewards/reward_flow_system.gd"
const RUN_PROGRESSION_PATH: String = "res://systems/run/run_progression_system.gd"
const MAIN_SCENE_PATH: String = "res://scenes/main.tscn"
const MetaSaveSystemScript := preload("res://systems/meta_growth/meta_save_system.gd")

const TEMP_SAVE_PATH: String = "user://test_l5_unlocks_tmp.json"

## backlog.md 收容的草稿目标（内容 JSON 不存在，v1 条件绝不指向）
const DRAFT_TARGET_IDS: Array = ["ungud", "medusa", "taotie", "styx_tail"]

## spec FR-016 冻结 stats 字段集（condition_type 枚举必须对齐其中之一）
const FROZEN_STATS_KEYS: Array = [
	"total_turns", "total_kills", "reaction_kills", "near_death_count",
	"survival_low_length_ticks", "floors_completed", "max_reaction_chain",
	"damage_taken", "max_length", "duration_ticks",
]

var _unlocked_events: Array = []
var _reward_presented_events: Array = []
var _reward_chosen_events: Array = []
var _room_completed_events: Array = []


func run(t) -> void:
	_test_v1_unlock_conditions_json(t)
	_test_default_unlock_json(t)
	_test_reward_pool_contains_gated_content(t)
	_test_unlock_system_v1_mapping(t)
	_test_unlock_system_run_ended_event_path(t)
	_test_unlock_system_no_class_name(t)
	_test_main_scene_has_meta_growth_root(t)
	_test_meta_growth_root_lifecycle(t)
	_test_attach_world_wiring(t)
	_test_reward_flow_unlock_filtering(t)
	_test_reward_flow_filtered_empty_auto_resolution(t)
	_test_unlock_toast_data_path(t)
	_test_game_over_summary_data_path(t)
	_remove_temp_save()


# === T007：unlock_conditions 重写为 v1 双条件（Designs §12.3 附录） ===

func _test_v1_unlock_conditions_json(t) -> void:
	var conditions: Array = ConfigManager.get_unlock_conditions()
	t.assert_eq(conditions.size(), 2, "[L5-M2] v1 unlock_conditions is exactly the pair")

	var by_id: Dictionary = {}
	for cond in conditions:
		if cond is Dictionary:
			by_id[cond.get("condition_id", "")] = cond

	var bai_she: Dictionary = by_id.get("reaction_kills_10", {})
	t.assert_false(bai_she.is_empty(), "[L5-M2] reaction_kills_10 condition present")
	t.assert_eq(bai_she.get("condition_type", ""), "reaction_kills",
		"[L5-M2] bai_she condition reads FR-016 reaction_kills stat")
	t.assert_eq(int(bai_she.get("threshold", 0)), 10, "[L5-M2] bai_she threshold = 10")
	t.assert_eq(bai_she.get("target_type", ""), "head", "[L5-M2] bai_she target_type head")
	t.assert_eq(bai_she.get("target_id", ""), "bai_she", "[L5-M2] bai_she target_id")

	var lag_tail: Dictionary = by_id.get("floors_2", {})
	t.assert_false(lag_tail.is_empty(), "[L5-M2] floors_2 condition present")
	t.assert_eq(lag_tail.get("condition_type", ""), "floors_completed",
		"[L5-M2] lag_tail condition reads FR-016 floors_completed stat")
	t.assert_eq(int(lag_tail.get("threshold", 0)), 2, "[L5-M2] lag_tail threshold = 2")
	t.assert_eq(lag_tail.get("target_type", ""), "tail", "[L5-M2] lag_tail target_type tail")
	t.assert_eq(lag_tail.get("target_id", ""), "lag_tail", "[L5-M2] lag_tail target_id")

	# display_name 对齐内容池（白蛇 / 时滞尾）
	t.assert_eq(bai_she.get("display_name", ""),
		ConfigManager.snake_heads.get("bai_she", {}).get("display_name", "?"),
		"[L5-M2] bai_she display_name matches content pool")
	t.assert_eq(lag_tail.get("display_name", ""),
		ConfigManager.snake_tails.get("lag_tail", {}).get("display_name", "?"),
		"[L5-M2] lag_tail display_name matches content pool")

	# 数据互证（设计先行红线）：target_id 必须存在于内容池；condition_type ∈ FR-016 冻结字段；
	# 草稿目标（ungud/medusa/taotie/styx_tail）零残留（backlog.md 收容）
	for cond in conditions:
		var target_type: String = cond.get("target_type", "")
		var target_id: String = cond.get("target_id", "")
		if target_type == "head":
			t.assert_true(ConfigManager.get_snake_head_ids().has(target_id),
				"[L5-M2] head target exists in snake_heads pool: %s" % target_id)
		elif target_type == "tail":
			t.assert_true(ConfigManager.get_snake_tail_ids().has(target_id),
				"[L5-M2] tail target exists in snake_tails pool: %s" % target_id)
		else:
			t.assert_true(false, "[L5-M2] unknown target_type: %s" % target_type)
		t.assert_true(FROZEN_STATS_KEYS.has(cond.get("condition_type", "")),
			"[L5-M2] condition_type aligns FR-016 stats key: %s" % cond.get("condition_type", ""))
		t.assert_false(DRAFT_TARGET_IDS.has(target_id),
			"[L5-M2] no draft (backlog) target in v1 conditions: %s" % target_id)


func _test_default_unlock_json(t) -> void:
	t.assert_eq(ConfigManager.get_default_unlocked_heads(), ["hydra"],
		"[L5-M2] default unlocked heads == [hydra] (Designs 12.3 v1)")
	t.assert_eq(ConfigManager.get_default_unlocked_tails(), ["salamander"],
		"[L5-M2] default unlocked tails == [salamander] (Designs 12.3 v1)")
	t.assert_true(ConfigManager.get_snake_head_ids().has("hydra"),
		"[L5-M2] default head exists in content pool")
	t.assert_true(ConfigManager.get_snake_tail_ids().has("salamander"),
		"[L5-M2] default tail exists in content pool")


## 生产数据通路：解锁内容必须有 offer 渠道——starter_build 池含被门控的 bai_she/lag_tail
## （新档被解锁集过滤掉，解锁后进入；纯测试池断言无法证明生产可达性）
func _test_reward_pool_contains_gated_content(t) -> void:
	var pool: Array = ConfigManager.get_reward_pool("starter_build")
	var has_bai_she: bool = false
	var has_lag_tail: bool = false
	for option in pool:
		if not (option is Dictionary):
			continue
		if option.get("reward_type", "") == "head" and option.get("target_id", "") == "bai_she":
			has_bai_she = true
		if option.get("reward_type", "") == "tail" and option.get("target_id", "") == "lag_tail":
			has_lag_tail = true
	t.assert_true(has_bai_she, "[L5-M2] starter_build pool carries gated bai_she head option")
	t.assert_true(has_lag_tail, "[L5-M2] starter_build pool carries gated lag_tail tail option")


# === T008：UnlockSystem v1 映射评估 + 幂等 + 落盘 ===

func _test_unlock_system_v1_mapping(t) -> void:
	_remove_temp_save()
	var meta = MetaSaveSystemScript.new(TEMP_SAVE_PATH)
	meta.reset()

	var unlock: Node = load(UNLOCK_PATH).new()
	unlock.setup(meta)
	t.add_child(unlock)
	_collect_unlocked()

	# 新档：锁定集正确
	t.assert_false(meta.is_head_unlocked("bai_she"), "[L5-M2] fresh save: bai_she locked")
	t.assert_false(meta.is_tail_unlocked("lag_tail"), "[L5-M2] fresh save: lag_tail locked")

	# 低于阈值零解锁
	var below: Array = unlock.check_unlocks({"reaction_kills": 9, "floors_completed": 1})
	t.assert_eq(below.size(), 0, "[L5-M2] below-threshold stats unlock nothing")
	t.assert_eq(_unlocked_events.size(), 0, "[L5-M2] below-threshold stats emit no event")

	# reaction_kills ≥ 10 → bai_she（事件 payload 契约）
	var unlocked: Array = unlock.check_unlocks({"reaction_kills": 10, "floors_completed": 0})
	t.assert_eq(unlocked.size(), 1, "[L5-M2] reaction_kills 10 unlocks exactly one")
	t.assert_true(meta.is_head_unlocked("bai_she"), "[L5-M2] bai_she unlocked at threshold")
	t.assert_eq(_unlocked_events.size(), 1, "[L5-M2] content_unlocked emitted once")
	if _unlocked_events.size() >= 1:
		t.assert_eq(_unlocked_events[0].get("content_type", ""), "head",
			"[L5-M2] event content_type head")
		t.assert_eq(_unlocked_events[0].get("content_id", ""), "bai_she",
			"[L5-M2] event content_id bai_she")
		t.assert_eq(_unlocked_events[0].get("display_name", ""), "白蛇",
			"[L5-M2] event display_name aligned with content pool")

	# 解锁即落盘（FR-002）：同路径新实例读回
	var reloaded = MetaSaveSystemScript.new(TEMP_SAVE_PATH)
	t.assert_true(reloaded.load_from_disk(), "[L5-M2] save written on unlock")
	t.assert_true(reloaded.is_head_unlocked("bai_she"), "[L5-M2] bai_she persisted to disk")

	# floors_completed ≥ 2 → lag_tail
	unlock.check_unlocks({"reaction_kills": 0, "floors_completed": 2})
	t.assert_true(meta.is_tail_unlocked("lag_tail"), "[L5-M2] lag_tail unlocked at 2 floors")

	# 幂等：重复达成零二次解锁、零事件（Edge Case）
	_unlocked_events.clear()
	var repeat: Array = unlock.check_unlocks({"reaction_kills": 25, "floors_completed": 3})
	t.assert_eq(repeat.size(), 0, "[L5-M2] repeated achievement: no duplicate unlock")
	t.assert_eq(_unlocked_events.size(), 0, "[L5-M2] repeated achievement: no duplicate event")

	_stop_collect_unlocked()
	unlock.cleanup()
	unlock.queue_free()
	_remove_temp_save()


## run_ended（FR-016 payload）事件路径驱动解锁（非仅直调 check_unlocks）
func _test_unlock_system_run_ended_event_path(t) -> void:
	_remove_temp_save()
	var meta = MetaSaveSystemScript.new(TEMP_SAVE_PATH)
	meta.reset()
	var unlock: Node = load(UNLOCK_PATH).new()
	unlock.setup(meta)
	t.add_child(unlock)

	EventBus.run_ended.emit({
		"outcome": "death",
		"run_id": "m2_event_path",
		"floor_index": 1,
		"stats": {"reaction_kills": 11, "floors_completed": 0},
	})
	t.assert_true(meta.is_head_unlocked("bai_she"),
		"[L5-M2] run_ended event path drives unlock evaluation")

	unlock.cleanup()
	unlock.queue_free()
	_remove_temp_save()


## 去 class_name（ScriptingLeading C.8）：源文件零裸全局类名声明
func _test_unlock_system_no_class_name(t) -> void:
	var file := FileAccess.open(UNLOCK_PATH, FileAccess.READ)
	t.assert_true(file != null, "[L5-M2] unlock_system source readable")
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()
	t.assert_false(text.begins_with("class_name") or text.contains("\nclass_name"),
		"[L5-M2] unlock_system.gd carries no class_name (C.8)")


# === T009：MetaGrowthRoot 装配（main.tscn 常驻、GameWorldContainer 外） ===

func _test_main_scene_has_meta_growth_root(t) -> void:
	t.assert_file_exists(META_ROOT_PATH)
	var scene = load(MAIN_SCENE_PATH) as PackedScene
	t.assert_true(scene != null, "[L5-M2] main.tscn loads")
	if scene == null:
		return
	# 不入树（_ready 不跑）：纯结构断言，生产存档零 IO
	var instance: Node = scene.instantiate()
	t.assert_true(instance.has_node("MetaGrowthRoot"),
		"[L5-M2] MetaGrowthRoot resident in main.tscn")
	t.assert_false(instance.has_node("GameWorldContainer/MetaGrowthRoot"),
		"[L5-M2] MetaGrowthRoot lives OUTSIDE GameWorldContainer (cross-run survival)")
	if instance.has_node("MetaGrowthRoot"):
		var root: Node = instance.get_node("MetaGrowthRoot")
		t.assert_true(root.get_script() != null
			and str(root.get_script().resource_path) == META_ROOT_PATH,
			"[L5-M2] MetaGrowthRoot carries meta_growth_root.gd")
	instance.free()


func _test_meta_growth_root_lifecycle(t) -> void:
	var saved: Dictionary = _save_game_manager()
	_remove_temp_save()

	var root: Node = load(META_ROOT_PATH).new()
	root.boot(TEMP_SAVE_PATH)
	t.add_child(root)

	# boot：注入路径生效 + 子系统挂载（tracker/unlock/legacy setup(meta_save)）
	t.assert_eq(root.get_meta_save().get_save_path(), TEMP_SAVE_PATH,
		"[L5-M2] root boot uses injected save_path")
	t.assert_true(root.get_stats_tracker() != null and root.get_stats_tracker().is_inside_tree(),
		"[L5-M2] root hosts RunStatsTracker child")
	t.assert_true(root.get_unlock_system() != null and root.get_unlock_system().is_inside_tree(),
		"[L5-M2] root hosts UnlockSystem child")
	t.assert_true(root.get_legacy_stone_system() != null
		and root.get_legacy_stone_system().is_inside_tree(),
		"[L5-M2] root hosts LegacyStoneSystem child")

	# 解锁查询口径：默认解锁可用、锁定不可用、鳞片 v1 不门控（Designs §12.3 附录）
	t.assert_true(root.is_content_unlocked("head", "hydra"),
		"[L5-M2] root query: default head unlocked")
	t.assert_false(root.is_content_unlocked("head", "bai_she"),
		"[L5-M2] root query: gated head locked on fresh save")
	t.assert_true(root.is_content_unlocked("scale", "flame_scale"),
		"[L5-M2] root query: scales ungated in v1")

	# 一局全程：run_started → 统计累积 → finalize → 解锁评估 + 落盘 + 结算缓存
	_collect_unlocked()
	EventBus.run_started.emit({"run_id": "m2_root_run", "floor_index": 1, "seed": 11})
	for _i in range(10):
		EventBus.enemy_killed.emit(
			{"enemy_def": null, "position": Vector2i.ZERO, "method": "reaction_steam"})
	EventBus.floor_completed.emit({"run_id": "m2_root_run", "floor_index": 1})
	EventBus.floor_completed.emit({"run_id": "m2_root_run", "floor_index": 2})
	root.get_stats_tracker().finalize_run("death")

	t.assert_eq(_unlocked_events.size(), 2,
		"[L5-M2] run end unlocks both v1 targets (bai_she + lag_tail)")
	t.assert_true(root.get_meta_save().is_head_unlocked("bai_she"),
		"[L5-M2] root run end unlocked bai_she")
	t.assert_true(root.get_meta_save().is_tail_unlocked("lag_tail"),
		"[L5-M2] root run end unlocked lag_tail")

	var reloaded = MetaSaveSystemScript.new(TEMP_SAVE_PATH)
	t.assert_true(reloaded.load_from_disk() and reloaded.is_head_unlocked("bai_she"),
		"[L5-M2] root unlocks persisted to injected temp path")

	# 结算数据通路（M2 卡）：统计 + 本局新解锁 + 铸石缓存
	var summary: Dictionary = root.get_last_run_summary()
	t.assert_eq(summary.get("outcome", ""), "death", "[L5-M2] summary outcome cached")
	t.assert_eq(int(summary.get("stats", {}).get("reaction_kills", -1)), 10,
		"[L5-M2] summary carries frozen run stats")
	t.assert_eq(summary.get("unlocks", []).size(), 2,
		"[L5-M2] summary carries unlocks earned this run")
	t.assert_true(str(summary.get("stone", {}).get("display_name", "")) != "",
		"[L5-M2] summary carries forged legacy stone")

	# 跨 run 存续 + 幂等：新局重置结算缓存，解锁集保留，重复达成零二次解锁
	_unlocked_events.clear()
	EventBus.run_started.emit({"run_id": "m2_root_run2", "floor_index": 1, "seed": 12})
	t.assert_true(root.get_last_run_summary().is_empty(),
		"[L5-M2] new run clears last-run summary cache")
	t.assert_true(root.get_meta_save().is_head_unlocked("bai_she"),
		"[L5-M2] unlock set survives across runs (root persists outside world)")
	for _i in range(10):
		EventBus.enemy_killed.emit(
			{"enemy_def": null, "position": Vector2i.ZERO, "method": "reaction_steam"})
	root.get_stats_tracker().finalize_run("victory")
	t.assert_eq(_unlocked_events.size(), 0,
		"[L5-M2] repeated achievement across runs: no duplicate unlock event")
	var summary2: Dictionary = root.get_last_run_summary()
	t.assert_eq(summary2.get("outcome", ""), "victory", "[L5-M2] second run summary cached")
	t.assert_eq(summary2.get("unlocks", []).size(), 0,
		"[L5-M2] second run summary carries no stale unlocks")

	_stop_collect_unlocked()
	root.cleanup()
	root.queue_free()
	_restore_game_manager(saved)
	_remove_temp_save()


# === T009/T010：attach_world 接线（tracker 注入 + 解锁过滤注入，口径同 set_sampling_bias） ===

func _test_attach_world_wiring(t) -> void:
	var saved: Dictionary = _save_game_manager()
	_remove_temp_save()

	var root: Node = load(META_ROOT_PATH).new()
	root.boot(TEMP_SAVE_PATH)
	t.add_child(root)

	var world := Node.new()
	world.name = "M2MockWorld"
	var run_system: Node = load(RUN_PROGRESSION_PATH).new()
	run_system.name = "RunProgressionSystem"
	world.add_child(run_system)
	var flow: Node = load(REWARD_FLOW_PATH).new()
	flow.name = "RewardFlowSystem"
	world.add_child(flow)
	t.add_child(world)
	var managers: Dictionary = _make_build_managers()
	flow.setup(managers.get("parts_mgr"), managers.get("scale_mgr"))

	root.attach_world(world)

	# tracker 注入生效：death 出口 run_ended 恰一次、解锁走 root 的 meta、结算缓存就绪
	_collect_unlocked()
	run_system.start_run(7001)
	for _i in range(10):
		EventBus.enemy_killed.emit(
			{"enemy_def": null, "position": Vector2i.ZERO, "method": "reaction_burst"})
	EventBus.snake_died.emit({"cause": "m2_attach_death"})

	t.assert_true(root.get_meta_save().is_head_unlocked("bai_she"),
		"[L5-M2] attach_world wires tracker -> run_ended -> unlock evaluation")
	t.assert_eq(root.get_last_run_summary().get("outcome", ""), "death",
		"[L5-M2] attach_world run end fills summary cache")

	# 解锁过滤注入生效：布景池（lag_tail 仍锁 / bai_she 本局已解锁 / hydra 默认）
	var saved_pool: Array = _stage_starter_pool([
		_tail_option("lag_tail", "时滞尾"),
		_head_option("bai_she", "白蛇"),
		_head_option("hydra", "九头蛇"),
	])
	var offer: Dictionary = flow.present_offer({"room_id": "m2_attach_room", "room_type": "reward"})
	var ids: Array = _option_target_ids(offer.get("options", []))
	t.assert_false(ids.has("lag_tail"),
		"[L5-M2] attach_world filter: still-locked tail absent from offer")
	t.assert_true(ids.has("bai_she"),
		"[L5-M2] attach_world filter: freshly unlocked head present in offer")
	t.assert_true(ids.has("hydra"),
		"[L5-M2] attach_world filter: default-unlocked head present in offer")

	_restore_starter_pool(saved_pool)
	_stop_collect_unlocked()
	flow.cleanup()
	run_system.cleanup()
	_cleanup_build_managers(managers)
	world.queue_free()
	root.cleanup()
	root.queue_free()
	_restore_game_manager(saved)
	_remove_temp_save()


# === T010：RewardFlow 解锁过滤（未注入全量回退 / 锁定不进 offer / 解锁后进入） ===

func _test_reward_flow_unlock_filtering(t) -> void:
	_remove_temp_save()
	var meta = MetaSaveSystemScript.new(TEMP_SAVE_PATH)
	meta.reset()

	var managers: Dictionary = _make_build_managers()
	var flow: Node = load(REWARD_FLOW_PATH).new()
	flow.setup(managers.get("parts_mgr"), managers.get("scale_mgr"))
	t.add_child(flow)

	var saved_pool: Array = _stage_starter_pool([
		_head_option("bai_she", "白蛇"),
		_tail_option("lag_tail", "时滞尾"),
		_head_option("hydra", "九头蛇"),
	])

	# 1) 未注入：全量回退（L3 既有行为零破坏）
	var offer: Dictionary = flow.present_offer({"room_id": "m2_filter_a", "room_type": "reward"})
	var ids: Array = _option_target_ids(offer.get("options", []))
	t.assert_true(ids.has("bai_she") and ids.has("lag_tail"),
		"[L5-M2] uninjected flow falls back to full pool (L3 compatibility)")
	_rearm_flow(flow)

	# 2) 注入 + 新档：锁定内容不进 offer
	var query := func(content_type: String, content_id: String) -> bool:
		if content_type == "head":
			return meta.is_head_unlocked(content_id)
		if content_type == "tail":
			return meta.is_tail_unlocked(content_id)
		return true
	flow.set_unlock_query(query)

	offer = flow.present_offer({"room_id": "m2_filter_b", "room_type": "reward"})
	ids = _option_target_ids(offer.get("options", []))
	t.assert_false(ids.has("bai_she"), "[L5-M2] locked bai_she absent from offer")
	t.assert_false(ids.has("lag_tail"), "[L5-M2] locked lag_tail absent from offer")
	t.assert_true(ids.has("hydra"), "[L5-M2] default-unlocked hydra present in offer")
	_rearm_flow(flow)

	# 3) 解锁后进入下局奖励池
	meta.unlock_head("bai_she")
	offer = flow.present_offer({"room_id": "m2_filter_c", "room_type": "reward"})
	ids = _option_target_ids(offer.get("options", []))
	t.assert_true(ids.has("bai_she"), "[L5-M2] unlocked bai_she enters next offer")
	t.assert_false(ids.has("lag_tail"), "[L5-M2] still-locked lag_tail stays absent")
	_rearm_flow(flow)

	# 4) 生产池 + 新档：头/尾 offer 恰为默认解锁集（bai_she/lag_tail 被过滤）
	_restore_starter_pool(saved_pool)
	var fresh = MetaSaveSystemScript.new(TEMP_SAVE_PATH)
	fresh.reset()
	var fresh_query := func(content_type: String, content_id: String) -> bool:
		if content_type == "head":
			return fresh.is_head_unlocked(content_id)
		if content_type == "tail":
			return fresh.is_tail_unlocked(content_id)
		return true
	flow.set_unlock_query(fresh_query)
	offer = flow.present_offer({"room_id": "m2_filter_d", "room_type": "reward"})
	for option in offer.get("options", []):
		var reward_type: String = option.get("reward_type", "")
		if reward_type == "head":
			t.assert_true(ConfigManager.get_default_unlocked_heads().has(option.get("target_id", "")),
				"[L5-M2] production pool fresh-save head offers only default unlocks")
		elif reward_type == "tail":
			t.assert_true(ConfigManager.get_default_unlocked_tails().has(option.get("target_id", "")),
				"[L5-M2] production pool fresh-save tail offers only default unlocks")
	_rearm_flow(flow)

	flow.cleanup()
	_cleanup_build_managers(managers)
	flow.queue_free()
	_remove_temp_save()


## 过滤后零选项必须走既有 FR-014 自动决议（不弹模态、合成 room_completed 保留——不死锁）
func _test_reward_flow_filtered_empty_auto_resolution(t) -> void:
	_remove_temp_save()
	var meta = MetaSaveSystemScript.new(TEMP_SAVE_PATH)
	meta.reset()

	var managers: Dictionary = _make_build_managers()
	var flow: Node = load(REWARD_FLOW_PATH).new()
	flow.setup(managers.get("parts_mgr"), managers.get("scale_mgr"))
	t.add_child(flow)
	flow.set_unlock_query(func(content_type: String, content_id: String) -> bool:
		if content_type == "head":
			return meta.is_head_unlocked(content_id)
		if content_type == "tail":
			return meta.is_tail_unlocked(content_id)
		return true)

	var saved_pool: Array = _stage_starter_pool([_head_option("bai_she", "白蛇")])
	_connect_reward_recorders()
	flow.present_offer({"room_id": "m2_locked_only", "room_type": "reward"})

	t.assert_eq(_reward_presented_events.size(), 0,
		"[L5-M2] all-locked pool presents no offer (no modal)")
	t.assert_eq(_reward_chosen_events.size(), 1,
		"[L5-M2] all-locked pool auto-resolves with reward_chosen")
	if _reward_chosen_events.size() >= 1:
		t.assert_true(bool(_reward_chosen_events[0].get("skipped", false)),
			"[L5-M2] auto-resolution carries skipped=true (FR-014)")
	t.assert_eq(_room_completed_events.size(), 1,
		"[L5-M2] auto-resolution keeps synthetic room_completed (FR-018, no deadlock)")
	t.assert_false(flow.has_pending_offer(),
		"[L5-M2] auto-resolution leaves no pending offer")

	_disconnect_reward_recorders()
	_restore_starter_pool(saved_pool)
	flow.cleanup()
	_cleanup_build_managers(managers)
	flow.queue_free()
	_remove_temp_save()


# === T011：解锁 toast（kit chip，toast 层，≤1，数据通路 only） ===

func _test_unlock_toast_data_path(t) -> void:
	t.assert_file_exists(TOAST_PATH)
	if not FileAccess.file_exists(TOAST_PATH):
		return

	var toast: Control = load(TOAST_PATH).new()
	toast.name = "M2UnlockToast"
	t.add_child(toast)

	# kit 出生即带：分组 / ui_layer 元数据（几何探测进组自动覆盖；toast ≤1 层规则）
	t.assert_true(toast.is_in_group("ui_kit"), "[L5-M2] toast born in ui_kit group")
	t.assert_true(toast.is_in_group("ui_chip"), "[L5-M2] toast born in ui_chip group")
	t.assert_eq(toast.get_ui_layer(), "toast", "[L5-M2] toast carries ui_layer=toast meta")
	t.assert_false(toast.visible, "[L5-M2] toast hidden before any unlock")

	EventBus.content_unlocked.emit(
		{"content_type": "head", "content_id": "bai_she", "display_name": "白蛇"})
	t.assert_true(toast.visible, "[L5-M2] toast appears on content_unlocked")
	t.assert_true(toast.get_text().contains("白蛇"), "[L5-M2] toast shows unlock display_name")
	t.assert_true(toast.get_text().contains("解锁"), "[L5-M2] toast labels the unlock semantics")

	# 重复解锁原地更新（恒 ≤1 件可见 toast）
	EventBus.content_unlocked.emit(
		{"content_type": "tail", "content_id": "lag_tail", "display_name": "时滞尾"})
	t.assert_true(toast.get_text().contains("时滞尾"),
		"[L5-M2] second unlock updates toast in place")
	var visible_toasts: int = 0
	for node in t.get_tree().get_nodes_in_group("ui_kit"):
		if node is Control and node.visible and str(node.get_meta("ui_layer", "")) == "toast":
			visible_toasts += 1
	t.assert_eq(visible_toasts, 1, "[L5-M2] at most one visible toast (geometry rule)")

	# run_started 收起（下局开始不残留）
	EventBus.run_started.emit({"run_id": "m2_toast_run", "floor_index": 1, "seed": 3})
	t.assert_false(toast.visible, "[L5-M2] toast hides on next run_started")

	toast.disconnect_events()
	toast.queue_free()


# === M2 结算数据通路：game_over_screen 文本行（统计 + 解锁 + 铸石，kit 样式零仪式） ===

func _test_game_over_summary_data_path(t) -> void:
	var saved: Dictionary = _save_game_manager()
	_remove_temp_save()

	# 临时档 root 直驱一局（death + 双解锁 + 铸石）
	var root: Node = load(META_ROOT_PATH).new()
	root.boot(TEMP_SAVE_PATH)
	t.add_child(root)
	EventBus.run_started.emit({"run_id": "m2_summary_run", "floor_index": 1, "seed": 21})
	for _i in range(10):
		EventBus.enemy_killed.emit(
			{"enemy_def": null, "position": Vector2i.ZERO, "method": "reaction_steam"})
	root.get_stats_tracker().finalize_run("death")

	# 从 main.tscn 拆出 GameOverScreen 子树入树（整壳不入树：生产存档零 IO）
	var app: Node = load(MAIN_SCENE_PATH).instantiate()
	var screen: Control = app.get_node("UILayer/GameOverScreen")
	screen.get_parent().remove_child(screen)
	t.add_child(screen)
	app.free()

	t.assert_true(screen.has_method("set_summary_source"),
		"[L5-M2] game_over_screen exposes summary source seam")
	screen.set_summary_source(root)
	screen.show_results({"score": 10, "best_score": 12, "cause": "m2_summary"})

	var lines: Array = screen.get_summary_lines()
	t.assert_true(lines.size() >= 3,
		"[L5-M2] summary renders stats + unlock + stone rows")
	var joined: String = "\n".join(PackedStringArray(lines))
	t.assert_true(joined.contains("击杀 10"), "[L5-M2] summary stats row carries kill count")
	t.assert_true(joined.contains("解锁") and joined.contains("白蛇"),
		"[L5-M2] summary lists unlock earned this run")
	t.assert_true(joined.contains("传承石"), "[L5-M2] summary lists forged legacy stone")

	# 基线契约不破（test_t11 节点路径 + show_results 既有语义）
	var score_label: Label = screen.get_node("VBoxContainer/ScoreLabel")
	t.assert_true(score_label.text.contains("10"), "[L5-M2] base score line intact")

	# 新局开始后再呈现：结算行清空（无陈旧数据）
	EventBus.run_started.emit({"run_id": "m2_summary_run2", "floor_index": 1, "seed": 22})
	screen.show_results({"score": 0, "best_score": 12, "cause": "m2_summary2"})
	t.assert_eq(screen.get_summary_lines().size(), 0,
		"[L5-M2] summary rows cleared once a new run starts")

	root.cleanup()
	root.queue_free()
	screen.queue_free()
	_restore_game_manager(saved)
	_remove_temp_save()


# === helpers ===

func _head_option(target_id: String, display: String) -> Dictionary:
	return {
		"option_id": "head_%s" % target_id, "display_name": display, "reward_type": "head",
		"target_id": target_id, "target_slot": "head", "level_delta": 0,
		"placeholder_color": "#FFFFFF",
	}


func _tail_option(target_id: String, display: String) -> Dictionary:
	return {
		"option_id": "tail_%s" % target_id, "display_name": display, "reward_type": "tail",
		"target_id": target_id, "target_slot": "tail", "level_delta": 0,
		"placeholder_color": "#FFFFFF",
	}


func _option_target_ids(options: Array) -> Array:
	var ids: Array = []
	for option in options:
		if option is Dictionary:
			ids.append(option.get("target_id", ""))
	return ids


## 池布景（改写 ConfigManager 段并还原——repo 既定数据反证模式）
func _stage_starter_pool(staged: Array) -> Array:
	var pools: Dictionary = ConfigManager.rewards.get("pools", {})
	var saved: Array = pools.get("starter_build", [])
	pools["starter_build"] = staged
	return saved


func _restore_starter_pool(saved: Array) -> void:
	var pools: Dictionary = ConfigManager.rewards.get("pools", {})
	pools["starter_build"] = saved


## offer 决议重置：cleanup 清 offer + 断连，再重连（公共 API 组合，不触私有状态）
func _rearm_flow(flow: Node) -> void:
	flow.cleanup()
	flow.connect_events()


func _make_build_managers() -> Dictionary:
	var mock_snake := Node2D.new()
	mock_snake.name = "M2MockSnake"
	var parts_mgr: Node = load("res://systems/snake_parts/snake_parts_manager.gd").new()
	parts_mgr.init_manager(mock_snake, StatusEffectManager._trigger_manager,
		StatusEffectManager._chain_resolver)
	var scale_mgr: Node = load("res://systems/snake_parts/scale_slot_manager.gd").new()
	scale_mgr.init_manager(mock_snake, StatusEffectManager._trigger_manager,
		StatusEffectManager._chain_resolver)
	return {"mock_snake": mock_snake, "parts_mgr": parts_mgr, "scale_mgr": scale_mgr}


func _cleanup_build_managers(managers: Dictionary) -> void:
	var parts_mgr: Node = managers.get("parts_mgr")
	var scale_mgr: Node = managers.get("scale_mgr")
	var mock_snake: Node = managers.get("mock_snake")
	if scale_mgr:
		scale_mgr.clear_all()
		scale_mgr.free()
	if parts_mgr:
		parts_mgr.unequip_head()
		parts_mgr.unequip_tail()
		parts_mgr.free()
	StatusEffectManager.clear_all()
	if mock_snake:
		mock_snake.free()


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


func _connect_reward_recorders() -> void:
	_reward_presented_events.clear()
	_reward_chosen_events.clear()
	_room_completed_events.clear()
	EventBus.reward_presented.connect(_on_reward_presented)
	EventBus.reward_chosen.connect(_on_reward_chosen)
	EventBus.room_completed.connect(_on_room_completed)


func _disconnect_reward_recorders() -> void:
	if EventBus.reward_presented.is_connected(_on_reward_presented):
		EventBus.reward_presented.disconnect(_on_reward_presented)
	if EventBus.reward_chosen.is_connected(_on_reward_chosen):
		EventBus.reward_chosen.disconnect(_on_reward_chosen)
	if EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.disconnect(_on_room_completed)


func _on_reward_presented(data: Dictionary) -> void:
	_reward_presented_events.append(data)


func _on_reward_chosen(data: Dictionary) -> void:
	_reward_chosen_events.append(data)


func _on_room_completed(data: Dictionary) -> void:
	_room_completed_events.append(data)


func _collect_unlocked() -> void:
	_unlocked_events.clear()
	if not EventBus.content_unlocked.is_connected(_on_content_unlocked):
		EventBus.content_unlocked.connect(_on_content_unlocked)


func _stop_collect_unlocked() -> void:
	if EventBus.content_unlocked.is_connected(_on_content_unlocked):
		EventBus.content_unlocked.disconnect(_on_content_unlocked)


func _on_content_unlocked(data: Dictionary) -> void:
	_unlocked_events.append(data)


func _remove_temp_save() -> void:
	if FileAccess.file_exists(TEMP_SAVE_PATH):
		DirAccess.remove_absolute(TEMP_SAVE_PATH)
