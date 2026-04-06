class_name ModifyFoodDropAtom
extends AtomBase
## 修改击杀后食物掉落数量
## 参数: amount (int, 叠加到 ctx.results 和持久 modifier)


func execute(ctx: AtomContext) -> void:
	var amount: int = get_param("amount", 0)
	# 临时结果（向后兼容）
	var current: int = int(ctx.results.get("food_drop_modifier", 0))
	ctx.results["food_drop_modifier"] = current + amount
	# 持久修改器（蛇头装备期间生效）
	if ctx.effect_mgr and ctx.source and is_instance_valid(ctx.source):
		var old: float = ctx.effect_mgr.get_modifier("food_drop", ctx.source, 0.0)
		ctx.effect_mgr.set_modifier("food_drop", ctx.source, old + amount)
