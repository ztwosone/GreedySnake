extends RefCounted
## L4 Phase 7: Floor reward tests (T027-T031).

const FLOOR_REWARD_PATH: String = "res://systems/growth/floor_reward_system.gd"

var _presented_events: Array = []
var _chosen_events: Array = []


func run(t) -> void:
	_test_floor_reward_config(t)
	_test_floor_reward_offer_and_choose(t)


func _test_floor_reward_config(t) -> void:
	var cfg: Dictionary = ConfigManager.get_floor_reward_config()
	t.assert_eq(int(cfg.get("offer_count", 0)), 3, "[L4-US5] offer_count = 3")
	var categories: Array = cfg.get("categories", [])
	t.assert_true(categories.has("expansion"), "[L4-US5] has expansion category")
	t.assert_true(categories.has("reinforcement"), "[L4-US5] has reinforcement category")
	t.assert_true(categories.has("correction"), "[L4-US5] has correction category")


func _test_floor_reward_offer_and_choose(t) -> void:
	t.assert_file_exists(FLOOR_REWARD_PATH)
	if not FileAccess.file_exists(FLOOR_REWARD_PATH):
		return

	var mock_snake := Node2D.new()
	mock_snake.name = "FloorMockSnake"

	var scale_mgr: Node = load("res://systems/snake_parts/scale_slot_manager.gd").new()
	scale_mgr.init_manager(mock_snake, StatusEffectManager._trigger_manager, StatusEffectManager._chain_resolver)

	var parts_mgr: Node = load("res://systems/snake_parts/snake_parts_manager.gd").new()
	parts_mgr.init_manager(mock_snake, StatusEffectManager._trigger_manager, StatusEffectManager._chain_resolver)

	var system: Node = load(FLOOR_REWARD_PATH).new()
	system.setup(scale_mgr, parts_mgr)
	t.add_child(system)

	_presented_events.clear()
	_chosen_events.clear()
	EventBus.floor_reward_presented.connect(_on_presented)
	EventBus.floor_reward_chosen.connect(_on_chosen)

	var offer: Dictionary = system.present_floor_reward(1, "boss_01")
	t.assert_eq(_presented_events.size(), 1, "[L4-US5] floor_reward_presented emitted")
	t.assert_eq(offer.get("floor_index", 0), 1, "[L4-US5] floor index = 1")
	var options: Array = offer.get("options", [])
	t.assert_eq(options.size(), 3, "[L4-US5] 3 floor reward options")

	t.assert_true(system.choose_floor_reward(0), "[L4-US5] choose first option succeeds")
	t.assert_eq(_chosen_events.size(), 1, "[L4-US5] floor_reward_chosen emitted")

	EventBus.floor_reward_presented.disconnect(_on_presented)
	EventBus.floor_reward_chosen.disconnect(_on_chosen)

	system.cleanup()
	scale_mgr.clear_all()
	parts_mgr.unequip_head()
	parts_mgr.unequip_tail()
	scale_mgr.free()
	parts_mgr.free()
	mock_snake.free()
	system.queue_free()


func _on_presented(data: Dictionary) -> void:
	_presented_events.append(data)


func _on_chosen(data: Dictionary) -> void:
	_chosen_events.append(data)