extends RefCounted
## L4 T1 簇：配置与契约基线（spec 002 修订版 2026-06-11）。
## T001 数据断言（FR-016/FR-017/SC-009/SC-010）+ T002 accessor 断言 + T003 EventBus 契约断言。
## 只读 JSON/ConfigManager/EventBus，不依赖任何 L4 系统实现。

const CONFIG_JSON_PATH: String = "res://data/json/game_config.json"
const V1_MODIFIER_IDS: Array = ["shield_enemies", "preset_status_tiles"]
const ELITE_BASE_TYPES: Array = ["wanderer", "chaser", "bog_crawler"]


func run(t) -> void:
	_test_run_max_floors(t)
	_test_no_max_floors_v1_residue(t)
	_test_floor_generator_switch(t)
	_test_pacing_modifier_weights(t)
	_test_pacing_elite_weights(t)
	_test_shop_guarantee(t)
	_test_shop_price_multiplier(t)
	_test_room_types_shop_and_elite(t)
	_test_elite_enemy_types(t)
	_test_difficulty_static_floor_table(t)
	_test_difficulty_reactive_params(t)
	_test_room_modifier_v1_configs(t)
	_test_l4_event_contracts(t)


func _test_run_max_floors(t) -> void:
	## FR-016: run.max_floors 取代 max_floors_v1
	var run_cfg: Dictionary = ConfigManager.get_run_config()
	t.assert_true(run_cfg.has("max_floors"), "[FR-016] run.max_floors exists")
	t.assert_eq(int(run_cfg.get("max_floors", 0)), 3, "[FR-016] run.max_floors == 3")
	t.assert_false(run_cfg.has("max_floors_v1"), "[FR-016] run.max_floors_v1 removed from run section")
	t.assert_true(ConfigManager.has_method("get_max_floors"), "[FR-016] get_max_floors accessor exists")
	if ConfigManager.has_method("get_max_floors"):
		t.assert_eq(ConfigManager.get_max_floors(), 3, "[FR-016] get_max_floors() == 3")


func _test_no_max_floors_v1_residue(t) -> void:
	## SC-009: max_floors_v1 不得在配置中残留
	var file := FileAccess.open(CONFIG_JSON_PATH, FileAccess.READ)
	t.assert_true(file != null, "[SC-009] game_config.json readable")
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()
	t.assert_false(text.contains("max_floors_v1"), "[SC-009] no max_floors_v1 residue anywhere in game_config.json")


func _test_floor_generator_switch(t) -> void:
	## FR-016: floor.generator 枚举 fixed_v1 | pcg
	var floor_cfg: Dictionary = ConfigManager.get_floor_config()
	var generator: String = str(floor_cfg.get("generator", ""))
	t.assert_true(generator == "fixed_v1" or generator == "pcg", "[FR-016] floor.generator is valid enum (fixed_v1|pcg)")
	t.assert_eq(generator, "fixed_v1", "[FR-016] v1 default generator is fixed_v1 (MDE fallback path)")
	t.assert_true(ConfigManager.has_method("get_floor_generator"), "[FR-016] get_floor_generator accessor exists")
	if ConfigManager.has_method("get_floor_generator"):
		t.assert_eq(ConfigManager.get_floor_generator(), generator, "[FR-016] get_floor_generator() matches JSON")


