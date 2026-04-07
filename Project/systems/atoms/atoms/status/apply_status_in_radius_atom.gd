class_name ApplyStatusInRadiusAtom
extends AtomBase
## 对范围内随机 N 个敌人施加状态
## 参数: type (String), radius (int, default 3), count (int, default 1), source (String)


func execute(ctx: AtomContext) -> void:
	var status_type: String = get_param("type", "")
	var radius: int = get_param("radius", 3)
	var count: int = get_param("count", 1)
	var source: String = get_param("source", "resonance")
	if status_type.is_empty() or not ctx.effect_mgr or not ctx.enemy_mgr:
		return
	var center: Vector2i = ctx.source_position
	var candidates: Array = []
	for enemy in ctx.enemy_mgr.current_enemies:
		if not is_instance_valid(enemy) or enemy.get("grid_position") == null:
			continue
		var dist: int = abs(enemy.grid_position.x - center.x) + abs(enemy.grid_position.y - center.y)
		if dist <= radius:
			candidates.append(enemy)
	candidates.shuffle()
	var limit: int = mini(count, candidates.size())
	for i in range(limit):
		ctx.effect_mgr.apply_status(candidates[i], status_type, source)
