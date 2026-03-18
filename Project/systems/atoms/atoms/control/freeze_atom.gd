class_name FreezeAtom
extends AtomBase
## Freezes the game by pausing the tick manager.
## Params: duration (float).
## Unfreeze logic is handled by a separate on_removed chain or the ice effect system.


func execute(ctx: AtomContext) -> void:
	var duration: float = get_param("duration", 0.0)

	if ctx.tick_mgr and ctx.tick_mgr.has_method("pause"):
		ctx.tick_mgr.pause()

	# Store freeze metadata
	if ctx.effect_data and ctx.effect_data.has_method("set_meta"):
		ctx.effect_data.set_meta("_freeze_duration", duration)
		ctx.effect_data.set_meta("_freeze_elapsed", 0.0)
	else:
		ctx.results["_freeze_duration"] = duration
		ctx.results["_freeze_elapsed"] = 0.0

	# Emit event if EventBus signal exists
	var event_bus = _get_event_bus()
	if event_bus and event_bus.has_signal("ice_freeze_started"):
		event_bus.ice_freeze_started.emit()


func _get_event_bus() -> Node:
	var ml = Engine.get_main_loop()
	var root = ml.root if ml else null
	if root:
		return root.get_node_or_null("EventBus")
	return null
