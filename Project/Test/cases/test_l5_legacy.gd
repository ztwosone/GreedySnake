extends RefCounted
## spec 003 M3（T012 Red 卡重写）：传承石簇。
## - T013：高光阈值 JSON 化（meta_growth.legacy_stone_thresholds，改写 ConfigManager 段反证）；
##   `legacy_stone_selected` payload 带完整 stone（{stone_index, stone}）；容量 5 + 最旧轮换；
##   run_ended 事件路径铸石；去 class_name。
## - T014：bias 消费——stone_bias 加权重排（tag 查询走 ConfigManager.get_scale_tags）经
##   ScaleRewardSystem.set_sampling_bias（S2 T005 既有钩子）+ RewardFlowSystem 同口径新钩子；
##   定种子分布偏移断言；bias 生命周期恰一局（game_world.start_game(run_options) 注入，
##   下局未带石清除，FR-015）。
## - T015：StoneSelectScreen（kit modal；←/→ + 数字 + 回车/鼠标选择 +「轻装上阵」跳过；
##   空石碑列表整屏跳过 FR-012——open() 返回 false 绝不闪现）；AppFlow（标题开始 → 有石
##   STONE_SELECT / 无石直进 RUN；GameManager.GameState.STONE_SELECT）。
## - T016：结算数据通路（get_last_run_summary 携带完整铸石，run_started 清缓存）。
## 存档卫生（不可妥协）：全部用例注入临时 save_path 并测后删除，
## 绝不触碰生产存档 user://meta_save.json、绝不依赖其先验状态。

const LEGACY_PATH: String = "res://systems/meta_growth/legacy_stone_system.gd"
const STONE_BIAS_PATH: String = "res://systems/meta_growth/stone_bias.gd"
const SCREEN_PATH: String = "res://ui/stone_select_screen.gd"
const META_ROOT_PATH: String = "res://systems/meta_growth/meta_growth_root.gd"
const SCALE_REWARD_PATH: String = "res://systems/growth/scale_reward_system.gd"
const REWARD_FLOW_PATH: String = "res://systems/rewards/reward_flow_system.gd"
const MAIN_SCENE_PATH: String = "res://scenes/main.tscn"
const GAME_WORLD_SCENE_PATH: String = "res://scenes/game_world.tscn"
const MetaSaveSystemScript := preload("res://systems/meta_growth/meta_save_system.gd")

const TEMP_SAVE_PATH: String = "user://test_l5_legacy_tmp.json"

## 完整 stone dict 的契约键集（spec Key Entities：LegacyStone）
const STONE_KEYS: Array = [
	"description", "highlight_type", "display_name", "bias_config", "created_at",
]

var _selected_events: Array = []
var _finished_stones: Array = []


func run(t) -> void:
	_remove_temp_save()
	_test_thresholds_json_schema(t)
	_test_highlight_evaluation_from_json(t)
	_test_stone_capacity_rotation(t)
	_test_selected_payload_full_stone(t)
	_test_run_ended_forges_stone(t)
	_test_no_class_name(t)
	_test_bias_helper(t)
	_test_scale_reward_bias_distribution_shift(t)
	_test_reward_flow_bias_distribution_shift(t)
	await _test_game_world_bias_lifecycle(t)
	_test_stone_select_screen_api(t)
	_test_stone_select_empty_skip(t)
	await _test_appflow_skip_when_empty(t)
	await _test_appflow_stone_select_flow(t)
	_test_summary_carries_stone(t)
	_remove_temp_save()


# === T013：高光阈值 JSON 化（meta_growth.legacy_stone_thresholds） ===

func _test_thresholds_json_schema(t) -> void:
	var thresholds: Dictionary = ConfigManager.get_legacy_stone_thresholds()
	t.assert_false(thresholds.is_empty(),
		"[L5-M3] meta_growth.legacy_stone_thresholds present in JSON")
	# 草稿魔数（30/5/2/3）入 JSON 的钉死断言（tasks T013）
	t.assert_eq(int(thresholds.get("high_kills", 0)), 30, "[L5-M3] high_kills threshold = 30")
	t.assert_eq(int(thresholds.get("complex_reaction", 0)), 5,
		"[L5-M3] complex_reaction threshold = 5")
	t.assert_eq(int(thresholds.get("near_death", 0)), 2, "[L5-M3] near_death threshold = 2")
	t.assert_eq(int(thresholds.get("long_survival", 0)), 3,
		"[L5-M3] long_survival threshold = 3")
	# 每个阈值键都有对应石碑模板（数据互证：高光类型 → 模板）
	var templates: Dictionary = ConfigManager.get_legacy_stone_templates()
	for key in thresholds.keys():
		t.assert_true(templates.has(key),
			"[L5-M3] threshold key has matching stone template: %s" % key)
	t.assert_true(templates.has("default"), "[L5-M3] default stone template present")


