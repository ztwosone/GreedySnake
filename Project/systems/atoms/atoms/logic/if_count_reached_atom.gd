class_name IfCountReachedAtom
extends AtomBase
## Condition: increments internal counter, returns true when threshold reached.
## Params: threshold (int).

var _count: int = 0


func is_condition() -> bool:
	return true


func evaluate(ctx: AtomContext) -> bool:
	var threshold: int = get_param("threshold", 1)
	_count += 1
	if _count >= threshold:
		_count = 0
		return true
	return false
