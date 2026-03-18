class_name CleanseAllAtom
extends AtomBase
## Removes all status effects from the target.


func execute(ctx: AtomContext) -> void:
	if not ctx.effect_mgr or not ctx.target:
		return

	ctx.effect_mgr.remove_all_statuses(ctx.target)
