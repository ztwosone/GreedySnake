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

	var grid_world = _get_grid_world()
	var new_pos := ctx.target_position

	for i in distance:
		var candidate := new_pos + dir
		if grid_world:
			if grid_world.has_method("is_within_bounds") and not grid_world.is_within_bounds(candidate):
				break
			if grid_world.has_method("is_cell_blocked") and grid_world.is_cell_blocked(candidate):
				break
		new_pos = candidate

	if new_pos != ctx.target_position and ctx.target.get("grid_position") != null:
		ctx.target.grid_position = new_pos


func _get_grid_world() -> Node:
	var ml = Engine.get_main_loop()
	var root = ml.root if ml else null
	if root:
		return root.get_node_or_null("GridWorld")
	return null
