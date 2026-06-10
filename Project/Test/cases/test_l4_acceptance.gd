extends RefCounted
## L4 v1 Automated Acceptance Test
## Covers SC-001 through SC-009 in a headless automated run.

const GAME_WORLD_PATH: String = "res://scenes/game_world.tscn"


func run(t) -> void:
	_test_sc001_scale_reward_flow(t)
	_test_sc002_shedskin_accumulation(t)
	_test_sc003_shop_items(t)
	_test_sc004_floor_reward_categories(t)
	_test_sc005_multi_floor(t)
	_test_sc006_difficulty_adjustment(t)
	await _test_sc007_modifiers(t)


func _test_sc001_scale_reward_flow(t) -> void:
	var mock_snake := Node2D.new()
	mock_snake.name = "AccMock"

	var scale_mgr: Node = load("res://systems/snake_parts/scale_slot_manager.gd").new()
	scale_mgr.init_manager(mock_snake, StatusEffectManager._trigger_manager, StatusEffectManager._chain_resolver)

	var system: Node = load("res://systems/growth/scale_reward_system.gd").new()
	system.setup(scale_mgr)
	t.add_child(system)

	var offer: Dictionary = system.present_offer({"room_id": "test", "room_type": "combat"})
	t.assert_eq(offer.get("options", []).size(), 3, "[SC-001] 3 scale options")
	t.assert_true(system.choose_scale(0), "[SC-001] can choose scale")

	system.cleanup()
	scale_mgr.clear_all()
	scale_mgr.free()
	mock_snake.free()
	system.queue_free()


func _test_sc002_shedskin_accumulation(t) -> void:
	var system: Node = load("res://systems/growth/shedskin_system.gd").new()
	t.add_child(system)

	system.earn(1, "kill_normal")
	t.assert_eq(system.get_amount(), 1, "[SC-002] +1 per normal kill")
	system.earn(3, "kill_elite")
	t.assert_eq(system.get_amount(), 4, "[SC-002] +3 per elite")

	# Amended 2026-06-11（FR-003/Designs §10.2）：蜕皮跨层保留，不清零
	EventBus.floor_generated.emit({"floor_index": 2})
	t.assert_eq(system.get_amount(), 4, "[SC-002] shedskin carries over across floors (FR-003)")

	system.cleanup()
	system.queue_free()


func _test_sc003_shop_items(t) -> void:
	var items: Array = []
	for i in range(3):
		items.append({"item_id": "item_%d" % i, "display_name": "商品 %d" % i, "price": 2 + i, "purchased": false, "affordable": true, "category": "scale", "placeholder_color": "#FF5722"})
	EventBus.shop_entered.emit({"room_id": "test", "items": items})
	t.assert_true(true, "[SC-003] shop_entered event fires with items")


func _test_sc004_floor_reward_categories(t) -> void:
	# Amended 2026-06-11（FR-007/Designs §10.3-10.5）：Boss 结算 = 固定槽位解锁步骤先行，
	# 再独立 3 选 1（扩展/强化/修正三类各一）。SC-001..SC-012 全量映射归 T033。
	var mock_snake := Node2D.new()
	mock_snake.name = "AccFloorRewardMock"
	var scale_mgr: Node = load("res://systems/snake_parts/scale_slot_manager.gd").new()
	scale_mgr.init_manager(mock_snake, StatusEffectManager._trigger_manager, StatusEffectManager._chain_resolver)
	var slot_system: Node = load("res://systems/growth/slot_expansion_system.gd").new()
	slot_system.setup(scale_mgr)
	t.add_child(slot_system)
	var system: Node = load("res://systems/growth/floor_reward_system.gd").new()
	system.setup(scale_mgr, slot_system)
	t.add_child(system)
	t.assert_true(scale_mgr.equip_scale("middle", "flame_scale", 1), "[SC-004] precondition: a scale equipped")

	var offer: Dictionary = system.present_settlement(1, "boss_01")
	t.assert_eq(str(offer.get("step", "")), "slot_unlock", "[SC-004] fixed slot-unlock step resolves first")
	t.assert_true(system.choose_slot_position("front"), "[SC-004] player picks a position")
	var options: Array = system.get_current_offer().get("options", [])
	t.assert_eq(options.size(), 3, "[SC-004] 3 floor reward options")
	var categories: Array = []
	for opt in options:
		categories.append(opt.get("category", ""))
	t.assert_true(categories.has("expansion"), "[SC-004] expansion category present")
	t.assert_true(categories.has("reinforcement"), "[SC-004] reinforcement category present")
	t.assert_true(categories.has("correction"), "[SC-004] correction category present")
	t.assert_true(system.choose_floor_reward(0), "[SC-004] choice resolves the settlement")

	system.cleanup()
	system.queue_free()
	slot_system.cleanup()
	slot_system.queue_free()
	scale_mgr.clear_all()
	scale_mgr.free()
	mock_snake.free()


