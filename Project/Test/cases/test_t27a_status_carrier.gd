extends RefCounted
## T27A 测试：StatusCarrier 统一载体 + ReactionResolver + CollisionHandler


func run(t) -> void:
	# --- 文件存在性 ---
	t.assert_file_exists("res://systems/status/reaction_resolver.gd")
	t.assert_file_exists("res://systems/status/collision_handler.gd")

	# --- EventBus 新信号 ---
	t.assert_has_signal(EventBus, "status_added_to_carrier")
	t.assert_has_signal(EventBus, "status_removed_from_carrier")

	# ═══════════════════════════════════════════
	# StatusCarrier 接口测试（SnakeSegment）
	# ═══════════════════════════════════════════

	var seg := SnakeSegment.new()
	Engine.get_main_loop().root.add_child(seg)

	t.assert_true(seg.has_method("get_statuses"), "SnakeSegment has get_statuses()")
	t.assert_true(seg.has_method("has_status"), "SnakeSegment has has_status()")
	t.assert_true(seg.has_method("add_status"), "SnakeSegment has add_status()")
	t.assert_true(seg.has_method("remove_status"), "SnakeSegment has remove_status()")
	t.assert_true(seg.has_method("clear_all_statuses"), "SnakeSegment has clear_all_statuses()")
	t.assert_true(seg.has_method("get_carrier_type"), "SnakeSegment has get_carrier_type()")
	t.assert_eq(seg.get_carrier_type(), "snake_segment", "carrier_type == snake_segment")

	# add_status
	t.assert_eq(seg.get_statuses().size(), 0, "initially empty")
	var added: bool = seg.add_status("fire")
	t.assert_true(added, "add_status fire returns true")
	t.assert_true(seg.has_status("fire"), "has_status fire")
	t.assert_eq(seg.carried_status, "fire", "compat getter returns fire")

	# 同类型 add 两次 → 只存一个
	var added2: bool = seg.add_status("fire")
	t.assert_true(not added2, "add_status fire again returns false")
	t.assert_eq(seg.get_statuses().size(), 1, "still 1 status after duplicate add")

	# remove_status
	seg.remove_status("fire")
	t.assert_true(not seg.has_status("fire"), "fire removed")
	t.assert_eq(seg.carried_status, "", "compat getter empty after remove")

	# clear_all_statuses
	seg.add_status("ice")
	seg.clear_all_statuses()
	t.assert_eq(seg.get_statuses().size(), 0, "clear_all empties statuses")

	# carried_status setter 兼容
	seg.carried_status = "poison"
	t.assert_true(seg.has_status("poison"), "setter: has_status poison")
	t.assert_eq(seg.get_statuses().size(), 1, "setter: exactly 1 status")
	seg.carried_status = ""
	t.assert_eq(seg.get_statuses().size(), 0, "setter empty: cleared")

	seg.queue_free()

	# ═══════════════════════════════════════════
	# StatusCarrier 接口测试（Enemy）
	# ═══════════════════════════════════════════

	var enemy := Enemy.new()
	Engine.get_main_loop().root.add_child(enemy)

	t.assert_true(enemy.has_method("get_statuses"), "Enemy has get_statuses()")
	t.assert_true(enemy.has_method("has_status"), "Enemy has has_status()")
	t.assert_true(enemy.has_method("add_status"), "Enemy has add_status()")
	t.assert_true(enemy.has_method("get_carrier_type"), "Enemy has get_carrier_type()")
	t.assert_eq(enemy.get_carrier_type(), "enemy", "carrier_type == enemy")

	enemy.add_status("fire")
	t.assert_eq(enemy.carried_status, "fire", "enemy compat getter after add_status")
	enemy.clear_all_statuses()
	t.assert_eq(enemy.carried_status, "", "enemy compat getter after clear_all")

	enemy.queue_free()

	# ═══════════════════════════════════════════
	# StatusCarrier 接口测试（StatusTile）
	# ═══════════════════════════════════════════

	var tile := StatusTile.new()
	Engine.get_main_loop().root.add_child(tile)
	tile.setup("fire", Color.RED)

	t.assert_eq(tile.get_carrier_type(), "status_tile", "tile carrier_type")
	t.assert_true(tile.has_status("fire"), "tile has_status fire")
	t.assert_eq(tile.status_type, "fire", "tile compat getter status_type")

	tile.queue_free()

	# ═══════════════════════════════════════════
	# ReactionResolver
	# ═══════════════════════════════════════════

	var ResolverScript: GDScript = preload("res://systems/status/reaction_resolver.gd")
	var resolver: Node = ResolverScript.new()
	resolver._build_reaction_map()

	t.assert_eq(resolver.find_reaction("fire", "ice"), "steam", "resolver: fire+ice = steam")
	t.assert_eq(resolver.find_reaction("ice", "fire"), "steam", "resolver: order-independent")
	t.assert_eq(resolver.find_reaction("fire", "poison"), "toxic_explosion", "resolver: fire+poison")
	t.assert_eq(resolver.find_reaction("ice", "poison"), "frozen_plague", "resolver: ice+poison")
	t.assert_eq(resolver.find_reaction("fire", "fire"), "", "resolver: same type = empty")
	t.assert_eq(resolver.find_reaction("unknown", "other"), "", "resolver: unknown pair = empty")

	# ═══════════════════════════════════════════
	# CollisionHandler
	# ═══════════════════════════════════════════

	GridWorld.init_grid(40, 22)

	var tile_mgr := StatusTileManager.new()
	Engine.get_main_loop().root.add_child(tile_mgr)
	tile_mgr.reaction_resolver = resolver

	var HandlerScript: GDScript = preload("res://systems/status/collision_handler.gd")
	var handler: Node = HandlerScript.new()
	handler.reaction_resolver = resolver
	handler.tile_manager = tile_mgr
	handler._collision_rules = ConfigManager._data.get("collision_rules", {})

	# --- 段无状态踩格子 → transfer ---
	var seg2 := SnakeSegment.new()
	Engine.get_main_loop().root.add_child(seg2)
	seg2.grid_position = Vector2i(5, 5)

	var tile2 := StatusTile.new()
	Engine.get_main_loop().root.add_child(tile2)
	tile2.setup("fire", Color.RED)
	tile2.grid_position = Vector2i(5, 5)

	var result: Dictionary = handler.handle_collision("segment_on_tile", seg2, tile2)
	t.assert_eq(result.get("action"), "transfer", "empty seg on tile: transfer")
	t.assert_true(seg2.has_status("fire"), "seg got fire from tile")

	# --- 段有同类状态踩格子 → ignore ---
	var result2: Dictionary = handler.handle_collision("segment_on_tile", seg2, tile2)
	t.assert_eq(result2.get("action"), "ignore", "same type: ignore")
	t.assert_true(seg2.has_status("fire"), "seg still has fire")

	# --- 段有异类状态踩格子 → add_and_check → 反应 ---
	var ice_tile := StatusTile.new()
	Engine.get_main_loop().root.add_child(ice_tile)
	ice_tile.setup("ice", Color.CYAN)
	ice_tile.grid_position = Vector2i(5, 5)

	var reaction_events: Array = []
	var _on_reaction := func(data: Dictionary) -> void:
		reaction_events.append(data)
	EventBus.reaction_triggered.connect(_on_reaction)

	var result3: Dictionary = handler.handle_collision("segment_on_tile", seg2, ice_tile)
	t.assert_eq(result3.get("action"), "add_and_check", "diff type: add_and_check")
	t.assert_eq(result3.get("reaction_id"), "steam", "diff type: reaction steam")
	t.assert_true(not seg2.has_status("fire"), "seg fire cleared after reaction")
	t.assert_true(reaction_events.size() >= 1, "reaction_triggered emitted")

	EventBus.reaction_triggered.disconnect(_on_reaction)

	# --- 敌人攻击段 → swap 规则测试 ---
	var atk_enemy := Enemy.new()
	Engine.get_main_loop().root.add_child(atk_enemy)
	atk_enemy.add_status("poison")

	var atk_seg := SnakeSegment.new()
	Engine.get_main_loop().root.add_child(atk_seg)
	atk_seg.grid_position = Vector2i(8, 8)
	# seg 无状态，敌人有 poison → transfer
	var result4: Dictionary = handler.handle_collision("enemy_hit_segment", atk_enemy, atk_seg)
	t.assert_eq(result4.get("action"), "transfer", "enemy_hit_segment: transfer to empty seg")

	# --- collision_rules 配置检查 ---
	var cfg: Dictionary = ConfigManager._data.get("collision_rules", {})
	t.assert_true(cfg.has("segment_on_tile"), "config has segment_on_tile rule")
	t.assert_true(cfg.has("enemy_on_tile"), "config has enemy_on_tile rule")
	t.assert_true(cfg.has("tile_on_tile"), "config has tile_on_tile rule")
	t.assert_true(cfg.has("head_eat_enemy"), "config has head_eat_enemy rule")
	t.assert_true(cfg.has("enemy_hit_segment"), "config has enemy_hit_segment rule")

	# === 清理 ===
	tile_mgr.clear_all()
	tile_mgr.queue_free()
	GridWorld.clear_all()
