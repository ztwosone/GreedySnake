extends RefCounted
## L3 v1 Automated Acceptance Test
## Covers SC-001 through SC-005 in a headless automated run.
## Verifies: full path smoke run, room intent visibility, reward cap,
## room type independence, and restart-safe cleanup.

const GAME_WORLD_PATH: String = "res://scenes/game_world.tscn"

var _events: Array = []


func run(t) -> void:
	_test_sc001_full_smoke_run(t)
	_test_sc002_room_type_independence(t)
	_test_sc003_room_intent_visible(t)
	_test_sc004_reward_cap(t)
	_test_sc005_cleanup_restart(t)


# ── SC-001: Full deterministic smoke run ────────────────────────────

func _test_sc001_full_smoke_run(t) -> void:
	var world: Node = _load_and_start_game_world(t, "[SC-001]")
	if world == null:
		return

	var run_sys = world.get_node("RunProgressionSystem")
	var room_flow = world.get_node("RoomFlowSystem")
	var floor_panel: Control = world.get_node("UI/FloorProgressPanel")
	var reward_panel: Control = world.get_node("UI/RewardChoicePanel")

	var path: Array = ConfigManager.get_floor_config().get("fixed_v1_path", [])
	t.assert_eq(path.size(), 5, "[SC-001] fixed v1 path has 5 rooms")
	t.assert_eq(run_sys.get_state().get("current_room_id", ""), path[0],
		"[SC-001] run starts in %s" % path[0])

	# combat_01: verify room flow started
	t.assert_false(room_flow.is_current_room_complete(),
		"[SC-001] combat_01 starts incomplete")
	t.assert_eq(floor_panel.get_progress_text(), "1/5",
		"[SC-001] floor progress shows 1/5")
	room_flow.record_objective_progress(3, {"method": "acceptance"})
	t.assert_true(room_flow.is_current_room_complete(),
		"[SC-001] combat_01 completes after 3 kills")
	# spec 002 T010：战斗房完成弹鳞片 offer（FR-015 门控），放弃后才能推进
	t.assert_true(world.get_node("UI/ScaleChoicePanel").discard_offer(),
		"[SC-001] resolve scale offer after combat_01")

	# reward_01
	t.assert_true(floor_panel.request_next_room(),
		"[SC-001] advance to reward_01")
	t.assert_eq(run_sys.get_state().get("current_room_id", ""), path[1],
		"[SC-001] run reaches reward_01")
	t.assert_true(reward_panel.visible,
		"[SC-001] reward panel visible")
	var opt_count: int = reward_panel.get_visible_option_count()
	t.assert_true(opt_count > 0,
		"[SC-001] reward options exist")
	t.assert_true(opt_count <= 3,
		"[SC-001] reward options ≤3")
	t.assert_true(reward_panel.choose_option_by_index(0),
		"[SC-001] reward choice applied")

	# combat_02
	t.assert_true(floor_panel.request_next_room(),
		"[SC-001] advance to combat_02")
	t.assert_eq(run_sys.get_state().get("current_room_id", ""), path[2],
		"[SC-001] run reaches combat_02")
	room_flow.record_objective_progress(3, {"method": "acceptance"})
	t.assert_true(world.get_node("UI/ScaleChoicePanel").discard_offer(),
		"[SC-001] resolve scale offer after combat_02")

	# rest_01
	t.assert_true(floor_panel.request_next_room(),
		"[SC-001] advance to rest_01")
	t.assert_eq(run_sys.get_state().get("current_room_id", ""), path[3],
		"[SC-001] run reaches rest_01")
	t.assert_true(room_flow.is_current_room_complete(),
		"[SC-001] rest_01 auto-completes")

	# endpoint_01
	t.assert_true(floor_panel.request_next_room(),
		"[SC-001] advance to endpoint_01")
	t.assert_eq(run_sys.get_state().get("outcome", ""), "victory",
		"[SC-001] endpoint triggers victory")
	t.assert_eq(floor_panel.get_progress_text(), "5/5",
		"[SC-001] floor progress reaches 5/5")

	_cleanup_world(world)


