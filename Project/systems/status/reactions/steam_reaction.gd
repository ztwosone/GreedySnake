class_name SteamReaction
extends RefCounted

## 蒸腾反应（火+冰）
## 消耗两种状态，对范围内实体造成 (layerA + layerB) * damage_coefficient 伤害


func execute(context: Dictionary) -> void:
	var pos: Vector2i = context["position"]
	var layer_a: int = context["layer_a"]
	var layer_b: int = context["layer_b"]
	var reaction_cfg: Dictionary = context["reaction_cfg"]

	var damage_coefficient: float = float(reaction_cfg.get("damage_coefficient", 0.5))
	var radius: int = int(reaction_cfg.get("radius", 3))

	var damage: int = int(ceil(float(layer_a + layer_b) * damage_coefficient))
	if damage < 1:
		damage = 1

	# 对范围内实体造成伤害
	var entities: Array = _get_entities_in_radius(pos, radius)
	if entities.size() > 0 or true:
		EventBus.length_decrease_requested.emit({
			"amount": damage,
			"source": "reaction_steam",
		})

	EventBus.reaction_triggered.emit({
		"reaction_id": "steam",
		"position": pos,
		"type_a": "fire",
		"type_b": "ice",
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
