extends AtomBase
## 对范围内敌人造成伤害（Hydra III 回声咬）
## 参数: amount (int, default 1), radius (int, default 1)


func execute(ctx: AtomContext) -> void:
	var amount: int = get_param("amount", 1)
	var radius: int = get_param("radius", 1)
	if amount <= 0 or radius <= 0:
		return
	if not ctx.enemy_mgr:
		return

	var center: Vector2i = ctx.source_position
	var killed_enemy = ctx.params.get("enemy_def")  # 已死的敌人，排除

	var enemies: Array = ctx.enemy_mgr.current_enemies.duplicate()
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy == killed_enemy:
			continue
		if enemy.get("grid_position") == null:
			continue
		var dist: int = abs(enemy.grid_position.x - center.x) + abs(enemy.grid_position.y - center.y)
		if dist <= radius and enemy.has_method("take_damage"):
			enemy.take_damage(amount)
