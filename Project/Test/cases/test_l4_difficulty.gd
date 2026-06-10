extends RefCounted
## L4 US6 重验收测试（spec 002 T029-T031，2026-06-11 修订版 spec 对照）：
## - FR-008 MUST 静态层：difficulty.floor_table → DifficultyScaler 静态层
##   （get_static_enemy_delta/get_enemy_hp_bonus）→ RoomDirector 消费
##   （敌人预算 + spawn_hp_bonus + 食物数，钳制参数全部走 difficulty 配置）；
## - FR-008 SHOULD 反应式 DDA：设计不可见（Designs §11.5「对玩家不可见」）——
##   本套件只做生成参数级断言，无任何玩家感知措辞；单房口径度量
##   （草稿 :114 全局累计 tick 回归）、命中源 snake_body_attacked/snake_hit_boundary、
##   状态源 reaction_triggered + status_added_to_carrier(carrier_type=="enemy")、
##   归一化分母 JSON 化（草稿 :93 硬编码回归）、clamp 边界、reactive.enabled
##   砍单开关（砍单阶梯首位）、run_started 重置（FR-013）；
## - FR-009 修饰符 v1（shield_enemies/preset_status_tiles）：经 RoomDirector 注入点
##   实际应用（草稿从不被应用）、可见标记（护盾描边 + 状态格视觉复用）、
##   room_completed 移除且不误伤外部状态格、应用层逐项 disable 复核、
##   叠加独立可读（spec edge case）、草稿残留/未知 id 拒绝（darkness 已入 backlog）；
## - T032 节奏数据互证归 test_l4_config / test_l4_pcg_rooms。

const SCALER_PATH: String = "res://systems/difficulty/difficulty_scaler.gd"
const MODIFIER_PATH: String = "res://systems/difficulty/room_modifier_system.gd"
const DIRECTOR_PATH: String = "res://systems/rooms/room_director.gd"
const ENEMY_MANAGER_PATH: String = "res://systems/enemy/enemy_manager.gd"
const FOOD_MANAGER_PATH: String = "res://systems/food_manager.gd"
const TILE_MANAGER_PATH: String = "res://entities/status_tiles/status_tile_manager.gd"
const GAME_WORLD_SCENE_PATH: String = "res://scenes/game_world.tscn"

var _adjusted_events: Array = []
var _modifier_events: Array = []
var _tile_placed_events: Array = []


class SnakeStub:
	extends RefCounted
	## preset_status_tiles 的 min_distance_from_snake 距离检查用 duck-typed 蛇桩
	var body: Array = []


func run(t) -> void:
	t.assert_file_exists(SCALER_PATH)
	t.assert_file_exists(MODIFIER_PATH)

	# ── FR-008 MUST：静态层 ──
	_test_scaler_contract(t)
	_test_static_floor_deltas(t)
	await _test_enemy_manager_spawn_hp_bonus(t)
	await _test_director_consumes_static_scaling(t)
	await _test_director_clamps_from_config(t)

	# ── FR-008 SHOULD：反应式 DDA（仅生成参数级断言） ──
	_test_per_room_tick_measurement(t)
	_test_hit_and_status_sources(t)
	_test_reactive_overperform_shifts_params(t)
	_test_reactive_underperform_shifts_params(t)
	_test_reactive_clamped_from_json(t)
	_test_normalization_denominators_from_json(t)
	_test_reactive_disable_switch(t)
	_test_master_switch_zeroes_all_deltas(t)
	_test_run_restart_resets_state(t)

	# ── FR-009：修饰符 v1 ──
	_test_modifier_contract(t)
	await _test_shield_enemies_applies_and_removes(t)
	await _test_preset_status_tiles_applies_and_removes(t)
	await _test_modifier_disable_rechecked_at_application(t)
	await _test_modifier_stacking_independent(t)
	await _test_draft_and_unknown_modifiers_rejected(t)
	await _test_room_director_applies_modifiers_e2e(t)
	_test_game_world_carries_difficulty_nodes(t)


# ═══ FR-008 MUST：静态层间压力 ═══════════════════════════════════════════════

func _test_scaler_contract(t) -> void:
	var scaler: Node = load(SCALER_PATH).new()
	for method in [
		"get_enemy_count_delta", "get_food_count_delta", "get_enemy_hp_bonus",
		"get_static_enemy_delta", "get_reactive_enemy_delta", "get_reactive_food_delta",
		"get_score", "get_last_room_metrics", "cleanup",
	]:
		t.assert_true(scaler.has_method(method), "[T030] DifficultyScaler exposes %s()" % method)
	scaler.free()


