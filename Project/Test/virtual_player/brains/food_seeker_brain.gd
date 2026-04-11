extends "res://Test/virtual_player/brains/player_brain.gd"
## 寻食大脑
## BFS 寻路到最近食物，使用快照数据（信息边界）

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1),
]


func set_seed(seed_value: int) -> void:
	_rng.seed = seed_value


func decide(snapshot: Dictionary) -> Dictionary:
	var head: Vector2i = snapshot.get("snake_head_pos", Vector2i.ZERO)
	var current_dir: Vector2i = snapshot.get("snake_direction", Vector2i(1, 0))
	var body: Array = snapshot.get("snake_body", [])
	var foods: Array = snapshot.get("foods", [])
	var width: int = snapshot.get("grid_width", 40)
	var height: int = snapshot.get("grid_height", 22)

	if foods.is_empty():
		return _fallback_survival(snapshot)

	# 找最近食物
	var nearest_food: Vector2i = _find_nearest_food(head, foods)

	# BFS 寻路
	var first_step: Vector2i = _bfs_first_step(head, nearest_food, body, width, height, current_dir)
	if first_step == Vector2i.ZERO:
		return _fallback_survival(snapshot)

	return {"direction": first_step}


func _find_nearest_food(head: Vector2i, foods: Array) -> Vector2i:
	var best_pos: Vector2i = Vector2i.ZERO
	var best_dist: int = 999999
	for food_data: Dictionary in foods:
		var pos: Vector2i = food_data.get("pos", Vector2i.ZERO)
		var dist: int = abs(pos.x - head.x) + abs(pos.y - head.y)
		if dist < best_dist:
			best_dist = dist
			best_pos = pos
	return best_pos


func _bfs_first_step(start: Vector2i, target: Vector2i, body: Array,
		width: int, height: int, current_dir: Vector2i) -> Vector2i:
	# BFS on grid, body cells as obstacles
	var body_set: Dictionary = {}
	for pos in body:
		body_set[pos] = true

	var queue: Array[Dictionary] = []
	var visited: Dictionary = {start: true}

	# 只从非反转方向开始
	var reverse: Vector2i = -current_dir
	for dir in DIRECTIONS:
		if dir == reverse:
			continue
		var next_pos: Vector2i = start + dir
		if _can_enter(next_pos, body_set, width, height) and not visited.has(next_pos):
			visited[next_pos] = true
			queue.append({"pos": next_pos, "first_dir": dir})

	var idx: int = 0
	while idx < queue.size():
		var entry: Dictionary = queue[idx]
		idx += 1
		var pos: Vector2i = entry["pos"]
		var first_dir: Vector2i = entry["first_dir"]

		if pos == target:
			return first_dir

		for dir in DIRECTIONS:
			var next_pos: Vector2i = pos + dir
			if _can_enter(next_pos, body_set, width, height) and not visited.has(next_pos):
				visited[next_pos] = true
				queue.append({"pos": next_pos, "first_dir": first_dir})

	return Vector2i.ZERO  # 无法到达


func _can_enter(pos: Vector2i, body_set: Dictionary, width: int, height: int) -> bool:
	if pos.x < 0 or pos.x >= width or pos.y < 0 or pos.y >= height:
		return false
	return not body_set.has(pos)


func _fallback_survival(snapshot: Dictionary) -> Dictionary:
	var head: Vector2i = snapshot.get("snake_head_pos", Vector2i.ZERO)
	var current_dir: Vector2i = snapshot.get("snake_direction", Vector2i(1, 0))
	var body: Array = snapshot.get("snake_body", [])
	var width: int = snapshot.get("grid_width", 40)
	var height: int = snapshot.get("grid_height", 22)

	var reverse: Vector2i = -current_dir
	var safe: Array[Vector2i] = []
	for dir in DIRECTIONS:
		if dir == reverse:
			continue
		var next_pos: Vector2i = head + dir
		if _can_enter(next_pos, {}, width, height):
			var body_set: Dictionary = {}
			for pos in body:
				body_set[pos] = true
			if not body_set.has(next_pos):
				safe.append(dir)

	if safe.is_empty():
		return {"direction": Vector2i.ZERO}
	return {"direction": safe[_rng.randi() % safe.size()]}
