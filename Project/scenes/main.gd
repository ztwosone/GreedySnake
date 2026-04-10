extends Node

@onready var title_screen: Control = $UILayer/TitleScreen
@onready var game_over_screen: Control = $UILayer/GameOverScreen
@onready var game_world_container: Node = $GameWorldContainer

var _game_world_scene: PackedScene = preload("res://scenes/game_world.tscn")
var _acceptance_scene: PackedScene = preload("res://scenes/l1_acceptance.tscn")
var _l2_acceptance_scene: PackedScene = preload("res://scenes/l2_acceptance.tscn")
var _current_game_world: Node2D
var _is_acceptance_mode: bool = false
var _acceptance_level: int = 1  # 1 = L1, 2 = L2


func _ready() -> void:
	title_screen.start_pressed.connect(_on_start_pressed)
	game_over_screen.restart_pressed.connect(_on_restart_pressed)
	game_over_screen.test_mode_pressed.connect(_on_test_mode_pressed)
	EventBus.game_over.connect(_on_game_over)

	# Initial state: show title only
	title_screen.show()
	game_over_screen.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not (title_screen.visible and event is InputEventKey and event.pressed):
		return
	# Press T on title screen to launch L1 acceptance test
	if event.keycode == KEY_T:
		title_screen.hide()
		_start_acceptance_test(1)
	# Press Y on title screen to launch L2 acceptance test
	elif event.keycode == KEY_Y:
		title_screen.hide()
		_start_acceptance_test(2)


func _on_start_pressed() -> void:
	title_screen.hide()
	_start_new_game()


func _on_restart_pressed() -> void:
	game_over_screen.hide()
	_cleanup_game_world()
	if _is_acceptance_mode:
		_start_acceptance_test(_acceptance_level)
	else:
		_start_new_game()


func _on_test_mode_pressed() -> void:
	game_over_screen.hide()
	_cleanup_game_world()
	_start_acceptance_test(_acceptance_level)


func _on_game_over(data: Dictionary) -> void:
	game_over_screen.show_results(data)


func _start_new_game() -> void:
	_is_acceptance_mode = false
	_current_game_world = _game_world_scene.instantiate()
	game_world_container.add_child(_current_game_world)
	_current_game_world.start_game()
	GameManager.start_game()


func _start_acceptance_test(level: int = 1) -> void:
	_is_acceptance_mode = true
	_acceptance_level = level
	_cleanup_game_world()
	var scene: PackedScene = _acceptance_scene if level == 1 else _l2_acceptance_scene
	_current_game_world = scene.instantiate()
	game_world_container.add_child(_current_game_world)
	_current_game_world.start_game()
	GameManager.start_game()


func _cleanup_game_world() -> void:
	if _current_game_world and is_instance_valid(_current_game_world):
		# T33: 先清理跨系统状态（TriggerManager/修改器/窗口），再释放节点
		if _current_game_world.has_method("cleanup"):
			_current_game_world.cleanup()
		_current_game_world.queue_free()
		_current_game_world = null
	GridWorld.clear_all()
