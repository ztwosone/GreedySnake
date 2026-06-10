class_name EnemyManager
extends Node
## spec 002 T020（RoomDirector 前置契约，增量改造——默认行为与 L1/L2 完全一致）：
## - respawn_policy："maintain"（默认）= 击杀即补怪、永续维持 max_enemy_count；
##   "room_budget" = 生成既定一批后不自动补怪（RoomDirector 按房型布怪用）。
## - spawn_budget：room_budget 档剩余可生成数（-1 = 不限）；spawn_enemy 成功生成消耗 1，
##   归零后拒绝生成。spawn_enemy_at 是脚本定点放置（l1/l2 验收场景、触发原子），不消耗预算。
## - 注入式权重表：set_spawn_weights() 覆盖 enemy.spawn_weights（空表 = 回退配置）；
##   RoomDirector 以 floor_themes.<id>.enemy_pool_weights 注入主题敌池。
## - spawn_hp_bonus（T030）：随机生成的敌人在 config hp 之上加成（FR-008 静态层 HP 压力，
##   RoomDirector 每房按 DifficultyScaler.get_enemy_hp_bonus() 写入；默认 0 保 L1/L2）。
##   spawn_enemy_at 是脚本定点放置（l1/l2 验收场景、触发原子），不吃加成。

var max_enemy_count: int = 3
var current_enemies: Array[Enemy] = []
var enemy_container: Node2D
var snake: Snake
var food_manager: FoodManager = null
var collision_handler: Node = null  ## CollisionHandler
var respawn_policy: String = "maintain"
var spawn_budget: int = -1
var spawn_hp_bonus: int = 0
var _spawn_weights_override: Dictionary = {}
const SPAWN_SAFE_DISTANCE: int = 3


func _ready() -> void:
	EventBus.snake_hit_enemy.connect(_on_snake_hit_enemy)
	EventBus.enemy_killed.connect(_on_enemy_killed)


func init_enemies(count: int) -> void:
	max_enemy_count = count
	for i in range(count):
		spawn_enemy(_pick_random_type())


## 覆盖随机生成权重表（T020）：空表 = 回退 enemy.spawn_weights 配置
func set_spawn_weights(weights: Dictionary) -> void:
	_spawn_weights_override = weights.duplicate(true)


func spawn_enemy(type_id: String = "wanderer") -> void:
	if respawn_policy == "room_budget" and spawn_budget == 0:
		return
	var empty_cells: Array[Vector2i] = GridWorld.get_empty_cells()
	if empty_cells.is_empty():
		return

	# Filter out cells too close to snake head
	var safe_cells: Array[Vector2i] = []
	var snake_head: Vector2i = snake.body[0] if snake and not snake.body.is_empty() else Vector2i(-100, -100)
	for cell in empty_cells:
		var dist: int = abs(cell.x - snake_head.x) + abs(cell.y - snake_head.y)
		if dist > SPAWN_SAFE_DISTANCE:
			safe_cells.append(cell)

	# Fall back to all empty cells if no safe cells
	var candidates: Array[Vector2i] = safe_cells if not safe_cells.is_empty() else empty_cells
	var pos: Vector2i = candidates[randi() % candidates.size()]

	var enemy := Enemy.new()
	enemy.setup_from_config(type_id)
	enemy.hp += maxi(0, spawn_hp_bonus)
	enemy.collision_handler = collision_handler
	enemy.place_on_grid(pos)
	if enemy_container:
		enemy_container.add_child(enemy)
	current_enemies.append(enemy)
	if respawn_policy == "room_budget" and spawn_budget > 0:
		spawn_budget -= 1
	EventBus.enemy_spawned.emit({"enemy_def": enemy, "position": pos, "type": type_id})