func _test_highlight_evaluation_from_json(t) -> void:
	_remove_temp_save()
	var meta = MetaSaveSystemScript.new(TEMP_SAVE_PATH)
	meta.reset()
	var legacy: Node = load(LEGACY_PATH).new()
	legacy.setup(meta)
	t.add_child(legacy)

	var th: Dictionary = ConfigManager.get_legacy_stone_thresholds()
	var kills_min: int = int(th.get("high_kills", 0))
	var chain_min: int = int(th.get("complex_reaction", 0))
	var near_min: int = int(th.get("near_death", 0))
	var floors_min: int = int(th.get("long_survival", 0))

	# 基线：阈值出自 JSON（达标/不达标成对）
	t.assert_eq(legacy.generate_legacy_stone({"total_kills": kills_min}).get("highlight_type", ""),
		"high_kills", "[L5-M3] kills at JSON threshold -> high_kills")
	t.assert_eq(legacy.generate_legacy_stone(
		{"max_reaction_chain": chain_min}).get("highlight_type", ""),
		"complex_reaction", "[L5-M3] chain at JSON threshold -> complex_reaction")
	t.assert_eq(legacy.generate_legacy_stone(
		{"near_death_count": near_min}).get("highlight_type", ""),
		"near_death", "[L5-M3] near-death at JSON threshold -> near_death")
	t.assert_eq(legacy.generate_legacy_stone(
		{"floors_completed": floors_min}).get("highlight_type", ""),
		"long_survival", "[L5-M3] floors at JSON threshold -> long_survival")
	var below: Dictionary = legacy.generate_legacy_stone({
		"total_kills": kills_min - 1,
		"max_reaction_chain": chain_min - 1,
		"near_death_count": near_min - 1,
		"floors_completed": floors_min - 1,
	})
	t.assert_eq(below.get("highlight_type", ""), "default",
		"[L5-M3] all-below-threshold run forges default survival stone (Edge Case)")
	t.assert_true(str(below.get("display_name", "")) != "",
		"[L5-M3] default stone carries display_name")
	# 评估优先级：high_kills 压过 complex_reaction（与草稿语义一致，现由 JSON 驱动）
	t.assert_eq(legacy.generate_legacy_stone({
		"total_kills": kills_min, "max_reaction_chain": chain_min + 5,
	}).get("highlight_type", ""), "high_kills",
		"[L5-M3] evaluation priority: high_kills wins over complex_reaction")

	# JSON 反证（改写 ConfigManager 段并还原——repo 既定数据反证模式）：
	# high_kills 阈值提到 kills_min+20 后，同样的击杀数不再触发 high_kills
	var saved_th: Dictionary = ConfigManager.meta_growth.get("legacy_stone_thresholds", {})
	var staged_th: Dictionary = saved_th.duplicate(true)
	staged_th["high_kills"] = kills_min + 20
	ConfigManager.meta_growth["legacy_stone_thresholds"] = staged_th
	t.assert_eq(legacy.generate_legacy_stone(
		{"total_kills": kills_min + 5}).get("highlight_type", ""),
		"default", "[L5-M3] threshold rewrite via ConfigManager changes evaluation (JSON-driven)")
	t.assert_eq(legacy.generate_legacy_stone(
		{"total_kills": kills_min + 20}).get("highlight_type", ""),
		"high_kills", "[L5-M3] rewritten threshold still reachable")
	ConfigManager.meta_growth["legacy_stone_thresholds"] = saved_th

	legacy.cleanup()
	legacy.queue_free()
	_remove_temp_save()


# === US2 场景 3：容量 5 + 最旧轮换 ===

func _test_stone_capacity_rotation(t) -> void:
	_remove_temp_save()
	t.assert_eq(ConfigManager.get_max_legacy_stones(), 5, "[L5-M3] max_legacy_stones = 5 (JSON)")
	var meta = MetaSaveSystemScript.new(TEMP_SAVE_PATH)
	meta.reset()
	var legacy: Node = load(LEGACY_PATH).new()
	legacy.setup(meta)
	t.add_child(legacy)

	for i in range(7):
		meta.add_legacy_stone({"display_name": "stone_%d" % i, "created_at": i})
	var stones: Array = legacy.get_available_stones()
	t.assert_eq(stones.size(), 5, "[L5-M3] stones capped at 5")
	t.assert_eq(stones[0].get("display_name", ""), "stone_2",
		"[L5-M3] oldest stones rotated out first")
	t.assert_eq(stones[4].get("display_name", ""), "stone_6", "[L5-M3] newest stone kept")

	legacy.cleanup()
	legacy.queue_free()
	_remove_temp_save()


# === T013：legacy_stone_selected 完整 stone payload + 消耗落盘 ===

