class_name ShopPanel
extends PanelContainer

var _shop_system: Node = null
var _title_label: Label
var _items_box: VBoxContainer
var _items: Array = []
var _status_text: String = ""


func _ready() -> void:
	_build_ui()
	_connect_events()
	visible = false


func _exit_tree() -> void:
	_disconnect_events()


func setup(system: Node) -> void:
	_shop_system = system


func get_visible_item_count() -> int:
	return _items.size()


func get_item_labels() -> Array:
	var labels: Array = []
	for item in _items:
		if item is Dictionary:
			labels.append(item.get("display_name", ""))
	return labels


func purchase_by_index(index: int) -> bool:
	if _shop_system == null:
		return false
	var item: Dictionary = _items[index] if index >= 0 and index < _items.size() else {}
	return _shop_system.purchase(item.get("item_id", ""))


func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.03, 0.92)
	style.border_color = Color(0.82, 0.65, 0.25, 0.5)
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)

	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -180
	offset_right = 180
	offset_top = 80
	offset_bottom = 360
	mouse_filter = Control.MOUSE_FILTER_STOP

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)

	_title_label = Label.new()
	_title_label.text = "蛇皮商店"
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title_label)

	_items_box = VBoxContainer.new()
	_items_box.add_theme_constant_override("separation", 4)
	column.add_child(_items_box)


func _connect_events() -> void:
	if not EventBus.shop_entered.is_connected(_on_shop_entered):
		EventBus.shop_entered.connect(_on_shop_entered)
	if not EventBus.shop_purchase.is_connected(_on_shop_purchase):
		EventBus.shop_purchase.connect(_on_shop_purchase)
	if not EventBus.currency_changed.is_connected(_on_currency_changed):
		EventBus.currency_changed.connect(_on_currency_changed)
	if not EventBus.game_over.is_connected(_on_game_over):
		EventBus.game_over.connect(_on_game_over)


func _disconnect_events() -> void:
	if EventBus.shop_entered.is_connected(_on_shop_entered):
		EventBus.shop_entered.disconnect(_on_shop_entered)
	if EventBus.shop_purchase.is_connected(_on_shop_purchase):
		EventBus.shop_purchase.disconnect(_on_shop_purchase)
	if EventBus.currency_changed.is_connected(_on_currency_changed):
		EventBus.currency_changed.disconnect(_on_currency_changed)
	if EventBus.game_over.is_connected(_on_game_over):
		EventBus.game_over.disconnect(_on_game_over)


func _on_shop_entered(data: Dictionary) -> void:
	_items = data.get("items", []).duplicate(true)
	_title_label.text = "蛇皮商店 (余额: %d)" % (_shop_system._shedskin_system.get_amount() if _shop_system and _shop_system._shedskin_system else 0)
	_refresh()
	visible = true


func _on_shop_purchase(data: Dictionary) -> void:
	_title_label.text = "蛇皮商店 (余额: %d)" % int(data.get("currency_remaining", 0))
	_refresh()


func _on_currency_changed(data: Dictionary) -> void:
	if not visible:
		return
	_title_label.text = "蛇皮商店 (余额: %d)" % int(data.get("total", 0))
	_refresh()


func _on_game_over(data: Dictionary) -> void:
	_items.clear()
	visible = false


func _refresh() -> void:
	if _items_box == null:
		return
	for child in _items_box.get_children():
		child.queue_free()
	for index in range(_items.size()):
		_items_box.add_child(_make_item_row(_items[index], index))


func _make_item_row(item: Dictionary, index: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(16, 28)
	swatch.color = Color.html(item.get("placeholder_color", "#FFFFFF"))
	row.add_child(swatch)

	var label := Label.new()
	label.text = "%s - %d 蜕皮" % [item.get("display_name", ""), int(item.get("price", 0))]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var button := Button.new()
	if bool(item.get("purchased", false)):
		button.text = "已购"
		button.disabled = true
	elif not bool(item.get("affordable", false)):
		button.text = "不足"
		button.disabled = true
	else:
		button.text = "购买"
		button.pressed.connect(Callable(self, "_on_purchase_pressed").bind(index))
	row.add_child(button)

	return row


func _on_purchase_pressed(index: int) -> void:
	purchase_by_index(index)