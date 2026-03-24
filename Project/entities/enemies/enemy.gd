class_name Enemy
extends GridEntity

var hp: int = 1
var attack_cost: int = 1
var enemy_type: String = "wanderer"
var enemy_shape: String = "square"
var brain: EnemyBrain = EnemyBrain.new()
var enemy_color: Color = Color(0.8, 0.1, 0.3)
var carried_status: String = ""  # 敌人携带的状态
var attack_cooldown_remaining: int = 0
var _color_rect: ColorRect
var _status_overlay: ColorRect
var _border_rect: ColorRect
var _status_tween: Tween
var _tick_connected: bool = false
var _move_accumulator: float = 0.0


func _init() -> void:
	entity_type = Constants.EntityType.ENEMY
	blocks_movement = false
	is_solid = true
	cell_layer = 1


func _ready() -> void:
	_build_visual()

	if not _tick_connected:
		EventBus.tick_post_process.connect(_on_tick_post_process)
		_tick_connected = true

	EventBus.status_applied.connect(_on_status_applied)
	EventBus.status_removed.connect(_on_status_removed)
	EventBus.status_expired.connect(_on_status_removed)


func _build_visual() -> void:
	var s: float = Constants.CELL_SIZE * 0.75
	match enemy_shape:
		"diamond":
			# 菱形：旋转 45°，缩小补偿对角线
			_color_rect = ColorRect.new()
			var ds: float = s * 0.7
			_color_rect.size = Vector2(ds, ds)
			_color_rect.position = Vector2(-ds / 2, -ds / 2)
			_color_rect.color = enemy_color
			_color_rect.rotation = PI / 4.0
			add_child(_color_rect)
		"cross":
			# 十字形：两个交叉 ColorRect
			var arm_w: float = s * 0.35
			var arm_l: float = s
			_color_rect = ColorRect.new()
			_color_rect.size = Vector2(arm_l, arm_w)
			_color_rect.position = Vector2(-arm_l / 2, -arm_w / 2)
			_color_rect.color = enemy_color
			add_child(_color_rect)
			var vert := ColorRect.new()
			vert.size = Vector2(arm_w, arm_l)
			vert.position = Vector2(-arm_w / 2, -arm_l / 2)
			vert.color = enemy_color
			add_child(vert)
		_:
			# 方形（wanderer 及默认）
			_color_rect = ColorRect.new()
			_color_rect.size = Vector2(s, s)
			_color_rect.position = Vector2(-s / 2, -s / 2)
			_color_rect.color = enemy_color
			add_child(_color_rect)

	# 状态视觉层（与 _color_rect 同尺寸，覆盖在上方）
	var full: float = Constants.CELL_SIZE
	var border: float = 3.0
	_border_rect = ColorRect.new()
	_border_rect.size = Vector2(full + border * 2, full + border * 2)
	_border_rect.position = Vector2(-full / 2 - border, -full / 2 - border)
	_border_rect.color = Color(1.0, 0.3, 0.0, 0.0)  # 初始透明
	_border_rect.z_index = -1
	add_child(_border_rect)

	_status_overlay = ColorRect.new()
	_status_overlay.size = Vector2(s, s)
	_status_overlay.position = Vector2(-s / 2, -s / 2)
	_status_overlay.color = Color(0, 0, 0, 0)  # 初始透明
	add_child(_status_overlay)


func setup_from_config(type_id: String) -> void:
	enemy_type = type_id
	brain = _create_brain(type_id)
	var cfg: Dictionary = ConfigManager.get_enemy_type(type_id)
	if cfg.is_empty():
		return
	hp = int(cfg.get("hp", 1))
	attack_cost = int(cfg.get("attack_cost", 1))
	var color_hex: String = cfg.get("color", "#CC1A4D")
	enemy_color = Color.from_string(color_hex, Color(0.8, 0.1, 0.3))
	enemy_shape = cfg.get("shape", "square")
	if _color_rect:
		_color_rect.color = enemy_color


func set_carried_status_visual(type: String) -> void:
	## 设置携带状态并更新视觉
	carried_status = type
	_apply_status_visual()


func clear_carried_status() -> void:
	carried_status = ""
	_clear_status_visual()


func _apply_status_visual() -> void:
	_clear_status_visual()
	if carried_status == "":
		return

	match carried_status:
		"fire":
			if _border_rect:
				_border_rect.color = Color(1.0, 0.3, 0.0, 0.9)
			if _status_overlay:
				_status_overlay.color = Color(1.0, 0.4, 0.1, 0.3)
			if is_inside_tree():
				_status_tween = create_tween().set_loops()
				_status_tween.tween_property(_border_rect, "color:a", 0.3, 0.25)
				_status_tween.tween_property(_border_rect, "color:a", 0.9, 0.25)
		"ice":
			if _status_overlay:
				_status_overlay.color = Color(0.4, 0.6, 1.0, 0.55)
		"poison":
			if _status_overlay:
				_status_overlay.color = Color(0.2, 0.8, 0.1, 0.45)
			if is_inside_tree():
				_status_tween = create_tween().set_loops()
				_status_tween.tween_property(_status_overlay, "color:a", 0.25, 0.5)
				_status_tween.tween_property(_status_overlay, "color:a", 0.55, 0.5)


