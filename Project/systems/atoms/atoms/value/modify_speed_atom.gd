class_name ModifySpeedAtom
extends AtomBase
## Modifies movement speed via per-entity SEM modifier.
## Params: multiplier (float).


func execute(ctx: AtomContext) -> void:
	var multiplier: float = get_param("multiplier", 1.0)
	if ctx.effect_mgr and ctx.target:
		ctx.effect_mgr.set_modifier("speed", ctx.target, multiplier)