func _test_selected_payload_full_stone(t) -> void:
	_remove_temp_save()
	var meta = MetaSaveSystemScript.new(TEMP_SAVE_PATH)
	meta.reset()
	var legacy: Node = load(LEGACY_PATH).new()
	legacy.setup(meta)
	t.add_child(legacy)

	legacy.generate_legacy_stone({"total_kills": 99})
	legacy.generate_legacy_stone({"near_death_count": 99})
	t.assert_eq(legacy.get_available_stones().size(), 2, "[L5-M3] two stones forged")

	_collect_selected()
	var selected: Dictionary = legacy.select_legacy_stone(1)
	t.assert_eq(selected.get("highlight_type", ""), "near_death",
		"[L5-M3] select returns the chosen stone")
	t.assert_eq(_selected_events.size(), 1, "[L5-M3] legacy_stone_selected emitted once")
	if _selected_events.size() >= 1:
		var payload: Dictionary = _selected_events[0]
		t.assert_eq(int(payload.get("stone_index", -1)), 1,
			"[L5-M3] selected payload keeps stone_index")
		var stone: Dictionary = payload.get("stone", {})
		t.assert_false(stone.is_empty(), "[L5-M3] selected payload carries FULL stone dict")
		for key in STONE_KEYS:
			t.assert_true(stone.has(key),
				"[L5-M3] selected stone payload has contract key: %s" % key)
		t.assert_eq(stone.get("highlight_type", ""), "near_death",
			"[L5-M3] payload stone matches the consumed stone")

	# 消耗：内存移除 + 落盘（同路径新实例读回恰 1 块）
	t.assert_eq(legacy.get_available_stones().size(), 1, "[L5-M3] stone consumed on selection")
	var reloaded = MetaSaveSystemScript.new(TEMP_SAVE_PATH)
	t.assert_true(reloaded.load_from_disk(), "[L5-M3] consumption persisted to disk")
	t.assert_eq(reloaded.get_legacy_stones().size(), 1,
		"[L5-M3] disk reflects consumed stone")

	# 越界选择：零副作用零事件
	_selected_events.clear()
	t.assert_true(legacy.select_legacy_stone(9).is_empty(),
		"[L5-M3] out-of-range selection returns empty")
	t.assert_eq(_selected_events.size(), 0, "[L5-M3] out-of-range selection emits nothing")

	_stop_collect_selected()
	legacy.cleanup()
	legacy.queue_free()
	_remove_temp_save()


# === run_ended 事件路径铸石（SC-003） ===

func _test_run_ended_forges_stone(t) -> void:
	_remove_temp_save()
	var meta = MetaSaveSystemScript.new(TEMP_SAVE_PATH)
	meta.reset()
	var legacy: Node = load(LEGACY_PATH).new()
	legacy.setup(meta)
	t.add_child(legacy)

	EventBus.run_ended.emit({
		"outcome": "death",
		"run_id": "m3_event_path",
		"floor_index": 1,
		"stats": {"near_death_count": 99},
	})
	var stones: Array = legacy.get_available_stones()
	t.assert_eq(stones.size(), 1, "[L5-M3] run_ended event path forges exactly one stone")
	if stones.size() >= 1:
		t.assert_eq(stones[0].get("highlight_type", ""), "near_death",
			"[L5-M3] event-path stone evaluated from run stats")

	legacy.cleanup()
	legacy.queue_free()
	_remove_temp_save()


# === 去 class_name（ScriptingLeading C.8） ===

func _test_no_class_name(t) -> void:
	for path in [LEGACY_PATH, STONE_BIAS_PATH, SCREEN_PATH]:
		t.assert_file_exists(path)
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var text: String = file.get_as_text()
		file.close()
		t.assert_false(text.begins_with("class_name") or text.contains("\nclass_name"),
			"[L5-M3] no class_name in %s (C.8)" % path)


# === T014：stone_bias 加权重排（tag 查询走 ConfigManager scale tags） ===

