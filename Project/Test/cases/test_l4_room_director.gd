extends RefCounted
## L4 T5a 重验收测试（spec 002 T020/T021/T022，2026-06-11 修订版 spec 对照）：
## - T020 EnemyManager 增量改造（RoomDirector 前置契约）：respawn_policy 默认 "maintain"
##   保 L1/L2「击杀即补怪」行为；"room_budget" 档生成既定一批、不自动补怪；
##   注入式权重表（floor_themes.enemy_pool_weights）+ spawn_budget；
## - T021 RoomDirector：监听 room_entered/floor_generated → 清场 → 按房型 + 主题权重 +
##   难度修正（duck-typed scaler 钩子，T6 前恒 0）布怪布食；精英房出 elite_* 变体；
##   boss 房按 is_boss 走精英池（spec 边界：boss 未配置 → 精英回退）；
##   floor_theme_set 由 RoomDirector 发射（生成器保持纯函数）；修饰符注入点（T031 消费）；
## - T022 多层切换：RunProgressionSystem 消费 run.max_floors；pcg 档 boss 完成 →
##   （楼层奖励决议先于推进，T027 groundwork）→ 延迟 advance_floor()（击杀级联重入防护）→
##   floor_generated → 进起点房；终层 → 胜利路径；fixed_v1 档保持单层 MDE 闭环（终点即胜利）；
##   game_world.reset_for_floor() 组合既有清场原语，蛇重建保长度、管理器存续。

const ENEMY_MANAGER_PATH: String = "res://systems/enemy/enemy_manager.gd"
const ROOM_DIRECTOR_PATH: String = "res://systems/rooms/room_director.gd"
const RUN_PROGRESSION_PATH: String = "res://systems/run/run_progression_system.gd"
const FLOOR_MAP_GENERATOR_PATH: String = "res://systems/rooms/floor_map_generator.gd"

var _floor_generated_events: Array = []
var _room_entered_events: Array = []
var _floor_completed_events: Array = []
var _victory_events: Array = []
var _theme_events: Array = []


class ScalerStub:
	extends RefCounted
	## T6 前的 duck-typed 难度修正桩（RoomDirector 唯一消费者契约的接口形状）
	var enemy_delta: int = 0
	var food_delta: int = 0

	func get_enemy_count_delta() -> int:
		return enemy_delta

	func get_food_count_delta() -> int:
		return food_delta


class ModifierHookStub:
	extends RefCounted
	## T031 修饰符注入点桩：记录 RoomDirector 转交的房间 dict
	var applied_rooms: Array = []

	func apply_modifiers(room: Dictionary) -> void:
		applied_rooms.append(room.duplicate(true))


func run(t) -> void:
	t.assert_file_exists(ENEMY_MANAGER_PATH)
	_test_enemy_manager_policy_contract(t)
	await _test_enemy_manager_maintain_respawns(t)
	await _test_enemy_manager_room_budget(t)
	await _test_enemy_manager_injected_weights(t)

	t.assert_file_exists(ROOM_DIRECTOR_PATH)
	if FileAccess.file_exists(ROOM_DIRECTOR_PATH):
		await _test_room_director_population_by_room_type(t)
		await _test_room_director_theme_and_elite(t)
		await _test_room_director_difficulty_hook(t)
		await _test_room_director_theme_signal_and_modifier_hook(t)

	await _test_run_progression_multifloor(t)
	await _test_floor_reward_gates_advance(t)
	await _test_fixed_v1_endpoint_victory_preserved(t)
	await _test_game_world_reset_for_floor(t)


# ── T020: respawn_policy / spawn_budget / 注入权重表 ────────────────────────

