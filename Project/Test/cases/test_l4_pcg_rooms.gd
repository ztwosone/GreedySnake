extends RefCounted
## L4 US4 重验收测试（spec 002 T018/T019，2026-06-11 修订版 spec 对照）：
## seeded PCG 性质测试——
## - 配置入 JSON（草稿 :54-84 魔数回归，FR-010）+ accessor 钳制语义；
## - fixed_v1 留作 `floor.generator` 开关回退（FR-016/SC-011，草稿无视开关、楼层 1 短路固定路径）；
## - 定种子确定性 / 变种子高概率差异（SC-011，草稿完全不用 seed）；
## - 连通性 / 全房可达 / 房数边界（US4 场景 1）；
## - endpoint = boss（US4「boss endpoint」，草稿 endpoint 房型）；
## - 商店保底排 >= min_combat_rooms_before 战斗房后（FR-017/SC-010，草稿无 shop）；
## - 首层 modifier/elite 权重为 0 从数据生效 + 权重驱动生成 + 逐项 disable（FR-009/FR-017）。

const FLOOR_MAP_PATH: String = "res://systems/rooms/floor_map_generator.gd"
const PROPERTY_SEEDS: Array = [9001, 9002, 9003, 9004, 9005]
const FLOOR_RANGE: Array = [1, 2, 3]


func run(t) -> void:
	t.assert_file_exists(FLOOR_MAP_PATH)
	if not FileAccess.file_exists(FLOOR_MAP_PATH):
		return
	_test_pcg_config_accessors(t)
	_test_generator_switch_and_fixed_v1_fallback(t)
	_test_seeded_determinism(t)
	_test_seed_variation(t)
	_test_connectivity_and_room_shape(t)
	_test_boss_endpoint(t)
	_test_room_count_bounds(t)
	_test_shop_guarantee_after_combat(t)
	_test_floor1_pacing_zero_from_data(t)
	_test_floor2_plus_pacing_presence_from_data(t)
	_test_pacing_weights_drive_generation(t)
	_test_modifier_per_item_disable_respected(t)


# ── T019: PCG 参数全部入 JSON（FR-010，草稿 :54-84 魔数回归） ───────────────

func _test_pcg_config_accessors(t) -> void:
	t.assert_true(ConfigManager.has_method("get_pcg_config"), "[L4-US4] get_pcg_config accessor exists")
	t.assert_true(ConfigManager.has_method("get_pcg_main_room_bounds"), "[L4-US4] get_pcg_main_room_bounds accessor exists")
	if not ConfigManager.has_method("get_pcg_config") or not ConfigManager.has_method("get_pcg_main_room_bounds"):
		return

	var pcg_cfg: Dictionary = ConfigManager.get_pcg_config()
	t.assert_true(not pcg_cfg.is_empty(), "[L4-US4] floor.pcg config section exists in JSON")
	var main_rooms: Dictionary = pcg_cfg.get("main_rooms", {})
	t.assert_true(not main_rooms.is_empty(), "[L4-US4] floor.pcg.main_rooms floor-keyed bounds in JSON")
	t.assert_true(not pcg_cfg.get("middle_type_weights", {}).is_empty(), "[L4-US4] floor.pcg.middle_type_weights in JSON")
	t.assert_true(not pcg_cfg.get("side_type_weights", {}).is_empty(), "[L4-US4] floor.pcg.side_type_weights in JSON")
	t.assert_true(pcg_cfg.has("side_room_chance"), "[L4-US4] floor.pcg.side_room_chance in JSON")
	t.assert_true(pcg_cfg.has("max_side_rooms"), "[L4-US4] floor.pcg.max_side_rooms in JSON")
	t.assert_true(int(pcg_cfg.get("min_reward_rooms", 0)) >= 1, "[L4-US4] floor.pcg.min_reward_rooms >= 1 (US4 场景 1 奖励机会保底)")

	var floor1_bounds: Dictionary = ConfigManager.get_pcg_main_room_bounds(1)
	t.assert_true(int(floor1_bounds.get("min", 0)) >= 5, "[L4-US4] floor 1 main rooms min >= 5 (US4 场景 1)")
	t.assert_true(int(floor1_bounds.get("max", 0)) >= int(floor1_bounds.get("min", 0)), "[L4-US4] floor 1 main rooms max >= min")
	var highest: Dictionary = main_rooms.get(_highest_floor_key(main_rooms), {})
	t.assert_eq(ConfigManager.get_pcg_main_room_bounds(99), highest,
		"[L4-US4] main room bounds clamp beyond-table floors to highest defined floor (_get_floor_keyed_value 语义)")


