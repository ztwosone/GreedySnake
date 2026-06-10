extends RefCounted
## L3 run loop foundation tests.
## T001-T008: config skeleton, typed accessors, EventBus contracts,
## RunState lifecycle, and deterministic floor map generation.

const RUN_PROGRESSION_SYSTEM_PATH: String = "res://systems/run/run_progression_system.gd"
const FLOOR_MAP_GENERATOR_PATH: String = "res://systems/rooms/floor_map_generator.gd"

var _started_events: Array = []
var _floor_events: Array = []


func run(t) -> void:
	_test_l3_config_sections(t)
	_test_l3_room_type_config(t)
	_test_l3_reward_config(t)
	_test_l3_event_contracts(t)
	_test_l3_floor_map_generation(t)
	_test_l3_run_state_lifecycle(t)


func _test_l3_config_sections(t) -> void:
	t.assert_true(ConfigManager.run is Dictionary, "[L3] run section is Dictionary")
	t.assert_true(ConfigManager.floor is Dictionary, "[L3] floor section is Dictionary")
	t.assert_true(ConfigManager.room_types is Dictionary, "[L3] room_types section is Dictionary")
	t.assert_true(ConfigManager.rewards is Dictionary, "[L3] rewards section is Dictionary")
	t.assert_true(ConfigManager.endpoint is Dictionary, "[L3] endpoint section is Dictionary")

	var run_cfg: Dictionary = ConfigManager.get_run_config()
	t.assert_true(run_cfg.get("enabled", false), "[L3] run config enabled")
	t.assert_eq(run_cfg.get("start_floor", 0), 1, "[L3] start_floor == 1")

	var floor_cfg: Dictionary = ConfigManager.get_floor_config()
	t.assert_true(int(floor_cfg.get("rooms_per_floor", 0)) >= 4, "[L3] floor has enough rooms for v1 loop")
	t.assert_true(int(floor_cfg.get("reward_choices", 99)) <= 3, "[L3] reward choices capped at 3")


func _test_l3_room_type_config(t) -> void:
	var ids: Array = ConfigManager.get_room_type_ids()
	for required in ["combat", "reward", "rest", "endpoint"]:
		t.assert_true(ids.has(required), "[L3] room type exists: %s" % required)
		var room_cfg: Dictionary = ConfigManager.get_room_type(required)
		t.assert_true(room_cfg.has("intent_label"), "[L3] %s has intent label" % required)
		t.assert_true(room_cfg.has("primary_intent"), "[L3] %s has one primary intent" % required)
		t.assert_true(room_cfg.has("placeholder_color"), "[L3] %s has placeholder color" % required)

	var combat: Dictionary = ConfigManager.get_room_type("combat")
	t.assert_eq(combat.get("objective_type", ""), "clear_enemies", "[L3] combat objective clears enemies")

	var endpoint: Dictionary = ConfigManager.get_room_type("endpoint")
	t.assert_eq(endpoint.get("objective_type", ""), "reach_endpoint", "[L3] endpoint objective reaches endpoint")


func _test_l3_reward_config(t) -> void:
	var rewards_cfg: Dictionary = ConfigManager.get_reward_config()
	t.assert_true(int(rewards_cfg.get("offer_count", 99)) <= 3, "[L3] reward offer count <= 3")
	t.assert_true(rewards_cfg.get("uses_existing_build", false), "[L3] rewards reuse existing Build")

	var pool_ids: Array = ConfigManager.get_reward_pool_ids()
	t.assert_true(pool_ids.has("starter_build"), "[L3] starter_build reward pool exists")

	var pool: Array = ConfigManager.get_reward_pool("starter_build")
	t.assert_true(pool.size() >= 3, "[L3] starter_build has at least 3 options")
	for option in pool:
		t.assert_true(option is Dictionary, "[L3] reward option is Dictionary")
		t.assert_true(option.has("reward_type"), "[L3] reward option has reward_type")
		t.assert_true(option.has("target_id"), "[L3] reward option has target_id")
		t.assert_true(option.has("placeholder_color"), "[L3] reward option has placeholder color")


func _test_l3_event_contracts(t) -> void:
	for signal_name in [
		"run_started",
		"floor_generated",
		"room_entered",
		"room_advance_requested",
		"room_objective_progressed",
		"room_completed",
		"reward_presented",
		"reward_chosen",
		"floor_completed",
		"run_victory",
	]:
		t.assert_has_signal(EventBus, signal_name)


