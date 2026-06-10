extends RefCounted
## L3 US1 tests: enter one room, show one intent, progress one objective,
## and complete it through existing enemy_killed events.

const ROOM_FLOW_SYSTEM_PATH: String = "res://systems/rooms/room_flow_system.gd"
const ROOM_INTENT_PANEL_PATH: String = "res://ui/room_intent_panel.gd"
const GAME_WORLD_SCENE_PATH: String = "res://scenes/game_world.tscn"

var _entered_events: Array = []
var _progress_events: Array = []
var _completed_events: Array = []


func run(t) -> void:
	_test_combat_room_objective_config(t)
	_test_room_flow_entry_progress_and_completion(t)
	_test_room_intent_panel_state(t)
	_test_game_world_has_l3_room_nodes(t)
	_test_acceptance_scenes_tolerate_missing_l3_nodes(t)


func _test_combat_room_objective_config(t) -> void:
	var combat: Dictionary = ConfigManager.get_room_type("combat")
	t.assert_true(combat.has("required_count"), "[L3-US1] combat room required_count is JSON-configured")
	t.assert_eq(int(combat.get("required_count", 0)), int(combat.get("enemy_count", 0)), "[L3-US1] combat required_count matches configured enemy_count")
	t.assert_eq(int(combat.get("enemy_count", 0)), 3, "[L3-US1] combat room enemy_count is JSON-configured")


func _test_room_flow_entry_progress_and_completion(t) -> void:
	t.assert_file_exists(ROOM_FLOW_SYSTEM_PATH)
	if not FileAccess.file_exists(ROOM_FLOW_SYSTEM_PATH):
		return

	var flow_script = load(ROOM_FLOW_SYSTEM_PATH)
	var flow: Node = flow_script.new()
	t.add_child(flow)

	_connect_recorders()
	var room: Dictionary = _make_combat_room()
	flow.enter_room(room)

	t.assert_eq(_entered_events.size(), 1, "[L3-US1] entering room emits room_entered once")
	t.assert_eq(flow.get_current_room().get("room_id", ""), "combat_test", "[L3-US1] flow tracks current room")
	t.assert_false(flow.is_current_room_complete(), "[L3-US1] room starts incomplete")

	EventBus.enemy_killed.emit({"enemy_def": null, "position": Vector2i.ZERO, "method": "test"})
	t.assert_eq(_progress_events.size(), 1, "[L3-US1] first kill emits objective progress")
	t.assert_eq(_progress_events[0].get("current", 0), 1, "[L3-US1] first kill sets progress to 1")
	t.assert_eq(_progress_events[0].get("required", 0), 3, "[L3-US1] progress event includes required count")
	t.assert_eq(_completed_events.size(), 0, "[L3-US1] first kill does not complete room")

	EventBus.enemy_killed.emit({"enemy_def": null, "position": Vector2i.ZERO, "method": "test"})
	t.assert_false(flow.is_current_room_complete(), "[L3-US1] second kill does not complete three-kill room")
	t.assert_eq(_completed_events.size(), 0, "[L3-US1] second kill does not emit completion")

	EventBus.enemy_killed.emit({"enemy_def": null, "position": Vector2i.ZERO, "method": "test"})
	t.assert_true(flow.is_current_room_complete(), "[L3-US1] third kill completes room")
	t.assert_eq(_completed_events.size(), 1, "[L3-US1] completion emits once")
	t.assert_eq(_completed_events[0].get("room_id", ""), "combat_test", "[L3-US1] completion identifies room")

	EventBus.enemy_killed.emit({"enemy_def": null, "position": Vector2i.ZERO, "method": "test"})
	t.assert_eq(_completed_events.size(), 1, "[L3-US1] extra kills do not duplicate completion")

	_disconnect_recorders()
	if flow.has_method("cleanup"):
		flow.cleanup()
	flow.queue_free()


