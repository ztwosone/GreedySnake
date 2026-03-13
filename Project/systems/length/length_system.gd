class_name LengthSystem
extends Node

var snake: Snake


func _ready() -> void:
	EventBus.snake_food_eaten.connect(_on_food_eaten)
	EventBus.length_decrease_requested.connect(_on_decrease_requested)
	EventBus.snake_hit_boundary.connect(_on_death_collision)
	EventBus.snake_hit_self.connect(_on_death_collision)


func get_current_length() -> int:
	if snake:
		return snake.body.size()
	return 0


func _on_food_eaten(_data: Dictionary) -> void:
	if not snake or not snake.is_alive:
		return
	var amount := 1
	snake.grow_pending += amount
	EventBus.snake_length_increased.emit({
		"amount": amount,
		"source": "food",
		"new_length": snake.body.size() + snake.grow_pending,
	})


func _on_decrease_requested(data: Dictionary) -> void:
	if not snake or not snake.is_alive:
		return
	var amount: int = data.get("amount", 1)
	var source: String = data.get("source", "unknown")

	var removed: int = 0
	for i in range(amount):
		if snake.body.size() <= 1:
			# Head is last segment — length would become 0 → death
			EventBus.snake_length_decreased.emit({
				"amount": 1,
				"source": source,
				"new_length": 0,
			})
			snake.die(source)
			return
		snake.remove_tail_segment()
		removed += 1

	# Emit length change if segments were removed
	if removed > 0:
		EventBus.snake_length_decreased.emit({
			"amount": removed,
			"source": source,
			"new_length": snake.body.size(),
		})


func _on_death_collision(data: Dictionary) -> void:
	if not snake or not snake.is_alive:
		return
	var cause: String = "hit_boundary" if data.has("direction") else "hit_self"
	snake.die(cause)
