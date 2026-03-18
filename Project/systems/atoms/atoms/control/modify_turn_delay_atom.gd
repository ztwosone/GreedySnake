class_name ModifyTurnDelayAtom
extends AtomBase
## Adds a turn delay to the target.
## Params: delay_ticks (int).
## Sets "turn_delay" meta on the target.


func execute(ctx: AtomContext) -> void:
	var delay_ticks: int = get_param("delay_ticks", 0)

	if not ctx.target:
		push_warning("ModifyTurnDelayAtom: target is null")
		return

	if ctx.target.has_method("set_meta"):
		ctx.target.set_meta("turn_delay", delay_ticks)
	else:
		push_warning("ModifyTurnDelayAtom: target does not support set_meta")
