class_name AttractAtom
extends AtomBase
## Pulls the target toward the source.
## Params: distance (int, default 1).
## Direction is sign(source_pos - target_pos).


func execute(ctx: AtomContext) -> void:
	var distance: int = get_param("distance", 1)

	if not ctx.target:
		push_warning("AttractAtom: target is null")
		return

	var diff := ctx.source_position - ctx.target_position
	var dir := Vector2i(signi(diff.x), signi(diff.y))
	if dir == Vector2i.ZERO:
		return

	var new_pos := ctx.target_position

	for i in distance:
		var candidate := new_pos + dir
		# Don't move onto the source position itself
		if candidate == ctx.source_position:
			break
		if not GridWorld.is_within_bounds(candidate):
			break
		if GridWorld.is_cell_blocked(candidate):
			break
		new_pos = candidate

	if new_pos != ctx.target_position and ctx.target.get("grid_position") != null:
		ctx.target.grid_position = new_pos