func _test_static_floor_deltas(t) -> void:
	## 静态层 = floor_table[层].enemy_count - baseline_enemy_count / enemy_hp_bonus（FR-008 MUST）
	var scaler: Node = _make_scaler(t)
	if not scaler.has_method("get_static_enemy_delta"):
		t.assert_true(false, "[FR-008] static layer API missing (T030 not implemented)")
		_free_scaler(scaler)
		return

	var cfg: Dictionary = ConfigManager.get_difficulty_config()
	var baseline: int = int(cfg.get("baseline_enemy_count", 0))
	var max_floors: int = ConfigManager.get_max_floors()
	var previous_enemy_delta: int = -999
	var previous_hp_bonus: int = -999
	for floor_index in range(1, max_floors + 1):
		EventBus.floor_generated.emit({"floor_index": floor_index})
		var params: Dictionary = ConfigManager.get_difficulty_floor_params(floor_index)
		var expected_delta: int = int(params.get("enemy_count", 0)) - baseline
		t.assert_eq(scaler.get_static_enemy_delta(), expected_delta,
			"[FR-008] floor %d static enemy delta == floor_table - baseline (%d)" % [floor_index, expected_delta])
		t.assert_eq(scaler.get_enemy_hp_bonus(), int(params.get("enemy_hp_bonus", -1)),
			"[FR-008] floor %d enemy hp bonus from floor_table" % floor_index)
		t.assert_true(scaler.get_static_enemy_delta() > previous_enemy_delta,
			"[SC-006] floor %d static enemy pressure strictly above floor %d" % [floor_index, floor_index - 1])
		t.assert_true(scaler.get_enemy_hp_bonus() > previous_hp_bonus,
			"[SC-006] floor %d hp pressure strictly above floor %d" % [floor_index, floor_index - 1])
		previous_enemy_delta = scaler.get_static_enemy_delta()
		previous_hp_bonus = scaler.get_enemy_hp_bonus()

	t.assert_eq(scaler.get_reactive_enemy_delta(), 0,
		"[FR-008] fresh scaler has zero reactive delta (中性起步，反应层不污染静态断言)")
	EventBus.floor_generated.emit({"floor_index": 2})
	t.assert_eq(scaler.get_enemy_count_delta(), scaler.get_static_enemy_delta(),
		"[FR-008] total enemy delta == static + reactive(0)")
	_free_scaler(scaler)


func _test_enemy_manager_spawn_hp_bonus(t) -> void:
	## RoomDirector 的 HP 静态压力落点：EnemyManager.spawn_hp_bonus（T030 增量改造）
	var field: Dictionary = await _make_field(t)
	var em: Node = field["enemy_manager"]
	if not ("spawn_hp_bonus" in em):
		t.assert_true(false, "[T030] EnemyManager.spawn_hp_bonus missing (not implemented)")
		await _free_field(t, field)
		return

	t.assert_eq(int(em.get("spawn_hp_bonus")), 0, "[T030] default spawn_hp_bonus is 0 (L1/L2 行为保持)")
	var base_hp: int = int(ConfigManager.get_enemy_type("wanderer").get("hp", 0))
	em.set_spawn_weights({"wanderer": 1})
	em.set("spawn_hp_bonus", 2)
	em.init_enemies(2)
	for enemy in em.current_enemies:
		t.assert_eq(enemy.hp, base_hp + 2, "[T030] spawn_enemy applies spawn_hp_bonus on top of config hp")

	var placed: Node = em.spawn_enemy_at("wanderer", Vector2i(3, 3))
	t.assert_eq(placed.hp, base_hp,
		"[T030] spawn_enemy_at stays scripted placement without hp bonus (l1/l2 验收/原子用法不变)")
	await _free_field(t, field)


func _test_director_consumes_static_scaling(t) -> void:
	## 唯一消费者契约：RoomDirector 把静态层落到敌人预算 + spawn_hp_bonus（FR-008 MUST）
	var field: Dictionary = await _make_field(t)
	var director: Node = _make_director(t, field)
	var em: Node = field["enemy_manager"]
	var scaler: Node = _make_scaler(t)
	if not scaler.has_method("get_static_enemy_delta") or not ("spawn_hp_bonus" in em):
		t.assert_true(false, "[FR-008] director consumption needs T030 APIs (not implemented)")
		_free_scaler(scaler)
		director.cleanup()
		director.queue_free()
		await _free_field(t, field)
		return
	director.set_difficulty_scaler(scaler)

	var cfg: Dictionary = ConfigManager.get_difficulty_config()
	var baseline: int = int(cfg.get("baseline_enemy_count", 0))
	var floor2: Dictionary = ConfigManager.get_difficulty_floor_params(2)
	var static_delta: int = int(floor2.get("enemy_count", 0)) - baseline

	EventBus.floor_generated.emit({"floor_index": 2, "theme_id": "", "rooms": []})
	EventBus.room_entered.emit(_combat_room("combat_diff_01", 3))
	t.assert_eq(em.current_enemies.size(), 3 + static_delta,
		"[FR-008] floor 2 combat budget = room enemy_count + static floor delta (%d)" % (3 + static_delta))
	t.assert_eq(int(em.get("spawn_hp_bonus")), int(floor2.get("enemy_hp_bonus", -1)),
		"[FR-008] director feeds floor_table hp bonus into EnemyManager.spawn_hp_bonus")

	EventBus.floor_generated.emit({"floor_index": 1, "theme_id": "", "rooms": []})
	EventBus.room_entered.emit(_combat_room("combat_diff_02", 3))
	t.assert_eq(em.current_enemies.size(), 3,
		"[FR-008] floor 1 static delta is 0 (baseline floor unchanged)")
	t.assert_eq(int(em.get("spawn_hp_bonus")), 0,
		"[FR-008] hp bonus resets to floor 1 value on re-entry (no stale bonus)")

	_free_scaler(scaler)
	director.cleanup()
	director.queue_free()
	await _free_field(t, field)