# ── SC-002: Room type independence ──────────────────────────────────

func _test_sc002_room_type_independence(t) -> void:
	for room_type in ["combat", "reward", "rest", "endpoint"]:
		var cfg: Dictionary = ConfigManager.get_room_type(room_type)
		t.assert_true(not cfg.is_empty(),
			"[SC-002] %s room config loads" % room_type)
		t.assert_true(cfg.has("intent_label"),
			"[SC-002] %s has intent_label" % room_type)
		t.assert_true(cfg.has("primary_intent"),
			"[SC-002] %s has primary_intent" % room_type)
		t.assert_true(cfg.has("placeholder_color"),
			"[SC-002] %s has placeholder_color" % room_type)
		t.assert_true(cfg.has("objective_type"),
			"[SC-002] %s has objective_type" % room_type)

		t.assert_true(len(cfg.get("intent_label", "")) > 0,
			"[SC-002] %s intent_label non-empty" % room_type)
		var color_str: String = cfg.get("placeholder_color", "")
		t.assert_true(color_str.begins_with("#"),
			"[SC-002] %s placeholder_color is hex string" % room_type)


# ── SC-003: Room intent visible from placeholder feedback ───────────

func _test_sc003_room_intent_visible(t) -> void:
	var world: Node = _load_and_start_game_world(t, "[SC-003]")
	if world == null:
		return

	var intent_panel: Control = world.get_node("UI/RoomIntentPanel")
	t.assert_true(intent_panel.visible,
		"[SC-003] RoomIntentPanel visible on room enter")

	# Combat room intent
	t.assert_eq(intent_panel.get_intent_text(), "清空敌人",
		"[SC-003] combat room shows '清空敌人' intent")
	t.assert_eq(intent_panel.get_status_text(), "进行中",
		"[SC-003] combat room shows '进行中' status")
	t.assert_eq(intent_panel.get_progress_text(), "0/3",
		"[SC-003] combat room progress starts at 0/3")
	var intent_color: Color = intent_panel.get_placeholder_color()
	t.assert_true(intent_color is Color,
		"[SC-003] combat room has valid placeholder color")

	# Progress through combat
	var room_flow = world.get_node("RoomFlowSystem")
	room_flow.record_objective_progress(1)
	t.assert_eq(intent_panel.get_progress_text(), "1/3",
		"[SC-003] progress updates to 1/3")
	room_flow.record_objective_progress(2)
	t.assert_eq(intent_panel.get_progress_text(), "3/3",
		"[SC-003] progress updates to 3/3")
	t.assert_true(intent_panel.get_status_text().find("完成") >= 0,
		"[SC-003] status shows completion after objective met")

	# Advance to reward_01 and check intent changed
	# spec 002 T010：先决议鳞片 offer（FR-015 门控）
	world.get_node("UI/ScaleChoicePanel").discard_offer()
	var floor_panel: Control = world.get_node("UI/FloorProgressPanel")
	floor_panel.request_next_room()
	t.assert_eq(intent_panel.get_intent_text(), "选择奖励",
		"[SC-003] reward room shows '选择奖励' intent")

	_cleanup_world(world)


# ── SC-004: Reward screen ≤3 options ────────────────────────────────

