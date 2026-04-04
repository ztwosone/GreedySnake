class_name StealStatusAtom
extends AtomBase
## 从 target 偷取所有状态到 source（StatusCarrier 接口）


func execute(ctx: AtomContext) -> void:
	if not ctx.source or not ctx.target:
		return
	if not ctx.target.has_method("get_statuses") or not ctx.source.has_method("add_status"):
		return
	var statuses: Array = ctx.target.get_statuses()
	for status_type in statuses:
		ctx.source.add_status(status_type)
		ctx.target.remove_status(status_type)
