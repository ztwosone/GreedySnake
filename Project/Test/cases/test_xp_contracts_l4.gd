extends RefCounted
## spec 002 T034: L4 VirtualPlayer 冒烟 + 新模态体验契约（presentation_design.md §12.1 机器层）
## 真实 game_world（pcg 档，种子 9090）两段式驱动：
##   Phase 1 —— CompositeBrain（food_seeker+survival，确定性种子）经 tick_pre_process
##   注入方向，真实步进穿过首个战斗房（目标余量由 record_objective_progress 补足，
##   与 test_xp_contracts_l3 同源的推进模式）；
##   Phase 2 —— 面板公共 API 驱动完成 3 层 run 至胜利（T028 模式），不再步进 tick。
## 防死锁断言（FR-014/FR-015 体验侧）：任一 pending 模态若无人能决议（playbook 不命中 /
## 面板 API 返回 false / 行动预算耗尽）即 FAIL——绝不静默挂起。
## L4 新模态契约表（experience_recorder 期望，test_xp_contracts_l3 风格延伸）：
##   - scale_reward_presented → ScaleChoicePanel 在 feedback_window_ticks 内有 ui 变化；
##     决议事件 = scale_reward_chosen | scale_option_discarded（presented/决议恰好配对）；
##   - floor_reward_presented 两段（step: slot_unlock → choice）= 同一 offer 家族的
##     步骤推进，pending 栈按前缀原地更新不叠层（镜像 RunProgression 家族登记语义）；
##     FloorRewardPanel 在 feedback_window_ticks 内有 ui 变化；
##   - shop_entered 非 *_presented：不入 pending 模态栈（商店不门控，T014 裁定）；
##   - 全程并发 pending 家族数 ≤ acceptance.max_pending_modals（模态唯一）。

const GAME_WORLD_SCENE_PATH: String = "res://scenes/game_world.tscn"
const RECORDER_PATH: String = "res://Test/experience/experience_recorder.gd"
const DRIVER_PATH: String = "res://Test/experience/tick_driver.gd"
const ACTOR_PATH: String = "res://Test/experience/ui_actor.gd"
const VIRTUAL_PLAYER_PATH: String = "res://Test/virtual_player/virtual_player.gd"
const COMPOSITE_BRAIN_PATH: String = "res://Test/virtual_player/brains/composite_brain.gd"

const RUN_SEED: int = 9090
const BRAIN_SEED: int = 4242
## Phase 1 真实步进预算：足够让大脑展示移动/觅食/避险，又不至于把套件拖慢
const PHASE1_MAX_TICKS: int = 48
const PHASE1_CHUNK_TICKS: int = 8
## Phase 2 行动预算：3 层 PCG（每层 ≤ 10 房 + 模态决议 + 冲帧）远低于此上界
const PHASE2_ACTION_BUDGET: int = 384


func run(t) -> void:
	await _test_l4_virtual_player_smoke(t)


