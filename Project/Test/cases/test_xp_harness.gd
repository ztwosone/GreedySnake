extends RefCounted
## SpecKit 004 T008: 体验验收基建 —— 录制器/步进器/UI 执行器
## 设计文档: Designs/Interactive/presentation_design.md §11.4（仪表缝）/§12.1（机器层契约）
## 本套件只测 harness 本体（合成事件 + 最小场景）；真实 game_world 契约见 test_xp_contracts_l3。

const RECORDER_PATH: String = "res://Test/experience/experience_recorder.gd"
const DRIVER_PATH: String = "res://Test/experience/tick_driver.gd"
const ACTOR_PATH: String = "res://Test/experience/ui_actor.gd"


class FakeChoicePanel extends Control:
	## 最小可观察面板：getter + 公共选择 API（选择时发 reward_chosen 完成模态闭环）
	var chosen_indices: Array = []
	var status: String = "idle"

	func get_status_text() -> String:
		return status

	func choose_option_by_index(index: int) -> bool:
		if index < 0:
			return false
		chosen_indices.append(index)
		EventBus.reward_chosen.emit({"option_index": index})
		return true


class FakeBus extends RefCounted:
	## 自定义事件源：测 targets 注入 + 0 参信号 + *_discarded 后缀弹栈
	signal stone_presented(data: Dictionary)
	signal stone_discarded(data: Dictionary)
	signal banner_shown


func run(t) -> void:
	t.assert_file_exists(RECORDER_PATH)
	t.assert_file_exists(DRIVER_PATH)
	t.assert_file_exists(ACTOR_PATH)
	for path in [RECORDER_PATH, DRIVER_PATH, ACTOR_PATH]:
		if not FileAccess.file_exists(path):
			return

	_test_recorder_event_channel(t)
	_test_recorder_vfx_channel(t)
	_test_recorder_pending_modals(t)
	_test_recorder_targets_injection(t)
	_test_recorder_panel_observation(t)
	_test_recorder_slice(t)
	await _test_tick_driver(t)
	_test_ui_actor(t)


func _new_recorder() -> RefCounted:
	return load(RECORDER_PATH).new()


func _filter(entries: Array, channel: String, name_part: String) -> Array:
	var out: Array = []
	for entry in entries:
		if str(entry.get("channel", "")) == channel and str(entry.get("name", "")).find(name_part) >= 0:
			out.append(entry)
	return out


# ── 录制器: event 通道 + tick 戳 + 镜像断连 ──────────────────────────

func _test_recorder_event_channel(t) -> void:
	var recorder: RefCounted = _new_recorder()
	recorder.attach({})
	var saved_tick: int = TickManager.current_tick
	TickManager.current_tick = 7
	EventBus.room_completed.emit({"room_id": "harness_room"})
	TickManager.current_tick = saved_tick
	var hits: Array = _filter(recorder.entries(), "event", "room_completed")
	t.assert_eq(hits.size(), 1, "[XP-H] recorder captures EventBus signal once")
	if hits.size() == 1:
		t.assert_eq(int(hits[0].get("tick", -1)), 7, "[XP-H] entry stamped with TickManager.current_tick")
		var data: Dictionary = hits[0].get("data", {})
		t.assert_eq(str(data.get("room_id", "")), "harness_room", "[XP-H] entry carries signal payload")
	recorder.detach()
	EventBus.room_completed.emit({"room_id": "after_detach"})
	t.assert_eq(_filter(recorder.entries(), "event", "room_completed").size(), 1,
		"[XP-H] detach stops recording (mirror disconnect)")


# ── 录制器: vfx 通道（vfx_invoked 在有效性守卫前发射，headless 安全） ──

func _test_recorder_vfx_channel(t) -> void:
	var recorder: RefCounted = _new_recorder()
	recorder.attach({})
	VFXManager.screen_shake(1.5, 0.1)
	var hits: Array = _filter(recorder.entries(), "vfx", "screen_shake")
	t.assert_eq(hits.size(), 1, "[XP-H] vfx_invoked recorded on vfx channel")
	if hits.size() == 1:
		var args: Dictionary = hits[0].get("data", {})
		t.assert_eq(float(args.get("intensity", 0.0)), 1.5, "[XP-H] vfx entry carries final args")
	recorder.detach()


# ── 录制器: pending modal 压栈/弹栈 ──────────────────────────────────

