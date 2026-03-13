class_name FoodManager
extends Node

var max_food_count: int = 3
var current_foods: Array[Food] = []
var food_container: Node2D


func _ready() -> void:
	EventBus.snake_food_eaten.connect(_on_food_eaten)


func init_foods(count: int) -> void:
	max_food_count = count
	for i in range(count):
		spawn_food()


func spawn_food() -> void:
	var empty_cells: Array[Vector2i] = GridWorld.get_empty_cells()
	if empty_cells.is_empty():
		return
	var pos: Vector2i = empty_cells[randi() % empty_cells.size()]
	var food := Food.new()
	food.place_on_grid(pos)
	if food_container:
		food_container.add_child(food)
	current_foods.append(food)


func _on_food_eaten(data: Dictionary) -> void:
	var food = data.get("food")
	if food and food in current_foods:
		current_foods.erase(food)
		food.remove_from_grid()
		food.queue_free()
	spawn_food()


func clear_foods() -> void:
	for food in current_foods:
		if is_instance_valid(food):
			food.remove_from_grid()
			food.queue_free()
	current_foods.clear()
