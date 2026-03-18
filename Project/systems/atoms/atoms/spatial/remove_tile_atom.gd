class_name RemoveTileAtom
extends AtomBase
## Removes a status tile at the target position.
## Params: type (String).


func execute(ctx: AtomContext) -> void:
	var type: String = get_param("type", "")

	if type.is_empty():
		push_warning("RemoveTileAtom: missing 'type' param")
		return

	if ctx.tile_mgr:
		ctx.tile_mgr.remove_tile(ctx.target_position, type)
	else:
		push_warning("RemoveTileAtom: tile_mgr not available in context")