func _test_pacing_modifier_weights(t) -> void:
	## FR-017/SC-010: 首层修饰权重全 0，2 层起出现正权重（概念节奏纯数据验证）
	var floor_cfg: Dictionary = ConfigManager.get_floor_config()
	var weights: Dictionary = floor_cfg.get("modifier_weights", {})
	t.assert_true(weights.has("1"), "[FR-017] floor 1 modifier weights defined")

	var floor1: Dictionary = weights.get("1", {})
	for modifier_id in V1_MODIFIER_IDS:
		t.assert_true(floor1.has(modifier_id), "[FR-017] floor 1 weights cover v1 modifier: %s" % modifier_id)
	var all_zero: bool = true
	for modifier_id in floor1:
		if float(floor1[modifier_id]) != 0.0:
			all_zero = false
	t.assert_true(all_zero, "[FR-017] floor 1 modifier weights are all 0")

	var has_later_positive: bool = false
	for floor_key in weights:
		if int(str(floor_key)) >= 2:
			var floor_weights: Dictionary = weights[floor_key]
			for modifier_id in floor_weights:
				if float(floor_weights[modifier_id]) > 0.0:
					has_later_positive = true
	t.assert_true(has_later_positive, "[FR-017] some floor >= 2 has positive modifier weight (首修饰自 2 层起)")

	t.assert_true(ConfigManager.has_method("get_floor_modifier_weights"), "[FR-017] get_floor_modifier_weights accessor exists")
	if ConfigManager.has_method("get_floor_modifier_weights"):
		t.assert_eq(ConfigManager.get_floor_modifier_weights(1), floor1, "[FR-017] accessor returns floor 1 weights")
		var highest: Dictionary = weights.get(_highest_floor_key(weights), {})
		t.assert_eq(ConfigManager.get_floor_modifier_weights(99), highest, "[FR-017] accessor clamps beyond-table floors to highest defined floor")


func _test_pacing_elite_weights(t) -> void:
	## FR-017/SC-010: 首层精英权重 0，逐层严格递增（首精英自 2 层起）
	var floor_cfg: Dictionary = ConfigManager.get_floor_config()
	var weights: Dictionary = floor_cfg.get("elite_weights", {})
	t.assert_true(weights.has("1"), "[FR-017] floor 1 elite weight defined")
	t.assert_eq(float(weights.get("1", -1.0)), 0.0, "[FR-017] floor 1 elite weight == 0")
	t.assert_true(float(weights.get("2", 0.0)) > 0.0, "[FR-017] floor 2 elite weight > 0")

	var floor_keys: Array = []
	for floor_key in weights:
		floor_keys.append(int(str(floor_key)))
	floor_keys.sort()
	var strictly_increasing: bool = floor_keys.size() >= 2
	for index in range(1, floor_keys.size()):
		var prev: float = float(weights.get(str(floor_keys[index - 1]), 0.0))
		var curr: float = float(weights.get(str(floor_keys[index]), 0.0))
		if curr <= prev:
			strictly_increasing = false
	t.assert_true(strictly_increasing, "[FR-017] elite weights strictly increase per floor")

	t.assert_true(ConfigManager.has_method("get_floor_elite_weight"), "[FR-017] get_floor_elite_weight accessor exists")
	if ConfigManager.has_method("get_floor_elite_weight"):
		t.assert_eq(ConfigManager.get_floor_elite_weight(1), 0, "[FR-017] get_floor_elite_weight(1) == 0")
		t.assert_true(ConfigManager.get_floor_elite_weight(2) > 0, "[FR-017] get_floor_elite_weight(2) > 0")
		var highest_weight: int = int(weights.get(_highest_floor_key(weights), 0))
		t.assert_eq(ConfigManager.get_floor_elite_weight(99), highest_weight, "[FR-017] elite weight clamps beyond-table floors to highest defined floor")


func _test_shop_guarantee(t) -> void:
	## FR-017/SC-010: 每层保底商店，排在 >=2 战斗房之后
	var floor_cfg: Dictionary = ConfigManager.get_floor_config()
	var guarantee: Dictionary = floor_cfg.get("shop_guarantee", {})
	t.assert_true(guarantee.get("enabled", false), "[FR-017] shop guarantee enabled")
	t.assert_true(int(guarantee.get("min_combat_rooms_before", 0)) >= 2, "[FR-017] guaranteed shop placed after >= 2 combat rooms")
	t.assert_true(ConfigManager.has_method("get_shop_guarantee"), "[FR-017] get_shop_guarantee accessor exists")
	if ConfigManager.has_method("get_shop_guarantee"):
		t.assert_eq(ConfigManager.get_shop_guarantee(), guarantee, "[FR-017] get_shop_guarantee() matches JSON")