func _test_enemy_manager_policy_contract(t) -> void:
	var em: Node = load(ENEMY_MANAGER_PATH).new()
	t.assert_true("respawn_policy" in em, "[T020] EnemyManager exposes respawn_policy")
	t.assert_true("spawn_budget" in em, "[T020] EnemyManager exposes spawn_budget")
	t.assert_true(em.has_method("set_spawn_weights"), "[T020] EnemyManager has set_spawn_weights()")
	if "respawn_policy" in em:
		t.assert_eq(str(em.get("respawn_policy")), "maintain",
			"[T020] default respawn_policy is maintain (L1/L2 行为保持)")
	if "spawn_budget" in em:
		t.assert_eq(int(em.get("spawn_budget")), -1,
			"[T020] default spawn_budget is -1 (不限，maintain 档语义)")
	em.free()


func _test_enemy_manager_maintain_respawns(t) -> void:
	var field: Dictionary = _make_field(t)
	var em: Node = field["enemy_manager"]
	em.init_enemies(3)
	t.assert_eq(em.current_enemies.size(), 3, "[T020] maintain: init_enemies(3) spawns 3")

	var victim: Node = em.current_enemies[0]
	victim.take_damage(victim.hp)
	t.assert_eq(em.current_enemies.size(), 3,
		"[T020] maintain: kill -> instant respawn keeps max_enemy_count (既有行为回归)")

	await _free_field(t, field)


func _test_enemy_manager_room_budget(t) -> void:
	if not _has_policy_api():
		t.assert_true(false, "[T020] room_budget mode needs respawn_policy/spawn_budget (not implemented)")
		return
	var field: Dictionary = _make_field(t)
	var em: Node = field["enemy_manager"]
	em.set("respawn_policy", "room_budget")
	em.set("spawn_budget", 2)
	em.init_enemies(2)
	t.assert_eq(em.current_enemies.size(), 2, "[T020] room_budget: defined set of 2 spawned")
	t.assert_eq(int(em.get("spawn_budget")), 0, "[T020] room_budget: budget consumed by spawns")

	var victim: Node = em.current_enemies[0]
	victim.take_damage(victim.hp)
	t.assert_eq(em.current_enemies.size(), 1,
		"[T020] room_budget: kill does NOT auto-respawn (no maintain)")

	em.spawn_enemy("wanderer")
	t.assert_eq(em.current_enemies.size(), 1,
		"[T020] room_budget: spawn_enemy refused at budget 0")

	em.set("spawn_budget", 1)
	em.spawn_enemy("wanderer")
	t.assert_eq(em.current_enemies.size(), 2, "[T020] room_budget: spawn allowed while budget remains")
	t.assert_eq(int(em.get("spawn_budget")), 0, "[T020] room_budget: spawn consumes budget")

	var placed: Node = em.spawn_enemy_at("wanderer", Vector2i(3, 3))
	t.assert_true(placed != null and em.current_enemies.size() == 3,
		"[T020] spawn_enemy_at is scripted placement and bypasses budget (l1/l2 验收场景用法)")

	await _free_field(t, field)


func _test_enemy_manager_injected_weights(t) -> void:
	if not _has_policy_api():
		t.assert_true(false, "[T020] injected weight table needs set_spawn_weights (not implemented)")
		return
	var field: Dictionary = _make_field(t)
	var em: Node = field["enemy_manager"]

	em.set_spawn_weights({"chaser": 7})
	em.init_enemies(5)
	var types: Dictionary = _spawned_type_set(em)
	t.assert_eq(types.keys(), ["chaser"],
		"[T020] injected weight table drives every random pick (got %s)" % [types.keys()])

	em.clear_enemies()
	em.set_spawn_weights({})
	em.init_enemies(5)
	var config_keys: Array = ConfigManager.enemy.get("spawn_weights", {}).keys()
	var fallback_violations: Array = []
	for type_id in _spawned_type_set(em):
		if not config_keys.has(type_id):
			fallback_violations.append(type_id)
	t.assert_eq(fallback_violations, [],
		"[T020] empty injected table falls back to enemy.spawn_weights config")

	await _free_field(t, field)


