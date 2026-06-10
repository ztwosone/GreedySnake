extends RefCounted
## L4 US2 重验收测试（spec 002 T006/T009，2026-06-11 修订版 spec 对照）：
## 蜕皮货币——击杀分型入账（enemy_def 为节点，is_elite 走 ConfigManager enemy_types）、
## 跨层保留（FR-003 修订：不清零）、run 重启清零（FR-013）、放弃补偿入账（scale_option_discarded）、
## HUD chip 渐进披露（首次入账才出现，T009 ui/kit chip 重建）。

const SHEDSKIN_PATH: String = "res://systems/growth/shedskin_system.gd"
const SHEDSKIN_DISPLAY_PATH: String = "res://ui/shedskin_display.gd"

var _currency_events: Array = []


## 假敌人（duck typing：真实 payload 的 enemy_def 是带 enemy_type 属性的 Enemy 节点；
## 必须是 Node 派生——EnemyManager 等全局监听方按 Node 收参）
class MockEnemy extends Node2D:
	var enemy_type: String = ""

	func _init(type_id: String = "") -> void:
		enemy_type = type_id


func run(t) -> void:
	# 冲掉先前套件 queue_free 未落地的残留世界（其 EnemyManager 仍连着 enemy_killed）
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	_test_earn_and_spend(t)
	_test_kill_income_resolves_enemy_node_type(t)
	_test_carries_over_floors_and_resets_on_run_start(t)
	_test_discard_income(t)
	_test_display_progressive_disclosure(t)


# ── T006: 基础账本 ───────────────────────────────────────────────────

func _test_earn_and_spend(t) -> void:
	t.assert_file_exists(SHEDSKIN_PATH)
	if not FileAccess.file_exists(SHEDSKIN_PATH):
		return

	var system: Node = load(SHEDSKIN_PATH).new()
	t.add_child(system)
	_connect_recorder()

	t.assert_eq(system.get_amount(), 0, "[L4-shed] starts at 0")
	system.earn(1, "test")
	t.assert_eq(system.get_amount(), 1, "[L4-shed] earn(1) -> amount=1")
	t.assert_eq(system.get_total_earned(), 1, "[L4-shed] total_earned=1")
	t.assert_eq(_currency_events.size(), 1, "[L4-shed] currency_changed emitted on earn")

	system.earn(3, "test_elite")
	t.assert_eq(system.get_amount(), 4, "[L4-shed] earn(3) -> amount=4")
	t.assert_true(system.can_afford(3), "[L4-shed] can afford 3")
	t.assert_false(system.can_afford(5), "[L4-shed] cannot afford 5")

	t.assert_true(system.spend(2, "test_item"), "[L4-shed] spend(2) succeeds")
	t.assert_eq(system.get_amount(), 2, "[L4-shed] after spend amount=2")
	t.assert_eq(system.get_total_spent(), 2, "[L4-shed] total_spent=2")
	t.assert_false(system.spend(5, "too_expensive"), "[L4-shed] overspend fails")
	t.assert_false(system.spend(0, "zero"), "[L4-shed] spend(0) fails")
	t.assert_false(system.spend(-1, "negative"), "[L4-shed] spend(-1) fails")

	_disconnect_recorder()
	system.cleanup()
	system.queue_free()


# ── T006: 击杀分型（草稿 :87 节点被当 Dictionary 的回归） ────────────

func _test_kill_income_resolves_enemy_node_type(t) -> void:
	var cfg: Dictionary = ConfigManager.get_shedskin_config()
	var kill_normal: int = int(cfg.get("kill_normal", 0))
	var kill_elite: int = int(cfg.get("kill_elite", 0))
	t.assert_true(kill_normal > 0 and kill_elite > kill_normal, "[L4-shed] kill incomes JSON-configured")

	var system: Node = load(SHEDSKIN_PATH).new()
	t.add_child(system)
	_connect_recorder()

	var normal_enemy := MockEnemy.new("wanderer")
	var elite_enemy := MockEnemy.new("elite_chaser")

	EventBus.enemy_killed.emit({"enemy_def": normal_enemy, "position": Vector2i.ZERO, "method": "test"})
	t.assert_eq(system.get_amount(), kill_normal, "[L4-shed] normal kill earns kill_normal")

	EventBus.enemy_killed.emit({"enemy_def": elite_enemy, "position": Vector2i.ZERO, "method": "test"})
	t.assert_eq(system.get_amount(), kill_normal + kill_elite,
		"[L4-shed] elite kill resolves is_elite from enemy NODE payload (draft :87 regression)")

	EventBus.enemy_killed.emit({"enemy_def": null, "position": Vector2i.ZERO, "method": "test"})
	t.assert_eq(system.get_amount(), kill_normal * 2 + kill_elite,
		"[L4-shed] typeless kill falls back to kill_normal")

	_disconnect_recorder()
	normal_enemy.free()
	elite_enemy.free()
	system.cleanup()
	system.queue_free()


# ── T006: 跨层保留（FR-003 修订）+ run 重启清零（FR-013） ────────────

