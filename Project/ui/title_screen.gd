extends Control

signal start_pressed

@onready var start_button: Button = $VBoxContainer/StartButton


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)


func _on_start_pressed() -> void:
	start_pressed.emit()
