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

	if final_amount <= 0:
		return

	# 判断 target 类型：蛇走 length_decrease，敌人走 take_damage
	var target_entity = ctx.target
	if target_entity and is_instance_valid(target_entity) and target_entity.has_method("take_damage"):
		# 非蛇实体（Enemy 等）：直接扣 HP
		target_entity.take_damage(final_amount)
	else:
		# 蛇或无具体目标：走长度减少信号
		var data := {
			"target": target_entity,
			"amount": final_amount,
			"source": get_param("source", "effect"),
		}
		EventBus.length_decrease_requested.emit(data)
