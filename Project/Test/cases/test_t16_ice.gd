extends RefCounted
## T16 测试：冰冻状态效果（通过原子系统，per-entity 速度修改）


func run(t) -> void:
	# --- StatusEffectManager 集成检查 ---
	var effect_mgr = StatusEffectManager
	t.assert_true(effect_mgr != null, "StatusEffectManager exists")
	if effect_mgr == null:
		return

	# --- TickManager 检查 ---
	var tick_mgr = TickManager
	t.assert_true(tick_mgr != null, "TickManager exists")
	if tick_mgr == null:
		return

	# --- 准备 ---
	GridWorld.init_grid(40, 22)
	effect_mgr.clear_all()

	var mock_snake := Node2D.new()
	mock_snake.name = "TestSnake"
	Engine.get_main_loop().root.add_child(mock_snake)

	# === 1层冰冻：减速 (per-entity modifier) ===

	effect_mgr.apply_status(mock_snake, "ice", "test")
	t.assert_true(effect_mgr.has_status(mock_snake, "ice"), "snake has ice status")

	var ice_status: StatusEffectData = effect_mgr.get_status(mock_snake, "ice")
	t.assert_eq(ice_status.layer, 1, "ice at layer 1")
	t.assert_eq(ice_status.max_layers, 2, "ice max_layers == 2")

	# Atom on_applied 应已设置 speed modifier
	var speed_mod: float = effect_mgr.get_modifier("speed", mock_snake, 1.0)
	t.assert_eq(speed_mod, 0.5, "1-layer ice: per-entity speed modifier == 0.5")

	# 验证有 atom chains
	t.assert_true(ice_status.chains.size() > 0, "ice effect has atom chains")

	# === 2层冰冻：叠层 ===

	effect_mgr.apply_status(mock_snake, "ice", "test")  # layer 2
	ice_status = effect_mgr.get_status(mock_snake, "ice")
	t.assert_eq(ice_status.layer, 2, "ice stacked to layer 2")

	# on_layer_reach 触发 freeze atom → speed = 0
	speed_mod = effect_mgr.get_modifier("speed", mock_snake, 1.0)
	t.assert_eq(speed_mod, 0.0, "per-entity speed == 0 at layer 2 (freeze)")

	# === 冰冻消失后速度恢复 ===

	effect_mgr.remove_status(mock_snake, "ice")
	t.assert_true(not effect_mgr.has_status(mock_snake, "ice"), "ice removed")

	# on_removed 链应将 speed 恢复为 1.0
	speed_mod = effect_mgr.get_modifier("speed", mock_snake, 1.0)
	t.assert_eq(speed_mod, 1.0, "per-entity speed restored to 1.0 after ice removed")

	# === config 读取验证 ===
	var cfg_node = ConfigManager
	if cfg_node:
		var cfg: Dictionary = cfg_node.get_status_effect("ice")
		t.assert_eq(cfg.get("speed_modifier"), 0.5, "config: speed_modifier == 0.5")
		t.assert_eq(cfg.get("freeze_at_layer"), 2, "config: freeze_at_layer == 2")
		t.assert_eq(cfg.get("freeze_duration"), 2.0, "config: freeze_duration == 2.0")
		t.assert_eq(cfg.get("entity_duration"), 6.0, "config: entity_duration == 6.0")
		t.assert_eq(cfg.get("max_layers"), 2, "config: max_layers == 2")
		t.assert_eq(cfg.get("tile_duration"), 12.0, "config: tile_duration == 12.0")
		# Atom chains 存在
		t.assert_true(cfg.has("entity_effects"), "config has entity_effects")
		t.assert_true(cfg.has("tile_effects"), "config has tile_effects")

	# === 清理 ===
	effect_mgr.clear_all()
	GridWorld.clear_all()
	mock_snake.queue_free()
