class_name Snake
extends Node2D

var body: Array[Vector2i] = []
var segments: Array[SnakeSegment] = []
var direction: Vector2i = Constants.DIR_VECTORS[Constants.Direction.RIGHT]
var input_buffer: Vector2i = Vector2i.ZERO
var is_alive: bool = false
var grow_pending: int = 0
var _move_accumulator: float = 0.0
var hits_taken: int = 0
var hits_per_segment_loss: int = 3

var _hurt_tween: Tween
var _danger_tween: Tween
var _countdown_tween: Tween


func _ready() -> void:
	EventBus.tick_input_collected.connect(_on_tick)
	EventBus.snake_length_decreased.connect(_on_hurt)
	EventBus.no_body_countdown_started.connect(_on_countdown_started)
	EventBus.no_body_countdown_tick.connect(_on_countdown_tick)
	EventBus.no_body_countdown_cancelled.connect(_on_countdown_cancelled)
	# 从配置读取受击阈值
	var snake_cfg: Dictionary = ConfigManager.snake if ConfigManager else {}
	hits_per_segment_loss = int(snake_cfg.get("hits_per_segment_loss", 3))


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
	hits_taken = 0
	_move_accumulator = 0.0
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

	# 6. Capture tail info BEFORE moving
	var vacated_pos: Vector2i = body[-1]
	var vacated_status: String = segments[-1].carried_status

	# 7. Calculate all new positions (shift forward)
	var new_positions: Array[Vector2i] = []
	new_positions.resize(body.size())
	new_positions[0] = new_head_pos
	for i in range(1, body.size()):
		new_positions[i] = body[i - 1]

	# 8. Move all segments to new positions
	for i in range(body.size()):
		body[i] = new_positions[i]
		segments[i].move_to(body[i])

	# 9. Handle growth
	if grow_pending > 0:
		grow_pending -= 1
		# Create new segment at old tail position (no status — fresh growth)
		var new_tail_seg := _create_segment(vacated_pos, body.size())
		body.append(vacated_pos)
		segments.append(new_tail_seg)
		# No cell was actually vacated during growth
		vacated_pos = Vector2i(-1, -1)
		vacated_status = ""

	# 10. Update segment types and indices
	_update_segment_types()
	for i in range(segments.size()):
		segments[i].segment_index = i

	# 11. Emit move event
	EventBus.snake_moved.emit({
		"body": body.duplicate(),
		"direction": direction,
		"head_pos": body[0],
		"old_tail_pos": body[-1],
		"vacated_pos": vacated_pos,
		"vacated_status": vacated_status,
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
	if not is_alive:
		return
	var speed: float = _get_effective_speed()
	if speed <= 0.0:
		return  # 冻结状态，不移动
	_move_accumulator += speed
	while _move_accumulator >= 1.0:
		_move_accumulator -= 1.0
		if not is_alive:
			break
		move()


func _get_effective_speed() -> float:
	return 1.0


func _update_segment_types() -> void:
	for i in range(segments.size()):
		var new_type: int
		if i == 0:
			new_type = SnakeSegment.HEAD
		elif i == segments.size() - 1:
			new_type = SnakeSegment.TAIL
		else:
			new_type = SnakeSegment.BODY
		if segments[i].segment_type != new_type:
			segments[i].segment_type = new_type
			segments[i].update_visual()


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


# === Hit counter ===

func take_hit(damage: int = 1) -> void:
	if not is_alive:
		return
	for i in range(damage):
		hits_taken += 1
		if hits_taken >= hits_per_segment_loss:
			hits_taken = 0
			EventBus.length_decrease_requested.emit({"amount": 1, "source": "body_attack"})


func get_segments_in_radius(center: Vector2i, radius: int) -> Array:
	var result: Array = []
	for seg in segments:
		if is_instance_valid(seg):
			var dist: int = abs(seg.grid_position.x - center.x) + abs(seg.grid_position.y - center.y)
			if dist <= radius:
				result.append(seg)
	return result


# === Hurt feedback ===

func _on_hurt(data: Dictionary) -> void:
	var new_length: int = data.get("new_length", body.size())
	# 红闪
	_flash_hurt()
	# 低血量脉动
	if new_length <= 3 and new_length > 0:
		_start_danger_pulse(new_length)
	else:
		_stop_danger_pulse()


func _flash_hurt() -> void:
	if _hurt_tween and _hurt_tween.is_valid():
		_hurt_tween.kill()
	# 所有蛇段红闪
	for seg in segments:
		if is_instance_valid(seg):
			seg.modulate = Color(1.5, 0.3, 0.3)
	_hurt_tween = create_tween()
	_hurt_tween.tween_callback(func():
		for seg in segments:
			if is_instance_valid(seg):
				seg.modulate = Color.WHITE
	).set_delay(0.15)


func _start_danger_pulse(length: int) -> void:
	_stop_danger_pulse()
	# 频率随长度降低加快
	var period: float = 0.3 if length <= 1 else (0.5 if length <= 2 else 0.8)
	_danger_tween = create_tween().set_loops()
	_danger_tween.tween_callback(func():
		for seg in segments:
			if is_instance_valid(seg):
				seg.modulate = Color(1.3, 0.5, 0.5)
	)
	_danger_tween.tween_interval(period * 0.5)
	_danger_tween.tween_callback(func():
		for seg in segments:
			if is_instance_valid(seg):
				seg.modulate = Color.WHITE
	)
	_danger_tween.tween_interval(period * 0.5)


func _stop_danger_pulse() -> void:
	if _danger_tween and _danger_tween.is_valid():
		_danger_tween.kill()
		_danger_tween = null
	for seg in segments:
		if is_instance_valid(seg):
			seg.modulate = Color.WHITE


# === No-Body Countdown Visual ===

func _on_countdown_started(_data: Dictionary) -> void:
	_stop_danger_pulse()
	_start_countdown_flash(1.0)


func _on_countdown_tick(data: Dictionary) -> void:
	var ratio: float = data.get("ratio", 1.0)
	# 根据剩余比例加速闪烁：ratio 1.0→0.0 对应 period 0.6s→0.1s
	_start_countdown_flash(ratio)


func _on_countdown_cancelled() -> void:
	_stop_countdown_flash()


func _start_countdown_flash(ratio: float) -> void:
	if _countdown_tween and _countdown_tween.is_valid():
		_countdown_tween.kill()
	# 闪烁频率随倒计时加速：越接近死亡越快
	var period: float = lerpf(0.1, 0.6, ratio)
	var half: float = period * 0.5
	# 颜色随倒计时从黄色渐变到红色
	var flash_color: Color = Color(1.5, lerpf(0.2, 0.8, ratio), lerpf(0.2, 0.3, ratio))
	_countdown_tween = create_tween().set_loops()
	_countdown_tween.tween_callback(func():
		for seg in segments:
			if is_instance_valid(seg):
				seg.modulate = flash_color
	)
	_countdown_tween.tween_interval(half)
	_countdown_tween.tween_callback(func():
		for seg in segments:
			if is_instance_valid(seg):
				seg.modulate = Color(0.4, 0.4, 0.4)
	)
	_countdown_tween.tween_interval(half)


func _stop_countdown_flash() -> void:
	if _countdown_tween and _countdown_tween.is_valid():
		_countdown_tween.kill()
		_countdown_tween = null
	for seg in segments:
		if is_instance_valid(seg):
			seg.modulate = Color.WHITE