func _test_bias_helper(t) -> void:
	t.assert_file_exists(STONE_BIAS_PATH)
	if not FileAccess.file_exists(STONE_BIAS_PATH):
		return
	var BiasScript: GDScript = load(STONE_BIAS_PATH)

	# 权重语义：scale 选项按 target_id 查 ConfigManager.get_scale_tags，匹配乘数连乘；
	# 非 scale 选项（head/tail）恒 1.0（v1 仅鳞片池受 bias，Designs §12.4）
	t.assert_eq(BiasScript.option_weight(_scale_option("flame_scale", "middle"),
		{"fire": 2.0}), 2.0, "[L5-M3] fire scale weighted by fire multiplier")
	t.assert_eq(BiasScript.option_weight(_scale_option("predator_scale", "front"),
		{"fire": 2.0, "ice": 2.0}), 4.0, "[L5-M3] multi-tag scale multiplies matching weights")
	t.assert_eq(BiasScript.option_weight(_scale_option("thorn_scale", "back"),
		{"fire": 2.0}), 1.0, "[L5-M3] unmatched tags keep weight 1.0")
	t.assert_eq(BiasScript.option_weight(
		{"reward_type": "head", "target_id": "hydra"}, {"fire": 9.0}),
		1.0, "[L5-M3] non-scale options unaffected by scale_tag_weights")

	# 重排是置换：同元素集、同尺寸
	var options: Array = _bias_pool_options()
	var bias: Callable = BiasScript.make_bias({"fire": 3.0}, 4242)
	var reordered: Variant = bias.call(options)
	t.assert_true(reordered is Array, "[L5-M3] bias returns an Array")
	if reordered is Array:
		t.assert_eq(reordered.size(), options.size(), "[L5-M3] bias keeps option count")
		var in_ids: Array = _option_target_ids(options)
		var out_ids: Array = _option_target_ids(reordered)
		in_ids.sort()
		out_ids.sort()
		t.assert_eq(out_ids, in_ids, "[L5-M3] bias output is a permutation of input")

	# 同种子确定性：同 weights + 同 seed → 全等输出
	var replay: Variant = BiasScript.make_bias({"fire": 3.0}, 4242).call(options)
	t.assert_eq(var_to_str(replay), var_to_str(reordered),
		"[L5-M3] same seed reproduces identical reorder")

	# 分布偏移（定种子多试次计数，全程确定性）：fire 权重把 flame_scale 推上首位的频率
	var uniform_first: int = 0
	var biased_first: int = 0
	for i in range(30):
		var uniform_out: Array = BiasScript.make_bias({}, 5000 + i).call(options)
		if str(uniform_out[0].get("target_id", "")) == "flame_scale":
			uniform_first += 1
		var biased_out: Array = BiasScript.make_bias({"fire": 4.0}, 5000 + i).call(options)
		if str(biased_out[0].get("target_id", "")) == "flame_scale":
			biased_first += 1
	t.assert_true(biased_first > uniform_first,
		"[L5-M3] fire bias shifts first-pick distribution (biased %d > uniform %d)"
		% [biased_first, uniform_first])


## ScaleRewardSystem：bias 注入后定种子抽样分布偏移（S2 T005 钩子零改造接入）
func _test_scale_reward_bias_distribution_shift(t) -> void:
	if not FileAccess.file_exists(STONE_BIAS_PATH):
		return
	var BiasScript: GDScript = load(STONE_BIAS_PATH)
	var managers: Dictionary = _make_build_managers()
	var system: Node = load(SCALE_REWARD_PATH).new()
	system.setup(managers.get("scale_mgr"))
	t.add_child(system)

	var pools: Dictionary = ConfigManager.growth.get("scale_reward", {}).get("pools", {})
	pools["m3_bias_pool"] = _bias_pool_options()

	var trials: int = 12
	var unbiased_hits: int = 0
	var biased_hits: int = 0
	for i in range(trials):
		# 无 bias：全局定种子（shuffle 流）下的基线命中
		seed(9000 + i)
		system.set_sampling_bias(Callable())
		var offer: Dictionary = system.present_offer(
			{"room_id": "m3_unbiased_%d" % i}, "m3_bias_pool")
		if _option_target_ids(offer.get("options", [])).has("flame_scale"):
			unbiased_hits += 1
		system.discard_offer()

		# 同 shuffle 流 + fire 重权 bias：命中应显著上移
		seed(9000 + i)
		system.set_sampling_bias(BiasScript.make_bias({"fire": 50.0}, 7000 + i))
		offer = system.present_offer({"room_id": "m3_biased_%d" % i}, "m3_bias_pool")
		var ids: Array = _option_target_ids(offer.get("options", []))
		t.assert_eq(ids.size(), 3, "[L5-M3] biased offer keeps offer_count options")
		if ids.has("flame_scale"):
			biased_hits += 1
		system.discard_offer()

	t.assert_true(biased_hits > unbiased_hits,
		"[L5-M3] fire-stone bias shifts scale offer distribution (biased %d > unbiased %d)"
		% [biased_hits, unbiased_hits])

	pools.erase("m3_bias_pool")
	system.cleanup()
	system.queue_free()
	_cleanup_build_managers(managers)


