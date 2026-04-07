class_name EnemyBrain
extends RefCounted

## 敌人 AI 行为基类
## 子类覆写 evaluate_* 方法定义具体行为
## decide() 按优先级依次调用，返回第一个命中的行动


func decide(enemy: Enemy, context: Dictionary) -> Dictionary:
	## 按优先级栈决策，返回 { action: String, direction: Vector2i }
	## action: "move" / "attack" / "idle"
	var result: Dictionary

	# P0: 攻击判定 — 攻击范围内有蛇身段？
	result = evaluate_attack(enemy, context)
	if not result.is_empty():
		return result

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


func evaluate_attack(enemy: Enemy, context: Dictionary) -> Dictionary:
	## P0: 攻击蛇身 — 检查 attack_range 内是否有蛇身段（非HEAD）
	var cfg: Dictionary = ConfigManager.get_enemy_type(enemy.enemy_type)
	if not cfg.get("can_attack", false):
		return {}
	if enemy.attack_cooldown_remaining > 0:
		return {}

	var attack_range: int = int(cfg.get("attack_range", 1))
	var target_seg = _find_attackable_segment(enemy, context, cfg, attack_range)
	if target_seg:
		return { "action": "attack", "target_segment": target_seg }
	return {}


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


func _find_attackable_segment(enemy: Enemy, context: Dictionary, cfg: Dictionary, attack_range: int):
	## 找攻击范围内的蛇身段（非HEAD），返回 SnakeSegment 或 null
	var segments: Array = context.get("snake_segments", [])
	var prefer_status: String = cfg.get("prefer_attack_status", "")
	var pos: Vector2i = enemy.grid_position

	# T31 幽灵鳞：计算免攻击尾段数
	var total_segs: int = segments.size()
	var phantom_count: int = 0
	if total_segs > 1:
		var snake_ref = segments[0].get_parent() if not segments.is_empty() and is_instance_valid(segments[0]) else null
		if snake_ref:
			phantom_count = int(StatusEffectManager.get_modifier("phantom_tail_count", snake_ref, 0.0))

	# 过滤：范围内 + 非HEAD + 非幽灵段
	var candidates: Array = []
	for seg in segments:
		if not is_instance_valid(seg):
			continue
		if seg.segment_type == SnakeSegment.HEAD:
			continue
		# 幽灵鳞：跳过最后 phantom_count 段
		if phantom_count > 0 and seg.segment_index >= total_segs - phantom_count:
			continue
		var dist: int = abs(seg.grid_position.x - pos.x) + abs(seg.grid_position.y - pos.y)
		if dist <= attack_range:
			candidates.append(seg)

	if candidates.is_empty():
		return null

	# 偏好状态排序
	if prefer_status != "":
		var preferred: Array = candidates.filter(func(s): return s.carried_status == prefer_status)
		if not preferred.is_empty():
			return preferred[randi() % preferred.size()]

	# 返回最近的
	candidates.sort_custom(func(a, b):
		var da: int = abs(a.grid_position.x - pos.x) + abs(a.grid_position.y - pos.y)
		var db: int = abs(b.grid_position.x - pos.x) + abs(b.grid_position.y - pos.y)
		return da < db
	)
	return candidates[0]


static func build_context(enemy: Enemy) -> Dictionary:
	## 构建 AI 决策上下文
	var ctx: Dictionary = {
		"enemy_pos": enemy.grid_position,
		"snake_head": Vector2i(-1, -1),
		"snake_body": [],
		"snake_segments": [],  # SnakeSegment 引用列表
	}

	# 遍历 GridWorld 找蛇段
	for pos in GridWorld.cell_map:
		var entities: Array = GridWorld.cell_map[pos]
		for e in entities:
			if not is_instance_valid(e):
				continue
			if e.get("entity_type") == Constants.EntityType.SNAKE_SEGMENT:
				if e.get("segment_type") == SnakeSegment.HEAD:
					ctx["snake_head"] = pos
				ctx["snake_body"].append(pos)
				ctx["snake_segments"].append(e)

	return ctx