func _test_carries_over_floors_and_resets_on_run_start(t) -> void:
	var system: Node = load(SHEDSKIN_PATH).new()
	t.add_child(system)

	system.earn(10, "test")
	t.assert_eq(system.get_amount(), 10, "[L4-shed] 10 before floor transition")

	EventBus.floor_generated.emit({"floor_index": 2, "rooms": []})
	t.assert_eq(system.get_amount(), 10,
		"[L4-shed] FR-003: shedskin CARRIES OVER across floors (no reset)")
	t.assert_eq(system.get_total_earned(), 10, "[L4-shed] total_earned survives floor transition")

	EventBus.run_started.emit({"run_id": "test_run", "floor_index": 1, "seed": 1})
	t.assert_eq(system.get_amount(), 0, "[L4-shed] FR-013: run restart clears the wallet")
	t.assert_eq(system.get_total_earned(), 0, "[L4-shed] run restart clears total_earned")

	system.cleanup()
	system.queue_free()


# ── T006: 放弃补偿入账（消费 scale_option_discarded） ────────────────

func _test_discard_income(t) -> void:
	var system: Node = load(SHEDSKIN_PATH).new()
	t.add_child(system)
	_connect_recorder()

	EventBus.scale_option_discarded.emit({"offer_id": "x", "discarded_ids": ["a", "b"], "shedskin_gained": 4})
	t.assert_eq(system.get_amount(), 4, "[L4-shed] discard compensation lands in the wallet")
	t.assert_eq(_currency_events.size(), 1, "[L4-shed] discard income emits currency_changed")
	if _currency_events.size() > 0:
		t.assert_eq(_currency_events[0].get("source", ""), "scale_discard",
			"[L4-shed] discard income tagged scale_discard")

	EventBus.scale_option_discarded.emit({"offer_id": "y", "discarded_ids": [], "shedskin_gained": 0})
	t.assert_eq(system.get_amount(), 4, "[L4-shed] zero-gain discard adds nothing")
	t.assert_eq(_currency_events.size(), 1, "[L4-shed] zero-gain discard emits no event")

	_disconnect_recorder()
	system.cleanup()
	system.queue_free()


# ── T009: HUD chip 渐进披露（ui/kit chip 重建） ──────────────────────

func _test_display_progressive_disclosure(t) -> void:
	t.assert_file_exists(SHEDSKIN_DISPLAY_PATH)
	if not FileAccess.file_exists(SHEDSKIN_DISPLAY_PATH):
		return

	var display: Control = load(SHEDSKIN_DISPLAY_PATH).new()
	t.add_child(display)

	t.assert_true(display.is_in_group("ui_kit"), "[L4-shed] display born on ui/kit base")
	t.assert_true(display.is_in_group("ui_chip"), "[L4-shed] display is a kit chip")
	t.assert_eq(str(display.get_meta("ui_layer", "")), "hud", "[L4-shed] chip carries hud ui_layer meta")
	t.assert_eq(display.get_glyph_id(), "shedskin", "[L4-shed] chip uses shedskin glyph")
	t.assert_false(display.visible, "[L4-shed] chip starts hidden")

	EventBus.currency_changed.emit({"currency": "shedskin", "amount": 0, "total": 0, "source": "run_reset"})
	t.assert_false(display.visible, "[L4-shed] zero/reset events do NOT reveal the chip (progressive disclosure)")

	EventBus.currency_changed.emit({"currency": "shedskin", "amount": 5, "total": 5, "source": "test"})
	t.assert_true(display.visible, "[L4-shed] chip appears on first income")
	t.assert_eq(display.get_amount_text(), "5", "[L4-shed] chip shows balance")

	EventBus.currency_changed.emit({"currency": "other", "amount": 1, "total": 9, "source": "test"})
	t.assert_eq(display.get_amount_text(), "5", "[L4-shed] non-shedskin currency ignored")

	EventBus.currency_changed.emit({"currency": "shedskin", "amount": -2, "total": 3, "source": "shop_purchase_x"})
	t.assert_true(display.visible, "[L4-shed] chip stays visible after spending")
	t.assert_eq(display.get_amount_text(), "3", "[L4-shed] chip updates on spend")

	EventBus.game_over.emit({"cause": "test"})
	t.assert_false(display.visible, "[L4-shed] chip hides on game over")

	EventBus.currency_changed.emit({"currency": "shedskin", "amount": 2, "total": 5, "source": "test"})
	t.assert_true(display.visible, "[L4-shed] next run income reveals the chip again")
	t.assert_eq(display.get_amount_text(), "5", "[L4-shed] chip shows fresh balance")

	display.queue_free()


# ── Helpers ──────────────────────────────────────────────────────────

func _connect_recorder() -> void:
	_currency_events.clear()
	if not EventBus.currency_changed.is_connected(_on_currency_changed):
		EventBus.currency_changed.connect(_on_currency_changed)


func _disconnect_recorder() -> void:
	if EventBus.currency_changed.is_connected(_on_currency_changed):
		EventBus.currency_changed.disconnect(_on_currency_changed)


func _on_currency_changed(data: Dictionary) -> void:
	_currency_events.append(data)
