class_name GridEntity
extends Node2D

var grid_position: Vector2i = Vector2i.ZERO
var entity_type: int = -1
var blocks_movement: bool = false
var is_solid: bool = true
var cell_layer: int = 1


# === Virtual methods — override in subclasses ===

func _on_entity_enter(_other: Node) -> void:
	pass


func _on_entity_exit(_other: Node) -> void:
	pass


func _on_tick() -> void:
	pass


func _on_stepped_on(_stepper: Node) -> void:
	pass


# === Grid registration methods — do NOT override ===

func place_on_grid(pos: Vector2i) -> void:
	grid_position = pos
	global_position = GridWorld.grid_to_world(pos)
	GridWorld.register_entity(self, pos)


func remove_from_grid() -> void:
	GridWorld.unregister_entity(self)


func move_to(new_pos: Vector2i) -> void:
	var old_pos := grid_position
	grid_position = new_pos
	GridWorld.move_entity(self, old_pos, new_pos)
