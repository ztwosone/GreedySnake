class_name KnockbackAtom
extends AtomBase
## Knocks the target away from the source.
## Params: distance (int, default 1).
## Calculates direction as sign(target_pos - source_pos) and moves target.


func execute(ctx: AtomContext) -> void:
	var distance: int = get_param("distance", 1)

	if not ctx.target:
		push_warning("KnockbackAtom: target is null")
		return

	var diff := ctx.target_position - ctx.source_position
	var dir := Vector2i(signi(diff.x), signi(diff.y))
	if dir == Vector2i.ZERO:
		return

	var new_pos := ctx.target_position

	for i in distance:
		var candidate := new_pos + dir
		if not GridWorld.is_within_bounds(candidate):
			break
		if GridWorld.is_cell_blocked(candidate):
			break
		new_pos = candidate

	if new_pos != ctx.target_position and ctx.target.get("grid_position") != null:
		ctx.target.grid_position = new_pos
