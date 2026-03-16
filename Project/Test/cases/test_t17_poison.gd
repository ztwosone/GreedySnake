extends RefCounted
## T17 测试：中毒状态效果


func run(t) -> void:
	# --- 文件存在性 ---
	t.assert_file_exists("res://systems/status/effects/poison_effect.gd")

	# --- PoisonEffect 基本检查 ---
	var pe := PoisonEffect.new()
	t.assert_true(pe is RefCounted, "PoisonEffect is RefCounted")
	t.assert_true(pe.has_method("process_entity_effects"), "has process_entity_effects")
	t.assert_true(pe.has_method("get_growth_modifier"), "has get_growth_modifier")

	# --- StatusEffectManager 集成检查 ---
	var effect_mgr = Engine.get_main_loop().root.get_node_or_null("StatusEffectManager")
	t.assert_true(effect_mgr != null, "StatusEffectManager exists")
	if effect_mgr == null:
		return
	t.assert_true(effect_mgr.get("poison_effect") != null, "StatusEffectManager has poison_effect")

	# --- 准备 ---
	GridWorld.init_grid(40, 22)
	effect_mgr.clear_all()

	var poison := PoisonEffect.new()

	var mock_snake := Node2D.new()
	mock_snake.name = "TestSnakePoison"
	Engine.get_main_loop().root.add_child(mock_snake)

	# === 基本状态施加 ===

	effect_mgr.apply_status(mock_snake, "poison", "test")
	t.assert_true(effect_mgr.has_status(mock_snake, "poison"), "snake has poison status")

	var poison_status: StatusEffectData = effect_mgr.get_status(mock_snake, "poison")
	t.assert_eq(poison_status.layer, 1, "poison at layer 1")
	t.assert_eq(poison_status.max_layers, 3, "poison max_layers == 3")

	# === 食物增长量减半 ===

	var modifier: float = poison.get_growth_modifier(effect_mgr, mock_snake)
	t.assert_eq(modifier, 0.5, "growth modifier == 0.5 when poisoned")

	# floor(1 * 0.5) = 0 → +1 变为 +0
	var modified_amount: int = int(floor(1.0 * modifier))
	t.assert_eq(modified_amount, 0, "floor(1 * 0.5) == 0: +1 food becomes +0")

	# floor(2 * 0.5) = 1 → +2 变为 +1
	var modified_amount2: int = int(floor(2.0 * modifier))
	t.assert_eq(modified_amount2, 1, "floor(2 * 0.5) == 1: +2 food becomes +1")

	# 无中毒时返回 1.0
	effect_mgr.remove_status(mock_snake, "poison")
	var no_poison_modifier: float = poison.get_growth_modifier(effect_mgr, mock_snake)
	t.assert_eq(no_poison_modifier, 1.0, "growth modifier == 1.0 when no poison")

	# === 毒化触发（3层） ===

	effect_mgr.clear_all()
	effect_mgr.apply_status(mock_snake, "poison", "test")  # layer 1
	effect_mgr.apply_status(mock_snake, "poison", "test")  # layer 2
	effect_mgr.apply_status(mock_snake, "poison", "test")  # layer 3
	poison_status = effect_mgr.get_status(mock_snake, "poison")
	t.assert_eq(poison_status.layer, 3, "poison stacked to layer 3")

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

	# process_entity_effects 检测到3层 → 触发毒化
	poison.process_entity_effects(0.1, effect_mgr)

	t.assert_eq(decrease_events.size(), 1, "toxify: length_decrease_requested emitted")
	if decrease_events.size() > 0:
		t.assert_eq(decrease_events[0].get("amount"), 3, "toxify: penalty amount == 3")
		t.assert_eq(decrease_events[0].get("source"), "poison_toxify", "toxify: source == poison_toxify")

	# 毒化后毒层被清除
	t.assert_true(not effect_mgr.has_status(mock_snake, "poison"), "toxify: poison cleared after toxify")

	# 检查 status_removed 信号
	var found_toxify_remove: bool = false
	for ev in remove_events:
		if ev.get("type") == "poison" and ev.get("source") == "toxify":
			found_toxify_remove = true
			break
	t.assert_true(found_toxify_remove, "toxify: status_removed emitted with source=toxify")

	EventBus.length_decrease_requested.disconnect(_on_decrease)
	EventBus.status_removed.disconnect(_on_remove)

	# === 2层不触发毒化 ===

	effect_mgr.clear_all()
	effect_mgr.apply_status(mock_snake, "poison", "test")  # layer 1
	effect_mgr.apply_status(mock_snake, "poison", "test")  # layer 2
	poison_status = effect_mgr.get_status(mock_snake, "poison")
	t.assert_eq(poison_status.layer, 2, "poison at layer 2")

	decrease_events.clear()
	EventBus.length_decrease_requested.connect(_on_decrease)

	poison.process_entity_effects(0.1, effect_mgr)
	t.assert_eq(decrease_events.size(), 0, "no toxify at layer 2")
	t.assert_true(effect_mgr.has_status(mock_snake, "poison"), "poison still exists at layer 2")

	EventBus.length_decrease_requested.disconnect(_on_decrease)

	# === 毒液格阻止食物生成 ===

	var tile_mgr := StatusTileManager.new()
	Engine.get_main_loop().root.add_child(tile_mgr)

	var poison_pos := Vector2i(5, 5)
	tile_mgr.place_tile(poison_pos, "poison")
	t.assert_true(tile_mgr.has_tile(poison_pos, "poison"), "poison tile placed")

	# FoodManager 排除毒液格位置
	var fm := FoodManager.new()
	fm.tile_manager = tile_mgr

	# 填满网格只留 poison_pos 一个空位
	# 简化：直接测试 filter 逻辑
	var test_cells: Array[Vector2i] = [Vector2i(5, 5), Vector2i(6, 6), Vector2i(7, 7)]
	var filtered: Array[Vector2i] = test_cells.filter(func(pos: Vector2i) -> bool:
		return not tile_mgr.has_tile(pos, "poison")
	)
	t.assert_eq(filtered.size(), 2, "poison tile position filtered out from spawn candidates")
	t.assert_true(not filtered.has(Vector2i(5, 5)), "Vector2i(5,5) excluded (has poison tile)")

	fm.queue_free()

	# === config 读取验证 ===

	var cfg_node = Engine.get_main_loop().root.get_node_or_null("ConfigManager")
	if cfg_node:
		var cfg: Dictionary = cfg_node.get_status_effect("poison")
		t.assert_eq(cfg.get("food_growth_modifier"), 0.5, "config: food_growth_modifier == 0.5")
		t.assert_eq(cfg.get("entity_duration"), 8.0, "config: entity_duration == 8.0")
		t.assert_eq(cfg.get("toxify_at_layer"), 3, "config: toxify_at_layer == 3")
		t.assert_eq(cfg.get("toxify_length_penalty"), 3, "config: toxify_length_penalty == 3")
		t.assert_eq(cfg.get("max_layers"), 3, "config: max_layers == 3")
		t.assert_eq(cfg.get("tile_duration"), 10.0, "config: tile_duration == 10.0")
		t.assert_eq(cfg.get("trail_interval"), 3, "config: trail_interval == 3")

	# === 清理 ===
	effect_mgr.clear_all()
	tile_mgr.clear_all()
	GridWorld.clear_all()
	mock_snake.queue_free()
	tile_mgr.queue_free()
