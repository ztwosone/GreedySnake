class_name IfLengthAboveAtom
extends AtomBase
## Condition: checks if snake body length is above threshold.
## Params: threshold (int).


func is_condition() -> bool:
	return true


func evaluate(ctx: AtomContext) -> bool:
	var threshold: int = get_param("threshold", 0)
	var snake = ctx.source if ctx.source else ctx.target
	if snake and "body" in snake:
		return snake.body.size() > threshold
	return false