# ── T019: fixed_v1 回退档（FR-016/SC-011） ──────────────────────────────────

func _test_generator_switch_and_fixed_v1_fallback(t) -> void:
	t.assert_eq(ConfigManager.get_floor_generator(), "fixed_v1", "[FR-016] default generator is fixed_v1 (MDE 回退档)")

	var fixed_map: Dictionary = _generate(1, 1001)
	var fixed_path: Array = ConfigManager.get_floor_config().get("fixed_v1_path", [])
	t.assert_eq(_room_ids(fixed_map), fixed_path, "[FR-016] fixed_v1 档输出与 fixed_v1_path 完全一致（L3 回退保护）")
	t.assert_eq(str(fixed_map.get("generator", "")), "fixed_v1", "[FR-016] fixed_v1 floor map carries generator tag")
	t.assert_eq(str(fixed_map.get("endpoint_room_id", "")), "endpoint_01", "[FR-016] fixed_v1 endpoint unchanged")

	var previous: String = _force_generator("pcg")
	var pcg_map: Dictionary = _generate(1, 1001)
	_restore_generator(previous)
	t.assert_eq(str(pcg_map.get("generator", "")), "pcg", "[SC-011] pcg 档 floor map carries generator tag")
	t.assert_true(_room_ids(pcg_map) != fixed_path,
		"[SC-011] pcg 档楼层 1 真正走 PCG（草稿回归：楼层 1 无条件短路 fixed 路径）")


# ── T018: 定种子确定性（SC-011） ────────────────────────────────────────────

func _test_seeded_determinism(t) -> void:
	var previous: String = _force_generator("pcg")
	for floor_index in FLOOR_RANGE:
		var first: Dictionary = _generate(floor_index, 9001)
		var second: Dictionary = _generate(floor_index, 9001)
		t.assert_eq(var_to_str(first), var_to_str(second),
			"[SC-011] floor %d: same seed + floor_index -> identical graph (fresh instances)" % floor_index)
	_restore_generator(previous)


func _test_seed_variation(t) -> void:
	var previous: String = _force_generator("pcg")
	var signatures: Dictionary = {}
	var seed_count: int = 10
	for run_seed in range(9001, 9001 + seed_count):
		signatures[var_to_str(_generate(2, run_seed).get("rooms", []))] = true
	t.assert_true(signatures.size() >= seed_count - 1,
		"[SC-011] %d seeds on floor 2 -> >= %d distinct room graphs (草稿回归：rooms 与 seed 完全无关)" % [seed_count, seed_count - 1])

	var floor1_types: String = var_to_str(_room_type_sequence(_generate(1, 9001)))
	var floor2_types: String = var_to_str(_room_type_sequence(_generate(2, 9001)))
	t.assert_true(floor1_types != floor2_types,
		"[SC-011] same run seed, different floor_index -> different graph (种子推导含 floor_index)")
	_restore_generator(previous)


# ── T018: 连通性 / 全房可达 / 房 dict 形状（US4 场景 1/2） ──────────────────

