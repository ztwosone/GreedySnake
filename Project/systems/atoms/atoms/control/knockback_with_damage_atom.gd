class_name KnockbackWithDamageAtom
extends AtomBase
## 击退攻击者，路径上其他敌人受伤害（荆棘鳞 L3）
## 参数: distance (int, default 2), path_damage (int, default 1)


func execute(ctx: AtomContext) -> void:
	var distance: int = get_param("distance", 2)
	var path_damage: int = get_param("path_damage", 1)
	var enemy = ctx.params.get("enemy", null)
	if not enemy or not is_instance_valid(enemy):
		return
	if enemy.get("grid_position") == null:
		return

	var seg = ctx.params.get("segment", null)
	var origin: Vector2i = seg.grid_position if seg and is_instance_valid(seg) else ctx.source_position
	var enemy_pos: Vector2i = enemy.grid_position
	var diff: Vector2i = enemy_pos - origin
	var dir := Vector2i(signi(diff.x), signi(diff.y))
	if dir == Vector2i.ZERO:
		return

	var new_pos: Vector2i = enemy_pos
	for i in range(distance):
		var candidate: Vector2i = new_pos + dir
		if not GridWorld.is_within_bounds(candidate):
			break
		if GridWorld.is_cell_blocked(candidate):
			break
		# 路径上的其他敌人受伤
		if path_damage > 0:
			var entities: Array = GridWorld.get_entities_at(candidate)
			for e in entities:
				if e != enemy and is_instance_valid(e) and e.has_method("take_damage"):
					e.take_damage(path_damage)
		new_pos = candidate

	if new_pos != enemy_pos:
		GridWorld.remove_entity(enemy)
		enemy.grid_position = new_pos
		GridWorld.place_entity(enemy, new_pos)
