class_name ApplyStatusAtom
extends AtomBase
## Applies a status effect to the target for each layer.
## Params: type/status_type (String), layers (int, default 1), source (String).
## Optional: apply_to = "attacker" → 从 ctx.params["enemy"] 获取目标（白蛇反击用）


func execute(ctx: AtomContext) -> void:
	var status_type: String = get_param("status_type", get_param("type", ""))
	var layers: int = get_param("layers", 1)
	var status_source: String = get_param("source", "effect")
	var apply_to: String = get_param("apply_to", "")

	if status_type.is_empty() or not ctx.effect_mgr:
		return

	# 确定目标
	var target = ctx.target
	if apply_to == "attacker":
		target = ctx.params.get("enemy", ctx.target)
	if not is_instance_valid(target):
		return

	for i in range(layers):
		ctx.effect_mgr.apply_status(target, status_type, status_source)
