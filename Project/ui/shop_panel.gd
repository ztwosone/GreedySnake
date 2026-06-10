extends "res://ui/kit/kit_panel.gd"
## 商店面板（spec 002 T015：ui/kit 重建，presentation_design.md §3/§6/§8.4）
## 货架行（glyph + 名称 + 价格 chip）× ≤5 + 余额 chip；买不起/已购行去饱和禁用（§8.4）。
## 表现层只听不驱动（§11.1）：购买一律走注入系统的 purchase 公共方法；
## 退店随 `room_entered`（进入任何非商店房间隐藏，与 ShopSystem 同一通路）。
## 无 class_name：消费方一律按路径加载（ScriptingLeading 附录 C.8）。
## 公共契约：setup / get_visible_item_count / get_item_labels / get_item_rows /
## get_row_price_text / is_item_disabled / purchase_by_index / get_balance_text /
## get_status_text。

const _GlyphScript := preload("res://ui/kit/glyph.gd")
const _ChipScript := preload("res://ui/kit/chip.gd")

## §3 词汇表：商品类别 → glyph id（presentation.glyphs）
const _CATEGORY_GLYPHS: Dictionary = {
	"scale": "scale",
	"slot": "slot_empty",
	"head_upgrade": "head",
	"tail_upgrade": "tail",
}

var _shop_system: Node = null
var _title_label: Label
var _balance_chip: Control
var _status_label: Label
var _items_box: VBoxContainer
var _items: Array = []
var _status_text: String = ""


func _init() -> void:
	super._init("modal")
	# §12.1 模态唯一探测按 ui_modal 组扫描可见数
	add_to_group("ui_modal")


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
			labels.append(str(item.get("display_name", item.get("item_id", ""))))
	return labels


## 当前在列的货架行（与 _items 同序；不含待释放节点）
func get_item_rows() -> Array:
	var rows: Array = []
	if _items_box == null:
		return rows
	for child in _items_box.get_children():
		if not child.is_queued_for_deletion():
			rows.append(child)
	return rows


func get_row_price_text(index: int) -> String:
	var rows: Array = get_item_rows()
	if index < 0 or index >= rows.size():
		return ""
	var chip: Control = rows[index].get_node_or_null("PriceChip")
	return chip.get_text() if chip != null else ""


func is_item_disabled(index: int) -> bool:
	var rows: Array = get_item_rows()
	if index < 0 or index >= rows.size():
		return true
	return bool(rows[index].get_meta("shop_row_disabled", true))


func purchase_by_index(index: int) -> bool:
	if _shop_system == null or index < 0 or index >= _items.size():
		return false
	if is_item_disabled(index):
		return false
	return _shop_system.purchase(str(_items[index].get("item_id", "")))


func get_balance_text() -> String:
	return _balance_chip.get_text() if _balance_chip else ""


func get_status_text() -> String:
	return _status_text


func _build_ui() -> void:
	var layout: Dictionary = ConfigManager.get_layout_config()
	var base_unit: float = float(layout.get("base_unit", 0))
	var screen_margin: float = float(layout.get("screen_margin", 0))

	# §6 布局：右上选择栏（宽 18 基准单位，顶部 7 单位起笔——与鳞片面板同槽位，
	# 模态在时间上互斥：商店开着时不存在其他待决 offer，FR-015）
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -(screen_margin + base_unit * 18.0)
	offset_right = -screen_margin
	offset_top = base_unit * 7.0
	offset_bottom = base_unit * 7.0
	mouse_filter = Control.MOUSE_FILTER_STOP

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(base_unit * 0.25))
	add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", int(base_unit * 0.5))
	column.add_child(header)

	_title_label = Label.new()
	_title_label.text = "蜕皮商店"
	_title_label.theme_type_variation = "HeadingLabel"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_balance_chip = _ChipScript.new()
	_balance_chip.set_ui_layer("modal")  # 寄宿在模态面板内，层语义跟随宿主（§11.5）
	header.add_child(_balance_chip)

	_status_label = Label.new()
	_status_label.theme_type_variation = "CaptionLabel"
	column.add_child(_status_label)

	_items_box = VBoxContainer.new()
	_items_box.add_theme_constant_override("separation", int(base_unit * 0.25))
	column.add_child(_items_box)


func _connect_events() -> void:
	if not EventBus.shop_entered.is_connected(_on_shop_entered):
		EventBus.shop_entered.connect(_on_shop_entered)
	if not EventBus.shop_purchase.is_connected(_on_shop_purchase):
		EventBus.shop_purchase.connect(_on_shop_purchase)
	if not EventBus.currency_changed.is_connected(_on_currency_changed):
		EventBus.currency_changed.connect(_on_currency_changed)
	if not EventBus.room_entered.is_connected(_on_room_entered):
		EventBus.room_entered.connect(_on_room_entered)
	if not EventBus.game_over.is_connected(_on_game_over):
		EventBus.game_over.connect(_on_game_over)