# ── T021: RoomDirector 清场 + 按房型/主题/难度布怪布食 ──────────────────────

func _test_room_director_population_by_room_type(t) -> void:
	var field: Dictionary = _make_field(t)
	var director: Node = _make_director(t, field)
	var em: Node = field["enemy_manager"]
	var fm: Node = field["food_manager"]

	EventBus.floor_generated.emit({"floor_index": 1, "theme_id": "", "rooms": []})
	EventBus.room_entered.emit(_combat_room("combat_rd_01", 3))
	t.assert_eq(em.current_enemies.size(), 3,
		"[T021] combat room populated with enemy_count enemies")
	t.assert_eq(str(em.get("respawn_policy")), "room_budget",
		"[T021] director switches manager to room_budget (清完即清，不补怪)")
	var floor1_food: int = int(ConfigManager.get_difficulty_floor_params(1).get("food_count", 3))
	t.assert_eq(fm.current_foods.size(), floor1_food,
		"[T021] room food re-laid from difficulty floor table (floor 1)")

	var victim: Node = em.current_enemies[0]
	victim.take_damage(victim.hp)
	t.assert_eq(em.current_enemies.size(), 2,
		"[T021] kills inside a directed room do not respawn (clear_enemies 目标可达成)")

	EventBus.room_entered.emit({
		"room_id": "reward_rd_01",
		"room_type": "reward",
		"objective": {"objective_type": "claim_reward", "required_count": 1},
		"modifiers": [],
	})
	t.assert_eq(em.current_enemies.size(), 0,
		"[T021] non-combat room entry clears the field (reward room has no enemies)")
	t.assert_eq(fm.current_foods.size(), floor1_food,
		"[T021] food still re-laid for non-combat rooms")

	director.cleanup()
	director.queue_free()
	await _free_field(t, field)


func _test_room_director_theme_and_elite(t) -> void:
	var field: Dictionary = _make_field(t)
	var director: Node = _make_director(t, field)
	var em: Node = field["enemy_manager"]
	var saved_themes: Dictionary = ConfigManager.floor_themes.duplicate(true)
	if ConfigManager.floor_themes.has("marsh"):
		ConfigManager.floor_themes["marsh"]["enemy_pool_weights"] = {"chaser": 7}

	EventBus.floor_generated.emit({"floor_index": 2, "theme_id": "marsh", "rooms": []})
	EventBus.room_entered.emit(_combat_room("combat_rd_02", 3))
	t.assert_eq(_spawned_type_set(em).keys(), ["chaser"],
		"[T021] combat spawns draw from the floor theme enemy pool (injected weights)")

	EventBus.room_entered.emit({
		"room_id": "elite_rd_01",
		"room_type": "elite",
		"objective": {"objective_type": "clear_enemies", "required_count": 2},
		"enemy_count": 2,
		"modifiers": [],
	})
	t.assert_eq(em.current_enemies.size(), 2, "[T021] elite room populated with enemy_count")
	t.assert_eq(_spawned_type_set(em).keys(), ["elite_chaser"],
		"[T021] elite room spawns elite_* variants of the theme pool")

	EventBus.room_entered.emit({
		"room_id": "boss_rd_01",
		"room_type": "boss",
		"objective": {"objective_type": "clear_enemies", "required_count": 1},
		"enemy_count": 1,
		"modifiers": [],
	})
	t.assert_eq(em.current_enemies.size(), 1, "[T021] boss room populated with single boss enemy")
	t.assert_eq(_spawned_type_set(em).keys(), ["elite_chaser"],
		"[T021] v1 boss uses elite variant (spec 边界：boss 未配置 → 精英回退)")

	ConfigManager.floor_themes.clear()
	ConfigManager.floor_themes.merge(saved_themes)
	director.cleanup()
	director.queue_free()
	await _free_field(t, field)


