class_name LockSlotAtom
extends AtomBase
## Locks a specific build slot by index.
## Params: slot_index (int).


func execute(ctx: AtomContext) -> void:
	var slot_index: int = get_param("slot_index", 0)
	ctx.results["_lock_slot"] = slot_index
