class_name KnockbackAttackerAtom
extends AtomBase
## 击退攻击者（远离被攻击的蛇段）
## 参数: distance (int, default 2)
## 从 ctx.params["enemy"] 获取攻击者，从 ctx.params["segment"] 获取被攻击段


func execute(ctx: AtomContext) -> void:
	var distance: int = get_param("distance", 2)
	var enemy = ctx.params.get("enemy", null)
	if not enemy or not is_instance_valid(enemy):
		return
	if enemy.get("grid_position") == null:
		return

	# 计算击退方向：从被攻击段 → 攻击者方向
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
		new_pos = candidate

	if new_pos != enemy_pos:
		GridWorld.remove_entity(enemy)
		enemy.grid_position = new_pos
		GridWorld.place_entity(enemy, new_pos)
