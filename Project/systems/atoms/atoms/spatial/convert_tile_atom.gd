class_name ConvertTileAtom
extends AtomBase
## Converts a status tile from one type to another at the target position.
## Params: from_type (String), to_type (String), to_layer (int, default 1).


func execute(ctx: AtomContext) -> void:
	var from_type: String = get_param("from_type", "")
	var to_type: String = get_param("to_type", "")
	var to_layer: int = get_param("to_layer", 1)

	if from_type.is_empty() or to_type.is_empty():
		push_warning("ConvertTileAtom: missing 'from_type' or 'to_type' param")
		return

	if ctx.tile_mgr:
		ctx.tile_mgr.remove_tile(ctx.target_position, from_type)
		ctx.tile_mgr.place_tile(ctx.target_position, to_type, to_layer)
	else:
		push_warning("ConvertTileAtom: tile_mgr not available in context")
