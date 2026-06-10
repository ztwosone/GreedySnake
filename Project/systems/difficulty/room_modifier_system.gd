class_name RoomModifierSystem
extends Node
## 房间修饰符系统（spec 002 T031 重写-扩展，2026-06-11 重验收——草稿从不被应用）。
## v1 修饰符（FR-009，darkness/speed_strips/mine_tiles 已入 backlog.md）：
## - shield_enemies：布场完成后随机 max_shielded 个敌人 hp += hp_bonus（经 EnemyManager
##   的已生成实体直接加成），并挂可见护盾描边（palette token 描边方块，z 序低于本体；
##   与精英 1.25x/状态描边视觉语言并存，叠加时各自独立可读——spec edge case）；
## - preset_status_tiles：进房经 StatusTileManager 预置 tile_count 个状态格
##   （Designs §11.5「状态格已预置」，复用状态格视觉顺带教学状态系统），
##   位置距蛇头 >= min_distance_from_snake（曼哈顿距离），类型抽自 tile_types。
## 生命周期：修饰符在生成期按 floor.modifier_weights 选定（FloorMapGenerator ⑧，
## 首层全 0 = FR-017 节奏），随房 dict modifiers 字段进场；应用 = RoomDirector 布场后
## 调 apply_modifiers(room)（注入点，先布怪后修饰——护盾需要已生成的敌人）；
## 移除 = room_completed（只回收自己放置的格/盾，不误伤外部状态格）；
## run_started 清账（FR-013）。应用层复核逐项 enabled 开关（生成层之外的纵深防御）。
## 全部数值出自 room_modifiers.<id>.params / .visual（FR-010）。

var _enemy_manager: Node = null
var _tile_manager: Node = null
var _snake: Object = null
var _active_modifiers: Array = []


func _ready() -> void:
	connect_events()


func _exit_tree() -> void:
	disconnect_events()


func setup(enemy_manager: Node, tile_manager: Node, snake: Object = null) -> void:
	_enemy_manager = enemy_manager
	_tile_manager = tile_manager
	_snake = snake


func connect_events() -> void:
	if not EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.connect(_on_room_completed)
	if not EventBus.run_started.is_connected(_on_run_started):
		EventBus.run_started.connect(_on_run_started)


func disconnect_events() -> void:
	if EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.disconnect(_on_room_completed)
	if EventBus.run_started.is_connected(_on_run_started):
		EventBus.run_started.disconnect(_on_run_started)


func cleanup() -> void:
	_revert_all()
	disconnect_events()
	_enemy_manager = null
	_tile_manager = null
	_snake = null


## RoomDirector 注入点：布场完成后转交房 dict（modifiers 由生成器在生成期选定）
func apply_modifiers(room: Dictionary) -> void:
	var room_id: String = str(room.get("room_id", ""))
	if room_id == "":
		return
	remove_modifiers(room_id)  # 重进房先回收旧账（布场已重建，旧引用作废）
	for modifier_id in room.get("modifiers", []):
		apply_modifier(str(modifier_id), room_id)


func apply_modifier(modifier_id: String, room_id: String) -> bool:
	var cfg: Dictionary = ConfigManager.get_room_modifier(modifier_id)
	if cfg.is_empty() or not bool(cfg.get("enabled", false)):
		return false

	var state: Dictionary = {}
	match modifier_id:
		"shield_enemies":
			state = _apply_shield_enemies(cfg)
		"preset_status_tiles":
			state = _apply_preset_status_tiles(cfg)
		_:
			return false  # v1 集合之外（含草稿残留 id）一律拒绝

	_active_modifiers.append({
		"modifier_id": modifier_id,
		"room_id": room_id,
		"state": state,
	})
	EventBus.room_modifier_applied.emit({
		"room_id": room_id,
		"modifier_id": modifier_id,
	})
	return true


func remove_modifiers(room_id: String) -> void:
	for index in range(_active_modifiers.size() - 1, -1, -1):
		if str(_active_modifiers[index].get("room_id", "")) == room_id:
			_revert_modifier(_active_modifiers[index])
			_active_modifiers.remove_at(index)


func get_active_modifiers() -> Array:
	return _active_modifiers.duplicate()


func has_modifier(room_id: String, modifier_id: String) -> bool:
	for entry in _active_modifiers:
		if str(entry.get("room_id", "")) == room_id and str(entry.get("modifier_id", "")) == modifier_id:
			return true
	return false


# ═══ shield_enemies ══════════════════════════════════════════════════════════

