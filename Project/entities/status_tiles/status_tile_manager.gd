class_name StatusTileManager
extends Node

## StatusTile 生命周期管理器
## 作为场景节点加入 GameWorld（非 Autoload）。

# { Vector2i → { String → StatusTile } }
var _tiles: Dictionary = {}
var max_tiles: int = 100
var _tile_order: Array = []  # 按创建顺序排列的 [pos, type] 对


func _process(delta: float) -> void:
	tick_update(delta)


func tick_update(delta: float) -> void:
	var expired: Array = []
	for pos in _tiles:
		var type_map: Dictionary = _tiles[pos]
		for type in type_map:
			var tile: StatusTile = type_map[type]
			if tile.tick_duration(delta):
				expired.append({ "pos": pos, "type": type })

	for entry in expired:
		_remove_tile_internal(entry["pos"], entry["type"], "expired")


func place_tile(pos: Vector2i, type: String, p_layer: int = 1) -> StatusTile:
	# 同位置同类型 → 叠层
	if _tiles.has(pos) and _tiles[pos].has(type):
		var existing: StatusTile = _tiles[pos][type]
		var old_layer: int = existing.layer
		existing.add_layer()
		EventBus.status_tile_placed.emit({
			"position": pos,
			"type": type,
			"layer": existing.layer,
		})
		return existing

	# 超过上限时移除最旧的
	_enforce_tile_cap()

	# 新建 StatusTile
	var cfg_node = Engine.get_main_loop().root.get_node_or_null("ConfigManager")
	var cfg_data: Dictionary = {}
	if cfg_node:
		cfg_data = cfg_node.get_status_effect(type)

	var tile_duration: float = float(cfg_data.get("tile_duration", 8.0))
	var color_hex: String = cfg_data.get("color", "#FFFFFF")
	var tile_color := Color.from_string(color_hex, Color.WHITE)

	var tile := StatusTile.new()
	tile.setup(type, p_layer, tile_duration, tile_color)

	if not _tiles.has(pos):
		_tiles[pos] = {}
	_tiles[pos][type] = tile

	add_child(tile)
	tile.place_on_grid(pos)

	_tile_order.append([pos, type])

	EventBus.status_tile_placed.emit({
		"position": pos,
		"type": type,
		"layer": tile.layer,
	})

	return tile


func remove_tile(pos: Vector2i, type: String) -> void:
	_remove_tile_internal(pos, type, "manual")


func _remove_tile_internal(pos: Vector2i, type: String, reason: String) -> void:
	if not _tiles.has(pos):
		return
	if not _tiles[pos].has(type):
		return

	var tile: StatusTile = _tiles[pos][type]
	_tiles[pos].erase(type)
	if _tiles[pos].is_empty():
		_tiles.erase(pos)

	tile.remove_from_grid()
	tile.queue_free()

	# 从顺序列表中移除
	for i in range(_tile_order.size() - 1, -1, -1):
		if _tile_order[i][0] == pos and _tile_order[i][1] == type:
			_tile_order.remove_at(i)
			break

	EventBus.status_tile_removed.emit({
		"position": pos,
		"type": type,
	})


func get_tile(pos: Vector2i, type: String) -> StatusTile:
	if not _tiles.has(pos):
		return null
	return _tiles[pos].get(type, null)


func get_tiles_at(pos: Vector2i) -> Array:
	if not _tiles.has(pos):
		return []
	return _tiles[pos].values()


func has_tile(pos: Vector2i, type: String) -> bool:
	if not _tiles.has(pos):
		return false
	return _tiles[pos].has(type)


func get_tile_count() -> int:
	var count: int = 0
	for pos in _tiles:
		count += _tiles[pos].size()
	return count


func _enforce_tile_cap() -> void:
	while get_tile_count() >= max_tiles and not _tile_order.is_empty():
		var oldest: Array = _tile_order[0]
		_remove_tile_internal(oldest[0], oldest[1], "cap_exceeded")


func clear_all() -> void:
	for pos in _tiles:
		var type_map: Dictionary = _tiles[pos]
		for type in type_map:
			var tile: StatusTile = type_map[type]
			tile.remove_from_grid()
			tile.queue_free()
	_tiles.clear()
	_tile_order.clear()
