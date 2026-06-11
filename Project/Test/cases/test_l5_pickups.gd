extends RefCounted
## spec 003 M4（T017 Red 卡重写）：事件拾取簇（US3 SHOULD，v1 = broken_eye ONLY）。
## - elite 判定走 Enemy 节点 + ConfigManager.get_enemy_type(...).is_elite
##   （草稿 Dictionary 判型 / `enemy_type != "elite"` 字符串比对的回归用例）；
## - randf 顺序：先判 elite 再掷骰——非精英零 RNG 消耗（定种子可证）；
## - v1 池恰 = broken_eye（serpent_scale 配置 enabled=false，backlog.md 收容）；
## - 网格实体掉落（仿 food：GridWorld 占格 + cell_layer 0）/ 占用格偏移最近空格 /
##   蛇头进入拾取（snake_moved 事件路径 + collect_pickup_at 直驱）；
## - 携带效果（Designs §9.4 持有效果）：broken_eye = 敌人下一步移动方向显示
##   （DangerIndicator 数据通路复用，carry_effect = "enemy_intent"）；
## - 房间倒数（duration_rooms，room_completed 递减，归零过期）；
## - floor 离场未激活清除（FR-008）；激活 API 幂等保留（路线 A/B 入 backlog）；
## - PickupDisplay（ui/kit chip 行，hud 层，渐进披露）；game_world 接线。
## 注意：全局 enemy_killed 的 enemy_def 必须是 Node 派生或 null（repo 测试事实）；
## Dictionary 形态回归走系统直驱 API，不上全局总线。

const PICKUP_PATH: String = "res://systems/events/pickup_system.gd"
const ENTITY_PATH: String = "res://entities/pickups/pickup_entity.gd"
const DISPLAY_PATH: String = "res://ui/pickup_display.gd"
const INDICATOR_PATH: String = "res://systems/vfx/danger_indicator.gd"
const GAME_WORLD_SCENE_PATH: String = "res://scenes/game_world.tscn"

var _dropped_events: Array = []
var _collected_events: Array = []
var _activated_events: Array = []
var _expired_events: Array = []


## 假敌人（duck typing：真实 payload 的 enemy_def 是带 enemy_type 属性的 Enemy 节点；
## 必须是 Node 派生——EnemyManager 等全局监听方按 Node 收参）
class MockEnemy extends Node2D:
	var enemy_type: String = ""
	var grid_position: Vector2i = Vector2i.ZERO

	func _init(type_id: String = "", pos: Vector2i = Vector2i.ZERO) -> void:
		enemy_type = type_id
		grid_position = pos


func run(t) -> void:
	_test_config_v1_scope(t)
	_test_no_class_name(t)
	_test_elite_check_via_config(t)
	_test_randf_order_no_rng_for_non_elite(t)
	_test_enemy_killed_node_typing(t)
	_test_grid_drop_and_offset(t)
	_test_head_entry_collection(t)
	_test_carry_effect_danger_indicator(t)
	_test_room_countdown_expiry(t)
	_test_floor_clear_unactivated(t)
	_test_activation_api_idempotent(t)
	_test_ground_cleared_on_room_entered(t)
	_test_run_started_reset(t)
	_test_pickup_display_chip_row(t)
	await _test_game_world_wiring(t)


# === v1 范围：配置即合同（serpent_scale 禁用入 backlog，broken_eye 唯一可掉） ===

func _test_config_v1_scope(t) -> void:
	var cfg: Dictionary = ConfigManager.get_event_pickups_config()
	t.assert_true(bool(cfg.get("enabled", false)), "[L5-M4] event_pickups enabled in JSON")
	var pickups: Dictionary = cfg.get("pickups", {})
	var enabled_ids: Array = []
	for pickup_id in pickups:
		if bool(pickups[pickup_id].get("enabled", false)):
			enabled_ids.append(pickup_id)
	t.assert_eq(enabled_ids, ["broken_eye"],
		"[L5-M4] v1 droppable pool is EXACTLY broken_eye (serpent_scale disabled -> backlog)")
	var broken_eye: Dictionary = ConfigManager.get_pickup("broken_eye")
	t.assert_eq(str(broken_eye.get("carry_effect", "")), "enemy_intent",
		"[L5-M4] broken_eye carry effect = enemy_intent (Designs §9.4 持有效果)")
	t.assert_true(int(broken_eye.get("duration_rooms", 0)) >= 1,
		"[L5-M4] broken_eye duration_rooms configured in JSON (FR-010)")
	# 拾取 glyph 入 presentation.glyphs（PickupDisplay chip 图标）
	t.assert_false(ConfigManager.get_glyph_def("pickup").is_empty(),
		"[L5-M4] presentation.glyphs has 'pickup' glyph for the chip row")