func _test_l4_virtual_player_smoke(t) -> void:
	var saved_state: int = GameManager.current_state
	var saved_score: int = GameManager.current_score
	var saved_best: int = GameManager.best_score
	var previous_generator: String = str(ConfigManager.floor.get("generator", "fixed_v1"))
	var previous_seed: int = int(ConfigManager.floor.get("default_seed", 0))
	ConfigManager.floor["generator"] = "pcg"
	ConfigManager.floor["default_seed"] = RUN_SEED

	var acceptance: Dictionary = ConfigManager.get_acceptance_config()
	var feedback_window: int = int(acceptance.get("feedback_window_ticks", 1))
	var max_modals: int = int(acceptance.get("max_pending_modals", 1))

	var scene = load(GAME_WORLD_SCENE_PATH) as PackedScene
	var world: Node = scene.instantiate()
	t.add_child(world)
	world.start_game()
	GameManager.start_game()

	# 冲掉先前套件 queue_free 未落地的残留世界（tick 信号全局，残留蛇会报错）
	await t.get_tree().process_frame
	await t.get_tree().process_frame

	var run_system: Node = world.get_node("RunProgressionSystem")
	var room_flow: Node = world.get_node("RoomFlowSystem")
	var snake: Node = world.get_node("EntityContainer/Snake")
	var floor_panel: Control = world.get_node("UI/FloorProgressPanel")
	var reward_panel: Control = world.get_node("UI/RewardChoicePanel")
	var scale_panel: Control = world.get_node("UI/ScaleChoicePanel")
	var floor_reward_panel: Control = world.get_node("UI/FloorRewardPanel")

	# ── VirtualPlayer：CompositeBrain（确定性种子）→ tick_pre_process 注入 ──
	var vp: Node = load(VIRTUAL_PLAYER_PATH).new()
	vp.name = "XpL4VirtualPlayer"
	vp.timing.set_deterministic(BRAIN_SEED)
	var brain: RefCounted = load(COMPOSITE_BRAIN_PATH).new()
	brain.set_seed(BRAIN_SEED)
	vp.brain = brain
	vp.snake = snake
	world.add_child(vp)

	# ── 录制器（面板先接线，后挂录制器 → 同一事件可观测 ui 差分）──
	var recorder: RefCounted = load(RECORDER_PATH).new()
	recorder.attach({})
	recorder.observe_panel(scale_panel, ["get_visible_option_count", "get_status_text"])
	recorder.observe_panel(floor_reward_panel, ["get_step", "get_visible_option_count", "get_status_text"])

	# ── 执行器 playbook：三类 L4 模态各有响应（floor_reward 两段按面板 step 分派）──
	var actor: RefCounted = load(ACTOR_PATH).new()
	actor.root = world
	actor.playbook = [
		{"on": "reward_presented", "node": reward_panel, "call": "choose_option_by_index", "args": [0]},
		{"on": "scale_reward_presented", "node": scale_panel, "call": "discard_offer", "args": []},
		{"on": "floor_reward_presented", "call": "callable",
			"fn": _make_floor_reward_responder(floor_reward_panel), "args": []},
	]

	var driver: RefCounted = load(DRIVER_PATH).new()
	driver.begin()

	# ════ Phase 1：CompositeBrain 真实步进穿过首个战斗房 ════
	var first_room: Dictionary = room_flow.get_current_room()
	t.assert_eq(str(first_room.get("room_type", "")), "combat",
		"[XP-L4] pcg floor 1 starts in a combat room (structure guarantee)")
	var head_before: Vector2i = snake.body[0]
	var tick_before: int = TickManager.current_tick

	var ticks_played: int = 0
	while ticks_played < PHASE1_MAX_TICKS:
		if room_flow.is_current_room_complete() or not snake.is_alive:
			break
		ticks_played += await driver.play(PHASE1_CHUNK_TICKS, recorder, actor)
		if driver.has_failures():
			break

	t.assert_true(snake.is_alive, "[XP-L4] snake survives the brain-driven combat segment")
	t.assert_true(ticks_played >= PHASE1_CHUNK_TICKS,
		"[XP-L4] real ticks actually advanced (%d played)" % ticks_played)
	t.assert_true(TickManager.current_tick > tick_before,
		"[XP-L4] TickManager tick advanced during the driven segment")
	t.assert_true(snake.body[0] != head_before,
		"[XP-L4] CompositeBrain moved the snake (head position changed)")

	# 目标余量补足（与 xp_contracts_l3 同源）：大脑负责移动体验，目标推进确定性收口
	if not room_flow.is_current_room_complete():
		var progress: Dictionary = room_flow.get_objective_progress()
		var remaining: int = int(progress.get("required", 1)) - int(progress.get("current", 0))
		room_flow.record_objective_progress(remaining, {"method": "xp_l4_topup"})
	t.assert_true(recorder.pending_modals().size() >= 1,
		"[XP-L4] first combat completion pushes the scale modal")
	await driver.play(1, recorder, actor)
	t.assert_true(recorder.pending_modals().is_empty(),
		"[XP-L4] ui_actor resolved the scale modal via panel public API")

	# Phase 2 起停止注入：面板驱动阶段不再步进 tick，大脑保持静默
	vp.enabled = false

	# ════ Phase 2：面板公共 API 驱动完成 3 层 run（防死锁断言内联）════
	var gating_checked: bool = false
	var deadlock: String = ""
	for _step in range(PHASE2_ACTION_BUDGET):
		if not run_system.is_running():
			break
		var pending: Array = recorder.pending_modals()
		if not pending.is_empty():
			if str(pending[0].get("name", "")) == "floor_reward_presented" and not gating_checked:
				gating_checked = true
				t.assert_true(floor_panel.is_advance_blocked(),
					"[XP-L4] advance UI disabled while the settlement is pending (FR-015)")
				t.assert_false(floor_panel.request_next_room(),
					"[XP-L4] advance request ignored while the settlement is pending")
			var resolved: bool = await actor.respond(pending)
			if not resolved:
				deadlock = "unanswered modal(s): %s (%s)" % [str(pending), actor.last_error]
				break
			await t.get_tree().process_frame
			continue
		if not room_flow.is_current_room_complete():
			var objective: Dictionary = room_flow.get_current_room().get("objective", {})
			if str(objective.get("objective_type", "")) == "clear_enemies":
				room_flow.record_objective_progress(int(objective.get("required_count", 1)), {"method": "xp_l4_driver"})
			continue
		# 房间已完成：可能有延迟切层在飞，先冲帧再推进
		await t.get_tree().process_frame
		if not run_system.is_running() or not recorder.pending_modals().is_empty():
			continue
		floor_panel.request_next_room()
	if not run_system.is_running() and run_system.get_state().get("outcome", "") == "running":
		deadlock = "action budget exhausted before the run ended"

	t.assert_eq(deadlock, "", "[XP-L4] deadlock guard: every modal was answered (%s)" % deadlock)
	t.assert_true(gating_checked, "[XP-L4] the run actually hit a boss settlement")
	t.assert_eq(run_system.get_state().get("outcome", ""), "victory",
		"[XP-L4] brain + panel driven 3-floor pcg run ends in victory")
	t.assert_true(recorder.pending_modals().is_empty(),
		"[XP-L4] no dangling pending modal after victory (deadlock guard)")

	driver.end()
	t.assert_true(driver.get_failures().is_empty(),
		"[XP-L4] tick driver finished without failures: %s" % str(driver.get_failures()))

	# ════ L4 新模态契约表（recorder 时间线断言）════
	var events: Array = recorder.entries()

	# (a) 模态唯一：并发 pending 家族数 ≤ max_pending_modals（两段结算同家族不叠层）
	var max_concurrent: int = _max_concurrent_modal_families(events)
	t.assert_true(max_concurrent >= 1, "[XP-L4] at least one modal ceremony happened")
	t.assert_true(max_concurrent <= max_modals,
		"[XP-L4] pending modal families never exceed %d (max seen %d)" % [max_modals, max_concurrent])

	# (b) scale_reward_presented / 决议恰好配对（chosen 或 option_discarded）
	var scale_presented: int = _count_events(events, "scale_reward_presented")
	var scale_resolved: int = _count_events(events, "scale_reward_chosen") \
		+ _count_events(events, "scale_option_discarded")
	t.assert_true(scale_presented >= 3,
		"[XP-L4] every combat completion presented a scale offer (%d seen)" % scale_presented)
	t.assert_eq(scale_resolved, scale_presented,
		"[XP-L4] every scale offer resolved exactly once (presented/resolution paired)")

	# (c) floor_reward 两段：step 序列 slot_unlock → choice（每个非终层 Boss 一组），
	#     每组恰一次 floor_reward_chosen
	var settlement_steps: Array = []
	var settlement_floors: Array = []
	for entry in events:
		if str(entry.get("channel", "")) == "event" and str(entry.get("name", "")) == "floor_reward_presented":
			settlement_steps.append(str(entry.get("data", {}).get("step", "")))
			settlement_floors.append(int(entry.get("data", {}).get("floor_index", 0)))
	t.assert_eq(settlement_steps, ["slot_unlock", "choice", "slot_unlock", "choice"],
		"[XP-L4] each non-final boss runs the two-step settlement in order")
	t.assert_eq(settlement_floors, [1, 1, 2, 2],
		"[XP-L4] final floor presents no settlement (US5 场景 4)")
	t.assert_eq(_count_events(events, "floor_reward_chosen"), 2,
		"[XP-L4] each settlement resolved exactly once")

	# (d) 新模态反馈窗口：presented 后 feedback_window_ticks 内对应面板有 ui 变化
	_assert_panel_feedback(t, events, "scale_reward_presented", "ScaleChoicePanel.", feedback_window)
	_assert_panel_feedback(t, events, "floor_reward_presented", "FloorRewardPanel.", feedback_window)

	# (e) 商店非模态：shop_entered 发生过，且其时刻 pending 家族为空（不门控）
	t.assert_true(_count_events(events, "shop_entered") >= 1,
		"[XP-L4] the run visited at least one shop (per-floor guarantee)")
	t.assert_true(_shop_never_pending(events),
		"[XP-L4] shop_entered never coincides with a pending modal family (shop is not a modal)")

	# ── 清理（镜像 T028 纪律）──
	recorder.detach()
	world.cleanup()
	world.queue_free()
	GameManager.current_state = saved_state
	GameManager.current_score = saved_score
	GameManager.best_score = saved_best
	TickManager.stop_ticking()
	GridWorld.clear_all()
	ConfigManager.floor["generator"] = previous_generator
	ConfigManager.floor["default_seed"] = previous_seed
	await t.get_tree().process_frame
	await t.get_tree().process_frame


