extends "res://Test/virtual_player/brains/player_brain.gd"
## 生存大脑
## 避开墙壁和自身碰撞，选择安全方向

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),   # RIGHT
	Vector2i(-1, 0),  # LEFT
	Vector2i(0, -1),  # UP
	Vector2i(0, 1),   # DOWN
]


func set_seed(seed_value: int) -> void:
	_rng.seed = seed_value


func decide(snapshot: Dictionary) -> Dictionary:
	var head: Vector2i = snapshot.get("snake_head_pos", Vector2i.ZERO)
	var current_dir: Vector2i = snapshot.get("snake_direction", Vector2i(1, 0))
	var body: Array = snapshot.get("snake_body", [])
	var width: int = snapshot.get("grid_width", 40)
	var height: int = snapshot.get("grid_height", 22)

	var candidates: Array[Vector2i] = _get_non_reversal_directions(current_dir)
	var safe: Array[Vector2i] = []
	for dir in candidates:
		var next_pos: Vector2i = head + dir
		if _is_safe(next_pos, body, width, height):
			safe.append(dir)

	if safe.is_empty():
		return {"direction": Vector2i.ZERO}

	return {"direction": safe[_rng.randi() % safe.size()]}


func _get_non_reversal_directions(current_dir: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var reverse: Vector2i = -current_dir
	for dir in DIRECTIONS:
		if dir != reverse:
			result.append(dir)
	return result


func _is_safe(pos: Vector2i, body: Array, width: int, height: int) -> bool:
	# 边界检查
	if pos.x < 0 or pos.x >= width or pos.y < 0 or pos.y >= height:
		return false
	# 自身碰撞检查（排除尾部——保守策略，全部检查）
	for segment_pos in body:
		if pos == segment_pos:
			return false
	return true
