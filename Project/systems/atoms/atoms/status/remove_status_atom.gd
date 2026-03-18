class_name RemoveStatusAtom
extends AtomBase
## Removes a specific status effect from the target.
## Params: type (String).


func execute(ctx: AtomContext) -> void:
	var status_type: String = get_param("type", "")
	if status_type.is_empty() or not ctx.effect_mgr or not ctx.target:
		return

	ctx.effect_mgr.remove_status(ctx.target, status_type)
