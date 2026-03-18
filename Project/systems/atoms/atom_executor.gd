class_name AtomExecutor
extends RefCounted
## 效果链执行器
## 评估条件 → 概率检查 → 解析范围 → 对每个目标执行原子。


## 执行一个效果链
func execute_chain(chain: EffectChain, ctx: AtomContext) -> void:
	if not chain._active:
		return

	# 1. 评估所有条件（AND 逻辑）
	for condition in chain.conditions:
		if not condition.evaluate(ctx):
			return

	# 2. 概率检查
	if chain.chance < 1.0:
		if randf() >= chain.chance:
			return

	# 3. 解析目标范围
	var positions: Array = PatternResolver.resolve(
		chain.pattern, ctx, chain.pattern_params
	)

	# 4. 对每个目标位置执行所有动作原子
	if positions.is_empty():
		# 无目标位置时也执行一次（某些原子不需要位置，如 modify_speed）
		_execute_actions(chain.actions, ctx)
	else:
		for pos in positions:
			var sub_ctx := ctx.with_target_position(pos)
			# 尝试解析该位置上的实体作为 target
			_resolve_target_entity(sub_ctx, pos)
			_execute_actions(chain.actions, sub_ctx)


## 执行动作原子列表
func _execute_actions(actions: Array, ctx: AtomContext) -> void:
	for atom in actions:
		atom.execute(ctx)


## 解析位置上的实体
func _resolve_target_entity(ctx: AtomContext, pos: Vector2i) -> void:
	var ml = Engine.get_main_loop()
	if ml == null:
		return
	var gw = ml.root.get_node_or_null("GridWorld")
	if gw == null or not gw.has_method("get_entities_at"):
		return

	var entities: Array = gw.get_entities_at(pos)
	if entities.size() > 0 and ctx.target == null:
		ctx.target = entities[0]
