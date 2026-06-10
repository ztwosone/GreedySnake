extends RefCounted
## L4 US5 重验收测试（spec 002 T024-T027，2026-06-11 修订版 spec 对照）：
## Boss 结算 = 固定槽位解锁步骤（玩家选前/中/后，先行）+ 独立 3 选 1（FR-007/US3 场景 1）；
## 三选项恰为 扩展=随机高级鳞 / 强化=最低等级鳞免费升一级 / 修正=同 tag 换鳞（Designs §10.4）；
## 终层不弹（US5 场景 4）+ fixed_v1 档不弹（T5a 裁定：单层 MDE 闭环终点即胜利，结算无后续楼层）；
## 奖励决议先于 advance_floor/floor_generated（US5 场景 5，T027 集成）；
## 全空自动决议（FR-014）+ 无合格目标类别以「随机高级鳞」替补（spec Edge Cases）；
## floor_reward_panel 两段式 ui/kit 模态（T026：槽位定位选择 → choice_card×3）。

const FLOOR_REWARD_PATH: String = "res://systems/growth/floor_reward_system.gd"
const FLOOR_REWARD_PANEL_PATH: String = "res://ui/floor_reward_panel.gd"
const SLOT_EXPANSION_PATH: String = "res://systems/growth/slot_expansion_system.gd"
const SCALE_SLOT_MANAGER_PATH: String = "res://systems/snake_parts/scale_slot_manager.gd"
const RUN_PROGRESSION_PATH: String = "res://systems/run/run_progression_system.gd"

var _presented: Array = []
var _chosen: Array = []
var _slot_unlocked: Array = []
var _sequence: Array = []


func run(t) -> void:
	t.assert_file_exists(FLOOR_REWARD_PATH)
	t.assert_file_exists(FLOOR_REWARD_PANEL_PATH)
	_test_floor_reward_config(t)
	_test_slot_step_precedes_choice(t)
	_test_substitution_and_expansion_apply(t)
	_test_correction_swaps_same_tag(t)
	_test_slot_step_skipped_when_maxed(t)
	_test_auto_resolve_when_all_empty(t)
	_test_auto_resolve_after_slot_pick(t)
	_test_final_floor_and_generator_gating(t)
	_test_panel_two_step_flow(t)
	# 冲掉本帧 queue_free 的面板/系统（EventBus 连接随 _exit_tree 落地解除）
	await t.get_tree().process_frame
	await _test_resolution_precedes_floor_generated(t)
	_test_world_scene_carries_settlement_nodes(t)


# ── T024: 配置（FR-007/FR-010） ──────────────────────────────────────

func _test_floor_reward_config(t) -> void:
	var cfg: Dictionary = ConfigManager.get_floor_reward_config()
	t.assert_eq(int(cfg.get("offer_count", 0)), 3, "[T024] offer_count = 3")
	t.assert_eq(cfg.get("categories", []), ["expansion", "reinforcement", "correction"],
		"[T024] exactly one option per category (Designs §10.4 三类各一)")
	var expansion: Dictionary = cfg.get("expansion", {})
	t.assert_true(int(expansion.get("advanced_level", 0)) >= 2,
		"[T024] expansion advanced_level in JSON (高级鳞 = 高于基础等级，FR-010)")
	var pool_id: String = str(expansion.get("scale_pool", ""))
	t.assert_true(pool_id != "" and ConfigManager.get_scale_reward_pool(pool_id).size() > 0,
		"[T024] expansion draws from a configured non-empty scale pool")


# ── T024/T025: 固定槽位解锁步骤先于 3 选 1（US3 场景 1 / FR-007） ───

