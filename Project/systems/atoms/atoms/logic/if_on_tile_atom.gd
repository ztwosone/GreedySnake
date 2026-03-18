class_name IfOnTileAtom
extends AtomBase
## Condition: checks if source is on a specific tile type.
## Params: type (String).


func is_condition() -> bool:
	return true


func evaluate(ctx: AtomContext) -> bool:
	var tile_type: String = get_param("type", "")
	if tile_type.is_empty() or not ctx.tile_mgr:
		return false

	return ctx.tile_mgr.has_tile(ctx.source_position, tile_type)
