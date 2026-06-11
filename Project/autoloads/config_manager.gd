extends Node

## JSON 配置管理器
## 加载 data/json/game_config.json，提供类型化访问接口。
## 必须在 Constants 之前注册为 autoload。

const CONFIG_PATH: String = "res://data/json/game_config.json"

var _data: Dictionary = {}

# === Section 缓存 ===
var grid: Dictionary = {}
var tick: Dictionary = {}
var snake: Dictionary = {}
var food: Dictionary = {}
var enemy: Dictionary = {}
var status_effects: Dictionary = {}
var reactions: Dictionary = {}
var enemy_types: Dictionary = {}
var length_thresholds: Dictionary = {}
var snake_heads: Dictionary = {}
var snake_tails: Dictionary = {}
var snake_scales: Dictionary = {}
var tag_resonances: Dictionary = {}
var scale_resonance_overrides: Dictionary = {}
var run: Dictionary = {}
var floor: Dictionary = {}
var room_types: Dictionary = {}
var rewards: Dictionary = {}
var endpoint: Dictionary = {}
var growth: Dictionary = {}
var shop: Dictionary = {}
var difficulty: Dictionary = {}
var room_modifiers: Dictionary = {}
var floor_themes: Dictionary = {}
var meta_growth: Dictionary = {}
var event_pickups: Dictionary = {}
var presentation: Dictionary = {}

# 反应查找表：("fire", "ice") → reaction_dict
var _reaction_lookup: Dictionary = {}
# 共鸣查找表：双向 tag pair → resonance_dict
var _tag_res_lookup: Dictionary = {}
# 共鸣覆盖查找表：双向 scale pair → override_dict
var _scale_override_lookup: Dictionary = {}


func _ready() -> void:
	load_config()


