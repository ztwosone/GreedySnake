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