## floor_reward 两段响应器：按面板当前 step 分派（slot_unlock → 选位 0；choice → 选项 0）
func _make_floor_reward_responder(panel: Control) -> Callable:
	return func() -> bool:
		if not is_instance_valid(panel):
			return false
		if panel.get_step() == "slot_unlock":
			return panel.choose_slot_by_index(0)
		return panel.choose_option_by_index(0)


# ── 时间线断言助手 ───────────────────────────────────────────────────

func _count_events(events: Array, event_name: String) -> int:
	var count: int = 0
	for entry in events:
		if str(entry.get("channel", "")) == "event" and str(entry.get("name", "")) == event_name:
			count += 1
	return count


## 家族级并发模态计数：presented 登记前缀家族（同前缀重呈现 = 步骤推进，不叠层），
## chosen/discarded/skipped 按前缀（精确 → 首 token 回退）注销——与 recorder pending 语义一致
func _max_concurrent_modal_families(events: Array) -> int:
	var families: Dictionary = {}
	var max_depth: int = 0
	for entry in events:
		if str(entry.get("channel", "")) != "event":
			continue
		var event_name: String = str(entry.get("name", ""))
		if event_name.ends_with("_presented"):
			families[event_name.trim_suffix("_presented")] = true
			max_depth = maxi(max_depth, families.size())
			continue
		for suffix in ["_chosen", "_discarded", "_skipped"]:
			if event_name.ends_with(suffix):
				var prefix: String = event_name.trim_suffix(suffix)
				if families.has(prefix):
					families.erase(prefix)
				else:
					var pop_head: String = prefix.get_slice("_", 0)
					for family in families.keys():
						if str(family).get_slice("_", 0) == pop_head:
							families.erase(family)
							break
				break
	return max_depth