## RewardFlowSystem：同口径 bias 钩子（未注入保持 L3 first-N 确定性行为）
func _test_reward_flow_bias_distribution_shift(t) -> void:
	if not FileAccess.file_exists(STONE_BIAS_PATH):
		return
	var BiasScript: GDScript = load(STONE_BIAS_PATH)
	var managers: Dictionary = _make_build_managers()
	var flow: Node = load(REWARD_FLOW_PATH).new()
	flow.setup(managers.get("parts_mgr"), managers.get("scale_mgr"))
	t.add_child(flow)
	t.assert_true(flow.has_method("set_sampling_bias"),
		"[L5-M3] RewardFlowSystem exposes set_sampling_bias seam (T014)")
	if not flow.has_method("set_sampling_bias"):
		flow.cleanup()
		flow.queue_free()
		_cleanup_build_managers(managers)
		return

	# 布景池：fire 鳞排在池尾——未注入时 first-N 永远取不到它（L3 行为保持）
	var staged: Array = [
		_head_pool_option("hydra", "九头蛇"),
		_scale_option("toxin_scale", "middle"),
		_scale_option("frost_scale", "middle"),
		_scale_option("regen_scale", "back"),
		_scale_option("flame_scale", "middle"),
	]
	var saved_pool: Array = _stage_starter_pool(staged)

	var offer: Dictionary = flow.present_offer({"room_id": "m3_flow_base", "room_type": "reward"})
	t.assert_eq(_option_target_ids(offer.get("options", [])),
		["hydra", "toxin_scale", "frost_scale"],
		"[L5-M3] uninjected flow keeps deterministic first-N pool order (L3 contract)")
	_rearm_flow(flow)

	var trials: int = 8
	var flame_hits: int = 0
	for i in range(trials):
		flow.set_sampling_bias(BiasScript.make_bias({"fire": 50.0}, 7100 + i))
		offer = flow.present_offer({"room_id": "m3_flow_bias_%d" % i, "room_type": "reward"})
		if _option_target_ids(offer.get("options", [])).has("flame_scale"):
			flame_hits += 1
		_rearm_flow(flow)
	t.assert_true(flame_hits > trials / 2,
		"[L5-M3] fire-stone bias surfaces tail-of-pool fire scale into offers (%d/%d)"
		% [flame_hits, trials])

	# 清除 bias 回退 first-N（生命周期消费端）
	flow.set_sampling_bias(Callable())
	offer = flow.present_offer({"room_id": "m3_flow_clear", "room_type": "reward"})
	t.assert_eq(_option_target_ids(offer.get("options", [])),
		["hydra", "toxin_scale", "frost_scale"],
		"[L5-M3] cleared bias restores deterministic first-N order")
	_rearm_flow(flow)

	_restore_starter_pool(saved_pool)
	flow.cleanup()
	flow.queue_free()
	_cleanup_build_managers(managers)


## bias 生命周期 = 恰一局（FR-015）：start_game(run_options) 注入，下局未带石清除
func _test_game_world_bias_lifecycle(t) -> void:
	var saved: Dictionary = _save_game_manager()
	var world: Node = (load(GAME_WORLD_SCENE_PATH) as PackedScene).instantiate()
	t.add_child(world)

	var stone: Dictionary = {
		"description": "测试石",
		"highlight_type": "high_kills",
		"display_name": "杀戮传承",
		"bias_config": {"scale_tag_weights": {"fire": 1.3}},
		"created_at": 0,
	}
	world.start_game({"legacy_stone": stone})
	t.assert_true(world.scale_reward_system.has_sampling_bias(),
		"[L5-M3] selected stone injects scale sampling bias at run start")
	t.assert_true(world.reward_flow_system.has_sampling_bias(),
		"[L5-M3] selected stone injects reward sampling bias at run start")

	# 第二局未带石：bias 必须清除（FR-015：恰一局有效）
	world.start_game({})
	t.assert_false(world.scale_reward_system.has_sampling_bias(),
		"[L5-M3] stone bias cleared on next run without a stone (scale)")
	t.assert_false(world.reward_flow_system.has_sampling_bias(),
		"[L5-M3] stone bias cleared on next run without a stone (reward flow)")

	world.cleanup()
	world.queue_free()
	_restore_game_manager(saved)
	TickManager.stop_ticking()
	GridWorld.clear_all()
	await t.get_tree().process_frame
	await t.get_tree().process_frame


# === T015：StoneSelectScreen（kit modal，公共 API + 键盘驱动） ===

