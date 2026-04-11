extends RefCounted
## 游戏感知层
## 只暴露玩家视觉可见的信息，严格遵守信息边界


static func take_snapshot(snake: Node) -> Dictionary:
	var snapshot: Dictionary = {}

	# 蛇状态（屏幕可见）
	snapshot["snake_head_pos"] = snake.body[0] if snake.body.size() > 0 else Vector2i.ZERO
	snapshot["snake_body"] = snake.body.duplicate()
	snapshot["snake_direction"] = snake.direction
	snapshot["snake_length"] = snake.segments.size()
	snapshot["snake_is_alive"] = snake.is_alive

	# 每段的可见状态颜色
	var statuses: Array[String] = []
	for seg in snake.segments:
		statuses.append(seg.carried_status if seg.carried_status else "")
	snapshot["segment_statuses"] = statuses

	# 网格尺寸
	snapshot["grid_width"] = Constants.GRID_WIDTH
	snapshot["grid_height"] = Constants.GRID_HEIGHT

	# Tick
	snapshot["current_tick"] = TickManager.current_tick

	# 敌人（屏幕可见：位置、类型、形状）
	var enemies: Array[Dictionary] = []
	for cell_pos: Vector2i in GridWorld.cell_map:
		for entity in GridWorld.cell_map[cell_pos]:
			if entity is Node and entity.get("entity_type") == Constants.EntityType.ENEMY:
				enemies.append({
					"pos": cell_pos,
					"type": entity.get("enemy_type", ""),
					"shape": entity.get("enemy_shape", ""),
				})
	snapshot["enemies"] = enemies

	# 食物（屏幕可见：位置）
	var foods: Array[Dictionary] = []
	for cell_pos: Vector2i in GridWorld.cell_map:
		for entity in GridWorld.cell_map[cell_pos]:
			if entity is Node and entity.get("entity_type") == Constants.EntityType.FOOD:
				foods.append({"pos": cell_pos})
	snapshot["foods"] = foods

	# 状态地砖（屏幕可见：位置、类型颜色）
	var tiles: Array[Dictionary] = []
	for cell_pos: Vector2i in GridWorld.cell_map:
		for entity in GridWorld.cell_map[cell_pos]:
			if entity is Node and entity.get("entity_type") == Constants.EntityType.STATUS_TILE:
				tiles.append({
					"pos": cell_pos,
					"type": entity.get("tile_type", ""),
				})
	snapshot["status_tiles"] = tiles

	return snapshot
