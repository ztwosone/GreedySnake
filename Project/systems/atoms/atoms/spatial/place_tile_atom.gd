class_name PlaceTileAtom
extends AtomBase
## Places a status tile at the target position.
## Params: type (String), layer (int, default 1).


func execute(ctx: AtomContext) -> void:
	var type: String = get_param("type", "")
	var layer: int = get_param("layer", 1)

	if type.is_empty():
		push_warning("PlaceTileAtom: missing 'type' param")
		return

	if ctx.tile_mgr:
		ctx.tile_mgr.place_tile(ctx.target_position, type, layer)
	else:
		push_warning("PlaceTileAtom: tile_mgr not available in context")
