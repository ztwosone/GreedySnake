class_name TriggerSlotAtom
extends AtomBase
## Triggers a build slot action.
## Params: slot_type (String: "front"/"mid"/"back"), count (int, default 1).
## L2: will call ScaleSystem.


func execute(ctx: AtomContext) -> void:
	var slot_type: String = get_param("slot_type", "front")
	var count: int = get_param("count", 1)
	ctx.results["_trigger_slot"] = {"type": slot_type, "count": count}
