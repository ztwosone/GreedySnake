class_name DisableSlotAtom
extends AtomBase
## Disables a build slot for a duration.
## Params: slot_type (String), duration (float).


func execute(ctx: AtomContext) -> void:
	var slot_type: String = get_param("slot_type", "")
	var duration: float = get_param("duration", 0.0)
	ctx.results["_disable_slot"] = {"type": slot_type, "duration": duration}
