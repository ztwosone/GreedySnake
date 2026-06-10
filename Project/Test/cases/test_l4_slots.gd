extends RefCounted
## L4 US3 重验收测试（spec 002 T011/T012，2026-06-11 修订版 spec 对照）：
## 槽位扩展——SlotExpansionSystem 为 ScaleSlotManager.open_slot() 的薄适配器
## （草稿判决：从不调 open_slot，买槽零效果）；MAX_SLOTS JSON 化（FR-010，
## growth.slot_expansion.max + get_max_slots/get_open_slots accessor）；
## 3→7 上限（前×2 中×3 后×2，FR-005）；新开槽位可装备并参与共鸣（US3 场景 2）；
## shop_purchase(category=slot) 事件链真开槽（FR-011 EventBus-only）。
## T023（spec 002 T5a）：Build 装备跨层存续——蛇重建后已装鳞片/头/共鸣/蜕皮余额
## 全部存续且触发器仍可用（FR-003/FR-013 边界：层间不清成长状态，仅 run 重启清）。

const SLOT_EXPANSION_PATH: String = "res://systems/growth/slot_expansion_system.gd"
const SCALE_SLOT_MANAGER_PATH: String = "res://systems/snake_parts/scale_slot_manager.gd"
const RESONANCE_MANAGER_PATH: String = "res://systems/snake_parts/resonance_manager.gd"

var _slot_events: Array = []


func run(t) -> void:
	_test_slot_expansion_config(t)
	_test_scale_slot_manager_uses_json_limits(t)
	_test_adapter_delegates_to_open_slot(t)
	_test_shop_purchase_event_opens_slot(t)
	_test_new_slot_participates_in_resonance(t)
	await _test_build_persists_across_floors(t)


# ── T023: Build 装备跨层存续（蛇重建后鳞片/头/共鸣/蜕皮/触发器全活） ──

