class_name IfHasStatusAtom
extends AtomBase
## Condition: checks if an entity has a specific status effect.
## Params: type (String), check_target (String: "source"/"target", default "target").


func is_condition() -> bool:
	return true


func evaluate(ctx: AtomContext) -> bool:
	var status_type: String = get_param("type", "")
	if status_type.is_empty() or not ctx.effect_mgr:
		return false

	var check_target: String = get_param("check_target", "target")
	var entity = ctx.target if check_target == "target" else ctx.source
	if not entity:
		return false

	return ctx.effect_mgr.has_status(entity, status_type)
