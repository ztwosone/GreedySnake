class_name PhaseAtom
extends AtomBase
## Makes the target entity intangible (phased).
## Params: duration (float).
## Sets "phased" and "phase_duration" meta on the target.


func execute(ctx: AtomContext) -> void:
	var duration: float = get_param("duration", 0.0)

	if not ctx.target:
		push_warning("PhaseAtom: target is null")
		return

	if ctx.target.has_method("set_meta"):
		ctx.target.set_meta("phased", true)
		ctx.target.set_meta("phase_duration", duration)
	else:
		push_warning("PhaseAtom: target does not support set_meta")
