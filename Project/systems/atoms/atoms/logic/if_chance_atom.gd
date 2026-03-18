class_name IfChanceAtom
extends AtomBase
## Condition: random chance check.
## Params: chance (float, 0.0 to 1.0).


func is_condition() -> bool:
	return true


func evaluate(ctx: AtomContext) -> bool:
	var chance: float = get_param("chance", 0.0)
	return randf() < chance
