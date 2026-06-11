extends HBoxContainer
## 拾取物 HUD chip 行（spec 003 M4 T018，presentation_design.md §8.7「顶部 chip 行」——
## S3 仅数据通路：每枚携带中的碎片一枚 ui/kit chip（pickup glyph + 名称 + 剩余房数）；
## 闪烁标记等仪式编排归 S4。渐进披露：无携带即整行隐藏（首次拾取才出现）。
## 停靠：右上角蜕皮 chip 下方（hud 层；chip 出生即带分组/元数据，几何探测进组自动覆盖）。
## 数据源：setup(pickup_system) 注入 + EventBus 驱动刷新（pickup_collected/expired/
## activated + room_completed 倒数 + run_started/game_over 收起）。
## 无 class_name：消费方一律按路径加载（ScriptingLeading 附录 C.8）。

const _ChipScript := preload("res://ui/kit/chip.gd")

var _pickup_system: Node = null


func _ready() -> void:
	var layout: Dictionary = ConfigManager.get_layout_config()
	var base_unit: float = float(layout.get("base_unit", 0))
	var screen_margin: float = float(layout.get("screen_margin", 0))
	# 右上角，蜕皮 chip（offset_top = screen_margin）正下方留 3 基准单位
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	alignment = BoxContainer.ALIGNMENT_END
	offset_left = -(screen_margin + base_unit * 12.0)
	offset_right = -screen_margin
	offset_top = screen_margin + base_unit * 3.0
	offset_bottom = screen_margin + base_unit * 3.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_connect_events()
	_refresh()


func _exit_tree() -> void:
	_disconnect_events()


func setup(pickup_system: Node) -> void:
	_pickup_system = pickup_system
	_refresh()


func get_chip_count() -> int:
	return get_child_count()


func get_chips() -> Array:
	return get_children()


func get_chip_texts() -> Array:
	var texts: Array = []
	for chip in get_children():
		if chip.has_method("get_text"):
			texts.append(chip.get_text())
	return texts


func _connect_events() -> void:
	if not EventBus.pickup_collected.is_connected(_on_pickups_changed):
		EventBus.pickup_collected.connect(_on_pickups_changed)
	if not EventBus.pickup_expired.is_connected(_on_pickups_changed):
		EventBus.pickup_expired.connect(_on_pickups_changed)
	if not EventBus.pickup_activated.is_connected(_on_pickups_changed):
		EventBus.pickup_activated.connect(_on_pickups_changed)
	if not EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.connect(_on_room_completed)
	if not EventBus.run_started.is_connected(_on_run_reset):
		EventBus.run_started.connect(_on_run_reset)
	if not EventBus.game_over.is_connected(_on_game_over):
		EventBus.game_over.connect(_on_game_over)


func _disconnect_events() -> void:
	if EventBus.pickup_collected.is_connected(_on_pickups_changed):
		EventBus.pickup_collected.disconnect(_on_pickups_changed)
	if EventBus.pickup_expired.is_connected(_on_pickups_changed):
		EventBus.pickup_expired.disconnect(_on_pickups_changed)
	if EventBus.pickup_activated.is_connected(_on_pickups_changed):
		EventBus.pickup_activated.disconnect(_on_pickups_changed)
	if EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.disconnect(_on_room_completed)
	if EventBus.run_started.is_connected(_on_run_reset):
		EventBus.run_started.disconnect(_on_run_reset)
	if EventBus.game_over.is_connected(_on_game_over):
		EventBus.game_over.disconnect(_on_game_over)


## 全量重建（携带数 ≤ 容量 5 级别，重建成本可忽略；chip 文案 = 名称 + 剩余房数，
## 激活者倒数冻结只显名称）
func _refresh() -> void:
	for chip in get_children():
		remove_child(chip)
		chip.queue_free()
	var carried: Array = []
	if _pickup_system != null and _pickup_system.has_method("get_carried_pickups"):
		carried = _pickup_system.get_carried_pickups()
	for pickup in carried:
		var chip: Control = _ChipScript.new()
		var def: Dictionary = ConfigManager.get_pickup(str(pickup.get("pickup_id", "")))
		var color: Color = Color.from_string(str(def.get("placeholder_color", "")),
			ConfigManager.get_palette_color("text_primary"))
		var text: String = str(pickup.get("display_name", ""))
		if not bool(pickup.get("active", false)):
			text += " %d" % int(pickup.get("rooms_remaining", 0))
		add_child(chip)
		chip.set_content("pickup", text, color)
	visible = not carried.is_empty()


func _on_pickups_changed(_data: Dictionary) -> void:
	_refresh()


func _on_room_completed(_data: Dictionary) -> void:
	_refresh()


func _on_run_reset(_data: Dictionary) -> void:
	_refresh()


func _on_game_over(_data: Dictionary) -> void:
	visible = false
