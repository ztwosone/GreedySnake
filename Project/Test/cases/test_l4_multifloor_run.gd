extends RefCounted
## L4 US4 多层冒烟（spec 002 T028，2026-06-11 修订版 spec 对照）：
## 3 层 PCG run 至胜利，全程面板公共 API 驱动（test_l3_smoke_run 模式扩展）——
## 战斗房 record progress → 鳞片 offer 放弃 → L3 奖励选取 → 商店径直通过 →
## Boss 结算（槽位定位选择 + 3 选 1，floor_reward_panel 公共 API）→ 延迟切层。
## 断言：floor_generated×3 且楼层主题/布局各异（SC-005）；楼层奖励未决时推进被阻
## （FR-015，决议先于 floor_generated——US5 场景 5）；Boss 槽位解锁真生效（US3）；
## 终层无楼层奖励直达胜利（US5 场景 4）；game_over cause=victory。
## 种子 9090（floor.default_seed 测试内覆写）：三层主题 ruins/marsh/cave 各异、
## 房型序列各异——pcg 为种子确定性（SC-011），断言锁定该种子的性质而非具体房序。

const GAME_WORLD_SCENE_PATH: String = "res://scenes/game_world.tscn"
const RUN_SEED: int = 9090

var _floor_maps: Array = []
var _reward_presented: Array = []
var _slot_unlocked: Array = []
var _victory_events: Array = []
var _game_over_events: Array = []


func run(t) -> void:
	await _test_three_floor_pcg_run_to_victory(t)


