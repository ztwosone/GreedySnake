extends RefCounted
## L4 US1 重验收测试（spec 002 T004/T007/T008/T010，2026-06-11 修订版 spec 对照）：
## 鳞片奖励链——恰 3 选项（FR-001）、幻影二次 offer 回归、无合成 room_completed（FR-018）、
## 满槽替换（US1 场景 3）、按开放槽过滤、空池自动决议（FR-014）、放弃蜕皮补偿（US2 场景 2）、
## 模态门控（FR-015：RunProgression 忽略推进 + FloorProgressPanel Next 禁用）、
## L3 RewardFlowSystem 空选项自动决议（T007 回补）与 game_world 全链集成（T010）。

const SCALE_REWARD_PATH: String = "res://systems/growth/scale_reward_system.gd"
const SCALE_CHOICE_PANEL_PATH: String = "res://ui/scale_choice_panel.gd"
const SCALE_SLOT_MANAGER_PATH: String = "res://systems/snake_parts/scale_slot_manager.gd"
const RUN_PROGRESSION_PATH: String = "res://systems/run/run_progression_system.gd"
const REWARD_FLOW_PATH: String = "res://systems/rewards/reward_flow_system.gd"
const FLOOR_PROGRESS_PANEL_PATH: String = "res://ui/floor_progress_panel.gd"
const GAME_WORLD_SCENE_PATH: String = "res://scenes/game_world.tscn"

var _presented_events: Array = []
var _chosen_events: Array = []
var _discarded_events: Array = []
var _room_completed_events: Array = []
var _reward_presented_events: Array = []
var _reward_chosen_events: Array = []


## 假槽位管理器（duck typing，ScriptingLeading 附录 C.8：测试不裸引用全局 class_name）
class MockSlotManager extends RefCounted:
	var locked_positions: Array = []
	var equipped: Dictionary = {}
	var equip_calls: Array = []

	func has_open_slot(position: String) -> bool:
		if locked_positions.has(position):
			return false
		return equipped.get(position, []).is_empty()

	func get_scales(position: String) -> Array:
		return equipped.get(position, []).duplicate()

	func equip_scale(position: String, scale_id: String, level: int = 1) -> bool:
		if locked_positions.has(position) or not equipped.get(position, []).is_empty():
			return false
		equipped[position] = [scale_id]
		equip_calls.append({"position": position, "scale_id": scale_id, "level": level})
		return true

	func unequip_scale(position: String, slot_index: int) -> void:
		var list: Array = equipped.get(position, [])
		if slot_index >= 0 and slot_index < list.size():
			list.remove_at(slot_index)
			equipped[position] = list


func run(t) -> void:
	_test_offer_presents_exactly_three_options(t)
	_test_choose_has_no_phantom_offer_and_no_synthetic_room_completed(t)
	_test_full_slot_choice_replaces_old_scale(t)
	_test_options_filtered_by_open_slots(t)
	_test_empty_pool_auto_resolves(t)
	_test_discard_grants_shedskin_compensation(t)
	_test_run_progression_ignores_advance_while_offer_pending(t)
	_test_floor_progress_next_disabled_while_offer_pending(t)
	_test_reward_flow_empty_offer_auto_resolves(t)
	_test_scale_choice_panel_public_api(t)
	await _test_game_world_scale_reward_chain(t)


# ── T004: offer 呈现（FR-001） ───────────────────────────────────────

