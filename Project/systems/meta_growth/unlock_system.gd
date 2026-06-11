extends Node
## spec 003 M2（T008，判决：保留+修）：解锁条件评估——Designs §12.3 附录「v1 内容映射」。
## - condition_type 与 spec FR-016 冻结 stats 字段对齐：直接以 condition_type 为 stats 键取值
##   （草稿手写映射表删除，含 survival_low_length 别名；v1 双条件 = reaction_kills / floors_completed）。
## - 幂等：已解锁目标不重复解锁、不重复发事件（spec Edge Case）；解锁即落盘（FR-002）。
## - `run_ended`（FR-016 冻结 payload）驱动评估；check_unlocks(stats) 亦可直调（测试/调用方）。
## - 已去 class_name（preload/duck-typing，ScriptingLeading C.8）。

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


## condition_type 即 FR-016 冻结 stats 字段名（数据互证由 test_l5_unlocks 钉住）
func _get_stat_value(stats: Dictionary, cond_type: String) -> int:
	return int(stats.get(cond_type, 0))


func _on_run_ended(data: Dictionary) -> void:
	check_unlocks(data.get("stats", {}))