class_name ShedskinDisplay
extends PanelContainer

var _amount_label: Label
var _amount: int = 0


func _ready() -> void:
	_build_ui()
	_connect_events()
	visible = false


func _exit_tree() -> void:
	_disconnect_events()


func get_amount_text() -> String:
	return str(_amount)


func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.04, 0.85)
	style.border_color = Color(0.82, 0.65, 0.25, 0.5)
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	add_theme_stylebox_override("panel", style)

	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -220
	offset_right = -12
	offset_top = 12
	offset_bottom = 46
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)

	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(14, 28)
	icon.color = Color(0.82, 0.65, 0.25)
	row.add_child(icon)

	var label := Label.new()
	label.text = "蜕皮"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.82, 0.65, 0.25))
	row.add_child(label)

	_amount_label = Label.new()
	_amount_label.text = "0"
	_amount_label.add_theme_font_size_override("font_size", 16)
	row.add_child(_amount_label)


func _connect_events() -> void:
	if not EventBus.currency_changed.is_connected(_on_currency_changed):
		EventBus.currency_changed.connect(_on_currency_changed)
	if not EventBus.game_over.is_connected(_on_game_over):
		EventBus.game_over.connect(_on_game_over)


func _disconnect_events() -> void:
	if EventBus.currency_changed.is_connected(_on_currency_changed):
		EventBus.currency_changed.disconnect(_on_currency_changed)
	if EventBus.game_over.is_connected(_on_game_over):
		EventBus.game_over.disconnect(_on_game_over)


func _on_currency_changed(data: Dictionary) -> void:
	if data.get("currency", "") != "shedskin":
		return
	_amount = int(data.get("total", 0))
	if _amount_label:
		_amount_label.text = str(_amount)
	if not visible:
		visible = true


func _on_game_over(data: Dictionary) -> void:
	visible = false