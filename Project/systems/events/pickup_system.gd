extends Node
## spec 003 M4（T018，判决：修+补实体层；US3 SHOULD）：事件拾取系统。
## v1 = broken_eye ONLY（serpent_scale 配置 enabled=false，backlog.md 收容）。
##
## 草稿三缺陷修复（plan.md 判决表）：
## - `_on_enemy_killed` 节点判型：enemy_def 是 Enemy 节点（同 ShedskinSystem 口径，
##   兼容 String/Dictionary 测试形态）——草稿把节点当 Dictionary 判型 = 生产零掉落死代码；
## - elite 判定走 ConfigManager.get_enemy_type(...).is_elite（草稿 `enemy_type != "elite"`
##   字符串比对，配置里不存在该字面量）；
## - randf 顺序：先判 elite 再掷骰——非精英零 RNG 消耗（定种子可证）。
##
## 实体层（仿 food）：掉落 = PickupEntity 网格实体（GridWorld 占格，cell_layer 0），
## 占用格偏移最近空格（BFS，spec Edge Case；enemy_killed 派发时刚死的敌人仍占格——
## exclude 参数排除尸格，碎片落在击杀位）；蛇头进入拾取（snake_moved.head_pos 命中）。
##
## 携带/激活模型（Designs §9.4，激活路线 A/B 入 backlog）：
## - 拾取 = 携带（active=false），携带效果即时生效（broken_eye：carry_effect =
##   "enemy_intent" → DangerIndicator 监听 pickup_collected/expired 显示敌人下一步方向）；
## - 携带倒数 duration_rooms：room_completed 递减，归零过期（pickup_expired
##   reason=rooms_exhausted）；
## - activate_pickup 幂等（active 字段 + pickup_activated 事件 = 模型缝）；激活者
##   免房间倒数、免层末清除；
## - FR-008：floor_completed 清除未激活携带（reason=floor_transition）+ 地面残留；
## - room_entered 清地面残留（房间重布景，与 RoomDirector 清敌清食同口径）；
## - run_started 全量重置（FR-013 风格）。
## 全数值走 JSON（event_pickups 段）；通信 EventBus-only（FR-011）；无 class_name（C.8）。

const PickupEntityScript := preload("res://entities/pickups/pickup_entity.gd")

## 实体挂载层（game_world 注入 EntityContainer；未注入挂本节点——单元测试形态）
var _entity_parent: Node = null
## 地面碎片：[{instance_id, pickup_id, display_name, carry_effect, duration_rooms,
##            position, entity}]
var _ground: Array = []
## 携带碎片：[{instance_id, pickup_id, display_name, carry_effect, rooms_remaining, active}]
var _carried: Array = []
var _next_instance: int = 0


func _ready() -> void:
	connect_events()


func _exit_tree() -> void:
	disconnect_events()


func setup(entity_parent: Node) -> void:
	_entity_parent = entity_parent


func connect_events() -> void:
	if not EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.connect(_on_enemy_killed)
	if not EventBus.snake_moved.is_connected(_on_snake_moved):
		EventBus.snake_moved.connect(_on_snake_moved)
	if not EventBus.room_entered.is_connected(_on_room_entered):
		EventBus.room_entered.connect(_on_room_entered)
	if not EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.connect(_on_room_completed)
	if not EventBus.floor_completed.is_connected(_on_floor_completed):
		EventBus.floor_completed.connect(_on_floor_completed)
	if not EventBus.run_started.is_connected(_on_run_started):
		EventBus.run_started.connect(_on_run_started)


func disconnect_events() -> void:
	if EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.disconnect(_on_enemy_killed)
	if EventBus.snake_moved.is_connected(_on_snake_moved):
		EventBus.snake_moved.disconnect(_on_snake_moved)
	if EventBus.room_entered.is_connected(_on_room_entered):
		EventBus.room_entered.disconnect(_on_room_entered)
	if EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.disconnect(_on_room_completed)
	if EventBus.floor_completed.is_connected(_on_floor_completed):
		EventBus.floor_completed.disconnect(_on_floor_completed)
	if EventBus.run_started.is_connected(_on_run_started):
		EventBus.run_started.disconnect(_on_run_started)


