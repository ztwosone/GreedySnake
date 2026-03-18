class_name ModifyAttackCostAtom
extends AtomBase
## Modifies enemy attack cost by setting target meta "attack_cost_mod".
## Params: modifier (int, additive).


func execute(ctx: AtomContext) -> void:
	var modifier: int = get_param("modifier", 0)
	if not ctx.target:
		return

	if ctx.target.has_method("set_meta"):
		ctx.target.set_meta("attack_cost_mod", modifier)
