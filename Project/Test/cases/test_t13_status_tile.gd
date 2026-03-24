extends RefCounted
## T13 测试：StatusTile 空间状态格 & StatusTileManager


func run(t) -> void:
	# --- 文件/目录存在性 ---
	t.assert_dir_exists("res://entities/status_tiles")
	t.assert_file_exists("res://entities/status_tiles/status_tile.gd")
	t.assert_file_exists("res://entities/status_tiles/status_tile_manager.gd")

	# --- EventBus 信号存在性 ---
	t.assert_has_signal(EventBus, "status_tile_placed")
	t.assert_has_signal(EventBus, "status_tile_removed")
	t.assert_has_signal(EventBus, "entity_entered_status_tile")

	# --- StatusTile 字段检查 ---
	var tile := StatusTile.new()
	t.assert_true(tile is GridEntity, "StatusTile extends GridEntity")
	t.assert_true(tile is Node2D, "StatusTile is Node2D (via GridEntity)")
	t.assert_true("status_type" in tile, "has status_type field")
	t.assert_true("layer" in tile, "has layer field")
	t.assert_true("duration" in tile, "has duration field")
	t.assert_true("tile_color" in tile, "has tile_color field")
	t.assert_eq(tile.entity_type, Constants.EntityType.STATUS_TILE, "entity_type == STATUS_TILE")
	t.assert_eq(tile.blocks_movement, false, "blocks_movement == false")
	t.assert_eq(tile.is_solid, false, "is_solid == false")
	t.assert_eq(tile.cell_layer, 0, "cell_layer == 0 (ground layer)")
	tile.queue_free()

	# --- StatusTile.setup ---
	var tile2 := StatusTile.new()
	Engine.get_main_loop().root.add_child(tile2)
	tile2.setup("fire", 1, 8.0, Color.RED)
	t.assert_eq(tile2.status_type, "fire", "setup: status_type == fire")
	t.assert_eq(tile2.layer, 1, "setup: layer == 1")
	t.assert_eq(tile2.duration, 8.0, "setup: duration == 8.0")
	t.assert_eq(tile2.max_duration, 8.0, "setup: max_duration == 8.0")
	t.assert_eq(tile2.tile_color, Color.RED, "setup: tile_color == RED")

	# --- StatusTile.add_layer ---
	tile2.add_layer()
	t.assert_eq(tile2.layer, 2, "add_layer: layer == 2")
	t.assert_eq(tile2.duration, 8.0, "add_layer: duration refreshed to max")

	# --- StatusTile.tick_duration ---
	tile2.duration = 2.0
	var expired: bool = tile2.tick_duration(1.0)
	t.assert_eq(expired, false, "tick_duration 1.0: not expired (1.0 remaining)")
	t.assert_eq(tile2.duration, 1.0, "tick_duration: duration decremented to 1.0")
	expired = tile2.tick_duration(1.5)
	t.assert_eq(expired, true, "tick_duration 1.5: expired")
	tile2.queue_free()

	# --- StatusTileManager ---
	var mgr := StatusTileManager.new()
	Engine.get_main_loop().root.add_child(mgr)

	# 方法存在性
	t.assert_true(mgr.has_method("place_tile"), "has place_tile()")
	t.assert_true(mgr.has_method("remove_tile"), "has remove_tile()")
	t.assert_true(mgr.has_method("get_tile"), "has get_tile()")
	t.assert_true(mgr.has_method("get_tiles_at"), "has get_tiles_at()")
	t.assert_true(mgr.has_method("has_tile"), "has has_tile()")
	t.assert_true(mgr.has_method("clear_all"), "has clear_all()")

	# --- place_tile ---
	var placed_events: Array = []
	var _on_placed := func(data: Dictionary) -> void:
		placed_events.append(data)
	EventBus.status_tile_placed.connect(_on_placed)

	var pos1 := Vector2i(5, 5)
	var t1: StatusTile = mgr.place_tile(pos1, "fire")
	t.assert_true(t1 != null, "place_tile returns StatusTile")
	t.assert_eq(t1.status_type, "fire", "placed tile type == fire")
	t.assert_eq(t1.layer, 1, "placed tile layer == 1")
	t.assert_true(t1.duration > 0.0, "placed tile duration > 0")
	t.assert_eq(t1.grid_position, pos1, "placed tile grid_position == (5,5)")
	t.assert_eq(placed_events.size(), 1, "status_tile_placed emitted once")
	if placed_events.size() > 0:
		t.assert_eq(placed_events[0].get("position"), pos1, "signal: position")
		t.assert_eq(placed_events[0].get("type"), "fire", "signal: type")
		t.assert_eq(placed_events[0].get("layer"), 1, "signal: layer")

	# --- has_tile / get_tile ---
	t.assert_true(mgr.has_tile(pos1, "fire"), "has_tile fire == true")
	t.assert_true(not mgr.has_tile(pos1, "ice"), "has_tile ice == false")
	var got: StatusTile = mgr.get_tile(pos1, "fire")
	t.assert_true(got != null, "get_tile fire != null")
	t.assert_eq(got, t1, "get_tile returns same instance")
	var got_null: StatusTile = mgr.get_tile(pos1, "ice")
	t.assert_true(got_null == null, "get_tile ice == null")

	# --- get_tiles_at ---
	var tiles_at: Array = mgr.get_tiles_at(pos1)
	t.assert_eq(tiles_at.size(), 1, "get_tiles_at size == 1")

	# --- 同位置同类型叠层 ---
	placed_events.clear()
	var t1_again: StatusTile = mgr.place_tile(pos1, "fire")
	t.assert_eq(t1_again, t1, "place_tile same pos+type returns same instance")
	t.assert_eq(t1.layer, 2, "same-type stacks: layer == 2")
	t.assert_eq(placed_events.size(), 1, "stacking emits status_tile_placed")

	# --- 同位置不同类型 → 触发反应，双方消除 ---
	var reaction_events: Array = []
	var _on_reaction := func(data: Dictionary) -> void:
		reaction_events.append(data)
	EventBus.reaction_triggered.connect(_on_reaction)

	var t2: StatusTile = mgr.place_tile(pos1, "ice")
	t.assert_true(t2 == null, "place ice on fire pos returns null (reaction)")
	t.assert_true(not mgr.has_tile(pos1, "fire"), "fire consumed by reaction")
	t.assert_true(not mgr.has_tile(pos1, "ice"), "ice not placed (reaction)")
	t.assert_eq(reaction_events.size(), 1, "reaction_triggered emitted")
	if reaction_events.size() > 0:
		t.assert_eq(reaction_events[0].get("reaction_id"), "steam", "fire+ice = steam")

	EventBus.reaction_triggered.disconnect(_on_reaction)
	EventBus.status_tile_placed.disconnect(_on_placed)

	# --- remove_tile ---
	# Re-place a tile for remove test
	var t_for_remove: StatusTile = mgr.place_tile(pos1, "poison")
	var removed_events: Array = []
	var _on_removed := func(data: Dictionary) -> void:
		removed_events.append(data)
	EventBus.status_tile_removed.connect(_on_removed)

	mgr.remove_tile(pos1, "poison")
	t.assert_true(not mgr.has_tile(pos1, "poison"), "poison removed")
	t.assert_eq(removed_events.size(), 1, "status_tile_removed emitted once")
	if removed_events.size() > 0:
		t.assert_eq(removed_events[0].get("type"), "poison", "removed signal: type == poison")

	EventBus.status_tile_removed.disconnect(_on_removed)

	# --- 不同位置独立（状态格永久存在） ---
	var pos2 := Vector2i(10, 10)
	var t3: StatusTile = mgr.place_tile(pos2, "poison")
	t.assert_true(mgr.has_tile(pos2, "poison"), "poison at pos2 exists")
	t.assert_true(not mgr.has_tile(pos1, "poison"), "poison not at pos1")

	# --- clear_all ---
	mgr.place_tile(Vector2i(1, 1), "fire")
	mgr.clear_all()
	t.assert_true(not mgr.has_tile(pos2, "poison"), "poison gone after clear_all")
	t.assert_true(not mgr.has_tile(Vector2i(1, 1), "fire"), "fire gone after clear_all")

	# --- GridWorld 注册检查 ---
	GridWorld.clear_all()
	var pos3 := Vector2i(3, 3)
	var t4: StatusTile = mgr.place_tile(pos3, "fire")
	var entities: Array = GridWorld.get_entities_at(pos3)
	t.assert_true(entities.size() > 0, "StatusTile registered in GridWorld")
	var found_tile: bool = false
	for e in entities:
		if e == t4:
			found_tile = true
			break
	t.assert_true(found_tile, "StatusTile found in GridWorld entities at pos")

	# Check entity_type in GridWorld
	var gw_tile: Node = GridWorld.get_first_entity_of_type(pos3, Constants.EntityType.STATUS_TILE)
	t.assert_true(gw_tile != null, "get_first_entity_of_type finds STATUS_TILE")

	# --- 清理 ---
	mgr.clear_all()
	GridWorld.clear_all()
	mgr.queue_free()