func _test_slot_step_precedes_choice(t) -> void:
	var setup: Dictionary = _make_setup(t)
	var system: Node = setup["system"]
	var scale_mgr: Node = setup["scale_mgr"]
	t.assert_true(scale_mgr.equip_scale("middle", "flame_scale", 1), "[T024] precondition: flame in middle")
	t.assert_true(scale_mgr.equip_scale("back", "thorn_scale", 1), "[T024] precondition: thorn in back")
	_connect_recorders()

	var offer: Dictionary = system.present_settlement(1, "boss_01")
	t.assert_eq(_presented.size(), 1, "[T024] settlement presents once at start")
	t.assert_eq(str(offer.get("step", "")), "slot_unlock",
		"[T024] FIXED slot-unlock step comes first (US3 场景 1)")
	t.assert_eq(offer.get("slot_options", []), ["front", "middle", "back"],
		"[T024] player picks among eligible positions")
	t.assert_eq(offer.get("options", []).size(), 0, "[T024] 3-choose-1 not built during the slot step")
	t.assert_true(system.has_pending_offer(), "[T024] settlement pending across both steps")
	t.assert_false(system.choose_floor_reward(0), "[T024] choice refused while in the slot step")
	t.assert_false(system.choose_slot_position("nowhere"), "[T024] bogus position refused")

	t.assert_true(system.choose_slot_position("front"), "[T024] player picks front")
	t.assert_eq(scale_mgr.get_open_slots("front"), 2,
		"[T024] new slot opens BEFORE the floor reward is presented (US3 场景 1)")
	t.assert_eq(_slot_unlocked.size(), 1, "[T024] slot_unlocked emitted through the adapter")
	if _slot_unlocked.size() > 0:
		t.assert_eq(str(_slot_unlocked[0].get("source", "")), "boss", "[T024] unlock tagged source=boss")
	t.assert_eq(_presented.size(), 2, "[T024] choice step presented after the slot pick")
	t.assert_eq(_chosen.size(), 0, "[T024] gate not released between the two steps (FR-015)")

	var choice: Dictionary = _presented[1] if _presented.size() > 1 else {}
	t.assert_eq(str(choice.get("step", "")), "choice", "[T024] second presentation is the 3-choose-1")
	var options: Array = choice.get("options", [])
	t.assert_eq(options.size(), 3, "[T024] exactly 3 floor reward options")
	var categories: Array = []
	for option in options:
		categories.append(str(option.get("category", "")))
	t.assert_eq(categories, ["expansion", "reinforcement", "correction"],
		"[T024] one option from each category, in config order")

	# 扩展类：随机高级鳞（advanced_level，目标位置可承载）
	var expansion: Dictionary = options[0] if options.size() > 0 else {}
	var advanced_level: int = int(ConfigManager.get_floor_reward_config().get("expansion", {}).get("advanced_level", 0))
	t.assert_eq(int(expansion.get("level", 0)), advanced_level, "[T024] expansion offers an ADVANCED scale")
	t.assert_false(ConfigManager.get_snake_scale(str(expansion.get("target_id", "")), advanced_level).is_empty(),
		"[T024] expansion target exists at the advanced level")

	# 强化类：当前最低等级鳞片免费升一级（flame/thorn 同为 L1，按 front→middle→back 序取 flame）
	var reinforcement: Dictionary = options[1] if options.size() > 1 else {}
	t.assert_eq(str(reinforcement.get("target_id", "")), "flame_scale",
		"[T024] reinforcement targets the lowest-level equipped scale")
	t.assert_eq(int(reinforcement.get("level", 0)), 2, "[T024] reinforcement upgrades by one level")
	t.assert_eq(str(reinforcement.get("position", "")), "middle", "[T024] reinforcement carries slot position")

	# 修正类：同 tag 换鳞（替换目标 ≠ 原件且共享至少一个 tag）
	var correction: Dictionary = options[2] if options.size() > 2 else {}
	var replace_id: String = str(correction.get("replace_id", ""))
	var swap_id: String = str(correction.get("target_id", ""))
	t.assert_true(replace_id in ["flame_scale", "thorn_scale"], "[T024] correction replaces an EQUIPPED scale")
	t.assert_true(swap_id != "" and swap_id != replace_id, "[T024] correction swaps to a different scale")
	var shares_tag: bool = false
	for tag in ConfigManager.get_scale_tags(replace_id):
		if ConfigManager.get_scale_tags(swap_id).has(tag):
			shares_tag = true
	t.assert_true(shares_tag, "[T024] correction swap shares a tag with the replaced scale")

	# 选强化 → flame 升 L2，决议事件解除门控
	var index: int = categories.find("reinforcement")
	t.assert_true(system.choose_floor_reward(index), "[T024] choosing reinforcement succeeds")
	t.assert_eq(_chosen.size(), 1, "[T024] floor_reward_chosen emitted once")
	if _chosen.size() > 0:
		t.assert_eq(str(_chosen[0].get("category", "")), "reinforcement", "[T024] chosen carries category")
		t.assert_false(bool(_chosen[0].get("skipped", true)), "[T024] real choice is not skipped")
		t.assert_eq(int(_chosen[0].get("floor_index", 0)), 1, "[T024] chosen carries floor_index")
	var middle_scales: Array = scale_mgr.get_scales("middle")
	t.assert_true(middle_scales.size() == 1 and int(middle_scales[0].level) == 2,
		"[T024] reinforcement REALLY upgrades the scale (draft regression: fake apply)")
	t.assert_false(system.has_pending_offer(), "[T024] settlement resolved")

	_disconnect_recorders()
	_free_setup(setup)


