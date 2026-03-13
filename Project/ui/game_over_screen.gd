extends Control

signal restart_pressed

@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var cause_label: Label = $VBoxContainer/CauseLabel
@onready var restart_button: Button = $VBoxContainer/RestartButton


func _ready() -> void:
	restart_button.pressed.connect(_on_restart_pressed)


func show_results(data: Dictionary) -> void:
	var score: int = data.get("score", 0)
	var best: int = data.get("best_score", 0)
	var cause: String = data.get("cause", "unknown")
	score_label.text = "Score: %d | Best: %d" % [score, best]
	cause_label.text = "Cause: %s" % cause
	show()


func _on_restart_pressed() -> void:
	restart_pressed.emit()
