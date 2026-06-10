extends RefCounted
## L4 v1 自动验收（spec 002 T033 重写，2026-06-11 修订版 spec SC-001..SC-012 逐条映射）
## 映射索引：
##   SC-001 世界级：战斗房完成 → 恰 3 鳞片选项 → 面板选择 → 真实装备（一屏内决议）
##   SC-002 经济：+1 普通击杀 / +3 精英 / +2 每放弃项（JSON==spec 且行为==JSON）、
##          蜕皮跨层保留（FR-003）、楼层物价 = ceil(基准 × multiplier^(层-1))
##   SC-003 世界级（state_stager 布景）：商店 ≥3 货项、价签可见、购买扣款
##   SC-004 Boss 结算：固定槽位解锁先行 → 独立 3 选 1（三类各一）；终层不弹（事件路径门控）
##   SC-005 多层：定种子 3 层 PCG，主题/布局各异
##   SC-006 难度两层：静态层表 MUST（逐层严格更难）+ 反应式 SHOULD（仅生成参数级断言，
##          Designs §11.5 隐性——无任何玩家感知措辞）
##   SC-007 修饰符 v1 双件：应用可见、可叠加、随房间完成移除
##   SC-008 全量回归：由 Tools/run_tests_strict.ps1 严格门禁执行（本条断言装置存在）
##   SC-009 配置基线：全 L4 段在 JSON、max_floors_v1 零残留（文本级）
##   SC-010 概念节奏纯数据：首层零修饰零精英、每层商店保底排 ≥2 战斗房后（多种子性质）
##   SC-011 generator 开关：fixed_v1/pcg 双档、定种子 pcg 两次全等
##   SC-012 无 offer 死锁：四 offer 系统空选项自动决议 + 未决时推进请求被忽略（FR-014/FR-015）
## 终层胜利路径 / 多层推进为 pcg 档行为（T5a 裁定，FR-016 fixed_v1 = 回退/MDE 档）；
## 全 run 端到端证据 = test_l4_multifloor_run（T028）+ test_xp_contracts_l4（T034）。

const GAME_WORLD_SCENE_PATH: String = "res://scenes/game_world.tscn"
const STAGER_PATH: String = "res://Test/experience/state_stager.gd"
const GAME_CONFIG_PATH: String = "res://data/json/game_config.json"
const SCALE_SLOT_MANAGER_PATH: String = "res://systems/snake_parts/scale_slot_manager.gd"
const SCALE_REWARD_SYSTEM_PATH: String = "res://systems/growth/scale_reward_system.gd"
const SHEDSKIN_SYSTEM_PATH: String = "res://systems/growth/shedskin_system.gd"
const SHOP_SYSTEM_PATH: String = "res://systems/growth/shop_system.gd"
const SLOT_EXPANSION_SYSTEM_PATH: String = "res://systems/growth/slot_expansion_system.gd"
const FLOOR_REWARD_SYSTEM_PATH: String = "res://systems/growth/floor_reward_system.gd"
const REWARD_FLOW_SYSTEM_PATH: String = "res://systems/rewards/reward_flow_system.gd"
const RUN_PROGRESSION_SYSTEM_PATH: String = "res://systems/run/run_progression_system.gd"
const FLOOR_PROGRESS_PANEL_PATH: String = "res://ui/floor_progress_panel.gd"
const FLOOR_MAP_GENERATOR_PATH: String = "res://systems/rooms/floor_map_generator.gd"
const DIFFICULTY_SCALER_PATH: String = "res://systems/difficulty/difficulty_scaler.gd"
const ROOM_MODIFIER_SYSTEM_PATH: String = "res://systems/difficulty/room_modifier_system.gd"
const ENEMY_MANAGER_PATH: String = "res://systems/enemy/enemy_manager.gd"
const STATUS_TILE_MANAGER_PATH: String = "res://entities/status_tiles/status_tile_manager.gd"

const PCG_SEED: int = 9090
const PACING_SEEDS: Array = [9090, 4242, 20260611]


## 真实 payload 的 enemy_def 是带 enemy_type 属性的 Enemy 节点（duck typing mock）
class MockEnemy extends Node2D:
	var enemy_type: String = ""

	func _init(type_id: String) -> void:
		enemy_type = type_id


func run(t) -> void:
	# 冲掉先前套件 queue_free 未落地的残留世界（tick/EventBus 信号是全局的）
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	_test_sc001_scale_reward_one_screen(t)
	await _flush(t)
	_test_sc002_shedskin_economy(t)
	_test_sc003_shop_screen(t)
	await _flush(t)
	_test_sc004_boss_settlement(t)
	_test_sc005_multi_floor_distinct(t)
	_test_sc006_difficulty_layers(t)
	await _test_sc007_modifiers(t)
	_test_sc008_regression_gate(t)
	_test_sc009_config_baseline(t)
	_test_sc010_concept_pacing(t)
	_test_sc011_generator_switch(t)
	_test_sc012_no_offer_deadlock(t)
	await _flush(t)