func _test_build_persists_across_floors(t) -> void:
	var saved_state: int = GameManager.current_state
	var saved_score: int = GameManager.current_score
	var saved_best: int = GameManager.best_score
	var previous_generator: String = str(ConfigManager.floor.get("generator", "fixed_v1"))
	ConfigManager.floor["generator"] = "pcg"

	var scene = load("res://scenes/game_world.tscn") as PackedScene
	var world: Node = scene.instantiate()
	if not world.has_method("reset_for_floor"):
		t.assert_true(false, "[T023] cross-floor persistence needs game_world.reset_for_floor (T022)")
		world.free()
		ConfigManager.floor["generator"] = previous_generator
		return
	t.add_child(world)
	world.start_game()
	GameManager.start_game()

	var run_system: Node = world.get_node("RunProgressionSystem")
	var snake: Node = world.get_node("EntityContainer/Snake")
	var scale_mgr: Node = world.get_node("ScaleSlotManager")
	var parts_mgr: Node = world.get_node("SnakePartsManager")
	var resonance_mgr: Node = world.get_node("ResonanceManager")
	var shedskin: Node = world.get_node("ShedskinSystem")

	# 走到 boss 房门口（不完成），路上鳞片 offer 全放弃攒蜕皮
	var at_boss: bool = await _drive_world_until_endpoint(t, world)
	t.assert_true(at_boss, "[T023] panels drive the pcg floor 1 to its boss room")
	if not at_boss:
		_teardown_world(world, saved_state, saved_score, saved_best, previous_generator)
		await t.get_tree().process_frame
		await t.get_tree().process_frame
		return

	# 安排已知 Build：中段 flame+phantom 共鸣对 + hydra 蛇头
	for slot_index in range(scale_mgr.get_max_slots("middle")):
		scale_mgr.unequip_scale("middle", slot_index)
	if scale_mgr.get_open_slots("middle") < 2:
		t.assert_true(scale_mgr.open_slot("middle"), "[T023] open a second middle slot for the pair")
	t.assert_true(scale_mgr.equip_scale("middle", "flame_scale", 1), "[T023] equip flame scale")
	t.assert_true(scale_mgr.equip_scale("middle", "phantom_scale", 1), "[T023] equip phantom scale")
	t.assert_true(resonance_mgr.get_active_resonances().has("phantom_flame"),
		"[T023] resonance active before the floor transition")
	parts_mgr.unequip_head()
	t.assert_true(parts_mgr.equip_head("hydra", 1), "[T023] equip hydra head")

	var balance_before: int = shedskin.get_amount()
	t.assert_true(balance_before > 0, "[T023] discard income banked before the transition (FR-003 前提)")
	var length_before: int = snake.body.size()
	var open_middle_before: int = scale_mgr.get_open_slots("middle")

	# 完成 boss → 延迟切层
	var room_flow: Node = world.get_node("RoomFlowSystem")
	var required: int = int(room_flow.get_current_room().get("objective", {}).get("required_count", 1))
	room_flow.record_objective_progress(required, {"method": "t023"})
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	t.assert_eq(int(run_system.get_state().get("floor_index", 0)), 2,
		"[T023] boss completion advances the run to floor 2")

	# 存续断言：鳞片/头/共鸣/蜕皮/长度/开槽数
	var middle_ids: Array = []
	for part in scale_mgr.get_scales("middle"):
		middle_ids.append(str(part.part_id))
	t.assert_eq(middle_ids, ["flame_scale", "phantom_scale"],
		"[T023] equipped scales survive the snake re-init (Build 不随楼层清)")
	t.assert_eq(scale_mgr.get_open_slots("middle"), open_middle_before,
		"[T023] opened slots survive the floor transition")
	t.assert_true(parts_mgr.has_head(), "[T023] head still equipped after the transition")
	t.assert_eq(str(parts_mgr.get_active_head().part_id), "hydra", "[T023] head identity preserved")
	t.assert_true(resonance_mgr.get_active_resonances().has("phantom_flame"),
		"[T023] resonance still active after the snake re-init")
	t.assert_eq(shedskin.get_amount(), balance_before,
		"[T023] shedskin balance carries over across floors (FR-003)")
	t.assert_eq(snake.body.size(), length_before, "[T023] snake length preserved")

	# 触发器仍然活着：卸装重装驱动共鸣重算（证明 TriggerManager 链路未被切层打断）
	scale_mgr.unequip_scale("middle", 1)
	t.assert_false(resonance_mgr.get_active_resonances().has("phantom_flame"),
		"[T023] resonance recalculates on unequip after the transition (triggers alive)")
	t.assert_true(scale_mgr.equip_scale("middle", "phantom_scale", 1), "[T023] re-equip on floor 2")
	t.assert_true(resonance_mgr.get_active_resonances().has("phantom_flame"),
		"[T023] resonance reactivates on floor 2 (trigger machinery intact)")

	_teardown_world(world, saved_state, saved_score, saved_best, previous_generator)
	# 冲掉 queue_free 的世界：EnemyManager 在落地前仍连着 enemy_killed（严格扫描防护）
	await t.get_tree().process_frame
	await t.get_tree().process_frame


func _drive_world_until_endpoint(t, world: Node) -> bool:
	## 面板公共 API 驱动至 boss 房门口（不完成 boss）；鳞片 offer 一律放弃攒蜕皮
	var run_system: Node = world.get_node("RunProgressionSystem")
	var room_flow: Node = world.get_node("RoomFlowSystem")
	var floor_panel: Node = world.get_node("UI/FloorProgressPanel")
	var reward_panel: Node = world.get_node("UI/RewardChoicePanel")
	var scale_panel: Node = world.get_node("UI/ScaleChoicePanel")
	var reward_flow: Node = world.get_node("RewardFlowSystem")
	var scale_system: Node = world.get_node("ScaleRewardSystem")

	for _step in range(64):
		if not run_system.is_running():
			return false
		var endpoint_id: String = str(run_system.get_floor_map().get("endpoint_room_id", ""))
		var current_id: String = str(run_system.get_state().get("current_room_id", ""))
		if scale_system.has_pending_offer():
			scale_panel.discard_offer()
			continue
		if reward_flow.has_pending_offer():
			reward_panel.choose_option_by_index(0)
			continue
		if current_id == endpoint_id:
			return true
		if not room_flow.is_current_room_complete():
			var objective: Dictionary = room_flow.get_current_room().get("objective", {})
			if str(objective.get("objective_type", "")) == "clear_enemies":
				room_flow.record_objective_progress(int(objective.get("required_count", 1)), {"method": "t023_driver"})
			continue
		if not floor_panel.request_next_room():
			return false
	return false