func _test_connectivity_and_room_shape(t) -> void:
	var previous: String = _force_generator("pcg")
	var violations: Array = []
	for floor_index in FLOOR_RANGE:
		for run_seed in PROPERTY_SEEDS:
			var floor_map: Dictionary = _generate(floor_index, run_seed)
			var rooms: Array = floor_map.get("rooms", [])
			var reachable: Dictionary = _reachable_ids(floor_map)
			if reachable.size() != rooms.size():
				violations.append("f%d s%d: %d/%d rooms reachable" % [floor_index, run_seed, reachable.size(), rooms.size()])
			var start_id: String = str(floor_map.get("start_room_id", ""))
			var start_room: Dictionary = _rooms_by_id(floor_map).get(start_id, {})
			if str(start_room.get("room_type", "")) != "combat":
				violations.append("f%d s%d: start room is %s, not combat" % [floor_index, run_seed, start_room.get("room_type", "?")])
			if not bool(start_room.get("available", false)):
				violations.append("f%d s%d: start room not available" % [floor_index, run_seed])
			for room in rooms:
				if not (room is Dictionary):
					violations.append("f%d s%d: non-dictionary room" % [floor_index, run_seed])
					continue
				for field in ["room_id", "room_type", "intent_label", "primary_intent", "objective", "exit_room_ids", "placeholder_color", "theme_id"]:
					if not room.has(field):
						violations.append("f%d s%d %s: missing %s" % [floor_index, run_seed, room.get("room_id", "?"), field])
				if not (room.get("modifiers", null) is Array):
					violations.append("f%d s%d %s: modifiers is not an Array" % [floor_index, run_seed, room.get("room_id", "?")])
	t.assert_eq(violations, [], "[L4-US4] all rooms reachable from start; room dict shape complete (3 floors x %d seeds)" % PROPERTY_SEEDS.size())
	_restore_generator(previous)


# ── T018: endpoint = boss（US4 场景 1） ─────────────────────────────────────

func _test_boss_endpoint(t) -> void:
	var boss_cfg: Dictionary = ConfigManager.get_room_type("boss")
	t.assert_true(not boss_cfg.is_empty(), "[L4-US4] room_types.boss exists in JSON")
	t.assert_eq(str(boss_cfg.get("objective_type", "")), "clear_enemies", "[L4-US4] boss room objective is clear_enemies")
	t.assert_eq(bool(boss_cfg.get("auto_complete_on_enter", true)), false, "[L4-US4] boss room does not auto-complete")

	var previous: String = _force_generator("pcg")
	var violations: Array = []
	for floor_index in FLOOR_RANGE:
		for run_seed in PROPERTY_SEEDS:
			var floor_map: Dictionary = _generate(floor_index, run_seed)
			var endpoint_id: String = str(floor_map.get("endpoint_room_id", ""))
			var by_id: Dictionary = _rooms_by_id(floor_map)
			if endpoint_id == "" or not by_id.has(endpoint_id):
				violations.append("f%d s%d: endpoint_room_id missing from rooms" % [floor_index, run_seed])
				continue
			var endpoint_room: Dictionary = by_id[endpoint_id]
			if str(endpoint_room.get("room_type", "")) != "boss":
				violations.append("f%d s%d: endpoint type %s != boss" % [floor_index, run_seed, endpoint_room.get("room_type", "?")])
			if not endpoint_room.get("exit_room_ids", []).is_empty():
				violations.append("f%d s%d: boss endpoint has exits" % [floor_index, run_seed])
			if not _reachable_ids(floor_map).has(endpoint_id):
				violations.append("f%d s%d: boss endpoint unreachable" % [floor_index, run_seed])
			var boss_count: int = 0
			for room in floor_map.get("rooms", []):
				if room is Dictionary and str(room.get("room_type", "")) == "boss":
					boss_count += 1
			if boss_count != 1:
				violations.append("f%d s%d: %d boss rooms != 1" % [floor_index, run_seed, boss_count])
	t.assert_eq(violations, [], "[L4-US4] every floor endpoint is the single reachable boss room")
	_restore_generator(previous)