func _flush(t) -> void:
	await t.get_tree().process_frame
	await t.get_tree().process_frame


# ── SC-001：战斗完成 → 3 选项 → 面板选择 → 装备生效（一屏内）─────────

func _test_sc001_scale_reward_one_screen(t) -> void:
	var saved_state: int = GameManager.current_state
	var saved_score: int = GameManager.current_score
	var saved_best: int = GameManager.best_score

	var world: Node = (load(GAME_WORLD_SCENE_PATH) as PackedScene).instantiate()
	t.add_child(world)
	world.start_game()
	GameManager.start_game()

	var room_flow: Node = world.get_node("RoomFlowSystem")
	var scale_system: Node = world.get_node("ScaleRewardSystem")
	var scale_panel: Control = world.get_node("UI/ScaleChoicePanel")
	var scale_mgr: Node = world.get_node("ScaleSlotManager")
	var shedskin: Node = world.get_node("ShedskinSystem")

	var required: int = int(room_flow.get_objective_progress().get("required", 1))
	room_flow.record_objective_progress(required, {"method": "sc001"})

	t.assert_true(scale_panel.visible, "[SC-001] scale reward screen appears after combat completion")
	t.assert_eq(scale_panel.get_visible_option_count(), 3, "[SC-001] exactly 3 scale options on screen")

	var offer: Dictionary = scale_system.get_current_offer()
	var chosen: Dictionary = offer.get("options", [])[0]
	var balance_before: int = shedskin.get_amount()
	t.assert_true(scale_panel.choose_option_by_index(0), "[SC-001] choose via the panel public API")

	var target_slot: String = str(chosen.get("target_slot", ""))
	var equipped_ids: Array = []
	for part in scale_mgr.get_scales(target_slot):
		equipped_ids.append(str(part.part_id))
	t.assert_true(equipped_ids.has(str(chosen.get("target_id", ""))),
		"[SC-001] chosen scale equips to its designated slot position (%s)" % target_slot)
	t.assert_false(scale_panel.visible, "[SC-001] the screen resolves after the choice (one screen)")
	var discard_unit: int = int(ConfigManager.get_shedskin_config().get("scale_discard", 0))
	t.assert_eq(shedskin.get_amount() - balance_before, 2 * discard_unit,
		"[SC-001/SC-002] the 2 unchosen options discard for +%d shedskin each (US2 场景 2)" % discard_unit)

	world.cleanup()
	world.queue_free()
	GameManager.current_state = saved_state
	GameManager.current_score = saved_score
	GameManager.best_score = saved_best
	TickManager.stop_ticking()
	GridWorld.clear_all()


# ── SC-002：蜕皮经济（数值 JSON==spec、跨层保留、楼层物价乘数）────────

func _test_sc002_shedskin_economy(t) -> void:
	var cfg: Dictionary = ConfigManager.get_shedskin_config()
	t.assert_eq(int(cfg.get("kill_normal", 0)), 1, "[SC-002] JSON: +1 per normal kill")
	t.assert_eq(int(cfg.get("kill_elite", 0)), 3, "[SC-002] JSON: +3 per elite kill")
	t.assert_eq(int(cfg.get("scale_discard", 0)), 2, "[SC-002] JSON: +2 per discarded scale option")

	var shedskin: Node = load(SHEDSKIN_SYSTEM_PATH).new()
	t.add_child(shedskin)
	EventBus.run_started.emit({"run_id": "sc002", "floor_index": 1, "seed": 777})
	t.assert_eq(shedskin.get_amount(), 0, "[SC-002] run start resets shedskin (FR-013)")

	var normal_enemy := MockEnemy.new("wanderer")
	var elite_enemy := MockEnemy.new("elite_wanderer")
	EventBus.enemy_killed.emit({"enemy_def": normal_enemy, "position": Vector2i.ZERO, "method": "sc002"})
	t.assert_eq(shedskin.get_amount(), int(cfg.get("kill_normal", 0)), "[SC-002] normal kill earns kill_normal")
	EventBus.enemy_killed.emit({"enemy_def": elite_enemy, "position": Vector2i.ZERO, "method": "sc002"})
	t.assert_eq(shedskin.get_amount(), int(cfg.get("kill_normal", 0)) + int(cfg.get("kill_elite", 0)),
		"[SC-002] elite kill earns kill_elite")

	# 放弃收入：真实 ScaleRewardSystem 全放弃 → 每项 +scale_discard
	var mock_snake := Node2D.new()
	mock_snake.name = "Sc002Snake"
	var scale_mgr: Node = load(SCALE_SLOT_MANAGER_PATH).new()
	scale_mgr.init_manager(mock_snake, StatusEffectManager._trigger_manager, StatusEffectManager._chain_resolver)
	var scale_system: Node = load(SCALE_REWARD_SYSTEM_PATH).new()
	scale_system.setup(scale_mgr)
	t.add_child(scale_system)
	var offer: Dictionary = scale_system.present_offer({"room_id": "sc002"})
	var option_count: int = offer.get("options", []).size()
	var before_discard: int = shedskin.get_amount()
	t.assert_true(scale_system.discard_offer(), "[SC-002] discard the whole offer")
	t.assert_eq(shedskin.get_amount() - before_discard, option_count * int(cfg.get("scale_discard", 0)),
		"[SC-002] each discarded option earns scale_discard shedskin")

	# 跨层保留（FR-003）+ 楼层物价（price_multiplier_per_floor 是唯一经济压力阀）
	var shop: Node = load(SHOP_SYSTEM_PATH).new()
	shop.setup(shedskin, scale_mgr, null)
	t.add_child(shop)
	var items_floor1: Array = shop.enter_shop("sc002_shop")
	t.assert_true(items_floor1.size() >= 3, "[SC-002] shop opens with priced items on floor 1")
	shop.exit_shop()

	var carried: int = shedskin.get_amount()
	EventBus.floor_generated.emit({"floor_index": 2})
	t.assert_eq(shedskin.get_amount(), carried,
		"[SC-002] shedskin carries over across floor transitions (FR-003, Designs §10.2)")

	var multiplier: float = ConfigManager.get_shop_price_multiplier_per_floor()
	t.assert_true(multiplier > 1.0, "[SC-002] JSON: later floors raise shop prices")
	var items_floor2: Array = shop.enter_shop("sc002_shop")
	t.assert_eq(items_floor2.size(), items_floor1.size(), "[SC-002] same seeded shelf on both visits")
	var price_scaled: bool = items_floor2.size() > 0
	for index in range(items_floor2.size()):
		var floor1_price: int = int(items_floor1[index].get("price", 0))
		var floor2_price: int = int(items_floor2[index].get("price", 0))
		if floor2_price != int(ceil(floor1_price * multiplier)) or floor2_price <= floor1_price:
			price_scaled = false
			break
	t.assert_true(price_scaled,
		"[SC-002] floor-2 prices = ceil(base x multiplier) and strictly higher (FR-003)")

	shop.cleanup()
	shop.queue_free()
	scale_system.cleanup()
	scale_system.queue_free()
	shedskin.cleanup()
	shedskin.queue_free()
	scale_mgr.clear_all()
	scale_mgr.free()
	mock_snake.free()
	normal_enemy.free()
	elite_enemy.free()