func _teardown_world(world: Node, saved_state: int, saved_score: int, saved_best: int, previous_generator: String) -> void:
	world.cleanup()
	world.queue_free()
	GameManager.current_state = saved_state
	GameManager.current_score = saved_score
	GameManager.best_score = saved_best
	TickManager.stop_ticking()
	GridWorld.clear_all()
	ConfigManager.floor["generator"] = previous_generator


# ── T011: 配置（FR-005/FR-010） ──────────────────────────────────────

func _test_slot_expansion_config(t) -> void:
	var cfg: Dictionary = ConfigManager.get_slot_expansion_config()
	t.assert_true(cfg is Dictionary and not cfg.is_empty(), "[L4-US3] slot expansion config in JSON")
	var initial: Dictionary = cfg.get("initial", {})
	t.assert_eq(int(initial.get("front", 0)), 1, "[L4-US3] initial front slots = 1")
	t.assert_eq(int(initial.get("middle", 0)), 1, "[L4-US3] initial middle slots = 1")
	t.assert_eq(int(initial.get("back", 0)), 1, "[L4-US3] initial back slots = 1")
	var max_slots: Dictionary = cfg.get("max", {})
	t.assert_eq(int(max_slots.get("front", 0)), 2, "[L4-US3] max front slots = 2")
	t.assert_eq(int(max_slots.get("middle", 0)), 3, "[L4-US3] max middle slots = 3")
	t.assert_eq(int(max_slots.get("back", 0)), 2, "[L4-US3] max back slots = 2")
	var initial_total: int = int(initial.get("front", 0)) + int(initial.get("middle", 0)) + int(initial.get("back", 0))
	var max_total: int = int(max_slots.get("front", 0)) + int(max_slots.get("middle", 0)) + int(max_slots.get("back", 0))
	t.assert_eq(initial_total, 3, "[L4-US3] FR-005: 3 initial slots")
	t.assert_eq(max_total, 7, "[L4-US3] FR-005: 7 max slots")


# ── T012: ScaleSlotManager 上限 JSON 化 + accessor ───────────────────

func _test_scale_slot_manager_uses_json_limits(t) -> void:
	var setup: Dictionary = _make_managers()
	var scale_mgr: Node = setup["scale_mgr"]
	var cfg: Dictionary = ConfigManager.get_slot_expansion_config()
	var max_slots: Dictionary = cfg.get("max", {})
	var initial: Dictionary = cfg.get("initial", {})

	for pos in ["front", "middle", "back"]:
		t.assert_eq(scale_mgr.get_max_slots(pos), int(max_slots.get(pos, -1)),
			"[L4-US3] get_max_slots(%s) reads growth.slot_expansion.max (JSON, no MAX_SLOTS const)" % pos)
		t.assert_eq(scale_mgr.get_open_slots(pos), int(initial.get(pos, -1)),
			"[L4-US3] get_open_slots(%s) starts at JSON initial" % pos)

	# 中段：1 开放 → 装 1 片满，open_slot 逐级到 JSON max=3 后拒绝
	t.assert_true(scale_mgr.equip_scale("middle", "flame_scale", 1), "[L4-US3] first middle equip uses the open slot")
	t.assert_false(scale_mgr.equip_scale("middle", "toxin_scale", 1), "[L4-US3] second middle equip blocked while only 1 slot open")
	t.assert_true(scale_mgr.open_slot("middle"), "[L4-US3] open_slot(middle) -> 2")
	t.assert_eq(scale_mgr.get_open_slots("middle"), 2, "[L4-US3] open slots tracked")
	t.assert_true(scale_mgr.equip_scale("middle", "toxin_scale", 1), "[L4-US3] newly opened slot accepts a scale")
	t.assert_true(scale_mgr.open_slot("middle"), "[L4-US3] open_slot(middle) -> 3 (JSON max)")
	t.assert_false(scale_mgr.open_slot("middle"), "[L4-US3] open_slot refuses beyond JSON max")
	t.assert_eq(scale_mgr.get_open_slots("middle"), 3, "[L4-US3] open slots clamp at JSON max")
	t.assert_eq(scale_mgr.get_open_slots("unknown"), 0, "[L4-US3] unknown position reads 0 open slots")
	t.assert_eq(scale_mgr.get_max_slots("unknown"), 0, "[L4-US3] unknown position reads 0 max slots")

	_teardown_managers(setup)


