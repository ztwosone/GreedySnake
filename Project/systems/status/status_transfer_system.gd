class_name StatusTransferSystem
extends Node

## 实体↔空间状态转化系统
## 监听移动事件，处理 StatusTile ↔ StatusEffect 双向转化。

var tile_manager: StatusTileManager = null

# 防循环：本 tick 内从空间获得状态的类型集合（以 snake instance_id 为 key）
var _freshly_applied: Dictionary = {}  # { instance_id → { type → true } }

# 实体→空间转移计数器（如毒的 trail_interval）
var _transfer_counters: Dictionary = {}  # { "type" → int }


func _ready() -> void:
	EventBus.snake_moved.connect(_on_snake_moved)
	EventBus.entity_moved.connect(_on_entity_moved)
	EventBus.tick_post_process.connect(_on_tick_post)


func _on_tick_post(_tick_index: int) -> void:
	_freshly_applied.clear()


# === 空间→实体：实体移动到 StatusTile 所在格 ===

func _on_entity_moved(data: Dictionary) -> void:
	var entity: Node = data.get("entity")
	var to: Vector2i = data.get("to", Vector2i(-1, -1))
	if entity == null or tile_manager == null:
		return
	# 蛇的 segment 移动不走这条路径（走 _on_snake_moved）
	if entity.get("entity_type") == Constants.EntityType.SNAKE_SEGMENT:
		return
	_try_spatial_to_entity(entity, to)


func _on_snake_moved(data: Dictionary) -> void:
	if tile_manager == null:
		return

	var head_pos: Vector2i = data.get("head_pos", Vector2i(-1, -1))
	var vacated_pos: Vector2i = data.get("vacated_pos", Vector2i(-1, -1))

	# 找到 Snake 节点（状态施加在 Snake 上，不在单个 segment 上）
	var snake: Node = _get_snake_node()
	if snake == null:
		return

	# 1. 空间→实体：蛇头踩入状态格
	_try_spatial_to_entity(snake, head_pos)

	# 2. 实体→空间：旧尾位置离开，检查蛇是否携带状态
	if vacated_pos != Vector2i(-1, -1):
		_try_entity_to_spatial(snake, vacated_pos)


func _try_spatial_to_entity(entity: Node, pos: Vector2i) -> void:
	var tiles: Array = tile_manager.get_tiles_at(pos)
	for tile in tiles:
		if tile is StatusTile:
			_transfer_spatial_to_entity(entity, tile)


func _transfer_spatial_to_entity(entity: Node, tile: StatusTile) -> void:
	var mgr = Engine.get_main_loop().root.get_node_or_null("StatusEffectManager")
	if mgr == null:
		return
	mgr.apply_status(entity, tile.status_type, "tile")

	# 标记防循环
	var eid: int = entity.get_instance_id()
	if not _freshly_applied.has(eid):
		_freshly_applied[eid] = {}
	_freshly_applied[eid][tile.status_type] = true


# === 实体→空间：带状态的蛇离开格子时放置 StatusTile ===

func _try_entity_to_spatial(snake: Node, vacated_pos: Vector2i) -> void:
	var mgr = Engine.get_main_loop().root.get_node_or_null("StatusEffectManager")
	if mgr == null:
		return

	var snake_id: int = snake.get_instance_id()
	var statuses: Array = mgr.get_statuses(snake)

	for s in statuses:
		var stype: String = s.type
		# 防循环：本 tick 刚从空间获得的状态不回写
		if _freshly_applied.has(snake_id) and _freshly_applied[snake_id].has(stype):
			continue
		if _should_transfer_to_spatial(stype):
			_transfer_entity_to_spatial(vacated_pos, stype)


func _transfer_entity_to_spatial(pos: Vector2i, type: String) -> void:
	if tile_manager == null:
		return
	tile_manager.place_tile(pos, type, 1)


func _should_transfer_to_spatial(type: String) -> bool:
	## 判断是否满足实体→空间转化条件
	var cfg_node = Engine.get_main_loop().root.get_node_or_null("ConfigManager")
	if cfg_node == null:
		return true

	var cfg: Dictionary = cfg_node.get_status_effect(type)

	# trail_interval: 每移动 N 格留 1 格（如毒 = 3）
	var trail_interval: int = int(cfg.get("trail_interval", 1))
	if trail_interval <= 1:
		return true

	# 全局计数器（以状态类型为 key）
	if not _transfer_counters.has(type):
		_transfer_counters[type] = 0

	_transfer_counters[type] += 1
	if _transfer_counters[type] >= trail_interval:
		_transfer_counters[type] = 0
		return true
	return false


# === 辅助方法 ===

func _get_snake_node() -> Node:
	## 找到场景中的 Snake 节点
	var game_world = get_parent()
	if game_world and game_world.has_node("EntityContainer/Snake"):
		return game_world.get_node("EntityContainer/Snake")
	# fallback: 在 GridWorld 中找蛇头 segment，取其 parent
	for pos in GridWorld.cell_map:
		var entities: Array = GridWorld.cell_map[pos]
		for e in entities:
			if e.get("entity_type") == Constants.EntityType.SNAKE_SEGMENT:
				if e.get("segment_type") == SnakeSegment.HEAD:
					return e.get_parent()
	return null

func _get_snake_head_entity(pos: Vector2i) -> Node:
	if pos == Vector2i(-1, -1):
		return null
	var entities: Array = GridWorld.get_entities_at(pos)
	for e in entities:
		if e.get("entity_type") == Constants.EntityType.SNAKE_SEGMENT:
			if e.get("segment_type") == SnakeSegment.HEAD:
				return e
	return null
