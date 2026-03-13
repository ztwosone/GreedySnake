extends Node


func run(runner: Node) -> void:
	# --- File existence ---
	runner.assert_file_exists("res://scenes/game_world.tscn")
	runner.assert_file_exists("res://scenes/game_world.gd")
	runner.assert_file_exists("res://scenes/grid_background.gd")
	runner.assert_file_exists("res://ui/hud.gd")

	# --- GridBackground script ---
	var bg_script = load("res://scenes/grid_background.gd")
	var bg = bg_script.new()
	runner.assert_true(bg is Node2D, "GridBackground extends Node2D")
	runner.assert_true(bg.has_method("_draw"), "GridBackground has _draw()")
	bg.queue_free()

	# --- GameWorld script ---
	var gw_script = load("res://scenes/game_world.gd")
	var gw = gw_script.new()
	runner.assert_true(gw is Node2D, "GameWorld extends Node2D")
	runner.assert_true(gw.has_method("start_game"), "GameWorld has start_game()")
	gw.queue_free()

	# --- HUD script ---
	var hud_script = load("res://ui/hud.gd")
	var hud = hud_script.new()
	runner.assert_true(hud is Control, "HUD extends Control")
	runner.assert_true(hud.has_method("_update_length"), "HUD has _update_length()")
	runner.assert_true(hud.has_method("_on_game_started"), "HUD has _on_game_started()")
	hud.queue_free()

	# --- Scene structure (load packed scene and check nodes) ---
	var scene = load("res://scenes/game_world.tscn") as PackedScene
	runner.assert_true(scene != null, "game_world.tscn loads successfully")

	var instance = scene.instantiate()
	runner.assert_true(instance != null, "game_world scene instantiates")

	# Check key child nodes exist
	runner.assert_true(instance.has_node("Camera2D"), "has Camera2D node")
	runner.assert_true(instance.has_node("GridBackground"), "has GridBackground node")
	runner.assert_true(instance.has_node("EntityContainer"), "has EntityContainer node")
	runner.assert_true(instance.has_node("EntityContainer/Snake"), "has Snake node")
	runner.assert_true(instance.has_node("EntityContainer/EnemyContainer"), "has EnemyContainer node")
	runner.assert_true(instance.has_node("EntityContainer/FoodContainer"), "has FoodContainer node")
	runner.assert_true(instance.has_node("LengthSystem"), "has LengthSystem node")
	runner.assert_true(instance.has_node("FoodManager"), "has FoodManager node")
	runner.assert_true(instance.has_node("EnemyManager"), "has EnemyManager node")
	runner.assert_true(instance.has_node("UI"), "has UI CanvasLayer")
	runner.assert_true(instance.has_node("UI/HUD"), "has HUD node")
	runner.assert_true(instance.has_node("UI/HUD/LengthLabel"), "has LengthLabel node")

	# Check Camera2D exists (position is set at runtime in _ready)
	var cam: Camera2D = instance.get_node("Camera2D")
	runner.assert_true(cam != null, "Camera2D exists")

	# Check UI/HUD/LengthLabel is a Label
	var label = instance.get_node("UI/HUD/LengthLabel")
	runner.assert_true(label is Label, "LengthLabel is a Label")

	# Check main_scene is set (T11 changes it to main.tscn)
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	runner.assert_eq(main_scene, "res://scenes/main.tscn", "main_scene set to main.tscn")

	instance.queue_free()