func _test_shop_price_multiplier(t) -> void:
	## FR-003: 蜕皮跨层保留，后层压力阀 = 物价乘数（单一配置旋钮）
	var shop_cfg: Dictionary = ConfigManager.get_shop_config()
	t.assert_true(shop_cfg.has("price_multiplier_per_floor"), "[FR-003] shop.price_multiplier_per_floor exists")
	t.assert_true(float(shop_cfg.get("price_multiplier_per_floor", 0.0)) > 1.0, "[FR-003] price multiplier > 1.0 (下层物价上涨)")
	t.assert_true(ConfigManager.has_method("get_shop_price_multiplier_per_floor"), "[FR-003] price multiplier accessor exists")
	if ConfigManager.has_method("get_shop_price_multiplier_per_floor"):
		t.assert_eq(
			ConfigManager.get_shop_price_multiplier_per_floor(),
			float(shop_cfg.get("price_multiplier_per_floor", 0.0)),
			"[FR-003] get_shop_price_multiplier_per_floor() matches JSON"
		)


func _test_room_types_shop_and_elite(t) -> void:
	## T001: room_types.shop / room_types.elite 落地
	var ids: Array = ConfigManager.get_room_type_ids()
	for required in ["shop", "elite"]:
		t.assert_true(ids.has(required), "[L4] room type exists: %s" % required)
		var room_cfg: Dictionary = ConfigManager.get_room_type(required)
		t.assert_true(room_cfg.has("intent_label"), "[L4] %s has intent_label" % required)
		t.assert_true(room_cfg.has("primary_intent"), "[L4] %s has primary_intent" % required)
		t.assert_true(room_cfg.has("placeholder_color"), "[L4] %s has placeholder_color" % required)
		t.assert_true(room_cfg.get("enabled", false), "[L4] %s room type enabled" % required)

	var shop_room: Dictionary = ConfigManager.get_room_type("shop")
	t.assert_eq(shop_room.get("auto_complete_on_enter", false), true, "[L4] shop room auto-completes on enter (退店无目标门槛)")

	var elite_room: Dictionary = ConfigManager.get_room_type("elite")
	t.assert_eq(elite_room.get("objective_type", ""), "clear_enemies", "[L4] elite room objective clears enemies")
	t.assert_eq(elite_room.get("auto_complete_on_enter", true), false, "[L4] elite room does not auto-complete")


func _test_elite_enemy_types(t) -> void:
	## T001: 精英敌人类型（is_elite 标记，复用既有敌人视觉语言：同形状 1.25x + room_elite 描边留待 UI）
	var palette: Dictionary = ConfigManager.get_presentation_config().get("palette", {})
	for base_id in ELITE_BASE_TYPES:
		var elite_id: String = "elite_%s" % base_id
		var base_cfg: Dictionary = ConfigManager.get_enemy_type(base_id)
		var elite_cfg: Dictionary = ConfigManager.get_enemy_type(elite_id)
		t.assert_true(elite_cfg.size() > 0, "[L4] elite enemy type exists: %s" % elite_id)
		if elite_cfg.is_empty():
			continue
		t.assert_eq(elite_cfg.get("is_elite", false), true, "[L4] %s has is_elite flag" % elite_id)
		t.assert_eq(elite_cfg.get("base_type", ""), base_id, "[L4] %s records base_type" % elite_id)
		t.assert_true(int(elite_cfg.get("hp", 0)) > int(base_cfg.get("hp", 0)), "[L4] %s hp > base hp" % elite_id)
		t.assert_eq(elite_cfg.get("shape", ""), base_cfg.get("shape", "?"), "[L4] %s reuses base shape (视觉语言复用)" % elite_id)
		t.assert_eq(elite_cfg.get("color", ""), base_cfg.get("color", "?"), "[L4] %s reuses base color" % elite_id)
		t.assert_eq(float(elite_cfg.get("visual_scale", 0.0)), 1.25, "[L4] %s visual_scale == 1.25" % elite_id)
		var outline_token: String = str(elite_cfg.get("outline_palette_token", ""))
		t.assert_eq(outline_token, "room_elite", "[L4] %s outline token is room_elite" % elite_id)
		t.assert_true(palette.has(outline_token), "[L4] outline palette token resolvable: %s" % outline_token)
		t.assert_false(base_cfg.get("is_elite", false), "[L4] base type %s is not elite" % base_id)


