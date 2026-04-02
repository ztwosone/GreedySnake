class_name StatusTransferSystem
extends Node

## 状态转化系统（T27A 重构版）
## 委托 CollisionHandler 处理所有碰撞逻辑

var tile_manager: StatusTileManager = null
var snake: Node = null
var collision_handler: Node = null  ## CollisionHandler


func _ready() -> void:
	EventBus.snake_moved.connect(_on_snake_moved)
	EventBus.entity_moved.connect(_on_entity_moved)


# === 蛇：逐段检测 ===

func _on_snake_moved(_data: Dictionary) -> void:
	if tile_manager == null or snake == null:
		return
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
		if collision_handler:
			var result: Dictionary = collision_handler.handle_collision("segment_on_tile", seg, tile)
			# VFX: 段获得状态弹跳
			if result.get("action") == "transfer" or (not seg.get_statuses().is_empty()):
				VFXManager.scale_bounce(seg, 1.2, 0.1)
			if result.get("reaction_id", "") != "":
				break  # 反应后格子已移除，不再遍历
		else:
			# fallback: 无 CollisionHandler 时直接处理
			_check_segment_tile_legacy(seg, tile)


func _check_segment_tile_legacy(seg: SnakeSegment, tile: StatusTile) -> void:
	## Legacy fallback（测试环境中可能未注入 CollisionHandler）
	var tile_type: String = tile.status_type
	if seg.carried_status == "":
		seg.set_carried_status(tile_type)
		VFXManager.scale_bounce(seg, 1.2, 0.1)
	elif seg.carried_status == tile_type:
		pass
	else:
		seg.clear_carried_status()
		tile_manager.remove_tile(seg.grid_position, tile_type)


# === 敌人：踩格子 ===

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
		if not tile is StatusTile:
			continue

		# 非 Enemy 实体走原有 StatusEffectManager 路径
		if not entity is Enemy:
			StatusEffectManager.apply_status(entity, tile.status_type, "tile")
			continue

		if collision_handler:
			var result: Dictionary = collision_handler.handle_collision("enemy_on_tile", entity, tile)
			if result.get("reaction_id", "") != "":
				break
		else:
			_try_enemy_tile_legacy(entity as Enemy, tile)


func _try_enemy_tile_legacy(enemy: Enemy, tile: StatusTile) -> void:
	## Legacy fallback
	var tile_type: String = tile.status_type
	if enemy.carried_status == "":
		enemy.set_carried_status_visual(tile_type)
	elif enemy.carried_status == tile_type:
		pass
	else:
		enemy.clear_carried_status()
		tile_manager.remove_tile(tile.grid_position, tile_type)