func _apply_shield_enemies(cfg: Dictionary) -> Dictionary:
	var params: Dictionary = cfg.get("params", {})
	var hp_bonus: int = maxi(0, int(params.get("hp_bonus", 1)))
	var max_shielded: int = maxi(0, int(params.get("max_shielded", 1)))
	var state: Dictionary = {"shielded": [], "hp_bonus": hp_bonus}
	if _enemy_manager == null or hp_bonus == 0:
		return state

	var candidates: Array = []
	for enemy in _enemy_manager.current_enemies:
		if is_instance_valid(enemy):
			candidates.append(enemy)
	candidates.shuffle()

	for index in range(mini(max_shielded, candidates.size())):
		var enemy: Node = candidates[index]
		enemy.hp += hp_bonus
		enemy.set_meta("room_modifier_shield", hp_bonus)
		_attach_shield_visual(enemy, cfg.get("visual", {}))
		state["shielded"].append(enemy)
	return state


func _remove_shield_enemies(state: Dictionary) -> void:
	var hp_bonus: int = int(state.get("hp_bonus", 0))
	for enemy in state.get("shielded", []):
		if not is_instance_valid(enemy):
			continue
		enemy.hp = maxi(1, enemy.hp - hp_bonus)
		if enemy.has_meta("room_modifier_shield"):
			enemy.remove_meta("room_modifier_shield")
		var outline: Node = enemy.get_node_or_null("ShieldOutline")
		if outline:
			outline.queue_free()


func _attach_shield_visual(enemy: Node, visual_cfg: Dictionary) -> void:
	## 可见护盾描边：palette token 色方块垫在本体之下、比状态描边（3px）再外扩，
	## 叠加时两层描边各自独立可读（spec edge case）
	var token: String = str(visual_cfg.get("outline_palette_token", "text_primary"))
	var palette: Dictionary = ConfigManager.get_presentation_config().get("palette", {})
	var color: Color = Color.from_string(str(palette.get(token, "#E8ECEF")), Color.WHITE)
	color.a = clampf(float(visual_cfg.get("outline_alpha", 0.5)), 0.0, 1.0)
	var pad: float = float(visual_cfg.get("outline_pad", 6.0))
	var full: float = Constants.CELL_SIZE

	var outline := ColorRect.new()
	outline.name = "ShieldOutline"
	outline.size = Vector2(full + pad * 2.0, full + pad * 2.0)
	outline.position = Vector2(-full / 2.0 - pad, -full / 2.0 - pad)
	outline.color = color
	outline.z_index = -2
	enemy.add_child(outline)


# ═══ preset_status_tiles ═════════════════════════════════════════════════════

func _apply_preset_status_tiles(cfg: Dictionary) -> Dictionary:
	var params: Dictionary = cfg.get("params", {})
	var tile_count: int = maxi(0, int(params.get("tile_count", 0)))
	var tile_types: Array = params.get("tile_types", [])
	var min_distance: int = maxi(0, int(params.get("min_distance_from_snake", 0)))
	var state: Dictionary = {"placed": []}
	if _tile_manager == null or tile_count == 0 or tile_types.is_empty():
		return state

	var head: Vector2i = _snake_head()
	var candidates: Array = []
	for cell in GridWorld.get_empty_cells():
		if head == Vector2i(-1000, -1000) or absi(cell.x - head.x) + absi(cell.y - head.y) >= min_distance:
			candidates.append(cell)
	candidates.shuffle()

	for index in range(mini(tile_count, candidates.size())):
		var tile_type: String = str(tile_types[randi() % tile_types.size()])
		var tile = _tile_manager.place_tile(candidates[index], tile_type)
		if tile != null:
			state["placed"].append([candidates[index], tile_type])
	return state


func _remove_preset_status_tiles(state: Dictionary) -> void:
	## 只回收自己放置的格（按 [pos, type] 账本）——不误伤敌人/原子放置的外部状态格
	if _tile_manager == null:
		return
	for entry in state.get("placed", []):
		var pos: Vector2i = entry[0]
		var tile_type: String = str(entry[1])
		if _tile_manager.has_tile(pos, tile_type):
			_tile_manager.remove_tile(pos, tile_type)


func _snake_head() -> Vector2i:
	if _snake == null:
		return Vector2i(-1000, -1000)
	var body = _snake.get("body")
	if body is Array and not body.is_empty():
		return body[0]
	return Vector2i(-1000, -1000)


# ═══ 生命周期 ════════════════════════════════════════════════════════════════

func _revert_modifier(entry: Dictionary) -> void:
	var state: Dictionary = entry.get("state", {})
	match str(entry.get("modifier_id", "")):
		"shield_enemies":
			_remove_shield_enemies(state)
		"preset_status_tiles":
			_remove_preset_status_tiles(state)


func _revert_all() -> void:
	for entry in _active_modifiers:
		_revert_modifier(entry)
	_active_modifiers.clear()


func _on_room_completed(data: Dictionary) -> void:
	remove_modifiers(str(data.get("room_id", "")))


func _on_run_started(_data: Dictionary) -> void:
	## FR-013：run 重启清账（场上实体由 game_world 重建，这里只回收账本与残留效果）
	_revert_all()