# ── SC-003：商店一屏（≥3 货项、价签、购买扣款）───────────────────────

func _test_sc003_shop_screen(t) -> void:
	var stager_script: GDScript = load(STAGER_PATH)
	var ctx: Dictionary = stager_script.stage("l4_shop_open", t)
	var world: Node = ctx.get("world", null)
	t.assert_true(world != null, "[SC-003] stager walks the fixed path into the shop room")
	if world == null:
		return

	var shop_panel: Control = world.get_node("UI/ShopPanel")
	var shop_system: Node = world.get_node("ShopSystem")
	var shedskin: Node = world.get_node("ShedskinSystem")

	t.assert_true(shop_panel.visible, "[SC-003] shop panel is on screen in the shop room")
	var item_count: int = shop_panel.get_visible_item_count()
	t.assert_true(item_count >= 3, "[SC-003] shop displays at least 3 purchasable items (%d)" % item_count)
	var all_priced: bool = item_count > 0
	for index in range(item_count):
		if shop_panel.get_row_price_text(index).strip_edges() == "":
			all_priced = false
			break
	t.assert_true(all_priced, "[SC-003] every shelf row shows a visible price")

	var inventory: Array = shop_system.get_inventory()
	var purchase_index: int = -1
	for index in range(item_count):
		if not shop_panel.is_item_disabled(index):
			purchase_index = index
			break
	t.assert_true(purchase_index >= 0, "[SC-003] at least one item is affordable after two discards")
	if purchase_index >= 0:
		var price: int = int(inventory[purchase_index].get("price", 0))
		var balance_before: int = shedskin.get_amount()
		t.assert_true(shop_panel.purchase_by_index(purchase_index), "[SC-003] purchase via the panel public API")
		t.assert_eq(shedskin.get_amount(), balance_before - price,
			"[SC-003] currency deducted by the visible price")

	stager_script.teardown(ctx)


# ── SC-004：Boss 结算两段式 + 终层不弹 ────────────────────────────────

var _sc004_presented: Array = []
var _sc004_chosen: Array = []