func _test_room_director_difficulty_hook(t) -> void:
	var field: Dictionary = _make_field(t)
	var director: Node = _make_director(t, field)
	var em: Node = field["enemy_manager"]
	var fm: Node = field["food_manager"]
	var scaler := ScalerStub.new()

	EventBus.floor_generated.emit({"floor_index": 1, "theme_id": "", "rooms": []})
	director.set_difficulty_scaler(scaler)

	scaler.enemy_delta = 2
	scaler.food_delta = -5
	EventBus.room_entered.emit(_combat_room("combat_rd_03", 3))
	t.assert_eq(em.current_enemies.size(), 5,
		"[T021] difficulty delta hook adds to the enemy budget (3 + 2)")
	t.assert_eq(fm.current_foods.size(), 0,
		"[T021] food delta applies and clamps at zero")

	scaler.enemy_delta = -5
	scaler.food_delta = 0
	EventBus.room_entered.emit(_combat_room("combat_rd_04", 3))
	t.assert_eq(em.current_enemies.size(), 3,
		"[T021] enemy budget never drops below required_count (目标必须可达成)")

	director.set_difficulty_scaler(null)
	EventBus.room_entered.emit(_combat_room("combat_rd_05", 3))
	t.assert_eq(em.current_enemies.size(), 3,
		"[T021] without a scaler the delta hook is a zero stub (T6 前)")

	director.cleanup()
	director.queue_free()
	await _free_field(t, field)


func _test_room_director_theme_signal_and_modifier_hook(t) -> void:
	var field: Dictionary = _make_field(t)
	var director: Node = _make_director(t, field)
	_theme_events.clear()
	EventBus.floor_theme_set.connect(_on_floor_theme_set)

	EventBus.floor_generated.emit({"floor_index": 2, "theme_id": "cave", "rooms": []})
	t.assert_eq(_theme_events.size(), 1, "[T021] director emits floor_theme_set for themed floors")
	if _theme_events.size() > 0:
		t.assert_eq(str(_theme_events[0].get("theme", "")), "cave", "[T021] floor_theme_set carries theme")
		t.assert_eq(int(_theme_events[0].get("floor_index", 0)), 2, "[T021] floor_theme_set carries floor_index")

	EventBus.floor_generated.emit({"floor_index": 1, "theme_id": "", "rooms": []})
	t.assert_eq(_theme_events.size(), 1,
		"[T021] no floor_theme_set for un-themed floors (fixed_v1 档)")

	var hook := ModifierHookStub.new()
	director.set_modifier_system(hook)
	var room: Dictionary = _combat_room("combat_rd_06", 3)
	room["modifiers"] = ["shield_enemies"]
	EventBus.room_entered.emit(room)
	t.assert_eq(hook.applied_rooms.size(), 1,
		"[T021] modifier injection point forwards the room to the modifier system (T031 消费)")
	if hook.applied_rooms.size() > 0:
		t.assert_eq(str(hook.applied_rooms[0].get("room_id", "")), "combat_rd_06",
			"[T021] modifier hook receives the entered room dict")

	EventBus.floor_theme_set.disconnect(_on_floor_theme_set)
	director.cleanup()
	director.queue_free()
	await _free_field(t, field)


# ── T022: RunProgression 多层推进（pcg 档）/ 终层胜利 / fixed_v1 单层保持 ────

