extends Node2D

@onready var snake: Snake = $EntityContainer/Snake
@onready var enemy_container: Node2D = $EntityContainer/EnemyContainer
@onready var food_container: Node2D = $EntityContainer/FoodContainer
@onready var length_system: LengthSystem = $LengthSystem
@onready var food_manager: FoodManager = $FoodManager
@onready var enemy_manager: EnemyManager = $EnemyManager
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	# Camera centers on the grid
	var cx: float = Constants.GRID_WIDTH * Constants.CELL_SIZE / 2.0
	var cy: float = Constants.GRID_HEIGHT * Constants.CELL_SIZE / 2.0
	camera.position = Vector2(cx, cy)

	# Wire up references
	length_system.snake = snake
	food_manager.food_container = food_container
	enemy_manager.enemy_container = enemy_container
	enemy_manager.snake = snake


func start_game() -> void:
	# 1. Initialize Grid
	GridWorld.init_grid(Constants.GRID_WIDTH, Constants.GRID_HEIGHT)

	# 2. Initialize snake at center-left
	var start_pos := Vector2i(Constants.GRID_WIDTH / 2, Constants.GRID_HEIGHT / 2)
	snake.init_snake(start_pos, Constants.INITIAL_SNAKE_LENGTH, Constants.DIR_VECTORS[Constants.Direction.RIGHT])

	# 3. Initialize food
	food_manager.init_foods(3)

	# 4. Initialize enemies
	enemy_manager.init_enemies(3)

	# 5. Start Tick
	TickManager.start_ticking()

	# 6. Notify game started
	EventBus.game_started.emit()
