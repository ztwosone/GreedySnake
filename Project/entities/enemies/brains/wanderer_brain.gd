class_name WandererBrain
extends EnemyBrain

## 游荡者 AI
## 随机移动，碰壁反弹，完全无视状态格
## 70% 概率保持上一次方向，30% 随机切换

var _last_direction: Vector2i = Vector2i.ZERO


func evaluate_default(enemy: Enemy, _context: Dictionary) -> Dictionary:
	var valid_moves: Array[Vector2i] = Pathfinding.get_valid_moves(enemy.grid_position)
	if valid_moves.is_empty():
		return { "action": "idle", "direction": Vector2i.ZERO }

	var chosen_dir: Vector2i

	# 70% 概率保持上一次方向（如果仍然合法）
	if _last_direction != Vector2i.ZERO and valid_moves.has(_last_direction) and randf() < 0.7:
		chosen_dir = _last_direction
	else:
		chosen_dir = valid_moves[randi() % valid_moves.size()]

	_last_direction = chosen_dir
	return { "action": "move", "direction": chosen_dir }