func _clear_status_visual() -> void:
	if _status_tween and _status_tween.is_valid():
		_status_tween.kill()
		_status_tween = null
	if _status_overlay:
		_status_overlay.color = Color(0, 0, 0, 0)
	if _border_rect:
		_border_rect.color = Color(1.0, 0.3, 0.0, 0.0)


func _on_status_applied(data: Dictionary) -> void:
	if data.get("target") != self:
		return
	var type: String = data.get("type", "")
	if type != "":
		set_carried_status_visual(type)


func _on_status_removed(data: Dictionary) -> void:
	if data.get("target") != self:
		return
	var type: String = data.get("type", "")
	if type == carried_status:
		clear_carried_status()


func _create_brain(type_id: String) -> EnemyBrain:
	match type_id:
		"wanderer":
			return WandererBrain.new()
		"chaser":
			return ChaserBrain.new()
		"bog_crawler":
			return BogCrawlerBrain.new()
		_:
			return EnemyBrain.new()


func _on_tick_post_process(_tick_index: int) -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return

	# 计算本 tick 有效速度
	var effective_speed: float = _get_effective_speed()

	# 累加器模式：支持小数速度（0.5 = 每 2 tick 移动一次）
	_move_accumulator += effective_speed
	while _move_accumulator >= 1.0:
		_move_accumulator -= 1.0
		if not is_instance_valid(self) or not is_inside_tree():
			break
		var context: Dictionary = EnemyBrain.build_context(self)
		var decision: Dictionary = brain.decide(self, context)
		_execute_decision(decision)


func _get_effective_speed() -> float:
	## 计算本 tick 的有效速度（基础 + 威胁加速 + 毒液加速）
	var cfg: Dictionary = ConfigManager.get_enemy_type(enemy_type)
	var base_speed: float = cfg.get("speed", 1.0)

	# 威胁加速：检查蛇头是否在 threat_range 内
	var threat_bonus: float = float(cfg.get("threat_speed_bonus", 0))
	if threat_bonus > 0.0:
		var threat_range: int = int(cfg.get("threat_range", 3))
		var context: Dictionary = EnemyBrain.build_context(self)
		var snake_head: Vector2i = context.get("snake_head", Vector2i(-1, -1))
		if snake_head != Vector2i(-1, -1):
			var dist: int = Pathfinding.manhattan_distance(grid_position, snake_head)
			if dist <= threat_range:
				base_speed += threat_bonus

	# 毒液格加速
	var poison_bonus := _get_poison_speed_bonus()
	if poison_bonus > 0:
		base_speed += float(poison_bonus)

	return base_speed


func _execute_decision(decision: Dictionary) -> void:
	var action: String = decision.get("action", "idle")
	var dir: Vector2i = decision.get("direction", Vector2i.ZERO)

	if action == "attack":
		var target_seg = decision.get("target_segment")
		if target_seg and is_instance_valid(target_seg):
			_attack_segment(target_seg)
	elif action == "move" and dir != Vector2i.ZERO:
		var new_pos: Vector2i = grid_position + dir
		if GridWorld.is_within_bounds(new_pos) and not GridWorld.is_cell_blocked(new_pos) and not _is_occupied_for_enemy(new_pos):
			var old_pos: Vector2i = grid_position
			remove_from_grid()
			place_on_grid(new_pos)
			EventBus.entity_moved.emit({
				"entity": self,
				"from": old_pos,
				"to": new_pos,
			})
		# 移动时递减攻击冷却
		if attack_cooldown_remaining > 0:
			attack_cooldown_remaining -= 1

	EventBus.enemy_action_decided.emit({
		"enemy": self,
		"action": action,
		"direction": dir,
	})


