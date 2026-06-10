extends RefCounted
## L3 v1 smoke: complete one fixed run through placeholder UI controls.

const GAME_WORLD_SCENE_PATH: String = "res://scenes/game_world.tscn"

var _run_victory_events: Array = []
var _game_over_events: Array = []


func run(t) -> void:
	_test_fixed_v1_run_reaches_visual_victory(t)


func _test_fixed_v1_run_reaches_visual_victory(t) -> void:
	var saved_state: int = GameManager.current_state
	var saved_score: int = GameManager.current_score
	var saved_best: int = GameManager.best_score

	var scene = load(GAME_WORLD_SCENE_PATH) as PackedScene
	t.assert_true(scene != null, "[L3-smoke] game_world scene loads")
	if scene == null:
		return

	_run_victory_events.clear()
	_game_over_events.clear()
	EventBus.run_victory.connect(_on_run_victory)
	EventBus.game_over.connect(_on_game_over)

	var world: Node = scene.instantiate()
	t.add_child(world)
	world.start_game()
	GameManager.start_game()

	var run_system: Node = world.get_node("RunProgressionSystem")
	var room_flow: Node = world.get_node("RoomFlowSystem")
	var reward_panel: Control = world.get_node("UI/RewardChoicePanel")
	var floor_panel: Control = world.get_node("UI/FloorProgressPanel")

	room_flow.record_objective_progress(3, {"method": "smoke_combat_01"})
	t.assert_true(floor_panel.request_next_room(), "[L3-smoke] Next enters reward room")
	t.assert_eq(run_system.get_state().get("current_room_id", ""), "reward_01",
		"[L3-smoke] run reaches reward room")
	t.assert_true(reward_panel.visible, "[L3-smoke] reward panel is visible")
	t.assert_true(reward_panel.get_visible_option_count() > 0, "[L3-smoke] reward options exist")
	t.assert_true(reward_panel.choose_option_by_index(0), "[L3-smoke] reward choice applies")

	t.assert_true(floor_panel.request_next_room(), "[L3-smoke] Next enters second combat room")
	t.assert_eq(run_system.get_state().get("current_room_id", ""), "combat_02",
		"[L3-smoke] run reaches second combat room")
	room_flow.record_objective_progress(3, {"method": "smoke_combat_02"})

	t.assert_true(floor_panel.request_next_room(), "[L3-smoke] Next enters rest room")
	t.assert_eq(run_system.get_state().get("current_room_id", ""), "rest_01",
		"[L3-smoke] run reaches rest room")
	t.assert_true(floor_panel.request_next_room(), "[L3-smoke] Next enters endpoint room")

	t.assert_eq(run_system.get_state().get("outcome", ""), "victory", "[L3-smoke] run outcome is victory")
	t.assert_eq(floor_panel.get_progress_text(), "5/5", "[L3-smoke] floor progress reaches endpoint")
	t.assert_eq(_run_victory_events.size(), 1, "[L3-smoke] run_victory emitted once")
	t.assert_eq(_game_over_events.size(), 1, "[L3-smoke] GameManager emits one game_over")
	var game_over_cause: String = _game_over_events[0].get("cause", "") if _game_over_events.size() > 0 else ""
	t.assert_eq(game_over_cause, "victory", "[L3-smoke] game over cause is victory")

	world.cleanup()
	world.queue_free()
	EventBus.run_victory.disconnect(_on_run_victory)
	EventBus.game_over.disconnect(_on_game_over)
	GameManager.current_state = saved_state
	GameManager.current_score = saved_score
	GameManager.best_score = saved_best
	TickManager.stop_ticking()
	GridWorld.clear_all()


func _on_run_victory(data: Dictionary) -> void:
	_run_victory_events.append(data)


func _on_game_over(data: Dictionary) -> void:
	_game_over_events.append(data)
