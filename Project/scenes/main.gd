extends Node

@onready var title_screen: Control = $UILayer/TitleScreen
@onready var game_over_screen: Control = $UILayer/GameOverScreen
@onready var game_world_container: Node = $GameWorldContainer

var _game_world_scene: PackedScene = preload("res://scenes/game_world.tscn")
var _acceptance_scene: PackedScene = preload("res://scenes/l1_acceptance.tscn")
var _current_game_world: Node2D
var _is_acceptance_mode: bool = false


func _ready() -> void:
	title_screen.start_pressed.connect(_on_start_pressed)
	game_over_screen.restart_pressed.connect(_on_restart_pressed)
	game_over_screen.test_mode_pressed.connect(_on_test_mode_pressed)
	EventBus.game_over.connect(_on_game_over)

	# Initial state: show title only
	title_screen.show()
	game_over_screen.hide()


func _unhandled_input(event: InputEvent) -> void:
	# Press T on title screen to launch L1 acceptance test
	if title_screen.visible and event is InputEventKey and event.pressed and event.keycode == KEY_T:
		title_screen.hide()
		_start_acceptance_test()


func _on_start_pressed() -> void:
	title_screen.hide()
	_start_new_game()


func _on_restart_pressed() -> void:
	game_over_screen.hide()
	_cleanup_game_world()
	if _is_acceptance_mode:
		_start_acceptance_test()
	else:
		_start_new_game()


func _on_test_mode_pressed() -> void:
	game_over_screen.hide()
	_cleanup_game_world()
	_start_acceptance_test()


func _on_game_over(data: Dictionary) -> void:
	game_over_screen.show_results(data)


func _start_new_game() -> void:
	_is_acceptance_mode = false
	_current_game_world = _game_world_scene.instantiate()
	game_world_container.add_child(_current_game_world)
	_current_game_world.start_game()
	GameManager.start_game()


func _start_acceptance_test() -> void:
	_is_acceptance_mode = true
	_cleanup_game_world()
	_current_game_world = _acceptance_scene.instantiate()
	game_world_container.add_child(_current_game_world)
	_current_game_world.start_game()
	GameManager.start_game()


func _cleanup_game_world() -> void:
	if _current_game_world and is_instance_valid(_current_game_world):
		_current_game_world.queue_free()
		_current_game_world = null
	GridWorld.clear_all()
