extends RefCounted
## T16 测试：冰冻状态效果


func run(t) -> void:
	# --- 文件存在性 ---
	t.assert_file_exists("res://systems/status/effects/ice_effect.gd")

	# --- IceEffect 基本检查 ---
	var ie := IceEffect.new()
	t.assert_true(ie is RefCounted, "IceEffect is RefCounted")
	t.assert_true(ie.has_method("process_entity_effects"), "has process_entity_effects")

	# --- StatusEffectManager 集成检查 ---
	var effect_mgr = Engine.get_main_loop().root.get_node_or_null("StatusEffectManager")
	t.assert_true(effect_mgr != null, "StatusEffectManager exists")
	if effect_mgr == null:
		return
	t.assert_true(effect_mgr.get("ice_effect") != null, "StatusEffectManager has ice_effect")

	# --- TickManager 检查 ---
	var tick_mgr = Engine.get_main_loop().root.get_node_or_null("TickManager")
	t.assert_true(tick_mgr != null, "TickManager exists")
	if tick_mgr == null:
		return

	# --- 准备 ---
	GridWorld.init_grid(40, 22)
	effect_mgr.clear_all()

	# 保存原始状态以便恢复
	var original_speed_modifier: float = tick_mgr.tick_speed_modifier
	var original_is_ticking: bool = tick_mgr.is_ticking

	var ice := IceEffect.new()

	var mock_snake := Node2D.new()
	mock_snake.name = "TestSnake"
	Engine.get_main_loop().root.add_child(mock_snake)

	# === 1层冰冻：减速 ===

	effect_mgr.apply_status(mock_snake, "ice", "test")
	t.assert_true(effect_mgr.has_status(mock_snake, "ice"), "snake has ice status")

	var ice_status: StatusEffectData = effect_mgr.get_status(mock_snake, "ice")
	t.assert_eq(ice_status.layer, 1, "ice at layer 1")
	t.assert_eq(ice_status.max_layers, 2, "ice max_layers == 2")

	# 确保 tick_speed_modifier 初始为 1.0
	tick_mgr.tick_speed_modifier = 1.0

	# 处理效果 → 应用减速
	ice.process_entity_effects(0.1, effect_mgr)
	t.assert_eq(tick_mgr.tick_speed_modifier, 0.5, "1-layer ice: speed_modifier == 0.5")
	t.assert_true(ice._is_slowed, "ice._is_slowed == true")

	# === 2层冰冻：冻结 ===

	effect_mgr.apply_status(mock_snake, "ice", "test")  # layer 2
	ice_status = effect_mgr.get_status(mock_snake, "ice")
	t.assert_eq(ice_status.layer, 2, "ice stacked to layer 2")

	# 监听冻结信号
	var freeze_events: Array = []
	var _on_freeze_start := func(data: Dictionary) -> void:
		freeze_events.append("start")
	var _on_freeze_end := func(data: Dictionary) -> void:
		freeze_events.append("end")
	EventBus.ice_freeze_started.connect(_on_freeze_start)
	EventBus.ice_freeze_ended.connect(_on_freeze_end)

	# 确保 TickManager 不处于暂停
	tick_mgr.tick_speed_modifier = 1.0
	tick_mgr._timer.paused = false
	tick_mgr.is_ticking = true

	# 处理效果 → 触发冻结
	ice.process_entity_effects(0.1, effect_mgr)
	t.assert_true(ice._is_frozen, "freeze triggered at layer 2")
	t.assert_true(tick_mgr._timer.paused, "TickManager paused during freeze")
	t.assert_true(freeze_events.has("start"), "ice_freeze_started emitted")

	# === 冻结期间：delta 累积但不产生其他效果 ===

	ice.process_entity_effects(1.0, effect_mgr)
	t.assert_true(ice._is_frozen, "still frozen after 1.0s (need 2.0s)")

	# === 冻结结束 ===

	ice.process_entity_effects(1.1, effect_mgr)  # 总计 0.1 + 1.0 + 1.1 = 2.2s > 2.0s
	t.assert_true(not ice._is_frozen, "freeze ended after 2.0s")
	t.assert_true(not tick_mgr._timer.paused, "TickManager resumed after freeze")
	t.assert_true(freeze_events.has("end"), "ice_freeze_ended emitted")

	# 冻结后层数回退到 1
	ice_status = effect_mgr.get_status(mock_snake, "ice")
	if ice_status:
		t.assert_eq(ice_status.layer, 1, "layer reset to 1 after freeze")

	# 冻结后恢复减速
	t.assert_eq(tick_mgr.tick_speed_modifier, 0.5, "speed_modifier back to 0.5 after freeze")
	t.assert_true(ice._is_slowed, "is_slowed restored after freeze")

	EventBus.ice_freeze_started.disconnect(_on_freeze_start)
	EventBus.ice_freeze_ended.disconnect(_on_freeze_end)

	# === 冰冻消失后速度恢复 ===

	effect_mgr.remove_status(mock_snake, "ice")
	t.assert_true(not effect_mgr.has_status(mock_snake, "ice"), "ice removed")

	ice.process_entity_effects(0.1, effect_mgr)
	t.assert_eq(tick_mgr.tick_speed_modifier, 1.0, "speed_modifier restored to 1.0 after ice removed")
	t.assert_true(not ice._is_slowed, "is_slowed == false after ice removed")

	# === config 读取验证 ===
	var cfg_node = Engine.get_main_loop().root.get_node_or_null("ConfigManager")
	if cfg_node:
		var cfg: Dictionary = cfg_node.get_status_effect("ice")
		t.assert_eq(cfg.get("speed_modifier"), 0.5, "config: speed_modifier == 0.5")
		t.assert_eq(cfg.get("freeze_at_layer"), 2, "config: freeze_at_layer == 2")
		t.assert_eq(cfg.get("freeze_duration"), 2.0, "config: freeze_duration == 2.0")
		t.assert_eq(cfg.get("entity_duration"), 6.0, "config: entity_duration == 6.0")
		t.assert_eq(cfg.get("max_layers"), 2, "config: max_layers == 2")
		t.assert_eq(cfg.get("tile_duration"), 12.0, "config: tile_duration == 12.0")

	# === 清理 ===
	effect_mgr.clear_all()
	GridWorld.clear_all()
	mock_snake.queue_free()

	# 恢复 TickManager 状态
	tick_mgr.tick_speed_modifier = original_speed_modifier
	tick_mgr.is_ticking = original_is_ticking
	tick_mgr._timer.paused = false
