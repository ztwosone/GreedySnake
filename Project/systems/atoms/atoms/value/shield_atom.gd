class_name ShieldAtom
extends AtomBase
## Gives the target a shield by setting meta "shield_amount".
## Params: amount (int).


func execute(ctx: AtomContext) -> void:
	var amount: int = get_param("amount", 0)
	if not ctx.target or amount <= 0:
		return

	if ctx.target.has_method("set_meta"):
		ctx.target.set_meta("shield_amount", amount)
