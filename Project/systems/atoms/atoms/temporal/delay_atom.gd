class_name DelayAtom
extends AtomBase
## Delays remaining actions by storing delay in ctx.results for TriggerManager.
## Params: delay (float, seconds).


func execute(ctx: AtomContext) -> void:
	var delay: float = get_param("delay", 0.0)
	if delay > 0.0:
		ctx.results["_delay"] = delay