# ── T012: 薄适配器——unlock 必经 open_slot（草稿回归：买槽零效果） ────

func _test_adapter_delegates_to_open_slot(t) -> void:
	t.assert_file_exists(SLOT_EXPANSION_PATH)
	if not FileAccess.file_exists(SLOT_EXPANSION_PATH):
		return

	var setup: Dictionary = _make_managers()
	var scale_mgr: Node = setup["scale_mgr"]
	var system: Node = load(SLOT_EXPANSION_PATH).new()
	system.setup(scale_mgr)
	t.add_child(system)
	_connect_recorder()

	t.assert_eq(system.get_total_slots(), 3, "[L4-US3] adapter reports 3 initial slots (manager truth)")
	t.assert_eq(system.get_slot_count("front"), 1, "[L4-US3] adapter front count mirrors manager")

	t.assert_true(system.can_unlock("front"), "[L4-US3] can unlock front below max")
	t.assert_true(system.unlock_slot("front", "boss"), "[L4-US3] front unlock succeeds")
	t.assert_eq(scale_mgr.get_open_slots("front"), 2,
		"[L4-US3] unlock REALLY calls ScaleSlotManager.open_slot (draft regression: zero effect)")
	t.assert_eq(system.get_slot_count("front"), 2, "[L4-US3] adapter count follows manager")
	t.assert_eq(system.get_total_slots(), 4, "[L4-US3] total = 4 after unlock")
	t.assert_eq(_slot_events.size(), 1, "[L4-US3] slot_unlocked emitted")
	if _slot_events.size() > 0:
		t.assert_eq(_slot_events[0].get("position", ""), "front", "[L4-US3] payload position")
		t.assert_eq(int(_slot_events[0].get("total_slots", 0)), 4, "[L4-US3] payload total_slots")
		t.assert_eq(_slot_events[0].get("source", ""), "boss", "[L4-US3] payload source")

	# 新开槽位立即可装备（US3 场景 2 前半）
	t.assert_true(scale_mgr.equip_scale("front", "greedy_scale", 1), "[L4-US3] fill first front slot")
	t.assert_true(scale_mgr.equip_scale("front", "predator_scale", 1), "[L4-US3] unlocked front slot accepts a scale")

	# 上限拒绝：front max=2
	t.assert_false(system.can_unlock("front"), "[L4-US3] cannot unlock front beyond max")
	t.assert_false(system.unlock_slot("front", "test"), "[L4-US3] front unlock fails at max")
	t.assert_eq(scale_mgr.get_open_slots("front"), 2, "[L4-US3] manager unchanged on refused unlock")
	t.assert_eq(_slot_events.size(), 1, "[L4-US3] no event on refused unlock")

	# 3→7 阶梯（FR-005）：middle ×2 + back ×1 全开
	t.assert_true(system.unlock_slot("middle", "boss"), "[L4-US3] middle unlock 1")
	t.assert_true(system.unlock_slot("middle", "shop"), "[L4-US3] middle unlock 2")
	t.assert_false(system.can_unlock("middle"), "[L4-US3] middle at max 3")
	t.assert_true(system.unlock_slot("back", "shop"), "[L4-US3] back unlock")
	t.assert_false(system.can_unlock("back"), "[L4-US3] back at max 2")
	t.assert_eq(system.get_total_slots(), 7, "[L4-US3] FR-005: total slots reach 7")
	t.assert_eq(scale_mgr.get_open_slots("middle"), 3, "[L4-US3] manager middle = 3")
	t.assert_eq(scale_mgr.get_open_slots("back"), 2, "[L4-US3] manager back = 2")
	t.assert_eq(system.get_unlock_history().size(), 4, "[L4-US3] history tracks 4 unlocks")

	system.reset()
	t.assert_eq(system.get_unlock_history().size(), 0, "[L4-US3] reset clears history")
	t.assert_eq(system.get_total_slots(), 7,
		"[L4-US3] adapter reset does NOT mutate manager state (single source of truth)")

	_disconnect_recorder()
	system.cleanup()
	system.queue_free()
	_teardown_managers(setup)


# ── T012: shop_purchase 事件链真开槽（FR-011） ───────────────────────