func _test_no_class_name(t) -> void:
	for path in [PICKUP_PATH, ENTITY_PATH, DISPLAY_PATH]:
		t.assert_file_exists(path)
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var text: String = file.get_as_text()
		file.close()
		t.assert_false(text.begins_with("class_name") or text.contains("\nclass_name"),
			"[L5-M4] no class_name in %s (C.8)" % path)


# === elite 判定走 ConfigManager enemy_types.is_elite（草稿字符串比对回归） ===

func _test_elite_check_via_config(t) -> void:
	var system: Node = _make_system(t)
	var saved_chance: float = _stage_drop_chance(1.0)

	# 真实精英类型（enemy_types.elite_wanderer.is_elite = true）→ 必掉（chance=1.0）
	t.assert_true(bool(ConfigManager.get_enemy_type("elite_wanderer").get("is_elite", false)),
		"[L5-M4] config cross-check: elite_wanderer is_elite (RoomDirector elite rooms spawn these)")
	var id: String = system.try_drop_pickup("elite_wanderer", Vector2i(8, 8))
	t.assert_eq(id, "broken_eye", "[L5-M4] is_elite enemy type drops broken_eye")

	# 草稿的字面量 "elite" 不存在于 enemy_types → is_elite false → 不掉
	# （回归：elite 判定必须走配置，不是 enemy_type 字符串比对）
	t.assert_eq(system.try_drop_pickup("elite", Vector2i(9, 9)), "",
		"[L5-M4] literal 'elite' string is NOT an is_elite config type -> no drop (regression)")
	t.assert_eq(system.try_drop_pickup("wanderer", Vector2i(9, 9)), "",
		"[L5-M4] non-elite type never drops")

	# 数据反证：drop_chance = 0 → 精英也不掉（JSON 驱动）
	_stage_drop_chance(0.0)
	t.assert_eq(system.try_drop_pickup("elite_wanderer", Vector2i(8, 9)), "",
		"[L5-M4] drop_chance 0 -> elite never drops (JSON-driven)")

	_stage_drop_chance(saved_chance)
	_teardown_system(system)


# === randf 顺序：先判 elite 再掷骰（非精英零 RNG 消耗，定种子可证） ===

func _test_randf_order_no_rng_for_non_elite(t) -> void:
	var system: Node = _make_system(t)

	# 非精英：零 RNG 消耗——同种子下后续 randf 流不被扰动
	seed(424242)
	var expected_next: float = randf()
	seed(424242)
	t.assert_eq(system.try_drop_pickup("wanderer", Vector2i(5, 5)), "",
		"[L5-M4] non-elite drop attempt returns empty")
	t.assert_eq(randf(), expected_next,
		"[L5-M4] non-elite path consumes ZERO rng (elite check precedes the roll)")

	# 精英：恰一次掷骰，结果与同种子直读 randf 完全一致（定种子可证）
	var chance: float = float(ConfigManager.get_event_pickups_config().get("drop_chance", 0.5))
	for s in [11, 22, 33, 44, 55]:
		seed(s)
		var roll: float = randf()
		seed(s)
		var id: String = system.try_drop_pickup("elite_wanderer", Vector2i(5, 5))
		t.assert_eq(id != "", roll <= chance,
			"[L5-M4] elite drop outcome matches the seeded roll (seed %d)" % s)
		_clear_ground(system)

	_teardown_system(system)


# === enemy_killed 节点判型（草稿把 Node 当 Dictionary 的死代码回归） ===

