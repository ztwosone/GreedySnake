extends RefCounted
## T15 测试：火焰状态效果（通过原子系统）


func run(t) -> void:
	# --- StatusEffectManager 集成检查 ---
	var effect_mgr = StatusEffectManager
	t.assert_true(effect_mgr != null, "StatusEffectManager exists")
	if effect_mgr == null:
		return

	# --- 准备 ---
	GridWorld.init_grid(40, 22)
	effect_mgr.clear_all()

	var tile_mgr := StatusTileManager.new()
	Engine.get_main_loop().root.add_child(tile_mgr)

	# === 实体效果：火焰状态施加与叠层 ===

	var mock_snake := Node2D.new()
	mock_snake.set_meta("body", [Vector2i(5, 5)])
	Engine.get_main_loop().root.add_child(mock_snake)

	effect_mgr.apply_status(mock_snake, "fire", "test")
	t.assert_true(effect_mgr.has_status(mock_snake, "fire"), "snake has fire status")

	var fire_status: StatusEffectData = effect_mgr.get_status(mock_snake, "fire")
	t.assert_eq(fire_status.layer, 1, "fire at layer 1")

	# 叠加到 3 层
	effect_mgr.apply_status(mock_snake, "fire", "test")  # layer 2
	effect_mgr.apply_status(mock_snake, "fire", "test")  # layer 3
	fire_status = effect_mgr.get_status(mock_snake, "fire")
	t.assert_eq(fire_status.layer, 3, "fire stacked to layer 3")

	# 验证有 atom chains
	t.assert_true(fire_status.chains.size() > 0, "fire effect has atom chains")

	# === 状态移除 ===
	effect_mgr.remove_status(mock_snake, "fire")
	t.assert_true(not effect_mgr.has_status(mock_snake, "fire"), "fire removed")

	# === 火焰格放置与实体进入 ===

	tile_mgr.clear_all()
	var fire_pos := Vector2i(10, 10)
	tile_mgr.place_tile(fire_pos, "fire")
	t.assert_true(tile_mgr.has_tile(fire_pos, "fire"), "fire tile placed")

	# === 火焰 config 读取验证 ===
	var cfg_node = ConfigManager
	if cfg_node:
		var cfg: Dictionary = cfg_node.get_status_effect("fire")
		t.assert_eq(cfg.get("entity_damage_interval"), 2.0, "config: entity_damage_interval == 2.0")
		t.assert_eq(cfg.get("entity_damage_amount"), 1, "config: entity_damage_amount == 1")
		t.assert_eq(cfg.get("spread_chance"), 0.2, "config: spread_chance == 0.2")
		t.assert_eq(cfg.get("spread_interval"), 1.0, "config: spread_interval == 1.0")
		t.assert_eq(cfg.get("max_layers"), 99, "config: max_layers == 99")
		# entity_effects atom chain 存在
		t.assert_true(cfg.has("entity_effects"), "config has entity_effects")
		t.assert_true(cfg.has("tile_effects"), "config has tile_effects")

	# === 清理 ===
	effect_mgr.clear_all()
	tile_mgr.clear_all()
	GridWorld.clear_all()
	mock_snake.queue_free()
	tile_mgr.queue_free()
