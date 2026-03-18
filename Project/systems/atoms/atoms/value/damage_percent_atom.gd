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

	var event_bus = _get_event_bus()
	if event_bus:
		var data := {
			"target": ctx.target,
			"amount": amount,
			"source": get_param("source", "percent_damage"),
		}
		event_bus.length_decrease_requested.emit(data)


func _get_event_bus() -> Node:
	var ml = Engine.get_main_loop()
	var root = ml.root if ml else null
	if root:
		return root.get_node_or_null("EventBus")
	return null
