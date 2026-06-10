class_name UnlockSystem
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


func check_unlocks(stats: Dictionary) -> Array:
	if _meta_save == null:
		return []

	var conditions: Array = ConfigManager.get_unlock_conditions()
	var unlocked: Array = []

	for cond in conditions:
		if not (cond is Dictionary):
			continue
		var cond_type: String = cond.get("condition_type", "")
		var threshold: int = int(cond.get("threshold", 0))
		var target_type: String = cond.get("target_type", "")
		var target_id: String = cond.get("target_id", "")

		if _is_already_unlocked(target_type, target_id):
			continue

		var stat_value: int = _get_stat_value(stats, cond_type)
		if stat_value >= threshold:
			_unlock_content(target_type, target_id)
			unlocked.append(cond.duplicate(true))
			EventBus.content_unlocked.emit({
				"content_type": target_type,
				"content_id": target_id,
				"display_name": cond.get("display_name", target_id),
			})

	return unlocked


func cleanup() -> void:
	disconnect_events()


func _is_already_unlocked(content_type: String, content_id: String) -> bool:
	if _meta_save == null:
		return false
	match content_type:
		"head":
			return _meta_save.is_head_unlocked(content_id)
		"tail":
			return _meta_save.is_tail_unlocked(content_id)
	return false


func _unlock_content(content_type: String, content_id: String) -> void:
	if _meta_save == null:
		return
	match content_type:
		"head":
			_meta_save.unlock_head(content_id)
		"tail":
			_meta_save.unlock_tail(content_id)
	_meta_save.save_to_disk()


func _get_stat_value(stats: Dictionary, cond_type: String) -> int:
	match cond_type:
		"total_turns":
			return int(stats.get("total_turns", 0))
		"total_kills":
			return int(stats.get("total_kills", 0))
		"reaction_kills":
			return int(stats.get("reaction_kills", 0))
		"survival_low_length":
			return int(stats.get("survival_low_length_ticks", 0))
		"floors_completed":
			return int(stats.get("floors_completed", 0))
	return 0


func _on_run_ended(data: Dictionary) -> void:
	check_unlocks(data.get("stats", {}))