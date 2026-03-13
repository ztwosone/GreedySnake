extends RefCounted
## T01 测试：项目脚手架与核心常量


func run(t) -> void:
	# --- 目录结构 ---
	t.assert_dir_exists("res://autoloads")
	t.assert_dir_exists("res://core")
	t.assert_dir_exists("res://core/helpers")
	t.assert_dir_exists("res://systems/movement")
	t.assert_dir_exists("res://systems/length")
	t.assert_dir_exists("res://entities/snake")
	t.assert_dir_exists("res://entities/enemies")
	t.assert_dir_exists("res://entities/foods")
	t.assert_dir_exists("res://ui")
	t.assert_dir_exists("res://data/json")
	t.assert_dir_exists("res://scenes")

	# --- constants.gd 文件存在 ---
	t.assert_file_exists("res://core/constants.gd")

	# --- 常量值 ---
	t.assert_true(Constants.CELL_SIZE > 0, "CELL_SIZE > 0")
	t.assert_true(Constants.GRID_WIDTH > 0, "GRID_WIDTH > 0")
	t.assert_true(Constants.GRID_HEIGHT > 0, "GRID_HEIGHT > 0")
	t.assert_eq(Constants.BASE_TICK_INTERVAL, 0.25, "BASE_TICK_INTERVAL == 0.25")
	t.assert_eq(Constants.INITIAL_SNAKE_LENGTH, 6, "INITIAL_SNAKE_LENGTH == 6")

	# --- 枚举存在性 ---
	t.assert_true(Constants.EntityType.has("SNAKE_SEGMENT"), "EntityType has SNAKE_SEGMENT")
	t.assert_true(Constants.EntityType.has("ENEMY"), "EntityType has ENEMY")
	t.assert_true(Constants.EntityType.has("FOOD"), "EntityType has FOOD")
	t.assert_true(Constants.EntityType.has("TERRAIN"), "EntityType has TERRAIN")
	t.assert_true(Constants.Direction.has("UP"), "Direction has UP")
	t.assert_true(Constants.Direction.has("DOWN"), "Direction has DOWN")
	t.assert_true(Constants.Direction.has("LEFT"), "Direction has LEFT")
	t.assert_true(Constants.Direction.has("RIGHT"), "Direction has RIGHT")

	# --- DIR_VECTORS 映射 ---
	t.assert_eq(Constants.DIR_VECTORS[Constants.Direction.UP], Vector2i(0, -1), "DIR_VECTORS UP")
	t.assert_eq(Constants.DIR_VECTORS[Constants.Direction.DOWN], Vector2i(0, 1), "DIR_VECTORS DOWN")
	t.assert_eq(Constants.DIR_VECTORS[Constants.Direction.LEFT], Vector2i(-1, 0), "DIR_VECTORS LEFT")
	t.assert_eq(Constants.DIR_VECTORS[Constants.Direction.RIGHT], Vector2i(1, 0), "DIR_VECTORS RIGHT")
