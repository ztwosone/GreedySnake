extends Node2D

@onready var snake: Snake = $EntityContainer/Snake
@onready var enemy_container: Node2D = $EntityContainer/EnemyContainer
@onready var food_container: Node2D = $EntityContainer/FoodContainer
@onready var length_system: LengthSystem = $LengthSystem
@onready var food_manager: FoodManager = $FoodManager
@onready var enemy_manager: EnemyManager = $EnemyManager
@onready var status_tile_manager: StatusTileManager = $StatusTileManager
@onready var status_transfer_system: StatusTransferSystem = $StatusTransferSystem
@onready var reaction_system: ReactionSystem = $ReactionSystem
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
	enemy_manager.food_manager = food_manager
	status_transfer_system.tile_manager = status_tile_manager
	status_transfer_system.snake = snake
	reaction_system.tile_manager = status_tile_manager
	food_manager.tile_manager = status_tile_manager
	# StatusEffectManager 需要 tile_manager 用于火焰蔓延
	StatusEffectManager.tile_manager = status_tile_manager
	if StatusEffectManager._trigger_manager:
		StatusEffectManager._trigger_manager.enemy_mgr = enemy_manager
		StatusEffectManager._trigger_manager.food_mgr = food_manager

	# 蛇段增益效果系统
	var seg_effect_system := SegmentEffectSystem.new()
	seg_effect_system.name = "SegmentEffectSystem"
	seg_effect_system.snake = snake
	seg_effect_system.enemy_manager = enemy_manager
	seg_effect_system.tile_manager = status_tile_manager
	add_child(seg_effect_system)

	# 反应视觉效果
	var reaction_vfx := ReactionVFX.new()
	reaction_vfx.name = "ReactionVFX"
	add_child(reaction_vfx)

	# VFX 层挂载
	VFXManager.setup(self)

	# 屏幕震动
	var ScreenShakeScript: GDScript = preload("res://systems/vfx/screen_shake.gd")
	var screen_shake: Node = ScreenShakeScript.new()
	screen_shake.name = "ScreenShake"
	screen_shake.setup(camera)
	add_child(screen_shake)

	# Debug 面板（按 C 切换）
	var DebugPanelScript: GDScript = preload("res://ui/debug_panel.gd")
	var debug_panel: PanelContainer = DebugPanelScript.new()
	debug_panel.name = "DebugPanel"
	debug_panel.set_snake(snake)
	$UI.add_child(debug_panel)


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
