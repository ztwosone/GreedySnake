class_name ReduceCooldownAtom
extends AtomBase
## Reduces cooldown by a specified amount.
## Params: amount (float).


func execute(ctx: AtomContext) -> void:
	var amount: float = get_param("amount", 0.0)
	if amount > 0.0:
		ctx.results["_cooldown_reduction"] = amount
