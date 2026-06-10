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
	# 注意：Object.get 只收 1 参（双参是 Dictionary API）——草稿的 get(prop, default)
	# 在任何敌人/状态格进入 cell_map 时即运行时报错、整个快照中断（spec 002 T034 实证修复）
	var enemies: Array[Dictionary] = []
	for cell_pos: Vector2i in GridWorld.cell_map:
		for entity in GridWorld.cell_map[cell_pos]:
			if entity is Node and entity.get("entity_type") == Constants.EntityType.ENEMY:
				enemies.append({
					"pos": cell_pos,
					"type": _get_node_prop(entity, "enemy_type", ""),
					"shape": _get_node_prop(entity, "enemy_shape", ""),
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
					"type": _get_node_prop(entity, "tile_type", ""),
				})
	snapshot["status_tiles"] = tiles

	return snapshot


## Node 属性带缺省读取（Object.get 无双参形式；属性缺失/为 null 时回退 default）
static func _get_node_prop(entity: Node, prop: String, default: Variant) -> Variant:
	if not (prop in entity):
		return default
	var value: Variant = entity.get(prop)
	return value if value != null else default