func _test_director_clamps_from_config(t) -> void:
	## 预算/食物钳制全部出自 difficulty JSON（FR-010：无魔数钳制）
	var field: Dictionary = await _make_field(t)
	var director: Node = _make_director(t, field)
	var em: Node = field["enemy_manager"]
	var fm: Node = field["food_manager"]
	var scaler: Node = _make_scaler(t)
	if not scaler.has_method("get_static_enemy_delta"):
		t.assert_true(false, "[FR-008] clamp checks need T030 APIs (not implemented)")
		_free_scaler(scaler)
		director.cleanup()
		director.queue_free()
		await _free_field(t, field)
		return
	director.set_difficulty_scaler(scaler)
	var saved: Dictionary = _save_difficulty()

	# max_enemy_count 钳上界：楼层 3 静态 delta 把预算推过 cap → 钳回
	ConfigManager.difficulty["max_enemy_count"] = 4
	EventBus.floor_generated.emit({"floor_index": 3, "theme_id": "", "rooms": []})
	EventBus.room_entered.emit(_combat_room("combat_clamp_01", 3))
	t.assert_eq(em.current_enemies.size(), 4,
		"[FR-008] enemy budget clamped to difficulty.max_enemy_count (3 + static > cap)")

	# required_count 永远压过 cap（目标必须可达成，spec 既有边界）
	ConfigManager.difficulty["max_enemy_count"] = 1
	EventBus.room_entered.emit(_combat_room("combat_clamp_02", 3))
	t.assert_eq(em.current_enemies.size(), 3,
		"[FR-008] objective required_count beats the cap (目标必须可达成)")

	# max_food_count 钳食物上界
	_restore_difficulty(saved)
	ConfigManager.difficulty["max_food_count"] = 2
	EventBus.floor_generated.emit({"floor_index": 1, "theme_id": "", "rooms": []})
	EventBus.room_entered.emit(_combat_room("combat_clamp_03", 3))
	t.assert_eq(fm.current_foods.size(), 2,
		"[FR-008] food count clamped to difficulty.max_food_count")

	_restore_difficulty(saved)
	_free_scaler(scaler)
	director.cleanup()
	director.queue_free()
	await _free_field(t, field)


# ═══ FR-008 SHOULD：反应式 DDA（生成参数级断言，无玩家感知措辞） ═══════════════

func _test_per_room_tick_measurement(t) -> void:
	## 草稿 :114 回归：单房用时 = room_entered 起算的 tick 差，不是全局累计 tick
	var scaler: Node = _make_scaler(t)
	if not scaler.has_method("get_last_room_metrics"):
		t.assert_true(false, "[T030] per-room metrics API missing (not implemented)")
		_free_scaler(scaler)
		return
	var saved_tick: int = TickManager.current_tick

	TickManager.current_tick = 500
	EventBus.room_entered.emit({"room_id": "metrics_01", "room_type": "combat"})
	TickManager.current_tick = 512
	EventBus.room_completed.emit({"room_id": "metrics_01"})
	var metrics: Dictionary = scaler.get_last_room_metrics()
	t.assert_eq(int(metrics.get("clear_ticks", -1)), 12,
		"[T030] clear_ticks is the per-room delta (12), not the global tick (512)")

	EventBus.room_entered.emit({"room_id": "metrics_02", "room_type": "combat"})
	TickManager.current_tick = 515
	EventBus.room_completed.emit({"room_id": "metrics_02"})
	t.assert_eq(int(scaler.get_last_room_metrics().get("clear_ticks", -1)), 3,
		"[T030] measurement restarts per room (second room counts its own 3 ticks)")

	TickManager.current_tick = saved_tick
	_free_scaler(scaler)


func _test_hit_and_status_sources(t) -> void:
	## 命中源 = snake_body_attacked + snake_hit_boundary；状态源 = reaction_triggered
	## + status_added_to_carrier(carrier_type=="enemy")（T030 度量事件源契约）
	var scaler: Node = _make_scaler(t)
	if not scaler.has_method("get_last_room_metrics"):
		t.assert_true(false, "[T030] metric source checks need per-room metrics API")
		_free_scaler(scaler)
		return
	var saved_tick: int = TickManager.current_tick

	EventBus.room_entered.emit({"room_id": "sources_01", "room_type": "combat"})
	EventBus.snake_body_attacked.emit({})
	EventBus.snake_body_attacked.emit({})
	EventBus.snake_hit_boundary.emit({})
	EventBus.reaction_triggered.emit({})
	EventBus.reaction_triggered.emit({})
	EventBus.status_added_to_carrier.emit({"carrier_type": "enemy", "type": "fire"})
	EventBus.status_added_to_carrier.emit({"carrier_type": "snake_segment", "type": "fire"})
	EventBus.room_completed.emit({"room_id": "sources_01"})

	var metrics: Dictionary = scaler.get_last_room_metrics()
	t.assert_eq(int(metrics.get("hits_taken", -1)), 3,
		"[T030] hits = body attacks (2) + boundary hits (1)")
	t.assert_eq(int(metrics.get("status_usage", -1)), 3,
		"[T030] status usage = reactions (2) + enemy carrier statuses (1); snake carrier excluded")

	EventBus.room_entered.emit({"room_id": "sources_02", "room_type": "combat"})
	EventBus.room_completed.emit({"room_id": "sources_02"})
	metrics = scaler.get_last_room_metrics()
	t.assert_eq(int(metrics.get("hits_taken", -1)), 0, "[T030] hit counter resets per room")
	t.assert_eq(int(metrics.get("status_usage", -1)), 0, "[T030] status counter resets per room")

	TickManager.current_tick = saved_tick
	_free_scaler(scaler)