# ── T018: 房数边界（config 钳制） ───────────────────────────────────────────

func _test_room_count_bounds(t) -> void:
	if not ConfigManager.has_method("get_pcg_config") or not ConfigManager.has_method("get_pcg_main_room_bounds"):
		t.assert_true(false, "[L4-US4] room count bounds need PCG config accessors (T019)")
		return
	var previous: String = _force_generator("pcg")
	var max_side: int = int(ConfigManager.get_pcg_config().get("max_side_rooms", 0))
	var violations: Array = []
	for floor_index in FLOOR_RANGE:
		var bounds: Dictionary = ConfigManager.get_pcg_main_room_bounds(floor_index)
		var lower: int = int(bounds.get("min", 0))
		var upper: int = int(bounds.get("max", 0)) + max_side
		for run_seed in PROPERTY_SEEDS:
			var total: int = _generate(floor_index, run_seed).get("rooms", []).size()
			if total < lower or total > upper:
				violations.append("f%d s%d: %d rooms outside [%d, %d]" % [floor_index, run_seed, total, lower, upper])
	t.assert_eq(violations, [], "[L4-US4] room count within JSON bounds (main_rooms + max_side_rooms)")
	_restore_generator(previous)


# ── T018: 商店保底排 >= N 战斗房后（FR-017/SC-010） ─────────────────────────

func _test_shop_guarantee_after_combat(t) -> void:
	var min_before: int = int(ConfigManager.get_shop_guarantee().get("min_combat_rooms_before", 0))
	t.assert_true(min_before >= 2, "[SC-010] shop guarantee config demands >= 2 combat rooms before shop")

	var previous: String = _force_generator("pcg")
	var violations: Array = []
	for floor_index in FLOOR_RANGE:
		for run_seed in PROPERTY_SEEDS:
			var floor_map: Dictionary = _generate(floor_index, run_seed)
			var shop_count: int = 0
			for room in floor_map.get("rooms", []):
				if room is Dictionary and str(room.get("room_type", "")) == "shop":
					shop_count += 1
			if shop_count != 1:
				violations.append("f%d s%d: %d shop rooms != 1" % [floor_index, run_seed, shop_count])
				continue
			var min_combat: int = _min_combat_before_shop(floor_map)
			if min_combat < min_before:
				violations.append("f%d s%d: only %d combat rooms before shop (< %d)" % [floor_index, run_seed, min_combat, min_before])
	t.assert_eq(violations, [], "[SC-010] every floor has exactly one shop, all paths to it pass >= %d combat rooms" % min_before)
	_restore_generator(previous)


# ── T018: 首层节奏从数据生效（FR-017/SC-010） ───────────────────────────────

func _test_floor1_pacing_zero_from_data(t) -> void:
	var previous: String = _force_generator("pcg")
	var violations: Array = []
	for run_seed in range(9001, 9013):
		var floor_map: Dictionary = _generate(1, run_seed)
		for room in floor_map.get("rooms", []):
			if not (room is Dictionary):
				continue
			if str(room.get("room_type", "")) == "elite":
				violations.append("s%d %s: elite on floor 1" % [run_seed, room.get("room_id", "?")])
			if not room.get("modifiers", []).is_empty():
				violations.append("s%d %s: modifiers on floor 1" % [run_seed, room.get("room_id", "?")])
	t.assert_eq(violations, [], "[FR-017] floor 1 has zero elite rooms and zero modifiers (weights all 0 in data)")
	_restore_generator(previous)


