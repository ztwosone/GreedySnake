class_name Pathfinding
extends RefCounted

## 寻路辅助工具
## L1 阶段使用 Manhattan 距离 + 简单方向选择，接口预留 A* 扩展


static func manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


static func get_valid_moves(pos: Vector2i) -> Array[Vector2i]:
	## 返回从 pos 出发的合法移动方向（不越界、不被阻挡）
	var result: Array[Vector2i] = []
	var directions: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1),
	]
	for dir in directions:
		var target: Vector2i = pos + dir
		if GridWorld.is_within_bounds(target) and not GridWorld.is_cell_blocked(target) and not _is_occupied_for_enemy(target):
			result.append(dir)
	return result


static func _is_occupied_for_enemy(pos: Vector2i) -> bool:
	## 检查目标格是否有敌人或食物（敌人不应与这些实体重叠）
	var entities: Array = GridWorld.get_entities_at(pos)
	for e in entities:
		if e is Enemy or e is Food:
			return true
	return false


static func get_direction_towards(from: Vector2i, to: Vector2i) -> Vector2i:
	## 向目标的最优方向（Manhattan 贪心，选离目标最近的合法方向）
	var valid_moves: Array[Vector2i] = get_valid_moves(from)
	if valid_moves.is_empty():
		return Vector2i.ZERO

	var best_dir: Vector2i = valid_moves[0]
	var best_dist: int = manhattan_distance(from + best_dir, to)
	for dir in valid_moves:
		var dist: int = manhattan_distance(from + dir, to)
		if dist < best_dist:
			best_dist = dist
			best_dir = dir
	return best_dir


static func get_direction_away(from: Vector2i, threat: Vector2i) -> Vector2i:
	## 远离威胁的方向（选离威胁最远的合法方向）
	var valid_moves: Array[Vector2i] = get_valid_moves(from)
	if valid_moves.is_empty():
		return Vector2i.ZERO

	var best_dir: Vector2i = valid_moves[0]
	var best_dist: int = manhattan_distance(from + best_dir, threat)
	for dir in valid_moves:
		var dist: int = manhattan_distance(from + dir, threat)
		if dist > best_dist:
			best_dist = dist
			best_dir = dir
	return best_dir


static func get_nearest_tile_of_type(pos: Vector2i, type: String, tile_mgr: StatusTileManager) -> Vector2i:
	## 找到最近的指定类型状态格，找不到返回 Vector2i(-1, -1)
	if tile_mgr == null:
		return Vector2i(-1, -1)

	var best_pos := Vector2i(-1, -1)
	var best_dist: int = 999999
	for tile_pos in tile_mgr._tiles:
		if tile_mgr._tiles[tile_pos].has(type):
			var dist: int = manhattan_distance(pos, tile_pos)
			if dist < best_dist:
				best_dist = dist
				best_pos = tile_pos
	return best_pos
