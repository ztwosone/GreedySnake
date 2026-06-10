extends RefCounted
## FloorMapGenerator（spec 002 T019 重写，2026-06-11 重验收）
## 楼层房间图生成器，双档（FR-016 `floor.generator`）：
## - "fixed_v1"：L3 固定 6 房路径，回退/MDE 档，输出与 L3 验收完全一致；
## - "pcg"：种子确定性程序化生成（SC-011）。
##
## PCG 种子推导（SC-011 文档化）：
##   rng.seed = hash("run_seed:floor_index")
## 同一 run 内不同楼层得到独立且可复现的序列；与 ShopSystem 的
## hash("run_seed:room_id") 派生约定一致。RNG 调用顺序固定——任何重排都会
## 改变同种子输出（性质测试 var_to_str 全等比对）：
##   ① 主题 → ② 主路径房数 → ③ 自由槽房型 → ④ 中段洗牌 → ⑤ 商店插位
##   → ⑥ 支线房 → ⑦ 精英升格 → ⑧ 修饰符
##
## 结构保证（构造即性质，test_l4_pcg_rooms.gd 对照）：
## - 起点房 = combat、终点房 = boss，恰一间（US4 场景 1）；
## - 每层恰一间商店，所有 start→shop 路径途经 >= shop_guarantee.min_combat_rooms_before
##   个战斗类房（combat/elite，FR-017/SC-010）——通过预留中段战斗槽 + 插位下界构造保证；
## - 至少 floor.pcg.min_reward_rooms 间奖励房（US4「奖励机会」）；
## - 主路径 exits[0] = 下一主路径房，支线房挂在主路径房 exits 末尾且为死端（全房可达）；
## - 精英升格/修饰符按 floor.elite_weights / floor.modifier_weights 数据权重生效
##   （首层全 0 = 概念节奏，FR-017），修饰符尊重逐项 enabled 开关（FR-009）；
## - 全部数值出自 `floor.pcg` JSON（FR-010，草稿 :54-84 魔数已清除）。

func generate_floor(floor_index: int, run_seed: int) -> Dictionary:
	var fixed_path: Array = ConfigManager.get_floor_config().get("fixed_v1_path", [])
	if ConfigManager.get_floor_generator() == "pcg" or fixed_path.is_empty():
		return _generate_pcg(floor_index, run_seed)
	return _generate_fixed_v1(floor_index, run_seed, fixed_path)


# ── fixed_v1 档（L3 回退路径，行为不变） ────────────────────────────────────

func _generate_fixed_v1(floor_index: int, run_seed: int, path: Array) -> Dictionary:
	var rooms: Array = []
	for index in range(path.size()):
		var room_id: String = path[index]
		var next_id: String = path[index + 1] if index < path.size() - 1 else ""
		var exits: Array = [next_id] if next_id != "" else []
		rooms.append(_make_room(room_id, _room_type_from_id(room_id), exits, index == 0, "", []))
	return {
		"floor_id": "floor_%d_%d" % [floor_index, run_seed],
		"floor_index": floor_index,
		"seed": run_seed,
		"generator": "fixed_v1",
		"rooms": rooms,
		"start_room_id": path[0] if path.size() > 0 else "",
		"endpoint_room_id": path[path.size() - 1] if path.size() > 0 else "",
		"theme_id": "",
	}


# ── pcg 档（seeded，T019） ──────────────────────────────────────────────────

