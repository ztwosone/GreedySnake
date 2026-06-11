extends Node

# STONE_SELECT 追加在尾部：既有状态 int 值不变（测试 save/restore 以 int 存取）。
# spec 003 M3 提前落地 §7 屏幕流的 STONE_SELECT；SUMMARY 仍归 S4（004 Phase P）。
enum GameState { TITLE, PLAYING, GAME_OVER, STONE_SELECT }

var current_state: int = GameState.TITLE
var current_score: int = 0
var best_score: int = 0


func _ready() -> void:
	EventBus.snake_died.connect(_on_snake_died)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.game_restart_requested.connect(restart_game)
	EventBus.run_victory.connect(_on_run_victory)


func start_game() -> void:
	current_state = GameState.PLAYING
	current_score = 0
	EventBus.game_started.emit()


func end_game(cause: String) -> void:
	current_state = GameState.GAME_OVER
	TickManager.stop_ticking()
	if current_score > best_score:
		best_score = current_score
	EventBus.game_over.emit({
		"cause": cause,
		"final_length": 0,
		"score": current_score,
		"best_score": best_score,
	})


func restart_game() -> void:
	GridWorld.clear_all()
	start_game()


func go_to_title() -> void:
	current_state = GameState.TITLE
	TickManager.stop_ticking()
	GridWorld.clear_all()


## spec 003 M3：传承石选择屏状态（presentation §7 屏幕流；可见性切换在 main.gd）
func enter_stone_select() -> void:
	current_state = GameState.STONE_SELECT


func _on_snake_died(data: Dictionary) -> void:
	end_game(data.get("cause", "unknown"))


func _on_enemy_killed(_data: Dictionary) -> void:
	if current_state == GameState.PLAYING:
		current_score += 1


func _on_run_victory(_data: Dictionary) -> void:
	if current_state == GameState.PLAYING:
		end_game("victory")
