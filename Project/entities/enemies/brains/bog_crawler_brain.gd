class_name BogCrawlerBrain
extends EnemyBrain

## 毒沼匍匐者 AI
## 趋向毒液格移动，在毒液格上加速，火焰格自保
## 优先级：自保(火焰格) > 趋向毒液格 > 随机移动


func evaluate_self_preservation(enemy: Enemy, _context: Dictionary) -> Dictionary:
	## P1: 当前格有火焰格 → 移离（火+毒触发毒爆对自己不利）
	var tile_mgr := _get_tile_manager()
	if tile_mgr == null:
		return {}
	var pos: Vector2i = enemy.grid_position
	if not tile_mgr.has_tile(pos, "fire"):
		return {}
	# 逃离火焰格：找一个没有火焰的相邻格
	var valid := Pathfinding.get_valid_moves(pos)
	for d in valid:
		var target: Vector2i = pos + d
		if not tile_mgr.has_tile(target, "fire"):
			return { "action": "move", "direction": d }
	# 所有方向都有火焰，随便走
	if not valid.is_empty():
		return { "action": "move", "direction": valid[randi() % valid.size()] }
	return {}


func evaluate_status_response(enemy: Enemy, _context: Dictionary) -> Dictionary:
	## P3: 趋向最近的毒液格
	var tile_mgr := _get_tile_manager()
	if tile_mgr == null:
		return {}
	var pos: Vector2i = enemy.grid_position
	var nearest_poison: Vector2i = Pathfinding.get_nearest_tile_of_type(pos, "poison", tile_mgr)
	if nearest_poison == Vector2i(-1, -1):
		return {}
	if nearest_poison == pos:
		# 已在毒液格上，不需要趋向
		return {}
	var dir := Pathfinding.get_direction_towards(pos, nearest_poison)
	if dir != Vector2i.ZERO:
		return { "action": "move", "direction": dir }
	return {}


func evaluate_default(enemy: Enemy, _context: Dictionary) -> Dictionary:
	## P5: 随机移动
	var valid := Pathfinding.get_valid_moves(enemy.grid_position)
	if valid.is_empty():
		return { "action": "idle", "direction": Vector2i.ZERO }
	return { "action": "move", "direction": valid[randi() % valid.size()] }


func _get_tile_manager() -> StatusTileManager:
	return StatusEffectManager.tile_manager
