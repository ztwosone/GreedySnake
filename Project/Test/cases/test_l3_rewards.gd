extends RefCounted
## L3 US2 tests: present no more than three Build rewards, choose one,
## and apply it through existing SnakePartsManager / ScaleSlotManager.

const REWARD_FLOW_SYSTEM_PATH: String = "res://systems/rewards/reward_flow_system.gd"
const REWARD_CHOICE_PANEL_PATH: String = "res://ui/reward_choice_panel.gd"
const GAME_WORLD_SCENE_PATH: String = "res://scenes/game_world.tscn"

var _presented_events: Array = []
var _chosen_events: Array = []
var _completed_events: Array = []


func run(t) -> void:
	_test_reward_trigger_config(t)
	_test_reward_flow_offer_and_build_application(t)
	_test_reward_choice_panel_state(t)
	_test_game_world_has_reward_nodes(t)


func _test_reward_trigger_config(t) -> void:
	var rewards_cfg: Dictionary = ConfigManager.get_reward_config()
	t.assert_true(rewards_cfg.has("trigger_room_types"), "[L3-US2] reward trigger room types are JSON-configured")
	t.assert_true(rewards_cfg.get("trigger_room_types", []).has("reward"), "[L3-US2] reward room entry can trigger v1 reward step")
	t.assert_true(int(rewards_cfg.get("offer_count", 99)) <= 3, "[L3-US2] reward choices stay capped at 3")


func _test_reward_flow_offer_and_build_application(t) -> void:
	t.assert_file_exists(REWARD_FLOW_SYSTEM_PATH)
	if not FileAccess.file_exists(REWARD_FLOW_SYSTEM_PATH):
		return

	var setup: Dictionary = _make_build_managers()
	var flow: Node = load(REWARD_FLOW_SYSTEM_PATH).new()
	flow.setup(setup.get("parts_mgr"), setup.get("scale_mgr"))
	t.add_child(flow)

	_connect_recorders()
	EventBus.room_completed.emit({"room_id": "combat_test", "room_type": "combat"})
	t.assert_eq(_presented_events.size(), 0, "[L3-US2] combat room completion does not carry reward intent")
	_completed_events.clear()

	EventBus.room_entered.emit({"room_id": "reward_test", "room_type": "reward"})

	t.assert_eq(_presented_events.size(), 1, "[L3-US2] reward room entry presents one reward offer")
	var offer: Dictionary = _presented_events[0]
	var options: Array = offer.get("options", [])
	t.assert_true(options.size() > 0, "[L3-US2] reward offer has visible options")
	t.assert_true(options.size() <= 3, "[L3-US2] reward offer shows no more than three options")
	t.assert_true(flow.has_pending_offer(), "[L3-US2] reward flow tracks pending offer")

	var chosen: bool = flow.choose_reward("head_hydra")
	t.assert_true(chosen, "[L3-US2] choosing head_hydra succeeds")
	var parts_mgr: Node = setup.get("parts_mgr")
	t.assert_true(parts_mgr.has_head(), "[L3-US2] reward applied to existing head slot")
	t.assert_eq(parts_mgr.get_active_head().part_id, "hydra", "[L3-US2] selected reward equips hydra head")
	t.assert_eq(_chosen_events.size(), 1, "[L3-US2] choosing reward emits reward_chosen once")
	t.assert_eq(_completed_events.size(), 1, "[L3-US2] choosing reward completes reward room once")
	t.assert_eq(_completed_events[0].get("room_id", ""), "reward_test", "[L3-US2] completed reward room id matches source")
	t.assert_false(flow.has_pending_offer(), "[L3-US2] choosing reward clears pending offer")

	_disconnect_recorders()
	flow.cleanup()
	_cleanup_build_managers(setup)
	flow.queue_free()