func _attack_segment(segment: SnakeSegment) -> void:
	## 攻击蛇身段：造成 hit + 状态传播
	var cfg: Dictionary = ConfigManager.get_enemy_type(enemy_type)
	var damage: int = int(cfg.get("attack_damage", 1))
	var cooldown: int = int(cfg.get("attack_cooldown", 0))

	# === 攻击 VFX：冲撞 + 爆裂 + 屏幕震动 ===
	var seg_world_pos: Vector2 = GridWorld.grid_to_world(segment.grid_position)
	VFXManager.lunge_toward(self, seg_world_pos)
	VFXManager.burst_at(seg_world_pos, Color(1.0, 0.2, 0.2), 20.0, 0.15)
	VFXManager.flash_entity(segment, Color(1.5, 0.3, 0.3))
	VFXManager.screen_shake(1.5, 0.05)

	# 找到蛇节点
	var snake_node: Snake = segment.get_parent() as Snake
	if snake_node:
		snake_node.take_hit(damage)

	# 双向状态传播：蛇段↔敌人
	var seg_status: String = segment.carried_status
	var enemy_status: String = carried_status

	if seg_status != "" and enemy_status == "":
		# 蛇段有状态 + 敌人无状态 → 敌人沾染蛇段状态
		set_carried_status_visual(seg_status)
	elif seg_status == "" and enemy_status != "":
		# 敌人有状态 + 段无状态 → 段获得敌人状态
		segment.set_carried_status(enemy_status)
	elif seg_status != "" and enemy_status != "":
		if seg_status == enemy_status:
			# 同类 → 无事发生
			pass
		else:
			# 异类 → 触发反应，双方状态清除
			EventBus.reaction_triggered.emit({
				"reaction_id": _get_reaction_id(enemy_status, seg_status),
				"position": segment.grid_position,
				"type_a": enemy_status,
				"type_b": seg_status,
			})
			segment.clear_carried_status()
			clear_carried_status()

	# 设置冷却
	if cooldown > 0:
		attack_cooldown_remaining = cooldown

	EventBus.snake_body_attacked.emit({
		"position": segment.grid_position,
		"segment": segment,
		"enemy": self,
		"enemy_status": enemy_status,
		"seg_status": seg_status,
	})


static func _get_reaction_id(type_a: String, type_b: String) -> String:
	## 根据两种状态类型返回反应 ID
	var pair: Array = [type_a, type_b]
	pair.sort()
	if pair == ["fire", "ice"]:
		return "steam"
	elif pair == ["fire", "poison"]:
		return "toxic_explosion"
	elif pair == ["ice", "poison"]:
		return "frozen_plague"
	return ""


func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		die()


func die() -> void:
	if _tick_connected:
		EventBus.tick_post_process.disconnect(_on_tick_post_process)
		_tick_connected = false
	_on_death_effect()
	EventBus.enemy_killed.emit({
		"enemy_def": self,
		"position": grid_position,
		"method": "snake_collision",
	})
	remove_from_grid()
	# 死亡动画：缩小消失
	_play_death_animation()


func _on_death_effect() -> void:
	## 死亡时特殊效果（子类行为通过 config 驱动）
	var cfg: Dictionary = ConfigManager.get_enemy_type(enemy_type)
	var death_tiles: int = int(cfg.get("death_poison_tiles", 0))
	if death_tiles <= 0:
		return

	if StatusEffectManager.tile_manager == null:
		return
	var tile_mgr: StatusTileManager = StatusEffectManager.tile_manager
	var pos: Vector2i = grid_position

	# 在死亡位置放第一格毒
	tile_mgr.place_tile(pos, "poison")
	var placed: int = 1

	# 在相邻格随机放剩余毒液格
	var neighbors: Array[Vector2i] = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var np: Vector2i = pos + d
		if GridWorld.is_within_bounds(np):
			neighbors.append(np)
	neighbors.shuffle()
	for np in neighbors:
		if placed >= death_tiles:
			break
		tile_mgr.place_tile(np, "poison")
		placed += 1


func _get_poison_speed_bonus() -> int:
	## 检查是否在毒液格上并返回额外移动次数
	var cfg: Dictionary = ConfigManager.get_enemy_type(enemy_type)
	var bonus: int = int(cfg.get("poison_speed_bonus", 0))
	if bonus <= 0:
		return 0

	if StatusEffectManager.tile_manager == null:
		return 0
	if StatusEffectManager.tile_manager.has_tile(grid_position, "poison"):
		return bonus
	return 0


func _play_death_animation() -> void:
	# 白色闪光
	var flash := ColorRect.new()
	flash.size = Vector2(Constants.CELL_SIZE, Constants.CELL_SIZE)
	flash.position = Vector2(-Constants.CELL_SIZE / 2, -Constants.CELL_SIZE / 2)
	flash.color = Color(1, 1, 1, 0.8)
	flash.z_index = 10
	# 闪光需要挂到父节点（因为 self 即将 free）
	var p: Node = get_parent()
	if p and is_instance_valid(p):
		var flash_holder := Node2D.new()
		flash_holder.global_position = global_position
		p.add_child(flash_holder)
		flash_holder.add_child(flash)
		var tw: Tween = flash_holder.create_tween()
		tw.tween_property(flash, "color:a", 0.0, 0.3)
		tw.tween_callback(flash_holder.queue_free)

	# 自身缩小消失
	var death_tw: Tween = create_tween()
	death_tw.tween_property(self, "scale", Vector2.ZERO, 0.2)
	death_tw.tween_callback(queue_free)


static func _is_occupied_for_enemy(pos: Vector2i) -> bool:
	var entities: Array = GridWorld.get_entities_at(pos)
	for e in entities:
		if is_instance_valid(e) and (e is Enemy or e is Food):
			return true
	return false