func _test_sc004_boss_settlement(t) -> void:
	var mock_snake := Node2D.new()
	mock_snake.name = "Sc004Snake"
	var scale_mgr: Node = load(SCALE_SLOT_MANAGER_PATH).new()
	scale_mgr.init_manager(mock_snake, StatusEffectManager._trigger_manager, StatusEffectManager._chain_resolver)
	var slot_system: Node = load(SLOT_EXPANSION_SYSTEM_PATH).new()
	slot_system.setup(scale_mgr)
	t.add_child(slot_system)
	var system: Node = load(FLOOR_REWARD_SYSTEM_PATH).new()
	system.setup(scale_mgr, slot_system)
	t.add_child(system)
	t.assert_true(scale_mgr.equip_scale("middle", "flame_scale", 1), "[SC-004] precondition: a scale equipped")

	_sc004_presented.clear()
	_sc004_chosen.clear()
	EventBus.floor_reward_presented.connect(_on_sc004_presented)
	EventBus.floor_reward_chosen.connect(_on_sc004_chosen)

	# 两段式：固定槽位解锁步骤先行（US3 场景 1），决议后才呈现独立 3 选 1
	var slots_before: int = slot_system.get_total_slots()
	var offer: Dictionary = system.present_settlement(1, "boss_01")
	t.assert_eq(str(offer.get("step", "")), "slot_unlock", "[SC-004] fixed slot-unlock step resolves first")
	t.assert_true(system.choose_slot_position("front"), "[SC-004] player picks a position (front/middle/back)")
	t.assert_eq(slot_system.get_total_slots(), slots_before + 1,
		"[SC-004] the slot REALLY opens before the 3-choose-1 (US3)")

	var options: Array = system.get_current_offer().get("options", [])
	t.assert_eq(options.size(), 3, "[SC-004] exactly 3 floor reward options")
	var categories: Array = []
	for opt in options:
		categories.append(str(opt.get("category", "")))
	t.assert_true(categories.has("expansion"), "[SC-004] expansion = random advanced scale present")
	t.assert_true(categories.has("reinforcement"), "[SC-004] reinforcement = upgrade lowest present")
	t.assert_true(categories.has("correction"), "[SC-004] correction = same-tag swap present")
	t.assert_true(system.choose_floor_reward(0), "[SC-004] choice resolves the settlement")
	t.assert_false(system.has_pending_offer(), "[SC-004] no dangling settlement after the choice")

	var steps: Array = []
	for presented in _sc004_presented:
		steps.append(str(presented.get("step", "")))
	t.assert_eq(steps, ["slot_unlock", "choice"], "[SC-004] settlement presents the two steps in order")
	t.assert_eq(_sc004_chosen.size(), 1, "[SC-004] settlement resolves with exactly one chosen event")
	t.assert_false(bool(_sc004_chosen[0].get("skipped", true)), "[SC-004] real choice is not skipped")

	# 终层不弹（US5 场景 4）：事件路径自守门——pcg 档 + 终层 floor_completed 不呈现
	var previous_generator: String = str(ConfigManager.floor.get("generator", "fixed_v1"))
	ConfigManager.floor["generator"] = "pcg"
	var presented_before: int = _sc004_presented.size()
	EventBus.floor_completed.emit({
		"run_id": "sc004",
		"floor_index": ConfigManager.get_max_floors(),
		"endpoint_room_id": "boss_final",
	})
	t.assert_eq(_sc004_presented.size(), presented_before,
		"[SC-004] FINAL floor boss presents no floor reward (victory path, US5 场景 4)")
	t.assert_false(system.has_pending_offer(), "[SC-004] final-floor completion leaves nothing pending")

	# 非终层事件路径正常呈现（对照组，防伪门控）
	EventBus.floor_completed.emit({
		"run_id": "sc004",
		"floor_index": 1,
		"endpoint_room_id": "boss_01",
	})
	t.assert_true(system.has_pending_offer(),
		"[SC-004] non-final boss completion DOES present the settlement (control group)")

	ConfigManager.floor["generator"] = previous_generator
	EventBus.floor_reward_presented.disconnect(_on_sc004_presented)
	EventBus.floor_reward_chosen.disconnect(_on_sc004_chosen)
	system.cleanup()
	system.queue_free()
	slot_system.cleanup()
	slot_system.queue_free()
	scale_mgr.clear_all()
	scale_mgr.free()
	mock_snake.free()


func _on_sc004_presented(data: Dictionary) -> void:
	_sc004_presented.append(data)


func _on_sc004_chosen(data: Dictionary) -> void:
	_sc004_chosen.append(data)


# ── SC-005：定种子 3 层 PCG，主题/布局各异 ────────────────────────────

func _test_sc005_multi_floor_distinct(t) -> void:
	var previous_generator: String = str(ConfigManager.floor.get("generator", "fixed_v1"))
	ConfigManager.floor["generator"] = "pcg"

	var gen = load(FLOOR_MAP_GENERATOR_PATH).new()
	var floor_ids: Dictionary = {}
	var themes: Dictionary = {}
	var layouts: Dictionary = {}
	for floor_index in range(1, 4):
		var floor_map: Dictionary = gen.generate_floor(floor_index, PCG_SEED)
		floor_ids[str(floor_map.get("floor_id", ""))] = true
		var theme: String = str(floor_map.get("theme_id", ""))
		themes[theme] = true
		t.assert_true(ConfigManager.get_floor_theme_ids().has(theme),
			"[SC-005] floor %d carries a valid theme (%s)" % [floor_index, theme])
		var rooms: Array = floor_map.get("rooms", [])
		t.assert_true(rooms.size() >= 5, "[SC-005] floor %d has at least 5 rooms" % floor_index)
		var signature: Array = []
		for room in rooms:
			signature.append(str(room.get("room_type", "")))
		layouts[str(signature)] = true
	t.assert_eq(floor_ids.size(), 3, "[SC-005] 3 distinct floors generated")
	t.assert_eq(themes.size(), 3, "[SC-005] themes differ across floors (seed %d)" % PCG_SEED)
	t.assert_eq(layouts.size(), 3, "[SC-005] room layouts (type sequences) differ across floors")

	ConfigManager.floor["generator"] = previous_generator


