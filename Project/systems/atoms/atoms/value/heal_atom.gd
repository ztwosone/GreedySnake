class_name HealAtom
extends AtomBase
## Heals the target by increasing its grow_pending counter.
## Params: amount (int).


func execute(ctx: AtomContext) -> void:
	var amount: int = get_param("amount", 0)
	if amount <= 0 or not ctx.target:
		return

	if "grow_pending" in ctx.target:
		ctx.target.grow_pending += amount
