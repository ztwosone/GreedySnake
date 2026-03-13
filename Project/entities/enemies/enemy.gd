class_name Enemy
extends GridEntity

var hp: int = 1
var attack_cost: int = 1
var _color_rect: ColorRect


func _init() -> void:
	entity_type = Constants.EntityType.ENEMY
	blocks_movement = false
	is_solid = true
	cell_layer = 1


func _ready() -> void:
	var s: float = Constants.CELL_SIZE * 0.75
	_color_rect = ColorRect.new()
	_color_rect.size = Vector2(s, s)
	_color_rect.position = Vector2(-s / 2, -s / 2)
	_color_rect.color = Color(0.8, 0.1, 0.3)
	add_child(_color_rect)


func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		die()


func die() -> void:
	EventBus.enemy_killed.emit({
		"enemy_def": self,
		"position": grid_position,
		"method": "snake_collision",
	})
	remove_from_grid()
	queue_free()