func _test_l3_floor_map_generation(t) -> void:
	t.assert_file_exists(FLOOR_MAP_GENERATOR_PATH)
	if not FileAccess.file_exists(FLOOR_MAP_GENERATOR_PATH):
		return

	var generator_script = load(FLOOR_MAP_GENERATOR_PATH)
	var generator = generator_script.new()
	var floor_cfg: Dictionary = ConfigManager.get_floor_config()
	var expected_path: Array = floor_cfg.get("fixed_v1_path", [])
	var floor_map: Dictionary = generator.generate_floor(1, int(floor_cfg.get("default_seed", 0)))
	var rooms: Array = floor_map.get("rooms", [])
	var start_room_id: String = expected_path[0]
	var endpoint_room_id: String = expected_path[expected_path.size() - 1]

	t.assert_eq(floor_map.get("floor_index", 0), 1, "[L3] floor map keeps floor index")
	t.assert_eq(floor_map.get("seed", 0), int(floor_cfg.get("default_seed", 0)), "[L3] floor map keeps deterministic seed")
	t.assert_eq(rooms.size(), expected_path.size(), "[L3] floor map follows fixed v1 path length")
	t.assert_eq(floor_map.get("start_room_id", ""), start_room_id, "[L3] floor map start room")
	t.assert_eq(floor_map.get("endpoint_room_id", ""), endpoint_room_id, "[L3] floor map endpoint room")

	for index in range(rooms.size()):
		var room: Dictionary = rooms[index]
		t.assert_eq(room.get("room_id", ""), expected_path[index], "[L3] room id matches fixed path")
		t.assert_true(room.has("intent_label"), "[L3] generated room has readable intent")
		t.assert_true(room.has("placeholder_color"), "[L3] generated room has placeholder color")
		t.assert_true(room.get("objective", {}) is Dictionary, "[L3] generated room has objective")
		if index < rooms.size() - 1:
			t.assert_eq(room.get("exit_room_ids", []), [expected_path[index + 1]], "[L3] generated room links to next room")
		else:
			t.assert_eq(room.get("exit_room_ids", []), [], "[L3] endpoint room has no exits")


func _test_l3_run_state_lifecycle(t) -> void:
	t.assert_file_exists(RUN_PROGRESSION_SYSTEM_PATH)
	if not FileAccess.file_exists(RUN_PROGRESSION_SYSTEM_PATH):
		return

	var system_script = load(RUN_PROGRESSION_SYSTEM_PATH)
	var run_system = system_script.new()

	_started_events.clear()
	_floor_events.clear()
	EventBus.run_started.connect(_on_run_started)
	EventBus.floor_generated.connect(_on_floor_generated)

	run_system.start_run(1001)
	var state: Dictionary = run_system.get_state()
	var floor_cfg: Dictionary = ConfigManager.get_floor_config()
	var expected_path: Array = floor_cfg.get("fixed_v1_path", [])
	var start_room_id: String = expected_path[0]

	t.assert_true(run_system.is_running(), "[L3] run system enters running state")
	t.assert_eq(state.get("floor_index", 0), ConfigManager.get_run_config().get("start_floor", 1), "[L3] run starts on configured floor")
	t.assert_eq(state.get("current_room_id", ""), start_room_id, "[L3] run starts in first room")
	t.assert_eq(state.get("completed_room_ids", []), [], "[L3] run starts with no completed rooms")
	t.assert_eq(state.get("available_room_ids", []), [start_room_id], "[L3] run starts with one available room")
	t.assert_eq(state.get("outcome", ""), "running", "[L3] run outcome starts running")
	t.assert_eq(_started_events.size(), 1, "[L3] start_run emits run_started")
	t.assert_eq(_floor_events.size(), 1, "[L3] start_run emits floor_generated")

	run_system.mark_victory()
	t.assert_eq(run_system.get_state().get("outcome", ""), "victory", "[L3] mark_victory records victory outcome")
	run_system.cleanup()
	t.assert_false(run_system.is_running(), "[L3] cleanup stops run")
	t.assert_eq(run_system.get_state(), {}, "[L3] cleanup clears run state")

	EventBus.run_started.disconnect(_on_run_started)
	EventBus.floor_generated.disconnect(_on_floor_generated)


func _on_run_started(data: Dictionary) -> void:
	_started_events.append(data)


func _on_floor_generated(data: Dictionary) -> void:
	_floor_events.append(data)