## 精英击杀掉落。顺序契约（T017）：enabled → elite 判定 → 掷骰——非精英零 RNG 消耗。
## exclude = 占格检查排除项（enemy_killed 派发时刚死的敌人仍在格上）。
## 返回掉落的 pickup_id（"" = 未掉落）。
func try_drop_pickup(enemy_type: String, position: Vector2i, exclude: Node = null) -> String:
	var cfg: Dictionary = ConfigManager.get_event_pickups_config()
	if not cfg.get("enabled", false):
		return ""
	if not bool(ConfigManager.get_enemy_type(enemy_type).get("is_elite", false)):
		return ""
	if randf() > float(cfg.get("drop_chance", 0.5)):
		return ""

	var pickup_id: String = _pick_droppable_id(cfg)
	if pickup_id == "":
		return ""
	var def: Dictionary = cfg.get("pickups", {}).get(pickup_id, {})
	var drop_pos: Vector2i = _resolve_drop_position(position, exclude)

	var entity: Node2D = PickupEntityScript.new()
	entity.setup(pickup_id, def)
	entity.place_on_grid(drop_pos)
	var parent: Node = _entity_parent if _entity_parent != null else self
	parent.add_child(entity)

	_next_instance += 1
	var record: Dictionary = {
		"instance_id": "%s_%d" % [pickup_id, _next_instance],
		"pickup_id": pickup_id,
		"display_name": str(def.get("display_name", "")),
		"carry_effect": str(def.get("carry_effect", "")),
		"duration_rooms": int(def.get("duration_rooms", 1)),
		"position": drop_pos,
		"entity": entity,
	}
	_ground.append(record)

	EventBus.pickup_dropped.emit({
		"pickup_id": pickup_id,
		"instance_id": record["instance_id"],
		"position": drop_pos,
		"display_name": record["display_name"],
	})
	return pickup_id


## 蛇头进入拾取（snake_moved 路径与测试直驱共用）。返回拾取的 pickup_id（"" = 该格无碎片）
func collect_pickup_at(position: Vector2i) -> String:
	for i in range(_ground.size()):
		var record: Dictionary = _ground[i]
		if record.get("position", Vector2i(-1, -1)) != position:
			continue
		_ground.remove_at(i)
		_free_entity(record)
		var carried: Dictionary = {
			"instance_id": record.get("instance_id", ""),
			"pickup_id": record.get("pickup_id", ""),
			"display_name": record.get("display_name", ""),
			"carry_effect": record.get("carry_effect", ""),
			"rooms_remaining": int(record.get("duration_rooms", 1)),
			"active": false,
		}
		_carried.append(carried)
		EventBus.pickup_collected.emit({
			"pickup_id": carried["pickup_id"],
			"instance_id": carried["instance_id"],
			"display_name": carried["display_name"],
			"carry_effect": carried["carry_effect"],
			"rooms_remaining": carried["rooms_remaining"],
		})
		return str(carried["pickup_id"])
	return ""


## 激活（幂等）：模型缝保留——v1 无激活路线内容（backlog），激活者免倒数/免层末清除
func activate_pickup(pickup_id: String) -> bool:
	for pickup in _carried:
		if pickup.get("pickup_id", "") == pickup_id and not bool(pickup.get("active", false)):
			pickup["active"] = true
			EventBus.pickup_activated.emit({
				"pickup_id": pickup_id,
				"instance_id": pickup.get("instance_id", ""),
			})
			return true
	return false


func get_ground_pickups() -> Array:
	var result: Array = []
	for record in _ground:
		result.append({
			"instance_id": record.get("instance_id", ""),
			"pickup_id": record.get("pickup_id", ""),
			"display_name": record.get("display_name", ""),
			"position": record.get("position", Vector2i.ZERO),
		})
	return result


func get_carried_pickups() -> Array:
	var result: Array = []
	for pickup in _carried:
		result.append(pickup.duplicate())
	return result


func has_carried(pickup_id: String) -> bool:
	for pickup in _carried:
		if pickup.get("pickup_id", "") == pickup_id:
			return true
	return false


## 携带效果是否在场（携带即生效，Designs §9.4 持有效果；激活不影响携带效果）
func is_carry_effect_active(effect: String) -> bool:
	for pickup in _carried:
		if str(pickup.get("carry_effect", "")) == effect:
			return true
	return false


func cleanup() -> void:
	_clear_ground()
	_carried.clear()
	disconnect_events()


# === 内部 ===