## presented → 对应面板 getter/visible 差分在窗口内出现（每次 presented 都验，逐条断言收敛为一条）
func _assert_panel_feedback(t, events: Array, presented_name: String, panel_prefix: String, window: int) -> void:
	var presented_ticks: Array = []
	for entry in events:
		if str(entry.get("channel", "")) == "event" and str(entry.get("name", "")) == presented_name:
			presented_ticks.append(int(entry.get("tick", -1)))
	t.assert_true(not presented_ticks.is_empty(),
		"[XP-L4] %s recorded at least once" % presented_name)
	var all_fed_back: bool = true
	for presented_tick in presented_ticks:
		var found: bool = false
		for entry in events:
			if str(entry.get("channel", "")) != "ui":
				continue
			if not str(entry.get("name", "")).begins_with(panel_prefix):
				continue
			var tick: int = int(entry.get("tick", -1))
			if tick >= presented_tick and tick <= presented_tick + window:
				found = true
				break
		if not found:
			all_fed_back = false
			break
	t.assert_true(all_fed_back,
		"[XP-L4] %s produced a %s ui change within %d tick(s) every time" % [presented_name, panel_prefix, window])


## shop_entered 时刻不得有任何 pending 模态家族（商店非门控模态，T014 裁定）
func _shop_never_pending(events: Array) -> bool:
	var families: Dictionary = {}
	for entry in events:
		if str(entry.get("channel", "")) != "event":
			continue
		var event_name: String = str(entry.get("name", ""))
		if event_name == "shop_entered" and not families.is_empty():
			return false
		if event_name.ends_with("_presented"):
			families[event_name.trim_suffix("_presented")] = true
			continue
		for suffix in ["_chosen", "_discarded", "_skipped"]:
			if event_name.ends_with(suffix):
				var prefix: String = event_name.trim_suffix(suffix)
				if families.has(prefix):
					families.erase(prefix)
				else:
					var pop_head: String = prefix.get_slice("_", 0)
					for family in families.keys():
						if str(family).get_slice("_", 0) == pop_head:
							families.erase(family)
							break
				break
	return true
