class_name DamagePercentAtom
extends AtomBase
## Deals percentage-based damage to the target's snake body.
## Params: percent (float, 0-1). Computes amount from target body size,
## then emits length_decrease_requested.


func execute(ctx: AtomContext) -> void:
	var percent: float = get_param("percent", 0.0)
	if percent <= 0.0 or not ctx.target:
		return

	var body = ctx.target.get("body")
	if body == null:
		return

	var amount: int = ceili(body.size() * percent)
	if amount <= 0:
		return

	ctx.results["damage_dealt"] = amount

	var data := {
		"target": ctx.target,
		"amount": amount,
		"source": get_param("source", "percent_damage"),
	}
	EventBus.length_decrease_requested.emit(data)
