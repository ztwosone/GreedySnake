class_name ToxicExplosionReaction
extends RefCounted

## 毒爆反应（火+毒）
## 消耗两种状态，造成伤害 + 范围内附加灼烧和中毒


func execute(context: Dictionary) -> void:
	var pos: Vector2i = context["position"]
	var layer_a: int = context["layer_a"]
	var layer_b: int = context["layer_b"]
	var reaction_cfg: Dictionary = context["reaction_cfg"]

	var damage_coefficient: float = float(reaction_cfg.get("damage_coefficient", 1.0))
	var radius: int = int(reaction_cfg.get("radius", 3))
	var apply_burn_layers: int = int(reaction_cfg.get("apply_burn_layers", 2))
	var apply_poison_layers: int = int(reaction_cfg.get("apply_poison_layers", 1))

	var damage: int = int(ceil(float(layer_a + layer_b) * damage_coefficient))
	if damage < 1:
		damage = 1

	# 伤害
	EventBus.length_decrease_requested.emit({
		"amount": damage,
		"source": "reaction_toxic_explosion",
	})

	# 范围内实体附加灼烧和中毒
	var effect_mgr = Engine.get_main_loop().root.get_node_or_null("StatusEffectManager")
	if effect_mgr:
		var entities: Array = _get_entities_in_radius(pos, radius)
		for entity in entities:
			if entity is Node:
				for i in range(apply_burn_layers):
					effect_mgr.apply_status(entity, "fire", "reaction_toxic_explosion")
				for i in range(apply_poison_layers):
					effect_mgr.apply_status(entity, "poison", "reaction_toxic_explosion")

	EventBus.reaction_triggered.emit({
		"reaction_id": "toxic_explosion",
		"position": pos,
		"type_a": "fire",
		"type_b": "poison",
		"layer_a": layer_a,
		"layer_b": layer_b,
		"damage": damage,
	})


func _get_entities_in_radius(center: Vector2i, radius: int) -> Array:
	var result: Array = []
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var check_pos := Vector2i(center.x + dx, center.y + dy)
			if not GridWorld.is_within_bounds(check_pos):
				continue
			var entities: Array = GridWorld.get_entities_at(check_pos)
			for e in entities:
				if not result.has(e):
					result.append(e)
	return result
