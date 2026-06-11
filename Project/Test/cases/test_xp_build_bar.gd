extends RefCounted
## Phase P T104c: Build 状态条 + 拾取物世界内闪烁标记契约（presentation_design.md §8.6/§8.7）
## 状态条（底中）：[头][前…][中…][后…][尾] 槽位格；空槽虚框；装备/升级 bounce + 等级点；
## 共鸣 = 相邻格间青色连线（get_active_pairs 槽位定位）+ 首次发现 caption。
## 纯监听 + 注入系统只读查询（§11.1）；数据驱动 _draw（minimap 同范式）。

const BAR_PATH: String = "res://ui/build_status_bar.gd"
const PICKUP_PATH: String = "res://entities/pickups/pickup_entity.gd"


## duck-typed 注入替身（只读查询面）
class StubSlots:
	var layout: Dictionary = {"front": [null], "middle": [null, null], "back": [null]}
	func get_slot_layout(position: String) -> Array:
		return layout.get(position, [])


class StubParts:
	var head = null
	var tail = null
	func get_active_head():
		return head
	func get_active_tail():
		return tail


class StubResonance:
	var pairs: Array = []
	func get_active_pairs() -> Array:
		return pairs


class FakeScale:
	var part_id: String = ""
	var level: int = 1
	func _init(id: String, lv: int = 1) -> void:
		part_id = id
		level = lv


func run(t) -> void:
	await _test_build_bar(t)
	_test_pickup_blink(t)


func _test_build_bar(t) -> void:
	t.assert_file_exists(BAR_PATH)
	var script = load(BAR_PATH)
	if script == null:
		return
	var bar: Control = script.new()
	t.add_child(bar)

	t.assert_true(bar.is_in_group("ui_kit"), "[P104c] bar in ui_kit group")
	t.assert_eq(str(bar.get_meta("ui_layer", "")), "hud", "[P104c] bar on hud layer")
	t.assert_false(bar.visible, "[P104c] hidden before setup (渐进披露：无 Build 系统不显示)")

	var slots := StubSlots.new()
	var parts := StubParts.new()
	var resonance := StubResonance.new()
	bar.setup(parts, slots, resonance)
	t.assert_true(bar.visible, "[P104c] visible after setup")

	# 格序：头 + front(1) + middle(2) + back(1) + 尾 = 6
	t.assert_eq(bar.get_cell_count(), 6, "[P104c] cells = head + open slots + tail")
	t.assert_eq(bar.get_occupied_count(), 0, "[P104c] all empty at start")

	# 装备刷新（事件驱动重读注入查询）
	slots.layout["front"] = [FakeScale.new("greedy_scale", 2)]
	parts.head = FakeScale.new("hydra", 1)
	EventBus.snake_scale_equipped.emit({"scale_id": "greedy_scale", "level": 2,
		"position": "front"})
	t.assert_eq(bar.get_occupied_count(), 2, "[P104c] equip event re-reads head+scale")

	# 共鸣连线：活跃对按 part_id 定位到槽位格
	slots.layout["middle"] = [FakeScale.new("swift_scale", 1), null]
	resonance.pairs = [{"resonance_id": "boil", "part_a": "greedy_scale",
		"part_b": "swift_scale"}]
	EventBus.resonance_activated.emit({"resonance_id": "boil",
		"display_name": "沸毒", "is_new_discovery": false})
	t.assert_eq(bar.get_link_count(), 1, "[P104c] active pair draws one resonance link")

	# 首次发现 caption：is_new_discovery=true 显示 → settle 后收起
	t.assert_false(bar.is_caption_visible(), "[P104c] no caption for re-discovery")
	EventBus.resonance_activated.emit({"resonance_id": "boil2",
		"display_name": "新共鸣", "is_new_discovery": true})
	t.assert_true(bar.is_caption_visible(), "[P104c] new discovery shows caption")
	t.assert_true(bar.get_caption_text().contains("新共鸣"),
		"[P104c] caption carries the display name")
	bar.settle()
	t.assert_false(bar.is_caption_visible(), "[P104c] caption auto-hides (settled)")

	# 共鸣停用：连线消失
	resonance.pairs = []
	EventBus.resonance_deactivated.emit({"resonance_id": "boil"})
	t.assert_eq(bar.get_link_count(), 0, "[P104c] deactivation clears the link")

	bar.queue_free()
	await t.get_tree().process_frame


# === §8.7 前半：拾取物世界内闪烁标记 ===
func _test_pickup_blink(t) -> void:
	var script = load(PICKUP_PATH)
	t.assert_true(script != null, "[P104c] pickup_entity loads")
	if script == null:
		return
	# 纯函数闪烁曲线：相位变化产生 [low,1] 区间内的不同 alpha（JSON 驱动频率）
	var has_helper: bool = false
	for m in script.get_script_method_list():
		if str(m.get("name", "")) == "blink_alpha":
			has_helper = true
	t.assert_true(has_helper, "[P104c] pickup has static blink_alpha helper")
	if not has_helper:
		return
	var hz: float = float(ConfigManager.get_game_feel().get("pickup_blink_hz", 0.0))
	t.assert_true(hz > 0.0, "[P104c] game_feel.pickup_blink_hz > 0 (JSON)")
	var a0: float = script.blink_alpha(0.0)
	var a1: float = script.blink_alpha(0.25 / hz)
	t.assert_true(absf(a0 - a1) > 0.05, "[P104c] blink curve actually varies with phase")
	for a in [a0, a1]:
		t.assert_true(a >= 0.5 and a <= 1.0,
			"[P104c] blink alpha stays readable in [0.5, 1.0] (got %f)" % a)
