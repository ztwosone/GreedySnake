class_name SpreadStatusToSegmentsAtom
extends AtomBase
## 将被吃敌人的状态传播到蛇前 N 段（掠夺鳞 L2/L3）
## 参数: count (int, default 1)
## 从 ctx.params["enemy_def"] 获取被吃敌人状态


func execute(ctx: AtomContext) -> void:
	var count: int = get_param("count", 1)
	if count <= 0:
		return

	# 获取被吃敌人的状态
	var enemy_def = ctx.params.get("enemy_def", null)
	if not enemy_def or not is_instance_valid(enemy_def):
		return
	var enemy_status: String = ""
	if enemy_def.get("carried_status"):
		enemy_status = enemy_def.carried_status
	if enemy_status.is_empty():
		return

	# 对蛇前 count 段施加状态
	var snake = ctx.source
	if not snake or not snake.get("segments"):
		return
	if not ctx.effect_mgr:
		return
	var limit: int = min(count, snake.segments.size())
	for i in range(limit):
		var seg = snake.segments[i]
		if is_instance_valid(seg):
			ctx.effect_mgr.apply_status(seg, enemy_status, "predator_scale")
