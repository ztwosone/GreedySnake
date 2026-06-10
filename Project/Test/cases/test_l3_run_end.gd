extends RefCounted
## L3 US4 tests: endpoint victory, death state, and restart-safe cleanup.

const RUN_PROGRESSION_SYSTEM_PATH: String = "res://systems/run/run_progression_system.gd"
const ROOM_FLOW_SYSTEM_PATH: String = "res://systems/rooms/room_flow_system.gd"
const GAME_WORLD_SCENE_PATH: String = "res://scenes/game_world.tscn"

var _floor_completed_events: Array = []
var _run_victory_events: Array = []


func run(t) -> void:
	_test_endpoint_auto_completion_ends_run_in_victory(t)
	_test_snake_death_marks_run_death(t)
	_test_game_world_cleanup_clears_l3_runtime_state(t)


func _test_endpoint_auto_completion_ends_run_in_victory(t) -> void:
	var setup: Dictionary = _make_run_flow_setup(t)
	var run_system: Node = setup["run_system"]
	var flow: Node = setup["flow"]
	var path: Array = ConfigManager.get_floor_config().get("fixed_v1_path", [])

	_floor_completed_events.clear()
	_run_victory_events.clear()
	EventBus.floor_completed.connect(_on_floor_completed)
	EventBus.run_victory.connect(_on_run_victory)

	_enter_and_complete_path_until_endpoint(run_system, flow, path)

	t.assert_eq(run_system.get_state().get("outcome", ""), "victory",
		"[L3-US4] endpoint auto-completion marks run victory")
	t.assert_eq(_floor_completed_events.size(), 1,
		"[L3-US4] endpoint completion emits floor_completed once")
	t.assert_eq(_run_victory_events.size(), 1,
		"[L3-US4] endpoint completion emits run_victory once")
	var victory_endpoint_id: String = _run_victory_events[0].get("endpoint_room_id", "") if _run_victory_events.size() > 0 else ""
	t.assert_eq(victory_endpoint_id, path[4],
		"[L3-US4] victory event identifies endpoint room")

	EventBus.floor_completed.disconnect(_on_floor_completed)
	EventBus.run_victory.disconnect(_on_run_victory)
	_cleanup_run_flow_setup(setup)


func _test_snake_death_marks_run_death(t) -> void:
	var saved_state: int = GameManager.current_state
	var saved_score: int = GameManager.current_score
	var saved_best: int = GameManager.best_score

	var run_system: Node = load(RUN_PROGRESSION_SYSTEM_PATH).new()
	t.add_child(run_system)
	run_system.start_run(1001)
	EventBus.snake_died.emit({"cause": "l3_test_death"})

	t.assert_eq(run_system.get_state().get("outcome", ""), "death",
		"[L3-US4] snake_died marks running L3 run as death")
	t.assert_eq(run_system.get_state().get("death_cause", ""), "l3_test_death",
		"[L3-US4] L3 death state keeps cause")

	run_system.cleanup()
	run_system.queue_free()
	GameManager.current_state = saved_state
	GameManager.current_score = saved_score
	GameManager.best_score = saved_best


func _test_game_world_cleanup_clears_l3_runtime_state(t) -> void:
	var scene = load(GAME_WORLD_SCENE_PATH) as PackedScene
	t.assert_true(scene != null, "[L3-US4] game_world scene loads for cleanup test")
	if scene == null:
		return

	var world: Node = scene.instantiate()
	t.add_child(world)
	world.start_game()

	var run_system: Node = world.get_node("RunProgressionSystem")
	var room_flow: Node = world.get_node("RoomFlowSystem")
	var reward_flow: Node = world.get_node("RewardFlowSystem")
	var path: Array = ConfigManager.get_floor_config().get("fixed_v1_path", [])

	room_flow.record_objective_progress(3, {"method": "cleanup_test"})
	run_system.advance_to_room(path[1])
	t.assert_true(reward_flow.has_pending_offer(),
		"[L3-US4] cleanup test reaches pending reward state")

	world.cleanup()
	t.assert_eq(run_system.get_state(), {}, "[L3-US4] cleanup clears run state")
	t.assert_eq(room_flow.get_current_room(), {}, "[L3-US4] cleanup clears room state")
	t.assert_false(reward_flow.has_pending_offer(), "[L3-US4] cleanup clears pending reward")
	t.assert_false(TickManager.is_ticking, "[L3-US4] cleanup stops TickManager")
	TickManager.stop_ticking()

	world.queue_free()
	GridWorld.clear_all()


func _make_run_flow_setup(t) -> Dictionary:
	var run_system: Node = load(RUN_PROGRESSION_SYSTEM_PATH).new()
	var flow: Node = load(ROOM_FLOW_SYSTEM_PATH).new()
	t.add_child(run_system)
	t.add_child(flow)
	run_system.start_run(1001)
	flow.enter_room(run_system.get_current_room())
	return {"run_system": run_system, "flow": flow}


func _cleanup_run_flow_setup(setup: Dictionary) -> void:
	var flow: Node = setup.get("flow")
	var run_system: Node = setup.get("run_system")
	if flow and flow.has_method("cleanup"):
		flow.cleanup()
	if run_system and run_system.has_method("cleanup"):
		run_system.cleanup()
	if flow:
		flow.queue_free()
	if run_system:
		run_system.queue_free()


func _enter_and_complete_path_until_endpoint(run_system: Node, flow: Node, path: Array) -> void:
	flow.record_objective_progress(3, {"method": "test_combat_01"})
	run_system.advance_to_room(path[1])
	flow.record_objective_progress(1, {"method": "test_reward"})
	run_system.advance_to_room(path[2])
	flow.record_objective_progress(3, {"method": "test_combat_02"})
	run_system.advance_to_room(path[3])
	run_system.advance_to_room(path[4])


func _on_floor_completed(data: Dictionary) -> void:
	_floor_completed_events.append(data)


func _on_run_victory(data: Dictionary) -> void:
	_run_victory_events.append(data)