func _test_run_progression_multifloor(t) -> void:
	var run_system: Node = load(RUN_PROGRESSION_PATH).new()
	if not run_system.has_method("advance_floor"):
		t.assert_true(false, "[T022] RunProgressionSystem.advance_floor not implemented")
		run_system.free()
		return
	var previous: String = _force_generator("pcg")
	t.add_child(run_system)
	_connect_run_recorders()

	run_system.start_run(7777)
	var max_floors: int = ConfigManager.get_max_floors()
	t.assert_eq(max_floors, 3, "[T022] run.max_floors == 3 (FR-016 baseline)")
	t.assert_eq(_floor_generated_events.size(), 1, "[T022] start_run generates floor 1")

	_walk_floor_to_endpoint(run_system)
	t.assert_eq(_floor_completed_events.size(), 1, "[T022] boss completion emits floor_completed")
	t.assert_eq(int(run_system.get_state().get("floor_index", 0)), 1,
		"[T022] floor advance is deferred (击杀级联重入防护——不在 room_completed 派发内重建世界)")
	await t.get_tree().process_frame

	t.assert_eq(int(run_system.get_state().get("floor_index", 0)), 2,
		"[T022] non-final boss completion advances to floor 2")
	t.assert_eq(_floor_generated_events.size(), 2, "[T022] advance regenerates and emits floor_generated")
	t.assert_eq(run_system.get_state().get("outcome", ""), "running",
		"[T022] run keeps running across the floor transition")
	t.assert_eq(run_system.get_state().get("completed_room_ids", []), [],
		"[T022] completed rooms reset per floor (room ids are floor-scoped)")

	var floor2_map: Dictionary = _floor_generated_events[1] if _floor_generated_events.size() > 1 else {}
	var fresh_map: Dictionary = load(FLOOR_MAP_GENERATOR_PATH).new().generate_floor(2, 7777)
	t.assert_eq(var_to_str(floor2_map), var_to_str(fresh_map),
		"[T022] floor 2 regenerated deterministically from the SAME run seed (种子推导含 floor_index)")

	var floor2_start: String = str(floor2_map.get("start_room_id", ""))
	t.assert_eq(run_system.get_state().get("current_room_id", ""), floor2_start,
		"[T022] run enters the new floor at its start room")
	var entered_floor2_start: bool = false
	for entered in _room_entered_events:
		if str(entered.get("room_id", "")) == floor2_start:
			entered_floor2_start = true
	t.assert_true(entered_floor2_start, "[T022] room_entered emitted for the new floor start room")

	_walk_floor_to_endpoint(run_system)
	await t.get_tree().process_frame
	t.assert_eq(int(run_system.get_state().get("floor_index", 0)), 3,
		"[T022] floor 2 boss completion advances to floor 3")

	_walk_floor_to_endpoint(run_system)
	t.assert_eq(run_system.get_state().get("outcome", ""), "victory",
		"[T022] FINAL floor boss completion takes the victory path (run.max_floors consumed)")
	t.assert_eq(_victory_events.size(), 1, "[T022] run_victory emitted once")
	await t.get_tree().process_frame
	t.assert_eq(_floor_generated_events.size(), 3,
		"[T022] no floor 4 is generated after the final floor")

	_disconnect_run_recorders()
	run_system.cleanup()
	run_system.queue_free()
	_restore_generator(previous)
	await t.get_tree().process_frame


func _test_floor_reward_gates_advance(t) -> void:
	var run_system: Node = load(RUN_PROGRESSION_PATH).new()
	if not run_system.has_method("advance_floor"):
		t.assert_true(false, "[T022] floor reward gating needs advance_floor (not implemented)")
		run_system.free()
		return
	var previous: String = _force_generator("pcg")
	t.add_child(run_system)
	run_system.start_run(8888)

	_walk_floor_until_endpoint(run_system)
	var endpoint_id: String = str(run_system.get_floor_map().get("endpoint_room_id", ""))
	t.assert_eq(run_system.get_state().get("current_room_id", ""), endpoint_id,
		"[T022] walked to the boss room without completing it")

	# T027 groundwork（FR-007/US5 场景 5）：楼层奖励决议先于 advance_floor/floor_generated
	EventBus.floor_reward_presented.emit({"floor_index": 1, "options": []})
	EventBus.room_advance_requested.emit({})
	t.assert_eq(run_system.get_state().get("current_room_id", ""), endpoint_id,
		"[T022] advance requests ignored while floor reward offer pending (FR-015)")

	EventBus.room_completed.emit({"room_id": endpoint_id})
	await t.get_tree().process_frame
	t.assert_eq(int(run_system.get_state().get("floor_index", 0)), 1,
		"[T022] floor does NOT advance while the floor reward is unresolved")

	EventBus.floor_reward_chosen.emit({"category": "expansion", "option_id": "adv"})
	await t.get_tree().process_frame
	t.assert_eq(int(run_system.get_state().get("floor_index", 0)), 2,
		"[T022] floor advances right after the floor reward resolves (决议先于 floor_generated)")

	run_system.cleanup()
	run_system.queue_free()
	_restore_generator(previous)
	await t.get_tree().process_frame


