class_name IceWaveAtom
extends AtomBase
## 对攻击者周围敌人施加冰状态（冰霜鳞 L3）
## 参数: radius (int, default 1)
## 从 ctx.params["enemy"] 获取攻击者位置


func execute(ctx: AtomContext) -> void:
	var radius: int = get_param("radius", 1)
	var enemy = ctx.params.get("enemy", null)
	if not enemy or not is_instance_valid(enemy):
		return
	if enemy.get("grid_position") == null:
		return
	if not ctx.effect_mgr or not ctx.enemy_mgr:
		return

	var center: Vector2i = enemy.grid_position
	for other_enemy in ctx.enemy_mgr.current_enemies:
		if not is_instance_valid(other_enemy) or other_enemy == enemy:
			continue
		if other_enemy.get("grid_position") == null:
			continue
		var dist: int = abs(other_enemy.grid_position.x - center.x) + abs(other_enemy.grid_position.y - center.y)
		if dist <= radius:
			ctx.effect_mgr.apply_status(other_enemy, "ice", "ice_wave")
