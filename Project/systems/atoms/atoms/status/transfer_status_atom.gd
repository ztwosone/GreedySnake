class_name TransferStatusAtom
extends AtomBase
## Transfers all status effects from source to target.
## Gets source's active statuses and applies each one to the target.


func execute(ctx: AtomContext) -> void:
	if not ctx.effect_mgr or not ctx.source or not ctx.target:
		return

	var statuses = ctx.effect_mgr.get_statuses(ctx.source)
	if statuses == null or statuses.is_empty():
		return

	for status in statuses:
		var status_type: String = status.type if "type" in status else str(status)
		ctx.effect_mgr.apply_status(ctx.target, status_type, "transfer")