# ── SC-006：静态层表 MUST + 反应式 SHOULD（仅生成参数级）──────────────

func _test_sc006_difficulty_layers(t) -> void:
	var system: Node = load(DIFFICULTY_SCALER_PATH).new()
	t.add_child(system)

	# 静态层（MUST，玩家可感的层间压力）：逐层读数严格更难，全部出自 JSON floor_table
	var cfg: Dictionary = ConfigManager.get_difficulty_config()
	var max_floors: int = ConfigManager.get_max_floors()
	var enemy_deltas: Array = []
	var hp_bonuses: Array = []
	for floor_index in range(1, max_floors + 1):
		EventBus.floor_generated.emit({"floor_index": floor_index})
		enemy_deltas.append(system.get_static_enemy_delta())
		hp_bonuses.append(system.get_enemy_hp_bonus())
		var expected_delta: int = int(ConfigManager.get_difficulty_floor_params(floor_index).get("enemy_count", 0)) \
			- int(cfg.get("baseline_enemy_count", 0))
		t.assert_eq(enemy_deltas[-1], expected_delta,
			"[SC-006] floor %d static enemy delta read from the JSON floor table (MUST)" % floor_index)
	var strictly_harder: bool = true
	for index in range(1, enemy_deltas.size()):
		if int(enemy_deltas[index]) <= int(enemy_deltas[index - 1]) \
				or int(hp_bonuses[index]) < int(hp_bonuses[index - 1]):
			strictly_harder = false
			break
	t.assert_true(strictly_harder,
		"[SC-006] floor N+1 generation parameters strictly harder than floor N (MUST)")

	# 反应式层（SHOULD，设计不可见）：模拟过强表现 → 生成参数微调且钳在 clamp 内
	EventBus.floor_generated.emit({"floor_index": 1})
	var saved_tick: int = TickManager.current_tick
	var normalization: Dictionary = ConfigManager.get_difficulty_reactive_config().get("normalization", {})
	var rooms_between: int = int(cfg.get("rooms_between_adjustments", 2))
	for index in range(rooms_between):
		EventBus.room_entered.emit({"room_id": "sc006_%d" % index, "room_type": "combat"})
		for _i in range(int(normalization.get("status_usage_per_room", 5))):
			EventBus.reaction_triggered.emit({})
		EventBus.room_completed.emit({"room_id": "sc006_%d" % index})
	var clamp_cfg: Dictionary = ConfigManager.get_difficulty_reactive_config().get("clamp", {})
	var reactive_delta: int = system.get_reactive_enemy_delta()
	t.assert_true(reactive_delta != 0, "[SC-006] reactive layer shifts generation parameters (SHOULD)")
	t.assert_true(
		reactive_delta >= int(clamp_cfg.get("enemy_delta_min", 0))
		and reactive_delta <= int(clamp_cfg.get("enemy_delta_max", 0)),
		"[SC-006] reactive delta stays within configured clamps")

	TickManager.current_tick = saved_tick
	system.cleanup()
	system.queue_free()


# ── SC-007：修饰符 v1 双件可见、可叠加、随房间完成移除 ────────────────

func _test_sc007_modifiers(t) -> void:
	var system: Node = load(ROOM_MODIFIER_SYSTEM_PATH).new()
	GridWorld.init_grid(Constants.GRID_WIDTH, Constants.GRID_HEIGHT)
	var enemy_container := Node2D.new()
	enemy_container.name = "Sc007EnemyContainer"
	t.add_child(enemy_container)
	var em: Node = load(ENEMY_MANAGER_PATH).new()
	em.enemy_container = enemy_container
	t.add_child(em)
	var tile_mgr: Node = load(STATUS_TILE_MANAGER_PATH).new()
	tile_mgr.name = "Sc007TileManager"
	t.add_child(tile_mgr)
	t.add_child(system)
	system.setup(em, tile_mgr, null)

	em.set("respawn_policy", "room_budget")
	em.init_enemies(3)
	system.apply_modifiers({"room_id": "sc007", "modifiers": ["shield_enemies", "preset_status_tiles"]})
	t.assert_eq(system.get_active_modifiers().size(), 2, "[SC-007] both v1 modifiers active simultaneously")

	var shielded: int = 0
	for enemy in em.current_enemies:
		if enemy.has_meta("room_modifier_shield"):
			shielded += 1
	t.assert_true(shielded > 0, "[SC-007] shield_enemies marks shielded enemies visibly")
	t.assert_true(tile_mgr.get_tile_count() > 0, "[SC-007] preset_status_tiles places visible status tiles")

	EventBus.room_completed.emit({"room_id": "sc007"})
	t.assert_eq(system.get_active_modifiers().size(), 0, "[SC-007] modifiers cleared on room completion")
	t.assert_eq(tile_mgr.get_tile_count(), 0, "[SC-007] preset tiles removed with the modifier")

	system.cleanup()
	system.queue_free()
	em.clear_enemies()
	em.queue_free()
	tile_mgr.queue_free()
	enemy_container.queue_free()
	GridWorld.clear_all()
	await t.get_tree().process_frame
	await t.get_tree().process_frame