func _test_reactive_overperform_shifts_params(t) -> void:
	## 模拟生成参数应上调的表现窗口（秒清/零受击/状态满额）→ delta 上调（SHOULD）
	var scaler: Node = _make_scaler(t)
	if not scaler.has_method("get_reactive_enemy_delta"):
		t.assert_true(false, "[FR-008] reactive API missing (T030 not implemented)")
		_free_scaler(scaler)
		return
	_adjusted_events.clear()
	EventBus.difficulty_adjusted.connect(_on_difficulty_adjusted)
	var saved_tick: int = TickManager.current_tick

	_drive_perfect_window(scaler)

	var cfg: Dictionary = ConfigManager.get_difficulty_config()
	t.assert_eq(scaler.get_reactive_enemy_delta(), int(cfg.get("adjustment_enemy_delta", 0)),
		"[FR-008] overperformance window raises the enemy generation delta")
	t.assert_eq(scaler.get_reactive_food_delta(), -int(cfg.get("adjustment_food_delta", 0)),
		"[FR-008] overperformance window lowers the food generation delta")
	t.assert_eq(scaler.get_enemy_count_delta(), scaler.get_static_enemy_delta() + scaler.get_reactive_enemy_delta(),
		"[FR-008] total delta = static + reactive")
	t.assert_true(_adjusted_events.size() >= 1,
		"[FR-008] difficulty_adjusted emitted after the adjustment window")
	if _adjusted_events.size() > 0:
		var adjustment: Dictionary = _adjusted_events[0].get("adjustment", {})
		t.assert_true(adjustment.has("score"), "[FR-008] difficulty_adjusted carries the score")
		t.assert_true(adjustment.has("enemy_delta"), "[FR-008] difficulty_adjusted carries enemy_delta")

	EventBus.difficulty_adjusted.disconnect(_on_difficulty_adjusted)
	TickManager.current_tick = saved_tick
	_free_scaler(scaler)


func _test_reactive_underperform_shifts_params(t) -> void:
	## 模拟生成参数应下调的表现窗口（满时长/满受击/零状态）→ delta 下调（SHOULD）
	var scaler: Node = _make_scaler(t)
	if not scaler.has_method("get_reactive_enemy_delta"):
		t.assert_true(false, "[FR-008] reactive API missing (T030 not implemented)")
		_free_scaler(scaler)
		return
	var saved_tick: int = TickManager.current_tick

	_drive_weak_window(scaler)

	var cfg: Dictionary = ConfigManager.get_difficulty_config()
	t.assert_eq(scaler.get_reactive_enemy_delta(), -int(cfg.get("adjustment_enemy_delta", 0)),
		"[FR-008] underperformance window lowers the enemy generation delta")
	t.assert_eq(scaler.get_reactive_food_delta(), int(cfg.get("adjustment_food_delta", 0)),
		"[FR-008] underperformance window raises the food generation delta")

	TickManager.current_tick = saved_tick
	_free_scaler(scaler)


func _test_reactive_clamped_from_json(t) -> void:
	## clamp 边界出自 reactive.clamp（FR-008/SC-006：调整幅度永不越界）
	var scaler: Node = _make_scaler(t)
	if not scaler.has_method("get_reactive_enemy_delta"):
		t.assert_true(false, "[FR-008] clamp checks need reactive API")
		_free_scaler(scaler)
		return
	var saved: Dictionary = _save_difficulty()
	var saved_tick: int = TickManager.current_tick
	ConfigManager.difficulty["adjustment_enemy_delta"] = 5
	ConfigManager.difficulty["adjustment_food_delta"] = 7

	_drive_perfect_window(scaler)

	var clamp_cfg: Dictionary = ConfigManager.get_difficulty_reactive_config().get("clamp", {})
	t.assert_eq(scaler.get_reactive_enemy_delta(), int(clamp_cfg.get("enemy_delta_max", 0)),
		"[FR-008] oversized enemy adjustment clamped to reactive.clamp.enemy_delta_max")
	t.assert_eq(scaler.get_reactive_food_delta(), int(clamp_cfg.get("food_delta_min", 0)),
		"[FR-008] oversized food adjustment clamped to reactive.clamp.food_delta_min")

	_restore_difficulty(saved)
	TickManager.current_tick = saved_tick
	_free_scaler(scaler)


func _test_normalization_denominators_from_json(t) -> void:
	## 草稿 :93 回归：归一化分母来自 reactive.normalization，不是硬编码
	var saved: Dictionary = _save_difficulty()
	var saved_tick: int = TickManager.current_tick

	# 同样的 100-tick 清房表现：分母 1000 → 高分上调；分母 100 → 中性不调
	var reactive: Dictionary = ConfigManager.difficulty.get("reactive", {})
	var normalization: Dictionary = reactive.get("normalization", {})
	normalization["room_clear_ticks"] = 1000
	var scaler: Node = _make_scaler(t)
	if not scaler.has_method("get_reactive_enemy_delta"):
		t.assert_true(false, "[FR-008] denominator checks need reactive API")
		_restore_difficulty(saved)
		_free_scaler(scaler)
		return
	_drive_window(scaler, 100, 0, 99)
	t.assert_true(scaler.get_reactive_enemy_delta() > 0,
		"[FR-008] generous tick denominator (1000) -> same play scores an upward shift")
	_free_scaler(scaler)

	normalization["room_clear_ticks"] = 100
	var second: Node = _make_scaler(t)
	_drive_window(second, 100, 0, 99)
	t.assert_eq(second.get_reactive_enemy_delta(), 0,
		"[FR-008] tight tick denominator (100) -> same play stays neutral (分母 JSON 驱动)")
	_free_scaler(second)

	_restore_difficulty(saved)
	TickManager.current_tick = saved_tick


