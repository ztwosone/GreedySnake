class_name SnakeSegment
extends GridEntity

const HEAD := 0
const BODY := 1
const TAIL := 2

const COLOR_HEAD := Color(0.2, 1.0, 0.2)
const COLOR_BODY := Color(0.1, 0.7, 0.1)
const COLOR_TAIL := Color(0.0, 0.5, 0.0)

var segment_index: int = 0
var segment_type: int = BODY

var _color_rect: ColorRect


func _init() -> void:
	entity_type = Constants.EntityType.SNAKE_SEGMENT
	blocks_movement = true
	is_solid = true


func _ready() -> void:
	_color_rect = ColorRect.new()
	_color_rect.size = Vector2(Constants.CELL_SIZE, Constants.CELL_SIZE)
	_color_rect.position = Vector2(-Constants.CELL_SIZE / 2, -Constants.CELL_SIZE / 2)
	add_child(_color_rect)
	update_visual()


func update_visual() -> void:
	if not _color_rect:
		return
	match segment_type:
		HEAD:
			_color_rect.color = COLOR_HEAD
		BODY:
			_color_rect.color = COLOR_BODY
		TAIL:
			_color_rect.color = COLOR_TAIL