func _test_shop_purchase_event_opens_slot(t) -> void:
	var setup: Dictionary = _make_managers()
	var scale_mgr: Node = setup["scale_mgr"]
	var system: Node = load(SLOT_EXPANSION_PATH).new()
	system.setup(scale_mgr)
	t.add_child(system)
	_connect_recorder()

	EventBus.shop_purchase.emit({"item_id": "slot_middle", "category": "slot", "cost": 5, "currency_remaining": 0})
	t.assert_eq(scale_mgr.get_open_slots("middle"), 2,
		"[L4-US3] shop slot purchase opens the slot through the adapter (draft regression)")
	t.assert_eq(_slot_events.size(), 1, "[L4-US3] shop unlock emits slot_unlocked")
	if _slot_events.size() > 0:
		t.assert_eq(_slot_events[0].get("source", ""), "shop", "[L4-US3] shop unlock tagged source=shop")

	EventBus.shop_purchase.emit({"item_id": "scale_l1", "category": "scale", "cost": 2, "currency_remaining": 0})
	t.assert_eq(system.get_total_slots(), 4, "[L4-US3] non-slot purchases do not open slots")
	t.assert_eq(_slot_events.size(), 1, "[L4-US3] non-slot purchases emit no slot_unlocked")

	_disconnect_recorder()
	system.cleanup()
	system.queue_free()
	_teardown_managers(setup)


# ── T011: 新槽参与共鸣（US3 场景 2 后半） ────────────────────────────

func _test_new_slot_participates_in_resonance(t) -> void:
	var setup: Dictionary = _make_managers()
	var scale_mgr: Node = setup["scale_mgr"]
	var resonance_mgr: Node = load(RESONANCE_MANAGER_PATH).new()
	resonance_mgr.init_manager(setup["snake"], StatusEffectManager._trigger_manager,
		StatusEffectManager._chain_resolver, scale_mgr)
	var system: Node = load(SLOT_EXPANSION_PATH).new()
	system.setup(scale_mgr)
	t.add_child(system)

	t.assert_true(scale_mgr.equip_scale("middle", "flame_scale", 1), "[L4-US3] equip flame (fire) in base slot")
	t.assert_eq(resonance_mgr.get_active_resonances().size(), 0, "[L4-US3] single scale -> no resonance")

	t.assert_true(system.unlock_slot("middle", "shop"), "[L4-US3] buy/unlock second middle slot")
	t.assert_true(scale_mgr.equip_scale("middle", "phantom_scale", 1), "[L4-US3] equip phantom (void) in NEW slot")
	t.assert_true(resonance_mgr.get_active_resonances().has("phantom_flame"),
		"[L4-US3] scale in the newly unlocked slot participates in resonance (fire+void)")

	scale_mgr.unequip_scale("middle", 1)
	t.assert_false(resonance_mgr.get_active_resonances().has("phantom_flame"),
		"[L4-US3] resonance recalculates when the new slot empties")

	system.cleanup()
	system.queue_free()
	resonance_mgr.clear_all()
	resonance_mgr.free()
	_teardown_managers(setup)


# ── Helpers ──────────────────────────────────────────────────────────

func _make_managers() -> Dictionary:
	var mock_snake := Node2D.new()
	mock_snake.name = "SlotTestMockSnake"
	var scale_mgr: Node = load(SCALE_SLOT_MANAGER_PATH).new()
	scale_mgr.init_manager(mock_snake, StatusEffectManager._trigger_manager, StatusEffectManager._chain_resolver)
	return {"snake": mock_snake, "scale_mgr": scale_mgr}


func _teardown_managers(setup: Dictionary) -> void:
	setup["scale_mgr"].clear_all()
	setup["scale_mgr"].free()
	setup["snake"].free()


func _connect_recorder() -> void:
	_slot_events.clear()
	if not EventBus.slot_unlocked.is_connected(_on_slot_unlocked):
		EventBus.slot_unlocked.connect(_on_slot_unlocked)


func _disconnect_recorder() -> void:
	if EventBus.slot_unlocked.is_connected(_on_slot_unlocked):
		EventBus.slot_unlocked.disconnect(_on_slot_unlocked)


func _on_slot_unlocked(data: Dictionary) -> void:
	_slot_events.append(data)
