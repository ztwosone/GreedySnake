class_name TeleportAtom
extends AtomBase
## Teleports the target to a specified position.
## Target position comes from ctx.target_position or params (x, y).


func execute(ctx: AtomContext) -> void:
	if not ctx.target:
		push_warning("TeleportAtom: target is null")
		return

	var dest := ctx.target_position

	# Allow explicit position override from params
	var px = get_param("x", null)
	var py = get_param("y", null)
	if px != null and py != null:
		dest = Vector2i(int(px), int(py))

	if ctx.target.get("grid_position") != null:
		ctx.target.grid_position = dest
