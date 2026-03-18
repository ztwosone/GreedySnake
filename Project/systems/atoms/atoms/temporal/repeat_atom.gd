class_name RepeatAtom
extends AtomBase
## Repeats the chain a number of times.
## Params: times (int, default 1).


func execute(ctx: AtomContext) -> void:
	var times: int = get_param("times", 1)
	ctx.results["_repeat_count"] = times