func _test_enemy_killed_node_typing(t) -> void:
	var saved_gm: Dictionary = _save_game_manager()
	var system: Node = _make_system(t)
	var saved_chance: float = _stage_drop_chance(1.0)
	_collect_events()

	# 真实形态：enemy_def = Enemy 节点（带 enemy_type 属性）→ 事件路径掉落
	var elite := MockEnemy.new("elite_chaser", Vector2i(12, 12))
	EventBus.enemy_killed.emit(
		{"enemy_def": elite, "position": Vector2i(12, 12), "method": "head_bite"})
	t.assert_eq(_dropped_events.size(), 1,
		"[L5-M4] NODE enemy_def resolves via duck-typed enemy_type (draft Dictionary-typing regression)")
	t.assert_eq(system.get_ground_pickups().size(), 1, "[L5-M4] event path drops a grid pickup")
	_clear_ground(system)

	# 非精英节点：零掉落
	var normal := MockEnemy.new("chaser", Vector2i(13, 13))
	EventBus.enemy_killed.emit(
		{"enemy_def": normal, "position": Vector2i(13, 13), "method": "head_bite"})
	t.assert_eq(system.get_ground_pickups().size(), 0, "[L5-M4] non-elite node kill: no drop")

	# null enemy_def（合法 payload 形态）：不崩、不掉
	EventBus.enemy_killed.emit(
		{"enemy_def": null, "position": Vector2i(13, 13), "method": "reaction_steam"})
	t.assert_eq(system.get_ground_pickups().size(), 0, "[L5-M4] null enemy_def: no drop, no crash")

	elite.free()
	normal.free()
	_stop_collect_events()
	_stage_drop_chance(saved_chance)
	_teardown_system(system)
	_restore_game_manager(saved_gm)


# === 网格实体掉落 + 占用格偏移最近空格（spec Edge Case） ===

func _test_grid_drop_and_offset(t) -> void:
	var system: Node = _make_system(t)
	var saved_chance: float = _stage_drop_chance(1.0)
	_collect_events()

	# 空格掉落：恰在击杀位
	var pos := Vector2i(10, 10)
	t.assert_eq(system.try_drop_pickup("elite_wanderer", pos), "broken_eye",
		"[L5-M4] elite drop succeeds at a free cell")
	var entity: Node = GridWorld.get_first_entity_of_type(pos, Constants.EntityType.PICKUP)
	t.assert_true(entity != null, "[L5-M4] pickup registered on GridWorld as a PICKUP entity")
	if entity != null:
		t.assert_eq(int(entity.get("cell_layer")), 0,
			"[L5-M4] pickup is a ground-layer entity (food-like)")
		t.assert_false(bool(entity.get("blocks_movement")),
			"[L5-M4] pickup does not block movement")
	t.assert_eq(_dropped_events.size(), 1, "[L5-M4] pickup_dropped emitted once")
	if _dropped_events.size() >= 1:
		t.assert_eq(_dropped_events[0].get("position", Vector2i.ZERO), pos,
			"[L5-M4] pickup_dropped carries the resolved drop position")
	_clear_ground(system)

	# 占用格：偏移到最近空格（曼哈顿距离 1）
	var blocker := MockEnemy.new("wanderer", pos)
	GridWorld.register_entity(blocker, pos)
	_dropped_events.clear()
	t.assert_eq(system.try_drop_pickup("elite_wanderer", pos), "broken_eye",
		"[L5-M4] occupied cell still drops (offset)")
	t.assert_eq(_dropped_events.size(), 1, "[L5-M4] offset drop emits pickup_dropped")
	if _dropped_events.size() >= 1:
		var resolved: Vector2i = _dropped_events[0].get("position", Vector2i.ZERO)
		t.assert_true(resolved != pos, "[L5-M4] occupied cell -> pickup offset away")
		t.assert_eq(absi(resolved.x - pos.x) + absi(resolved.y - pos.y), 1,
			"[L5-M4] offset lands on the NEAREST free cell (manhattan 1)")
		t.assert_true(
			GridWorld.get_first_entity_of_type(resolved, Constants.EntityType.PICKUP) != null,
			"[L5-M4] offset pickup actually registered at the resolved cell")
	_clear_ground(system)

	# exclude 缝（生产路径：enemy_killed 派发时刚死的敌人仍占格——排除后落在原位）
	_dropped_events.clear()
	t.assert_eq(system.try_drop_pickup("elite_wanderer", pos, blocker), "broken_eye",
		"[L5-M4] dying enemy excluded from the occupancy check")
	if _dropped_events.size() >= 1:
		t.assert_eq(_dropped_events[0].get("position", Vector2i.ZERO), pos,
			"[L5-M4] with the dying enemy excluded, pickup lands AT the kill cell")
	_clear_ground(system)

	GridWorld.unregister_entity(blocker)
	blocker.free()
	_stop_collect_events()
	_stage_drop_chance(saved_chance)
	_teardown_system(system)


