extends Node
## spec 003 M3（T013，判决：保留+修）：传承石生成与选择。
## - 高光阈值 JSON 化（FR-004）：草稿魔数（30/5/2/3）→ meta_growth.legacy_stone_thresholds
##   （highlight_type 键 → 达标下限；缺键 = 该高光禁用，落到 default 石）。
##   评估优先级固定：high_kills > complex_reaction > near_death > long_survival > default。
## - `legacy_stone_selected` payload 带完整 stone dict（{stone_index, stone}，2026-06-11
##   spec 修订）：消费方（main.gd 开局注入 / S4 呈现层）无需回查存档。
## - 选中即消耗：存档移除 + 落盘（US2 场景 2），容量 5 + 最旧轮换在 MetaSaveSystem 侧。
## - 无高光 run 铸 default「旅者」石（spec Edge Case）。
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


## 选中即消耗（移除 + 落盘）并发完整 stone payload；越界返回空 dict 零副作用
func select_legacy_stone(index: int) -> Dictionary:
	if _meta_save == null:
		return {}
	var stones: Array = _meta_save.get_legacy_stones()
	if index < 0 or index >= stones.size():
		return {}
	var stone: Dictionary = stones[index]
	_meta_save.remove_legacy_stone(index)
	_meta_save.save_to_disk()
	EventBus.legacy_stone_selected.emit({
		"stone_index": index,
		"stone": stone.duplicate(true),
	})
	return stone


func get_available_stones() -> Array:
	if _meta_save == null:
		return []
	return _meta_save.get_legacy_stones()


func cleanup() -> void:
	disconnect_events()


## 阈值全 JSON（meta_growth.legacy_stone_thresholds）；缺键 = 该高光禁用
func _evaluate_highlight(stats: Dictionary) -> String:
	var thresholds: Dictionary = ConfigManager.get_legacy_stone_thresholds()
	if _meets(int(stats.get("total_kills", 0)), "high_kills", thresholds):
		return "high_kills"
	if _meets(int(stats.get("max_reaction_chain", 0)), "complex_reaction", thresholds):
		return "complex_reaction"
	if _meets(int(stats.get("near_death_count", 0)), "near_death", thresholds):
		return "near_death"
	if _meets(int(stats.get("floors_completed", 0)), "long_survival", thresholds):
		return "long_survival"
	return "default"


func _meets(value: int, key: String, thresholds: Dictionary) -> bool:
	if not thresholds.has(key):
		return false
	return value >= int(thresholds.get(key, 0))


func _on_run_ended(data: Dictionary) -> void:
	generate_legacy_stone(data.get("stats", {}))
