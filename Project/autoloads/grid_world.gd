extends Node

var cell_map: Dictionary = {}
var grid_width: int = Constants.GRID_WIDTH
var grid_height: int = Constants.GRID_HEIGHT


func init_grid(width: int, height: int) -> void:
	cell_map.clear()
	grid_width = width
	grid_height = height


func register_entity(entity: Node, pos: Vector2i) -> void:
	if not cell_map.has(pos):
		cell_map[pos] = []
	cell_map[pos].append(entity)
	EventBus.entity_placed.emit({"entity": entity, "position": pos})


func unregister_entity(entity: Node) -> void:
	for pos in cell_map:
		var arr: Array = cell_map[pos]
		if entity in arr:
			arr.erase(entity)
			if arr.is_empty():
				cell_map.erase(pos)
			EventBus.entity_removed.emit({"entity": entity, "position": pos})
			return


func move_entity(entity: Node, from: Vector2i, to: Vector2i) -> void:
	# 1. Remove from old cell
	if cell_map.has(from):
		cell_map[from].erase(entity)
		if cell_map[from].is_empty():
			cell_map.erase(from)

	# 2. Notify remaining entities at old cell
	if cell_map.has(from):
		for other in cell_map[from]:
			if other.has_method("_on_entity_exit"):
				other._on_entity_exit(entity)

	# 3. Add to new cell
	if not cell_map.has(to):
		cell_map[to] = []
	cell_map[to].append(entity)

	# 4. Notify existing entities at new cell
	for other in cell_map[to]:
		if other == entity:
			continue
		if other.has_method("_on_entity_enter"):
			other._on_entity_enter(entity)

	# 5. Notify ground entities (cell_layer == 0)
	for other in cell_map[to]:
		if other == entity:
			continue
		if other.has_method("_on_stepped_on") and other.get("cell_layer") == 0:
			other._on_stepped_on(entity)

	# 6. Emit event
	EventBus.entity_moved.emit({"entity": entity, "from": from, "to": to})

	# 7. Update visual position (through GridEntity interpolation)
	var target_world_pos: Vector2 = grid_to_world(to)
	if entity.has_method("_set_visual_target"):
		entity._set_visual_target(target_world_pos)
	elif entity.has_method("set") and "global_position" in entity:
		entity.global_position = target_world_pos


func get_entities_at(pos: Vector2i) -> Array:
	if cell_map.has(pos):
		return cell_map[pos].filter(func(e): return is_instance_valid(e))
	return []


func get_first_entity_of_type(pos: Vector2i, type: int) -> Node:
	if not cell_map.has(pos):
		return null
	for entity in cell_map[pos]:
		if not is_instance_valid(entity):
			continue
		if entity.get("entity_type") == type:
			return entity
	return null


func is_cell_blocked(pos: Vector2i) -> bool:
	if not cell_map.has(pos):
		return false
	for entity in cell_map[pos]:
		if not is_instance_valid(entity):
			continue
		if entity.get("blocks_movement") == true:
			return true
	return false


func is_within_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < grid_width and pos.y >= 0 and pos.y < grid_height


func get_neighbors(pos: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir in Constants.DIR_VECTORS.values():
		var neighbor: Vector2i = pos + dir
		if is_within_bounds(neighbor):
			result.append(neighbor)
	return result


func get_empty_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in range(grid_width):
		for y in range(grid_height):
			var pos := Vector2i(x, y)
			if not cell_map.has(pos) or cell_map[pos].is_empty():
				result.append(pos)
	return result


func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		grid_pos.x * Constants.CELL_SIZE + Constants.CELL_SIZE / 2,
		grid_pos.y * Constants.CELL_SIZE + Constants.CELL_SIZE / 2
	)


func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(world_pos.x / Constants.CELL_SIZE),
		int(world_pos.y / Constants.CELL_SIZE)
	)


func clear_all() -> void:
	cell_map.clear()
