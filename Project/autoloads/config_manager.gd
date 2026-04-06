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

# 反应查找表：("fire", "ice") → reaction_dict
var _reaction_lookup: Dictionary = {}


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


func reload_config() -> bool:
	## 开发时热重载
	return load_config()
