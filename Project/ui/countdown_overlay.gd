class_name CountdownOverlay
extends CanvasLayer

## 无身体倒计时全屏效果：红色暗角 + 中央 "EAT OR DIE" 大字

var _vignette: ColorRect
var _center_label: Label
var _vignette_tween: Tween


func _ready() -> void:
	layer = 4
	mouse_filter_ignore()

	# 红色暗角（用四边 ColorRect 模拟 vignette）
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.color = Color(0.5, 0.0, 0.0, 0.0)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)

	# 中央文字
	_center_label = Label.new()
	_center_label.text = "EAT OR DIE"
	_center_label.add_theme_font_size_override("font_size", 48)
	_center_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 0.0))
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center_label.set_anchors_preset(Control.PRESET_CENTER)
	_center_label.offset_top = -60
	_center_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center_label)

	EventBus.no_body_countdown_started.connect(_on_started)
	EventBus.no_body_countdown_tick.connect(_on_tick)
	EventBus.no_body_countdown_cancelled.connect(_on_cancelled)


func mouse_filter_ignore() -> void:
	# CanvasLayer children need individual mouse_filter
	pass


func _on_started(_data: Dictionary) -> void:
	_vignette.visible = true
	_center_label.visible = true
	_update(1.0)


func _on_tick(data: Dictionary) -> void:
	var ratio: float = data.get("ratio", 1.0)
	_update(ratio)


func _on_cancelled() -> void:
	if _vignette_tween and _vignette_tween.is_valid():
		_vignette_tween.kill()
	_vignette.color.a = 0.0
	_center_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2, 0.0))
	_vignette.visible = false
	_center_label.visible = false


func _update(ratio: float) -> void:
	# Vignette intensity increases as ratio decreases (closer to death)
	var intensity: float = lerpf(0.4, 0.05, ratio)
	_vignette.color = Color(0.5, 0.0, 0.0, intensity)

	# Label alpha pulses, faster as ratio decreases
	var label_alpha: float = lerpf(0.9, 0.4, ratio)
	var flash_color := Color(1.0, lerpf(0.1, 0.5, ratio), 0.1, label_alpha)
	_center_label.add_theme_color_override("font_color", flash_color)
