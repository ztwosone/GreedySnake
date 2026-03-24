class_name GridEntity
extends Node2D

var grid_position: Vector2i = Vector2i.ZERO
var entity_type: int = -1
var blocks_movement: bool = false
var is_solid: bool = true
var cell_layer: int = 1

## 运动插值
var _lerp_target: Vector2 = Vector2.ZERO
var _lerp_enabled: bool = false
const LERP_SPEED: float = 15.0  # 约 0.08s 到位（tick 间隔 0.25s 的 1/3）


func _process(delta: float) -> void:
	if not _lerp_enabled:
		return
	if global_position.distance_squared_to(_lerp_target) < 0.5:
		global_position = _lerp_target
		return
	global_position = global_position.lerp(_lerp_target, LERP_SPEED * delta)


# === Visual target (called by GridWorld.move_entity) ===

func _set_visual_target(world_pos: Vector2) -> void:
	_lerp_target = world_pos
	if not _lerp_enabled:
		# 首次（未激活插值）：立即到位
		global_position = world_pos


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
	var world_pos: Vector2 = GridWorld.grid_to_world(pos)
	global_position = world_pos
	_lerp_target = world_pos
	_lerp_enabled = true
	GridWorld.register_entity(self, pos)


func remove_from_grid() -> void:
	GridWorld.unregister_entity(self)


func move_to(new_pos: Vector2i) -> void:
	var old_pos := grid_position
	grid_position = new_pos
	GridWorld.move_entity(self, old_pos, new_pos)
