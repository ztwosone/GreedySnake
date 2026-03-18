class_name ExtendDurationAtom
extends AtomBase
## Extends the duration of a specific status effect on the target.
## Params: type (String), amount (float, seconds to add).


func execute(ctx: AtomContext) -> void:
	var status_type: String = get_param("type", "")
	var amount: float = get_param("amount", 0.0)

	if status_type.is_empty() or amount == 0.0 or not ctx.effect_mgr or not ctx.target:
		return

	var status = ctx.effect_mgr.get_status(ctx.target, status_type)
	if status and "duration" in status:
		status.duration += amount