# ── SC-008：全量回归 = 严格门禁装置（STRICT PASSED 为 Gate-A 证据）────

func _test_sc008_regression_gate(t) -> void:
	var strict_path: String = (ProjectSettings.globalize_path("res://") + "/../Tools/run_tests_strict.ps1").simplify_path()
	t.assert_true(FileAccess.file_exists(strict_path),
		"[SC-008] strict regression gate wrapper exists (Tools/run_tests_strict.ps1)")


# ── SC-009：配置基线（全 JSON、max_floors_v1 零残留）──────────────────

func _test_sc009_config_baseline(t) -> void:
	var config_text: String = FileAccess.get_file_as_string(GAME_CONFIG_PATH)
	t.assert_true(config_text.length() > 0, "[SC-009] game_config.json readable")
	t.assert_false(config_text.contains("max_floors_v1"),
		"[SC-009] max_floors_v1 no longer exists anywhere in config (superseded by run.max_floors)")
	t.assert_eq(ConfigManager.get_max_floors(), int(ConfigManager.get_run_config().get("max_floors", 0)),
		"[SC-009] run.max_floors served by the accessor")
	t.assert_true(ConfigManager.get_max_floors() >= 1, "[SC-009] run.max_floors is a positive floor count")
	t.assert_true(["fixed_v1", "pcg"].has(ConfigManager.get_floor_generator()),
		"[SC-009] floor.generator is a valid enum value (FR-016)")
	# L4 配置段全部存在且非空（细粒度数据断言归 test_l4_config）
	t.assert_false(ConfigManager.get_scale_reward_config().is_empty(), "[SC-009] growth.scale_reward in JSON")
	t.assert_false(ConfigManager.get_shedskin_config().is_empty(), "[SC-009] growth.shedskin in JSON")
	t.assert_false(ConfigManager.get_slot_expansion_config().is_empty(), "[SC-009] growth.slot_expansion in JSON")
	t.assert_false(ConfigManager.get_floor_reward_config().is_empty(), "[SC-009] growth.floor_reward in JSON")
	t.assert_false(ConfigManager.get_shop_config().is_empty(), "[SC-009] shop in JSON")
	t.assert_false(ConfigManager.get_difficulty_config().is_empty(), "[SC-009] difficulty in JSON")
	t.assert_false(ConfigManager.get_pcg_config().is_empty(), "[SC-009] floor.pcg in JSON")


# ── SC-010：概念节奏纯数据（首层零修饰零精英 + 商店保底性质）──────────

func _test_sc010_concept_pacing(t) -> void:
	var floor1_weights: Dictionary = ConfigManager.get_floor_modifier_weights(1)
	var all_zero: bool = not floor1_weights.is_empty()
	for modifier_id in floor1_weights:
		if int(floor1_weights[modifier_id]) != 0:
			all_zero = false
			break
	t.assert_true(all_zero, "[SC-010] floor-1 modifier weights are all 0 (FR-017)")
	t.assert_eq(ConfigManager.get_floor_elite_weight(1), 0, "[SC-010] floor-1 elite weight is 0 (FR-017)")

	var guarantee: Dictionary = ConfigManager.get_shop_guarantee()
	var min_before: int = int(guarantee.get("min_combat_rooms_before", 0))
	t.assert_true(bool(guarantee.get("enabled", false)) and min_before >= 2,
		"[SC-010] shop guarantee configured: after at least 2 combat rooms")

	# 多种子性质：每层恰一商店，且所有 start→shop 路径前置战斗类房 ≥ min_before
	var previous_generator: String = str(ConfigManager.floor.get("generator", "fixed_v1"))
	ConfigManager.floor["generator"] = "pcg"
	var gen = load(FLOOR_MAP_GENERATOR_PATH).new()
	var property_holds: bool = true
	var failure_note: String = ""
	for seed_value in PACING_SEEDS:
		for floor_index in range(1, ConfigManager.get_max_floors() + 1):
			var floor_map: Dictionary = gen.generate_floor(floor_index, int(seed_value))
			var shop_count: int = 0
			for room in floor_map.get("rooms", []):
				if str(room.get("room_type", "")) == "shop":
					shop_count += 1
			if shop_count != 1:
				property_holds = false
				failure_note = "seed %s floor %d has %d shops" % [str(seed_value), floor_index, shop_count]
				break
			if not _all_shop_paths_have_combat(floor_map, min_before):
				property_holds = false
				failure_note = "seed %s floor %d places the shop too early" % [str(seed_value), floor_index]
				break
		if not property_holds:
			break
	t.assert_true(property_holds,
		"[SC-010] every generated floor guarantees one shop after >=%d combat rooms (%s)" % [min_before, failure_note])
	ConfigManager.floor["generator"] = previous_generator


