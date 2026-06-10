class_name MetaSaveSystem
extends RefCounted

var _data: Dictionary = {
	"unlocked_heads": [],
	"unlocked_tails": [],
	"discovered_scales": [],
	"legacy_stones": [],
}


func _init() -> void:
	load_from_disk()


func load_from_disk() -> bool:
	var cfg: Dictionary = ConfigManager.get_meta_growth_config()
	var save_path: String = cfg.get("save_path", "user://meta_save.json")
	if not FileAccess.file_exists(save_path):
		return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return false
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		return false
	var result = json.data
	if result is Dictionary:
		_data = result
		return true
	return false


func save_to_disk() -> bool:
	var cfg: Dictionary = ConfigManager.get_meta_growth_config()
	var save_path: String = cfg.get("save_path", "user://meta_save.json")
	var file := FileAccess.open(save_path, FileAccess.WRITE)
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
	_data = {
		"unlocked_heads": [],
		"unlocked_tails": [],
		"discovered_scales": [],
		"legacy_stones": [],
	}