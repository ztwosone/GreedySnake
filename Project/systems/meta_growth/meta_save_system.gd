extends RefCounted
## spec 003 M1（T002，判决：保留+微修）：L5 元成长存档。
## - save_path 注入缝：构造参数注入（测试用 user:// 临时路径），缺省读 meta_growth.save_path
##   （生产路径 user://meta_save.json，FR-009）；草稿 _init 隐式读盘已改为显式 load_from_disk()
##   （注入必须先于首次磁盘 IO）。
## - schema_version：写入恒带（FR-014）；读档校验——parse 失败 / 非 Dictionary 形状 / 版本未知
##   → push_warning + 容错重置默认值，绝不带病加载。
## - 默认值含默认解锁集（meta_growth.default_unlocked_heads/tails，hydra/salamander）。

var _save_path: String = ""
var _data: Dictionary = {}


func _init(save_path: String = "") -> void:
	_save_path = save_path
	if _save_path == "":
		_save_path = str(ConfigManager.get_meta_growth_config().get("save_path", "user://meta_save.json"))
	_data = _default_data()


func get_save_path() -> String:
	return _save_path


func load_from_disk() -> bool:
	if not FileAccess.file_exists(_save_path):
		_data = _default_data()
		return false
	var file := FileAccess.open(_save_path, FileAccess.READ)
	if not file:
		push_warning("[MetaSave] cannot open save file, tolerant reset: %s" % _save_path)
		_data = _default_data()
		return false
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("[MetaSave] corrupt save file (JSON parse error), tolerant reset: %s" % _save_path)
		_data = _default_data()
		return false
	var result = json.data
	if not (result is Dictionary):
		push_warning("[MetaSave] save file is not a Dictionary, tolerant reset: %s" % _save_path)
		_data = _default_data()
		return false
	var version: int = int(result.get("schema_version", -1))
	if version != ConfigManager.get_meta_schema_version():
		push_warning("[MetaSave] unknown schema_version %d (expected %d), tolerant reset: %s"
			% [version, ConfigManager.get_meta_schema_version(), _save_path])
		_data = _default_data()
		return false
	_data = result
	return true


func save_to_disk() -> bool:
	_data["schema_version"] = ConfigManager.get_meta_schema_version()
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(JSON.stringify(_data, "  "))
	file.close()
	return true


func is_head_unlocked(head_id: String) -> bool:
	return _data.get("unlocked_heads", []).has(head_id)


func unlock_head(head_id: String) -> void:
	var unlocked: Array = _data.get("unlocked_heads", [])
	if not unlocked.has(head_id):
		unlocked.append(head_id)
		_data["unlocked_heads"] = unlocked


func is_tail_unlocked(tail_id: String) -> bool:
	return _data.get("unlocked_tails", []).has(tail_id)


func unlock_tail(tail_id: String) -> void:
	var unlocked: Array = _data.get("unlocked_tails", [])
	if not unlocked.has(tail_id):
		unlocked.append(tail_id)
		_data["unlocked_tails"] = unlocked


func add_legacy_stone(stone: Dictionary) -> void:
	var stones: Array = _data.get("legacy_stones", [])
	var max_stones: int = ConfigManager.get_max_legacy_stones()
	stones.append(stone)
	while stones.size() > max_stones:
		stones.pop_front()
	_data["legacy_stones"] = stones


func get_legacy_stones() -> Array:
	return _data.get("legacy_stones", []).duplicate()


func remove_legacy_stone(index: int) -> Dictionary:
	var stones: Array = _data.get("legacy_stones", [])
	if index < 0 or index >= stones.size():
		return {}
	var stone: Dictionary = stones[index]
	stones.remove_at(index)
	_data["legacy_stones"] = stones
	return stone


func get_unlocked_heads() -> Array:
	return _data.get("unlocked_heads", []).duplicate()


func get_unlocked_tails() -> Array:
	return _data.get("unlocked_tails", []).duplicate()


func reset() -> void:
	_data = _default_data()


func _default_data() -> Dictionary:
	return {
		"schema_version": ConfigManager.get_meta_schema_version(),
		"unlocked_heads": ConfigManager.get_default_unlocked_heads().duplicate(),
		"unlocked_tails": ConfigManager.get_default_unlocked_tails().duplicate(),
		"discovered_scales": [],
		"legacy_stones": [],
	}
