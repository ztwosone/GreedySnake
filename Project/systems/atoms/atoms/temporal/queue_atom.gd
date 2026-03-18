class_name QueueAtom
extends AtomBase
## Queues remaining actions for the next tick.


func execute(ctx: AtomContext) -> void:
	ctx.results["_queue_next_tick"] = true
