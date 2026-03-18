class_name CancelCostAtom
extends AtomBase
## Cancels the cost of the current action.


func execute(ctx: AtomContext) -> void:
	ctx.results["cancel_cost"] = true
