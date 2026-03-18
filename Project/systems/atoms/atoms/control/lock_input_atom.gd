class_name LockInputAtom
extends AtomBase
## Locks the target's input for a duration.
## Params: duration (float).
## Sets "input_locked" and "input_lock_duration" meta on the target.


func execute(ctx: AtomContext) -> void:
	var duration: float = get_param("duration", 0.0)

	if not ctx.target:
		push_warning("LockInputAtom: target is null")
		return

	if ctx.target.has_method("set_meta"):
		ctx.target.set_meta("input_locked", true)
		ctx.target.set_meta("input_lock_duration", duration)
	else:
		push_warning("LockInputAtom: target does not support set_meta")
