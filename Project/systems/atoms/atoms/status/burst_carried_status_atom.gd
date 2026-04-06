extends AtomBase
## 向范围内敌人释放蛇头携带状态（白蛇 III 到期爆发）
## 参数: radius (int, default 1)


func execute(ctx: AtomContext) -> void:
	var radius: int = get_param("radius", 1)
	if radius <= 0:
		return
	if not ctx.enemy_mgr or not ctx.effect_mgr:
		return

	# 获取蛇头段的携带状态
	var source = ctx.source
	if not is_instance_valid(source):
		return

	var statuses: Array = []
	# Snake 实例 → 用 segments[0]（蛇头段）
	if source.get("segments") != null and source.segments.size() > 0:
		var head_seg = source.segments[0]
		if head_seg.has_method("get_statuses"):
			statuses = head_seg.get_statuses()
	elif source.has_method("get_statuses"):
		statuses = source.get_statuses()

	if statuses.is_empty():
		return

	var center: Vector2i = ctx.source_position
	var enemies: Array = ctx.enemy_mgr.current_enemies.duplicate()
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.get("grid_position") == null:
			continue
		var dist: int = abs(enemy.grid_position.x - center.x) + abs(enemy.grid_position.y - center.y)
		if dist <= radius:
			for status_type in statuses:
				ctx.effect_mgr.apply_status(enemy, status_type, "burst")
