extends RefCounted
## L4 Phase 5: Slot expansion tests (T019-T022).

const SLOT_EXPANSION_PATH: String = "res://systems/growth/slot_expansion_system.gd"

var _slot_events: Array = []


func run(t) -> void:
	_test_slot_expansion_config(t)
	_test_slot_unlock_and_tracking(t)
	_test_slot_reset(t)


func _test_slot_expansion_config(t) -> void:
	var cfg: Dictionary = ConfigManager.get_slot_expansion_config()
	t.assert_true(cfg is Dictionary, "[L4-US3] slot expansion config is Dictionary")
	var initial: Dictionary = cfg.get("initial", {})
	t.assert_eq(int(initial.get("front", 0)), 1, "[L4-US3] initial front slots = 1")
	t.assert_eq(int(initial.get("middle", 0)), 1, "[L4-US3] initial middle slots = 1")
	t.assert_eq(int(initial.get("back", 0)), 1, "[L4-US3] initial back slots = 1")
	var max_slots: Dictionary = cfg.get("max", {})
	t.assert_eq(int(max_slots.get("front", 0)), 2, "[L4-US3] max front slots = 2")
	t.assert_eq(int(max_slots.get("middle", 0)), 3, "[L4-US3] max middle slots = 3")
	t.assert_eq(int(max_slots.get("back", 0)), 2, "[L4-US3] max back slots = 2")


func _test_slot_unlock_and_tracking(t) -> void:
	t.assert_file_exists(SLOT_EXPANSION_PATH)
	if not FileAccess.file_exists(SLOT_EXPANSION_PATH):
		return

	var system: Node = load(SLOT_EXPANSION_PATH).new()
	t.add_child(system)

	_slot_events.clear()
	EventBus.slot_unlocked.connect(_on_slot_unlocked)

	t.assert_eq(system.get_total_slots(), 3, "[L4-US3] starts with 3 total slots")
	t.assert_eq(system.get_slot_count("front"), 1, "[L4-US3] front starts at 1")
	t.assert_eq(system.get_slot_count("middle"), 1, "[L4-US3] middle starts at 1")
	t.assert_eq(system.get_slot_count("back"), 1, "[L4-US3] back starts at 1")

	t.assert_true(system.can_unlock("front"), "[L4-US3] can unlock front")
	t.assert_true(system.unlock_slot("front", "boss"), "[L4-US3] front unlock succeeds")
	t.assert_eq(system.get_slot_count("front"), 2, "[L4-US3] front slots = 2 after unlock")
	t.assert_eq(system.get_total_slots(), 4, "[L4-US3] total = 4 after unlock")
	t.assert_eq(_slot_events.size(), 1, "[L4-US3] slot_unlocked emitted")

	t.assert_false(system.can_unlock("front"), "[L4-US3] cannot unlock front again (max=2)")
	t.assert_false(system.unlock_slot("front", "test"), "[L4-US3] front unlock fails at max")

	t.assert_true(system.unlock_slot("middle", "boss"), "[L4-US3] middle unlock succeeds")
	t.assert_eq(system.get_slot_count("middle"), 2, "[L4-US3] middle = 2")
	t.assert_true(system.unlock_slot("middle", "shop"), "[L4-US3] middle second unlock succeeds")
	t.assert_eq(system.get_slot_count("middle"), 3, "[L4-US3] middle = 3 (max)")
	t.assert_false(system.can_unlock("middle"), "[L4-US3] middle at max")

	t.assert_eq(system.get_unlock_history().size(), 3, "[L4-US3] unlock history tracks 3 unlocks")

	EventBus.slot_unlocked.disconnect(_on_slot_unlocked)
	system.cleanup()
	system.queue_free()


func _test_slot_reset(t) -> void:
	t.assert_file_exists(SLOT_EXPANSION_PATH)
	if not FileAccess.file_exists(SLOT_EXPANSION_PATH):
		return

	var system: Node = load(SLOT_EXPANSION_PATH).new()
	t.add_child(system)

	system.unlock_slot("front", "boss")
	system.unlock_slot("middle", "shop")
	t.assert_eq(system.get_total_slots(), 5, "[L4-US3] 5 slots before reset")

	system.reset()
	t.assert_eq(system.get_total_slots(), 3, "[L4-US3] reset to 3 slots")
	t.assert_eq(system.get_unlock_history().size(), 0, "[L4-US3] history cleared on reset")

	system.cleanup()
	system.queue_free()


func _on_slot_unlocked(data: Dictionary) -> void:
	_slot_events.append(data)