## DFS 枚举 start→shop 全部路径：每条路径商店前的战斗类房（combat/elite）数 ≥ min_before
func _all_shop_paths_have_combat(floor_map: Dictionary, min_before: int) -> bool:
	var rooms_by_id: Dictionary = {}
	for room in floor_map.get("rooms", []):
		rooms_by_id[str(room.get("room_id", ""))] = room
	var start_id: String = str(floor_map.get("start_room_id", ""))
	if not rooms_by_id.has(start_id):
		return false
	var stack: Array = [[start_id, 0]]
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var room: Dictionary = rooms_by_id.get(str(entry[0]), {})
		var combat_count: int = int(entry[1])
		var room_type: String = str(room.get("room_type", ""))
		if room_type == "shop":
			if combat_count < min_before:
				return false
			continue
		if room_type == "combat" or room_type == "elite":
			combat_count += 1
		for exit_id in room.get("exit_room_ids", []):
			stack.append([str(exit_id), combat_count])
	return true


# ── SC-011：generator 开关 + 定种子 pcg 确定性 ────────────────────────

func _test_sc011_generator_switch(t) -> void:
	var previous_generator: String = str(ConfigManager.floor.get("generator", "fixed_v1"))
	var gen = load(FLOOR_MAP_GENERATOR_PATH).new()

	ConfigManager.floor["generator"] = "fixed_v1"
	var fixed_map: Dictionary = gen.generate_floor(1, PCG_SEED)
	t.assert_eq(str(fixed_map.get("generator", "")), "fixed_v1", "[SC-011] fixed_v1 switch position honored")
	var fixed_ids: Array = []
	for room in fixed_map.get("rooms", []):
		fixed_ids.append(str(room.get("room_id", "")))
	t.assert_eq(fixed_ids, ConfigManager.get_floor_config().get("fixed_v1_path", []),
		"[SC-011] fixed_v1 output equals the configured fixed path (fallback/MDE tier)")

	ConfigManager.floor["generator"] = "pcg"
	var first_map: Dictionary = gen.generate_floor(1, PCG_SEED)
	var second_map: Dictionary = gen.generate_floor(1, PCG_SEED)
	t.assert_eq(str(first_map.get("generator", "")), "pcg", "[SC-011] pcg switch position honored")
	t.assert_eq(var_to_str(first_map), var_to_str(second_map),
		"[SC-011] same seed generates the same graph twice (deterministic)")
	var other_map: Dictionary = gen.generate_floor(1, PCG_SEED + 1)
	t.assert_true(var_to_str(other_map) != var_to_str(first_map),
		"[SC-011] a different seed generates a different graph")

	ConfigManager.floor["generator"] = previous_generator


# ── SC-012：四 offer 系统空选项自动决议 + 模态门控 ────────────────────

var _sc012_events: Array = []
var _sc012_connections: Array = []