# === 蛇头进入拾取（snake_moved 事件路径 + 直驱 API） ===

func _test_head_entry_collection(t) -> void:
	var system: Node = _make_system(t)
	var saved_chance: float = _stage_drop_chance(1.0)
	_collect_events()

	var duration: int = int(ConfigManager.get_pickup("broken_eye").get("duration_rooms", 0))

	# 直驱 API：collect_pickup_at（蛇头进入语义的可测缝）
	var pos := Vector2i(6, 6)
	system.try_drop_pickup("elite_wanderer", pos)
	t.assert_eq(system.collect_pickup_at(pos), "broken_eye",
		"[L5-M4] head-entry collection via public API")
	t.assert_eq(system.get_ground_pickups().size(), 0, "[L5-M4] collected pickup leaves the grid")
	t.assert_true(
		GridWorld.get_first_entity_of_type(pos, Constants.EntityType.PICKUP) == null,
		"[L5-M4] grid entity unregistered on collection")
	t.assert_true(system.has_carried("broken_eye"), "[L5-M4] collected pickup is carried")
	t.assert_eq(_collected_events.size(), 1, "[L5-M4] pickup_collected emitted once")
	if _collected_events.size() >= 1:
		var payload: Dictionary = _collected_events[0]
		t.assert_eq(str(payload.get("pickup_id", "")), "broken_eye",
			"[L5-M4] collected payload carries pickup_id")
		t.assert_eq(str(payload.get("carry_effect", "")), "enemy_intent",
			"[L5-M4] collected payload carries carry_effect (DangerIndicator data path)")
		t.assert_eq(int(payload.get("rooms_remaining", -1)), duration,
			"[L5-M4] carry countdown starts at JSON duration_rooms")
	var carried: Array = system.get_carried_pickups()
	t.assert_eq(carried.size(), 1, "[L5-M4] exactly one carried record")
	if carried.size() >= 1:
		t.assert_false(bool(carried[0].get("active", true)),
			"[L5-M4] picked up = carried INACTIVE (Designs §9.4 carry/activate model)")
		t.assert_eq(int(carried[0].get("rooms_remaining", -1)), duration,
			"[L5-M4] carried record holds rooms_remaining")
	system.cleanup()
	system.connect_events()

	# 事件路径：snake_moved 的 head_pos 命中拾取格 → 拾取
	var pos2 := Vector2i(7, 7)
	system.try_drop_pickup("elite_wanderer", pos2)
	_collected_events.clear()
	EventBus.snake_moved.emit({
		"body": [pos2], "direction": Vector2i.RIGHT,
		"head_pos": pos2, "old_tail_pos": pos2,
	})
	t.assert_eq(_collected_events.size(), 1,
		"[L5-M4] snake head entering the cell collects the pickup (snake_moved path)")
	t.assert_true(system.has_carried("broken_eye"), "[L5-M4] event-path pickup carried")

	# 空格移动：零拾取零事件
	_collected_events.clear()
	EventBus.snake_moved.emit({
		"body": [Vector2i(1, 1)], "direction": Vector2i.RIGHT,
		"head_pos": Vector2i(1, 1), "old_tail_pos": Vector2i(1, 1),
	})
	t.assert_eq(_collected_events.size(), 0, "[L5-M4] moving onto an empty cell collects nothing")

	_stop_collect_events()
	_stage_drop_chance(saved_chance)
	_teardown_system(system)


# === 携带效果：DangerIndicator 敌人意图显示（SC-005 数据通路） ===

