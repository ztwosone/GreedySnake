extends Node

# ╔══════════════════════════════════════════════════════════╗
# ║  编译期常量（保留作为默认值 / 回退）                       ║
# ╚══════════════════════════════════════════════════════════╝
const CELL_SIZE: int = 32
const GRID_WIDTH: int = 40
const GRID_HEIGHT: int = 22

# === Viewport（自动派生，勿手动改） ===
const VIEWPORT_WIDTH: int = GRID_WIDTH * CELL_SIZE
const VIEWPORT_HEIGHT: int = GRID_HEIGHT * CELL_SIZE
const WINDOW_SCALE: int = 1          # 窗口放大倍率（像素风时可设 2/3/4）

# === Tick ===
const BASE_TICK_INTERVAL: float = 0.25

# === Snake ===
const INITIAL_SNAKE_LENGTH: int = 6

# ╔══════════════════════════════════════════════════════════╗
# ║  运行时可配置别名（从 ConfigManager JSON 读取）            ║
# ║  新代码优先使用这些 var；const 留作编译期兼容              ║
# ╚══════════════════════════════════════════════════════════╝
var cell_size: int = CELL_SIZE
var grid_width: int = GRID_WIDTH
var grid_height: int = GRID_HEIGHT
var viewport_width: int = VIEWPORT_WIDTH
var viewport_height: int = VIEWPORT_HEIGHT
var window_scale: int = WINDOW_SCALE
var base_tick_interval: float = BASE_TICK_INTERVAL
var initial_snake_length: int = INITIAL_SNAKE_LENGTH

# === Enums ===
enum EntityType { SNAKE_SEGMENT, ENEMY, FOOD, TERRAIN, STATUS_TILE, PICKUP, BUILDING }
enum Direction { UP, DOWN, LEFT, RIGHT }

# === Direction → Vector2i 映射 ===
const DIR_VECTORS: Dictionary = {
	Direction.UP: Vector2i(0, -1),
	Direction.DOWN: Vector2i(0, 1),
	Direction.LEFT: Vector2i(-1, 0),
	Direction.RIGHT: Vector2i(1, 0),
}


func _ready() -> void:
	_load_from_config()
	_apply_window_settings()


func _load_from_config() -> void:
	# ConfigManager 在 autoload 顺序中排在 Constants 之前，此时已加载完毕
	if not is_instance_valid(ConfigManager):
		return
	var cfg = ConfigManager

	# Grid
	cell_size = cfg.grid.get("cell_size", CELL_SIZE)
	grid_width = cfg.grid.get("width", GRID_WIDTH)
	grid_height = cfg.grid.get("height", GRID_HEIGHT)
	window_scale = cfg.grid.get("window_scale", WINDOW_SCALE)

	# 派生 viewport
	viewport_width = grid_width * cell_size
	viewport_height = grid_height * cell_size

	# Tick
	base_tick_interval = cfg.tick.get("base_interval", BASE_TICK_INTERVAL)

	# Snake
	initial_snake_length = cfg.snake.get("initial_length", INITIAL_SNAKE_LENGTH)


func _apply_window_settings() -> void:
	var window := get_window()
	window.content_scale_size = Vector2i(viewport_width, viewport_height)
	var win_w: int = viewport_width * window_scale
	var win_h: int = viewport_height * window_scale
	window.size = Vector2i(win_w, win_h)
	# 居中窗口
	var screen_size := DisplayServer.screen_get_size()
	window.position = Vector2i(
		(screen_size.x - win_w) / 2,
		(screen_size.y - win_h) / 2
	)