func _test_offer_presents_exactly_three_options(t) -> void:
	t.assert_file_exists(SCALE_REWARD_PATH)
	if not FileAccess.file_exists(SCALE_REWARD_PATH):
		return

	var cfg: Dictionary = ConfigManager.get_scale_reward_config()
	t.assert_eq(int(cfg.get("offer_count", 0)), 3, "[L4-US1] offer_count = 3 (JSON)")
	t.assert_true(cfg.get("trigger_room_types", []).has("combat"),
		"[L4-US1] combat triggers scale reward (JSON)")
	t.assert_true(cfg.has("default_pool"),
		"[L4-US1] default pool id is JSON-configured (no magic pool id in code)")

	var setup: Dictionary = _make_real_slot_manager()
	var system: Node = load(SCALE_REWARD_PATH).new()
	system.setup(setup["scale_mgr"])
	t.add_child(system)
	_connect_recorders()

	var offer: Dictionary = system.present_offer({"room_id": "combat_a", "room_type": "combat"})
	t.assert_eq(_presented_events.size(), 1, "[L4-US1] scale_reward_presented emitted once")
	t.assert_eq(offer.get("options", []).size(), 3, "[L4-US1] offer has exactly 3 options")
	if _presented_events.size() > 0:
		var payload: Dictionary = _presented_events[0]
		t.assert_eq(payload.get("room_id", ""), "combat_a", "[L4-US1] presented payload carries room_id")
		t.assert_true(str(payload.get("offer_id", "")) != "", "[L4-US1] presented payload carries offer_id")
		for option in payload.get("options", []):
			t.assert_true(option is Dictionary and option.has("option_id") and option.has("target_id")
				and option.has("target_slot") and option.has("display_name"),
				"[L4-US1] option carries id/target/slot/name")
	t.assert_true(system.has_pending_offer(), "[L4-US1] pending offer tracked")

	system.present_offer({"room_id": "combat_a2", "room_type": "combat"})
	t.assert_eq(_presented_events.size(), 1, "[L4-US1] pending offer blocks a second present")

	t.assert_true(system.discard_offer(), "[L4-US1] discard resolves the offer")
	_teardown_system(setup, system)


# ── T004: 幻影二次 offer 回归 + FR-018 无合成 room_completed ──────────

func _test_choose_has_no_phantom_offer_and_no_synthetic_room_completed(t) -> void:
	var setup: Dictionary = _make_real_slot_manager()
	var system: Node = load(SCALE_REWARD_PATH).new()
	system.setup(setup["scale_mgr"])
	t.add_child(system)
	_connect_recorders()

	EventBus.room_completed.emit({"room_id": "combat_b", "room_type": "combat",
		"intent_label": "清空敌人", "objective": {}, "exit_room_ids": []})
	t.assert_eq(_presented_events.size(), 1, "[L4-US1] combat room_completed triggers one offer")
	t.assert_eq(_room_completed_events.size(), 1, "[L4-US1] baseline: one room_completed recorded")

	var sd: int = int(ConfigManager.get_shedskin_config().get("scale_discard", 0))
	t.assert_true(system.choose_scale(0), "[L4-US1] choosing first option succeeds")
	t.assert_eq(_chosen_events.size(), 1, "[L4-US1] scale_reward_chosen emitted once")
	if _chosen_events.size() > 0:
		t.assert_eq(_chosen_events[0].get("skipped", true), false, "[L4-US1] normal choice is not skipped")
		t.assert_true(str(_chosen_events[0].get("scale_id", "")) != "", "[L4-US1] chosen payload carries scale_id")
	t.assert_eq(_presented_events.size(), 1, "[L4-US1] no phantom second offer after choosing")
	t.assert_eq(_room_completed_events.size(), 1,
		"[L4-US1] FR-018: ScaleRewardSystem emits NO synthetic room_completed")
	t.assert_eq(_discarded_events.size(), 1, "[L4-US2] unchosen options discarded on choice")
	if _discarded_events.size() > 0:
		t.assert_eq(_discarded_events[0].get("discarded_ids", []).size(), 2,
			"[L4-US2] choosing discards the other two options")
		t.assert_eq(int(_discarded_events[0].get("shedskin_gained", 0)), 2 * sd,
			"[L4-US2] each discarded option compensates scale_discard shedskin")
	t.assert_false(system.has_pending_offer(), "[L4-US1] pending cleared after choice")
	t.assert_eq(setup["scale_mgr"].get_all_scales().size(), 1, "[L4-US1] chosen scale equipped via ScaleSlotManager")

	_teardown_system(setup, system)


