extends RefCounted
## SpecKit 004 T010: L3 首批体验契约（设计文档 presentation_design.md §12.1 机器层）
## 真实 game_world + 录制器/步进器/执行器：
##   (a) 模态唯一（max_pending_modals）
##   (b) reward_presented 在 feedback_window_ticks 内产生 RewardChoicePanel 的 ui 变化
##   (c) 首个 *_presented 在 time_to_first_choice_max_ticks 内
## 推进方式与 test_l3_smoke_run 同源（面板驱动），仅多了真实 tick 步进；
## 清理纪律镜像既有 full-run 套件（cleanup + queue_free + GridWorld.clear_all）。

const RECORDER_PATH: String = "res://Test/experience/experience_recorder.gd"
const DRIVER_PATH: String = "res://Test/experience/tick_driver.gd"
const ACTOR_PATH: String = "res://Test/experience/ui_actor.gd"
const STAGER_PATH: String = "res://Test/experience/state_stager.gd"


func run(t) -> void:
	t.assert_file_exists(RECORDER_PATH)
	t.assert_file_exists(DRIVER_PATH)
	t.assert_file_exists(ACTOR_PATH)
	t.assert_file_exists(STAGER_PATH)
	for path in [RECORDER_PATH, DRIVER_PATH, ACTOR_PATH, STAGER_PATH]:
		if not FileAccess.file_exists(path):
			return
	await _test_l3_first_contracts(t)


