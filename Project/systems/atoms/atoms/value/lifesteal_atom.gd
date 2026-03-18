class_name LifestealAtom
extends AtomBase
## Heals the source based on damage dealt earlier in the chain.
## Params: ratio (float, default 1.0). Reads ctx.results["damage_dealt"],
## heals source by ceil(damage * ratio).


func execute(ctx: AtomContext) -> void:
	var ratio: float = get_param("ratio", 1.0)
	var damage_dealt = ctx.results.get("damage_dealt", 0)
	if damage_dealt <= 0 or not ctx.source:
		return

	var heal_amount: int = ceili(damage_dealt * ratio)
	if heal_amount <= 0:
		return

	if "grow_pending" in ctx.source:
		ctx.source.grow_pending += heal_amount