# ── T004: 满槽替换（US1 场景 3 / Edge「all slots full」） ─────────────

func _test_full_slot_choice_replaces_old_scale(t) -> void:
	var setup: Dictionary = _make_real_slot_manager()
	var scale_mgr: Node = setup["scale_mgr"]
	t.assert_true(scale_mgr.equip_scale("front", "greedy_scale", 1), "[L4-US1] precondition: front filled")
	t.assert_true(scale_mgr.equip_scale("middle", "flame_scale", 1), "[L4-US1] precondition: middle filled")
	t.assert_true(scale_mgr.equip_scale("back", "thorn_scale", 1), "[L4-US1] precondition: back filled")

	var system: Node = load(SCALE_REWARD_PATH).new()
	system.setup(scale_mgr)
	t.add_child(system)
	_connect_recorders()

	var offer: Dictionary = system.present_offer({"room_id": "combat_c", "room_type": "combat"})
	t.assert_eq(offer.get("options", []).size(), 3,
		"[L4-US1] full slots still offer 3 options (replacement, not forced slot purchase)")
	if offer.get("options", []).size() > 0:
		var option: Dictionary = offer.get("options", [])[0]
		t.assert_true(system.choose_scale(0), "[L4-US1] choosing with full slot succeeds via replacement")
		var slot: String = str(option.get("target_slot", ""))
		var scales: Array = scale_mgr.get_scales(slot)
		t.assert_eq(scales.size(), 1, "[L4-US1] replacement keeps one scale in the slot")
		if scales.size() > 0:
			t.assert_eq(scales[0].part_id, str(option.get("target_id", "")),
				"[L4-US1] old scale replaced by the chosen one")

	_teardown_system(setup, system)


# ── T004: 按开放槽过滤 ───────────────────────────────────────────────

func _test_options_filtered_by_open_slots(t) -> void:
	var mock := MockSlotManager.new()
	mock.locked_positions = ["front"]
	var system: Node = load(SCALE_REWARD_PATH).new()
	system.setup(mock)
	t.add_child(system)
	_connect_recorders()

	var offer: Dictionary = system.present_offer({"room_id": "combat_d", "room_type": "combat"})
	t.assert_eq(offer.get("options", []).size(), 3, "[L4-US1] filtered offer still fills 3 options")
	for option in offer.get("options", []):
		t.assert_true(str(option.get("target_slot", "")) != "front",
			"[L4-US1] options for positions without any usable slot are filtered out")

	system.discard_offer()
	system.cleanup()
	system.queue_free()
	_disconnect_recorders()


# ── T004: 空池自动决议（FR-014） ─────────────────────────────────────

func _test_empty_pool_auto_resolves(t) -> void:
	var mock := MockSlotManager.new()
	var system: Node = load(SCALE_REWARD_PATH).new()
	system.setup(mock)
	t.add_child(system)
	_connect_recorders()

	var offer: Dictionary = system.present_offer({"room_id": "combat_e", "room_type": "combat"}, "no_such_pool")
	t.assert_eq(_presented_events.size(), 0, "[L4-FR014] empty pool presents no modal")
	t.assert_eq(_chosen_events.size(), 1, "[L4-FR014] empty pool auto-resolves with chosen event")
	if _chosen_events.size() > 0:
		t.assert_eq(_chosen_events[0].get("skipped", false), true, "[L4-FR014] auto-resolution carries skipped=true")
	t.assert_true(offer.is_empty(), "[L4-FR014] auto-resolved offer returns empty")
	t.assert_false(system.has_pending_offer(), "[L4-FR014] no pending offer after auto-resolve")

	# 零合格选项（全部位置不可承载）同样自动决议
	mock.locked_positions = ["front", "middle", "back"]
	system.present_offer({"room_id": "combat_e2", "room_type": "combat"})
	t.assert_eq(_presented_events.size(), 0, "[L4-FR014] zero eligible options presents no modal")
	t.assert_eq(_chosen_events.size(), 2, "[L4-FR014] zero eligible options auto-resolves too")
	t.assert_false(system.has_pending_offer(), "[L4-FR014] run progression can continue")

	system.cleanup()
	system.queue_free()
	_disconnect_recorders()