func _test_sc004_reward_cap(t) -> void:
	var world: Node = _load_and_start_game_world(t, "[SC-004]")
	if world == null:
		return

	var room_flow = world.get_node("RoomFlowSystem")
	var floor_panel: Control = world.get_node("UI/FloorProgressPanel")
	var reward_panel: Control = world.get_node("UI/RewardChoicePanel")

	room_flow.record_objective_progress(3, {"method": "acceptance"})
	# spec 002 T010：先决议鳞片 offer（FR-015 门控）
	world.get_node("UI/ScaleChoicePanel").discard_offer()
	floor_panel.request_next_room()

	t.assert_true(reward_panel.visible,
		"[SC-004] reward panel is visible at reward room")
	t.assert_true(reward_panel.get_visible_option_count() > 0,
		"[SC-004] at least one reward option available")
	t.assert_true(reward_panel.get_visible_option_count() <= 3,
		"[SC-004] reward options capped at 3 (got %d)" % reward_panel.get_visible_option_count())

	var labels: Array = reward_panel.get_option_labels()
	for label in labels:
		t.assert_true(len(str(label)) > 0,
			"[SC-004] reward option label '%s' non-empty" % label)

	t.assert_true(reward_panel.choose_option_by_index(0),
		"[SC-004] can choose first reward option")
	t.assert_true(reward_panel.get_status_text().find("已选择") >= 0,
		"[SC-004] reward panel shows '已选择' after choice")
	t.assert_true(reward_panel.get_visible_option_count() == 0,
		"[SC-004] option list cleared after choice")

	_cleanup_world(world)


# ── SC-005: Restart-safe cleanup ────────────────────────────────────

func _test_sc005_cleanup_restart(t) -> void:
	var world: Node = _load_and_start_game_world(t, "[SC-005-cleanup]")
	if world == null:
		return

	var run_sys = world.get_node("RunProgressionSystem")
	var room_flow = world.get_node("RoomFlowSystem")
	var floor_panel: Control = world.get_node("UI/FloorProgressPanel")
	var reward_panel: Control = world.get_node("UI/RewardChoicePanel")

	# Complete combat_01
	room_flow.record_objective_progress(3, {"method": "acceptance"})
	# spec 002 T010：先决议鳞片 offer（FR-015 门控）
	world.get_node("UI/ScaleChoicePanel").discard_offer()

	# Enter reward_01 and choose a reward
	floor_panel.request_next_room()
	t.assert_true(reward_panel.visible, "[SC-005] reward panel visible before cleanup")
	reward_panel.choose_option_by_index(0)

	# Cleanup world
	_cleanup_world(world)

	# Verify core systems are clean
	t.assert_false(TickManager.is_ticking,
		"[SC-005] TickManager stopped after cleanup")

	# Now start a new world and verify no L3 state leaked
	var world2: Node = _load_and_start_game_world(t, "[SC-005-restart]")
	if world2 == null:
		return

	var run_sys2 = world2.get_node("RunProgressionSystem")
	var room_flow2 = world2.get_node("RoomFlowSystem")
	var reward_panel2: Control = world2.get_node("UI/RewardChoicePanel")

	var state2: Dictionary = run_sys2.get_state()
	t.assert_eq(state2.get("completed_room_ids", ["X"]), [],
		"[SC-005] restart has no completed rooms")
	t.assert_eq(state2.get("outcome", ""), "running",
		"[SC-005] restart outcome is 'running' (not leftover victory/death)")
	t.assert_false(room_flow2.is_current_room_complete(),
		"[SC-005] restart room starts incomplete")
	t.assert_false(reward_panel2.visible,
		"[SC-005] reward panel hidden on restart")

	_cleanup_world(world2)


# ── Helpers ─────────────────────────────────────────────────────────

func _load_and_start_game_world(t, tag: String) -> Node:
	var saved_state: int = GameManager.current_state
	var saved_score: int = GameManager.current_score
	var saved_best: int = GameManager.best_score

	GameManager.current_state = GameManager.GameState.PLAYING
	GameManager.current_score = 0
	GameManager.best_score = 0

	var scene = load(GAME_WORLD_PATH) as PackedScene
	if scene == null:
		t.assert_true(false, "%s game_world scene failed to load" % tag)
		return null

	var world: Node = scene.instantiate()
	t.add_child(world)
	world.start_game()
	GameManager.start_game()

	return world


func _cleanup_world(world: Node) -> void:
	if world.has_method("cleanup"):
		world.cleanup()
	if world.is_inside_tree():
		world.queue_free()