# ── T024/T025: 无合格目标类别以「随机高级鳞」替补（spec Edge Cases）──

func _test_substitution_and_expansion_apply(t) -> void:
	var setup: Dictionary = _make_setup(t)
	var system: Node = setup["system"]
	var scale_mgr: Node = setup["scale_mgr"]
	_connect_recorders()

	# 无已装鳞片：强化/修正无目标 → 以高级鳞替补，仍保持 3 选项
	system.present_settlement(1, "boss_02")
	t.assert_true(system.choose_slot_position("middle"), "[T024] slot step resolves")
	var options: Array = system.get_current_offer().get("options", [])
	t.assert_eq(options.size(), 3, "[T024] 3 options remain via substitution (Edge Cases)")
	var target_ids: Dictionary = {}
	for option in options:
		t.assert_eq(str(option.get("category", "")), "expansion",
			"[T024] empty-target categories substitute advanced scale options")
		target_ids[str(option.get("target_id", ""))] = true
	t.assert_eq(target_ids.size(), 3, "[T024] substituted options offer distinct scales")

	# 扩展类应用：选中即装备高级鳞
	var picked: Dictionary = options[1]
	t.assert_true(system.choose_floor_reward(1), "[T024] expansion choice applies")
	var equipped: bool = false
	for part in scale_mgr.get_scales(str(picked.get("position", ""))):
		if str(part.part_id) == str(picked.get("target_id", "")) and int(part.level) == int(picked.get("level", 0)):
			equipped = true
	t.assert_true(equipped, "[T024] expansion equips the advanced scale (draft regression: hardcoded equip)")

	_disconnect_recorders()
	_free_setup(setup)


# ── T024/T025: 修正类同 tag 换鳞应用 ─────────────────────────────────

func _test_correction_swaps_same_tag(t) -> void:
	var setup: Dictionary = _make_setup(t)
	var system: Node = setup["system"]
	var scale_mgr: Node = setup["scale_mgr"]
	t.assert_true(scale_mgr.equip_scale("back", "thorn_scale", 1), "[T024] precondition: thorn in back")
	_connect_recorders()

	system.present_settlement(1, "boss_03")
	t.assert_true(system.choose_slot_position("front"), "[T024] slot step resolves")
	var options: Array = system.get_current_offer().get("options", [])
	var correction_index: int = -1
	for index in range(options.size()):
		if str(options[index].get("category", "")) == "correction":
			correction_index = index
	t.assert_true(correction_index >= 0, "[T024] correction option present with an equipped scale")
	if correction_index < 0:
		_disconnect_recorders()
		_free_setup(setup)
		return
	var correction: Dictionary = options[correction_index]
	t.assert_eq(str(correction.get("replace_id", "")), "thorn_scale", "[T024] correction targets thorn (唯一已装)")
	t.assert_eq(str(correction.get("target_id", "")), "retaliation_scale",
		"[T024] same-tag swap: physical -> retaliation (唯一同 tag 候选)")
	t.assert_eq(int(correction.get("level", 0)), 1, "[T024] swap preserves the level")

	t.assert_true(system.choose_floor_reward(correction_index), "[T024] correction choice applies")
	var back_ids: Array = []
	for part in scale_mgr.get_scales("back"):
		back_ids.append(str(part.part_id))
	t.assert_eq(back_ids, ["retaliation_scale"],
		"[T024] correction REALLY swaps the scale (draft regression: correction was pass)")

	_disconnect_recorders()
	_free_setup(setup)


# ── T024/T025: 槽位全满 → 跳过槽位步骤直入 3 选 1（FR-014 精神）─────

func _test_slot_step_skipped_when_maxed(t) -> void:
	var setup: Dictionary = _make_setup(t)
	var system: Node = setup["system"]
	var scale_mgr: Node = setup["scale_mgr"]
	for position in ["front", "middle", "back"]:
		while scale_mgr.open_slot(position):
			pass
	t.assert_true(scale_mgr.equip_scale("middle", "flame_scale", 1), "[T024] precondition: flame equipped")
	_connect_recorders()

	var offer: Dictionary = system.present_settlement(2, "boss_04")
	t.assert_eq(_presented.size(), 1, "[T024] single presentation when no slot is unlockable")
	t.assert_eq(str(offer.get("step", "")), "choice",
		"[T024] slot step auto-skips when all positions are at max")
	t.assert_eq(offer.get("options", []).size(), 3, "[T024] choice step intact without the slot step")
	t.assert_true(system.choose_floor_reward(0), "[T024] choice resolves the settlement")
	t.assert_false(system.has_pending_offer(), "[T024] no dangling offer")

	_disconnect_recorders()
	_free_setup(setup)