func _test_reactive_disable_switch(t) -> void:
	## reactive.enabled = false → 反应层归零、静态层保留（SHOULD 可砍——砍单阶梯首位）
	var saved: Dictionary = _save_difficulty()
	var saved_tick: int = TickManager.current_tick
	ConfigManager.difficulty.get("reactive", {})["enabled"] = false

	var scaler: Node = _make_scaler(t)
	if not scaler.has_method("get_reactive_enemy_delta"):
		t.assert_true(false, "[FR-008] disable switch checks need reactive API")
		_restore_difficulty(saved)
		_free_scaler(scaler)
		return
	_drive_perfect_window(scaler)
	EventBus.floor_generated.emit({"floor_index": 2})

	t.assert_eq(scaler.get_reactive_enemy_delta(), 0,
		"[FR-008] reactive.enabled=false zeroes the reactive layer")
	t.assert_eq(scaler.get_reactive_food_delta(), 0,
		"[FR-008] reactive.enabled=false zeroes the food reactive layer")
	t.assert_eq(scaler.get_enemy_count_delta(), scaler.get_static_enemy_delta(),
		"[FR-008] static MUST layer survives the reactive cut (静态层独立于砍单开关)")

	_restore_difficulty(saved)
	TickManager.current_tick = saved_tick
	_free_scaler(scaler)


func _test_master_switch_zeroes_all_deltas(t) -> void:
	## difficulty.enabled = false → 全部生成参数修正归零（调试总开关）
	var saved: Dictionary = _save_difficulty()
	var saved_tick: int = TickManager.current_tick
	var scaler: Node = _make_scaler(t)
	if not scaler.has_method("get_reactive_enemy_delta"):
		t.assert_true(false, "[FR-008] master switch checks need T030 API")
		_restore_difficulty(saved)
		_free_scaler(scaler)
		return
	_drive_perfect_window(scaler)
	EventBus.floor_generated.emit({"floor_index": 2})
	ConfigManager.difficulty["enabled"] = false

	t.assert_eq(scaler.get_enemy_count_delta(), 0, "[FR-008] master off -> enemy delta 0")
	t.assert_eq(scaler.get_food_count_delta(), 0, "[FR-008] master off -> food delta 0")
	t.assert_eq(scaler.get_enemy_hp_bonus(), 0, "[FR-008] master off -> hp bonus 0")

	_restore_difficulty(saved)
	TickManager.current_tick = saved_tick
	_free_scaler(scaler)


func _test_run_restart_resets_state(t) -> void:
	## FR-013：run 重启清空难度状态（分数回中性、度量窗口清空）
	var scaler: Node = _make_scaler(t)
	if not scaler.has_method("get_reactive_enemy_delta"):
		t.assert_true(false, "[FR-013] reset checks need T030 API")
		_free_scaler(scaler)
		return
	var saved_tick: int = TickManager.current_tick
	_drive_perfect_window(scaler)
	t.assert_true(scaler.get_reactive_enemy_delta() != 0, "[FR-013] precondition: reactive delta active")

	EventBus.run_started.emit({"run_id": "reset_run", "floor_index": 1})
	t.assert_eq(scaler.get_reactive_enemy_delta(), 0, "[FR-013] run restart zeroes the reactive delta")
	t.assert_eq(scaler.get_last_room_metrics(), {}, "[FR-013] run restart clears per-room metrics")
	EventBus.floor_generated.emit({"floor_index": 1})
	t.assert_eq(scaler.get_enemy_count_delta(), 0, "[FR-013] run restart returns to floor-1 neutral deltas")

	TickManager.current_tick = saved_tick
	_free_scaler(scaler)


# ═══ FR-009：修饰符 v1（shield_enemies / preset_status_tiles） ═══════════════

func _test_modifier_contract(t) -> void:
	var system: Node = load(MODIFIER_PATH).new()
	for method in ["setup", "apply_modifiers", "apply_modifier", "remove_modifiers", "get_active_modifiers", "has_modifier", "cleanup"]:
		t.assert_true(system.has_method(method), "[T031] RoomModifierSystem exposes %s()" % method)
	system.free()


