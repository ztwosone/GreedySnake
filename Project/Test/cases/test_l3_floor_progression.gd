extends RefCounted
## L3 US3 tests: fixed v1 path reveals and advances rooms in order.

const RUN_PROGRESSION_SYSTEM_PATH: String = "res://systems/run/run_progression_system.gd"
const ROOM_FLOW_SYSTEM_PATH: String = "res://systems/rooms/room_flow_system.gd"
const FLOOR_PROGRESS_PANEL_PATH: String = "res://ui/floor_progress_panel.gd"
const GAME_WORLD_SCENE_PATH: String = "res://scenes/game_world.tscn"

var _entered_events: Array = []
var _floor_completed_events: Array = []
var _advance_requested_events: Array = []


func run(t) -> void:
	_test_fixed_path_reveals_and_advances_in_order(t)
	_test_ignores_locked_or_non_current_completion(t)
	_test_room_flow_syncs_on_run_progression_advance(t)
	_test_v1_rest_and_endpoint_auto_complete_on_entry(t)
	_test_run_progression_handles_advance_request(t)
	_test_floor_progress_panel_state(t)
	_test_floor_progress_panel_can_request_next_room(t)
	_test_game_world_has_floor_progress_ui(t)


func _test_fixed_path_reveals_and_advances_in_order(t) -> void:
	t.assert_file_exists(RUN_PROGRESSION_SYSTEM_PATH)
	if not FileAccess.file_exists(RUN_PROGRESSION_SYSTEM_PATH):
		return

	var run_system: Node = load(RUN_PROGRESSION_SYSTEM_PATH).new()
	t.add_child(run_system)
	run_system.start_run(1001)

	var floor_cfg: Dictionary = ConfigManager.get_floor_config()
	var path: Array = floor_cfg.get("fixed_v1_path", [])
	t.assert_eq(run_system.get_state().get("current_room_id", ""), path[0], "[L3-US3] run starts at first path room")

	EventBus.room_completed.emit({"room_id": path[0], "room_type": "combat"})
	var state_after_first: Dictionary = run_system.get_state()
	t.assert_true(state_after_first.get("completed_room_ids", []).has(path[0]), "[L3-US3] completed room is recorded")
	t.assert_true(state_after_first.get("available_room_ids", []).has(path[1]), "[L3-US3] next room becomes available")
	t.assert_eq(state_after_first.get("current_room_id", ""), path[0], "[L3-US3] completion alone does not auto-enter next room")

	_entered_events.clear()
	EventBus.room_entered.connect(_on_room_entered)
	var advanced: bool = run_system.advance_to_room(path[1])
	t.assert_true(advanced, "[L3-US3] can advance to available next room")
	t.assert_eq(run_system.get_state().get("current_room_id", ""), path[1], "[L3-US3] current room updates after advance")
	t.assert_eq(_entered_events.size(), 1, "[L3-US3] advance emits room_entered")
	t.assert_eq(_entered_events[0].get("room_id", ""), path[1], "[L3-US3] room_entered identifies advanced room")

	var skipped: bool = run_system.advance_to_room(path[3])
	t.assert_false(skipped, "[L3-US3] cannot skip locked rooms")

	run_system.cleanup()
	t.assert_eq(run_system.get_state(), {}, "[L3-US3] cleanup clears floor progression state")
	EventBus.room_entered.disconnect(_on_room_entered)
	run_system.queue_free()


func _test_ignores_locked_or_non_current_completion(t) -> void:
	var run_system: Node = load(RUN_PROGRESSION_SYSTEM_PATH).new()
	t.add_child(run_system)
	run_system.start_run(1001)

	var path: Array = ConfigManager.get_floor_config().get("fixed_v1_path", [])
	EventBus.room_completed.emit({"room_id": path[3], "room_type": "rest"})

	var state_after_locked_event: Dictionary = run_system.get_state()
	t.assert_false(state_after_locked_event.get("completed_room_ids", []).has(path[3]),
		"[L3-US3-fix] locked/non-current room completion is ignored")
	t.assert_false(state_after_locked_event.get("available_room_ids", []).has(path[4]),
		"[L3-US3-fix] locked/non-current room does not unlock endpoint")

	run_system.cleanup()
	run_system.queue_free()