# ── T024/T025: 全空自动决议（FR-014——空选项 + 模态门控否则死锁）────

func _test_auto_resolve_when_all_empty(t) -> void:
	var setup: Dictionary = _make_setup(t)
	var system: Node = setup["system"]
	var scale_mgr: Node = setup["scale_mgr"]
	for position in ["front", "middle", "back"]:
		while scale_mgr.open_slot(position):
			pass
	var expansion_cfg: Dictionary = ConfigManager.growth.get("floor_reward", {}).get("expansion", {})
	var saved_pool: String = str(expansion_cfg.get("scale_pool", ""))
	expansion_cfg["scale_pool"] = "t024_empty_pool"
	_connect_recorders()

	var offer: Dictionary = system.present_settlement(1, "boss_05")
	t.assert_true(offer.is_empty(), "[T024] auto-resolve returns no offer")
	t.assert_eq(_presented.size(), 0, "[T024] FR-014 auto-resolve never presents a modal")
	t.assert_eq(_chosen.size(), 1, "[T024] auto-resolve emits floor_reward_chosen")
	if _chosen.size() > 0:
		t.assert_true(bool(_chosen[0].get("skipped", false)), "[T024] auto-resolve marked skipped=true")
	t.assert_false(system.has_pending_offer(), "[T024] progression can never deadlock on an empty offer")

	expansion_cfg["scale_pool"] = saved_pool
	_disconnect_recorders()
	_free_setup(setup)


# ── T024/T025: 槽位步骤后选项为空 → 自动决议解除门控 ────────────────

func _test_auto_resolve_after_slot_pick(t) -> void:
	var setup: Dictionary = _make_setup(t)
	var system: Node = setup["system"]
	var expansion_cfg: Dictionary = ConfigManager.growth.get("floor_reward", {}).get("expansion", {})
	var saved_pool: String = str(expansion_cfg.get("scale_pool", ""))
	expansion_cfg["scale_pool"] = "t024_empty_pool"
	_connect_recorders()

	system.present_settlement(1, "boss_06")
	t.assert_eq(_presented.size(), 1, "[T024] slot step still presents (positions eligible)")
	t.assert_true(system.choose_slot_position("middle"), "[T024] slot pick succeeds")
	t.assert_eq(_presented.size(), 1, "[T024] empty choice step never presents")
	t.assert_eq(_chosen.size(), 1, "[T024] empty choice step auto-resolves after the slot pick")
	if _chosen.size() > 0:
		t.assert_true(bool(_chosen[0].get("skipped", false)), "[T024] post-slot auto-resolve marked skipped")
	t.assert_false(system.has_pending_offer(), "[T024] gate released (FR-014/FR-015 配对)")

	expansion_cfg["scale_pool"] = saved_pool
	_disconnect_recorders()
	_free_setup(setup)


# ── T024/T025: 终层不弹 + fixed_v1 档不弹（US5 场景 4 / T5a 裁定）───

func _test_final_floor_and_generator_gating(t) -> void:
	var setup: Dictionary = _make_setup(t)
	var system: Node = setup["system"]
	_connect_recorders()

	# fixed_v1 档（默认）：单层 MDE 闭环终点即胜利，结算不弹
	EventBus.floor_completed.emit({"run_id": "run_t024", "floor_index": 1, "endpoint_room_id": "endpoint_01"})
	t.assert_eq(_presented.size(), 0, "[T024] fixed_v1 floor completion presents nothing (MDE 单层闭环)")
	t.assert_eq(_chosen.size(), 0, "[T024] fixed_v1 floor completion auto-resolves nothing")

	var previous: String = _force_generator("pcg")
	# 终层：不弹楼层奖励，直达胜利路径（US5 场景 4）
	EventBus.floor_completed.emit({
		"run_id": "run_t024",
		"floor_index": ConfigManager.get_max_floors(),
		"endpoint_room_id": "boss_final",
	})
	t.assert_eq(_presented.size(), 0, "[T024] FINAL floor boss presents NO floor reward (US5 场景 4)")
	t.assert_eq(_chosen.size(), 0, "[T024] final floor emits no synthetic resolution either")

	# 非终层 pcg：照常呈现
	EventBus.floor_completed.emit({"run_id": "run_t024", "floor_index": 1, "endpoint_room_id": "boss_01"})
	t.assert_eq(_presented.size(), 1, "[T024] non-final pcg boss completion presents the settlement")
	t.assert_true(system.has_pending_offer(), "[T024] settlement pending after event-driven present")

	_restore_generator(previous)
	_disconnect_recorders()
	_free_setup(setup)