func _test_room_intent_panel_state(t) -> void:
	t.assert_file_exists(ROOM_INTENT_PANEL_PATH)
	if not FileAccess.file_exists(ROOM_INTENT_PANEL_PATH):
		return

	var panel_script = load(ROOM_INTENT_PANEL_PATH)
	var panel: Control = panel_script.new()
	t.add_child(panel)

	EventBus.room_entered.emit(_make_combat_room())
	t.assert_true(panel.visible, "[L3-US1] room intent panel appears on room_entered")
	t.assert_eq(panel.get_intent_text(), "清空敌人", "[L3-US1] panel shows room intent")

	EventBus.room_objective_progressed.emit({
		"room_id": "combat_test",
		"objective_type": "clear_enemies",
		"current": 1,
		"required": 2,
	})
	t.assert_eq(panel.get_progress_text(), "1/2", "[L3-US1] panel shows objective progress")

	EventBus.room_completed.emit({"room_id": "combat_test", "room_type": "combat"})
	t.assert_true(panel.get_status_text().find("完成") >= 0, "[L3-US1] panel shows completion state")

	panel.queue_free()


func _test_game_world_has_l3_room_nodes(t) -> void:
	var scene = load(GAME_WORLD_SCENE_PATH) as PackedScene
	t.assert_true(scene != null, "[L3-US1] game_world scene loads")
	if scene == null:
		return

	var instance = scene.instantiate()
	t.assert_true(instance.has_node("RunProgressionSystem"), "[L3-US1] game_world has RunProgressionSystem node")
	t.assert_true(instance.has_node("RoomFlowSystem"), "[L3-US1] game_world has RoomFlowSystem node")
	t.assert_true(instance.has_node("UI/RoomIntentPanel"), "[L3-US1] game_world has RoomIntentPanel placeholder UI")
	instance.queue_free()


func _test_acceptance_scenes_tolerate_missing_l3_nodes(t) -> void:
	for path in ["res://scenes/l1_acceptance.tscn", "res://scenes/l2_acceptance.tscn"]:
		var scene = load(path) as PackedScene
		t.assert_true(scene != null, "[L3-US1-fix] %s loads" % path)
		if scene == null:
			continue
		var instance = scene.instantiate()
		t.assert_true(instance != null, "[L3-US1-fix] %s instantiates without required L3 child nodes" % path)
		t.add_child(instance)
		t.assert_true(instance.is_inside_tree(), "[L3-US1-fix] %s enters tree without required L3 child nodes" % path)
		if instance.has_method("cleanup"):
			instance.cleanup()
		t.remove_child(instance)
		instance.free()


func _make_combat_room() -> Dictionary:
	var combat: Dictionary = ConfigManager.get_room_type("combat")
	return {
		"room_id": "combat_test",
		"room_type": "combat",
		"intent_label": combat.get("intent_label", "清空敌人"),
		"primary_intent": combat.get("primary_intent", "clear_enemies"),
		"objective": {
			"objective_type": combat.get("objective_type", "clear_enemies"),
			"required_count": int(combat.get("required_count", 3)),
			"current_count": 0,
			"complete": false,
		},
		"placeholder_color": combat.get("placeholder_color", "#B84444"),
		"exit_room_ids": [],
		"enabled": true,
		"available": true,
		"completed": false,
	}


func _connect_recorders() -> void:
	_entered_events.clear()
	_progress_events.clear()
	_completed_events.clear()
	EventBus.room_entered.connect(_on_room_entered)
	EventBus.room_objective_progressed.connect(_on_room_objective_progressed)
	EventBus.room_completed.connect(_on_room_completed)


func _disconnect_recorders() -> void:
	if EventBus.room_entered.is_connected(_on_room_entered):
		EventBus.room_entered.disconnect(_on_room_entered)
	if EventBus.room_objective_progressed.is_connected(_on_room_objective_progressed):
		EventBus.room_objective_progressed.disconnect(_on_room_objective_progressed)
	if EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.disconnect(_on_room_completed)


func _on_room_entered(data: Dictionary) -> void:
	_entered_events.append(data)


func _on_room_objective_progressed(data: Dictionary) -> void:
	_progress_events.append(data)


func _on_room_completed(data: Dictionary) -> void:
	_completed_events.append(data)
