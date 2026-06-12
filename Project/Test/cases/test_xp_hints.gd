extends RefCounted
## Phase P T106: hint_system 认知轻度引导契约（presentation_design.md §8.8）
## 无教程屏：首次事件 → 底中 caption chip 停留 hint_hold_sec；每条仅一次
## （已见列表入 meta 存档，schema_version 1 兼容新增字段）；≤1 条新概念/房间
## （被压掉的不标已见，下个房间另一次首次事件再现）；文案全部在 presentation.hints。

const HINT_PATH: String = "res://ui/hint_system.gd"


## meta 存档替身（duck-typed：get_seen_hints / mark_hint_seen）
class StubSave:
	var seen: Array = []
	func get_seen_hints() -> Array:
		return seen
	func mark_hint_seen(hint_id: String) -> void:
		if not seen.has(hint_id):
			seen.append(hint_id)


class StubRoot:
	extends Node
	var save = null
	func get_meta_save():
		return save


func run(t) -> void:
	_test_hints_config(t)
	await _test_hint_flow(t)


# === 文案全 JSON（§8.8/FR-001） ===
func _test_hints_config(t) -> void:
	var hints: Dictionary = ConfigManager.get_presentation_config().get("hints", {})
	t.assert_true(hints.size() >= 6,
		"[P106] hints covers the first-event set (got %d)" % hints.size())
	for hint_id in hints:
		t.assert_true(not str(hints[hint_id]).is_empty(),
			"[P106] hint '%s' has non-empty copy" % hint_id)
	for required in ["first_food", "first_hit", "first_reward", "first_resonance"]:
		t.assert_true(hints.has(required), "[P106] hints has '%s'" % required)
	t.assert_true(
		float(ConfigManager.get_ceremony_config().get("hint_hold_sec", 0.0)) > 0.0,
		"[P106] ceremony.hint_hold_sec > 0 (JSON)")


# === 首次事件 → caption；仅一次；≤1/房间；已见入档 ===
func _test_hint_flow(t) -> void:
	t.assert_file_exists(HINT_PATH)
	var script = load(HINT_PATH)
	if script == null:
		return
	var stub_save := StubSave.new()
	var root := StubRoot.new()
	root.save = stub_save
	t.add_child(root)

	var hint: Control = script.new()
	t.add_child(hint)
	hint.set_save_source(root)

	t.assert_false(hint.is_caption_visible(), "[P106] silent at birth")

	# 首食 → caption 文案 = hints.first_food；显示即标已见（入档）
	EventBus.snake_food_eaten.emit({"food": null, "position": Vector2i.ZERO,
		"food_type": "normal"})
	t.assert_true(hint.is_caption_visible(), "[P106] first food shows the caption")
	var expected: String = str(ConfigManager.get_presentation_config() \
		.get("hints", {}).get("first_food", ""))
	t.assert_eq(hint.get_caption_text(), expected, "[P106] copy comes from JSON")
	t.assert_true(stub_save.seen.has("first_food"), "[P106] shown hint persisted as seen")
	hint.settle()
	t.assert_false(hint.is_caption_visible(), "[P106] caption auto-hides after hold")

	# ≤1 概念/房间：同房间第二个首次事件被压掉且不标已见
	EventBus.snake_body_attacked.emit({"position": Vector2i.ZERO, "segment": null,
		"enemy": null, "status_transferred": false})
	t.assert_false(hint.is_caption_visible(),
		"[P106] second concept in the same room is suppressed")
	t.assert_false(stub_save.seen.has("first_hit"),
		"[P106] suppressed hint NOT marked seen (gets another chance)")

	# 新房间重置预算：同事件再来 → 这次显示
	EventBus.room_entered.emit({"room_id": "combat_02", "room_type": "combat",
		"intent_label": "战斗"})
	EventBus.snake_body_attacked.emit({"position": Vector2i.ZERO, "segment": null,
		"enemy": null, "status_transferred": false})
	t.assert_true(hint.is_caption_visible(), "[P106] new room re-opens the budget")
	t.assert_true(stub_save.seen.has("first_hit"), "[P106] now marked seen")
	hint.settle()

	# 每条仅一次：已见的首食不再现（跨房间也不再现）
	EventBus.room_entered.emit({"room_id": "combat_03", "room_type": "combat",
		"intent_label": "战斗"})
	EventBus.snake_food_eaten.emit({"food": null, "position": Vector2i.ZERO,
		"food_type": "normal"})
	t.assert_false(hint.is_caption_visible(), "[P106] seen hint never repeats")

	# 存档预置已见：换档后直接静默（跨进程语义经 meta save 字段）
	var fresh := StubSave.new()
	fresh.seen = ["first_reward"]
	root.save = fresh
	EventBus.room_entered.emit({"room_id": "reward_01", "room_type": "reward",
		"intent_label": "奖励"})
	EventBus.reward_presented.emit({"offer_id": "t106", "options": []})
	t.assert_false(hint.is_caption_visible(),
		"[P106] hints seen in a previous session stay silent")

	hint.queue_free()
	root.queue_free()
	await t.get_tree().process_frame