# ── T004: 放弃蜕皮补偿（US2 场景 2 / SC-002） ────────────────────────

func _test_discard_grants_shedskin_compensation(t) -> void:
	var mock := MockSlotManager.new()
	var system: Node = load(SCALE_REWARD_PATH).new()
	system.setup(mock)
	t.add_child(system)
	_connect_recorders()

	var sd: int = int(ConfigManager.get_shedskin_config().get("scale_discard", 0))
	t.assert_true(sd > 0, "[L4-US2] scale_discard compensation is JSON-configured")

	var offer: Dictionary = system.present_offer({"room_id": "combat_f", "room_type": "combat"})
	var option_count: int = offer.get("options", []).size()
	t.assert_eq(system.get_discard_reward(), option_count * sd,
		"[L4-US2] discard reward = option count x scale_discard")

	t.assert_true(system.discard_offer(), "[L4-US2] discarding the whole offer succeeds")
	t.assert_eq(_discarded_events.size(), 1, "[L4-US2] scale_option_discarded emitted once")
	if _discarded_events.size() > 0:
		t.assert_eq(_discarded_events[0].get("discarded_ids", []).size(), option_count,
			"[L4-US2] all options discarded")
		t.assert_eq(int(_discarded_events[0].get("shedskin_gained", 0)), option_count * sd,
			"[L4-US2] discard grants +scale_discard per option")
	t.assert_eq(_chosen_events.size(), 0, "[L4-US2] discard path emits no chosen event")
	t.assert_false(system.has_pending_offer(), "[L4-US2] pending cleared after discard")
	t.assert_false(system.discard_offer(), "[L4-US2] double discard rejected")

	system.cleanup()
	system.queue_free()
	_disconnect_recorders()


# ── T007: RunProgression 模态门控（FR-015） ──────────────────────────

func _test_run_progression_ignores_advance_while_offer_pending(t) -> void:
	var run_system: Node = load(RUN_PROGRESSION_PATH).new()
	t.add_child(run_system)
	run_system.start_run(1001)
	var path: Array = ConfigManager.get_floor_config().get("fixed_v1_path", [])

	EventBus.room_completed.emit({"room_id": path[0], "room_type": "combat"})
	t.assert_false(run_system.has_pending_offer(), "[L4-FR015] no pending offer before presented")

	EventBus.scale_reward_presented.emit({"offer_id": "gate_1", "room_id": path[0], "options": []})
	t.assert_true(run_system.has_pending_offer(), "[L4-FR015] scale offer registers as pending")
	EventBus.room_advance_requested.emit({"room_id": path[1]})
	t.assert_eq(run_system.get_state().get("current_room_id", ""), path[0],
		"[L4-FR015] advance request ignored while scale offer pending")

	EventBus.scale_option_discarded.emit({"offer_id": "gate_1", "discarded_ids": [], "shedskin_gained": 0})
	t.assert_false(run_system.has_pending_offer(), "[L4-FR015] discard releases the gate")
	EventBus.room_advance_requested.emit({"room_id": path[1]})
	t.assert_eq(run_system.get_state().get("current_room_id", ""), path[1],
		"[L4-FR015] advance works after resolution")

	# L3 reward 家族走同一门控
	EventBus.room_completed.emit({"room_id": path[1], "room_type": "reward"})
	EventBus.reward_presented.emit({"offer_id": "gate_2", "options": []})
	EventBus.room_advance_requested.emit({"room_id": path[2]})
	t.assert_eq(run_system.get_state().get("current_room_id", ""), path[1],
		"[L4-FR015] advance ignored while L3 reward offer pending")
	EventBus.reward_chosen.emit({"offer_id": "gate_2", "chosen_option_id": "x", "option": {}})
	EventBus.room_advance_requested.emit({"room_id": path[2]})
	t.assert_eq(run_system.get_state().get("current_room_id", ""), path[2],
		"[L4-FR015] reward resolution releases the gate")

	# floor reward 家族（T5 发射方落地前先锁契约）
	EventBus.floor_reward_presented.emit({"floor_index": 1, "options": []})
	t.assert_true(run_system.has_pending_offer(), "[L4-FR015] floor reward offer registers as pending")
	EventBus.floor_reward_chosen.emit({"category": "expansion", "option_id": "x"})
	t.assert_false(run_system.has_pending_offer(), "[L4-FR015] floor reward resolution releases the gate")

	run_system.cleanup()
	run_system.queue_free()


