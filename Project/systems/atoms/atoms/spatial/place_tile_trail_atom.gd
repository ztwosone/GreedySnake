class_name PlaceTileTrailAtom
extends AtomBase
## Places a status tile periodically along a snake's trail.
## Params: type (String), interval (int, default 3).
## Increments an internal counter each execute; places tile when counter >= interval.

var _trail_counter: int = 0


func execute(ctx: AtomContext) -> void:
	var type: String = get_param("type", "")
	var interval: int = get_param("interval", 3)

	if type.is_empty():
		push_warning("PlaceTileTrailAtom: missing 'type' param")
		return

	_trail_counter += 1
	if _trail_counter >= interval:
		_trail_counter = 0
		if ctx.tile_mgr:
			ctx.tile_mgr.place_tile(ctx.target_position, type, 1)
		else:
			push_warning("PlaceTileTrailAtom: tile_mgr not available in context")
