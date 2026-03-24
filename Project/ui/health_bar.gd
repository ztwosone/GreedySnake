class_name HealthBar
extends HBoxContainer

## 蛇长度可视化条：每格 = 1 蛇段，颜色反映该段状态

const CELL_W: float = 8.0
const CELL_H: float = 16.0
const GAP: float = 1.0
const MAX_DISPLAY: int = 20

var _cells: Array[ColorRect] = []
var _overflow_label: Label
var _flash_tween: Tween


func _ready() -> void:
	add_theme_constant_override("separation", int(GAP))

	_overflow_label = Label.new()
	_overflow_label.add_theme_font_size_override("font_size", 14)
	_overflow_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_overflow_label.visible = false
	add_child(_overflow_label)

	EventBus.snake_length_increased.connect(_on_length_changed)
	EventBus.snake_length_decreased.connect(_on_length_changed)
	EventBus.game_started.connect(_on_game_started)
	EventBus.status_applied.connect(func(_d): _refresh())
	EventBus.status_removed.connect(func(_d): _refresh())
	EventBus.status_layer_changed.connect(func(_d): _refresh())
	EventBus.status_expired.connect(func(_d): _refresh())


func _on_game_started() -> void:
	_refresh()


func _on_length_changed(_data: Dictionary) -> void:
	_refresh()


func _refresh() -> void:
	var snake: Snake = _find_snake()
	if snake == null:
		return

	var seg_count: int = snake.segments.size()
	var display_count: int = mini(seg_count, MAX_DISPLAY)

	# Resize cell pool
	while _cells.size() < display_count:
		var cell := ColorRect.new()
		cell.custom_minimum_size = Vector2(CELL_W, CELL_H)
		# Insert before overflow label
		add_child(cell)
		move_child(cell, _cells.size())
		_cells.append(cell)

	while _cells.size() > display_count:
		var cell: ColorRect = _cells.pop_back()
		cell.queue_free()

	# Update colors
	for i in range(display_count):
		var seg: SnakeSegment = snake.segments[i]
		_cells[i].color = _get_segment_color(seg)

	# Overflow
	if seg_count > MAX_DISPLAY:
		_overflow_label.text = "+%d" % (seg_count - MAX_DISPLAY)
		_overflow_label.visible = true
	else:
		_overflow_label.visible = false


func _get_segment_color(seg: SnakeSegment) -> Color:
	if seg.carried_status == "fire":
		return Color(1.0, 0.5, 0.1)
	elif seg.carried_status == "ice":
		return Color(0.4, 0.7, 1.0)
	elif seg.carried_status == "poison":
		return Color(0.3, 0.8, 0.2)
	# Default: segment type color
	match seg.segment_type:
		SnakeSegment.HEAD:
			return Color(0.95, 0.95, 0.95)
		SnakeSegment.TAIL:
			return Color(0.6, 0.6, 0.6)
		_:
			return Color(0.78, 0.78, 0.78)


func _find_snake() -> Snake:
	var s = get_tree().get_first_node_in_group("snake") if is_inside_tree() else null
	if s:
		return s as Snake
	# Fallback: walk up to GameWorld
	var p = self
	while p:
		p = p.get_parent()
		if p and p.has_node("EntityContainer/Snake"):
			return p.get_node("EntityContainer/Snake") as Snake
	return null
