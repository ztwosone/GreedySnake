class_name Snake
extends Node2D

var body: Array[Vector2i] = []
var segments: Array[SnakeSegment] = []
var direction: Vector2i = Constants.DIR_VECTORS[Constants.Direction.RIGHT]
var input_buffer: Vector2i = Vector2i.ZERO
var is_alive: bool = false
var grow_pending: int = 0


func _ready() -> void:
	EventBus.tick_input_collected.connect(_on_tick)


func _unhandled_input(event: InputEvent) -> void:
	if not is_alive:
		return
	if event.is_action_pressed("move_up"):
		_buffer_direction(Constants.DIR_VECTORS[Constants.Direction.UP])
	elif event.is_action_pressed("move_down"):
		_buffer_direction(Constants.DIR_VECTORS[Constants.Direction.DOWN])
	elif event.is_action_pressed("move_left"):
		_buffer_direction(Constants.DIR_VECTORS[Constants.Direction.LEFT])
	elif event.is_action_pressed("move_right"):
		_buffer_direction(Constants.DIR_VECTORS[Constants.Direction.RIGHT])


func init_snake(start_pos: Vector2i, length: int, dir: Vector2i) -> void:
	# Clean up any existing segments
	_clear_segments()

	direction = dir
	input_buffer = Vector2i.ZERO
	is_alive = true
	grow_pending = 0
	body.clear()
	segments.clear()

	# Build snake from head to tail in reverse direction
	for i in range(length):
		var pos := start_pos - dir * i
		body.append(pos)
		var seg := _create_segment(pos, i)
		segments.append(seg)

	# Set segment types
	if segments.size() > 0:
		segments[0].segment_type = SnakeSegment.HEAD
		segments[0].update_visual()
	if segments.size() > 1:
		segments[-1].segment_type = SnakeSegment.TAIL
		segments[-1].update_visual()


func move() -> void:
	if not is_alive:
		return

	# 1. Process buffered input
	process_input()

	# 2. Calculate new head position
	var new_head_pos := body[0] + direction

	# 3. Boundary check
	if not GridWorld.is_within_bounds(new_head_pos):
		EventBus.snake_hit_boundary.emit({"position": new_head_pos, "direction": direction})
		return

	# 4. Self-collision check (skip tail if not growing)
	var body_to_check: Array[Vector2i]
	if grow_pending <= 0:
		body_to_check.assign(body.slice(0, body.size() - 1))
	else:
		body_to_check.assign(body.duplicate())
	if new_head_pos in body_to_check:
		EventBus.snake_hit_self.emit({"position": new_head_pos, "segment_index": body.find(new_head_pos)})
		return

	# 5. Check entities at target cell
	var entities_at_target: Array = GridWorld.get_entities_at(new_head_pos)
	for entity in entities_at_target:
		if entity.get("entity_type") == Constants.EntityType.ENEMY:
			EventBus.snake_hit_enemy.emit({"enemy": entity, "position": new_head_pos})
		elif entity.get("entity_type") == Constants.EntityType.FOOD:
			EventBus.snake_food_eaten.emit({"food": entity, "position": new_head_pos, "food_type": "basic"})

	# 6. Insert new head
	body.push_front(new_head_pos)
	var new_head_seg := _create_segment(new_head_pos, 0)
	new_head_seg.segment_type = SnakeSegment.HEAD
	new_head_seg.update_visual()
	segments.push_front(new_head_seg)

	# Old head becomes body
	if segments.size() > 1:
		segments[1].segment_type = SnakeSegment.BODY
		segments[1].update_visual()

	# 7. Handle tail
	if grow_pending > 0:
		grow_pending -= 1
	else:
		var old_tail_pos: Vector2i = body.pop_back()
		var old_tail_seg: SnakeSegment = segments.pop_back()
		old_tail_seg.remove_from_grid()
		old_tail_seg.queue_free()

	# 8. Update tail type
	if segments.size() > 1:
		segments[-1].segment_type = SnakeSegment.TAIL
		segments[-1].update_visual()

	# 9. Update segment indices
	for i in range(segments.size()):
		segments[i].segment_index = i

	# 10. Emit move event
	EventBus.snake_moved.emit({
		"body": body.duplicate(),
		"direction": direction,
		"head_pos": body[0],
		"old_tail_pos": body[-1],
	})


func add_segment_at_tail() -> void:
	grow_pending += 1


func remove_tail_segment() -> void:
	if body.size() <= 1:
		return
	var old_tail_pos: Vector2i = body.pop_back()
	var old_tail_seg: SnakeSegment = segments.pop_back()
	old_tail_seg.remove_from_grid()
	old_tail_seg.queue_free()
	# Update new tail
	if segments.size() > 1:
		segments[-1].segment_type = SnakeSegment.TAIL
		segments[-1].update_visual()


func die(cause: String) -> void:
	is_alive = false
	EventBus.snake_died.emit({"cause": cause})


func process_input() -> void:
	if input_buffer != Vector2i.ZERO:
		var old_dir := direction
		direction = input_buffer
		input_buffer = Vector2i.ZERO
		if old_dir != direction:
			EventBus.snake_turned.emit({"old_dir": old_dir, "new_dir": direction})


func _buffer_direction(new_dir: Vector2i) -> void:
	# Prevent 180° reversal
	if new_dir + direction != Vector2i.ZERO:
		input_buffer = new_dir


func _on_tick(_tick_index: int) -> void:
	if is_alive:
		move()


func _create_segment(pos: Vector2i, index: int) -> SnakeSegment:
	var seg := SnakeSegment.new()
	seg.segment_index = index
	seg.segment_type = SnakeSegment.BODY
	add_child(seg)
	seg.place_on_grid(pos)
	return seg


func _clear_segments() -> void:
	for seg in segments:
		if is_instance_valid(seg):
			seg.remove_from_grid()
			seg.queue_free()
	segments.clear()
	body.clear()