func _test_carry_effect_danger_indicator(t) -> void:
	var system: Node = _make_system(t)
	var saved_chance: float = _stage_drop_chance(1.0)
	var indicator: Node2D = load(INDICATOR_PATH).new()
	t.add_child(indicator)

	t.assert_false(indicator.is_intent_display_enabled(),
		"[L5-M4] intent display OFF before any pickup is carried")

	# 拾取 → 携带效果即时生效（spec US3：while carried, the carry effect is live）
	var pos := Vector2i(4, 4)
	system.try_drop_pickup("elite_wanderer", pos)
	t.assert_false(indicator.is_intent_display_enabled(),
		"[L5-M4] ground drop alone does not enable the carry effect")
	system.collect_pickup_at(pos)
	t.assert_true(indicator.is_intent_display_enabled(),
		"[L5-M4] carrying broken_eye enables enemy intent display (SC-005)")
	t.assert_true(system.is_carry_effect_active("enemy_intent"),
		"[L5-M4] system-side carry effect query active")

	# 敌人意图：enemy_action_decided 的最近一次移动方向 → 目标格
	var enemy := MockEnemy.new("wanderer", Vector2i(15, 10))
	EventBus.enemy_action_decided.emit(
		{"enemy": enemy, "action": "move", "direction": Vector2i(1, 0)})
	var cells: Array = indicator.get_intent_cells()
	t.assert_true(cells.has(Vector2i(16, 10)),
		"[L5-M4] enemy next-move cell exposed via the intent data path")
	# 攻击决策清除意图（下一步移动未知）
	EventBus.enemy_action_decided.emit(
		{"enemy": enemy, "action": "attack", "direction": Vector2i.ZERO})
	t.assert_false(indicator.get_intent_cells().has(Vector2i(16, 10)),
		"[L5-M4] non-move decision clears that enemy's intent cell")

	# 过期 → 效果关闭
	var duration: int = int(ConfigManager.get_pickup("broken_eye").get("duration_rooms", 0))
	for _i in range(duration):
		EventBus.room_completed.emit({"room_id": "m4_carry_room", "room_type": "combat"})
	t.assert_false(indicator.is_intent_display_enabled(),
		"[L5-M4] countdown expiry disables the intent display")
	t.assert_eq(indicator.get_intent_cells().size(), 0,
		"[L5-M4] disabled display exposes no intent cells")

	enemy.free()
	indicator.queue_free()
	_stage_drop_chance(saved_chance)
	_teardown_system(system)


# === 房间倒数：duration_rooms，room_completed 递减，归零过期 ===

func _test_room_countdown_expiry(t) -> void:
	var system: Node = _make_system(t)
	var saved_chance: float = _stage_drop_chance(1.0)
	_collect_events()

	var duration: int = int(ConfigManager.get_pickup("broken_eye").get("duration_rooms", 0))
	var pos := Vector2i(3, 3)
	system.try_drop_pickup("elite_wanderer", pos)
	system.collect_pickup_at(pos)

	for i in range(duration - 1):
		EventBus.room_completed.emit({"room_id": "m4_room_%d" % i, "room_type": "combat"})
		t.assert_true(system.has_carried("broken_eye"),
			"[L5-M4] pickup survives room %d of %d" % [i + 1, duration])
	var carried: Array = system.get_carried_pickups()
	if carried.size() >= 1:
		t.assert_eq(int(carried[0].get("rooms_remaining", -1)), 1,
			"[L5-M4] countdown decrements per room_completed")
	t.assert_eq(_expired_events.size(), 0, "[L5-M4] no expiry before the countdown hits zero")

	EventBus.room_completed.emit({"room_id": "m4_room_last", "room_type": "combat"})
	t.assert_false(system.has_carried("broken_eye"),
		"[L5-M4] pickup expires when duration_rooms is exhausted")
	t.assert_eq(_expired_events.size(), 1, "[L5-M4] pickup_expired emitted once")
	if _expired_events.size() >= 1:
		t.assert_eq(str(_expired_events[0].get("reason", "")), "rooms_exhausted",
			"[L5-M4] expiry reason = rooms_exhausted")

	_stop_collect_events()
	_stage_drop_chance(saved_chance)
	_teardown_system(system)


# === FR-008：floor 离场未激活清除；激活者存续 ===

