class_name HitCounter
extends HBoxContainer

## 受击计数器：N 个圆点表示距离掉段还剩多少次被击
## 被击时亮红，满了后全部爆裂并重置

const DOT_SIZE: float = 12.0
const DOT_GAP: float = 4.0

var _dots: Array[ColorRect] = []
var _max_hits: int = 3
var _current_hits: int = 0
var _burst_tween: Tween


func _ready() -> void:
	add_theme_constant_override("separation", int(DOT_GAP))

	EventBus.snake_body_attacked.connect(_on_body_attacked)
	EventBus.snake_length_decreased.connect(_on_segment_lost)
	EventBus.game_started.connect(_on_game_started)


func _on_game_started() -> void:
	var snake_cfg: Dictionary = ConfigManager.snake if ConfigManager else {}
	_max_hits = int(snake_cfg.get("hits_per_segment_loss", 3))
	_current_hits = 0
	_rebuild_dots()


func _rebuild_dots() -> void:
	for d in _dots:
		d.queue_free()
	_dots.clear()

	for i in range(_max_hits):
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(DOT_SIZE, DOT_SIZE)
		dot.color = Color(0.3, 0.3, 0.3, 0.6)  # Inactive: dim gray
		add_child(dot)
		_dots.append(dot)


func _on_body_attacked(_data: Dictionary) -> void:
	_current_hits += 1
	if _current_hits > _max_hits:
		_current_hits = _max_hits
	_update_dots()


func _on_segment_lost(_data: Dictionary) -> void:
	# Segment was lost — burst all dots, reset
	_burst_all()
	_current_hits = 0
	# Rebuild after short delay
	get_tree().create_timer(0.3).timeout.connect(_rebuild_dots)


func _update_dots() -> void:
	for i in range(_dots.size()):
		if i < _current_hits:
			_dots[i].color = Color(1.0, 0.2, 0.2, 1.0)  # Active: red
		else:
			_dots[i].color = Color(0.3, 0.3, 0.3, 0.6)  # Inactive: gray


func _burst_all() -> void:
	if _burst_tween and _burst_tween.is_valid():
		_burst_tween.kill()
	_burst_tween = create_tween().set_parallel(true)
	for dot in _dots:
		if is_instance_valid(dot):
			dot.color = Color(1.0, 0.8, 0.0)  # Flash yellow
			_burst_tween.tween_property(dot, "color:a", 0.0, 0.2)
			_burst_tween.tween_property(dot, "custom_minimum_size", Vector2(DOT_SIZE * 1.5, DOT_SIZE * 1.5), 0.2)
