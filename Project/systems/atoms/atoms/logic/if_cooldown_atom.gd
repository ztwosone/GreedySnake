class_name IfCooldownAtom
extends AtomBase
## Condition: checks if enough time has passed since last firing.
## Params: cooldown (float, seconds).

var _last_fired_time: float = -999.0


func is_condition() -> bool:
	return true


func evaluate(ctx: AtomContext) -> bool:
	var cooldown: float = get_param("cooldown", 0.0)
	var current_time: float = Time.get_ticks_msec() / 1000.0

	if current_time - _last_fired_time < cooldown:
		return false

	_last_fired_time = current_time
	return true