func _test_difficulty_static_floor_table(t) -> void:
	## FR-008 MUST: 静态层间压力表，层 N+1 严格更难
	var difficulty_cfg: Dictionary = ConfigManager.get_difficulty_config()
	var table: Dictionary = difficulty_cfg.get("floor_table", {})
	var max_floors: int = int(ConfigManager.get_run_config().get("max_floors", 0))
	for floor_index in range(1, max_floors + 1):
		t.assert_true(table.has(str(floor_index)), "[FR-008] floor_table covers floor %d" % floor_index)

	for floor_index in range(2, max_floors + 1):
		var prev: Dictionary = table.get(str(floor_index - 1), {})
		var curr: Dictionary = table.get(str(floor_index), {})
		t.assert_true(
			int(curr.get("enemy_count", 0)) > int(prev.get("enemy_count", 99)),
			"[FR-008] floor %d enemy_count > floor %d" % [floor_index, floor_index - 1]
		)
		t.assert_true(
			int(curr.get("enemy_hp_bonus", 0)) > int(prev.get("enemy_hp_bonus", 99)),
			"[FR-008] floor %d enemy_hp_bonus > floor %d" % [floor_index, floor_index - 1]
		)
		t.assert_true(
			int(curr.get("food_count", 0)) <= int(prev.get("food_count", 0)),
			"[FR-008] floor %d food_count <= floor %d (食物压力不回落)" % [floor_index, floor_index - 1]
		)

	t.assert_true(ConfigManager.has_method("get_difficulty_floor_params"), "[FR-008] get_difficulty_floor_params accessor exists")
	if ConfigManager.has_method("get_difficulty_floor_params"):
		t.assert_eq(ConfigManager.get_difficulty_floor_params(1), table.get("1", {}), "[FR-008] accessor returns floor 1 params")
		var highest: Dictionary = table.get(_highest_floor_key(table), {})
		t.assert_eq(ConfigManager.get_difficulty_floor_params(99), highest, "[FR-008] accessor clamps beyond-table floors")


func _test_difficulty_reactive_params(t) -> void:
	## FR-008 SHOULD: 反应式 DDA 归一化参数 JSON 化（仅生成参数级，隐性）
	var difficulty_cfg: Dictionary = ConfigManager.get_difficulty_config()
	var reactive: Dictionary = difficulty_cfg.get("reactive", {})
	t.assert_true(reactive.has("enabled"), "[FR-008] reactive DDA has enabled switch (SHOULD 可砍)")

	var normalization: Dictionary = reactive.get("normalization", {})
	for key in ["room_clear_ticks", "damage_taken_per_room", "status_usage_per_room"]:
		t.assert_true(float(normalization.get(key, 0.0)) > 0.0, "[FR-008] normalization denominator > 0: %s" % key)

	var clamp_cfg: Dictionary = reactive.get("clamp", {})
	t.assert_true(
		int(clamp_cfg.get("enemy_delta_min", 0)) < int(clamp_cfg.get("enemy_delta_max", 0)),
		"[FR-008] reactive enemy delta clamp min < max"
	)
	t.assert_true(
		int(clamp_cfg.get("food_delta_min", 0)) < int(clamp_cfg.get("food_delta_max", 0)),
		"[FR-008] reactive food delta clamp min < max"
	)

	var under: float = float(difficulty_cfg.get("underperform_threshold", 0.0))
	var over: float = float(difficulty_cfg.get("overperform_threshold", 0.0))
	t.assert_true(under > 0.0 and under < over, "[FR-008] underperform < overperform thresholds")

	t.assert_true(ConfigManager.has_method("get_difficulty_reactive_config"), "[FR-008] get_difficulty_reactive_config accessor exists")
	if ConfigManager.has_method("get_difficulty_reactive_config"):
		t.assert_eq(ConfigManager.get_difficulty_reactive_config(), reactive, "[FR-008] reactive accessor matches JSON")


