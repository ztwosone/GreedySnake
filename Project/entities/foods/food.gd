class_name Food
extends GridEntity

var _color_rect: ColorRect


func _init() -> void:
	entity_type = Constants.EntityType.FOOD
	blocks_movement = false
	is_solid = false
	cell_layer = 0


func _ready() -> void:
	var s: float = Constants.CELL_SIZE * 0.75
	_color_rect = ColorRect.new()
	_color_rect.size = Vector2(s, s)
	_color_rect.position = Vector2(-s / 2, -s / 2)
	_color_rect.color = Color(1.0, 0.2, 0.2)
	add_child(_color_rect)