func _test_stone_select_screen_api(t) -> void:
	t.assert_file_exists(SCREEN_PATH)
	if not FileAccess.file_exists(SCREEN_PATH):
		return
	_remove_temp_save()
	var meta = MetaSaveSystemScript.new(TEMP_SAVE_PATH)
	meta.reset()
	var legacy: Node = load(LEGACY_PATH).new()
	legacy.setup(meta)
	t.add_child(legacy)
	legacy.generate_legacy_stone({"total_kills": 99})
	legacy.generate_legacy_stone({"near_death_count": 99})

	var screen: Control = load(SCREEN_PATH).new()
	screen.name = "M3StoneSelectScreen"
	t.add_child(screen)
	screen.setup(legacy)

	# kit 出生即带：分组 / ui_layer 元数据（几何探测进组自动覆盖）
	t.assert_true(screen.is_in_group("ui_kit"), "[L5-M3] screen born in ui_kit group")
	t.assert_true(screen.is_in_group("ui_modal"), "[L5-M3] screen born in ui_modal group")
	t.assert_eq(screen.get_ui_layer(), "modal", "[L5-M3] screen carries ui_layer=modal meta")
	t.assert_false(screen.visible, "[L5-M3] screen hidden before open()")

	t.assert_true(screen.open(), "[L5-M3] open() succeeds with stones available")
	t.assert_true(screen.visible, "[L5-M3] screen visible after open()")
	t.assert_eq(screen.get_visible_stone_count(), 2, "[L5-M3] both stones rendered as cards")
	var labels: Array = screen.get_stone_labels()
	var templates: Dictionary = ConfigManager.get_legacy_stone_templates()
	t.assert_true(labels.has(templates.get("high_kills", {}).get("display_name", "?")),
		"[L5-M3] stone card shows template display_name (high_kills)")
	t.assert_true(labels.has(templates.get("near_death", {}).get("display_name", "?")),
		"[L5-M3] stone card shows template display_name (near_death)")
	t.assert_true(screen.get_skip_label_text().contains("轻装上阵"),
		"[L5-M3] skip entry labelled 轻装上阵 (presentation §7)")

	# 方向键移动高亮（环绕）
	t.assert_eq(screen.get_selected_index(), 0, "[L5-M3] selection starts at first stone")
	_push_key(screen, KEY_RIGHT)
	t.assert_eq(screen.get_selected_index(), 1, "[L5-M3] RIGHT moves selection")
	_push_key(screen, KEY_RIGHT)
	t.assert_eq(screen.get_selected_index(), 0, "[L5-M3] selection wraps around")
	_push_key(screen, KEY_LEFT)
	t.assert_eq(screen.get_selected_index(), 1, "[L5-M3] LEFT moves selection backwards")

	# 回车确认当前高亮（index 1 = near_death 石）；消耗 + 完整 payload + 关屏
	_collect_selected()
	_finished_stones.clear()
	screen.stone_select_finished.connect(_on_stone_select_finished)
	_push_key(screen, KEY_ENTER)
	t.assert_eq(_finished_stones.size(), 1, "[L5-M3] ENTER confirms highlighted stone")
	if _finished_stones.size() >= 1:
		t.assert_eq(_finished_stones[0].get("highlight_type", ""), "near_death",
			"[L5-M3] finished signal carries the chosen stone")
	t.assert_eq(_selected_events.size(), 1,
		"[L5-M3] screen drives legacy_stone_selected exactly once")
	if _selected_events.size() >= 1:
		t.assert_eq(_selected_events[0].get("stone", {}).get("highlight_type", ""),
			"near_death", "[L5-M3] selected event payload carries full stone dict")
	t.assert_false(screen.visible, "[L5-M3] screen closes after choosing")
	t.assert_eq(legacy.get_available_stones().size(), 1,
		"[L5-M3] chosen stone consumed from save")

	# 数字键直选（剩 1 块石：按 1 选 index 0）
	t.assert_true(screen.open(), "[L5-M3] reopen with remaining stone")
	_push_key(screen, KEY_1)
	t.assert_eq(_finished_stones.size(), 2, "[L5-M3] number key picks stone directly")
	if _finished_stones.size() >= 2:
		t.assert_eq(_finished_stones[1].get("highlight_type", ""), "high_kills",
			"[L5-M3] number key chose the remaining stone")
	t.assert_eq(legacy.get_available_stones().size(), 0, "[L5-M3] save emptied by selections")

	# 轻装上阵（空石走不到这——重新铸一块再跳过）：石不消耗、finished 带空 dict
	legacy.generate_legacy_stone({"total_kills": 99})
	t.assert_true(screen.open(), "[L5-M3] reopen for skip path")
	_selected_events.clear()
	t.assert_true(screen.skip(), "[L5-M3] skip() succeeds while open")
	t.assert_eq(_finished_stones.size(), 3, "[L5-M3] skip emits finished")
	if _finished_stones.size() >= 3:
		t.assert_true(_finished_stones[2].is_empty(),
			"[L5-M3] skip finishes with empty stone (轻装上阵)")
	t.assert_eq(_selected_events.size(), 0, "[L5-M3] skip emits no legacy_stone_selected")
	t.assert_eq(legacy.get_available_stones().size(), 1, "[L5-M3] skip keeps stones in save")
	t.assert_false(screen.visible, "[L5-M3] screen closes after skip")

	# Esc = 跳过
	t.assert_true(screen.open(), "[L5-M3] reopen for ESC path")
	_push_key(screen, KEY_ESCAPE)
	t.assert_eq(_finished_stones.size(), 4, "[L5-M3] ESC skips")
	if _finished_stones.size() >= 4:
		t.assert_true(_finished_stones[3].is_empty(), "[L5-M3] ESC finishes with empty stone")

	screen.stone_select_finished.disconnect(_on_stone_select_finished)
	_stop_collect_selected()
	screen.queue_free()
	legacy.cleanup()
	legacy.queue_free()
	_remove_temp_save()


