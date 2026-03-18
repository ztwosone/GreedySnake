class_name ConsumeTileAtom
extends AtomBase
## Removes a tile at target_position and optionally applies a status to source.
## Params: type (String), apply_type (String, optional), apply_source (String, optional).


func execute(ctx: AtomContext) -> void:
	var tile_type: String = get_param("type", "")
	if tile_type.is_empty() or not ctx.tile_mgr:
		return

	ctx.tile_mgr.remove_tile(ctx.target_position, tile_type)

	var apply_type: String = get_param("apply_type", "")
	if apply_type.is_empty() or not ctx.effect_mgr or not ctx.source:
		return

	var apply_source: String = get_param("apply_source", "tile")
	ctx.effect_mgr.apply_status(ctx.source, apply_type, apply_source)
