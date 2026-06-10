extends RefCounted
## L4 Phase 8: Difficulty and room modifier tests (T032-T036).

const DIFFICULTY_PATH: String = "res://systems/difficulty/difficulty_scaler.gd"
const MODIFIER_PATH: String = "res://systems/difficulty/room_modifier_system.gd"

var _diff_events: Array = []
var _mod_events: Array = []


func run(t) -> void:
	_test_difficulty_scaler(t)
	_test_room_modifiers(t)


func _test_difficulty_scaler(t) -> void:
	t.assert_file_exists(DIFFICULTY_PATH)
	if not FileAccess.file_exists(DIFFICULTY_PATH):
		return

	var system: Node = load(DIFFICULTY_PATH).new()
	t.add_child(system)

	t.assert_true(system.get_score() > 0.0, "[L4-US6] initial score > 0")

	system.record_room_completion(20, 1, 2)
	system.record_room_completion(15, 0, 4)
	t.assert_true(system.get_score() > 0.0, "[L4-US6] score recalculated after rooms")

	var delta: int = system.get_enemy_count_delta()
	t.assert_true(delta >= -1 and delta <= 1, "[L4-US6] enemy delta in range [-1, 1]")

	system.cleanup()
	system.queue_free()


func _test_room_modifiers(t) -> void:
	t.assert_file_exists(MODIFIER_PATH)
	if not FileAccess.file_exists(MODIFIER_PATH):
		return

	var system: Node = load(MODIFIER_PATH).new()
	t.add_child(system)

	_mod_events.clear()
	EventBus.room_modifier_applied.connect(_on_modifier_applied)

	t.assert_true(system.apply_modifier("darkness", "room_test"), "[L4-US6] darkness modifier applied")
	t.assert_eq(_mod_events.size(), 1, "[L4-US6] room_modifier_applied emitted")
	t.assert_true(system.has_modifier("room_test", "darkness"), "[L4-US6] has_modifier returns true")

	t.assert_true(system.apply_modifier("speed_strips", "room_test"), "[L4-US6] speed_strips modifier applied")
	t.assert_eq(system.get_active_modifiers().size(), 2, "[L4-US6] 2 active modifiers")

	system.remove_modifiers("room_test")
	t.assert_eq(system.get_active_modifiers().size(), 0, "[L4-US6] modifiers removed on room completion")

	t.assert_false(system.apply_modifier("nonexistent", "room_test"), "[L4-US6] nonexistent modifier fails")

	EventBus.room_modifier_applied.disconnect(_on_modifier_applied)
	system.cleanup()
	system.queue_free()


func _on_modifier_applied(data: Dictionary) -> void:
	_mod_events.append(data)