## FR-012：空石碑列表整屏跳过——open() 返回 false 且绝不闪现
func _test_stone_select_empty_skip(t) -> void:
	if not FileAccess.file_exists(SCREEN_PATH):
		return
	_remove_temp_save()
	var meta = MetaSaveSystemScript.new(TEMP_SAVE_PATH)
	meta.reset()
	var legacy: Node = load(LEGACY_PATH).new()
	legacy.setup(meta)
	t.add_child(legacy)

	var screen: Control = load(SCREEN_PATH).new()
	t.add_child(screen)
	screen.setup(legacy)
	t.assert_false(screen.open(), "[L5-M3] open() returns false on empty stone list (FR-012)")
	t.assert_false(screen.visible, "[L5-M3] empty list never flashes the screen")

	screen.queue_free()
	legacy.cleanup()
	legacy.queue_free()
	_remove_temp_save()


# === T015 AppFlow：标题开始 → 无石直进 RUN / 有石 STONE_SELECT ===

func _test_appflow_skip_when_empty(t) -> void:
	var saved: Dictionary = _save_game_manager()
	_remove_temp_save()

	t.assert_true("STONE_SELECT" in GameManager.GameState,
		"[L5-M3] GameManager.GameState gains STONE_SELECT")

	var app: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	t.add_child(app)
	var root: Node = app.get_node("MetaGrowthRoot")
	root.boot(TEMP_SAVE_PATH)  # 存档卫生：壳层入树 + 可能触发 run_ended 的流程必先换临时档

	app.get_node("UILayer/TitleScreen").start_pressed.emit()
	var screen: Node = app.get_node_or_null("UILayer/StoneSelectScreen")
	t.assert_true(screen != null, "[L5-M3] StoneSelectScreen resident in main.tscn UILayer")
	if screen != null:
		t.assert_false(screen.visible,
			"[L5-M3] empty save: stone select skipped entirely (FR-012)")
	t.assert_eq(GameManager.current_state, GameManager.GameState.PLAYING,
		"[L5-M3] empty save: start goes straight to RUN")
	t.assert_eq(app.get_node("GameWorldContainer").get_child_count(), 1,
		"[L5-M3] empty save: game world started immediately")

	_teardown_app(app)
	_restore_game_manager(saved)
	_remove_temp_save()
	await t.get_tree().process_frame
	await t.get_tree().process_frame


func _test_appflow_stone_select_flow(t) -> void:
	var saved: Dictionary = _save_game_manager()
	_remove_temp_save()

	# 布景：临时档先写入 2 块石（玩家上两局的遗愿）
	var stager_meta = MetaSaveSystemScript.new(TEMP_SAVE_PATH)
	stager_meta.reset()
	stager_meta.add_legacy_stone({
		"description": "上一局大杀四方",
		"highlight_type": "high_kills",
		"display_name": "杀戮传承",
		"bias_config": {"scale_tag_weights": {"fire": 1.3}},
		"created_at": 1,
	})
	stager_meta.add_legacy_stone({
		"description": "稳健存活到了最后",
		"highlight_type": "long_survival",
		"display_name": "生存传承",
		"bias_config": {"scale_tag_weights": {"recovery": 1.5}},
		"created_at": 2,
	})
	stager_meta.save_to_disk()

	var app: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	t.add_child(app)
	var root: Node = app.get_node("MetaGrowthRoot")
	root.boot(TEMP_SAVE_PATH)

	_collect_selected()
	app.get_node("UILayer/TitleScreen").start_pressed.emit()
	var screen: Control = app.get_node("UILayer/StoneSelectScreen")
	t.assert_true(screen.visible, "[L5-M3] stones exist: STONE_SELECT screen shown")
	t.assert_eq(GameManager.current_state, GameManager.GameState.STONE_SELECT,
		"[L5-M3] app flow enters STONE_SELECT state")
	t.assert_eq(app.get_node("GameWorldContainer").get_child_count(), 0,
		"[L5-M3] run does not start while stone select pending")
	t.assert_eq(screen.get_visible_stone_count(), 2, "[L5-M3] both staged stones offered")

	# 选石 → 消耗 + 注入新局（bias 双系统生效）+ 进 RUN
	t.assert_true(screen.choose_stone_by_index(0), "[L5-M3] choose stone via public API")
	t.assert_eq(GameManager.current_state, GameManager.GameState.PLAYING,
		"[L5-M3] choosing a stone starts the run")
	t.assert_eq(app.get_node("GameWorldContainer").get_child_count(), 1,
		"[L5-M3] game world started after stone choice")
	var world: Node = app.get_node("GameWorldContainer").get_child(0)
	t.assert_true(world.scale_reward_system.has_sampling_bias(),
		"[L5-M3] chosen stone bias wired into the new run (scale)")
	t.assert_true(world.reward_flow_system.has_sampling_bias(),
		"[L5-M3] chosen stone bias wired into the new run (reward flow)")
	t.assert_eq(root.get_meta_save().get_legacy_stones().size(), 1,
		"[L5-M3] chosen stone consumed from meta save")
	t.assert_eq(_selected_events.size(), 1, "[L5-M3] app flow emits legacy_stone_selected once")
	if _selected_events.size() >= 1:
		t.assert_eq(_selected_events[0].get("stone", {}).get("display_name", ""),
			"杀戮传承", "[L5-M3] app-flow selected payload carries full stone")

	_stop_collect_selected()
	_teardown_app(app)
	_restore_game_manager(saved)
	_remove_temp_save()
	await t.get_tree().process_frame
	await t.get_tree().process_frame