func _test_room_modifier_v1_configs(t) -> void:
	## FR-009: 修饰符 v1 = shield_enemies + preset_status_tiles，逐项 disable 开关
	var ids: Array = ConfigManager.get_room_modifier_ids()
	for modifier_id in V1_MODIFIER_IDS:
		t.assert_true(ids.has(modifier_id), "[FR-009] v1 modifier exists: %s" % modifier_id)
		var mod: Dictionary = ConfigManager.get_room_modifier(modifier_id)
		t.assert_true(mod.has("display_name"), "[FR-009] %s has display_name" % modifier_id)
		t.assert_true(mod.get("enabled") is bool, "[FR-009] %s has per-item enabled switch" % modifier_id)
		t.assert_true(mod.get("enabled", false), "[FR-009] %s enabled in v1" % modifier_id)

	# T032/backlog 收容：room_modifiers 恰为 v1 双件，darkness/speed_strips/mine_tiles 草稿残留已清
	var sorted_ids: Array = ids.duplicate()
	sorted_ids.sort()
	var sorted_v1: Array = V1_MODIFIER_IDS.duplicate()
	sorted_v1.sort()
	t.assert_eq(sorted_ids, sorted_v1,
		"[T032] room_modifiers contains EXACTLY the v1 set (draft residue removed per backlog.md)")

	# T032：v1 参数形状（应用层消费的全部数值出自 JSON，FR-010）
	var shield_params: Dictionary = ConfigManager.get_room_modifier("shield_enemies").get("params", {})
	t.assert_true(int(shield_params.get("hp_bonus", 0)) >= 1, "[T032] shield_enemies.params.hp_bonus >= 1")
	t.assert_true(int(shield_params.get("max_shielded", 0)) >= 1, "[T032] shield_enemies.params.max_shielded >= 1")
	var tile_params: Dictionary = ConfigManager.get_room_modifier("preset_status_tiles").get("params", {})
	t.assert_true(int(tile_params.get("tile_count", 0)) >= 1, "[T032] preset_status_tiles.params.tile_count >= 1")
	t.assert_true(int(tile_params.get("min_distance_from_snake", 0)) >= 1,
		"[T032] preset_status_tiles keeps distance from the snake spawn")
	var tile_types: Array = tile_params.get("tile_types", [])
	t.assert_true(tile_types.size() >= 1, "[T032] preset_status_tiles.params.tile_types non-empty")
	for tile_type in tile_types:
		t.assert_true(not ConfigManager.get_status_effect(str(tile_type)).is_empty(),
			"[T032] preset tile type is a real status effect: %s" % tile_type)

	# T032：floor.modifier_weights 只引用真实存在的 v1 修饰符
	var weights: Dictionary = ConfigManager.get_floor_config().get("modifier_weights", {})
	for floor_key in weights:
		for modifier_id in weights[floor_key]:
			t.assert_true(V1_MODIFIER_IDS.has(str(modifier_id)),
				"[T032] floor %s modifier weight references a v1 modifier: %s" % [floor_key, modifier_id])

	# T032：JSON 文本零草稿残留（与 max_floors_v1 检查同款）
	var file := FileAccess.open(CONFIG_JSON_PATH, FileAccess.READ)
	if file != null:
		var text: String = file.get_as_text()
		file.close()
		for residue in ["darkness", "speed_strips", "mine_tiles"]:
			t.assert_false(text.contains("\"%s\"" % residue),
				"[T032] no draft modifier residue in game_config.json: %s" % residue)


func _test_l4_event_contracts(t) -> void:
	## T003: plan.md L4 信号清单全量存在（scale_option_discarded/floor_theme_set 为重验收补缺）
	for signal_name in [
		"currency_changed",
		"scale_reward_presented",
		"scale_reward_chosen",
		"scale_option_discarded",
		"shop_entered",
		"shop_purchase",
		"slot_unlocked",
		"floor_reward_presented",
		"floor_reward_chosen",
		"difficulty_adjusted",
		"room_modifier_applied",
		"floor_theme_set",
	]:
		t.assert_has_signal(EventBus, signal_name)


func _highest_floor_key(table: Dictionary) -> String:
	var highest: int = -1
	for key in table:
		var floor_index: int = int(str(key))
		if floor_index > highest:
			highest = floor_index
	return str(highest)
