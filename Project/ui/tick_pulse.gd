class_name TickPulse
extends ColorRect

## 屏幕底部 tick 脉搏线：每 tick 闪一次

var _pulse_tween: Tween
var _base_color: Color = Color(1, 1, 1, 0.0)


func _ready() -> void:
	color = _base_color
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_BOTTOM_WIDE)
	custom_minimum_size = Vector2(0, 2)
	size = Vector2(0, 2)
	offset_top = -2
	offset_bottom = 0

	EventBus.tick_post_process.connect(_on_tick)
	EventBus.no_body_countdown_tick.connect(_on_countdown_tick)
	EventBus.no_body_countdown_cancelled.connect(_on_countdown_cancelled)


func _on_tick(_tick_index: int) -> void:
	_pulse(_base_color)


func _on_countdown_tick(data: Dictionary) -> void:
	var ratio: float = data.get("ratio", 1.0)
	_base_color = Color(1.0, lerpf(0.1, 1.0, ratio), lerpf(0.1, 1.0, ratio), 0.0)


func _on_countdown_cancelled() -> void:
	_base_color = Color(1, 1, 1, 0.0)


func _pulse(c: Color) -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	color = Color(c.r, c.g, c.b, 0.4)
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(self, "color:a", 0.0, 0.2)
