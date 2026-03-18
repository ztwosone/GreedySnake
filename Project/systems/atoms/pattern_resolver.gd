class_name PatternResolver
extends RefCounted
## 范围模式解析器
## 根据 pattern 字符串和上下文，解析出目标位置列表。


## 解析 pattern → 位置数组
static func resolve(pattern: String, ctx: AtomContext, params: Dictionary = {}) -> Array:
	match pattern:
		"self":
			return _resolve_self(ctx)
		"target":
			return _resolve_target(ctx)
		"radius":
			return _resolve_radius(ctx, params)
		"neighbors":
			return _resolve_neighbors(ctx, params)
		"trail":
			return _resolve_trail(ctx)
		"body_segment":
			return _resolve_body_segment(ctx, params)
		"line":
			return _resolve_line(ctx, params)
		"cross":
			return _resolve_cross(ctx, params)
		"ring":
			return _resolve_ring(ctx, params)
		"random_n":
			return _resolve_random_n(ctx, params)
		"cone":
			return _resolve_cone(ctx, params)
		_:
			push_warning("PatternResolver: unknown pattern '%s'" % pattern)
			return [ctx.source_position]


# === 具体模式实现 ===

static func _resolve_self(ctx: AtomContext) -> Array:
	return [ctx.source_position]


static func _resolve_target(ctx: AtomContext) -> Array:
	return [ctx.target_position]


static func _resolve_radius(ctx: AtomContext, params: Dictionary) -> Array:
	var center: Vector2i = params.get("center", ctx.source_position)
	if center is not Vector2i:
		center = ctx.source_position
	var r: int = int(params.get("radius", 1))
	var use_chebyshev: bool = params.get("chebyshev", false)
	var positions: Array = []

	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			var pos := Vector2i(center.x + dx, center.y + dy)
			if use_chebyshev:
				if max(abs(dx), abs(dy)) <= r:
					if _is_valid_pos(pos):
						positions.append(pos)
			else:
				if abs(dx) + abs(dy) <= r:
					if _is_valid_pos(pos):
						positions.append(pos)
	return positions


static func _resolve_neighbors(ctx: AtomContext, params: Dictionary) -> Array:
	var center: Vector2i = params.get("center", ctx.source_position)
	if center is not Vector2i:
		center = ctx.source_position
	var positions: Array = []
	var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for d in dirs:
		var pos := center + d
		if _is_valid_pos(pos):
			positions.append(pos)
	return positions


static func _resolve_trail(ctx: AtomContext) -> Array:
	# trail 模式：返回移动事件中的 vacated_pos
	var vacated = ctx.params.get("vacated_pos", null)
	if vacated is Vector2i:
		return [vacated]
	return []


static func _resolve_body_segment(ctx: AtomContext, params: Dictionary) -> Array:
	var snake = ctx.source if ctx.source and ctx.source.get("body") != null else ctx.target
	if snake == null or snake.get("body") == null:
		return []

	var body: Array = snake.body
	var segment: String = params.get("segment", "all")

	match segment:
		"all":
			return body.duplicate()
		"front":
			var count: int = int(params.get("count", 1))
			return body.slice(0, mini(count, body.size()))
		"back":
			var count: int = int(params.get("count", 1))
			return body.slice(maxi(0, body.size() - count))
		"head":
			return [body[0]] if body.size() > 0 else []
		"tail":
			return [body[body.size() - 1]] if body.size() > 0 else []
		_:
			return body.duplicate()


static func _resolve_line(ctx: AtomContext, params: Dictionary) -> Array:
	var start: Vector2i = params.get("start", ctx.source_position)
	if start is not Vector2i:
		start = ctx.source_position
	var dir: Vector2i = params.get("direction", ctx.direction)
	if dir is not Vector2i or dir == Vector2i.ZERO:
		return [start]
	var length: int = int(params.get("length", 3))
	var positions: Array = []
	for i in range(1, length + 1):
		var pos := start + dir * i
		if _is_valid_pos(pos):
			positions.append(pos)
		else:
			break  # 碰到边界停止
	return positions


static func _resolve_cross(ctx: AtomContext, params: Dictionary) -> Array:
	var center: Vector2i = params.get("center", ctx.source_position)
	if center is not Vector2i:
		center = ctx.source_position
	var length: int = int(params.get("length", 3))
	var positions: Array = []
	var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for d in dirs:
		for i in range(1, length + 1):
			var pos := center + d * i
			if _is_valid_pos(pos):
				positions.append(pos)
			else:
				break
	return positions


static func _resolve_ring(ctx: AtomContext, params: Dictionary) -> Array:
	var center: Vector2i = params.get("center", ctx.source_position)
	if center is not Vector2i:
		center = ctx.source_position
	var r: int = int(params.get("radius", 2))
	var positions: Array = []
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			if abs(dx) + abs(dy) == r:
				var pos := Vector2i(center.x + dx, center.y + dy)
				if _is_valid_pos(pos):
					positions.append(pos)
	return positions


static func _resolve_random_n(ctx: AtomContext, params: Dictionary) -> Array:
	var count: int = int(params.get("count", 1))
	# 先取 radius 范围内的全部位置
	var all_positions := _resolve_radius(ctx, params)
	if all_positions.size() <= count:
		return all_positions
	# 随机选 N 个（Fisher-Yates 部分洗牌）
	var result: Array = []
	var pool := all_positions.duplicate()
	for i in range(mini(count, pool.size())):
		var idx: int = randi() % pool.size()
		result.append(pool[idx])
		pool.remove_at(idx)
	return result


static func _resolve_cone(ctx: AtomContext, params: Dictionary) -> Array:
	var center: Vector2i = params.get("center", ctx.source_position)
	if center is not Vector2i:
		center = ctx.source_position
	var dir: Vector2i = params.get("direction", ctx.direction)
	if dir is not Vector2i or dir == Vector2i.ZERO:
		return []
	var length: int = int(params.get("length", 3))
	var positions: Array = []

	# 扇形：沿主方向展开，每步宽度 +1
	# 确定垂直于主方向的横向
	var lateral: Vector2i
	if dir.x != 0:
		lateral = Vector2i(0, 1)
	else:
		lateral = Vector2i(1, 0)

	for i in range(1, length + 1):
		var base := center + dir * i
		# 宽度 = i（含中心线）
		var half_width: int = i / 2
		for w in range(-half_width, half_width + 1):
			var pos := base + lateral * w
			if _is_valid_pos(pos):
				positions.append(pos)
	return positions


# === 辅助 ===

static func _is_valid_pos(pos: Vector2i) -> bool:
	return GridWorld.is_within_bounds(pos)