func _test_fixed_v1_endpoint_victory_preserved(t) -> void:
	var run_system: Node = load(RUN_PROGRESSION_PATH).new()
	t.add_child(run_system)
	_connect_run_recorders()

	run_system.start_run(1001)
	t.assert_eq(str(run_system.get_floor_map().get("generator", "")), "fixed_v1",
		"[T022] default generator stays fixed_v1 (MDE 回退档)")
	_walk_floor_to_endpoint(run_system)
	t.assert_eq(run_system.get_state().get("outcome", ""), "victory",
		"[T022] fixed_v1 endpoint completion still ends in victory on floor 1 (MDE 单层闭环保持)")
	await t.get_tree().process_frame
	t.assert_eq(_floor_generated_events.size(), 1,
		"[T022] fixed_v1 never advances to a second floor (多层推进是 pcg 档行为)")

	_disconnect_run_recorders()
	run_system.cleanup()
	run_system.queue_free()
	await t.get_tree().process_frame


# ── T022: game_world.reset_for_floor() e2e（pcg 3 层 run 的第一次切层） ─────

func _test_game_world_reset_for_floor(t) -> void:
	var saved_state: int = GameManager.current_state
	var saved_score: int = GameManager.current_score
	var saved_best: int = GameManager.best_score
	var previous: String = _force_generator("pcg")

	var scene = load("res://scenes/game_world.tscn") as PackedScene
	var world: Node = scene.instantiate()
	t.assert_true(world.has_method("reset_for_floor"), "[T022] game_world has reset_for_floor()")
	t.assert_true(world.has_node("RoomDirector"), "[T022] game_world scene carries a RoomDirector node")
	if not world.has_method("reset_for_floor") or not world.has_node("RoomDirector"):
		world.free()
		_restore_generator(previous)
		return

	t.add_child(world)
	world.start_game()
	GameManager.start_game()

	var run_system: Node = world.get_node("RunProgressionSystem")
	var snake: Node = world.get_node("EntityContainer/Snake")
	var tile_mgr: Node = world.get_node("StatusTileManager")
	var enemy_mgr: Node = world.get_node("EnemyManager")
	var food_mgr: Node = world.get_node("FoodManager")

	t.assert_eq(int(run_system.get_state().get("floor_index", 0)), 1, "[T022] pcg run starts on floor 1")
	t.assert_true(enemy_mgr.current_enemies.size() > 0,
		"[T022] RoomDirector populates the start room (start_game 让位给 director)")
	var length_before: int = snake.body.size()
	tile_mgr.place_tile(Vector2i(2, 2), "fire")
	t.assert_true(tile_mgr.get_tile_count() > 0, "[T022] precondition: stray status tile on the field")

	var advanced: bool = await _drive_world_to_next_floor(t, world, 1)
	t.assert_true(advanced, "[T022] panels drive the pcg floor 1 to its boss and beyond")
	t.assert_eq(int(run_system.get_state().get("floor_index", 0)), 2,
		"[T022] world run reaches floor 2")
	t.assert_eq(snake.body.size(), length_before,
		"[T022] snake re-init preserves length across the floor transition")
	t.assert_eq(tile_mgr.get_tile_count(), 0,
		"[T022] reset_for_floor clears status tiles (组合既有 clear_all 原语)")
	var start_room: Dictionary = run_system.get_current_room()
	t.assert_eq(str(start_room.get("room_type", "")), "combat",
		"[T022] floor 2 starts at its combat start room")
	t.assert_eq(enemy_mgr.current_enemies.size(), int(start_room.get("enemy_count", 0)),
		"[T022] floor 2 start room repopulated by RoomDirector after the reset")
	t.assert_true(food_mgr.current_foods.size() > 0, "[T022] food re-laid on the new floor")

	world.cleanup()
	world.queue_free()
	GameManager.current_state = saved_state
	GameManager.current_score = saved_score
	GameManager.best_score = saved_best
	TickManager.stop_ticking()
	GridWorld.clear_all()
	_restore_generator(previous)
	# 冲掉 queue_free 的世界：EnemyManager 在落地前仍连着 enemy_killed（严格扫描防护）
	await t.get_tree().process_frame
	await t.get_tree().process_frame


