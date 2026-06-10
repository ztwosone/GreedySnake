extends RefCounted
## L4 Phase 2: Shedskin currency tests (T005).

const SHEDSKIN_PATH: String = "res://systems/growth/shedskin_system.gd"
const SHEDSKIN_DISPLAY_PATH: String = "res://ui/shedskin_display.gd"

var _currency_events: Array = []


func run(t) -> void:
	_test_shedskin_earn_and_spend(t)
	_test_shedskin_floor_reset(t)
	_test_shedskin_display(t)


func _test_shedskin_earn_and_spend(t) -> void:
	t.assert_file_exists(SHEDSKIN_PATH)
	if not FileAccess.file_exists(SHEDSKIN_PATH):
		return

	var system: Node = load(SHEDSKIN_PATH).new()
	t.add_child(system)

	_currency_events.clear()
	EventBus.currency_changed.connect(_on_currency_changed)

	t.assert_eq(system.get_amount(), 0, "[L4-shed] starts at 0")
	t.assert_eq(system.get_total_earned(), 0, "[L4-shed] total_earned starts at 0")
	t.assert_eq(system.get_total_spent(), 0, "[L4-shed] total_spent starts at 0")

	system.earn(1, "test")
	t.assert_eq(system.get_amount(), 1, "[L4-shed] earn(1) → amount=1")
	t.assert_eq(system.get_total_earned(), 1, "[L4-shed] total_earned=1")
	t.assert_eq(_currency_events.size(), 1, "[L4-shed] currency_changed emitted on earn")

	system.earn(3, "test_elite")
	t.assert_eq(system.get_amount(), 4, "[L4-shed] earn(3) → amount=4")
	t.assert_eq(system.get_total_earned(), 4, "[L4-shed] total_earned=4")

	t.assert_true(system.can_afford(3), "[L4-shed] can afford 3")
	t.assert_false(system.can_afford(5), "[L4-shed] cannot afford 5")

	t.assert_true(system.spend(2, "test_item"), "[L4-shed] spend(2) succeeds")
	t.assert_eq(system.get_amount(), 2, "[L4-shed] after spend amount=2")
	t.assert_eq(system.get_total_spent(), 2, "[L4-shed] total_spent=2")

	t.assert_false(system.spend(5, "too_expensive"), "[L4-shed] spend(5) fails when insufficient")
	t.assert_eq(system.get_amount(), 2, "[L4-shed] amount unchanged after failed spend")

	t.assert_false(system.spend(0, "zero"), "[L4-shed] spend(0) fails")
	t.assert_false(system.spend(-1, "negative"), "[L4-shed] spend(-1) fails")

	EventBus.currency_changed.disconnect(_on_currency_changed)
	system.cleanup()
	system.queue_free()


func _test_shedskin_floor_reset(t) -> void:
	t.assert_file_exists(SHEDSKIN_PATH)
	if not FileAccess.file_exists(SHEDSKIN_PATH):
		return

	var system: Node = load(SHEDSKIN_PATH).new()
	t.add_child(system)

	system.earn(10, "test")
	t.assert_eq(system.get_amount(), 10, "[L4-shed] 10 before floor transition")

	EventBus.floor_generated.emit({"floor_index": 2, "rooms": []})
	t.assert_eq(system.get_amount(), 0, "[L4-shed] reset to 0 on new floor")
	t.assert_eq(system.get_total_earned(), 0, "[L4-shed] total_earned reset")

	system.cleanup()
	system.queue_free()


func _test_shedskin_display(t) -> void:
	t.assert_file_exists(SHEDSKIN_DISPLAY_PATH)
	if not FileAccess.file_exists(SHEDSKIN_DISPLAY_PATH):
		return

	var display: Control = load(SHEDSKIN_DISPLAY_PATH).new()
	t.add_child(display)

	t.assert_false(display.visible, "[L4-shed] display starts hidden")

	EventBus.currency_changed.emit({"currency": "shedskin", "amount": 5, "total": 5, "source": "test"})
	t.assert_true(display.visible, "[L4-shed] display becomes visible on shedskin change")
	t.assert_eq(display.get_amount_text(), "5", "[L4-shed] display shows correct amount")

	EventBus.currency_changed.emit({"currency": "other", "amount": 1, "total": 1, "source": "test"})
	t.assert_eq(display.get_amount_text(), "5", "[L4-shed] display ignores non-shedskin currency")

	EventBus.game_over.emit({"cause": "test"})
	t.assert_false(display.visible, "[L4-shed] display hides on game over")

	display.queue_free()


func _on_currency_changed(data: Dictionary) -> void:
	_currency_events.append(data)