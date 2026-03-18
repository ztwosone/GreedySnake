class_name ModifyGrowthAtom
extends AtomBase
## Modifies the food growth multiplier for the target via effect_mgr.
## Params: multiplier (float). Uses effect_mgr.set_modifier("growth", target, multiplier).


func execute(ctx: AtomContext) -> void:
	var multiplier: float = get_param("multiplier", 1.0)
	if not ctx.effect_mgr or not ctx.target:
		return

	if ctx.effect_mgr.has_method("set_modifier"):
		ctx.effect_mgr.set_modifier("growth", ctx.target, multiplier)
	elif "_active_modifiers" in ctx.effect_mgr:
		# 回退：直接写字典
		if not ctx.effect_mgr._active_modifiers.has("growth"):
			ctx.effect_mgr._active_modifiers["growth"] = {}
		ctx.effect_mgr._active_modifiers["growth"][ctx.target.get_instance_id()] = multiplier
