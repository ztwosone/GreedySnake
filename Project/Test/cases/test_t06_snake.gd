extends RefCounted
## T06 测试：Snake 实体与移动系统


func run(t) -> void:
	t.assert_file_exists("res://entities/snake/snake.gd")
	t.assert_file_exists("res://entities/snake/snake_segment.gd")

	# --- SnakeSegment checks ---
	var seg := SnakeSegment.new()
	t.assert_true(seg is Node2D, "SnakeSegment extends Node2D (via GridEntity)")
	t.assert_eq(seg.entity_type, Constants.EntityType.SNAKE_SEGMENT, "segment entity_type == SNAKE_SEGMENT")
	t.assert_eq(seg.blocks_movement, true, "segment blocks_movement == true")
	t.assert_true(seg.has_method("update_visual"), "segment has update_visual()")
	seg.free()

	# --- Snake method existence ---
	var snake := Snake.new()
	t.assert_true(snake.has_method("init_snake"), "has init_snake()")
	t.assert_true(snake.has_method("move"), "has move()")
	t.assert_true(snake.has_method("process_input"), "has process_input()")
	t.assert_true(snake.has_method("add_segment_at_tail"), "has add_segment_at_tail()")
	t.assert_true(snake.has_method("remove_tail_segment"), "has remove_tail_segment()")
	t.assert_true(snake.has_method("die"), "has die()")

	# --- Snake property defaults ---
	t.assert_eq(snake.is_alive, false, "is_alive default == false")
	t.assert_eq(snake.grow_pending, 0, "grow_pending default == 0")
	t.assert_eq(snake.direction, Constants.DIR_VECTORS[Constants.Direction.RIGHT], "default direction == RIGHT")

	# --- Input buffer: 180° reversal blocked ---
	snake.direction = Constants.DIR_VECTORS[Constants.Direction.RIGHT]
	snake._buffer_direction(Constants.DIR_VECTORS[Constants.Direction.LEFT])
	t.assert_eq(snake.input_buffer, Vector2i.ZERO, "180° reversal blocked (RIGHT→LEFT)")

	snake._buffer_direction(Constants.DIR_VECTORS[Constants.Direction.UP])
	t.assert_eq(snake.input_buffer, Constants.DIR_VECTORS[Constants.Direction.UP], "90° turn allowed (RIGHT→UP)")

	# --- Init and move integration test ---
	GridWorld.init_grid(20, 11)

	# Need to add snake to tree for _ready and children to work
	var tree_root = Engine.get_main_loop().root
	tree_root.add_child(snake)

	snake.init_snake(Vector2i(5, 5), 3, Constants.DIR_VECTORS[Constants.Direction.RIGHT])
	t.assert_eq(snake.is_alive, true, "is_alive == true after init")
	t.assert_eq(snake.body.size(), 3, "body size == 3 after init")
	t.assert_eq(snake.body[0], Vector2i(5, 5), "head at (5,5)")
	t.assert_eq(snake.body[1], Vector2i(4, 5), "body[1] at (4,5)")
	t.assert_eq(snake.body[2], Vector2i(3, 5), "body[2] at (3,5)")

	# Test move
	var moved := []
	var on_move := func(data: Dictionary) -> void:
		moved.append(data)
	EventBus.snake_moved.connect(on_move)

	snake.move()
	t.assert_eq(snake.body[0], Vector2i(6, 5), "head moved to (6,5)")
	t.assert_eq(snake.body.size(), 3, "body size still 3 (no growth)")
	t.assert_eq(moved.size(), 1, "snake_moved event emitted")

	# Test segment persistence: head object survives move
	var head_ref: SnakeSegment = snake.segments[0]
	var body_ref: SnakeSegment = snake.segments[1]
	snake.move()
	t.assert_eq(snake.segments[0], head_ref, "head segment persists after move")
	t.assert_eq(snake.segments[1], body_ref, "body segment persists after move")

	# Test status persistence: status follows segment
	head_ref.set_carried_status("fire")
	snake.move()
	t.assert_eq(snake.segments[0], head_ref, "head ref still same after 2nd move")
	t.assert_eq(snake.segments[0].carried_status, "fire", "head status persists after move")
	head_ref.clear_carried_status()

	# Test grow
	snake.grow_pending = 1
	snake.move()
	t.assert_eq(snake.body.size(), 4, "body size == 4 after grow")

	# Test boundary hit
	var boundary_hits := []
	var on_boundary := func(data: Dictionary) -> void:
		boundary_hits.append(data)
	EventBus.snake_hit_boundary.connect(on_boundary)

	# Move snake to edge
	snake.direction = Constants.DIR_VECTORS[Constants.Direction.RIGHT]
	while snake.body[0].x < 19:
		snake.move()
	snake.move()  # This should hit boundary
	t.assert_eq(boundary_hits.size(), 1, "snake_hit_boundary emitted at wall")

	# Clean up
	EventBus.snake_moved.disconnect(on_move)
	EventBus.snake_hit_boundary.disconnect(on_boundary)
	snake.queue_free()
	GridWorld.clear_all()
