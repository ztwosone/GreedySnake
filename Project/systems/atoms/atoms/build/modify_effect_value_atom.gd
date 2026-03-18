class_name ModifyEffectValueAtom
extends AtomBase
## Modifies the effect value by a multiplier.
## Params: multiplier (float).


func execute(ctx: AtomContext) -> void:
	var multiplier: float = get_param("multiplier", 1.0)
	ctx.results["effect_value_multiplier"] = multiplier