func _test_shield_enemies_applies_and_removes(t) -> void:
	var field: Dictionary = await _make_field(t)
	var em: Node = field["enemy_manager"]
	var system: Node = _make_modifier_system(t, field, null)
	if system == null:
		await _free_field(t, field)
		return
	_modifier_events.clear()
	EventBus.room_modifier_applied.connect(_on_modifier_applied)

	var params: Dictionary = ConfigManager.get_room_modifier("shield_enemies").get("params", {})
	var hp_bonus: int = int(params.get("hp_bonus", 0))
	var max_shielded: int = int(params.get("max_shielded", 0))
	t.assert_true(hp_bonus >= 1, "[FR-009] shield_enemies hp_bonus >= 1 in JSON")
	t.assert_true(max_shielded >= 1, "[FR-009] shield_enemies max_shielded >= 1 in JSON")

	var base_hp: int = int(ConfigManager.get_enemy_type("wanderer").get("hp", 0))
	em.set_spawn_weights({"wanderer": 1})
	em.set("respawn_policy", "room_budget")
	em.init_enemies(3)
	system.apply_modifiers({"room_id": "mod_shield_01", "modifiers": ["shield_enemies"]})

	t.assert_true(system.has_modifier("mod_shield_01", "shield_enemies"),
		"[FR-009] shield_enemies tracked as active for the room")
	t.assert_eq(_modifier_events.size(), 1, "[FR-009] room_modifier_applied emitted once")
	if _modifier_events.size() > 0:
		t.assert_eq(str(_modifier_events[0].get("modifier_id", "")), "shield_enemies",
			"[FR-009] applied event carries the modifier id")

	var shielded: Array = []
	for enemy in em.current_enemies:
		if enemy.has_meta("room_modifier_shield"):
			shielded.append(enemy)
			t.assert_eq(enemy.hp, base_hp + hp_bonus,
				"[US6-3] shielded enemy carries the +%d hp shield" % hp_bonus)
			t.assert_true(enemy.get_node_or_null("ShieldOutline") != null,
				"[US6-3] shielded enemy carries a visible shield outline (readable)")
	t.assert_eq(shielded.size(), mini(max_shielded, 3),
		"[FR-009] exactly max_shielded enemies shielded")
	var unshielded_intact: bool = true
	for enemy in em.current_enemies:
		if not enemy.has_meta("room_modifier_shield") and enemy.hp != base_hp:
			unshielded_intact = false
	t.assert_true(unshielded_intact, "[FR-009] unshielded enemies keep base hp")

	EventBus.room_completed.emit({"room_id": "mod_shield_01"})
	await t.get_tree().process_frame
	t.assert_false(system.has_modifier("mod_shield_01", "shield_enemies"),
		"[FR-009] shield modifier removed on room completion")
	for enemy in em.current_enemies:
		t.assert_false(enemy.has_meta("room_modifier_shield"),
			"[FR-009] shield meta reverted on surviving enemies")
		t.assert_eq(enemy.hp, base_hp, "[FR-009] shield hp reverted on surviving enemies")
		t.assert_true(enemy.get_node_or_null("ShieldOutline") == null,
			"[FR-009] shield outline removed with the modifier")

	EventBus.room_modifier_applied.disconnect(_on_modifier_applied)
	system.cleanup()
	system.queue_free()
	await _free_field(t, field)


func _test_preset_status_tiles_applies_and_removes(t) -> void:
	var field: Dictionary = await _make_field(t)
	var tile_mgr: Node = field["tile_manager"]
	var snake_stub := SnakeStub.new()
	snake_stub.body = [Vector2i(20, 11)]
	var system: Node = _make_modifier_system(t, field, snake_stub)
	if system == null:
		await _free_field(t, field)
		return

	var params: Dictionary = ConfigManager.get_room_modifier("preset_status_tiles").get("params", {})
	var tile_count: int = int(params.get("tile_count", 0))
	var tile_types: Array = params.get("tile_types", [])
	var min_distance: int = int(params.get("min_distance_from_snake", 0))
	t.assert_true(tile_count >= 1, "[FR-009] preset_status_tiles tile_count >= 1 in JSON")
	t.assert_true(tile_types.size() >= 1, "[FR-009] preset_status_tiles tile_types non-empty in JSON")
	t.assert_true(min_distance >= 1, "[FR-009] preset_status_tiles keeps distance from the snake in JSON")

	_tile_placed_events.clear()
	EventBus.status_tile_placed.connect(_on_tile_placed)
	system.apply_modifiers({"room_id": "mod_tiles_01", "modifiers": ["preset_status_tiles"]})

	t.assert_eq(tile_mgr.get_tile_count(), tile_count,
		"[US6-3] preset tiles placed on room application (状态格视觉复用，可见可读)")
	t.assert_eq(_tile_placed_events.size(), tile_count,
		"[FR-009] each preset tile goes through StatusTileManager (status_tile_placed)")
	for event in _tile_placed_events:
		t.assert_true(tile_types.has(str(event.get("type", ""))),
			"[FR-009] preset tile type drawn from configured tile_types")
		var pos: Vector2i = event.get("position", Vector2i.ZERO)
		var dist: int = absi(pos.x - snake_stub.body[0].x) + absi(pos.y - snake_stub.body[0].y)
		t.assert_true(dist >= min_distance,
			"[FR-009] preset tile keeps min_distance_from_snake (%d >= %d)" % [dist, min_distance])

	# 外部状态格不被修饰符移除误伤
	var foreign_pos: Vector2i = _find_free_cell(_tile_placed_events)
	tile_mgr.place_tile(foreign_pos, "poison")
	EventBus.room_completed.emit({"room_id": "mod_tiles_01"})
	t.assert_eq(tile_mgr.get_tile_count(), 1,
		"[FR-009] room completion removes ONLY the preset tiles (外部格存活)")
	t.assert_true(tile_mgr.has_tile(foreign_pos, "poison"),
		"[FR-009] foreign tile untouched by modifier removal")
	t.assert_false(system.has_modifier("mod_tiles_01", "preset_status_tiles"),
		"[FR-009] preset modifier removed on room completion")

	EventBus.status_tile_placed.disconnect(_on_tile_placed)
	system.cleanup()
	system.queue_free()
	await _free_field(t, field)