func _test_room_flow_syncs_on_run_progression_advance(t) -> void:
	t.assert_file_exists(ROOM_FLOW_SYSTEM_PATH)
	if not FileAccess.file_exists(ROOM_FLOW_SYSTEM_PATH):
		return

	var run_system: Node = load(RUN_PROGRESSION_SYSTEM_PATH).new()
	var flow: Node = load(ROOM_FLOW_SYSTEM_PATH).new()
	t.add_child(run_system)
	t.add_child(flow)
	run_system.start_run(1001)

	var path: Array = ConfigManager.get_floor_config().get("fixed_v1_path", [])
	flow.enter_room(run_system.get_current_room())
	flow.record_objective_progress(3, {"method": "test"})
	run_system.advance_to_room(path[1])

	t.assert_eq(flow.get_current_room().get("room_id", ""), path[1],
		"[L3-US3-fix] RoomFlow follows RunProgression room advance")
	t.assert_eq(flow.get_current_room().get("objective", {}).get("objective_type", ""), "claim_reward",
		"[L3-US3-fix] RoomFlow objective resets for advanced room")

	flow.cleanup()
	run_system.cleanup()
	flow.queue_free()
	run_system.queue_free()


func _test_v1_rest_and_endpoint_auto_complete_on_entry(t) -> void:
	var floor_map: Dictionary = _make_floor_map()
	var rest_room: Dictionary = _find_room(floor_map, "rest_01")
	var endpoint_room: Dictionary = _find_room(floor_map, "endpoint_01")
	t.assert_true(bool(rest_room.get("auto_complete_on_enter", false)),
		"[L3-US3-fix] rest room is configured to auto-complete for v1")
	t.assert_true(bool(endpoint_room.get("auto_complete_on_enter", false)),
		"[L3-US3-fix] endpoint room is configured to auto-complete for v1")

	var run_system: Node = load(RUN_PROGRESSION_SYSTEM_PATH).new()
	var flow: Node = load(ROOM_FLOW_SYSTEM_PATH).new()
	t.add_child(run_system)
	t.add_child(flow)
	run_system.start_run(1001)

	var path: Array = ConfigManager.get_floor_config().get("fixed_v1_path", [])
	flow.enter_room(run_system.get_current_room())
	flow.record_objective_progress(3, {"method": "test"})
	run_system.advance_to_room(path[1])
	flow.record_objective_progress(1, {"method": "test_reward"})
	run_system.advance_to_room(path[2])
	flow.record_objective_progress(3, {"method": "test"})
	run_system.advance_to_room(path[3])  # shop_01：spec 002 T016，auto_complete_on_enter
	run_system.advance_to_room(path[4])  # rest_01

	var state_after_rest: Dictionary = run_system.get_state()
	t.assert_true(state_after_rest.get("completed_room_ids", []).has(path[3]),
		"[L3-US3-fix] entering shop auto-completes the shop room")
	t.assert_true(state_after_rest.get("completed_room_ids", []).has(path[4]),
		"[L3-US3-fix] entering rest auto-completes the rest room")
	t.assert_true(state_after_rest.get("available_room_ids", []).has(path[5]),
		"[L3-US3-fix] rest completion unlocks endpoint")

	flow.cleanup()
	run_system.cleanup()
	flow.queue_free()
	run_system.queue_free()


func _test_run_progression_handles_advance_request(t) -> void:
	if not EventBus.has_signal("room_advance_requested"):
		return

	var run_system: Node = load(RUN_PROGRESSION_SYSTEM_PATH).new()
	var flow: Node = load(ROOM_FLOW_SYSTEM_PATH).new()
	t.add_child(run_system)
	t.add_child(flow)
	run_system.start_run(1001)

	var path: Array = ConfigManager.get_floor_config().get("fixed_v1_path", [])
	flow.enter_room(run_system.get_current_room())
	flow.record_objective_progress(3, {"method": "test"})
	EventBus.room_advance_requested.emit({"room_id": path[1]})

	t.assert_eq(run_system.get_state().get("current_room_id", ""), path[1],
		"[L3-US4] room_advance_requested advances run state")
	t.assert_eq(flow.get_current_room().get("room_id", ""), path[1],
		"[L3-US4] room_advance_requested keeps RoomFlow in sync")

	flow.cleanup()
	run_system.cleanup()
	flow.queue_free()
	run_system.queue_free()


