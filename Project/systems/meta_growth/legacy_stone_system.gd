class_name LegacyStoneSystem
extends Node

# MetaSaveSystem 实例（鸭子类型，避免 headless 下依赖全局 class_name 缓存）
var _meta_save = null


func _ready() -> void:
	connect_events()


func setup(meta_save) -> void:
	_meta_save = meta_save


func connect_events() -> void:
	if not EventBus.run_ended.is_connected(_on_run_ended):
		EventBus.run_ended.connect(_on_run_ended)


func disconnect_events() -> void:
	if EventBus.run_ended.is_connected(_on_run_ended):
		EventBus.run_ended.disconnect(_on_run_ended)


func generate_legacy_stone(stats: Dictionary) -> Dictionary:
	var highlight: String = _evaluate_highlight(stats)
	var templates: Dictionary = ConfigManager.get_legacy_stone_templates()
	var template: Dictionary = templates.get(highlight, templates.get("default", {}))

	var stone: Dictionary = {
		"description": template.get("description", ""),
		"highlight_type": highlight,
		"display_name": template.get("display_name", ""),
		"bias_config": template.get("bias_config", {}).duplicate(true),
		"created_at": Time.get_unix_time_from_system(),
	}

	if _meta_save != null:
		_meta_save.add_legacy_stone(stone)
		_meta_save.save_to_disk()

	EventBus.legacy_stone_created.emit(stone.duplicate(true))
	return stone


func select_legacy_stone(index: int) -> Dictionary:
	if _meta_save == null:
		return {}
	var stones: Array = _meta_save.get_legacy_stones()
	if index < 0 or index >= stones.size():
		return {}
	var stone: Dictionary = stones[index]
	_meta_save.remove_legacy_stone(index)
	_meta_save.save_to_disk()
	EventBus.legacy_stone_selected.emit({"stone_index": index})
	return stone


func get_available_stones() -> Array:
	if _meta_save == null:
		return []
	return _meta_save.get_legacy_stones()


func cleanup() -> void:
	disconnect_events()


func _evaluate_highlight(stats: Dictionary) -> String:
	var kills: int = int(stats.get("total_kills", 0))
	var max_chain: int = int(stats.get("max_reaction_chain", 0))
	var floors: int = int(stats.get("floors_completed", 0))
	var near_death: int = int(stats.get("near_death_count", 0))

	if kills >= 30:
		return "high_kills"
	if max_chain >= 5:
		return "complex_reaction"
	if near_death >= 2:
		return "near_death"
	if floors >= 3:
		return "long_survival"
	return "default"


func _on_run_ended(data: Dictionary) -> void:
	generate_legacy_stone(data.get("stats", {}))