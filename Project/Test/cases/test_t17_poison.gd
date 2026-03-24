extends RefCounted
## T17 测试：中毒状态效果（通过原子系统）


func run(t) -> void:
	# --- StatusEffectManager 集成检查 ---
	var effect_mgr = StatusEffectManager
	t.assert_true(effect_mgr != null, "StatusEffectManager exists")
	if effect_mgr == null:
		return

	# --- 准备 ---
	GridWorld.init_grid(40, 22)
	effect_mgr.clear_all()

	var mock_snake := Node2D.new()
	mock_snake.name = "TestSnakePoison"
	Engine.get_main_loop().root.add_child(mock_snake)

	# === 基本状态施加 ===

	effect_mgr.apply_status(mock_snake, "poison", "test")
	t.assert_true(effect_mgr.has_status(mock_snake, "poison"), "snake has poison status")

	var poison_status: StatusEffectData = effect_mgr.get_status(mock_snake, "poison")
	t.assert_eq(poison_status.layer, 1, "poison at layer 1")
	t.assert_eq(poison_status.max_layers, 3, "poison max_layers == 3")

	# 验证有 atom chains
	t.assert_true(poison_status.chains.size() > 0, "poison effect has atom chains")

	# === 食物增长量减半（通过 atom modify_growth） ===

	var modifier: float = effect_mgr.get_modifier("growth", mock_snake, 1.0)
	t.assert_eq(modifier, 0.5, "growth modifier == 0.5 when poisoned")

	# floor(1 * 0.5) = 0 → +1 变为 +0
	var modified_amount: int = int(floor(1.0 * modifier))
	t.assert_eq(modified_amount, 0, "floor(1 * 0.5) == 0: +1 food becomes +0")

	# floor(2 * 0.5) = 1 → +2 变为 +1
	var modified_amount2: int = int(floor(2.0 * modifier))
	t.assert_eq(modified_amount2, 1, "floor(2 * 0.5) == 1: +2 food becomes +1")

	# 移除后 modifier 恢复
	effect_mgr.remove_status(mock_snake, "poison")
	var no_poison_modifier: float = effect_mgr.get_modifier("growth", mock_snake, 1.0)
	t.assert_eq(no_poison_modifier, 1.0, "growth modifier == 1.0 when no poison")

	# === 毒化触发（3层） ===

	effect_mgr.clear_all()
	effect_mgr.apply_status(mock_snake, "poison", "test")  # layer 1
	effect_mgr.apply_status(mock_snake, "poison", "test")  # layer 2

	# 监听扣长度请求
	var decrease_events: Array = []
	var _on_decrease := func(data: Dictionary) -> void:
		decrease_events.append(data)
	EventBus.length_decrease_requested.connect(_on_decrease)

	# 监听状态移除
	var remove_events: Array = []
	var _on_remove := func(data: Dictionary) -> void:
		remove_events.append(data)
	EventBus.status_removed.connect(_on_remove)

	# layer 3 → on_layer_reach 触发 damage + remove_status atoms
	effect_mgr.apply_status(mock_snake, "poison", "test")  # layer 3

	t.assert_eq(decrease_events.size(), 1, "toxify: length_decrease_requested emitted")
	if decrease_events.size() > 0:
		t.assert_eq(decrease_events[0].get("amount"), 3, "toxify: penalty amount == 3")
		t.assert_eq(decrease_events[0].get("source"), "poison_toxify", "toxify: source == poison_toxify")

	# 毒化后毒层被清除
	t.assert_true(not effect_mgr.has_status(mock_snake, "poison"), "toxify: poison cleared after toxify")

	EventBus.length_decrease_requested.disconnect(_on_decrease)
	EventBus.status_removed.disconnect(_on_remove)

	# === 2层不触发毒化 ===

	effect_mgr.clear_all()
	decrease_events.clear()
	EventBus.length_decrease_requested.connect(_on_decrease)

	effect_mgr.apply_status(mock_snake, "poison", "test")  # layer 1
	effect_mgr.apply_status(mock_snake, "poison", "test")  # layer 2
	poison_status = effect_mgr.get_status(mock_snake, "poison")
	t.assert_eq(poison_status.layer, 2, "poison at layer 2")
	t.assert_eq(decrease_events.size(), 0, "no toxify at layer 2")
	t.assert_true(effect_mgr.has_status(mock_snake, "poison"), "poison still exists at layer 2")

	EventBus.length_decrease_requested.disconnect(_on_decrease)

	# === 毒液格阻止食物生成 ===

	var tile_mgr := StatusTileManager.new()
	Engine.get_main_loop().root.add_child(tile_mgr)

	var poison_pos := Vector2i(5, 5)
	tile_mgr.place_tile(poison_pos, "poison")
	t.assert_true(tile_mgr.has_tile(poison_pos, "poison"), "poison tile placed")

	var test_cells: Array[Vector2i] = [Vector2i(5, 5), Vector2i(6, 6), Vector2i(7, 7)]
	var filtered: Array[Vector2i] = test_cells.filter(func(pos: Vector2i) -> bool:
		return not tile_mgr.has_tile(pos, "poison")
	)
	t.assert_eq(filtered.size(), 2, "poison tile position filtered out from spawn candidates")
	t.assert_true(not filtered.has(Vector2i(5, 5)), "Vector2i(5,5) excluded (has poison tile)")

	# === config 读取验证 ===

	var cfg_node = ConfigManager
	if cfg_node:
		var cfg: Dictionary = cfg_node.get_status_effect("poison")
		t.assert_eq(cfg.get("food_growth_modifier"), 0.5, "config: food_growth_modifier == 0.5")
		t.assert_eq(cfg.get("toxify_at_layer"), 3, "config: toxify_at_layer == 3")
		t.assert_eq(cfg.get("toxify_length_penalty"), 3, "config: toxify_length_penalty == 3")
		t.assert_eq(cfg.get("max_layers"), 3, "config: max_layers == 3")
		t.assert_eq(cfg.get("trail_interval"), 3, "config: trail_interval == 3")
		t.assert_true(cfg.has("entity_effects"), "config has entity_effects")
		t.assert_true(cfg.has("tile_effects"), "config has tile_effects")

	# === 清理 ===
	effect_mgr.clear_all()
	tile_mgr.clear_all()
	GridWorld.clear_all()
	mock_snake.queue_free()
	tile_mgr.queue_free()
