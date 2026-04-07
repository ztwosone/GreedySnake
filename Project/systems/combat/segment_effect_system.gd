class_name SegmentEffectSystem
extends Node

## 蛇段状态增益系统
## 火：光环伤敌（tick 时检测火段周围敌人）
## 毒：蔓延（每 N tick 毒段向随机邻格蔓延毒状态格）
## 冰：防御效果在 Enemy._attack_segment 中处理

var snake: Snake = null
var enemy_manager: EnemyManager = null
var tile_manager: StatusTileManager = null
var reaction_resolver: Node = null  ## ReactionResolver

var _aura_damage: int = 1
var _spread_interval: int = 3
var _spread_counters: Dictionary = {}  # SnakeSegment -> int

const SPREAD_DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


func _ready() -> void:
	EventBus.tick_post_process.connect(_on_tick_post_process)
	# 从 config 读取火光环伤害
	var fire_cfg: Dictionary = ConfigManager.get_status_effect("fire")
	_aura_damage = int(fire_cfg.get("aura_damage", 1))
	# 从 config 读取毒蔓延间隔
	var poison_cfg: Dictionary = ConfigManager.get_status_effect("poison")
	_spread_interval = int(poison_cfg.get("trail_interval", 3))


func _on_tick_post_process(_tick_index: int) -> void:
	if snake == null or enemy_manager == null:
		return
	_process_fire_aura()
	_process_poison_spread()
	_process_poison_tile_damage()


func _process_fire_aura() -> void:
	## 火光环：火段周围有敌人则造成伤害
	# T31 鳞片修改器
	var bonus_damage: int = int(StatusEffectManager.get_modifier("fire_aura_damage", snake, 0.0))
	var actual_damage: int = _aura_damage + bonus_damage
	var aura_range: int = 1 + int(StatusEffectManager.get_modifier("fire_aura_range", snake, 0.0))

	for seg in snake.segments:
		if not is_instance_valid(seg):
			continue
		if not seg.has_status("fire"):
			continue
		var pos: Vector2i = seg.grid_position
		# 曼哈顿距离范围扫描
		for dx in range(-aura_range, aura_range + 1):
			for dy in range(-aura_range, aura_range + 1):
				if dx == 0 and dy == 0:
					continue
				if abs(dx) + abs(dy) > aura_range:
					continue
				var adj: Vector2i = pos + Vector2i(dx, dy)
				if not GridWorld.is_within_bounds(adj):
					continue
				var entities: Array = GridWorld.get_entities_at(adj)
				for e in entities:
					if is_instance_valid(e) and e is Enemy and e.hp > 0:
						# 火属性伤害：若敌人携带异类状态则触发反应
						var enemy_status: String = e.carried_status if e.carried_status else ""
						if enemy_status != "" and enemy_status != "fire":
							var reaction_id: String = ""
							if reaction_resolver:
								reaction_id = reaction_resolver.find_reaction("fire", enemy_status)
							if reaction_id != "":
								EventBus.reaction_triggered.emit({
									"reaction_id": reaction_id,
									"position": adj,
									"type_a": "fire",
									"type_b": enemy_status,
								})
							e.clear_carried_status()
						e.take_damage(actual_damage)


func _process_poison_spread() -> void:
	## 毒蔓延：每个毒段独立计数，满了向随机邻格蔓延毒状态格
	if snake == null or tile_manager == null:
		return

	# 收集蛇身位置用于排除
	var snake_positions: Dictionary = {}
	for seg in snake.segments:
		if is_instance_valid(seg):
			snake_positions[seg.grid_position] = true

	# 清理已失效的计数器
	var to_erase: Array = []
	for seg in _spread_counters:
		if not is_instance_valid(seg) or not seg.has_status("poison"):
			to_erase.append(seg)
	for seg in to_erase:
		_spread_counters.erase(seg)

	# 处理每个毒段
	for seg in snake.segments:
		if not is_instance_valid(seg) or not seg.has_status("poison"):
			continue

		if not _spread_counters.has(seg):
			_spread_counters[seg] = 0
		_spread_counters[seg] += 1
		# T31 毒液鳞修改器
		var spread_bonus: int = int(StatusEffectManager.get_modifier("poison_spread_bonus", snake, 0.0))
		var actual_interval: int = max(1, _spread_interval - spread_bonus)

		if _spread_counters[seg] >= actual_interval:
			_spread_counters[seg] = 0
			_try_spread_poison(seg.grid_position, snake_positions)


func _try_spread_poison(pos: Vector2i, snake_positions: Dictionary) -> void:
	## 从 pos 向随机邻格蔓延一格毒
	var candidates: Array[Vector2i] = []
	for dir in SPREAD_DIRS:
		var adj: Vector2i = pos + dir
		if not GridWorld.is_within_bounds(adj) or snake_positions.has(adj):
			continue
		# 跳过已有毒格的位置，让毒向外扩散
		var existing_tiles: Array = tile_manager.get_tiles_at(adj)
		var has_poison: bool = false
		for tile in existing_tiles:
			if is_instance_valid(tile) and tile.status_type == "poison":
				has_poison = true
				break
		if not has_poison:
			candidates.append(adj)
	if candidates.is_empty():
		return
	var target: Vector2i = candidates[randi() % candidates.size()]
	tile_manager.place_tile(target, "poison")


func _process_poison_tile_damage() -> void:
	## T31 毒液鳞 L3：毒格上的敌人受直接伤害
	var tile_dmg: int = int(StatusEffectManager.get_modifier("poison_tile_damage", snake, 0.0))
	if tile_dmg <= 0 or tile_manager == null:
		return
	for e in enemy_manager.current_enemies:
		if not is_instance_valid(e) or e.hp <= 0:
			continue
		var tiles: Array = tile_manager.get_tiles_at(e.grid_position)
		for tile in tiles:
			if is_instance_valid(tile) and tile.status_type == "poison":
				e.take_damage(tile_dmg)
				break  # 只算一次
