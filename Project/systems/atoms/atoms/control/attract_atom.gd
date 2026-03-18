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

	var grid_world = _get_grid_world()
	var new_pos := ctx.target_position

	for i in distance:
		var candidate := new_pos + dir
		# Don't move onto the source position itself
		if candidate == ctx.source_position:
			break
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