func _test_floor_clear_unactivated(t) -> void:
	var system: Node = _make_system(t)
	var saved_chance: float = _stage_drop_chance(1.0)
	_collect_events()

	# 未激活：floor_completed 清除
	var pos := Vector2i(2, 2)
	system.try_drop_pickup("elite_wanderer", pos)
	system.collect_pickup_at(pos)
	EventBus.floor_completed.emit({"floor_index": 1, "floor_id": "m4_floor"})
	t.assert_false(system.has_carried("broken_eye"),
		"[L5-M4] non-activated pickup cleared on floor transition (FR-008/SC-006)")
	t.assert_eq(_expired_events.size(), 1, "[L5-M4] floor clearing emits pickup_expired")
	if _expired_events.size() >= 1:
		t.assert_eq(str(_expired_events[0].get("reason", "")), "floor_transition",
			"[L5-M4] expiry reason = floor_transition")

	# 地面未拾取的碎片同样不跨层
	system.try_drop_pickup("elite_wanderer", pos)
	EventBus.floor_completed.emit({"floor_index": 2, "floor_id": "m4_floor2"})
	t.assert_eq(system.get_ground_pickups().size(), 0,
		"[L5-M4] uncollected ground fragments do not cross floors")

	# 已激活：跨层存续（FR-008 只清未激活；激活路线 A/B 的内容在 backlog）
	_expired_events.clear()
	system.try_drop_pickup("elite_wanderer", pos)
	system.collect_pickup_at(pos)
	t.assert_true(system.activate_pickup("broken_eye"), "[L5-M4] activation succeeds")
	EventBus.floor_completed.emit({"floor_index": 3, "floor_id": "m4_floor3"})
	t.assert_true(system.has_carried("broken_eye"),
		"[L5-M4] ACTIVATED pickup survives the floor transition (FR-008 scope)")
	t.assert_eq(_expired_events.size(), 0, "[L5-M4] activated pickup emits no expiry")

	_stop_collect_events()
	_stage_drop_chance(saved_chance)
	_teardown_system(system)


# === 激活 API 幂等（模型缝保留：active 字段 / activate_pickup / pickup_activated） ===

func _test_activation_api_idempotent(t) -> void:
	var system: Node = _make_system(t)
	var saved_chance: float = _stage_drop_chance(1.0)
	_collect_events()

	var pos := Vector2i(14, 14)
	system.try_drop_pickup("elite_wanderer", pos)
	system.collect_pickup_at(pos)

	t.assert_false(system.activate_pickup("missing_id"), "[L5-M4] unknown id activation rejected")
	t.assert_true(system.activate_pickup("broken_eye"), "[L5-M4] first activation succeeds")
	t.assert_false(system.activate_pickup("broken_eye"),
		"[L5-M4] second activation rejected (idempotent)")
	t.assert_eq(_activated_events.size(), 1, "[L5-M4] pickup_activated emitted exactly once")
	var carried: Array = system.get_carried_pickups()
	if carried.size() >= 1:
		t.assert_true(bool(carried[0].get("active", false)),
			"[L5-M4] active flag set on the carried record")

	# 激活者不再吃房间倒数（已转入激活态，倒数属携带期）
	var duration: int = int(ConfigManager.get_pickup("broken_eye").get("duration_rooms", 0))
	for i in range(duration + 1):
		EventBus.room_completed.emit({"room_id": "m4_act_room_%d" % i, "room_type": "combat"})
	t.assert_true(system.has_carried("broken_eye"),
		"[L5-M4] activated pickup exempt from the room countdown")

	_stop_collect_events()
	_stage_drop_chance(saved_chance)
	_teardown_system(system)


# === 地面碎片随 room_entered 清场（房间重布景，与 RoomDirector 清敌清食同口径） ===

func _test_ground_cleared_on_room_entered(t) -> void:
	var system: Node = _make_system(t)
	var saved_chance: float = _stage_drop_chance(1.0)

	var pos := Vector2i(11, 11)
	system.try_drop_pickup("elite_wanderer", pos)
	t.assert_eq(system.get_ground_pickups().size(), 1, "[L5-M4] fragment on the ground")
	EventBus.room_entered.emit({"room_id": "m4_next_room", "room_type": "combat"})
	t.assert_eq(system.get_ground_pickups().size(), 0,
		"[L5-M4] uncollected fragments cleared when the next room is staged")
	t.assert_true(
		GridWorld.get_first_entity_of_type(pos, Constants.EntityType.PICKUP) == null,
		"[L5-M4] grid entity unregistered on room re-stage")

	_stage_drop_chance(saved_chance)
	_teardown_system(system)


# === FR-013 风格：run_started 全量重置 ===