func _disconnect_events() -> void:
	if EventBus.shop_entered.is_connected(_on_shop_entered):
		EventBus.shop_entered.disconnect(_on_shop_entered)
	if EventBus.shop_purchase.is_connected(_on_shop_purchase):
		EventBus.shop_purchase.disconnect(_on_shop_purchase)
	if EventBus.currency_changed.is_connected(_on_currency_changed):
		EventBus.currency_changed.disconnect(_on_currency_changed)
	if EventBus.room_entered.is_connected(_on_room_entered):
		EventBus.room_entered.disconnect(_on_room_entered)
	if EventBus.game_over.is_connected(_on_game_over):
		EventBus.game_over.disconnect(_on_game_over)


func _on_shop_entered(data: Dictionary) -> void:
	_items = data.get("items", []).duplicate(true)
	_status_text = "进入下一房间离开商店"
	_refresh()
	visible = true


func _on_shop_purchase(data: Dictionary) -> void:
	if not visible:
		return
	_status_text = "已购入 %s" % str(data.get("item_id", ""))
	_refresh()


func _on_currency_changed(data: Dictionary) -> void:
	if not visible or str(data.get("currency", "")) != "shedskin":
		return
	_refresh()


## 退店通路与 ShopSystem 同源：进入任何非商店房间即收起（plan.md「exits via room_entered」）
func _on_room_entered(data: Dictionary) -> void:
	var shop_room_type: String = str(ConfigManager.get_shop_config().get("room_type", "shop"))
	if str(data.get("room_type", "")) == shop_room_type:
		return
	if visible:
		_close()


func _on_game_over(_data: Dictionary) -> void:
	_close()


func _close() -> void:
	_items.clear()
	_status_text = ""
	_refresh()
	visible = false


func _refresh() -> void:
	# 余额/可买性以系统为准（表现层只读）
	if _shop_system != null and _shop_system.is_active():
		_items = _shop_system.get_inventory()
	if _balance_chip:
		var balance: int = _shop_system.get_balance() if _shop_system != null else 0
		_balance_chip.set_content("shedskin", str(balance), ConfigManager.get_palette_color("accent_shedskin"))
	if _status_label:
		_status_label.text = _status_text
		var status_token: String = "accent_confirm" if _status_text.find("已购入") >= 0 else "text_dim"
		_status_label.add_theme_color_override("font_color", ConfigManager.get_palette_color(status_token))
	if _items_box == null:
		return

	for child in _items_box.get_children():
		child.queue_free()
	for index in range(_items.size()):
		_items_box.add_child(_make_item_row(_items[index], index))


## §3 货架行解剖：类别 glyph + 名称 + 价格 chip（蜕皮 glyph）；
## 已购/买不起 → modulate 染 text_dim 去饱和（§8.4 禁用态）
func _make_item_row(item: Dictionary, index: int) -> Control:
	var base_unit: float = float(ConfigManager.get_layout_config().get("base_unit", 0))
	var purchased: bool = bool(item.get("purchased", false))
	var disabled: bool = purchased or not bool(item.get("affordable", false))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(base_unit * 0.5))
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.set_meta("shop_row_disabled", disabled)
	# §6/§12.1：货架行整行可点，入 ui_hit 组并保证最小命中目标
	register_hit_target(row)

	var glyph: Control = _GlyphScript.new()
	glyph.custom_minimum_size = Vector2(base_unit * 1.5, base_unit * 1.5)
	var color_text: String = str(item.get("placeholder_color", ""))
	var glyph_color: Color = Color.html(color_text) if Color.html_is_valid(color_text) \
			else ConfigManager.get_palette_color("text_primary")
	glyph.set_glyph(str(_CATEGORY_GLYPHS.get(str(item.get("category", "")), "scale")), glyph_color)
	row.add_child(glyph)

	var name_label := Label.new()
	name_label.theme_type_variation = "BodyLabel"
	name_label.text = str(item.get("display_name", item.get("item_id", "")))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var price_chip: Control = _ChipScript.new()
	price_chip.name = "PriceChip"
	price_chip.set_ui_layer("modal")  # 同上：层语义跟随模态宿主
	if purchased:
		price_chip.set_content("shedskin", "已购", ConfigManager.get_palette_color("text_dim"))
	else:
		price_chip.set_content("shedskin", str(int(item.get("price", 0))),
			ConfigManager.get_palette_color("accent_shedskin"))
	row.add_child(price_chip)

	if disabled:
		var dim: Color = ConfigManager.get_palette_color("text_dim")
		row.modulate = Color(dim.r, dim.g, dim.b, 1.0)

	row.gui_input.connect(_on_row_gui_input.bind(index))
	return row


func _on_row_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		purchase_by_index(index)
