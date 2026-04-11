extends RefCounted
## 方向输入注入器
## 将 Vector2i 方向转换为 Godot InputEventAction 注入输入管线


static func inject_direction(dir: Vector2i, snake: Node = null) -> void:
	if dir == Vector2i.ZERO:
		return
	var action_name: String = _dir_to_action(dir)
	if action_name == "":
		return

	# 优先走 Input 管线
	var press := InputEventAction.new()
	press.action = action_name
	press.pressed = true
	Input.parse_input_event(press)

	var release := InputEventAction.new()
	release.action = action_name
	release.pressed = false
	Input.parse_input_event(release)

	# headless fallback: 如果 snake 可用，直接写 buffer
	if snake and snake.has_method("_buffer_direction"):
		snake._buffer_direction(dir)


static func _dir_to_action(dir: Vector2i) -> String:
	if dir == Vector2i(0, -1):
		return "move_up"
	elif dir == Vector2i(0, 1):
		return "move_down"
	elif dir == Vector2i(-1, 0):
		return "move_left"
	elif dir == Vector2i(1, 0):
		return "move_right"
	return ""