func _test_reward_choice_panel_state(t) -> void:
	t.assert_file_exists(REWARD_CHOICE_PANEL_PATH)
	t.assert_file_exists(REWARD_FLOW_SYSTEM_PATH)
	if not FileAccess.file_exists(REWARD_CHOICE_PANEL_PATH) or not FileAccess.file_exists(REWARD_FLOW_SYSTEM_PATH):
		return

	var setup: Dictionary = _make_build_managers()
	var flow: Node = load(REWARD_FLOW_SYSTEM_PATH).new()
	flow.setup(setup.get("parts_mgr"), setup.get("scale_mgr"))
	t.add_child(flow)

	var panel: Control = load(REWARD_CHOICE_PANEL_PATH).new()
	panel.setup(flow)
	t.add_child(panel)

	flow.present_offer({"room_id": "combat_test", "room_type": "combat"})
	t.assert_true(panel.visible, "[L3-US2] reward panel appears when reward is presented")
	t.assert_true(panel.get_visible_option_count() > 0, "[L3-US2] reward panel lists options")
	t.assert_true(panel.get_visible_option_count() <= 3, "[L3-US2] reward panel caps visible options")
	t.assert_true(panel.get_option_labels().has("九头蛇"), "[L3-US2] reward panel shows readable option label")

	var chosen: bool = panel.choose_option_by_index(0)
	t.assert_true(chosen, "[L3-US2] reward panel can choose first option")
	t.assert_true(panel.get_status_text().find("已选择") >= 0, "[L3-US2] reward panel shows chosen feedback")

	flow.cleanup()
	_cleanup_build_managers(setup)
	panel.queue_free()
	flow.queue_free()


func _test_game_world_has_reward_nodes(t) -> void:
	var scene = load(GAME_WORLD_SCENE_PATH) as PackedScene
	t.assert_true(scene != null, "[L3-US2] game_world scene loads")
	if scene == null:
		return

	var instance = scene.instantiate()
	t.assert_true(instance.has_node("RewardFlowSystem"), "[L3-US2] game_world has RewardFlowSystem node")
	t.assert_true(instance.has_node("UI/RewardChoicePanel"), "[L3-US2] game_world has RewardChoicePanel placeholder UI")
	instance.queue_free()


func _make_build_managers() -> Dictionary:
	var mock_snake := Node2D.new()
	mock_snake.name = "RewardMockSnake"

	var parts_mgr: Node = load("res://systems/snake_parts/snake_parts_manager.gd").new()
	parts_mgr.init_manager(mock_snake, StatusEffectManager._trigger_manager, StatusEffectManager._chain_resolver)

	var scale_mgr: Node = load("res://systems/snake_parts/scale_slot_manager.gd").new()
	scale_mgr.init_manager(mock_snake, StatusEffectManager._trigger_manager, StatusEffectManager._chain_resolver)

	return {
		"mock_snake": mock_snake,
		"parts_mgr": parts_mgr,
		"scale_mgr": scale_mgr,
	}


func _cleanup_build_managers(setup: Dictionary) -> void:
	var parts_mgr: Node = setup.get("parts_mgr")
	var scale_mgr: Node = setup.get("scale_mgr")
	var mock_snake: Node = setup.get("mock_snake")
	if scale_mgr:
		scale_mgr.clear_all()
		scale_mgr.free()
	if parts_mgr:
		parts_mgr.unequip_head()
		parts_mgr.unequip_tail()
		parts_mgr.free()
	StatusEffectManager.clear_all()
	if mock_snake:
		mock_snake.free()


func _connect_recorders() -> void:
	_presented_events.clear()
	_chosen_events.clear()
	_completed_events.clear()
	EventBus.reward_presented.connect(_on_reward_presented)
	EventBus.reward_chosen.connect(_on_reward_chosen)
	EventBus.room_completed.connect(_on_room_completed)


func _disconnect_recorders() -> void:
	if EventBus.reward_presented.is_connected(_on_reward_presented):
		EventBus.reward_presented.disconnect(_on_reward_presented)
	if EventBus.reward_chosen.is_connected(_on_reward_chosen):
		EventBus.reward_chosen.disconnect(_on_reward_chosen)
	if EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.disconnect(_on_room_completed)


func _on_reward_presented(data: Dictionary) -> void:
	_presented_events.append(data)


func _on_reward_chosen(data: Dictionary) -> void:
	_chosen_events.append(data)


func _on_room_completed(data: Dictionary) -> void:
	_completed_events.append(data)
