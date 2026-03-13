extends RefCounted
## T05 测试：GridEntity 万物基类


func run(t) -> void:
	t.assert_file_exists("res://core/grid_entity.gd")

	var ge := GridEntity.new()

	# --- Property defaults ---
	t.assert_eq(ge.grid_position, Vector2i.ZERO, "grid_position default == Vector2i.ZERO")
	t.assert_eq(ge.entity_type, -1, "entity_type default == -1")
	t.assert_eq(ge.blocks_movement, false, "blocks_movement default == false")
	t.assert_eq(ge.is_solid, true, "is_solid default == true")
	t.assert_eq(ge.cell_layer, 1, "cell_layer default == 1")

	# --- Method existence ---
	t.assert_true(ge.has_method("_on_entity_enter"), "has _on_entity_enter()")
	t.assert_true(ge.has_method("_on_entity_exit"), "has _on_entity_exit()")
	t.assert_true(ge.has_method("_on_tick"), "has _on_tick()")
	t.assert_true(ge.has_method("_on_stepped_on"), "has _on_stepped_on()")
	t.assert_true(ge.has_method("place_on_grid"), "has place_on_grid()")
	t.assert_true(ge.has_method("remove_from_grid"), "has remove_from_grid()")
	t.assert_true(ge.has_method("move_to"), "has move_to()")

	# --- Inherits Node2D ---
	t.assert_true(ge is Node2D, "GridEntity extends Node2D")

	# --- place_on_grid / remove_from_grid integration ---
	GridWorld.init_grid(20, 11)
	ge.place_on_grid(Vector2i(5, 5))
	t.assert_eq(ge.grid_position, Vector2i(5, 5), "grid_position updated after place_on_grid")
	var entities_at = GridWorld.get_entities_at(Vector2i(5, 5))
	t.assert_true(ge in entities_at, "entity registered in GridWorld after place_on_grid")

	ge.remove_from_grid()
	t.assert_eq(GridWorld.get_entities_at(Vector2i(5, 5)).size(), 0, "entity removed from GridWorld after remove_from_grid")

	GridWorld.clear_all()
	ge.free()