func load_config(path: String = CONFIG_PATH) -> bool:
	if not FileAccess.file_exists(path):
		push_warning("ConfigManager: config file not found at %s, using defaults" % path)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("ConfigManager: failed to open %s" % path)
		return false

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("ConfigManager: JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return false

	var result = json.data
	if not result is Dictionary:
		push_error("ConfigManager: JSON root must be a Dictionary")
		return false

	_data = result
	_populate_sections()
	_build_reaction_lookup()
	_build_resonance_lookups()
	return true


func _populate_sections() -> void:
	grid = _data.get("grid", {})
	tick = _data.get("tick", {})
	snake = _data.get("snake", {})
	food = _data.get("food", {})
	enemy = _data.get("enemy", {})
	status_effects = _data.get("status_effects", {})
	reactions = _data.get("reactions", {})
	enemy_types = _data.get("enemy_types", {})
	length_thresholds = _data.get("length_thresholds", {})
	snake_heads = _data.get("snake_heads", {})
	snake_tails = _data.get("snake_tails", {})
	snake_scales = _data.get("snake_scales", {})
	tag_resonances = _data.get("tag_resonances", {})
	scale_resonance_overrides = _data.get("scale_resonance_overrides", {})
	run = _data.get("run", {})
	floor = _data.get("floor", {})
	room_types = _data.get("room_types", {})
	rewards = _data.get("rewards", {})
	endpoint = _data.get("endpoint", {})
	growth = _data.get("growth", {})
	shop = _data.get("shop", {})
	difficulty = _data.get("difficulty", {})
	room_modifiers = _data.get("room_modifiers", {})
	floor_themes = _data.get("floor_themes", {})
	meta_growth = _data.get("meta_growth", {})
	event_pickups = _data.get("event_pickups", {})
	presentation = _data.get("presentation", {})


func _build_reaction_lookup() -> void:
	_reaction_lookup.clear()
	for reaction_id in reactions:
		var r: Dictionary = reactions[reaction_id]
		var a: String = r.get("type_a", "")
		var b: String = r.get("type_b", "")
		if a != "" and b != "":
			# 双向注册
			var key_ab := _make_reaction_key(a, b)
			var key_ba := _make_reaction_key(b, a)
			_reaction_lookup[key_ab] = r
			_reaction_lookup[key_ba] = r


func _make_reaction_key(a: String, b: String) -> String:
	return "%s+%s" % [a, b]


# === 公共 API ===

func get_status_effect(id: String) -> Dictionary:
	return status_effects.get(id, {})


func get_enemy_type(id: String) -> Dictionary:
	return enemy_types.get(id, {})


func get_reaction(id: String) -> Dictionary:
	return reactions.get(id, {})


func find_reaction(type_a: String, type_b: String) -> Dictionary:
	## 双向匹配：find_reaction("fire","ice") == find_reaction("ice","fire")
	var key := _make_reaction_key(type_a, type_b)
	return _reaction_lookup.get(key, {})


func get_status_effect_ids() -> Array:
	return status_effects.keys()


func get_enemy_type_ids() -> Array:
	return enemy_types.keys()


func get_reaction_ids() -> Array:
	return reactions.keys()


func get_snake_head(head_id: String, level: int = 1) -> Dictionary:
	var head_cfg: Dictionary = snake_heads.get(head_id, {})
	var levels: Dictionary = head_cfg.get("levels", {})
	return levels.get(str(level), {})


func get_snake_head_ids() -> Array:
	return snake_heads.keys()


func get_snake_tail(tail_id: String, level: int = 1) -> Dictionary:
	var tail_cfg: Dictionary = snake_tails.get(tail_id, {})
	var levels: Dictionary = tail_cfg.get("levels", {})
	return levels.get(str(level), {})


func get_snake_tail_ids() -> Array:
	return snake_tails.keys()


func get_snake_scale(scale_id: String, level: int = 1) -> Dictionary:
	var scale_cfg: Dictionary = snake_scales.get(scale_id, {})
	var levels: Dictionary = scale_cfg.get("levels", {})
	return levels.get(str(level), {})


func get_snake_scale_ids() -> Array:
	return snake_scales.keys()


func get_scale_tags(scale_id: String) -> Array:
	var scale_cfg: Dictionary = snake_scales.get(scale_id, {})
	return scale_cfg.get("tags", [])


func find_tag_resonance(tag_a: String, tag_b: String) -> Dictionary:
	## 双向匹配 tag pair 共鸣
	var key := _make_tag_res_key(tag_a, tag_b)
	return _tag_res_lookup.get(key, {})


func find_scale_resonance_override(scale_a: String, scale_b: String) -> Dictionary:
	## 双向匹配 scale pair 覆盖
	var key := _make_sorted_key(scale_a, scale_b)
	return _scale_override_lookup.get(key, {})


func get_tag_resonance_ids() -> Array:
	var ids: Array = []
	for key in tag_resonances:
		var res_id: String = tag_resonances[key].get("resonance_id", key)
		if not ids.has(res_id):
			ids.append(res_id)
	return ids


func get_run_config() -> Dictionary:
	return run


func get_floor_config() -> Dictionary:
	return floor


# === L4 重验收基线 accessor（spec 002 FR-016/FR-017，2026-06-11） ===

func get_max_floors() -> int:
	## FR-016: run.max_floors（取代已删除的 max_floors_v1）
	return int(run.get("max_floors", 1))


func get_floor_generator() -> String:
	## FR-016: 楼层生成器开关，枚举 "fixed_v1" | "pcg"
	return str(floor.get("generator", "fixed_v1"))


func get_floor_modifier_weights(floor_index: int) -> Dictionary:
	## FR-017: 逐层修饰符权重（首层全 0）；超出表的楼层钳制到最高已定义层
	return _get_floor_keyed_value(floor.get("modifier_weights", {}), floor_index, {})


func get_floor_elite_weight(floor_index: int) -> int:
	## FR-017: 逐层精英权重（首层 0）；超出表的楼层钳制到最高已定义层
	return int(_get_floor_keyed_value(floor.get("elite_weights", {}), floor_index, 0))


func get_shop_guarantee() -> Dictionary:
	## FR-017: 每层保底商店参数（>= min_combat_rooms_before 战斗房后）
	return floor.get("shop_guarantee", {})


func get_pcg_config() -> Dictionary:
	## T019: PCG 生成参数段（floor.pcg——主路径房数表/房型权重/支线参数，FR-010 无魔数）
	return floor.get("pcg", {})


func get_pcg_main_room_bounds(floor_index: int) -> Dictionary:
	## T019: 指定楼层主路径房数边界 {min, max}；超出表的楼层钳制到最高已定义层
	return _get_floor_keyed_value(get_pcg_config().get("main_rooms", {}), floor_index, {})


func get_shop_price_multiplier_per_floor() -> float:
	## FR-003: 跨层物价压力阀（蜕皮不清零，下层物价上涨）
	return float(shop.get("price_multiplier_per_floor", 1.0))


func get_difficulty_floor_table() -> Dictionary:
	## FR-008 MUST: 静态层间压力表
	return difficulty.get("floor_table", {})


func get_difficulty_floor_params(floor_index: int) -> Dictionary:
	## FR-008 MUST: 指定楼层的静态压力参数；超出表的楼层钳制到最高已定义层
	return _get_floor_keyed_value(get_difficulty_floor_table(), floor_index, {})


func get_difficulty_reactive_config() -> Dictionary:
	## FR-008 SHOULD: 反应式 DDA 归一化/钳制参数（隐性，仅生成参数级生效）
	return difficulty.get("reactive", {})


func _get_floor_keyed_value(table: Dictionary, floor_index: int, fallback: Variant) -> Variant:
	## 楼层键表查询："1"/"2"/... 精确命中；否则钳制到 <= floor_index 的最高层；再否则取最低层
	var exact: String = str(floor_index)
	if table.has(exact):
		return table[exact]
	var best_floor: int = -1
	var lowest_floor: int = 0x7FFFFFFF
	for key in table:
		var key_floor: int = int(str(key))
		lowest_floor = mini(lowest_floor, key_floor)
		if key_floor <= floor_index and key_floor > best_floor:
			best_floor = key_floor
	if best_floor > 0:
		return table[str(best_floor)]
	if lowest_floor != 0x7FFFFFFF:
		return table[str(lowest_floor)]
	return fallback


func get_room_type(room_type: String) -> Dictionary:
	return room_types.get(room_type, {})


func get_room_type_ids() -> Array:
	return room_types.keys()


func get_reward_config() -> Dictionary:
	return rewards


func get_reward_pool(pool_id: String) -> Array:
	var pools: Dictionary = rewards.get("pools", {})
	return pools.get(pool_id, [])


func get_reward_pool_ids() -> Array:
	var pools: Dictionary = rewards.get("pools", {})
	return pools.keys()


func get_endpoint_config() -> Dictionary:
	return endpoint


func get_growth_config() -> Dictionary:
	return growth


func get_shedskin_config() -> Dictionary:
	return growth.get("shedskin", {})


func get_scale_reward_config() -> Dictionary:
	return growth.get("scale_reward", {})


func get_scale_reward_pool(pool_id: String) -> Array:
	var pools: Dictionary = growth.get("scale_reward", {}).get("pools", {})
	return pools.get(pool_id, [])


func get_scale_reward_pool_ids() -> Array:
	var pools: Dictionary = growth.get("scale_reward", {}).get("pools", {})
	return pools.keys()


func get_slot_expansion_config() -> Dictionary:
	return growth.get("slot_expansion", {})


func get_floor_reward_config() -> Dictionary:
	return growth.get("floor_reward", {})


func get_shop_config() -> Dictionary:
	return shop


func get_shop_item_price(item_id: String) -> int:
	var categories: Dictionary = shop.get("item_categories", {})
	var cat: Dictionary = categories.get(item_id, {})
	return int(cat.get("price", 0))


func get_shop_item_category(item_id: String) -> String:
	var categories: Dictionary = shop.get("item_categories", {})
	var cat: Dictionary = categories.get(item_id, {})
	return cat.get("category", "")


func get_difficulty_config() -> Dictionary:
	return difficulty


func get_room_modifier(modifier_id: String) -> Dictionary:
	return room_modifiers.get(modifier_id, {})


func get_room_modifier_ids() -> Array:
	return room_modifiers.keys()


func get_floor_theme(theme_id: String) -> Dictionary:
	return floor_themes.get(theme_id, {})


func get_floor_theme_ids() -> Array:
	return floor_themes.keys()


func get_meta_growth_config() -> Dictionary:
	return meta_growth


func get_unlock_conditions() -> Array:
	return meta_growth.get("unlock_conditions", [])


func get_legacy_stone_templates() -> Dictionary:
	return meta_growth.get("legacy_stone_templates", {})


## spec 003 M3（T013）：高光评估阈值（highlight_type 键 → 达标下限；缺键 = 该高光禁用，
## 落到 default 石——FR-004/FR-010，草稿魔数 30/5/2/3 已入 JSON）
func get_legacy_stone_thresholds() -> Dictionary:
	return meta_growth.get("legacy_stone_thresholds", {})


func get_max_legacy_stones() -> int:
	return int(meta_growth.get("max_legacy_stones", 5))


## spec 003 M1：meta 存档 schema 版本（写入恒带；读档不符 → 容错重置，FR-014）
func get_meta_schema_version() -> int:
	return int(meta_growth.get("schema_version", 1))


## spec 003 M1：run 统计度量参数（low_length_threshold 等，FR-010）
func get_meta_stats_config() -> Dictionary:
	return meta_growth.get("stats", {})


## spec 003 M1：默认解锁集（新档/容错重置即含，Designs §12.3 附录 v1 映射）
func get_default_unlocked_heads() -> Array:
	return meta_growth.get("default_unlocked_heads", [])


func get_default_unlocked_tails() -> Array:
	return meta_growth.get("default_unlocked_tails", [])


func get_event_pickups_config() -> Dictionary:
	return event_pickups


func get_pickup(pickup_id: String) -> Dictionary:
	var pickups: Dictionary = event_pickups.get("pickups", {})
	return pickups.get(pickup_id, {})


# === Presentation（SpecKit 004，设计文档 presentation_design.md §14） ===

func get_presentation_config() -> Dictionary:
	return presentation


func get_palette_color(token: String) -> Color:
	## §2.1 语义色 token → Color；未知/非法 token 警告并回退品红
	var palette: Dictionary = presentation.get("palette", {})
	var hex: String = str(palette.get(token, ""))
	if hex.is_empty() or not Color.html_is_valid(hex):
		push_warning("ConfigManager: unknown palette token '%s', falling back to magenta" % token)
		return Color.MAGENTA
	return Color.html(hex)


func get_typography() -> Dictionary:
	return presentation.get("typography", {})


func get_motion() -> Dictionary:
	return presentation.get("motion", {})


func get_layout_config() -> Dictionary:
	return presentation.get("layout", {})


func get_acceptance_config() -> Dictionary:
	return presentation.get("acceptance", {})


func get_ceremony_config() -> Dictionary:
	## §7/§8 仪式编排参数（Phase P；CeremonyLayer 唯一数值来源）
	return presentation.get("ceremony", {})


func get_death_cause_text(cause: String) -> String:
	## §7 死亡仪式：cause→中文映射（presentation.death_causes；缺键回退原文）
	var causes: Dictionary = presentation.get("death_causes", {})
	return str(causes.get(cause, cause))


func get_game_feel() -> Dictionary:
	## §9 game-feel 强度/数量调参（VFXManager 默认参数来源）
	return presentation.get("game_feel", {})


func get_glyph_def(glyph_id: String) -> Array:
	## §3 glyph 定义（≤4 矩形）；"_" 前缀为元数据键，非 glyph
	var glyphs: Dictionary = presentation.get("glyphs", {})
	var def: Variant = glyphs.get(glyph_id, [])
	if def is Array:
		return def
	return []


func is_debug_ui_enabled() -> bool:
	return bool(presentation.get("debug_ui", false))


func _build_resonance_lookups() -> void:
	_tag_res_lookup.clear()
	_scale_override_lookup.clear()
	# Tag resonances: 双向注册
	for key in tag_resonances:
		var cfg: Dictionary = tag_resonances[key]
		_tag_res_lookup[key] = cfg
		# 生成反向 key
		var parts: Array = key.split("+")
		if parts.size() == 2:
			var reverse_key: String = parts[1] + "+" + parts[0]
			_tag_res_lookup[reverse_key] = cfg
	# Scale overrides: 双向注册
	for key in scale_resonance_overrides:
		var cfg: Dictionary = scale_resonance_overrides[key]
		_scale_override_lookup[key] = cfg
		var parts: Array = key.split("+")
		if parts.size() == 2:
			var reverse_key: String = parts[1] + "+" + parts[0]
			_scale_override_lookup[reverse_key] = cfg


func _make_tag_res_key(a: String, b: String) -> String:
	return "%s+%s" % [a, b]


func _make_sorted_key(a: String, b: String) -> String:
	if a < b:
		return "%s+%s" % [a, b]
	return "%s+%s" % [b, a]


func reload_config() -> bool:
	## 开发时热重载
	return load_config()
