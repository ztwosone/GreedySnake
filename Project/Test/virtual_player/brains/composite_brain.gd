extends "res://Test/virtual_player/brains/player_brain.gd"
## 组合大脑
## 优先级堆叠：危险回避 > 食物寻路 > 生存兜底

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _food_brain: RefCounted = preload("res://Test/virtual_player/brains/food_seeker_brain.gd").new()
var _survival_brain: RefCounted = preload("res://Test/virtual_player/brains/survival_brain.gd").new()

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1),
]


func set_seed(seed_value: int) -> void:
	_rng.seed = seed_value
	_food_brain.set_seed(seed_value + 1)
	_survival_brain.set_seed(seed_value + 2)


func decide(snapshot: Dictionary) -> Dictionary:
	# 优先级 1：危险回避（敌人在邻格）
	var danger_dir: Vector2i = _evaluate_danger(snapshot)
	if danger_dir != Vector2i.ZERO:
		return {"direction": danger_dir}

	# 优先级 2：食物寻路
	var foods: Array = snapshot.get("foods", [])
	if not foods.is_empty():
		var food_result: Dictionary = _food_brain.decide(snapshot)
		if food_result.get("direction", Vector2i.ZERO) != Vector2i.ZERO:
			return food_result

	# 优先级 3：生存兜底
	return _survival_brain.decide(snapshot)


func _evaluate_danger(snapshot: Dictionary) -> Vector2i:
	var head: Vector2i = snapshot.get("snake_head_pos", Vector2i.ZERO)
	var current_dir: Vector2i = snapshot.get("snake_direction", Vector2i(1, 0))
	var body: Array = snapshot.get("snake_body", [])
	var enemies: Array = snapshot.get("enemies", [])
	var width: int = snapshot.get("grid_width", 40)
	var height: int = snapshot.get("grid_height", 22)

	if enemies.is_empty():
		return Vector2i.ZERO

	# 检查邻格是否有敌人
	var enemy_positions: Dictionary = {}
	for enemy_data: Dictionary in enemies:
		enemy_positions[enemy_data.get("pos", Vector2i(-1, -1))] = true

	var has_adjacent_enemy: bool = false
	for dir in DIRECTIONS:
		if enemy_positions.has(head + dir):
			has_adjacent_enemy = true
			break

	if not has_adjacent_enemy:
		return Vector2i.ZERO

	# 找到远离敌人的安全方向
	var reverse: Vector2i = -current_dir
	var body_set: Dictionary = {}
	for pos in body:
		body_set[pos] = true

	var best_dir: Vector2i = Vector2i.ZERO
	var best_score: int = -999

	for dir in DIRECTIONS:
		if dir == reverse:
			continue
		var next_pos: Vector2i = head + dir
		# 安全检查
		if next_pos.x < 0 or next_pos.x >= width or next_pos.y < 0 or next_pos.y >= height:
			continue
		if body_set.has(next_pos):
			continue
		if enemy_positions.has(next_pos):
			continue

		# 评分：离所有敌人越远越好
		var score: int = 0
		for enemy_data: Dictionary in enemies:
			var epos: Vector2i = enemy_data.get("pos", Vector2i.ZERO)
			score += abs(next_pos.x - epos.x) + abs(next_pos.y - epos.y)

		if score > best_score:
			best_score = score
			best_dir = dir

	return best_dir
