class_name ForcedMoveAtom
extends AtomBase
## Forces the target to move in a direction.
## Params: distance (int, default 1), direction (String, optional).
## Direction can come from params or ctx.direction.


func execute(ctx: AtomContext) -> void:
	var distance: int = get_param("distance", 1)

	if not ctx.target:
		push_warning("ForcedMoveAtom: target is null")
		return

	var dir := ctx.direction
	# Allow param override for direction
	var dir_param: String = get_param("direction", "")
	if not dir_param.is_empty():
		match dir_param:
			"up": dir = Vector2i(0, -1)
			"down": dir = Vector2i(0, 1)
			"left": dir = Vector2i(-1, 0)
			"right": dir = Vector2i(1, 0)

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