# ── Helpers ─────────────────────────────────────────────────────────────────

func _has_policy_api() -> bool:
	var em: Node = load(ENEMY_MANAGER_PATH).new()
	var ok: bool = ("respawn_policy" in em) and ("spawn_budget" in em) and em.has_method("set_spawn_weights")
	em.free()
	return ok


func _make_field(t) -> Dictionary:
	GridWorld.init_grid(Constants.GRID_WIDTH, Constants.GRID_HEIGHT)
	var enemy_container := Node2D.new()
	enemy_container.name = "RdTestEnemyContainer"
	t.add_child(enemy_container)
	var food_container := Node2D.new()
	food_container.name = "RdTestFoodContainer"
	t.add_child(food_container)

	var em: Node = load(ENEMY_MANAGER_PATH).new()
	em.enemy_container = enemy_container
	t.add_child(em)

	var fm: Node = load("res://systems/food_manager.gd").new()
	fm.food_container = food_container
	t.add_child(fm)

	return {
		"enemy_manager": em,
		"food_manager": fm,
		"enemy_container": enemy_container,
		"food_container": food_container,
	}


func _free_field(t, field: Dictionary) -> void:
	field["enemy_manager"].clear_enemies()
	field["food_manager"].clear_foods()
	field["enemy_manager"].queue_free()
	field["food_manager"].queue_free()
	field["enemy_container"].queue_free()
	field["food_container"].queue_free()
	GridWorld.clear_all()
	# 等 queue_free 落地，断开 EnemyManager/FoodManager 的 EventBus 监听
	# （maintain 档的管理器会把后续套件的 mock enemy_killed 当真补怪）
	await t.get_tree().process_frame
	await t.get_tree().process_frame


func _make_director(t, field: Dictionary) -> Node:
	var director: Node = load(ROOM_DIRECTOR_PATH).new()
	director.name = "RdTestDirector"
	t.add_child(director)
	director.setup(field["enemy_manager"], field["food_manager"])
	return director


func _combat_room(room_id: String, enemy_count: int) -> Dictionary:
	return {
		"room_id": room_id,
		"room_type": "combat",
		"objective": {"objective_type": "clear_enemies", "required_count": 3, "current_count": 0},
		"enemy_count": enemy_count,
		"modifiers": [],
	}


func _spawned_type_set(em: Node) -> Dictionary:
	var types: Dictionary = {}
	for enemy in em.current_enemies:
		if is_instance_valid(enemy):
			types[str(enemy.enemy_type)] = true
	return types


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


func _walk_floor_until_endpoint(run_system: Node) -> void:
	## 走到 endpoint/boss 房门口但不完成它
	for _i in range(32):
		var room: Dictionary = run_system.get_current_room()
		var room_id: String = str(room.get("room_id", ""))
		if room_id == str(run_system.get_floor_map().get("endpoint_room_id", "")):
			return
		EventBus.room_completed.emit({"room_id": room_id})
		var exits: Array = room.get("exit_room_ids", [])
		if exits.is_empty():
			return
		run_system.advance_to_room(str(exits[0]))


