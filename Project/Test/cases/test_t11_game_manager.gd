extends Node


func run(runner: Node) -> void:
	# --- File existence ---
	runner.assert_file_exists("res://autoloads/game_manager.gd")
	runner.assert_file_exists("res://scenes/main.tscn")
	runner.assert_file_exists("res://scenes/main.gd")
	runner.assert_file_exists("res://ui/title_screen.gd")
	runner.assert_file_exists("res://ui/game_over_screen.gd")

	# --- GameManager is autoload ---
	runner.assert_true(GameManager != null, "GameManager autoload exists")
	runner.assert_true(GameManager.has_method("start_game"), "has start_game()")
	runner.assert_true(GameManager.has_method("end_game"), "has end_game()")
	runner.assert_true(GameManager.has_method("restart_game"), "has restart_game()")
	runner.assert_true(GameManager.has_method("go_to_title"), "has go_to_title()")

	# --- Initial state ---
	# Save and restore state after testing
	var saved_state: int = GameManager.current_state
	var saved_score: int = GameManager.current_score
	var saved_best: int = GameManager.best_score

	runner.assert_eq(GameManager.GameState.TITLE, 0, "GameState.TITLE == 0")
	runner.assert_eq(GameManager.GameState.PLAYING, 1, "GameState.PLAYING == 1")
	runner.assert_eq(GameManager.GameState.GAME_OVER, 2, "GameState.GAME_OVER == 2")

	# --- start_game changes state ---
	GameManager.current_state = GameManager.GameState.TITLE
	GameManager.current_score = 5  # should reset to 0
	# Disconnect snake_died temporarily to avoid side effects
	GameManager.start_game()
	runner.assert_eq(GameManager.current_state, GameManager.GameState.PLAYING, "start_game -> PLAYING")
	runner.assert_eq(GameManager.current_score, 0, "start_game resets score to 0")

	# --- enemy_killed increments score ---
	GameManager.current_score = 0
	EventBus.enemy_killed.emit({"enemy_def": null, "position": Vector2i.ZERO, "method": "test"})
	runner.assert_eq(GameManager.current_score, 1, "enemy_killed increments score")

	EventBus.enemy_killed.emit({"enemy_def": null, "position": Vector2i.ZERO, "method": "test"})
	runner.assert_eq(GameManager.current_score, 2, "second kill -> score 2")

	# --- end_game changes state ---
	GameManager.best_score = 0
	GameManager.current_score = 3

	var game_over_events := []
	var _on_game_over = func(data: Dictionary) -> void:
		game_over_events.append(data)
	EventBus.game_over.connect(_on_game_over)

	GameManager.end_game("test_cause")
	runner.assert_eq(GameManager.current_state, GameManager.GameState.GAME_OVER, "end_game -> GAME_OVER")
	runner.assert_eq(GameManager.best_score, 3, "best_score updated to 3")
	runner.assert_eq(game_over_events.size(), 1, "game_over event emitted")
	runner.assert_eq(game_over_events[0].get("cause") if game_over_events.size() > 0 else null, "test_cause", "game_over cause correct")
	runner.assert_eq(game_over_events[0].get("score") if game_over_events.size() > 0 else null, 3, "game_over score correct")
	runner.assert_eq(game_over_events[0].get("best_score") if game_over_events.size() > 0 else null, 3, "game_over best_score correct")

	EventBus.game_over.disconnect(_on_game_over)

	# --- best_score persists across games ---
	GameManager.start_game()
	GameManager.current_score = 1
	GameManager.end_game("test2")
	runner.assert_eq(GameManager.best_score, 3, "best_score stays 3 when score < best")

	GameManager.start_game()
	GameManager.current_score = 10
	GameManager.end_game("test3")
	runner.assert_eq(GameManager.best_score, 10, "best_score updated to 10 when score > best")

	# --- go_to_title ---
	GameManager.go_to_title()
	runner.assert_eq(GameManager.current_state, GameManager.GameState.TITLE, "go_to_title -> TITLE")

	# --- Main scene structure ---
	var main_scene = load("res://scenes/main.tscn") as PackedScene
	runner.assert_true(main_scene != null, "main.tscn loads successfully")

	var instance = main_scene.instantiate()
	runner.assert_true(instance != null, "main scene instantiates")
	runner.assert_true(instance.has_node("UILayer/TitleScreen"), "has TitleScreen")
	runner.assert_true(instance.has_node("GameWorldContainer"), "has GameWorldContainer")
	runner.assert_true(instance.has_node("UILayer/GameOverScreen"), "has GameOverScreen")
	runner.assert_true(instance.has_node("UILayer/TitleScreen/VBoxContainer/TitleLabel"), "has TitleLabel")
	runner.assert_true(instance.has_node("UILayer/TitleScreen/VBoxContainer/StartButton"), "has StartButton")
	runner.assert_true(instance.has_node("UILayer/GameOverScreen/VBoxContainer/GameOverLabel"), "has GameOverLabel")
	runner.assert_true(instance.has_node("UILayer/GameOverScreen/VBoxContainer/ScoreLabel"), "has ScoreLabel")
	runner.assert_true(instance.has_node("UILayer/GameOverScreen/VBoxContainer/CauseLabel"), "has CauseLabel")
	runner.assert_true(instance.has_node("UILayer/GameOverScreen/VBoxContainer/RestartButton"), "has RestartButton")
	instance.queue_free()

	# --- Autoload registered ---
	var gm_autoload: String = ProjectSettings.get_setting("autoload/GameManager", "")
	runner.assert_true(gm_autoload != "", "GameManager in autoload list")

	# --- main_scene setting ---
	var ms: String = ProjectSettings.get_setting("application/run/main_scene", "")
	runner.assert_eq(ms, "res://scenes/main.tscn", "main_scene == main.tscn")

	# Restore GameManager state
	GameManager.current_state = saved_state
	GameManager.current_score = saved_score
	GameManager.best_score = saved_best
