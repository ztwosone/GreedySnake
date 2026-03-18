class_name StunAtom
extends AtomBase
## Stuns the target for a number of ticks.
## Params: ticks (int, default 1).
## Sets "stunned_ticks" meta on the target.


func execute(ctx: AtomContext) -> void:
	var ticks: int = get_param("ticks", 1)

	if ctx.target and ctx.target.has_method("set_meta"):
		ctx.target.set_meta("stunned_ticks", ticks)
	else:
		push_warning("StunAtom: target is null or does not support set_meta")
