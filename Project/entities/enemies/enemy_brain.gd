class_name EnemyBrain
extends RefCounted

## 敌人 AI 行为基类
## 子类覆写 evaluate_* 方法定义具体行为
## decide() 按优先级依次调用，返回第一个命中的行动


func decide(enemy: Enemy, context: Dictionary) -> Dictionary:
	## 按优先级栈决策，返回 { action: String, direction: Vector2i }
	## action: "move" / "attack" / "idle"
	var result: Dictionary

	# P1: 自我保护 — 当前格是危险状态格？
	result = evaluate_self_preservation(enemy, context)
	if not result.is_empty():
		return result

	# P2: 威胁响应 — 蛇头在攻击范围内？
	result = evaluate_threat_response(enemy, context)
	if not result.is_empty():
		return result

	# P3: 状态响应 — 战场上有状态格？
	result = evaluate_status_response(enemy, context)
	if not result.is_empty():
		return result

	# P4: 目标追踪
	result = evaluate_tracking(enemy, context)
	if not result.is_empty():
		return result

	# P5: 默认行为
	result = evaluate_default(enemy, context)
	if not result.is_empty():
		return result

	return { "action": "idle", "direction": Vector2i.ZERO }


func evaluate_self_preservation(_enemy: Enemy, _context: Dictionary) -> Dictionary:
	## P1: 自我保护 — 子类覆写
	return {}


func evaluate_threat_response(_enemy: Enemy, _context: Dictionary) -> Dictionary:
	## P2: 威胁响应 — 子类覆写
	return {}


func evaluate_status_response(_enemy: Enemy, _context: Dictionary) -> Dictionary:
	## P3: 状态响应 — 子类覆写
	return {}


func evaluate_tracking(_enemy: Enemy, _context: Dictionary) -> Dictionary:
	## P4: 目标追踪 — 子类覆写
	return {}


func evaluate_default(_enemy: Enemy, _context: Dictionary) -> Dictionary:
	## P5: 默认行为 — 基类默认不移动
	return { "action": "idle", "direction": Vector2i.ZERO }


static func build_context(enemy: Enemy) -> Dictionary:
	## 构建 AI 决策上下文
	var ctx: Dictionary = {
		"enemy_pos": enemy.grid_position,
		"snake_head": Vector2i(-1, -1),
		"snake_body": [],
	}

	# 找蛇位置
	var game_world = enemy.get_parent()
	if game_world:
		game_world = game_world.get_parent()  # EnemyContainer → EntityContainer → GameWorld
		if game_world:
			game_world = game_world.get_parent()
	# 备用：遍历 GridWorld 找蛇头
	for pos in GridWorld.cell_map:
		var entities: Array = GridWorld.cell_map[pos]
		for e in entities:
			if e.get("entity_type") == Constants.EntityType.SNAKE_SEGMENT:
				if e.get("segment_type") == SnakeSegment.HEAD:
					ctx["snake_head"] = pos
				ctx["snake_body"].append(pos)

	return ctx