# ── T007/T008: FloorProgressPanel Next 禁用（FR-015 UI 侧） ──────────

func _test_floor_progress_next_disabled_while_offer_pending(t) -> void:
	var panel: Control = load(FLOOR_PROGRESS_PANEL_PATH).new()
	t.add_child(panel)
	var floor_map: Dictionary = load("res://systems/rooms/floor_map_generator.gd").new().generate_floor(1, 1001)
	EventBus.floor_generated.emit(floor_map)
	EventBus.room_completed.emit({"room_id": "combat_01", "room_type": "combat"})
	t.assert_false(panel.get_next_button().disabled, "[L4-FR015] Next enabled with no pending offer")

	EventBus.scale_reward_presented.emit({"offer_id": "gate_ui", "room_id": "combat_01", "options": []})
	t.assert_true(panel.get_next_button().disabled, "[L4-FR015] Next disabled while offer pending")
	t.assert_false(panel.request_next_room(), "[L4-FR015] request_next_room refuses while offer pending")

	EventBus.scale_reward_chosen.emit({"offer_id": "gate_ui", "option_id": "x", "scale_id": "flame_scale",
		"position": "middle", "level": 1, "skipped": false})
	t.assert_false(panel.get_next_button().disabled, "[L4-FR015] Next re-enabled after resolution")
	t.assert_true(panel.request_next_room(), "[L4-FR015] request_next_room works after resolution")

	panel.queue_free()


# ── T007: L3 RewardFlowSystem 空选项自动决议回补（FR-014） ───────────

func _test_reward_flow_empty_offer_auto_resolves(t) -> void:
	var flow: Node = load(REWARD_FLOW_PATH).new()
	flow.setup(null, null)
	t.add_child(flow)
	_connect_recorders()

	var offer: Dictionary = flow.present_offer({"room_id": "reward_x", "room_type": "reward"})
	t.assert_eq(_reward_presented_events.size(), 0, "[L3-FR014] zero applicable options presents no modal")
	t.assert_eq(_reward_chosen_events.size(), 1, "[L3-FR014] auto-resolves with reward_chosen")
	if _reward_chosen_events.size() > 0:
		t.assert_eq(_reward_chosen_events[0].get("skipped", false), true,
			"[L3-FR014] auto-resolution carries skipped=true")
	t.assert_eq(_room_completed_events.size(), 1,
		"[L3-FR014] synthetic room_completed keeps the reward room completion pathway (FR-018 scope note)")
	if _room_completed_events.size() > 0:
		t.assert_eq(_room_completed_events[0].get("room_id", ""), "reward_x",
			"[L3-FR014] synthetic completion identifies the reward room")
	t.assert_true(offer.is_empty(), "[L3-FR014] auto-resolved offer returns empty")
	t.assert_false(flow.has_pending_offer(), "[L3-FR014] no pending offer left behind")

	flow.cleanup()
	flow.queue_free()
	_disconnect_recorders()


# ── T008: 面板公共 API（ui/kit 构建） ────────────────────────────────

