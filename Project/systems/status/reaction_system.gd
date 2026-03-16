class_name ReactionSystem
extends Node

## 状态反应检测与执行系统
## 监听 status_applied / status_tile_placed / entity_entered_status_tile
## 检测是否触发反应（火+冰=蒸腾，火+毒=毒爆）

var tile_manager: StatusTileManager = null

# 可插拔反应处理器: { reaction_id → handler }
var _reaction_handlers: Dictionary = {}

# 防止同一 tick 连锁反应
var _reaction_cooldown: bool = false


func _ready() -> void:
	_register_handlers()
	EventBus.status_applied.connect(_on_status_applied)
	EventBus.status_tile_placed.connect(_on_status_tile_placed)
	EventBus.entity_entered_status_tile.connect(_on_entity_entered_tile)
	EventBus.tick_post_process.connect(_on_tick_post)


func _register_handlers() -> void:
	_reaction_handlers["steam"] = SteamReaction.new()
	_reaction_handlers["toxic_explosion"] = ToxicExplosionReaction.new()


func _on_tick_post(_tick_index: int) -> void:
	_reaction_cooldown = false


# === 触发条件 1: 同一实体上两种不同状态 ===

func _on_status_applied(data: Dictionary) -> void:
	if _reaction_cooldown:
		return
	var target: Object = data.get("target")
	var new_type: String = data.get("type", "")
	var source: String = data.get("source", "")
	# 反应产生的状态不触发新反应
	if source.begins_with("reaction_"):
		return
	if target == null or new_type == "":
		return
	_check_entity_reaction(target, new_type)


# === 触发条件 2: 相邻格不同类型 StatusTile ===

func _on_status_tile_placed(data: Dictionary) -> void:
	if _reaction_cooldown:
		return
	var pos: Vector2i = data.get("position", Vector2i(-1, -1))
	var new_type: String = data.get("type", "")
	if pos == Vector2i(-1, -1) or new_type == "":
		return
	_check_spatial_reaction(pos, new_type)


# === 触发条件 3: 带状态实体进入不同类型 StatusTile ===

func _on_entity_entered_tile(data: Dictionary) -> void:
	if _reaction_cooldown:
		return
	var entity: Node = data.get("entity")
	var tile_type: String = data.get("type", "")
	if entity == null or tile_type == "":
		return

	var effect_mgr = Engine.get_main_loop().root.get_node_or_null("StatusEffectManager")
	if effect_mgr == null:
		return

	var statuses: Array = effect_mgr.get_statuses(entity)
	for s in statuses:
		if s.type != tile_type:
			var reaction_cfg: Dictionary = _find_reaction(s.type, tile_type)
			if reaction_cfg.size() > 0:
				var pos: Vector2i = data.get("position", Vector2i(0, 0))
				var tile_layer: int = 1
				if tile_manager and tile_manager.has_tile(pos, tile_type):
					var tile = tile_manager.get_tile(pos, tile_type)
					if tile:
						tile_layer = tile.layer
				_execute_reaction(reaction_cfg, pos, s.layer, tile_layer, entity, s.type, tile_type)
				return


func _check_entity_reaction(target: Object, new_type: String) -> void:
	var effect_mgr = Engine.get_main_loop().root.get_node_or_null("StatusEffectManager")
	if effect_mgr == null:
		return

	var statuses: Array = effect_mgr.get_statuses(target)
	for s in statuses:
		if s.type != new_type:
			var reaction_cfg: Dictionary = _find_reaction(s.type, new_type)
			if reaction_cfg.size() > 0:
				var new_effect: StatusEffectData = effect_mgr.get_status(target, new_type)
				var new_layer: int = new_effect.layer if new_effect else 1
				var pos := Vector2i(0, 0)
				if target is Node2D and target.has_method("get") and target.get("grid_position") != null:
					pos = target.get("grid_position")
				elif target is Node2D:
					pos = Vector2i(int(target.position.x / Constants.CELL_SIZE), int(target.position.y / Constants.CELL_SIZE))
				_execute_reaction(reaction_cfg, pos, s.layer, new_layer, target, s.type, new_type)
				return


func _check_spatial_reaction(pos: Vector2i, new_type: String) -> void:
	if tile_manager == null:
		return

	# 检查同位置不同类型
	var tiles_at: Array = tile_manager.get_tiles_at(pos)
	for tile in tiles_at:
		if tile is StatusTile and tile.status_type != new_type:
			var reaction_cfg: Dictionary = _find_reaction(tile.status_type, new_type)
			if reaction_cfg.size() > 0:
				var new_tile = tile_manager.get_tile(pos, new_type)
				var new_layer: int = new_tile.layer if new_tile else 1
				_execute_reaction(reaction_cfg, pos, tile.layer, new_layer, null, tile.status_type, new_type)
				return

	# 检查相邻格不同类型
	var neighbors: Array[Vector2i] = GridWorld.get_neighbors(pos)
	for n_pos in neighbors:
		if not GridWorld.is_within_bounds(n_pos):
			continue
		var n_tiles: Array = tile_manager.get_tiles_at(n_pos)
		for tile in n_tiles:
			if tile is StatusTile and tile.status_type != new_type:
				var reaction_cfg: Dictionary = _find_reaction(tile.status_type, new_type)
				if reaction_cfg.size() > 0:
					var new_tile = tile_manager.get_tile(pos, new_type)
					var new_layer: int = new_tile.layer if new_tile else 1
					# 反应发生在两个格子的中间位置，取新格位置
					_execute_reaction(reaction_cfg, pos, tile.layer, new_layer, null, tile.status_type, new_type)
					return


func _execute_reaction(reaction_cfg: Dictionary, pos: Vector2i, layer_a: int, layer_b: int, target: Object, type_a: String, type_b: String) -> void:
	_reaction_cooldown = true

	# 消耗参与反应的两种状态
	var effect_mgr = Engine.get_main_loop().root.get_node_or_null("StatusEffectManager")
	if effect_mgr and target:
		effect_mgr.remove_status(target, type_a, "reaction")
		effect_mgr.remove_status(target, type_b, "reaction")

	# 消耗空间状态格
	if tile_manager:
		tile_manager.remove_tile(pos, type_a)
		tile_manager.remove_tile(pos, type_b)

	# 查找并执行反应处理器
	var reaction_id: String = _get_reaction_id(type_a, type_b)
	var handler = _reaction_handlers.get(reaction_id)
	if handler and handler.has_method("execute"):
		handler.execute({
			"position": pos,
			"layer_a": layer_a,
			"layer_b": layer_b,
			"reaction_cfg": reaction_cfg,
			"target": target,
		})


func _find_reaction(type_a: String, type_b: String) -> Dictionary:
	var cfg_node = Engine.get_main_loop().root.get_node_or_null("ConfigManager")
	if cfg_node == null:
		return {}
	return cfg_node.find_reaction(type_a, type_b)


func _get_reaction_id(type_a: String, type_b: String) -> String:
	var cfg_node = Engine.get_main_loop().root.get_node_or_null("ConfigManager")
	if cfg_node == null:
		return ""
	# 遍历 reactions 找到匹配的 id
	for rid in cfg_node.get_reaction_ids():
		var r: Dictionary = cfg_node.get_reaction(rid)
		if (r.get("type_a") == type_a and r.get("type_b") == type_b) or \
		   (r.get("type_a") == type_b and r.get("type_b") == type_a):
			return rid
	return ""
