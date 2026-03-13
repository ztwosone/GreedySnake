extends RefCounted
## T04 测试：GridWorld 网格世界管理器


func run(t) -> void:
	t.assert_file_exists("res://autoloads/grid_world.gd")

	# --- Method existence ---
	t.assert_true(GridWorld.has_method("init_grid"), "has init_grid()")
	t.assert_true(GridWorld.has_method("register_entity"), "has register_entity()")
	t.assert_true(GridWorld.has_method("unregister_entity"), "has unregister_entity()")
	t.assert_true(GridWorld.has_method("move_entity"), "has move_entity()")
	t.assert_true(GridWorld.has_method("get_entities_at"), "has get_entities_at()")
	t.assert_true(GridWorld.has_method("get_first_entity_of_type"), "has get_first_entity_of_type()")
	t.assert_true(GridWorld.has_method("is_cell_blocked"), "has is_cell_blocked()")
	t.assert_true(GridWorld.has_method("is_within_bounds"), "has is_within_bounds()")
	t.assert_true(GridWorld.has_method("get_neighbors"), "has get_neighbors()")
	t.assert_true(GridWorld.has_method("get_empty_cells"), "has get_empty_cells()")
	t.assert_true(GridWorld.has_method("grid_to_world"), "has grid_to_world()")
	t.assert_true(GridWorld.has_method("world_to_grid"), "has world_to_grid()")
	t.assert_true(GridWorld.has_method("clear_all"), "has clear_all()")

	# Reset grid for testing
	GridWorld.init_grid(20, 11)

	# --- Bounds checking ---
	t.assert_true(GridWorld.is_within_bounds(Vector2i(0, 0)), "bounds: (0,0) is in")
	t.assert_true(GridWorld.is_within_bounds(Vector2i(19, 10)), "bounds: (19,10) is in")
	t.assert_true(not GridWorld.is_within_bounds(Vector2i(-1, 0)), "bounds: (-1,0) is out")
	t.assert_true(not GridWorld.is_within_bounds(Vector2i(20, 0)), "bounds: (20,0) is out")
	t.assert_true(not GridWorld.is_within_bounds(Vector2i(0, 11)), "bounds: (0,11) is out")

	# --- Register / query / unregister ---
	var mock = _MockEntity.new()
	mock.entity_type = Constants.EntityType.FOOD
	mock.blocks_movement = false
	GridWorld.register_entity(mock, Vector2i(5, 5))
	var at_5_5 = GridWorld.get_entities_at(Vector2i(5, 5))
	t.assert_eq(at_5_5.size(), 1, "register: entity found at (5,5)")
	t.assert_true(at_5_5[0] == mock, "register: correct entity reference")

	# get_first_entity_of_type
	var found = GridWorld.get_first_entity_of_type(Vector2i(5, 5), Constants.EntityType.FOOD)
	t.assert_true(found == mock, "get_first_entity_of_type finds FOOD")
	var not_found = GridWorld.get_first_entity_of_type(Vector2i(5, 5), Constants.EntityType.ENEMY)
	t.assert_true(not_found == null, "get_first_entity_of_type returns null for wrong type")

	# is_cell_blocked
	t.assert_true(not GridWorld.is_cell_blocked(Vector2i(5, 5)), "non-blocking entity: cell not blocked")
	mock.blocks_movement = true
	t.assert_true(GridWorld.is_cell_blocked(Vector2i(5, 5)), "blocking entity: cell blocked")

	# unregister
	GridWorld.unregister_entity(mock)
	t.assert_eq(GridWorld.get_entities_at(Vector2i(5, 5)).size(), 0, "unregister: entity removed")

	# --- Move entity with callback ---
	var mover = _MockEntity.new()
	var receiver = _MockEntity.new()
	receiver.cell_layer = 1
	GridWorld.register_entity(receiver, Vector2i(3, 3))
	GridWorld.register_entity(mover, Vector2i(2, 3))
	GridWorld.move_entity(mover, Vector2i(2, 3), Vector2i(3, 3))
	t.assert_eq(GridWorld.get_entities_at(Vector2i(2, 3)).size(), 0, "move: old cell empty")
	t.assert_true(mover in GridWorld.get_entities_at(Vector2i(3, 3)), "move: mover at new cell")
	t.assert_true(receiver.enter_called, "move: _on_entity_enter called on receiver")

	# --- Coordinate conversion (derived from CELL_SIZE) ---
	var half_cell: float = Constants.CELL_SIZE / 2.0
	var world_pos: Vector2 = GridWorld.grid_to_world(Vector2i(0, 0))
	t.assert_eq(world_pos, Vector2(half_cell, half_cell), "grid_to_world (0,0) -> center of cell")
	var grid_pos: Vector2i = GridWorld.world_to_grid(Vector2(100, 200))
	var expected_gx: int = int(100.0 / Constants.CELL_SIZE)
	var expected_gy: int = int(200.0 / Constants.CELL_SIZE)
	t.assert_eq(grid_pos, Vector2i(expected_gx, expected_gy), "world_to_grid (100,200) -> correct grid pos")

	# Inverse
	var round_trip: Vector2i = GridWorld.world_to_grid(GridWorld.grid_to_world(Vector2i(5, 7)))
	t.assert_eq(round_trip, Vector2i(5, 7), "grid_to_world/world_to_grid round trip")

	# --- Safe query on out-of-bounds / empty ---
	t.assert_eq(GridWorld.get_entities_at(Vector2i(-1, -1)).size(), 0, "out-of-bounds query returns empty")
	t.assert_true(not GridWorld.is_cell_blocked(Vector2i(99, 99)), "out-of-bounds not blocked")

	# --- Neighbors ---
	var n_corner: Array[Vector2i] = GridWorld.get_neighbors(Vector2i(0, 0))
	t.assert_eq(n_corner.size(), 2, "corner (0,0) has 2 neighbors")
	var n_middle: Array[Vector2i] = GridWorld.get_neighbors(Vector2i(5, 5))
	t.assert_eq(n_middle.size(), 4, "middle (5,5) has 4 neighbors")

	# --- get_empty_cells ---
	GridWorld.clear_all()
	GridWorld.init_grid(3, 3)
	GridWorld.register_entity(_MockEntity.new(), Vector2i(1, 1))
	var empty: Array[Vector2i] = GridWorld.get_empty_cells()
	t.assert_eq(empty.size(), 8, "3x3 grid with 1 entity: 8 empty cells")

	# Clean up
	GridWorld.clear_all()
	GridWorld.init_grid(20, 11)


class _MockEntity:
	extends Node
	var entity_type: int = 0
	var blocks_movement: bool = false
	var is_solid: bool = true
	var cell_layer: int = 1
	var enter_called: bool = false

	func _on_entity_enter(_other) -> void:
		enter_called = true

	func _on_entity_exit(_other) -> void:
		pass

	func _on_stepped_on(_stepper) -> void:
		pass