# ── T026: 面板两段式（ui/kit 模态，公共 API 驱动） ───────────────────

func _test_panel_two_step_flow(t) -> void:
	var setup: Dictionary = _make_setup(t)
	var system: Node = setup["system"]
	var scale_mgr: Node = setup["scale_mgr"]
	t.assert_true(scale_mgr.equip_scale("middle", "flame_scale", 1), "[T026] precondition: flame equipped")

	var panel: Control = load(FLOOR_REWARD_PANEL_PATH).new()
	panel.name = "T026FloorRewardPanel"
	t.add_child(panel)
	panel.setup(system)
	t.assert_true(panel.is_in_group("ui_kit"), "[T026] panel born in ui_kit group (S1 内核)")
	t.assert_true(panel.is_in_group("ui_modal"), "[T026] panel joins ui_modal (模态唯一探测)")
	t.assert_eq(str(panel.get_meta("ui_layer", "")), "modal", "[T026] ui_layer meta = modal")
	t.assert_false(panel.visible, "[T026] panel hidden before presentation")

	system.present_settlement(1, "boss_ui")
	t.assert_true(panel.visible, "[T026] panel shows on the slot step")
	t.assert_eq(panel.get_step(), "slot_unlock", "[T026] panel reports the slot step")
	t.assert_eq(panel.get_visible_option_count(), 3, "[T026] three slot position cards")
	t.assert_eq(panel.get_slot_labels(), ["前段", "中段", "后段"], "[T026] readable position names (§3 词汇表)")

	t.assert_true(panel.choose_slot_by_index(0), "[T026] slot pick through the panel API")
	t.assert_eq(panel.get_step(), "choice", "[T026] panel transitions to the choice step")
	t.assert_eq(panel.get_visible_option_count(), 3, "[T026] choice_card x3")
	t.assert_eq(panel.get_option_labels().size(), 3, "[T026] option labels exposed")

	t.assert_true(panel.choose_option_by_index(0), "[T026] choice through the panel API")
	t.assert_false(panel.visible, "[T026] panel hides after resolution")
	t.assert_false(system.has_pending_offer(), "[T026] panel-driven flow resolves the settlement")

	panel.queue_free()
	_free_setup(setup)


# ── T027: 决议先于 advance_floor/floor_generated（US5 场景 5） ───────

func _test_resolution_precedes_floor_generated(t) -> void:
	var previous: String = _force_generator("pcg")
	var setup: Dictionary = _make_setup(t)
	var system: Node = setup["system"]
	var run_system: Node = load(RUN_PROGRESSION_PATH).new()
	t.add_child(run_system)
	_connect_recorders()
	_sequence.clear()
	EventBus.floor_generated.connect(_on_floor_generated)

	run_system.start_run(9090)
	_walk_floor_to_endpoint(run_system)
	t.assert_true(system.has_pending_offer(),
		"[T027] boss completion presents the settlement inside the same dispatch")
	t.assert_eq(int(run_system.get_state().get("floor_index", 0)), 1, "[T027] floor unchanged at presentation")

	EventBus.room_advance_requested.emit({})
	await t.get_tree().process_frame
	t.assert_eq(int(run_system.get_state().get("floor_index", 0)), 1,
		"[T027] advance held while the settlement is unresolved (FR-015)")
	t.assert_eq(_sequence.count("floor_generated"), 1,
		"[T027] no floor_generated before the reward resolves (US5 场景 5)")

	var offer: Dictionary = system.get_current_offer()
	if str(offer.get("step", "")) == "slot_unlock":
		t.assert_true(system.choose_slot_position(str(offer.get("slot_options", ["front"])[0])),
			"[T027] resolve the slot step")
	t.assert_true(system.choose_floor_reward(0), "[T027] resolve the 3-choose-1")
	await t.get_tree().process_frame
	t.assert_eq(int(run_system.get_state().get("floor_index", 0)), 2,
		"[T027] floor advances right after resolution")
	t.assert_eq(_sequence, ["floor_generated", "chosen", "floor_generated"],
		"[T027] resolution strictly precedes the next floor_generated")

	EventBus.floor_generated.disconnect(_on_floor_generated)
	_disconnect_recorders()
	run_system.cleanup()
	run_system.queue_free()
	_free_setup(setup)
	_restore_generator(previous)
	await t.get_tree().process_frame


