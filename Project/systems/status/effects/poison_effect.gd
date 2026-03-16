class_name PoisonEffect
extends RefCounted

## 中毒状态效果处理器
## 实体效果：食物增长量减半 + 3层毒化（立即扣长度并清毒）
## 空间效果：毒液格阻止食物生成（FoodManager 检查）
## 留痕：每 trail_interval 格留 1 格毒液（由 StatusTransferSystem 处理）


func process_entity_effects(_delta: float, effect_mgr: Node) -> void:
	## 检查是否有实体达到毒化层数
	var cfg_node = Engine.get_main_loop().root.get_node_or_null("ConfigManager")
	var cfg: Dictionary = {}
	if cfg_node:
		cfg = cfg_node.get_status_effect("poison")

	var toxify_at_layer: int = int(cfg.get("toxify_at_layer", 3))
	var toxify_length_penalty: int = int(cfg.get("toxify_length_penalty", 3))

	var targets_with_poison: Array = _get_targets_with_poison(effect_mgr)
	for entry in targets_with_poison:
		var target: Object = entry["target"]
		var effect: StatusEffectData = entry["effect"]
		if effect.layer >= toxify_at_layer:
			_trigger_toxify(target, toxify_length_penalty, effect_mgr)


func get_growth_modifier(effect_mgr: Node, target: Object) -> float:
	## 返回中毒时的增长系数（0.5），无中毒返回 1.0
	if effect_mgr == null or target == null:
		return 1.0
	if not effect_mgr.has_status(target, "poison"):
		return 1.0

	var cfg_node = Engine.get_main_loop().root.get_node_or_null("ConfigManager")
	var cfg: Dictionary = {}
	if cfg_node:
		cfg = cfg_node.get_status_effect("poison")
	return float(cfg.get("food_growth_modifier", 0.5))


func _trigger_toxify(target: Object, penalty: int, effect_mgr: Node) -> void:
	# 发射扣长度请求
	EventBus.length_decrease_requested.emit({
		"amount": penalty,
		"source": "poison_toxify",
	})
	# 清除毒层
	effect_mgr.remove_status(target, "poison", "toxify")


func _get_targets_with_poison(effect_mgr: Node) -> Array:
	var result: Array = []
	if not effect_mgr.has_method("has_status"):
		return result
	for target_id in effect_mgr._statuses:
		var target_effects: Dictionary = effect_mgr._statuses[target_id]
		if target_effects.has("poison"):
			var target: Object = effect_mgr._id_to_target.get(target_id)
			if is_instance_valid(target):
				result.append({
					"target": target,
					"effect": target_effects["poison"],
				})
	return result