func _test_scale_choice_panel_public_api(t) -> void:
	t.assert_file_exists(SCALE_CHOICE_PANEL_PATH)
	if not FileAccess.file_exists(SCALE_CHOICE_PANEL_PATH):
		return

	var setup: Dictionary = _make_real_slot_manager()
	var system: Node = load(SCALE_REWARD_PATH).new()
	system.setup(setup["scale_mgr"])
	t.add_child(system)

	var panel: Control = load(SCALE_CHOICE_PANEL_PATH).new()
	panel.setup(system)
	t.add_child(panel)
	_connect_recorders()

	t.assert_false(panel.visible, "[L4-US1] panel starts hidden")
	t.assert_true(panel.is_in_group("ui_kit"), "[L4-US1] panel born on ui/kit base")
	t.assert_true(panel.is_in_group("ui_modal"), "[L4-US1] panel joins ui_modal group (geometry probe)")
	t.assert_eq(str(panel.get_meta("ui_layer", "")), "modal", "[L4-US1] panel carries modal ui_layer meta")

	system.present_offer({"room_id": "combat_ui", "room_type": "combat"})
	t.assert_true(panel.visible, "[L4-US1] panel visible on scale_reward_presented")
	t.assert_eq(panel.get_visible_option_count(), 3, "[L4-US1] 3 options visible")
	t.assert_eq(panel.get_option_cards().size(), 3, "[L4-US1] options rendered as kit choice cards")
	for card in panel.get_option_cards():
		t.assert_true(card.is_in_group("ui_kit"), "[L4-US1] option card is a kit component")
	for label in panel.get_option_labels():
		t.assert_true(str(label).length() > 0, "[L4-US1] option labels readable")
	var sd: int = int(ConfigManager.get_shedskin_config().get("scale_discard", 0))
	t.assert_true(panel.get_discard_label_text().find(str(3 * sd)) >= 0,
		"[L4-US2] discard entry labels +N shedskin from config")

	t.assert_true(panel.choose_option_by_index(0), "[L4-US1] choose via panel public API")
	t.assert_false(panel.visible, "[L4-US1] panel hides after choice")
	t.assert_eq(panel.get_visible_option_count(), 0, "[L4-US1] options cleared after choice")

	system.present_offer({"room_id": "combat_ui2", "room_type": "combat"})
	t.assert_true(panel.visible, "[L4-US1] panel visible on second offer")
	var discards_before: int = _discarded_events.size()
	t.assert_true(panel.discard_offer(), "[L4-US2] discard via panel public API")
	t.assert_false(panel.visible, "[L4-US2] panel hides after discard")
	t.assert_eq(_discarded_events.size(), discards_before + 1,
		"[L4-US2] panel discard emits scale_option_discarded")

	system.present_offer({"room_id": "combat_ui3", "room_type": "combat"})
	EventBus.game_over.emit({"cause": "test"})
	t.assert_false(panel.visible, "[L4-US1] panel hides on game over")

	panel.queue_free()
	_teardown_system(setup, system)


# ── T010: game_world 集成全链 ────────────────────────────────────────

