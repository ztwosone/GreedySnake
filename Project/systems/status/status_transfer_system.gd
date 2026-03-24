class_name StatusTransferSystem
extends Node

## 状态转化系统（重写版）
## 蛇：逐段检测所在格状态格，按规则处理
## 敌人：踩格子仍走 StatusEffectManager

var tile_manager: StatusTileManager = null
var snake: Node = null


func _ready() -> void:
	EventBus.snake_moved.connect(_on_snake_moved)
	EventBus.entity_moved.connect(_on_entity_moved)


# === 蛇：逐段检测 ===

func _on_snake_moved(_data: Dictionary) -> void:
	if tile_manager == null or snake == null:
		return
	# 遍历所有蛇身段
	for seg in snake.segments:
		if not is_instance_valid(seg):
			continue
		_check_segment_tile(seg)


func _check_segment_tile(seg: SnakeSegment) -> void:
	var tiles: Array = tile_manager.get_tiles_at(seg.grid_position)
	if tiles.is_empty():
		return

	for tile in tiles:
		if not is_instance_valid(tile):
			continue
		var tile_type: String = tile.status_type

		if seg.carried_status == "":
			# 段无状态 → 获得格子状态
			seg.set_carried_status(tile_type)
			# VFX: 段获得状态弹跳
			VFXManager.scale_bounce(seg, 1.2, 0.1)
		elif seg.carried_status == tile_type:
			# 同类 → 无事发生
			pass
		else:
			# 异类 → 触发反应，段状态清除 + 格子消除
			var reaction_id := Enemy._get_reaction_id(seg.carried_status, tile_type)
			EventBus.reaction_triggered.emit({
				"reaction_id": reaction_id,
				"position": seg.grid_position,
				"type_a": seg.carried_status,
				"type_b": tile_type,
			})
			seg.clear_carried_status()
			tile_manager.remove_tile(seg.grid_position, tile_type)
			break  # 格子已移除，不再遍历该位置的其他格子


# === 敌人：踩格子走 StatusEffectManager ===

func _on_entity_moved(data: Dictionary) -> void:
	var entity: Node = data.get("entity")
	var to: Vector2i = data.get("to", Vector2i(-1, -1))
	if entity == null or tile_manager == null:
		return
	if entity.get("entity_type") == Constants.EntityType.SNAKE_SEGMENT:
		return
	_try_spatial_to_entity(entity, to)


func _try_spatial_to_entity(entity: Node, pos: Vector2i) -> void:
	var tiles: Array = tile_manager.get_tiles_at(pos)
	for tile in tiles:
		if tile is StatusTile:
			StatusEffectManager.apply_status(entity, tile.status_type, "tile")
