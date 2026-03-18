class_name DamageAtom
extends AtomBase
## Emits length_decrease_requested signal to deal damage to a target.
## Params: amount (int), amount_per_layer (int), source (String),
##         formula (String, optional: "sum_layers"), coefficient (float).
## Writes ctx.results["damage_dealt"] with the final computed amount.


func execute(ctx: AtomContext) -> void:
	var final_amount: int = get_param("amount", 0)

	# Per-layer scaling
	var per_layer: int = get_param("amount_per_layer", 0)
	if per_layer > 0 and ctx.effect_data:
		final_amount = per_layer * ctx.effect_data.layer

	# Sum-layers formula
	var formula: String = get_param("formula", "")
	if formula == "sum_layers":
		var coeff: float = get_param("coefficient", 1.0)
		final_amount = ceili((ctx.layer_a + ctx.layer_b) * coeff)

	# Respect damage cap if set
	var cap = ctx.results.get("damage_cap", -1)
	if cap is int and cap >= 0 and final_amount > cap:
		final_amount = cap

	ctx.results["damage_dealt"] = final_amount

	var event_bus = _get_event_bus()
	if event_bus and final_amount > 0:
		var data := {
			"target": ctx.target,
			"amount": final_amount,
			"source": get_param("source", "effect"),
		}
		event_bus.length_decrease_requested.emit(data)


func _get_event_bus() -> Node:
	var ml = Engine.get_main_loop()
	var root = ml.root if ml else null
	if root:
		return root.get_node_or_null("EventBus")
	return null