func _test_run_started_reset(t) -> void:
	var system: Node = _make_system(t)
	var saved_chance: float = _stage_drop_chance(1.0)

	system.try_drop_pickup("elite_wanderer", Vector2i(5, 9))
	system.try_drop_pickup("elite_wanderer", Vector2i(6, 9))
	system.collect_pickup_at(Vector2i(5, 9))
	EventBus.run_started.emit({"run_id": "m4_reset_run", "floor_index": 1, "seed": 1})
	t.assert_eq(system.get_carried_pickups().size(), 0, "[L5-M4] run_started clears carried")
	t.assert_eq(system.get_ground_pickups().size(), 0, "[L5-M4] run_started clears ground")

	_stage_drop_chance(saved_chance)
	_teardown_system(system)


# === PickupDisplay：ui/kit chip 行（hud 层，渐进披露） ===

func _test_pickup_display_chip_row(t) -> void:
	var system: Node = _make_system(t)
	var saved_chance: float = _stage_drop_chance(1.0)

	var display: Control = load(DISPLAY_PATH).new()
	display.name = "M4PickupDisplay"
	t.add_child(display)
	display.setup(system)

	t.assert_false(display.visible, "[L5-M4] chip row hidden before any pickup (渐进披露)")
	t.assert_eq(display.get_chip_count(), 0, "[L5-M4] empty chip row")

	var pos := Vector2i(9, 5)
	system.try_drop_pickup("elite_wanderer", pos)
	t.assert_false(display.visible, "[L5-M4] ground drop alone does not show the chip row")
	system.collect_pickup_at(pos)
	t.assert_true(display.visible, "[L5-M4] carrying a pickup shows the chip row")
	t.assert_eq(display.get_chip_count(), 1, "[L5-M4] one chip per carried pickup")
	var texts: Array = display.get_chip_texts()
	var duration: int = int(ConfigManager.get_pickup("broken_eye").get("duration_rooms", 0))
	var display_name: String = str(ConfigManager.get_pickup("broken_eye").get("display_name", ""))
	t.assert_true(texts.size() >= 1 and str(texts[0]).contains(display_name),
		"[L5-M4] chip shows the pickup display_name")
	t.assert_true(texts.size() >= 1 and str(texts[0]).contains(str(duration)),
		"[L5-M4] chip shows rooms_remaining")
	# kit 出生即带（chip 进组 + hud 层元数据——几何探测进组自动覆盖）
	var chips: Array = display.get_chips()
	t.assert_true(chips.size() >= 1 and chips[0].is_in_group("ui_kit"),
		"[L5-M4] chips born in ui_kit group")
	t.assert_true(chips.size() >= 1 and chips[0].is_in_group("ui_chip"),
		"[L5-M4] chips born in ui_chip group")
	t.assert_true(chips.size() >= 1 and chips[0].get_ui_layer() == "hud",
		"[L5-M4] chips carry ui_layer=hud meta")

	# 倒数刷新（room_completed 后 rooms_remaining 文本更新）
	EventBus.room_completed.emit({"room_id": "m4_disp_room", "room_type": "combat"})
	texts = display.get_chip_texts()
	t.assert_true(texts.size() >= 1 and str(texts[0]).contains(str(duration - 1)),
		"[L5-M4] chip text tracks the room countdown")

	# 过期 → 行收起
	for i in range(duration):
		EventBus.room_completed.emit({"room_id": "m4_disp_room_%d" % i, "room_type": "combat"})
	t.assert_false(display.visible, "[L5-M4] chip row hides when nothing is carried")
	t.assert_eq(display.get_chip_count(), 0, "[L5-M4] chips removed on expiry")

	display.queue_free()
	_stage_drop_chance(saved_chance)
	_teardown_system(system)


# === game_world 接线 + 真实世界 e2e（精英定点击杀 → 掉落 → 拾取 → 效果） ===

