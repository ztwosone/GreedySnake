class_name AccumulateAtom
extends AtomBase
## Accumulates a value over multiple executions.
## Params: amount (int, default 1).

var _accumulated: int = 0


func execute(ctx: AtomContext) -> void:
	var amount: int = get_param("amount", 1)
	_accumulated += amount
	ctx.results["accumulated"] = _accumulated
