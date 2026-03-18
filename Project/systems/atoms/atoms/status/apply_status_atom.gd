class_name ApplyStatusAtom
extends AtomBase
## Applies a status effect to the target for each layer.
## Params: type (String), layers (int, default 1), source (String).


func execute(ctx: AtomContext) -> void:
	var status_type: String = get_param("type", "")
	var layers: int = get_param("layers", 1)
	var status_source: String = get_param("source", "effect")

	if status_type.is_empty() or not ctx.effect_mgr or not ctx.target:
		return

	for i in range(layers):
		ctx.effect_mgr.apply_status(ctx.target, status_type, status_source)