func _test_game_world_scale_reward_chain(t) -> void:
	var saved_state: int = GameManager.current_state
	var saved_score: int = GameManager.current_score
	var saved_best: int = GameManager.best_score

	var scene = load(GAME_WORLD_SCENE_PATH) as PackedScene
	t.assert_true(scene != null, "[L4-T010] game_world scene loads")
	if scene == null:
		return

	var world: Node = scene.instantiate()
	var wired: bool = world.has_node("ScaleRewardSystem") and world.has_node("ShedskinSystem") \
		and world.has_node("UI/ScaleChoicePanel") and world.has_node("UI/ShedskinDisplay")
	t.assert_true(world.has_node("ScaleRewardSystem"), "[L4-T010] game_world has ScaleRewardSystem node")
	t.assert_true(world.has_node("ShedskinSystem"), "[L4-T010] game_world has ShedskinSystem node")
	t.assert_true(world.has_node("UI/ScaleChoicePanel"), "[L4-T010] game_world has ScaleChoicePanel UI")
	t.assert_true(world.has_node("UI/ShedskinDisplay"), "[L4-T010] game_world has ShedskinDisplay chip")
	if not wired:
		# 未接线时不开局：避免半途中断把 ticking/GameManager 状态泄漏给后续套件
		world.free()
		return
	t.add_child(world)
	world.start_game()
	GameManager.start_game()

	var run_system: Node = world.get_node("RunProgressionSystem")
	var room_flow: Node = world.get_node("RoomFlowSystem")
	var floor_panel: Control = world.get_node("UI/FloorProgressPanel")
	var scale_panel: Control = world.get_node("UI/ScaleChoicePanel")
	var reward_panel: Control = world.get_node("UI/RewardChoicePanel")
	var shedskin_chip: Control = world.get_node("UI/ShedskinDisplay")
	var shedskin: Node = world.get_node("ShedskinSystem")
	var path: Array = ConfigManager.get_floor_config().get("fixed_v1_path", [])

	t.assert_false(scale_panel.visible, "[L4-T010] scale panel hidden at run start")
	t.assert_false(shedskin_chip.visible, "[L4-T010] shedskin chip hidden before first income")

	# combat_01：清怪 → offer → 门控 → 放弃 → 蜕皮入账
	var required: int = int(room_flow.get_objective_progress().get("required", 1))
	room_flow.record_objective_progress(required, {"method": "l4_t010"})
	t.assert_true(scale_panel.visible, "[L4-T010] combat completion presents scale offer")
	t.assert_true(run_system.has_pending_offer(), "[L4-T010] run progression registers pending offer")
	t.assert_true(floor_panel.get_next_button().disabled, "[L4-T010] Next disabled while offer pending")
	t.assert_false(floor_panel.request_next_room(), "[L4-T010] advance refused while offer pending")
	t.assert_eq(run_system.get_state().get("current_room_id", ""), path[0],
		"[L4-T010] run stays in combat room while offer pending")

	var sd: int = int(ConfigManager.get_shedskin_config().get("scale_discard", 0))
	t.assert_true(scale_panel.discard_offer(), "[L4-T010] discard via panel public API")
	t.assert_eq(shedskin.get_amount(), 3 * sd, "[L4-T010] discard income lands in the run wallet")
	t.assert_true(shedskin_chip.visible, "[L4-T010] shedskin chip appears on first income")
	t.assert_eq(shedskin_chip.get_amount_text(), str(3 * sd), "[L4-T010] chip shows the balance")
	t.assert_false(scale_panel.visible, "[L4-T010] scale panel hides after discard")
	t.assert_false(run_system.has_pending_offer(), "[L4-T010] gate released after discard")

	# 奖励房：L3 流程不受影响（合成 room_completed 通路保留）
	t.assert_true(floor_panel.request_next_room(), "[L4-T010] Next enters reward room")
	t.assert_eq(run_system.get_state().get("current_room_id", ""), path[1], "[L4-T010] run reaches reward room")
	t.assert_true(reward_panel.visible, "[L4-T010] L3 reward panel still works")
	t.assert_true(reward_panel.choose_option_by_index(0), "[L4-T010] L3 reward choice applies")

	# combat_02：这次选择装备
	t.assert_true(floor_panel.request_next_room(), "[L4-T010] Next enters second combat room")
	room_flow.record_objective_progress(required, {"method": "l4_t010"})
	t.assert_true(scale_panel.visible, "[L4-T010] second combat presents scale offer")
	t.assert_true(scale_panel.choose_option_by_index(0), "[L4-T010] choose equips via world ScaleSlotManager")
	var scale_mgr: Node = world.get_node("ScaleSlotManager")
	t.assert_true(scale_mgr.get_all_scales().size() >= 1, "[L4-T010] chosen scale present in Build")
	t.assert_eq(shedskin.get_amount(), 5 * sd, "[L4-T010] choice discards the other two options (+2 each)")

	# 休整 → 终点：全链胜利（无合成 room_completed 干扰房间流程）
	t.assert_true(floor_panel.request_next_room(), "[L4-T010] Next enters rest room")
	t.assert_true(floor_panel.request_next_room(), "[L4-T010] Next enters endpoint room")
	t.assert_eq(run_system.get_state().get("outcome", ""), "victory",
		"[L4-T010] full chain reaches victory")

	world.cleanup()
	world.queue_free()
	GameManager.current_state = saved_state
	GameManager.current_score = saved_score
	GameManager.best_score = saved_best
	TickManager.stop_ticking()
	GridWorld.clear_all()
	# 冲掉本套件 queue_free 的世界：其 EnemyManager 在落地前仍连着 enemy_killed，
	# 会把后续套件的 mock payload 当 Enemy 节点收参（严格门禁扫描 SCRIPT ERROR）
	await t.get_tree().process_frame
	await t.get_tree().process_frame