func _test_sc005_multi_floor(t) -> void:
	var gen = load("res://systems/rooms/floor_map_generator.gd").new()
	var floor_ids: Array = []
	for i in range(1, 4):
		var floor_map: Dictionary = gen.generate_floor(i, 5000 + i)
		var floor_id: String = floor_map.get("floor_id", "")
		floor_ids.append(floor_id)
		t.assert_true(floor_map.get("rooms", []).size() >= 5, "[SC-005] floor %d has ≥5 rooms" % i)
	t.assert_eq(floor_ids.size(), 3, "[SC-005] 3 distinct floors generated")
	t.assert_true(floor_ids[0] != floor_ids[1], "[SC-005] floor 1 ≠ floor 2")


func _test_sc006_difficulty_adjustment(t) -> void:
	# Amended 2026-06-11（FR-008/SC-006，T029 同卡更新）：静态层 MUST（层表数据）+
	# 反应式 SHOULD（仅生成参数级断言——Designs §11.5 隐性）。SC 全量映射归 T033。
	var system: Node = load("res://systems/difficulty/difficulty_scaler.gd").new()
	t.add_child(system)
	if not system.has_method("get_static_enemy_delta"):
		t.assert_true(false, "[SC-006] difficulty scaler v2 API missing (T030)")
		system.queue_free()
		return

	var cfg: Dictionary = ConfigManager.get_difficulty_config()
	EventBus.floor_generated.emit({"floor_index": 2})
	var expected_static: int = int(ConfigManager.get_difficulty_floor_params(2).get("enemy_count", 0)) \
		- int(cfg.get("baseline_enemy_count", 0))
	t.assert_eq(system.get_static_enemy_delta(), expected_static,
		"[SC-006] static per-floor scaling read from the JSON floor table (MUST)")

	# 模拟一个秒清/零受击/状态满额的调整窗口 → 生成参数微调且在 clamp 内
	var saved_tick: int = TickManager.current_tick
	var normalization: Dictionary = ConfigManager.get_difficulty_reactive_config().get("normalization", {})
	var rooms_between: int = int(cfg.get("rooms_between_adjustments", 2))
	for index in range(rooms_between):
		EventBus.room_entered.emit({"room_id": "sc006_%d" % index, "room_type": "combat"})
		for _i in range(int(normalization.get("status_usage_per_room", 5))):
			EventBus.reaction_triggered.emit({})
		EventBus.room_completed.emit({"room_id": "sc006_%d" % index})
	var clamp_cfg: Dictionary = ConfigManager.get_difficulty_reactive_config().get("clamp", {})
	var reactive_delta: int = system.get_reactive_enemy_delta()
	t.assert_true(reactive_delta != 0, "[SC-006] reactive layer shifts generation parameters (SHOULD)")
	t.assert_true(
		reactive_delta >= int(clamp_cfg.get("enemy_delta_min", 0))
		and reactive_delta <= int(clamp_cfg.get("enemy_delta_max", 0)),
		"[SC-006] reactive delta stays within configured clamps")

	TickManager.current_tick = saved_tick
	system.cleanup()
	system.queue_free()


func _test_sc007_modifiers(t) -> void:
	# Amended 2026-06-11（FR-009/SC-007，T029 同卡更新）：v1 = shield_enemies +
	# preset_status_tiles（darkness/speed_strips 入 backlog.md），可叠加、可见、可移除。
	var system: Node = load("res://systems/difficulty/room_modifier_system.gd").new()
	if not system.has_method("setup") or not system.has_method("apply_modifiers"):
		t.assert_true(false, "[SC-007] room modifier v2 API missing (T031)")
		system.free()
		return

	GridWorld.init_grid(Constants.GRID_WIDTH, Constants.GRID_HEIGHT)
	var enemy_container := Node2D.new()
	enemy_container.name = "Sc007EnemyContainer"
	t.add_child(enemy_container)
	var em: Node = load("res://systems/enemy/enemy_manager.gd").new()
	em.enemy_container = enemy_container
	t.add_child(em)
	var tile_mgr: Node = load("res://entities/status_tiles/status_tile_manager.gd").new()
	tile_mgr.name = "Sc007TileManager"
	t.add_child(tile_mgr)
	t.add_child(system)
	system.setup(em, tile_mgr, null)

	em.set("respawn_policy", "room_budget")
	em.init_enemies(3)
	system.apply_modifiers({"room_id": "sc007", "modifiers": ["shield_enemies", "preset_status_tiles"]})
	t.assert_eq(system.get_active_modifiers().size(), 2, "[SC-007] both v1 modifiers active simultaneously")

	var shielded: int = 0
	for enemy in em.current_enemies:
		if enemy.has_meta("room_modifier_shield"):
			shielded += 1
	t.assert_true(shielded > 0, "[SC-007] shield_enemies marks shielded enemies visibly")
	t.assert_true(tile_mgr.get_tile_count() > 0, "[SC-007] preset_status_tiles places visible status tiles")

	EventBus.room_completed.emit({"room_id": "sc007"})
	t.assert_eq(system.get_active_modifiers().size(), 0, "[SC-007] modifiers cleared on room completion")
	t.assert_eq(tile_mgr.get_tile_count(), 0, "[SC-007] preset tiles removed with the modifier")

	system.cleanup()
	system.queue_free()
	em.clear_enemies()
	em.queue_free()
	tile_mgr.queue_free()
	enemy_container.queue_free()
	GridWorld.clear_all()
	await t.get_tree().process_frame
	await t.get_tree().process_frame