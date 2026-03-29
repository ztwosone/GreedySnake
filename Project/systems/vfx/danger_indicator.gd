class_name DangerIndicator
extends Node2D

## 敌人攻击范围指示器
## - 冷却=0时：周围格画淡红边框；蛇段在范围内则加深警告
## - 冷却中：敌人身上显示小冷却条

const CELL_SIZE: int = 32
const BORDER_WIDTH: float = 2.0
const IDLE_COLOR: Color = Color(1.0, 0.3, 0.3, 0.2)
const WARN_COLOR: Color = Color(1.0, 0.2, 0.2, 0.5)
const COOLDOWN_BAR_W: float = 20.0
const COOLDOWN_BAR_H: float = 3.0

var enemy_manager: EnemyManager = null
var snake: Snake = null

var _range_rects: Array[ColorRect] = []
var _range_active: int = 0
var _cd_bars: Dictionary = {}  # Enemy -> ColorRect


func _ready() -> void:
	z_index = 2
	EventBus.tick_post_process.connect(_on_tick)
	EventBus.enemy_killed.connect(_on_enemy_killed)


func _on_tick(_tick_index: int) -> void:
	# 延迟到所有敌人移动完毕后再刷新，确保位置同步
	call_deferred("_refresh")


func _on_enemy_killed(data: Dictionary) -> void:
	var enemy = data.get("enemy_def")
	if enemy and _cd_bars.has(enemy):
		var bar: ColorRect = _cd_bars[enemy]
		if is_instance_valid(bar):
			bar.queue_free()
		_cd_bars.erase(enemy)


func _refresh() -> void:
	if enemy_manager == null:
		_hide_all_ranges()
		return

	var range_idx: int = 0
	var snake_positions: Array[Vector2i] = []
	if snake:
		for seg in snake.segments:
			if is_instance_valid(seg):
				snake_positions.append(seg.grid_position)

	for enemy in enemy_manager.current_enemies:
		if not is_instance_valid(enemy):
			continue

		var cfg: Dictionary = ConfigManager.get_enemy_type(enemy.enemy_type)
		var attack_range: int = int(cfg.get("attack_range", 1))
		var max_cooldown: int = int(cfg.get("attack_cooldown", 0))

		if enemy.attack_cooldown_remaining <= 0:
			# Can attack — 仅当蛇身段在威胁范围内时才显示攻击范围
			_remove_cd_bar(enemy)

			# 只在蛇身段实际处于攻击范围内时才显示
			var pos: Vector2i = enemy.grid_position
			var has_target_in_range: bool = false
			for sp: Vector2i in snake_positions:
				if abs(sp.x - pos.x) + abs(sp.y - pos.y) <= attack_range:
					has_target_in_range = true
					break

			if not has_target_in_range:
				continue

			for dx in range(-attack_range, attack_range + 1):
				for dy in range(-attack_range, attack_range + 1):
					if dx == 0 and dy == 0:
						continue
					if abs(dx) + abs(dy) > attack_range:
						continue
					var cell: Vector2i = pos + Vector2i(dx, dy)
					if not GridWorld.is_within_bounds(cell):
						continue

					var is_target: bool = cell in snake_positions

					var rect: ColorRect = _get_or_create_range(range_idx)
					rect.global_position = Vector2(cell.x * CELL_SIZE + BORDER_WIDTH, cell.y * CELL_SIZE + BORDER_WIDTH)
					rect.size = Vector2(CELL_SIZE - BORDER_WIDTH * 2, CELL_SIZE - BORDER_WIDTH * 2)
					rect.color = WARN_COLOR if is_target else IDLE_COLOR
					rect.visible = true
					range_idx += 1
		else:
			# On cooldown — show cooldown bar
			_show_cd_bar(enemy, max_cooldown)

	_range_active = range_idx
	for i in range(range_idx, _range_rects.size()):
		_range_rects[i].visible = false


func _show_cd_bar(enemy: Enemy, max_cooldown: int) -> void:
	if max_cooldown <= 0:
		return
	var bar: ColorRect
	if _cd_bars.has(enemy):
		bar = _cd_bars[enemy]
		if not is_instance_valid(bar):
			_cd_bars.erase(enemy)
			bar = _create_cd_bar(enemy)
	else:
		bar = _create_cd_bar(enemy)

	var ratio: float = float(enemy.attack_cooldown_remaining) / float(max_cooldown)
	bar.size = Vector2(COOLDOWN_BAR_W * ratio, COOLDOWN_BAR_H)
	var world_pos: Vector2 = GridWorld.grid_to_world(enemy.grid_position)
	bar.global_position = world_pos + Vector2(-COOLDOWN_BAR_W / 2, CELL_SIZE * 0.4)
	bar.visible = true


func _create_cd_bar(enemy: Enemy) -> ColorRect:
	var bar := ColorRect.new()
	bar.color = Color(1.0, 0.5, 0.0, 0.7)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	_cd_bars[enemy] = bar
	return bar


func _remove_cd_bar(enemy: Enemy) -> void:
	if _cd_bars.has(enemy):
		var bar: ColorRect = _cd_bars[enemy]
		if is_instance_valid(bar):
			bar.visible = false


func _get_or_create_range(idx: int) -> ColorRect:
	if idx < _range_rects.size():
		return _range_rects[idx]
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	_range_rects.append(rect)
	return rect


func _hide_all_ranges() -> void:
	for rect in _range_rects:
		if is_instance_valid(rect):
			rect.visible = false
	_range_active = 0
