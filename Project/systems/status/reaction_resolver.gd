class_name ReactionResolver
extends Node

## JSON 驱动的反应规则引擎（T27A）
## 替代 3 处硬编码的 _get_reaction_id()
## 从 ConfigManager 的 reactions 配置中构建 sorted pair → reaction_id 映射

var _reaction_map: Dictionary = {}  # { "fire|ice" → "steam", ... }


func _ready() -> void:
	_build_reaction_map()


func _build_reaction_map() -> void:
	_reaction_map.clear()
	var reaction_ids: Array = ConfigManager.get_reaction_ids()
	for reaction_id in reaction_ids:
		var cfg: Dictionary = ConfigManager.get_reaction(reaction_id)
		var a: String = cfg.get("type_a", "")
		var b: String = cfg.get("type_b", "")
		if a != "" and b != "":
			var pair: Array = [a, b]
			pair.sort()
			var key: String = pair[0] + "|" + pair[1]
			_reaction_map[key] = reaction_id


func find_reaction(type_a: String, type_b: String) -> String:
	## 返回两种状态类型之间的反应 ID，无反应返回 ""
	var pair: Array = [type_a, type_b]
	pair.sort()
	return _reaction_map.get(pair[0] + "|" + pair[1], "")
