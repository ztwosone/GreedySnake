class_name FreezeAtom
extends AtomBase
## Freezes target entity by setting speed modifier to 0.
## Params: duration (float).
## Auto-resumes after duration via SceneTreeTimer.
## Only affects the target entity, not the global tick.


func execute(ctx: AtomContext) -> void:
	var duration: float = get_param("duration", 0.0)

	if not ctx.effect_mgr or not ctx.target:
		return

	# Set speed to 0 (frozen)
	ctx.effect_mgr.set_modifier("speed", ctx.target, 0.0)

	# Emit freeze started event
	EventBus.ice_freeze_started.emit({})

	# Auto-resume after duration using SceneTreeTimer
	if duration > 0.0:
		var tree := Engine.get_main_loop() as SceneTree
		if tree:
			var timer: SceneTreeTimer = tree.create_timer(duration, true, false, true)
			var effect_mgr_ref = ctx.effect_mgr
			var target_ref = ctx.target
			var effect_ref = ctx.effect_data
			timer.timeout.connect(func():
				_on_freeze_ended(effect_mgr_ref, target_ref, effect_ref)
			)


func _on_freeze_ended(effect_mgr, target, effect) -> void:
	if not effect_mgr or not is_instance_valid(effect_mgr):
		return
	if not target or not is_instance_valid(target):
		return

	# If ice effect is still active (layer > 0), restore to slow speed (0.5)
	# Otherwise restore to normal speed (1.0)
	if effect and is_instance_valid(effect) and effect.get("layer") != null and effect.layer > 0:
		# Ice still on, go back to slowed state
		effect_mgr.set_modifier("speed", target, 0.5)
		if effect.layer > 1:
			effect.layer = 1
	else:
		# Ice gone, restore normal speed
		effect_mgr.set_modifier("speed", target, 1.0)

	EventBus.ice_freeze_ended.emit({})
