extends Control

@onready var length_label: Label = $LengthLabel


func _ready() -> void:
	EventBus.snake_length_increased.connect(_update_length)
	EventBus.snake_length_decreased.connect(_update_length)
	EventBus.game_started.connect(_on_game_started)


func _update_length(data: Dictionary) -> void:
	length_label.text = "Length: %d" % data.get("new_length", 0)


func _on_game_started() -> void:
	length_label.text = "Length: %d" % Constants.INITIAL_SNAKE_LENGTH
