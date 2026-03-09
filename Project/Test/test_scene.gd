extends Control

var colors: Array[Dictionary] = [
	{"name": "红色 (Red)", "color": Color.RED},
	{"name": "蓝色 (Blue)", "color": Color.BLUE},
	{"name": "绿色 (Green)", "color": Color.GREEN},
	{"name": "黄色 (Yellow)", "color": Color.YELLOW},
	{"name": "紫色 (Purple)", "color": Color.PURPLE},
]
var current_index: int = 0

@onready var color_rect: ColorRect = $ColorRect
@onready var color_label: Label = $ColorLabel
@onready var cycle_button: Button = $CycleButton

func _ready() -> void:
	cycle_button.pressed.connect(_on_button_pressed)
	_update_display()

func _on_button_pressed() -> void:
	current_index = (current_index + 1) % colors.size()
	_update_display()

func _update_display() -> void:
	color_rect.color = colors[current_index]["color"]
	color_label.text = colors[current_index]["name"]