func _test_game_world_wiring(t) -> void:
	var saved_gm: Dictionary = _save_game_manager()
	var saved_chance: float = _stage_drop_chance(1.0)
	var world: Node = (load(GAME_WORLD_SCENE_PATH) as PackedScene).instantiate()
	t.add_child(world)

	var pickup_system: Node = world.get_node_or_null("PickupSystem")
	t.assert_true(pickup_system != null, "[L5-M4] PickupSystem resident in game_world.tscn")
	var pickup_display: Node = world.get_node_or_null("UI/PickupDisplay")
	t.assert_true(pickup_display != null, "[L5-M4] PickupDisplay resident in game_world UI")
	var indicator: Node = world.get_node_or_null("DangerIndicator")
	t.assert_true(indicator != null, "[L5-M4] DangerIndicator present for the carry effect")

	if pickup_system != null and indicator != null:
		world.start_game()

		# 精英定点放置（spawn_enemy_at 不耗预算）→ 击杀 → 掉落（排除尸格 → 原位）
		var spawn_pos := Vector2i(20, 5)
		var enemy: Node = world.enemy_manager.spawn_enemy_at("elite_wanderer", spawn_pos)
		t.assert_true(enemy != null, "[L5-M4] elite spawned in the live world")
		if enemy != null:
			enemy.take_damage(999)
			var ground: Array = pickup_system.get_ground_pickups()
			t.assert_eq(ground.size(), 1, "[L5-M4] elite kill drops a grid fragment (e2e)")
			if ground.size() >= 1:
				var drop_pos: Vector2i = ground[0].get("position", Vector2i.ZERO)
				t.assert_eq(pickup_system.collect_pickup_at(drop_pos), "broken_eye",
					"[L5-M4] fragment collectable in the live world")
				t.assert_true(indicator.is_intent_display_enabled(),
					"[L5-M4] carry effect live on the world's DangerIndicator (e2e)")
				if pickup_display != null:
					t.assert_true(pickup_display.visible,
						"[L5-M4] HUD chip row live in the world (e2e)")

	world.cleanup()
	world.queue_free()
	_stage_drop_chance(saved_chance)
	_restore_game_manager(saved_gm)
	TickManager.stop_ticking()
	GridWorld.clear_all()
	await t.get_tree().process_frame
	await t.get_tree().process_frame


# === helpers ===

func _make_system(t) -> Node:
	var system: Node = load(PICKUP_PATH).new()
	t.add_child(system)
	return system


func _teardown_system(system: Node) -> void:
	system.cleanup()
	system.queue_free()


func _clear_ground(_system: Node) -> void:
	# 公共 API 组合清地面（room_entered 清场语义）
	EventBus.room_entered.emit({"room_id": "m4_clear_helper", "room_type": "combat"})


func _stage_drop_chance(chance: float) -> float:
	var saved: float = float(ConfigManager.event_pickups.get("drop_chance", 0.5))
	ConfigManager.event_pickups["drop_chance"] = chance
	return saved


func _save_game_manager() -> Dictionary:
	return {
		"state": GameManager.current_state,
		"score": GameManager.current_score,
		"best": GameManager.best_score,
	}


func _restore_game_manager(saved: Dictionary) -> void:
	GameManager.current_state = int(saved.get("state", GameManager.GameState.TITLE))
	GameManager.current_score = int(saved.get("score", 0))
	GameManager.best_score = int(saved.get("best", 0))


func _collect_events() -> void:
	_dropped_events.clear()
	_collected_events.clear()
	_activated_events.clear()
	_expired_events.clear()
	if not EventBus.pickup_dropped.is_connected(_on_dropped):
		EventBus.pickup_dropped.connect(_on_dropped)
	if not EventBus.pickup_collected.is_connected(_on_collected):
		EventBus.pickup_collected.connect(_on_collected)
	if not EventBus.pickup_activated.is_connected(_on_activated):
		EventBus.pickup_activated.connect(_on_activated)
	if not EventBus.pickup_expired.is_connected(_on_expired):
		EventBus.pickup_expired.connect(_on_expired)


func _stop_collect_events() -> void:
	if EventBus.pickup_dropped.is_connected(_on_dropped):
		EventBus.pickup_dropped.disconnect(_on_dropped)
	if EventBus.pickup_collected.is_connected(_on_collected):
		EventBus.pickup_collected.disconnect(_on_collected)
	if EventBus.pickup_activated.is_connected(_on_activated):
		EventBus.pickup_activated.disconnect(_on_activated)
	if EventBus.pickup_expired.is_connected(_on_expired):
		EventBus.pickup_expired.disconnect(_on_expired)


func _on_dropped(data: Dictionary) -> void:
	_dropped_events.append(data)


func _on_collected(data: Dictionary) -> void:
	_collected_events.append(data)


func _on_activated(data: Dictionary) -> void:
	_activated_events.append(data)


func _on_expired(data: Dictionary) -> void:
	_expired_events.append(data)