func _test_floor_progress_panel_state(t) -> void:
	t.assert_file_exists(FLOOR_PROGRESS_PANEL_PATH)
	if not FileAccess.file_exists(FLOOR_PROGRESS_PANEL_PATH):
		return

	var panel: Control = load(FLOOR_PROGRESS_PANEL_PATH).new()
	t.add_child(panel)
	var floor_map: Dictionary = _make_floor_map()
	EventBus.floor_generated.emit(floor_map)
	t.assert_true(panel.visible, "[L3-US3] floor progress panel appears when floor is generated")
	t.assert_eq(panel.get_progress_text(), "1/6", "[L3-US3] floor progress starts at first room")

	EventBus.room_completed.emit({"room_id": "combat_01", "room_type": "combat"})
	t.assert_eq(panel.get_progress_text(), "1/6", "[L3-US3] progress does not advance until next room entered")
	t.assert_true(panel.get_status_text().find("完成") >= 0,
		"[L3-US3-fix] floor progress shows completed/advance feedback")

	EventBus.room_entered.emit({"room_id": "reward_01", "room_type": "reward", "intent_label": "选择奖励"})
	t.assert_eq(panel.get_progress_text(), "2/6", "[L3-US3] progress advances when next room entered")
	t.assert_true(panel.get_status_text().find("选择奖励") >= 0, "[L3-US3] floor progress shows current room intent")

	panel.queue_free()


func _test_floor_progress_panel_can_request_next_room(t) -> void:
	var panel: Control = load(FLOOR_PROGRESS_PANEL_PATH).new()
	t.add_child(panel)
	EventBus.floor_generated.emit(_make_floor_map())
	EventBus.room_completed.emit({"room_id": "combat_01", "room_type": "combat"})

	t.assert_true(panel.has_method("request_next_room"),
		"[L3-US4] floor progress panel exposes next-room request")
	if not EventBus.has_signal("room_advance_requested"):
		panel.queue_free()
		return
	_advance_requested_events.clear()
	EventBus.room_advance_requested.connect(_on_room_advance_requested)
	if panel.has_method("request_next_room"):
		panel.request_next_room()

	t.assert_eq(_advance_requested_events.size(), 1,
		"[L3-US4] floor progress panel emits room_advance_requested once")
	var requested_room_id: String = _advance_requested_events[0].get("room_id", "") if _advance_requested_events.size() > 0 else ""
	t.assert_eq(requested_room_id, "reward_01",
		"[L3-US4] floor progress panel requests next available room")

	EventBus.room_advance_requested.disconnect(_on_room_advance_requested)
	panel.queue_free()


func _test_game_world_has_floor_progress_ui(t) -> void:
	var scene = load(GAME_WORLD_SCENE_PATH) as PackedScene
	t.assert_true(scene != null, "[L3-US3] game_world scene loads")
	if scene == null:
		return

	var instance = scene.instantiate()
	t.assert_true(instance.has_node("UI/FloorProgressPanel"), "[L3-US3] game_world has FloorProgressPanel placeholder UI")
	instance.queue_free()


func _make_floor_map() -> Dictionary:
	return load("res://systems/rooms/floor_map_generator.gd").new().generate_floor(1, 1001)


func _find_room(floor_map: Dictionary, room_id: String) -> Dictionary:
	for room in floor_map.get("rooms", []):
		if room is Dictionary and room.get("room_id", "") == room_id:
			return room
	return {}


func _on_room_entered(data: Dictionary) -> void:
	_entered_events.append(data)


func _on_room_advance_requested(data: Dictionary) -> void:
	_advance_requested_events.append(data)