## v1 可掉池 = enabled 项（恰 broken_eye）；多项时随机取（v1 单项 = 零额外 RNG）
func _pick_droppable_id(cfg: Dictionary) -> String:
	var pickups: Dictionary = cfg.get("pickups", {})
	var enabled_ids: Array = []
	for pickup_id in pickups:
		if bool(pickups[pickup_id].get("enabled", false)):
			enabled_ids.append(pickup_id)
	if enabled_ids.is_empty():
		return ""
	enabled_ids.sort()
	if enabled_ids.size() == 1:
		return enabled_ids[0]
	return enabled_ids[randi() % enabled_ids.size()]


## 占用格偏移最近空格（BFS，曼哈顿环序；exclude 排除刚死的敌人）；无空格回退原位
func _resolve_drop_position(position: Vector2i, exclude: Node) -> Vector2i:
	if _is_cell_free(position, exclude):
		return position
	var queue: Array = [position]
	var visited: Dictionary = {position: true}
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for dir in Constants.DIR_VECTORS.values():
			var next: Vector2i = current + dir
			if visited.has(next) or not GridWorld.is_within_bounds(next):
				continue
			visited[next] = true
			if _is_cell_free(next, exclude):
				return next
			queue.append(next)
	return position


func _is_cell_free(position: Vector2i, exclude: Node) -> bool:
	if not GridWorld.is_within_bounds(position):
		return false
	for entity in GridWorld.get_entities_at(position):
		if entity != exclude:
			return false
	return true


func _free_entity(record: Dictionary) -> void:
	var entity = record.get("entity")
	if entity != null and is_instance_valid(entity):
		entity.remove_from_grid()
		entity.queue_free()


func _clear_ground() -> void:
	for record in _ground:
		_free_entity(record)
	_ground.clear()


func _expire(pickup: Dictionary, reason: String) -> void:
	EventBus.pickup_expired.emit({
		"pickup_id": pickup.get("pickup_id", ""),
		"instance_id": pickup.get("instance_id", ""),
		"reason": reason,
	})


# === 事件 ===

## enemy_killed 的 enemy_def 是 Enemy 节点（兼容 String/Dictionary 形态的测试 payload，
## 同 ShedskinSystem._resolve_enemy_type 口径）；尸格经 exclude 排除
func _on_enemy_killed(data: Dictionary) -> void:
	var enemy_def = data.get("enemy_def")
	var exclude: Node = enemy_def if enemy_def is Node else null
	try_drop_pickup(_resolve_enemy_type(enemy_def),
		data.get("position", Vector2i.ZERO), exclude)


func _resolve_enemy_type(enemy_def: Variant) -> String:
	if enemy_def is String:
		return enemy_def
	if enemy_def is Dictionary:
		return str(enemy_def.get("enemy_type", ""))
	if enemy_def is Object and is_instance_valid(enemy_def) and "enemy_type" in enemy_def:
		return str(enemy_def.enemy_type)
	return ""


func _on_snake_moved(data: Dictionary) -> void:
	if _ground.is_empty():
		return
	collect_pickup_at(data.get("head_pos", Vector2i(-1, -1)))


## 房间重布景：未拾取的地面碎片随旧房清场（RoomDirector 清敌清食同口径）
func _on_room_entered(_data: Dictionary) -> void:
	_clear_ground()


## 携带倒数：未激活者每房 -1，归零过期（duration_rooms，FR-010 JSON）
func _on_room_completed(_data: Dictionary) -> void:
	var expired: Array = []
	for pickup in _carried:
		if bool(pickup.get("active", false)):
			continue
		pickup["rooms_remaining"] = int(pickup.get("rooms_remaining", 0)) - 1
		if int(pickup["rooms_remaining"]) <= 0:
			expired.append(pickup)
	for pickup in expired:
		_carried.erase(pickup)
		_expire(pickup, "rooms_exhausted")


## FR-008：层结束清除未激活携带 + 地面残留；激活者跨层存续
func _on_floor_completed(_data: Dictionary) -> void:
	_clear_ground()
	var expired: Array = []
	for pickup in _carried:
		if not bool(pickup.get("active", false)):
			expired.append(pickup)
	for pickup in expired:
		_carried.erase(pickup)
		_expire(pickup, "floor_transition")


## FR-013 风格：run 重启全量重置（无过期事件——世界重建，监听方各自随 run_started 复位）
func _on_run_started(_data: Dictionary) -> void:
	_clear_ground()
	_carried.clear()