# ── T027: 场景接线（game_world 节点存在性） ──────────────────────────

func _test_world_scene_carries_settlement_nodes(t) -> void:
	var scene = load("res://scenes/game_world.tscn") as PackedScene
	var world: Node = scene.instantiate()
	t.assert_true(world.get_node_or_null("FloorRewardSystem") != null,
		"[T027] game_world scene carries a FloorRewardSystem node")
	t.assert_true(world.get_node_or_null("UI/FloorRewardPanel") != null,
		"[T027] game_world scene carries the FloorRewardPanel")
	world.free()


# ── Helpers ──────────────────────────────────────────────────────────

func _make_setup(t) -> Dictionary:
	var mock_snake := Node2D.new()
	mock_snake.name = "FloorRewardMockSnake"
	var scale_mgr: Node = load(SCALE_SLOT_MANAGER_PATH).new()
	scale_mgr.init_manager(mock_snake, StatusEffectManager._trigger_manager, StatusEffectManager._chain_resolver)
	var slot_system: Node = load(SLOT_EXPANSION_PATH).new()
	slot_system.setup(scale_mgr)
	t.add_child(slot_system)
	var system: Node = load(FLOOR_REWARD_PATH).new()
	system.setup(scale_mgr, slot_system)
	t.add_child(system)
	return {
		"snake": mock_snake,
		"scale_mgr": scale_mgr,
		"slot_system": slot_system,
		"system": system,
	}


func _free_setup(setup: Dictionary) -> void:
	setup["system"].cleanup()
	setup["system"].queue_free()
	setup["slot_system"].cleanup()
	setup["slot_system"].queue_free()
	setup["scale_mgr"].clear_all()
	setup["scale_mgr"].free()
	setup["snake"].free()


func _connect_recorders() -> void:
	_presented.clear()
	_chosen.clear()
	_slot_unlocked.clear()
	if not EventBus.floor_reward_presented.is_connected(_on_presented):
		EventBus.floor_reward_presented.connect(_on_presented)
	if not EventBus.floor_reward_chosen.is_connected(_on_chosen):
		EventBus.floor_reward_chosen.connect(_on_chosen)
	if not EventBus.slot_unlocked.is_connected(_on_slot_unlocked):
		EventBus.slot_unlocked.connect(_on_slot_unlocked)


func _disconnect_recorders() -> void:
	if EventBus.floor_reward_presented.is_connected(_on_presented):
		EventBus.floor_reward_presented.disconnect(_on_presented)
	if EventBus.floor_reward_chosen.is_connected(_on_chosen):
		EventBus.floor_reward_chosen.disconnect(_on_chosen)
	if EventBus.slot_unlocked.is_connected(_on_slot_unlocked):
		EventBus.slot_unlocked.disconnect(_on_slot_unlocked)


func _on_presented(data: Dictionary) -> void:
	_presented.append(data)


func _on_chosen(data: Dictionary) -> void:
	_chosen.append(data)
	_sequence.append("chosen")


func _on_slot_unlocked(data: Dictionary) -> void:
	_slot_unlocked.append(data)


func _on_floor_generated(_data: Dictionary) -> void:
	_sequence.append("floor_generated")


func _walk_floor_to_endpoint(run_system: Node) -> void:
	## 完成当前楼层全部主路径房（含 endpoint/boss 的 completion 发射）
	for _i in range(32):
		var room: Dictionary = run_system.get_current_room()
		var room_id: String = str(room.get("room_id", ""))
		EventBus.room_completed.emit({"room_id": room_id})
		if room_id == str(run_system.get_floor_map().get("endpoint_room_id", "")):
			return
		var exits: Array = room.get("exit_room_ids", [])
		if exits.is_empty():
			return
		run_system.advance_to_room(str(exits[0]))


func _force_generator(mode: String) -> String:
	var previous: String = str(ConfigManager.floor.get("generator", "fixed_v1"))
	ConfigManager.floor["generator"] = mode
	return previous


func _restore_generator(previous: String) -> void:
	ConfigManager.floor["generator"] = previous
