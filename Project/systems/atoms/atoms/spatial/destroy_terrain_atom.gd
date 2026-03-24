class_name DestroyTerrainAtom
extends AtomBase
## Destroys terrain at the target position.
## Params: delay (float, default 0).
## If delay > 0, sets meta on effect_data for deferred destruction.
## If delay == 0, attempts immediate destruction via GridWorld.


func execute(ctx: AtomContext) -> void:
	var delay: float = get_param("delay", 0.0)

	if delay > 0.0:
		# Mark for delayed destruction
		if ctx.effect_data and ctx.effect_data.has_method("set_meta"):
			ctx.effect_data.set_meta("destroy_terrain_pos", ctx.target_position)
			ctx.effect_data.set_meta("destroy_terrain_delay", delay)
		else:
			ctx.results["destroy_terrain_pos"] = ctx.target_position
			ctx.results["destroy_terrain_delay"] = delay
	else:
		# Immediate destruction
		if GridWorld.has_method("set_cell_blocked"):
			GridWorld.set_cell_blocked(ctx.target_position, true)
		else:
			push_warning("DestroyTerrainAtom: GridWorld does not support terrain destruction yet")