func _test_recorder_pending_modals(t) -> void:
	var recorder: RefCounted = _new_recorder()
	recorder.attach({})
	t.assert_true(recorder.pending_modals().is_empty(), "[XP-H] no pending modals initially")
	EventBus.reward_presented.emit({"offer_id": "h1", "options": []})
	t.assert_eq(recorder.pending_modals().size(), 1, "[XP-H] *_presented pushes pending modal")
	EventBus.scale_reward_presented.emit({"options": []})
	t.assert_eq(recorder.pending_modals().size(), 2, "[XP-H] second *_presented stacks")
	EventBus.reward_chosen.emit({"option_id": "x"})
	var pending: Array = recorder.pending_modals()
	t.assert_eq(pending.size(), 1, "[XP-H] *_chosen pops matching prefix only")
	if pending.size() == 1:
		t.assert_eq(str(pending[0].get("name", "")), "scale_reward_presented",
			"[XP-H] unrelated pending modal survives the pop")
	EventBus.scale_reward_chosen.emit({"option_id": "y"})
	t.assert_true(recorder.pending_modals().is_empty(), "[XP-H] all modals resolved")
	recorder.detach()


# ── 录制器: targets 注入 + 0 参信号 + _discarded 弹栈 ────────────────

func _test_recorder_targets_injection(t) -> void:
	var bus := FakeBus.new()
	var recorder: RefCounted = _new_recorder()
	recorder.attach({"event_bus": bus})
	bus.banner_shown.emit()
	t.assert_eq(_filter(recorder.entries(), "event", "banner_shown").size(), 1,
		"[XP-H] zero-arg signal captured via injected event source")
	bus.stone_presented.emit({"stone": 1})
	t.assert_eq(recorder.pending_modals().size(), 1, "[XP-H] injected *_presented pushes modal")
	bus.stone_discarded.emit({})
	t.assert_true(recorder.pending_modals().is_empty(), "[XP-H] *_discarded pops pending modal")
	recorder.detach()
	bus.stone_presented.emit({"stone": 2})
	t.assert_eq(_filter(recorder.entries(), "event", "stone_presented").size(), 1,
		"[XP-H] detach mirrors injected connections")


# ── 录制器: 面板观察（getter+visible 差分 → ui 通道） ────────────────

func _test_recorder_panel_observation(t) -> void:
	var panel := FakeChoicePanel.new()
	panel.name = "FakeChoicePanel"
	t.add_child(panel)
	var recorder: RefCounted = _new_recorder()
	recorder.attach({})
	recorder.observe_panel(panel, ["get_status_text"])
	panel.status = "armed"
	EventBus.room_entered.emit({"room_id": "obs"})
	var ui_hits: Array = _filter(recorder.entries(), "ui", "FakeChoicePanel.get_status_text")
	t.assert_eq(ui_hits.size(), 1, "[XP-H] getter diff recorded on ui channel after event")
	if ui_hits.size() == 1:
		var diff: Dictionary = ui_hits[0].get("data", {})
		t.assert_eq(str(diff.get("from", "")), "idle", "[XP-H] ui diff carries previous value")
		t.assert_eq(str(diff.get("to", "")), "armed", "[XP-H] ui diff carries new value")
	panel.visible = false
	EventBus.room_completed.emit({"room_id": "obs"})
	t.assert_eq(_filter(recorder.entries(), "ui", "FakeChoicePanel.visible").size(), 1,
		"[XP-H] visibility change recorded on ui channel")
	EventBus.room_entered.emit({"room_id": "obs2"})
	t.assert_eq(_filter(recorder.entries(), "ui", "FakeChoicePanel").size(), 2,
		"[XP-H] unchanged snapshot adds no ui entries")
	recorder.detach()
	panel.queue_free()


# ── 录制器: slice 时间窗 ─────────────────────────────────────────────

func _test_recorder_slice(t) -> void:
	var recorder: RefCounted = _new_recorder()
	recorder.attach({})
	var saved_tick: int = TickManager.current_tick
	TickManager.current_tick = 3
	EventBus.room_entered.emit({"room_id": "early"})
	TickManager.current_tick = 9
	EventBus.room_completed.emit({"room_id": "late"})
	TickManager.current_tick = saved_tick
	var window: Array = recorder.slice(0, 5)
	t.assert_eq(window.size(), 1, "[XP-H] slice keeps in-window entries only")
	if window.size() == 1:
		t.assert_eq(str(window[0].get("name", "")), "room_entered", "[XP-H] slice keeps the tick-3 entry")
	recorder.detach()


# ── 步进器: 模态感知步进 + 失败旗标 ──────────────────────────────────

