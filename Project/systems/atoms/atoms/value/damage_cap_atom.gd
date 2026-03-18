class_name DamageCapAtom
extends AtomBase
## Sets a damage cap in the atom context results pipeline.
## Params: cap (int). Downstream damage atoms should respect this cap.
## Writes ctx.results["damage_cap"] = cap.


func execute(ctx: AtomContext) -> void:
	var cap: int = get_param("cap", 0)
	ctx.results["damage_cap"] = cap