func _test_modifier_disable_rechecked_at_application(t) -> void:
	## FR-009：应用层复核逐项 enabled（生成层过滤之外的纵深防御）
	var field: Dictionary = await _make_field(t)
	var em: Node = field["enemy_manager"]
	var system: Node = _make_modifier_system(t, field, null)
	if system == null:
		await _free_field(t, field)
		return
	var saved_modifiers: Dictionary = ConfigManager.room_modifiers.duplicate(true)
	ConfigManager.room_modifiers.get("shield_enemies", {})["enabled"] = false

	em.set("respawn_policy", "room_budget")
	em.init_enemies(2)
	t.assert_false(system.apply_modifier("shield_enemies", "mod_disabled_01"),
		"[FR-009] disabled modifier refused at application time")
	t.assert_eq(system.get_active_modifiers().size(), 0, "[FR-009] nothing tracked for a refused modifier")
	for enemy in em.current_enemies:
		t.assert_false(enemy.has_meta("room_modifier_shield"), "[FR-009] no shield applied while disabled")

	ConfigManager.room_modifiers.clear()
	ConfigManager.room_modifiers.merge(saved_modifiers)
	system.cleanup()
	system.queue_free()
	await _free_field(t, field)


func _test_modifier_stacking_independent(t) -> void:
	## spec edge case：双修饰叠加，反馈各自独立可读，移除互不串扰
	var field: Dictionary = await _make_field(t)
	var em: Node = field["enemy_manager"]
	var tile_mgr: Node = field["tile_manager"]
	var system: Node = _make_modifier_system(t, field, null)
	if system == null:
		await _free_field(t, field)
		return

	em.set_spawn_weights({"wanderer": 1})
	em.set("respawn_policy", "room_budget")
	em.init_enemies(3)
	system.apply_modifiers({"room_id": "mod_stack_01", "modifiers": ["shield_enemies", "preset_status_tiles"]})

	t.assert_eq(system.get_active_modifiers().size(), 2, "[FR-009] both v1 modifiers stack in one room")
	var shielded_count: int = 0
	for enemy in em.current_enemies:
		if enemy.has_meta("room_modifier_shield"):
			shielded_count += 1
	t.assert_true(shielded_count > 0, "[FR-009] shield feedback present under stacking")
	t.assert_true(tile_mgr.get_tile_count() > 0, "[FR-009] tile feedback present under stacking")

	EventBus.room_completed.emit({"room_id": "mod_stack_01"})
	await t.get_tree().process_frame
	t.assert_eq(system.get_active_modifiers().size(), 0, "[FR-009] stacked modifiers both removed on completion")
	t.assert_eq(tile_mgr.get_tile_count(), 0, "[FR-009] preset tiles cleared with the stack")

	system.cleanup()
	system.queue_free()
	await _free_field(t, field)


func _test_draft_and_unknown_modifiers_rejected(t) -> void:
	## backlog 收容（darkness/speed_strips/mine_tiles 已出 JSON）+ 未知 id 防御
	var field: Dictionary = await _make_field(t)
	var system: Node = _make_modifier_system(t, field, null)
	if system == null:
		await _free_field(t, field)
		return
	for draft_id in ["darkness", "speed_strips", "mine_tiles", "nonexistent"]:
		t.assert_false(system.apply_modifier(draft_id, "mod_reject_01"),
			"[FR-009] draft/unknown modifier rejected: %s" % draft_id)
	t.assert_eq(system.get_active_modifiers().size(), 0, "[FR-009] rejections leave no active state")
	system.cleanup()
	system.queue_free()
	await _free_field(t, field)


func _test_room_director_applies_modifiers_e2e(t) -> void:
	## T031：经 RoomDirector 注入点实际应用（先布场后修饰——草稿「从不被应用」回归）
	var field: Dictionary = await _make_field(t)
	var em: Node = field["enemy_manager"]
	var director: Node = _make_director(t, field)
	var system: Node = _make_modifier_system(t, field, null)
	if system == null:
		director.cleanup()
		director.queue_free()
		await _free_field(t, field)
		return
	director.set_modifier_system(system)

	EventBus.floor_generated.emit({"floor_index": 2, "theme_id": "", "rooms": []})
	var room: Dictionary = _combat_room("combat_mod_e2e", 3)
	room["modifiers"] = ["shield_enemies"]
	EventBus.room_entered.emit(room)

	var shielded_count: int = 0
	for enemy in em.current_enemies:
		if enemy.has_meta("room_modifier_shield"):
			shielded_count += 1
	t.assert_true(shielded_count > 0,
		"[T031] room entry through RoomDirector applies modifiers to the populated field")
	t.assert_true(system.has_modifier("combat_mod_e2e", "shield_enemies"),
		"[T031] modifier tracked for the directed room")

	director.cleanup()
	director.queue_free()
	system.cleanup()
	system.queue_free()
	await _free_field(t, field)


func _test_game_world_carries_difficulty_nodes(t) -> void:
	## T030/T031 game_world 接线：场景常驻 DifficultyScaler + RoomModifierSystem 节点
	var scene = load(GAME_WORLD_SCENE_PATH) as PackedScene
	var world: Node = scene.instantiate()
	t.assert_true(world.has_node("DifficultyScaler"),
		"[T030] game_world scene carries a DifficultyScaler node (唯一消费者接线)")
	t.assert_true(world.has_node("RoomModifierSystem"),
		"[T031] game_world scene carries a RoomModifierSystem node")
	world.free()


# ═══ Helpers ═════════════════════════════════════════════════════════════════

