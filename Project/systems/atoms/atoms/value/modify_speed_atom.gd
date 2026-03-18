class_name ModifySpeedAtom
extends AtomBase
## Modifies tick speed via tick_mgr.tick_speed_modifier.
## Params: multiplier (float).


func execute(ctx: AtomContext) -> void:
	var multiplier: float = get_param("multiplier", 1.0)
	if ctx.tick_mgr and "tick_speed_modifier" in ctx.tick_mgr:
		ctx.tick_mgr.tick_speed_modifier = multiplier