func _test_floor2_plus_pacing_presence_from_data(t) -> void:
	## T032 节奏互证（SC-010 正面半幅）：真实配置 + 固定种子（确定性，非抽样波动）下，
	## 2 层起精英与修饰符确实从数据权重出现，且生成的修饰符 id 全部落在 v1 集合内。
	var previous: String = _force_generator("pcg")
	var elite_seen: int = 0
	var modifier_seen: int = 0
	var foreign_modifiers: Array = []
	var v1_ids: Array = ["shield_enemies", "preset_status_tiles"]
	for floor_index in [2, 3]:
		for run_seed in range(9001, 9013):
			for room in _generate(floor_index, run_seed).get("rooms", []):
				if not (room is Dictionary):
					continue
				if str(room.get("room_type", "")) == "elite":
					elite_seen += 1
				for modifier_id in room.get("modifiers", []):
					modifier_seen += 1
					if not v1_ids.has(str(modifier_id)):
						foreign_modifiers.append("f%d s%d %s: %s" % [floor_index, run_seed, room.get("room_id", "?"), modifier_id])
	_restore_generator(previous)

	t.assert_true(elite_seen >= 1,
		"[T032] floors >= 2 generate elite rooms from data weights (got %d across fixed seeds)" % elite_seen)
	t.assert_true(modifier_seen >= 1,
		"[T032] floors >= 2 generate room modifiers from data weights (got %d across fixed seeds)" % modifier_seen)
	t.assert_eq(foreign_modifiers, [],
		"[T032] every generated modifier id belongs to the v1 set (FR-009)")


func _test_pacing_weights_drive_generation(t) -> void:
	## 反证数据通路：把首层权重拉满，同一种子必须生成出精英与修饰
	## （证明 elite/modifier 查询走 floor.elite_weights / floor.modifier_weights 数据而非硬编码）。
	var previous: String = _force_generator("pcg")
	var saved_floor: Dictionary = ConfigManager.floor.duplicate(true)
	ConfigManager.floor["elite_weights"] = {"1": 100}
	ConfigManager.floor["modifier_weights"] = {"1": {"shield_enemies": 100, "preset_status_tiles": 100}}

	var floor_map: Dictionary = _generate(1, 9001)
	var elite_count: int = 0
	var combat_like_count: int = 0
	var missing_modifiers: Array = []
	for room in floor_map.get("rooms", []):
		if not (room is Dictionary):
			continue
		var room_type: String = str(room.get("room_type", ""))
		if room_type == "elite":
			elite_count += 1
		if room_type == "combat" or room_type == "elite":
			combat_like_count += 1
			var modifiers: Array = room.get("modifiers", [])
			if not modifiers.has("shield_enemies") or not modifiers.has("preset_status_tiles"):
				missing_modifiers.append(str(room.get("room_id", "?")))

	_restore_floor_section(saved_floor)
	_restore_generator(previous)

	t.assert_true(elite_count >= 1, "[FR-017] elite weight 100 -> elite rooms appear (data-driven, got %d)" % elite_count)
	t.assert_true(combat_like_count >= 1, "[FR-017] generated floor has combat-like rooms to modify")
	t.assert_eq(missing_modifiers, [], "[FR-017] modifier weight 100 -> every combat-like room carries both v1 modifiers")


func _test_modifier_per_item_disable_respected(t) -> void:
	## FR-009: 修饰符逐项 disable 开关在生成层生效
	var previous: String = _force_generator("pcg")
	var saved_floor: Dictionary = ConfigManager.floor.duplicate(true)
	var saved_modifiers: Dictionary = ConfigManager.room_modifiers.duplicate(true)
	ConfigManager.floor["modifier_weights"] = {"1": {"shield_enemies": 100, "preset_status_tiles": 100}}
	if ConfigManager.room_modifiers.has("shield_enemies"):
		ConfigManager.room_modifiers["shield_enemies"]["enabled"] = false

	var floor_map: Dictionary = _generate(1, 9001)
	var shield_seen: bool = false
	var preset_seen: bool = false
	for room in floor_map.get("rooms", []):
		if not (room is Dictionary):
			continue
		var modifiers: Array = room.get("modifiers", [])
		if modifiers.has("shield_enemies"):
			shield_seen = true
		if modifiers.has("preset_status_tiles"):
			preset_seen = true

	_restore_floor_section(saved_floor)
	ConfigManager.room_modifiers.clear()
	ConfigManager.room_modifiers.merge(saved_modifiers)
	_restore_generator(previous)

	t.assert_false(shield_seen, "[FR-009] disabled modifier never generated even at weight 100")
	t.assert_true(preset_seen, "[FR-009] enabled modifier still generated (开关逐项独立)")


