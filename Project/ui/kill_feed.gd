class_name KillFeed
extends VBoxContainer

## 右上角事件简讯：最新 3 条游戏事件，2 秒后淡出

const MAX_ENTRIES: int = 3
const FADE_DELAY: float = 2.0
const FADE_DURATION: float = 0.5
const FONT_SIZE: int = 14


func _ready() -> void:
	set_anchors_preset(PRESET_TOP_RIGHT)
	offset_left = -220
	offset_right = -8
	offset_top = 8
	add_theme_constant_override("separation", 4)
	mouse_filter = MOUSE_FILTER_IGNORE

	EventBus.snake_hit_enemy.connect(_on_snake_hit_enemy)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.reaction_triggered.connect(_on_reaction)
	EventBus.snake_length_decreased.connect(_on_segment_lost)
	EventBus.snake_food_eaten.connect(_on_food_eaten)


func _add_entry(text: String, color: Color = Color(0.9, 0.9, 0.9)) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(label)

	# Remove excess entries
	while get_child_count() > MAX_ENTRIES:
		var old: Node = get_child(0)
		remove_child(old)
		old.queue_free()

	# Fade out after delay
	var tw: Tween = label.create_tween()
	tw.tween_interval(FADE_DELAY)
	tw.tween_property(label, "modulate:a", 0.0, FADE_DURATION)
	tw.tween_callback(label.queue_free)


func _on_snake_hit_enemy(data: Dictionary) -> void:
	var enemy = data.get("enemy")
	if enemy and is_instance_valid(enemy):
		var cfg: Dictionary = ConfigManager.get_enemy_type(enemy.enemy_type)
		var name: String = cfg.get("display_name", enemy.enemy_type)
		_add_entry(">> %s" % name, Color(1.0, 0.8, 0.3))


func _on_enemy_killed(data: Dictionary) -> void:
	var method: String = data.get("method", "")
	if method == "aura":
		_add_entry("~ aura kill", Color(1.0, 0.5, 0.1))


func _on_reaction(data: Dictionary) -> void:
	var reaction_id: String = data.get("reaction_id", "")
	var cfg: Dictionary = ConfigManager.get_reaction(reaction_id)
	var name: String = cfg.get("display_name", reaction_id)
	_add_entry("! %s" % name, Color(0.5, 1.0, 1.0))


func _on_segment_lost(data: Dictionary) -> void:
	var amount: int = data.get("amount", 1)
	_add_entry("- lost %d seg" % amount, Color(1.0, 0.3, 0.3))


func _on_food_eaten(_data: Dictionary) -> void:
	_add_entry("+ food", Color(0.3, 1.0, 0.4))