func _on_snake_hit_enemy(data: Dictionary) -> void:
	var enemy = data.get("enemy")
	if not enemy or not is_instance_valid(enemy):
		return

	# === 吞噬状态反应（委托 CollisionHandler） ===
	if snake and not snake.segments.is_empty() and is_instance_valid(snake.segments[0]):
		var head_seg: SnakeSegment = snake.segments[0]
		if collision_handler:
			collision_handler.handle_collision("head_eat_enemy", head_seg, enemy)
		else:
			# Legacy fallback
			var head_status: String = head_seg.carried_status
			var enemy_status: String = enemy.carried_status if enemy.carried_status else ""
			if head_status != "" and enemy_status != "" and head_status != enemy_status:
				head_seg.clear_carried_status()
				enemy.clear_carried_status()

	# === 吞噬 VFX ===
	# 蛇头 scale bounce
	if snake and not snake.segments.is_empty() and is_instance_valid(snake.segments[0]):
		VFXManager.scale_bounce(snake.segments[0], 1.3, 0.15)
	# 极短暂停（打击感）
	VFXManager.hit_stop(0.02)

	# Snake eats enemy
	enemy.take_damage(enemy.hp)



func _spawn_food_drops(center: Vector2i, count: int) -> void:
	## 在 center 及其周围空格生成食物
	var candidates: Array[Vector2i] = []
	# 中心优先
	if GridWorld.is_within_bounds(center) and GridWorld.get_entities_at(center).is_empty():
		candidates.append(center)
	# 四邻
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var pos: Vector2i = center + dir
		if GridWorld.is_within_bounds(pos) and GridWorld.get_entities_at(pos).is_empty():
			candidates.append(pos)
	# 对角
	for dir in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var pos: Vector2i = center + dir
		if GridWorld.is_within_bounds(pos) and GridWorld.get_entities_at(pos).is_empty():
			candidates.append(pos)
	# 打乱顺序
	candidates.shuffle()
	var spawned: int = 0
	for pos in candidates:
		if spawned >= count:
			break
		food_manager.spawn_food_at(pos)
		spawned += 1


func _on_enemy_killed(data: Dictionary) -> void:
	var enemy = data.get("enemy_def")
	var pos: Vector2i = data.get("position", Vector2i.ZERO)
	# 掉落食物（无论何种方式击杀）
	_drop_food_for_enemy(enemy, pos)
	if enemy and enemy in current_enemies:
		current_enemies.erase(enemy)
	# Respawn to maintain count（仅 maintain 档——room_budget 档清完即清，T020）
	if respawn_policy == "maintain" and current_enemies.size() < max_enemy_count:
		spawn_enemy(_pick_random_type())


func _drop_food_for_enemy(enemy: Node, pos: Vector2i) -> void:
	if not food_manager or enemy == null:
		return
	var type_id: String = enemy.get("enemy_type") if enemy.get("enemy_type") else "wanderer"
	var cfg: Dictionary = ConfigManager.get_enemy_type(type_id)
	var drop_count: int = int(cfg.get("drop_food_count", 0))
	# 蛇头食物掉落修改器（九头蛇: -99 → 0 掉落）
	if snake and StatusEffectManager:
		var food_mod: int = int(StatusEffectManager.get_modifier("food_drop", snake, 0.0))
		drop_count = max(0, drop_count + food_mod)
	if drop_count <= 0:
		return
	_spawn_food_drops(pos, drop_count)


func _pick_random_type() -> String:
	var weights: Dictionary = _spawn_weights_override
	if weights.is_empty():
		weights = ConfigManager.enemy.get("spawn_weights", {})
	if weights.is_empty():
		return "wanderer"
	var total: float = 0.0
	for w in weights.values():
		total += maxf(0.0, float(w))
	if total <= 0.0:
		return "wanderer"
	var roll: float = randf() * total
	for type_id in weights:
		roll -= maxf(0.0, float(weights[type_id]))
		if roll < 0.0:
			return str(type_id)
	return str(weights.keys().back())


func spawn_enemy_at(type_id: String, pos: Vector2i) -> Enemy:
	var enemy := Enemy.new()
	enemy.setup_from_config(type_id)
	enemy.collision_handler = collision_handler
	enemy.place_on_grid(pos)
	if enemy_container:
		enemy_container.add_child(enemy)
	current_enemies.append(enemy)
	EventBus.enemy_spawned.emit({"enemy_def": enemy, "position": pos, "type": type_id})
	return enemy


func clear_enemies() -> void:
	for enemy in current_enemies:
		if is_instance_valid(enemy):
			enemy.remove_from_grid()
			enemy.queue_free()
	current_enemies.clear()
