extends Control

signal restart_pressed
signal test_mode_pressed

@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var cause_label: Label = $VBoxContainer/CauseLabel
@onready var restart_button: Button = $VBoxContainer/RestartButton

var _test_button: Button


func _ready() -> void:
	restart_button.pressed.connect(_on_restart_pressed)

	# 测试模式按钮（紧跟在 Restart 下方）
	_test_button = Button.new()
	_test_button.text = "Test Mode (T)"
	_test_button.pressed.connect(_on_test_mode_pressed)
	$VBoxContainer.add_child(_test_button)


func show_results(data: Dictionary) -> void:
	var score: int = data.get("score", 0)
	var best: int = data.get("best_score", 0)
	var cause: String = data.get("cause", "unknown")
	score_label.text = "Score: %d | Best: %d" % [score, best]
	cause_label.text = "Cause: %s" % cause
	show()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		_on_test_mode_pressed()


func _on_restart_pressed() -> void:
	restart_pressed.emit()


func _on_test_mode_pressed() -> void:
	test_mode_pressed.emit()