func _generate_pcg(floor_index: int, run_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d" % [run_seed, floor_index])

	var pcg_cfg: Dictionary = ConfigManager.get_pcg_config()
	var guarantee: Dictionary = ConfigManager.get_shop_guarantee()

	# ① 主题（floor_themes 键序来自 JSON，迭代确定）
	var theme_ids: Array = ConfigManager.get_floor_theme_ids()
	var theme_id: String = ""
	if theme_ids.size() > 0:
		theme_id = str(theme_ids[rng.randi_range(0, theme_ids.size() - 1)])

	# ② 主路径房数
	var bounds: Dictionary = ConfigManager.get_pcg_main_room_bounds(floor_index)
	var main_min: int = int(bounds.get("min", 5))
	var main_max: int = maxi(main_min, int(bounds.get("max", main_min)))
	var main_count: int = rng.randi_range(main_min, main_max)

	# 中段保底内容：商店 ×1（保底开关）、奖励 ×min_reward_rooms、
	# 战斗 ×(min_combat_rooms_before - 1)（起点房固定 combat，计入 1 个）
	var shop_enabled: bool = bool(guarantee.get("enabled", true))
	var min_combat_before: int = int(guarantee.get("min_combat_rooms_before", 2))
	var reserved_combat: int = maxi(0, min_combat_before - 1)
	var min_reward_rooms: int = int(pcg_cfg.get("min_reward_rooms", 1))
	var reserved_total: int = reserved_combat + min_reward_rooms + (1 if shop_enabled else 0)
	main_count = maxi(main_count, 2 + reserved_total)  # 防御钳制：中段必须装得下保底内容

	# ③ 自由槽房型（中段 = 主路径去掉起点与 boss）
	var middle: Array = []
	for _i in range(reserved_combat):
		middle.append("combat")
	for _i in range(min_reward_rooms):
		middle.append("reward")
	var middle_weights: Dictionary = pcg_cfg.get("middle_type_weights", {})
	var free_slots: int = main_count - 2 - middle.size() - (1 if shop_enabled else 0)
	for _i in range(free_slots):
		var picked: String = _weighted_pick(rng, middle_weights)
		middle.append(picked if picked != "" else "combat")

	# ④ 中段洗牌（seeded Fisher-Yates；Array.shuffle 走全局 RNG，不可用）
	_seeded_shuffle(rng, middle)

	# ⑤ 商店插位：下界 = 中段第 (min_combat_before - 1) 个战斗房之后
	#（起点 combat 贡献第 1 个），上界 = 中段末尾；保留 combat 槽保证下界存在
	if shop_enabled:
		var needed: int = min_combat_before - 1
		var earliest: int = 0
		var seen: int = 0
		while earliest < middle.size() and seen < needed:
			if _is_combat_like(middle[earliest]):
				seen += 1
			earliest += 1
		middle.insert(rng.randi_range(earliest, middle.size()), "shop")

	var types: Array = ["combat"]
	types.append_array(middle)
	types.append("boss")
	var path_count: int = types.size()

	# ⑥ 支线房：死端，挂在任一非 boss 主路径房上；房型不允许 shop/boss
	var side_types: Array = []
	var side_parents: Array = []
	var side_weights: Dictionary = pcg_cfg.get("side_type_weights", {})
	var side_chance: float = float(pcg_cfg.get("side_room_chance", 0.0))
	for _i in range(int(pcg_cfg.get("max_side_rooms", 0))):
		if rng.randf() >= side_chance:
			continue
		var side_type: String = _weighted_pick(rng, side_weights)
		if side_type == "" or side_type == "shop" or side_type == "boss":
			side_type = "combat"
		side_types.append(side_type)
		side_parents.append(rng.randi_range(0, path_count - 2))

	# ⑦ 精英升格：combat 按 floor.elite_weights 概率升格（起点与 boss 豁免，
	# 开局可读性 + 终点唯一性）；首层权重 0 = 永不出现（FR-017）
	var elite_weight: float = float(ConfigManager.get_floor_elite_weight(floor_index))
	for index in range(1, path_count - 1):
		if types[index] == "combat" and rng.randf() * 100.0 < elite_weight:
			types[index] = "elite"
	for index in range(side_types.size()):
		if side_types[index] == "combat" and rng.randf() * 100.0 < elite_weight:
			side_types[index] = "elite"

	# 组装房 id（type_序号_f层，序号 = rooms 数组下标，保证唯一）
	var main_ids: Array = []
	for index in range(path_count):
		main_ids.append("%s_%02d_f%d" % [types[index], index, floor_index])
	var side_ids: Array = []
	for index in range(side_types.size()):
		side_ids.append("%s_%02d_f%d" % [side_types[index], path_count + index, floor_index])

	# 出口：主路径 exits[0] = 下一主路径房，支线挂末尾；支线为死端
	var rooms: Array = []
	for index in range(path_count):
		var exits: Array = []
		if index < path_count - 1:
			exits.append(main_ids[index + 1])
		for side_index in range(side_parents.size()):
			if side_parents[side_index] == index:
				exits.append(side_ids[side_index])
		rooms.append(_make_room(main_ids[index], types[index], exits, index == 0, theme_id, []))
	for index in range(side_types.size()):
		rooms.append(_make_room(side_ids[index], side_types[index], [], false, theme_id, []))

	# ⑧ 修饰符：战斗类房（combat/elite）按 floor.modifier_weights 逐项概率附加；
	# 尊重 room_modifiers.<id>.enabled 逐项开关（FR-009）；boss 房豁免（v1 可读性）
	var modifier_weights: Dictionary = ConfigManager.get_floor_modifier_weights(floor_index)
	for room in rooms:
		if not _is_combat_like(str(room.get("room_type", ""))):
			continue
		var modifiers: Array = room.get("modifiers", [])
		for modifier_id in modifier_weights:
			var weight: float = float(modifier_weights[modifier_id])
			if weight <= 0.0:
				continue
			if not bool(ConfigManager.get_room_modifier(str(modifier_id)).get("enabled", false)):
				continue
			if rng.randf() * 100.0 < weight:
				modifiers.append(str(modifier_id))

	return {
		"floor_id": "floor_%d_%d" % [floor_index, run_seed],
		"floor_index": floor_index,
		"seed": run_seed,
		"generator": "pcg",
		"rooms": rooms,
		"start_room_id": main_ids[0],
		"endpoint_room_id": main_ids[path_count - 1],
		"theme_id": theme_id,
	}


# ── helpers ─────────────────────────────────────────────────────────────────

func _make_room(room_id: String, room_type: String, exits: Array, available: bool, theme_id: String, modifiers: Array) -> Dictionary:
	var room_cfg: Dictionary = ConfigManager.get_room_type(room_type)
	return {
		"room_id": room_id,
		"room_type": room_type,
		"intent_label": room_cfg.get("intent_label", room_id),
		"primary_intent": room_cfg.get("primary_intent", ""),
		"objective": {
			"objective_type": room_cfg.get("objective_type", "clear_enemies"),
			"required_count": int(room_cfg.get("required_count", 3)),
			"current_count": 0,
			"complete": false,
		},
		"exit_room_ids": exits,
		"placeholder_color": room_cfg.get("placeholder_color", "#FFFFFF"),
		"enabled": true,
		"available": available,
		"completed": false,
		"auto_complete_on_enter": bool(room_cfg.get("auto_complete_on_enter", false)),
		"enemy_count": int(room_cfg.get("enemy_count", 3)),
		"theme_id": theme_id,
		"modifiers": modifiers,
	}


func _is_combat_like(room_type: String) -> bool:
	return room_type == "combat" or room_type == "elite"


func _weighted_pick(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total: float = 0.0
	for key in weights:
		total += maxf(0.0, float(weights[key]))
	if total <= 0.0:
		return ""
	var roll: float = rng.randf() * total
	for key in weights:
		roll -= maxf(0.0, float(weights[key]))
		if roll < 0.0:
			return str(key)
	return str(weights.keys().back())


func _seeded_shuffle(rng: RandomNumberGenerator, items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swapped = items[i]
		items[i] = items[j]
		items[j] = swapped


func _room_type_from_id(room_id: String) -> String:
	for room_type in ["combat", "reward", "rest", "endpoint", "shop", "elite", "boss"]:
		if room_id.begins_with(room_type):
			return room_type
	return "combat"
