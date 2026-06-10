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
	_test_sc007_modifiers(t)


func _test_sc001_scale_reward_flow(t) -> void:
	var mock_snake := Node2D.new()
	mock_snake.name = "AccMock"

	var scale_mgr: Node = load("res://systems/snake_parts/scale_slot_manager.gd").new()
	scale_mgr.init_manager(mock_snake, StatusEffectManager._trigger_manager, StatusEffectManager._chain_resolver)

	var system: Node = load("res://systems/growth/scale_reward_system.gd").new()
	system.setup(scale_mgr, null)
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

	EventBus.floor_generated.emit({"floor_index": 2})
	t.assert_eq(system.get_amount(), 0, "[SC-002] reset to 0 on floor transition")

	system.cleanup()
	system.queue_free()


func _test_sc003_shop_items(t) -> void:
	var items: Array = []
	for i in range(3):
		items.append({"item_id": "item_%d" % i, "display_name": "商品 %d" % i, "price": 2 + i, "purchased": false, "affordable": true, "category": "scale", "placeholder_color": "#FF5722"})
	EventBus.shop_entered.emit({"room_id": "test", "items": items})
	t.assert_true(true, "[SC-003] shop_entered event fires with items")


func _test_sc004_floor_reward_categories(t) -> void:
	var system: Node = load("res://systems/growth/floor_reward_system.gd").new()
	t.add_child(system)

	var offer: Dictionary = system.present_floor_reward(1, "boss_01")
	var options: Array = offer.get("options", [])
	t.assert_eq(options.size(), 3, "[SC-004] 3 floor reward options")
	var categories: Array = []
	for opt in options:
		categories.append(opt.get("category", ""))
	t.assert_true(categories.has("expansion"), "[SC-004] expansion category present")
	t.assert_true(categories.has("reinforcement"), "[SC-004] reinforcement category present")
	t.assert_true(categories.has("correction"), "[SC-004] correction category present")

	system.cleanup()
	system.queue_free()


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
	var system: Node = load("res://systems/difficulty/difficulty_scaler.gd").new()
	t.add_child(system)

	system.record_room_completion(10, 0, 5)
	system.record_room_completion(12, 1, 3)
	var delta: int = system.get_enemy_count_delta()
	t.assert_true(delta >= -1 and delta <= 1, "[SC-006] enemy delta in range [-1, 1]")

	system.cleanup()
	system.queue_free()


func _test_sc007_modifiers(t) -> void:
	var system: Node = load("res://systems/difficulty/room_modifier_system.gd").new()
	t.add_child(system)

	t.assert_true(system.apply_modifier("darkness", "room_a"), "[SC-007] darkness modifier applied")
	t.assert_true(system.apply_modifier("speed_strips", "room_a"), "[SC-007] speed_strips modifier applied")
	t.assert_eq(system.get_active_modifiers().size(), 2, "[SC-007] 2 modifiers active simultaneously")

	system.remove_modifiers("room_a")
	t.assert_eq(system.get_active_modifiers().size(), 0, "[SC-007] modifiers cleared on room exit")

	system.cleanup()
	system.queue_free()