func _make_scaler(t) -> Node:
	var scaler: Node = load(SCALER_PATH).new()
	t.add_child(scaler)
	return scaler


func _free_scaler(scaler: Node) -> void:
	if scaler.has_method("cleanup"):
		scaler.cleanup()
	scaler.queue_free()


func _make_field(t) -> Dictionary:
	GridWorld.init_grid(Constants.GRID_WIDTH, Constants.GRID_HEIGHT)
	var enemy_container := Node2D.new()
	enemy_container.name = "DiffTestEnemyContainer"
	t.add_child(enemy_container)
	var food_container := Node2D.new()
	food_container.name = "DiffTestFoodContainer"
	t.add_child(food_container)

	var em: Node = load(ENEMY_MANAGER_PATH).new()
	em.enemy_container = enemy_container
	t.add_child(em)

	var fm: Node = load(FOOD_MANAGER_PATH).new()
	fm.food_container = food_container
	t.add_child(fm)

	var tile_mgr: Node = load(TILE_MANAGER_PATH).new()
	tile_mgr.name = "DiffTestTileManager"
	t.add_child(tile_mgr)

	return {
		"enemy_manager": em,
		"food_manager": fm,
		"tile_manager": tile_mgr,
		"enemy_container": enemy_container,
		"food_container": food_container,
	}


func _free_field(t, field: Dictionary) -> void:
	field["enemy_manager"].clear_enemies()
	field["food_manager"].clear_foods()
	field["tile_manager"].clear_all()
	field["enemy_manager"].queue_free()
	field["food_manager"].queue_free()
	field["tile_manager"].queue_free()
	field["enemy_container"].queue_free()
	field["food_container"].queue_free()
	GridWorld.clear_all()
	# 等 queue_free 落地，断开 EnemyManager 的 EventBus 监听（maintain 档防串扰）
	await t.get_tree().process_frame
	await t.get_tree().process_frame


func _make_director(t, field: Dictionary) -> Node:
	var director: Node = load(DIRECTOR_PATH).new()
	director.name = "DiffTestDirector"
	t.add_child(director)
	director.setup(field["enemy_manager"], field["food_manager"])
	return director


func _make_modifier_system(t, field: Dictionary, snake: Object) -> Node:
	var system: Node = load(MODIFIER_PATH).new()
	if not system.has_method("setup") or not system.has_method("apply_modifiers"):
		t.assert_true(false, "[T031] RoomModifierSystem v2 API missing (not implemented)")
		system.free()
		return null
	t.add_child(system)
	system.setup(field["enemy_manager"], field["tile_manager"], snake)
	return system


func _combat_room(room_id: String, enemy_count: int) -> Dictionary:
	return {
		"room_id": room_id,
		"room_type": "combat",
		"objective": {"objective_type": "clear_enemies", "required_count": 3, "current_count": 0},
		"enemy_count": enemy_count,
		"modifiers": [],
	}


## 驱动一个调整窗口：每房 clear_ticks/hits/status_usage 相同（生成参数级模拟）
func _drive_window(scaler: Node, clear_ticks: int, hits: int, status_usage: int) -> void:
	var rooms_between: int = int(ConfigManager.get_difficulty_config().get("rooms_between_adjustments", 2))
	for index in range(rooms_between):
		var room_id: String = "window_%d_%d" % [scaler.get_instance_id(), index]
		EventBus.room_entered.emit({"room_id": room_id, "room_type": "combat"})
		for _i in range(hits):
			EventBus.snake_body_attacked.emit({})
		for _i in range(status_usage):
			EventBus.reaction_triggered.emit({})
		TickManager.current_tick += clear_ticks
		EventBus.room_completed.emit({"room_id": room_id})


func _drive_perfect_window(scaler: Node) -> void:
	## 秒清/零受击/状态满额 → 分数顶到 1.0
	var normalization: Dictionary = ConfigManager.get_difficulty_reactive_config().get("normalization", {})
	_drive_window(scaler, 0, 0, int(normalization.get("status_usage_per_room", 5)))


func _drive_weak_window(scaler: Node) -> void:
	## 满时长/满受击/零状态 → 分数压到 0.0
	var normalization: Dictionary = ConfigManager.get_difficulty_reactive_config().get("normalization", {})
	_drive_window(
		scaler,
		int(normalization.get("room_clear_ticks", 120)),
		int(normalization.get("damage_taken_per_room", 3)),
		0
	)


func _find_free_cell(placed_events: Array) -> Vector2i:
	var taken: Dictionary = {}
	for event in placed_events:
		taken[event.get("position", Vector2i.ZERO)] = true
	for x in range(Constants.GRID_WIDTH):
		for y in range(Constants.GRID_HEIGHT):
			var pos := Vector2i(x, y)
			if not taken.has(pos) and GridWorld.get_entities_at(pos).is_empty():
				return pos
	return Vector2i.ZERO


func _save_difficulty() -> Dictionary:
	return ConfigManager.difficulty.duplicate(true)


func _restore_difficulty(saved: Dictionary) -> void:
	ConfigManager.difficulty.clear()
	ConfigManager.difficulty.merge(saved)


func _on_difficulty_adjusted(data: Dictionary) -> void:
	_adjusted_events.append(data)


func _on_modifier_applied(data: Dictionary) -> void:
	_modifier_events.append(data)


func _on_tile_placed(data: Dictionary) -> void:
	_tile_placed_events.append(data)
