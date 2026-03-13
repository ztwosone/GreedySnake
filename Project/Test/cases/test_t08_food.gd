extends RefCounted
## T08 测试：Food 食物系统


func run(t) -> void:
	t.assert_file_exists("res://entities/foods/food.gd")
	t.assert_file_exists("res://systems/food_manager.gd")

	# --- Food entity checks ---
	var food := Food.new()
	t.assert_true(food is GridEntity, "Food extends GridEntity")
	t.assert_true(food is Node2D, "Food extends Node2D")
	t.assert_eq(food.entity_type, Constants.EntityType.FOOD, "entity_type == FOOD")
	t.assert_eq(food.blocks_movement, false, "blocks_movement == false")
	t.assert_eq(food.is_solid, false, "is_solid == false")
	t.assert_eq(food.cell_layer, 0, "cell_layer == 0 (ground)")
	food.free()

	# --- FoodManager checks ---
	var fm := FoodManager.new()
	t.assert_true(fm.has_method("init_foods"), "has init_foods()")
	t.assert_true(fm.has_method("spawn_food"), "has spawn_food()")
	t.assert_true(fm.has_method("clear_foods"), "has clear_foods()")
	t.assert_eq(fm.max_food_count, 3, "max_food_count default == 3")

	# --- Integration: spawn on grid ---
	GridWorld.clear_all()
	GridWorld.init_grid(20, 11)

	var container := Node2D.new()
	var tree_root = Engine.get_main_loop().root
	tree_root.call_deferred("add_child", container)

	fm.food_container = container

	# Spawn one food
	fm.spawn_food()
	t.assert_eq(fm.current_foods.size(), 1, "spawn_food: 1 food in list")

	var spawned_food: Food = fm.current_foods[0]
	t.assert_true(GridWorld.is_within_bounds(spawned_food.grid_position), "food spawned within bounds")

	# Verify food is registered in GridWorld
	var entities = GridWorld.get_entities_at(spawned_food.grid_position)
	t.assert_true(spawned_food in entities, "food registered in GridWorld")

	# --- Food doesn't spawn on occupied cell ---
	# Fill grid with mock entities leaving only 1 cell
	GridWorld.clear_all()
	GridWorld.init_grid(2, 2)  # 4 cells total
	fm.current_foods.clear()

	var blockers: Array[Node] = []
	for pos in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]:
		var blocker := Node.new()
		GridWorld.register_entity(blocker, pos)
		blockers.append(blocker)

	fm.spawn_food()
	t.assert_eq(fm.current_foods.size(), 1, "food spawned on last empty cell")
	t.assert_eq(fm.current_foods[0].grid_position, Vector2i(1, 1), "food at only empty cell (1,1)")

	# --- Full grid: no crash ---
	GridWorld.register_entity(Node.new(), Vector2i(1, 1))
	fm.spawn_food()  # should not crash
	t.assert_eq(fm.current_foods.size(), 1, "no new food when grid full (no crash)")

	# --- Event response: food eaten ---
	GridWorld.clear_all()
	GridWorld.init_grid(20, 11)
	fm.current_foods.clear()
	# Manually connect since _ready() wasn't called (fm not in tree)
	if not EventBus.snake_food_eaten.is_connected(fm._on_food_eaten):
		EventBus.snake_food_eaten.connect(fm._on_food_eaten)
	fm.spawn_food()
	var eaten_food: Food = fm.current_foods[0]
	EventBus.snake_food_eaten.emit({"food": eaten_food, "position": eaten_food.grid_position, "food_type": "basic"})
	t.assert_true(eaten_food not in fm.current_foods, "eaten food removed from list")
	t.assert_eq(fm.current_foods.size(), 1, "new food spawned after eating")

	# Clean up
	fm.clear_foods()
	for b in blockers:
		b.free()
	container.queue_free()
	fm.free()
	GridWorld.clear_all()
	GridWorld.init_grid(20, 11)