func _test_tick_driver(t) -> void:
	# 冲掉先前套件 queue_free 未落地的残留节点（全局 tick 会打到树上所有 Snake）
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	var recorder: RefCounted = _new_recorder()
	var driver: RefCounted = load(DRIVER_PATH).new()
	var actor: RefCounted = load(ACTOR_PATH).new()
	var panel := FakeChoicePanel.new()
	panel.name = "DriverFakePanel"
	t.add_child(panel)
	actor.playbook = [
		{"on": "reward_presented", "node": panel, "call": "choose_option_by_index", "args": [0]},
	]
	recorder.attach({})
	driver.begin()
	t.assert_true(TickManager.manual_mode, "[XP-H] begin enables manual_mode")
	t.assert_true(TickManager.is_ticking, "[XP-H] begin starts ticking")
	t.assert_eq(TickManager.current_tick, 0, "[XP-H] begin resets tick to 0")

	var advanced: int = await driver.play(3, recorder, actor)
	t.assert_eq(advanced, 3, "[XP-H] play advances requested ticks when no modal pending")
	t.assert_eq(TickManager.current_tick, 3, "[XP-H] TickManager stepped 3 ticks")
	t.assert_eq(_filter(recorder.entries(), "event", "tick_post_process").size(), 3,
		"[XP-H] tick events recorded during play")

	EventBus.reward_presented.emit({"offer_id": "drv", "options": []})
	advanced = await driver.play(2, recorder, actor)
	t.assert_eq(advanced, 2, "[XP-H] play resolves modal then keeps stepping")
	t.assert_eq(panel.chosen_indices, [0], "[XP-H] ui_actor called panel public API")
	t.assert_true(recorder.pending_modals().is_empty(), "[XP-H] modal resolved via reward_chosen")
	t.assert_eq(TickManager.current_tick, 5, "[XP-H] modal response does not consume ticks")
	t.assert_true(driver.get_failures().is_empty(), "[XP-H] no driver failures on happy path")

	EventBus.floor_reward_presented.emit({"options": []})
	advanced = await driver.play(1, recorder, actor)
	t.assert_eq(advanced, 0, "[XP-H] unresolvable modal blocks stepping")
	t.assert_true(driver.get_failures().size() >= 1,
		"[XP-H] unresolvable modal recorded as failure without crashing")

	driver.end()
	t.assert_false(TickManager.manual_mode, "[XP-H] end restores manual_mode=false")
	t.assert_false(TickManager.is_ticking, "[XP-H] end stops ticking")
	recorder.detach()
	panel.queue_free()


# ── 执行器: playbook 匹配（node 引用 / node_path / callable） ────────

func _test_ui_actor(t) -> void:
	var actor: RefCounted = load(ACTOR_PATH).new()
	var panel := FakeChoicePanel.new()
	panel.name = "ActorPathPanel"
	t.add_child(panel)
	actor.root = t
	var callable_hits: Array = []
	actor.playbook = [
		{"on": "reward_presented", "node": panel, "call": "choose_option_by_index", "args": [1]},
		{"on": "scale_reward_presented", "node_path": "ActorPathPanel", "call": "choose_option_by_index", "args": [2]},
		{"on": "floor_reward_presented", "call": "callable", "fn": func() -> void: callable_hits.append(true)},
	]
	t.assert_true(actor.respond([{"name": "reward_presented", "prefix": "reward"}]),
		"[XP-H] actor resolves node-ref playbook entry")
	t.assert_true(actor.respond([{"name": "scale_reward_presented", "prefix": "scale_reward"}]),
		"[XP-H] actor resolves node_path playbook entry via root")
	t.assert_eq(panel.chosen_indices, [1, 2], "[XP-H] actor called panel API with playbook args")
	t.assert_true(actor.respond([{"name": "floor_reward_presented", "prefix": "floor_reward"}]),
		"[XP-H] actor supports callable playbook entries")
	t.assert_eq(callable_hits.size(), 1, "[XP-H] callable entry invoked exactly once")
	t.assert_false(actor.respond([{"name": "unknown_presented", "prefix": "unknown"}]),
		"[XP-H] unmatched pending returns false")
	actor.playbook = [{"on": "reward_presented", "node": panel, "call": "choose_option_by_index", "args": [-1]}]
	t.assert_false(actor.respond([{"name": "reward_presented", "prefix": "reward"}]),
		"[XP-H] panel API returning false propagates as failure")
	panel.queue_free()