# ── Helpers ──────────────────────────────────────────────────────────

func _make_real_slot_manager() -> Dictionary:
	var mock_snake := Node2D.new()
	mock_snake.name = "ScaleRewardMockSnake"
	var scale_mgr: Node = load(SCALE_SLOT_MANAGER_PATH).new()
	scale_mgr.init_manager(mock_snake, StatusEffectManager._trigger_manager, StatusEffectManager._chain_resolver)
	return {"snake": mock_snake, "scale_mgr": scale_mgr}


func _teardown_system(setup: Dictionary, system: Node) -> void:
	_disconnect_recorders()
	system.cleanup()
	system.queue_free()
	setup["scale_mgr"].clear_all()
	setup["scale_mgr"].free()
	setup["snake"].free()


func _connect_recorders() -> void:
	_presented_events.clear()
	_chosen_events.clear()
	_discarded_events.clear()
	_room_completed_events.clear()
	_reward_presented_events.clear()
	_reward_chosen_events.clear()
	if not EventBus.scale_reward_presented.is_connected(_on_presented):
		EventBus.scale_reward_presented.connect(_on_presented)
	if not EventBus.scale_reward_chosen.is_connected(_on_chosen):
		EventBus.scale_reward_chosen.connect(_on_chosen)
	if not EventBus.scale_option_discarded.is_connected(_on_discarded):
		EventBus.scale_option_discarded.connect(_on_discarded)
	if not EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.connect(_on_room_completed)
	if not EventBus.reward_presented.is_connected(_on_reward_presented):
		EventBus.reward_presented.connect(_on_reward_presented)
	if not EventBus.reward_chosen.is_connected(_on_reward_chosen):
		EventBus.reward_chosen.connect(_on_reward_chosen)


func _disconnect_recorders() -> void:
	if EventBus.scale_reward_presented.is_connected(_on_presented):
		EventBus.scale_reward_presented.disconnect(_on_presented)
	if EventBus.scale_reward_chosen.is_connected(_on_chosen):
		EventBus.scale_reward_chosen.disconnect(_on_chosen)
	if EventBus.scale_option_discarded.is_connected(_on_discarded):
		EventBus.scale_option_discarded.disconnect(_on_discarded)
	if EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.disconnect(_on_room_completed)
	if EventBus.reward_presented.is_connected(_on_reward_presented):
		EventBus.reward_presented.disconnect(_on_reward_presented)
	if EventBus.reward_chosen.is_connected(_on_reward_chosen):
		EventBus.reward_chosen.disconnect(_on_reward_chosen)


func _on_presented(data: Dictionary) -> void:
	_presented_events.append(data)


func _on_chosen(data: Dictionary) -> void:
	_chosen_events.append(data)


func _on_discarded(data: Dictionary) -> void:
	_discarded_events.append(data)


func _on_room_completed(data: Dictionary) -> void:
	_room_completed_events.append(data)


func _on_reward_presented(data: Dictionary) -> void:
	_reward_presented_events.append(data)


func _on_reward_chosen(data: Dictionary) -> void:
	_reward_chosen_events.append(data)