func _test_three_floor_pcg_run_to_victory(t) -> void:
	var saved_state: int = GameManager.current_state
	var saved_score: int = GameManager.current_score
	var saved_best: int = GameManager.best_score
	var previous_generator: String = str(ConfigManager.floor.get("generator", "fixed_v1"))
	var previous_seed: int = int(ConfigManager.floor.get("default_seed", 0))
	ConfigManager.floor["generator"] = "pcg"
	ConfigManager.floor["default_seed"] = RUN_SEED

	_connect_recorders()
	var scene = load(GAME_WORLD_SCENE_PATH) as PackedScene
	var world: Node = scene.instantiate()
	t.add_child(world)
	world.start_game()
	GameManager.start_game()

	var run_system: Node = world.get_node("RunProgressionSystem")
	var room_flow: Node = world.get_node("RoomFlowSystem")
	var reward_flow: Node = world.get_node("RewardFlowSystem")
	var scale_system: Node = world.get_node("ScaleRewardSystem")
	var floor_reward_system: Node = world.get_node("FloorRewardSystem")
	var slot_expansion: Node = world.get_node("SlotExpansionSystem")
	var floor_panel: Node = world.get_node("UI/FloorProgressPanel")
	var reward_panel: Node = world.get_node("UI/RewardChoicePanel")
	var scale_panel: Node = world.get_node("UI/ScaleChoicePanel")
	var floor_reward_panel: Node = world.get_node("UI/FloorRewardPanel")

	t.assert_eq(int(run_system.get_state().get("floor_index", 0)), 1, "[T028] pcg run starts on floor 1")
	t.assert_eq(slot_expansion.get_total_slots(), 3, "[T028] run starts with 3 slots")

	var gating_checked: bool = false
	for _step in range(256):
		if not run_system.is_running():
			break
		if scale_system.has_pending_offer():
			t.assert_true(scale_panel.discard_offer(), "[T028] scale offers resolved via panel API")
			continue
		if reward_flow.has_pending_offer():
			t.assert_true(reward_panel.choose_option_by_index(0), "[T028] L3 rewards resolved via panel API")
			continue
		if floor_reward_system.has_pending_offer():
			if not gating_checked:
				gating_checked = true
				t.assert_false(floor_panel.request_next_room(),
					"[T028] advance blocked while the settlement is pending (FR-015)")
				t.assert_eq(int(run_system.get_state().get("floor_index", 0)), 1,
					"[T028] floor does not advance until the reward resolves (US5 场景 5)")
			if floor_reward_panel.get_step() == "slot_unlock":
				t.assert_true(floor_reward_panel.choose_slot_by_index(0),
					"[T028] slot-unlock step resolved via panel API")
			else:
				t.assert_true(floor_reward_panel.choose_option_by_index(0),
					"[T028] floor reward resolved via panel API")
			continue
		if not room_flow.is_current_room_complete():
			var objective: Dictionary = room_flow.get_current_room().get("objective", {})
			if str(objective.get("objective_type", "")) == "clear_enemies":
				room_flow.record_objective_progress(int(objective.get("required_count", 1)), {"method": "t028_driver"})
			continue
		# 房间已完成：可能有延迟切层在飞，先冲帧再推进
		await t.get_tree().process_frame
		if not run_system.is_running() or floor_reward_system.has_pending_offer():
			continue
		floor_panel.request_next_room()

	t.assert_true(gating_checked, "[T028] the run actually hit a boss settlement")
	t.assert_eq(run_system.get_state().get("outcome", ""), "victory", "[T028] 3-floor pcg run ends in victory")
	t.assert_eq(_victory_events.size(), 1, "[T028] run_victory emitted once")
	t.assert_eq(_game_over_events.size(), 1, "[T028] GameManager emits one game_over")
	if _game_over_events.size() > 0:
		t.assert_eq(str(_game_over_events[0].get("cause", "")), "victory", "[T028] game over cause is victory")

	# SC-005：3 层、主题/布局各异
	t.assert_eq(_floor_maps.size(), 3, "[T028] floor_generated emitted exactly 3 times")
	var floor_indexes: Array = []
	var themes: Array = []
	var distinct_themes: Dictionary = {}
	var type_signatures: Dictionary = {}
	for map in _floor_maps:
		floor_indexes.append(int(map.get("floor_index", 0)))
		var theme: String = str(map.get("theme_id", ""))
		themes.append(theme)
		distinct_themes[theme] = true
		t.assert_true(ConfigManager.get_floor_theme_ids().has(theme),
			"[T028] each floor carries a valid theme (%s)" % theme)
		var signature: Array = []
		for room in map.get("rooms", []):
			signature.append(str(room.get("room_type", "")))
		type_signatures[str(signature)] = true
	t.assert_eq(floor_indexes, [1, 2, 3], "[T028] floors generated in order 1 -> 2 -> 3")
	t.assert_eq(distinct_themes.size(), 3, "[T028] themes distinct across floors (seed %d: %s)" % [RUN_SEED, str(themes)])
	t.assert_eq(type_signatures.size(), 3, "[T028] room layouts (type sequences) distinct across floors")

	# US3/US5：非终层 Boss 各一次两段结算（slot_unlock → choice），终层无楼层奖励
	var steps: Array = []
	var reward_floors: Array = []
	for presented in _reward_presented:
		steps.append(str(presented.get("step", "")))
		reward_floors.append(int(presented.get("floor_index", 0)))
	t.assert_eq(steps, ["slot_unlock", "choice", "slot_unlock", "choice"],
		"[T028] each non-final boss runs the two-step settlement in order")
	t.assert_eq(reward_floors, [1, 1, 2, 2],
		"[T028] FINAL floor presents no floor reward (US5 场景 4)")
	t.assert_eq(_slot_unlocked.size(), 2, "[T028] two boss slot unlocks across the run")
	for unlocked in _slot_unlocked:
		t.assert_eq(str(unlocked.get("source", "")), "boss", "[T028] unlock source tagged boss")
	t.assert_eq(slot_expansion.get_total_slots(), 5, "[T028] boss slot unlocks REALLY opened slots (3 + 2)")
	t.assert_false(floor_reward_system.has_pending_offer(), "[T028] no dangling settlement after victory")

	world.cleanup()
	world.queue_free()
	_disconnect_recorders()
	GameManager.current_state = saved_state
	GameManager.current_score = saved_score
	GameManager.best_score = saved_best
	TickManager.stop_ticking()
	GridWorld.clear_all()
	ConfigManager.floor["generator"] = previous_generator
	ConfigManager.floor["default_seed"] = previous_seed
	# 冲掉 queue_free 的世界：EnemyManager 在落地前仍连着 enemy_killed（严格扫描防护）
	await t.get_tree().process_frame
	await t.get_tree().process_frame


# ── Recorders ────────────────────────────────────────────────────────

func _connect_recorders() -> void:
	_floor_maps.clear()
	_reward_presented.clear()
	_slot_unlocked.clear()
	_victory_events.clear()
	_game_over_events.clear()
	EventBus.floor_generated.connect(_on_floor_generated)
	EventBus.floor_reward_presented.connect(_on_reward_presented)
	EventBus.slot_unlocked.connect(_on_slot_unlocked)
	EventBus.run_victory.connect(_on_run_victory)
	EventBus.game_over.connect(_on_game_over)


func _disconnect_recorders() -> void:
	EventBus.floor_generated.disconnect(_on_floor_generated)
	EventBus.floor_reward_presented.disconnect(_on_reward_presented)
	EventBus.slot_unlocked.disconnect(_on_slot_unlocked)
	EventBus.run_victory.disconnect(_on_run_victory)
	EventBus.game_over.disconnect(_on_game_over)


func _on_floor_generated(data: Dictionary) -> void:
	_floor_maps.append(data)


func _on_reward_presented(data: Dictionary) -> void:
	_reward_presented.append(data)


func _on_slot_unlocked(data: Dictionary) -> void:
	_slot_unlocked.append(data)


func _on_run_victory(data: Dictionary) -> void:
	_victory_events.append(data)


func _on_game_over(data: Dictionary) -> void:
	_game_over_events.append(data)
