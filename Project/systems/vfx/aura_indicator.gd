class_name AuraIndicator
extends Node2D

## 火光环范围指示器：在火属性蛇段的4邻格绘制淡红色半透明格
## 每 tick 更新，使用对象池避免频繁创建/销毁

const CELL_SIZE: int = 32
const BASE_ALPHA: float = 0.15
const MAX_ALPHA: float = 0.3
const AURA_COLOR: Color = Color(1.0, 0.3, 0.0)

var snake: Snake = null
var _pool: Array[ColorRect] = []
var _active_count: int = 0


func _ready() -> void:
	z_index = -1
	EventBus.tick_post_process.connect(_on_tick)
	EventBus.snake_moved.connect(func(_d): _refresh())


func _on_tick(_tick_index: int) -> void:
	call_deferred("_refresh")


func _refresh() -> void:
	if snake == null:
		_hide_all()
		return

	# Collect all aura positions with overlap count
	var aura_counts: Dictionary = {}  # Vector2i -> int
	for seg in snake.segments:
		if not is_instance_valid(seg) or not seg.has_status("fire"):
			continue
		var pos: Vector2i = seg.grid_position
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var adj: Vector2i = pos + dir
			if not GridWorld.is_within_bounds(adj):
				continue
			# Don't show indicator on snake body positions
			if _is_snake_position(adj):
				continue
			aura_counts[adj] = aura_counts.get(adj, 0) + 1

	# Update visuals
	var idx: int = 0
	for cell_pos: Vector2i in aura_counts:
		var count: int = aura_counts[cell_pos]
		var rect: ColorRect = _get_or_create(idx)
		rect.global_position = Vector2(cell_pos.x * CELL_SIZE, cell_pos.y * CELL_SIZE)
		var alpha: float = minf(BASE_ALPHA * count, MAX_ALPHA)
		rect.color = Color(AURA_COLOR.r, AURA_COLOR.g, AURA_COLOR.b, alpha)
		rect.visible = true
		idx += 1

	_active_count = idx
	# Hide unused
	for i in range(idx, _pool.size()):
		_pool[i].visible = false


func _is_snake_position(pos: Vector2i) -> bool:
	if snake == null:
		return false
	for seg in snake.segments:
		if is_instance_valid(seg) and seg.grid_position == pos:
			return true
	return false


func _get_or_create(idx: int) -> ColorRect:
	if idx < _pool.size():
		return _pool[idx]
	var rect := ColorRect.new()
	rect.size = Vector2(CELL_SIZE, CELL_SIZE)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	_pool.append(rect)
	return rect


func _hide_all() -> void:
	for rect in _pool:
		rect.visible = false
	_active_count = 0