func _drive_world_to_next_floor(t, world: Node, from_floor: int) -> bool:
	## 面板公共 API 驱动一层（test_l3_smoke_run 模式扩展）：
	## 战斗类房 record progress → 决议鳞片/奖励/Boss 结算模态 → Next；boss 完成 → 等延迟切层
	var run_system: Node = world.get_node("RunProgressionSystem")
	var room_flow: Node = world.get_node("RoomFlowSystem")
	var floor_panel: Node = world.get_node("UI/FloorProgressPanel")
	var reward_panel: Node = world.get_node("UI/RewardChoicePanel")
	var scale_panel: Node = world.get_node("UI/ScaleChoicePanel")
	var reward_flow: Node = world.get_node("RewardFlowSystem")
	var scale_system: Node = world.get_node("ScaleRewardSystem")
	var floor_reward_system: Node = world.get_node("FloorRewardSystem")
	var floor_reward_panel: Node = world.get_node("UI/FloorRewardPanel")

	for _step in range(64):
		if int(run_system.get_state().get("floor_index", 0)) != from_floor:
			return true
		if not run_system.is_running():
			return false
		if scale_system.has_pending_offer():
			scale_panel.discard_offer()
			continue
		if reward_flow.has_pending_offer():
			reward_panel.choose_option_by_index(0)
			continue
		# T5b：Boss 结算两段式（槽位定位选择 → 3 选 1），决议先于切层（FR-007）
		if floor_reward_system.has_pending_offer():
			if floor_reward_panel.get_step() == "slot_unlock":
				floor_reward_panel.choose_slot_by_index(0)
			else:
				floor_reward_panel.choose_option_by_index(0)
			continue
		if not room_flow.is_current_room_complete():
			var objective: Dictionary = room_flow.get_current_room().get("objective", {})
			if str(objective.get("objective_type", "")) == "clear_enemies":
				room_flow.record_objective_progress(int(objective.get("required_count", 1)), {"method": "t5a_driver"})
			continue
		# 房间已完成：可能是 boss（延迟切层在飞），先冲帧再请求推进
		await t.get_tree().process_frame
		if int(run_system.get_state().get("floor_index", 0)) != from_floor:
			return true
		if not floor_panel.request_next_room():
			return false
	return false


func _connect_run_recorders() -> void:
	_floor_generated_events.clear()
	_room_entered_events.clear()
	_floor_completed_events.clear()
	_victory_events.clear()
	EventBus.floor_generated.connect(_on_floor_generated)
	EventBus.room_entered.connect(_on_room_entered)
	EventBus.floor_completed.connect(_on_floor_completed)
	EventBus.run_victory.connect(_on_run_victory)


func _disconnect_run_recorders() -> void:
	EventBus.floor_generated.disconnect(_on_floor_generated)
	EventBus.room_entered.disconnect(_on_room_entered)
	EventBus.floor_completed.disconnect(_on_floor_completed)
	EventBus.run_victory.disconnect(_on_run_victory)


func _on_floor_generated(data: Dictionary) -> void:
	_floor_generated_events.append(data)


func _on_room_entered(data: Dictionary) -> void:
	_room_entered_events.append(data)


func _on_floor_completed(data: Dictionary) -> void:
	_floor_completed_events.append(data)


func _on_run_victory(data: Dictionary) -> void:
	_victory_events.append(data)


func _on_floor_theme_set(data: Dictionary) -> void:
	_theme_events.append(data)


func _force_generator(mode: String) -> String:
	var previous: String = str(ConfigManager.floor.get("generator", "fixed_v1"))
	ConfigManager.floor["generator"] = mode
	return previous


func _restore_generator(previous: String) -> void:
	ConfigManager.floor["generator"] = previous
