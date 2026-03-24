class_name SpawnEntityAtom
extends AtomBase
## Spawns an entity (enemy or food) via the appropriate manager.
## Params: entity_type (String: "enemy"/"food"), enemy_type (String, optional).


func execute(ctx: AtomContext) -> void:
	var entity_type: String = get_param("entity_type", "enemy")

	if entity_type == "enemy":
		if ctx.enemy_mgr and ctx.enemy_mgr.has_method("spawn_enemy"):
			var enemy_type: String = get_param("enemy_type", "basic")
			ctx.enemy_mgr.spawn_enemy(enemy_type)
		else:
			push_warning("SpawnEntityAtom: enemy_mgr not available in context.")
	elif entity_type == "food":
		if ctx.food_mgr and ctx.food_mgr.has_method("spawn_food"):
			ctx.food_mgr.spawn_food()
		else:
			push_warning("SpawnEntityAtom: food_mgr not available in context.")