# === T016：结算数据通路（summary 携带完整铸石，run_started 清缓存） ===

func _test_summary_carries_stone(t) -> void:
	var saved: Dictionary = _save_game_manager()
	_remove_temp_save()

	var root: Node = load(META_ROOT_PATH).new()
	root.boot(TEMP_SAVE_PATH)
	t.add_child(root)

	EventBus.run_started.emit({"run_id": "m3_summary_run", "floor_index": 1, "seed": 31})
	for _i in range(30):
		EventBus.enemy_killed.emit(
			{"enemy_def": null, "position": Vector2i.ZERO, "method": "head_bite"})
	root.get_stats_tracker().finalize_run("death")

	var summary: Dictionary = root.get_last_run_summary()
	t.assert_eq(int(summary.get("stats", {}).get("total_kills", -1)), 30,
		"[L5-M3] summary stats carry kill count")
	var stone: Dictionary = summary.get("stone", {})
	t.assert_eq(stone.get("highlight_type", ""), "high_kills",
		"[L5-M3] summary stone evaluated from this run's stats")
	for key in STONE_KEYS:
		t.assert_true(stone.has(key), "[L5-M3] summary stone has contract key: %s" % key)

	# 下个 run_started 清缓存（呈现编排 S4 接手前的数据正确性）
	EventBus.run_started.emit({"run_id": "m3_summary_run2", "floor_index": 1, "seed": 32})
	t.assert_true(root.get_last_run_summary().is_empty(),
		"[L5-M3] summary cache cleared on next run_started")

	root.cleanup()
	root.queue_free()
	_restore_game_manager(saved)
	_remove_temp_save()


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


func _head_pool_option(target_id: String, display: String) -> Dictionary:
	return {
		"option_id": "head_%s" % target_id,
		"display_name": display,
		"reward_type": "head",
		"target_id": target_id,
		"target_slot": "head",
		"level_delta": 0,
	}


## bias 测试池：恰 1 个 fire 鳞 + 5 个非 fire 鳞（全部真实配置，槽位均可承载）
func _bias_pool_options() -> Array:
	return [
		_scale_option("toxin_scale", "middle"),
		_scale_option("frost_scale", "middle"),
		_scale_option("phantom_scale", "middle"),
		_scale_option("regen_scale", "back"),
		_scale_option("thorn_scale", "back"),
		_scale_option("flame_scale", "middle"),
	]


func _option_target_ids(options: Array) -> Array:
	var ids: Array = []
	for option in options:
		if option is Dictionary:
			ids.append(str(option.get("target_id", "")))
	return ids


func _push_key(target: Control, keycode: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.pressed = true
	target.get_viewport().push_input(key)


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
	mock_snake.name = "M3MockSnake"
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


## 壳层 app 收尾：先 cleanup 局内世界（停 tick/清网格），再整壳释放
func _teardown_app(app: Node) -> void:
	var container: Node = app.get_node_or_null("GameWorldContainer")
	if container != null:
		for child in container.get_children():
			if child.has_method("cleanup"):
				child.cleanup()
	app.queue_free()
	TickManager.stop_ticking()
	GridWorld.clear_all()


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


func _collect_selected() -> void:
	_selected_events.clear()
	if not EventBus.legacy_stone_selected.is_connected(_on_stone_selected):
		EventBus.legacy_stone_selected.connect(_on_stone_selected)


func _stop_collect_selected() -> void:
	if EventBus.legacy_stone_selected.is_connected(_on_stone_selected):
		EventBus.legacy_stone_selected.disconnect(_on_stone_selected)


func _on_stone_selected(data: Dictionary) -> void:
	_selected_events.append(data)


func _on_stone_select_finished(stone: Dictionary) -> void:
	_finished_stones.append(stone)


func _remove_temp_save() -> void:
	if FileAccess.file_exists(TEMP_SAVE_PATH):
		DirAccess.remove_absolute(TEMP_SAVE_PATH)
