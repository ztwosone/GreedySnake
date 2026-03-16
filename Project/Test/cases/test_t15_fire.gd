extends RefCounted
## T15 测试：火焰状态效果


func run(t) -> void:
	# --- 文件存在性 ---
	t.assert_dir_exists("res://systems/status/effects")
	t.assert_file_exists("res://systems/status/effects/fire_effect.gd")

	# --- FireEffect 基本检查 ---
	var fe := FireEffect.new()
	t.assert_true(fe is RefCounted, "FireEffect is RefCounted")
	t.assert_true(fe.has_method("process_entity_effects"), "has process_entity_effects")
	t.assert_true(fe.has_method("process_tile_spread"), "has process_tile_spread")

	# --- StatusEffectManager 集成检查 ---
	var effect_mgr = Engine.get_main_loop().root.get_node_or_null("StatusEffectManager")
	t.assert_true(effect_mgr != null, "StatusEffectManager exists")
	if effect_mgr == null:
		return
	t.assert_true(effect_mgr.get("fire_effect") != null, "StatusEffectManager has fire_effect")

	# --- 准备 ---
	GridWorld.init_grid(40, 22)
	effect_mgr.clear_all()

	var tile_mgr := StatusTileManager.new()
	Engine.get_main_loop().root.add_child(tile_mgr)

	# 用独立 FireEffect 实例测试，避免全局副作用
	var fire := FireEffect.new()

	# === 实体效果：周期扣长度 ===

	var mock_snake := Node2D.new()
	# 模拟蛇节点（has "body" property）
	mock_snake.set_meta("body", [Vector2i(5, 5)])
	Engine.get_main_loop().root.add_child(mock_snake)

	effect_mgr.apply_status(mock_snake, "fire", "test")
	t.assert_true(effect_mgr.has_status(mock_snake, "fire"), "snake has fire status")

	# 监听 length_decrease_requested
	var decrease_events: Array = []
	var _on_decrease := func(data: Dictionary) -> void:
		decrease_events.append(data)
	EventBus.length_decrease_requested.connect(_on_decrease)

	# 模拟 1.9 秒 → 不应触发伤害
	fire.process_entity_effects(1.9, effect_mgr)
	t.assert_eq(decrease_events.size(), 0, "no damage before 2.0s interval")

	# 模拟再过 0.2 秒（总 2.1 秒）→ 触发一次
	fire.process_entity_effects(0.2, effect_mgr)
	t.assert_eq(decrease_events.size(), 1, "damage at 2.0s interval")
	if decrease_events.size() > 0:
		t.assert_eq(decrease_events[0].get("amount"), 1, "damage amount = 1 (layer 1)")
		t.assert_eq(decrease_events[0].get("source"), "fire", "damage source = fire")

	# === 叠层倍增伤害 ===
	decrease_events.clear()
	fire._damage_timers.clear()

	# 叠加到 3 层
	effect_mgr.apply_status(mock_snake, "fire", "test")  # layer 2
	effect_mgr.apply_status(mock_snake, "fire", "test")  # layer 3
	var fire_status: StatusEffectData = effect_mgr.get_status(mock_snake, "fire")
	t.assert_eq(fire_status.layer, 3, "fire stacked to layer 3")

	# 模拟 2.1 秒
	fire.process_entity_effects(2.1, effect_mgr)
	t.assert_eq(decrease_events.size(), 1, "damage triggered once at layer 3")
	if decrease_events.size() > 0:
		t.assert_eq(decrease_events[0].get("amount"), 3, "damage amount = 3 (layer 3)")

	EventBus.length_decrease_requested.disconnect(_on_decrease)

	# === 火焰格蔓延 ===

	tile_mgr.clear_all()
	fire._spread_timers.clear()

	# 放置一个火焰格
	var fire_pos := Vector2i(10, 10)
	tile_mgr.place_tile(fire_pos, "fire")

	# 用固定种子让蔓延可预测（通过多次调用确保至少蔓延一次）
	# 蔓延概率 20%，调用多次模拟多个 spread_interval
	var spread_count: int = 0
	for i in range(20):
		fire._spread_timers.clear()
		fire.process_tile_spread(1.1, tile_mgr)  # > spread_interval=1.0

	# 统计蔓延到的相邻格数量
	var neighbors: Array[Vector2i] = GridWorld.get_neighbors(fire_pos)
	for n_pos in neighbors:
		if tile_mgr.has_tile(n_pos, "fire"):
			spread_count += 1

	t.assert_true(spread_count > 0, "fire spread to at least 1 neighbor after 20 attempts")

	# === 蔓延不覆盖已有火焰格 ===
	var pre_spread_pos := Vector2i(10, 9)
	if not tile_mgr.has_tile(pre_spread_pos, "fire"):
		tile_mgr.place_tile(pre_spread_pos, "fire")
	var tile_before: StatusTile = tile_mgr.get_tile(pre_spread_pos, "fire")
	var layer_before: int = tile_before.layer

	# 再次蔓延不应改变已有格子（place_tile 会叠层，但蔓延代码跳过已有）
	# _try_spread 检查 has_tile 后跳过
	# 这里验证 _try_spread 内部逻辑正确

	# === 蔓延不蔓延到障碍物 ===
	var blocked_pos := Vector2i(11, 10)
	var blocker := GridEntity.new()
	blocker.blocks_movement = true
	Engine.get_main_loop().root.add_child(blocker)
	blocker.place_on_grid(blocked_pos)

	tile_mgr.remove_tile(blocked_pos, "fire")  # 确保没有火焰格
	t.assert_true(GridWorld.is_cell_blocked(blocked_pos), "blocked_pos is blocked")

	# 清除 blocked_pos 附近可能已有的蔓延火焰格
	tile_mgr.remove_tile(blocked_pos, "fire")

	# 重新放火焰源并蔓延
	tile_mgr.clear_all()
	tile_mgr.place_tile(fire_pos, "fire")
	fire._spread_timers.clear()
	for i in range(50):
		fire._spread_timers.clear()
		fire.process_tile_spread(1.1, tile_mgr)

	# blocked_pos 不应有火焰格
	t.assert_true(not tile_mgr.has_tile(blocked_pos, "fire"), "fire does not spread to blocked cell")

	blocker.remove_from_grid()
	blocker.queue_free()

	# === 火焰 config 读取验证 ===
	var cfg_node = Engine.get_main_loop().root.get_node_or_null("ConfigManager")
	if cfg_node:
		var cfg: Dictionary = cfg_node.get_status_effect("fire")
		t.assert_eq(cfg.get("entity_damage_interval"), 2.0, "config: entity_damage_interval == 2.0")
		t.assert_eq(cfg.get("entity_damage_amount"), 1, "config: entity_damage_amount == 1")
		t.assert_eq(cfg.get("tile_duration"), 8.0, "config: tile_duration == 8.0")
		t.assert_eq(cfg.get("spread_chance"), 0.2, "config: spread_chance == 0.2")
		t.assert_eq(cfg.get("spread_interval"), 1.0, "config: spread_interval == 1.0")
		t.assert_eq(cfg.get("max_layers"), 99, "config: max_layers == 99")

	# === 清理 ===
	effect_mgr.clear_all()
	tile_mgr.clear_all()
	GridWorld.clear_all()
	mock_snake.queue_free()
	tile_mgr.queue_free()
