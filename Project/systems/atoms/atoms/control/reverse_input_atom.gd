class_name ReverseInputAtom
extends AtomBase
## Reverses the snake's input direction.
## Sets "input_reversed" meta on the target.


func execute(ctx: AtomContext) -> void:
	if not ctx.target:
		push_warning("ReverseInputAtom: target is null")
		return

	if ctx.target.has_method("set_meta"):
		ctx.target.set_meta("input_reversed", true)
	else:
		push_warning("ReverseInputAtom: target does not support set_meta")
