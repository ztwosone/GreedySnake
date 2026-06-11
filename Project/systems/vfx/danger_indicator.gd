class_name DangerIndicator
extends Node2D

## 敌人攻击范围指示器
## - 冷却=0时：周围格画淡红边框；蛇段在范围内则加深警告
## - 冷却中：敌人身上显示小冷却条
## - 敌人意图显示（spec 003 M4，Designs §9.4 broken_eye 持有效果）：携带
##   carry_effect == "enemy_intent" 的拾取物期间，按 enemy_action_decided 的
##   最近一次移动决策在目标格画意图标记（"下一步移动方向，仅 1 格"）。
##   数据通路 EventBus-only：pickup_collected 开 / pickup_expired 关 /
##   run_started 复位（FR-011；多枚携带按 instance_id 计数）。

const CELL_SIZE: int = 32
const BORDER_WIDTH: float = 2.0
const IDLE_COLOR: Color = Color(1.0, 0.3, 0.3, 0.2)
const WARN_COLOR: Color = Color(1.0, 0.2, 0.2, 0.5)
const COOLDOWN_BAR_W: float = 20.0
const COOLDOWN_BAR_H: float = 3.0
const INTENT_COLOR: Color = Color(0.81, 0.58, 0.85, 0.55)
const INTENT_SIZE_RATIO: float = 0.35

var enemy_manager: EnemyManager = null
var snake: Snake = null

var _range_rects: Array[ColorRect] = []
var _range_active: int = 0
var _cd_bars: Dictionary = {}  # Enemy -> ColorRect
var _intent_sources: Dictionary = {}  # pickup instance_id -> true（enemy_intent 携带计数）
var _enemy_intents: Dictionary = {}  # enemy(Node) -> Vector2i（最近一次移动决策方向）
var _intent_rects: Array[ColorRect] = []


func _ready() -> void:
	z_index = 2
	EventBus.tick_post_process.connect(_on_tick)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.enemy_action_decided.connect(_on_enemy_action_decided)
	EventBus.pickup_collected.connect(_on_pickup_collected)
	EventBus.pickup_expired.connect(_on_pickup_expired)
	EventBus.run_started.connect(_on_run_started)


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
	if enemy:
		_enemy_intents.erase(enemy)


# === 敌人意图显示（broken_eye 携带效果数据通路，SC-005） ===

func is_intent_display_enabled() -> bool:
	return not _intent_sources.is_empty()


## 当前可见的意图目标格（敌人位置 + 最近移动决策方向；越界/失效敌人滤除）
func get_intent_cells() -> Array:
	if not is_intent_display_enabled():
		return []
	var cells: Array = []
	for enemy in _enemy_intents:
		if not is_instance_valid(enemy):
			continue
		if enemy_manager != null and not enemy_manager.current_enemies.has(enemy):
			continue
		var dir: Vector2i = _enemy_intents[enemy]
		var pos = enemy.get("grid_position")
		if not (pos is Vector2i):
			continue
		var cell: Vector2i = pos + dir
		if GridWorld.is_within_bounds(cell):
			cells.append(cell)
	return cells


func _on_enemy_action_decided(data: Dictionary) -> void:
	var enemy = data.get("enemy")
	if enemy == null:
		return
	var dir: Vector2i = data.get("direction", Vector2i.ZERO)
	if str(data.get("action", "")) == "move" and dir != Vector2i.ZERO:
		_enemy_intents[enemy] = dir
	else:
		_enemy_intents.erase(enemy)


func _on_pickup_collected(data: Dictionary) -> void:
	if str(data.get("carry_effect", "")) == "enemy_intent":
		_intent_sources[str(data.get("instance_id", ""))] = true


func _on_pickup_expired(data: Dictionary) -> void:
	_intent_sources.erase(str(data.get("instance_id", "")))
	if not is_intent_display_enabled():
		_hide_all_intents()


func _on_run_started(_data: Dictionary) -> void:
	_intent_sources.clear()
	_enemy_intents.clear()
	_hide_all_intents()


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

	_refresh_intents()


## 意图标记重绘（携带 broken_eye 期间：目标格中心小菱形，复用矩形池）
func _refresh_intents() -> void:
	var cells: Array = get_intent_cells()
	var s: float = CELL_SIZE * INTENT_SIZE_RATIO
	for i in range(cells.size()):
		var rect: ColorRect = _get_or_create_intent(i)
		var cell: Vector2i = cells[i]
		rect.size = Vector2(s, s)
		rect.pivot_offset = Vector2(s / 2, s / 2)
		rect.rotation = PI / 4.0
		rect.global_position = GridWorld.grid_to_world(cell) - Vector2(s / 2, s / 2)
		rect.color = INTENT_COLOR
		rect.visible = true
	for i in range(cells.size(), _intent_rects.size()):
		_intent_rects[i].visible = false


func _get_or_create_intent(idx: int) -> ColorRect:
	if idx < _intent_rects.size():
		return _intent_rects[idx]
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	_intent_rects.append(rect)
	return rect


func _hide_all_intents() -> void:
	for rect in _intent_rects:
		if is_instance_valid(rect):
			rect.visible = false


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
