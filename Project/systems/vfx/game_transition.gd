class_name GameTransition
extends CanvasLayer

## 游戏开始/结束过渡效果
## 开始：黑屏淡入 + "GO!" 弹出
## 结束：白闪 + 屏幕变暗

var _overlay: ColorRect
var _label: Label
var _tw: Tween


func _ready() -> void:
	layer = 6
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 64)
	_label.add_theme_color_override("font_color", Color(1, 1, 1, 0))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_CENTER)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

	EventBus.game_started.connect(_on_game_started)
	EventBus.snake_died.connect(_on_snake_died)


func _on_game_started() -> void:
	_kill_tween()
	# Start from black, fade to clear
	_overlay.color = Color(0, 0, 0, 0.8)
	_label.text = "GO!"
	_label.add_theme_color_override("font_color", Color(1, 1, 0, 0))

	_tw = create_tween()
	# Fade in from black
	_tw.tween_property(_overlay, "color:a", 0.0, 0.4).set_ease(Tween.EASE_OUT)
	# Show "GO!" at 0.2s
	_tw.parallel().tween_property(_label, "theme_override_colors/font_color", Color(1, 1, 0, 1.0), 0.15).set_delay(0.1)
	# Scale bounce for GO text
	_label.scale = Vector2.ONE
	_tw.parallel().tween_property(_label, "scale", Vector2(1.3, 1.3), 0.1).set_delay(0.1)
	_tw.tween_property(_label, "scale", Vector2.ONE, 0.1)
	# Fade out GO text
	_tw.tween_property(_label, "theme_override_colors/font_color", Color(1, 1, 0, 0.0), 0.3).set_delay(0.3)


func _on_snake_died(_data: Dictionary) -> void:
	_kill_tween()
	# White flash then darken
	_overlay.color = Color(1, 1, 1, 0.6)
	VFXManager.screen_shake(5.0, 0.3)

	_tw = create_tween()
	_tw.tween_property(_overlay, "color", Color(0, 0, 0, 0.0), 0.15)
	_tw.tween_property(_overlay, "color", Color(0, 0, 0, 0.5), 0.8)


func _kill_tween() -> void:
	if _tw and _tw.is_valid():
		_tw.kill()
