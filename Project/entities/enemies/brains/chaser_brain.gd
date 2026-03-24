class_name ChaserBrain
extends EnemyBrain

## 追踪者 AI
## 向蛇头追踪，回避状态格，进入威胁范围时加速
## 优先级：自保 > 威胁加速 > 状态回避 > 追踪 > 随机


func evaluate_self_preservation(enemy: Enemy, context: Dictionary) -> Dictionary:
	## P1: 当前格有状态格 → 逃离
	var tile_mgr := _get_tile_manager()
	if tile_mgr == null:
		return {}
	var pos: Vector2i = enemy.grid_position
	var tiles: Array = tile_mgr.get_tiles_at(pos)
	if tiles.is_empty():
		return {}
	# 逃离：选离状态格最远的方向
	var dir := Pathfinding.get_direction_away(pos, pos)
	# 更好的策略：找一个没有状态格的相邻格
	var valid := Pathfinding.get_valid_moves(pos)
	for d in valid:
		var target: Vector2i = pos + d
		if tile_mgr.get_tiles_at(target).is_empty():
			return { "action": "move", "direction": d }
	# 所有方向都有状态格，随便走
	if not valid.is_empty():
		return { "action": "move", "direction": valid[randi() % valid.size()] }
	return {}


func evaluate_threat_response(enemy: Enemy, context: Dictionary) -> Dictionary:
	## P2: 蛇头在 threat_range 内 → 标记加速（实际加速在 Enemy._on_tick 处理）
	var snake_head: Vector2i = context.get("snake_head", Vector2i(-1, -1))
	if snake_head == Vector2i(-1, -1):
		return {}

	var cfg := _get_config()
	var threat_range: int = int(cfg.get("threat_range", 3))
	var dist: int = Pathfinding.manhattan_distance(enemy.grid_position, snake_head)

	if dist <= threat_range:
		# 返回追踪方向 + 标记威胁激活
		var dir := _get_tracking_direction(enemy.grid_position, snake_head)
		if dir != Vector2i.ZERO:
			return { "action": "move", "direction": dir, "threat_active": true }
	return {}


func evaluate_status_response(enemy: Enemy, _context: Dictionary) -> Dictionary:
	## P3: 回避状态格 — 如果追踪方向有状态格，选择绕行
	# 此优先级在 evaluate_tracking 中集成处理
	return {}


func evaluate_tracking(enemy: Enemy, context: Dictionary) -> Dictionary:
	## P4: 向最近蛇身段追踪（优先身体而非头）
	var target := _find_nearest_body_target(enemy, context)
	if target == Vector2i(-1, -1):
		# 退回到追踪蛇头
		var snake_head: Vector2i = context.get("snake_head", Vector2i(-1, -1))
		if snake_head == Vector2i(-1, -1):
			return {}
		target = snake_head

	var dir := _get_tracking_direction(enemy.grid_position, target)
	if dir != Vector2i.ZERO:
		return { "action": "move", "direction": dir }
	return {}


func _find_nearest_body_target(enemy: Enemy, context: Dictionary) -> Vector2i:
	## 找到最近的蛇身段（非HEAD）的相邻空格作为追踪目标
	var segments: Array = context.get("snake_segments", [])
	var pos: Vector2i = enemy.grid_position
	var best_target := Vector2i(-1, -1)
	var best_dist: int = 9999

	for seg in segments:
		if not is_instance_valid(seg):
			continue
		if seg.segment_type == SnakeSegment.HEAD:
			continue
		# 找这个段的相邻空格（敌人可以站的位置）
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var adj: Vector2i = seg.grid_position + d
			if not GridWorld.is_within_bounds(adj):
				continue
			if GridWorld.is_cell_blocked(adj):
				continue
			var dist: int = abs(adj.x - pos.x) + abs(adj.y - pos.y)
			if dist < best_dist:
				best_dist = dist
				best_target = adj

	return best_target


func evaluate_default(enemy: Enemy, _context: Dictionary) -> Dictionary:
	## P5: 随机移动（被堵住时）
	var valid := Pathfinding.get_valid_moves(enemy.grid_position)
	if valid.is_empty():
		return { "action": "idle", "direction": Vector2i.ZERO }
	return { "action": "move", "direction": valid[randi() % valid.size()] }


func _get_tracking_direction(from: Vector2i, to: Vector2i) -> Vector2i:
	## 向目标追踪，优先选择无状态格的方向
	var tile_mgr := _get_tile_manager()
	var valid := Pathfinding.get_valid_moves(from)
	if valid.is_empty():
		return Vector2i.ZERO

	# 按距离目标近排序
	valid.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Pathfinding.manhattan_distance(from + a, to) < Pathfinding.manhattan_distance(from + b, to)
	)

	# 优先选无状态格的方向
	if tile_mgr:
		for dir in valid:
			var target: Vector2i = from + dir
			if tile_mgr.get_tiles_at(target).is_empty():
				return dir

	# 如果所有方向都有状态格，退回到最近方向
	return valid[0]


func _get_tile_manager() -> StatusTileManager:
	return StatusEffectManager.tile_manager


func _get_config() -> Dictionary:
	return ConfigManager.get_enemy_type("chaser")