# ── helpers ─────────────────────────────────────────────────────────────────

func _generate(floor_index: int, run_seed: int) -> Dictionary:
	## 每次全新实例，证明生成器无隐藏实例状态
	return load(FLOOR_MAP_PATH).new().generate_floor(floor_index, run_seed)


func _force_generator(mode: String) -> String:
	var previous: String = str(ConfigManager.floor.get("generator", "fixed_v1"))
	ConfigManager.floor["generator"] = mode
	return previous


func _restore_generator(previous: String) -> void:
	ConfigManager.floor["generator"] = previous


func _restore_floor_section(saved: Dictionary) -> void:
	ConfigManager.floor.clear()
	ConfigManager.floor.merge(saved)


func _room_ids(floor_map: Dictionary) -> Array:
	var ids: Array = []
	for room in floor_map.get("rooms", []):
		if room is Dictionary:
			ids.append(str(room.get("room_id", "")))
	return ids


func _room_type_sequence(floor_map: Dictionary) -> Array:
	var types: Array = []
	for room in floor_map.get("rooms", []):
		if room is Dictionary:
			types.append(str(room.get("room_type", "")))
	return types


func _rooms_by_id(floor_map: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for room in floor_map.get("rooms", []):
		if room is Dictionary:
			result[str(room.get("room_id", ""))] = room
	return result


func _reachable_ids(floor_map: Dictionary) -> Dictionary:
	var by_id: Dictionary = _rooms_by_id(floor_map)
	var visited: Dictionary = {}
	var queue: Array = [str(floor_map.get("start_room_id", ""))]
	while queue.size() > 0:
		var current: String = str(queue.pop_front())
		if current == "" or visited.has(current) or not by_id.has(current):
			continue
		visited[current] = true
		for exit_id in by_id[current].get("exit_room_ids", []):
			queue.append(str(exit_id))
	return visited


func _min_combat_before_shop(floor_map: Dictionary) -> int:
	## 枚举 start -> shop 的全部简单路径，返回前缀战斗类房（combat/elite）的最小数量；
	## 无 shop 或不可达返回 -1
	var by_id: Dictionary = _rooms_by_id(floor_map)
	var shop_id: String = ""
	for room_id in by_id:
		if str(by_id[room_id].get("room_type", "")) == "shop":
			shop_id = str(room_id)
			break
	if shop_id == "":
		return -1
	var best: Array = [-1]
	_dfs_min_combat(by_id, str(floor_map.get("start_room_id", "")), shop_id, {}, 0, best)
	return best[0]


func _dfs_min_combat(by_id: Dictionary, current: String, target: String, visited: Dictionary, combat_count: int, best: Array) -> void:
	if not by_id.has(current) or visited.has(current):
		return
	if current == target:
		best[0] = combat_count if best[0] < 0 else mini(best[0], combat_count)
		return
	visited[current] = true
	var room_type: String = str(by_id[current].get("room_type", ""))
	var next_count: int = combat_count
	if room_type == "combat" or room_type == "elite":
		next_count += 1
	for exit_id in by_id[current].get("exit_room_ids", []):
		_dfs_min_combat(by_id, str(exit_id), target, visited, next_count, best)
	visited.erase(current)


func _highest_floor_key(table: Dictionary) -> String:
	var highest: int = -1
	for key in table:
		var floor_index: int = int(str(key))
		if floor_index > highest:
			highest = floor_index
	return str(highest)