func _test_l3_first_contracts(t) -> void:
	var acceptance: Dictionary = ConfigManager.get_acceptance_config()
	var feedback_window: int = int(acceptance.get("feedback_window_ticks", 0))
	var max_modals: int = int(acceptance.get("max_pending_modals", 0))
	var first_choice_max: int = int(acceptance.get("time_to_first_choice_max_ticks", 0))
	t.assert_true(max_modals >= 1 and first_choice_max >= 1,
		"[XP-L3] acceptance thresholds present in JSON")

	var stager_script: GDScript = load(STAGER_PATH)
	var ctx: Dictionary = stager_script.stage("l3_run_start", t)
	var world: Node = ctx.get("world", null)
	t.assert_true(world != null, "[XP-L3] stager boots real game_world run")
	if world == null:
		return

	# 冲掉先前套件 queue_free 未落地的残留世界：tick 信号是全局的，
	# 残留 Snake（含 no-body 空身躯）会在手动步进时收到 tick 并报错
	await t.get_tree().process_frame
	await t.get_tree().process_frame

	var run_system: Node = world.get_node("RunProgressionSystem")
	var room_flow: Node = world.get_node("RoomFlowSystem")
	var floor_panel: Control = world.get_node("UI/FloorProgressPanel")
	var reward_panel: Control = world.get_node("UI/RewardChoicePanel")
	var scale_panel: Control = world.get_node("UI/ScaleChoicePanel")
	var combat_required: int = int(room_flow.get_objective_progress().get("required", 1))

	# 录制器后于面板接线（面板先收到事件 → 同一事件即可观测到 ui 差分）
	var recorder: RefCounted = load(RECORDER_PATH).new()
	recorder.attach({})
	recorder.observe_panel(reward_panel, ["get_visible_option_count", "get_status_text"])

	var actor: RefCounted = load(ACTOR_PATH).new()
	actor.root = world
	actor.playbook = [
		{"on": "reward_presented", "node": reward_panel, "call": "choose_option_by_index", "args": [0]},
		{"on": "scale_reward_presented", "node": scale_panel, "call": "discard_offer", "args": []},
	]

	var driver: RefCounted = load(DRIVER_PATH).new()
	driver.begin()

	# combat_01: 真实步进若干拍 → 完成目标 → 鳞片模态（spec 002 T010）→ 决议 → 进奖励房
	await driver.play(2, recorder, actor)
	room_flow.record_objective_progress(combat_required, {"method": "xp_contracts"})
	t.assert_true(recorder.pending_modals().size() >= 1,
		"[XP-L4] combat completion pushes a scale modal")
	await driver.play(1, recorder, actor)
	t.assert_true(recorder.pending_modals().is_empty(),
		"[XP-L4] ui_actor resolved the scale modal via panel public API")
	t.assert_true(floor_panel.request_next_room(), "[XP-L3] advance to reward room")
	t.assert_true(recorder.pending_modals().size() >= 1,
		"[XP-L3] reward_presented pushes a pending modal")
	await driver.play(2, recorder, actor)
	t.assert_true(recorder.pending_modals().is_empty(),
		"[XP-L3] ui_actor resolved the reward modal via panel public API")

	# combat_02 → shop → rest → endpoint（与 smoke 同路径，鳞片模态由 actor 决议；
	# 商店 shop_entered 非 *_presented，不入 pending modal 栈——spec 002 T016）
	t.assert_true(floor_panel.request_next_room(), "[XP-L3] advance to second combat room")
	await driver.play(2, recorder, actor)
	room_flow.record_objective_progress(combat_required, {"method": "xp_contracts"})
	await driver.play(1, recorder, actor)
	t.assert_true(floor_panel.request_next_room(), "[XP-L3] advance to shop room")
	await driver.play(1, recorder, actor)
	t.assert_true(recorder.pending_modals().is_empty(),
		"[XP-L4] shop is not a blocking modal (no pending entry)")
	t.assert_true(floor_panel.request_next_room(), "[XP-L3] advance to rest room")
	await driver.play(1, recorder, actor)
	t.assert_true(floor_panel.request_next_room(), "[XP-L3] advance to endpoint room")
	t.assert_eq(run_system.get_state().get("outcome", ""), "victory", "[XP-L3] run ends in victory")

	driver.end()
	t.assert_true(driver.get_failures().is_empty(),
		"[XP-L3] tick driver finished without failures: %s" % str(driver.get_failures()))

	var events: Array = recorder.entries()

	# (a) 模态唯一：全程并发 *_presented 不得超过 max_pending_modals
	var max_concurrent: int = _max_concurrent_modals(events)
	t.assert_true(max_concurrent >= 1, "[XP-L3] at least one choice ceremony happened")
	t.assert_true(max_concurrent <= max_modals,
		"[XP-L3] pending modals never exceed %d (max seen %d)" % [max_modals, max_concurrent])

	# (b) reward_presented → RewardChoicePanel ui 变化在 feedback_window_ticks 内
	var presented_tick: int = -1
	for entry in events:
		if str(entry.get("channel", "")) == "event" and str(entry.get("name", "")) == "reward_presented":
			presented_tick = int(entry.get("tick", -1))
			break
	t.assert_true(presented_tick >= 0, "[XP-L3] reward_presented recorded")
	var ui_change_found: bool = false
	for entry in events:
		if str(entry.get("channel", "")) != "ui":
			continue
		if not str(entry.get("name", "")).begins_with("RewardChoicePanel."):
			continue
		var tick: int = int(entry.get("tick", -1))
		if tick >= presented_tick and tick <= presented_tick + feedback_window:
			ui_change_found = true
			break
	t.assert_true(ui_change_found,
		"[XP-L3] RewardChoicePanel changed within %d tick(s) of reward_presented" % feedback_window)

	# (c) time-to-first-choice：首个 *_presented 的 tick 戳在阈值内
	var first_presented_tick: int = -1
	for entry in events:
		if str(entry.get("channel", "")) == "event" and str(entry.get("name", "")).ends_with("_presented"):
			first_presented_tick = int(entry.get("tick", -1))
			break
	t.assert_true(first_presented_tick >= 0, "[XP-L3] a *_presented event was recorded")
	t.assert_true(first_presented_tick <= first_choice_max,
		"[XP-L3] first choice within %d ticks (was tick %d)" % [first_choice_max, first_presented_tick])

	recorder.detach()
	stager_script.teardown(ctx)
	t.assert_false(TickManager.is_ticking, "[XP-L3] teardown leaves ticking stopped")


func _max_concurrent_modals(events: Array) -> int:
	var depth: int = 0
	var max_depth: int = 0
	for entry in events:
		if str(entry.get("channel", "")) != "event":
			continue
		var event_name: String = str(entry.get("name", ""))
		if event_name.ends_with("_presented"):
			depth += 1
			max_depth = maxi(max_depth, depth)
		elif event_name.ends_with("_chosen") or event_name.ends_with("_discarded") \
				or event_name.ends_with("_skipped"):
			depth = maxi(0, depth - 1)
	return max_depth