func _test_sc012_no_offer_deadlock(t) -> void:
	for signal_name in ["reward_presented", "reward_chosen", "scale_reward_presented",
			"scale_reward_chosen", "floor_reward_presented", "floor_reward_chosen",
			"shop_entered", "room_completed"]:
		var callback: Callable = _on_sc012_event.bind(signal_name)
		EventBus.connect(signal_name, callback)
		_sc012_connections.append({"name": signal_name, "callable": callback})
	_sc012_events.clear()

	# ① RewardFlowSystem（L3 奖励流）：零可应用选项 → chosen 带 skipped + 合成 room_completed
	#   （L3 奖励房唯一完成通路保留，FR-018——流程继续不依赖玩家输入）
	var reward_flow: Node = load(REWARD_FLOW_SYSTEM_PATH).new()
	reward_flow.setup(null, null)
	t.add_child(reward_flow)
	var rf_offer: Dictionary = reward_flow.present_offer({"room_id": "sc012_reward", "room_type": "reward"})
	t.assert_true(rf_offer.is_empty(), "[SC-012] RewardFlow zero-option offer returns empty (no modal)")
	t.assert_eq(_count_sc012("reward_presented"), 0, "[SC-012] RewardFlow presents nothing on empty offer")
	t.assert_eq(_count_sc012("reward_chosen"), 1, "[SC-012] RewardFlow auto-resolves with reward_chosen")
	t.assert_true(bool(_last_sc012("reward_chosen").get("skipped", false)),
		"[SC-012] RewardFlow auto-resolution carries skipped: true (FR-014)")
	t.assert_eq(_count_sc012("room_completed"), 1,
		"[SC-012] RewardFlow synthetic room_completed keeps the room pathway alive (FR-018)")
	reward_flow.cleanup()
	reward_flow.queue_free()

	# ② ScaleRewardSystem：零合格选项（无槽位管理器 = 全部不可承载）→ chosen 带 skipped
	var scale_system: Node = load(SCALE_REWARD_SYSTEM_PATH).new()
	scale_system.setup(null)
	t.add_child(scale_system)
	var scale_offer: Dictionary = scale_system.present_offer({"room_id": "sc012_scale"})
	t.assert_true(scale_offer.is_empty(), "[SC-012] ScaleReward zero-eligible offer returns empty")
	t.assert_eq(_count_sc012("scale_reward_presented"), 0, "[SC-012] ScaleReward presents no modal")
	t.assert_true(bool(_last_sc012("scale_reward_chosen").get("skipped", false)),
		"[SC-012] ScaleReward auto-resolves with skipped: true (FR-014)")
	t.assert_false(scale_system.has_pending_offer(), "[SC-012] ScaleReward leaves nothing pending")
	scale_system.cleanup()
	scale_system.queue_free()

	# ③ FloorRewardSystem：槽位与三类全空 → chosen 带 skipped、不发 presented
	var floor_reward: Node = load(FLOOR_REWARD_SYSTEM_PATH).new()
	floor_reward.setup(null, null)
	t.add_child(floor_reward)
	var settlement: Dictionary = floor_reward.present_settlement(1, "sc012_boss")
	t.assert_true(settlement.is_empty(), "[SC-012] FloorReward all-empty settlement returns empty")
	t.assert_eq(_count_sc012("floor_reward_presented"), 0, "[SC-012] FloorReward presents no modal")
	t.assert_true(bool(_last_sc012("floor_reward_chosen").get("skipped", false)),
		"[SC-012] FloorReward auto-resolves with skipped: true (FR-014)")
	t.assert_false(floor_reward.has_pending_offer(), "[SC-012] FloorReward leaves nothing pending")
	floor_reward.cleanup()
	floor_reward.queue_free()

	# ④ ShopSystem：空货架 → 不发 shop_entered、不进 active（玩家可径直离店）
	var shop: Node = load(SHOP_SYSTEM_PATH).new()
	shop.setup(null, null, null)
	t.add_child(shop)
	var items: Array = shop.enter_shop("sc012_shop")
	t.assert_true(items.is_empty(), "[SC-012] Shop empty shelf returns no items")
	t.assert_eq(_count_sc012("shop_entered"), 0, "[SC-012] Shop never announces an empty shelf")
	t.assert_false(shop.is_active(), "[SC-012] Shop stays inactive on empty inventory (no deadlock)")
	shop.cleanup()
	shop.queue_free()

	# ⑤ 门控（FR-015）：未决 offer 时推进请求被忽略、Next UI 禁用；决议后恢复推进
	var run_system: Node = load(RUN_PROGRESSION_SYSTEM_PATH).new()
	t.add_child(run_system)
	var floor_panel: Control = load(FLOOR_PROGRESS_PANEL_PATH).new()
	t.add_child(floor_panel)
	run_system.start_run()
	EventBus.room_completed.emit({"room_id": "combat_01", "room_type": "combat"})

	EventBus.scale_reward_presented.emit({"offer_id": "sc012_gate", "options": []})
	t.assert_true(run_system.has_pending_offer(), "[SC-012] pending offer registered (FR-015)")
	t.assert_true(floor_panel.is_advance_blocked(), "[SC-012] room-advance UI disabled while pending")
	EventBus.room_advance_requested.emit({})
	t.assert_eq(run_system.get_state().get("current_room_id", ""), "combat_01",
		"[SC-012] advance request ignored while an offer is pending")

	EventBus.scale_option_discarded.emit({"offer_id": "sc012_gate", "discarded_ids": [], "shedskin_gained": 0})
	t.assert_false(run_system.has_pending_offer(), "[SC-012] resolution clears the pending offer")
	t.assert_false(floor_panel.is_advance_blocked(), "[SC-012] room-advance UI re-enabled after resolution")
	EventBus.room_advance_requested.emit({})
	t.assert_eq(run_system.get_state().get("current_room_id", ""), "reward_01",
		"[SC-012] run progression continues after the offer resolves")

	floor_panel.queue_free()
	run_system.cleanup()
	run_system.queue_free()

	for connection in _sc012_connections:
		EventBus.disconnect(str(connection.get("name", "")), connection.get("callable"))
	_sc012_connections.clear()


func _on_sc012_event(data: Dictionary, signal_name: String) -> void:
	_sc012_events.append({"name": signal_name, "data": data})


func _count_sc012(signal_name: String) -> int:
	var count: int = 0
	for entry in _sc012_events:
		if str(entry.get("name", "")) == signal_name:
			count += 1
	return count


func _last_sc012(signal_name: String) -> Dictionary:
	for index in range(_sc012_events.size() - 1, -1, -1):
		if str(_sc012_events[index].get("name", "")) == signal_name:
			return _sc012_events[index].get("data", {})
	return {}
