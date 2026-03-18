class_name SpawnEntityAtom
extends AtomBase
## Spawns an entity (enemy or food) via the appropriate manager.
## Params: entity_type (String: "enemy"/"food"), enemy_type (String, optional).


func execute(ctx: AtomContext) -> void:
	var entity_type: String = get_param("entity_type", "enemy")
	var ml = Engine.get_main_loop()
	var root = ml.root if ml else null
	if not root:
		return

	if entity_type == "enemy":
		var mgr = root.get_node_or_null("Main/EnemyManager")
		if mgr and mgr.has_method("spawn_enemy"):
			var enemy_type: String = get_param("enemy_type", "basic")
			mgr.spawn_enemy(enemy_type)
		else:
			push_warning("SpawnEntityAtom: EnemyManager not found in scene tree.")
	elif entity_type == "food":
		var mgr = root.get_node_or_null("Main/FoodManager")
		if mgr and mgr.has_method("spawn_food"):
			mgr.spawn_food()
		else:
			push_warning("SpawnEntityAtom: FoodManager not found in scene tree.")
