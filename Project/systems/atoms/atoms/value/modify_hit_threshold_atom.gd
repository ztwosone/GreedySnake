class_name ModifyHitThresholdAtom
extends AtomBase
## 修改 hits_per_segment_loss 阈值
## 参数: value (int, 叠加到 ctx.results 和持久 modifier)


func execute(ctx: AtomContext) -> void:
	var value: int = get_param("value", 0)
	# 临时结果（向后兼容）
	var current: int = int(ctx.results.get("hit_threshold_modifier", 0))
	ctx.results["hit_threshold_modifier"] = current + value
	# 持久修改器（蛇头装备期间生效）
	if ctx.effect_mgr and ctx.source and is_instance_valid(ctx.source):
		var old: float = ctx.effect_mgr.get_modifier("hit_threshold", ctx.source, 0.0)
		ctx.effect_mgr.set_modifier("hit_threshold", ctx.source, old + value)
