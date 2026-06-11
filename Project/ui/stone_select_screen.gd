extends "res://ui/kit/kit_panel.gd"
## 传承石选择屏（spec 003 M3 T015：presentation_design.md §7「传承石选择」设计契约）。
## 横排石碑卡（≤5，meta 存档驱动）+「轻装上阵」跳过入口。
## - 空石碑列表整屏跳过（FR-012）：open() 返回 false 且绝不闪现——概念第二局、带着玩家
##   刚看着铸成的那块石头首次登场（总体计划裁定 #12）。
## - 交互：←/→ 移动高亮（环绕）、1-5 数字直选、回车/空格确认、Esc =「轻装上阵」、
##   鼠标点卡直选（与既有选择面板同口径，§8.3）。
## - 选中石经注入的 LegacyStoneSystem.select_legacy_stone 消耗（存档移除 + 落盘 +
##   `legacy_stone_selected` 完整 stone payload），随后 stone_select_finished(stone)
##   交 main.gd 注入新局；跳过 = finished({})，石保留。
## - 屏幕流：GameManager.GameState.STONE_SELECT（S3 M3 提前落地）；仪式编排归 S4。
## - 无 class_name：消费方一律按路径加载（ScriptingLeading C.8）。

signal stone_select_finished(stone: Dictionary)

const _ChoiceCardScript := preload("res://ui/kit/choice_card.gd")

var _legacy_system = null
var _stones: Array = []
var _selected_index: int = 0
var _title_label: Label
var _hint_label: Label
var _cards_box: HBoxContainer
var _skip_button: Button


func _init() -> void:
	super._init("modal")
	# §12.1 模态唯一探测按 ui_modal 组扫描可见数
	add_to_group("ui_modal")


func _ready() -> void:
	_build_ui()
	visible = false


## 注入 LegacyStoneSystem（duck-typed：get_available_stones / select_legacy_stone）
func setup(legacy_system) -> void:
	_legacy_system = legacy_system


## 打开选择屏。空石碑列表返回 false 且绝不闪现（FR-012 整屏跳过，调用方直接开局）。
func open() -> bool:
	if _legacy_system == null:
		return false
	_stones = _legacy_system.get_available_stones()
	if _stones.is_empty():
		return false
	_selected_index = 0
	_refresh()
	_snap_center()
	visible = true
	return true


func get_visible_stone_count() -> int:
	return _stones.size()


func get_stone_labels() -> Array:
	var labels: Array = []
	for stone in _stones:
		if stone is Dictionary:
			labels.append(str(stone.get("display_name", "")))
	return labels


func get_selected_index() -> int:
	return _selected_index


func get_skip_label_text() -> String:
	return _skip_button.text if _skip_button else ""


## 选中第 index 块石：消耗（移除 + 落盘 + legacy_stone_selected 完整 payload）并关屏
func choose_stone_by_index(index: int) -> bool:
	if not visible or _legacy_system == null:
		return false
	if index < 0 or index >= _stones.size():
		return false
	var stone: Dictionary = _legacy_system.select_legacy_stone(index)
	if stone.is_empty():
		return false
	_close()
	stone_select_finished.emit(stone.duplicate(true))
	return true


## 「轻装上阵」：不消耗任何石，空 dict 收尾
func skip() -> bool:
	if not visible:
		return false
	_close()
	stone_select_finished.emit({})
	return true


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.is_echo():
		return
	match event.keycode:
		KEY_LEFT:
			_move_selection(-1)
			get_viewport().set_input_as_handled()
		KEY_RIGHT:
			_move_selection(1)
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			choose_stone_by_index(_selected_index)
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			skip()
			get_viewport().set_input_as_handled()
		_:
			if event.keycode >= KEY_1 and event.keycode <= KEY_5:
				choose_stone_by_index(int(event.keycode - KEY_1))
				get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var layout: Dictionary = ConfigManager.get_layout_config()
	var base_unit: float = float(layout.get("base_unit", 0))

	# §6 布局：屏幕居中模态（内容驱动尺寸；open() 时按最小尺寸重新居中停靠）
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	mouse_filter = Control.MOUSE_FILTER_STOP

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(base_unit * 0.5))
	add_child(column)

	_title_label = Label.new()
	_title_label.text = "选择传承石"
	_title_label.theme_type_variation = "HeadingLabel"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title_label)

	_hint_label = Label.new()
	_hint_label.text = "上一局的遗愿，偏置这一局的鳞片池"
	_hint_label.theme_type_variation = "CaptionLabel"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_color_override(
		"font_color", ConfigManager.get_palette_color("text_dim"))
	column.add_child(_hint_label)

	_cards_box = HBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", int(base_unit * 0.5))
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_cards_box)

	_skip_button = Button.new()
	_skip_button.text = "轻装上阵"
	_skip_button.pressed.connect(_on_skip_pressed)
	# §6/§12.1：交互件入 ui_hit 组并保证最小命中目标
	register_hit_target(_skip_button)
	column.add_child(_skip_button)


func _refresh() -> void:
	if _cards_box == null:
		return
	for child in _cards_box.get_children():
		child.queue_free()
	for index in range(_stones.size()):
		_cards_box.add_child(_make_stone_card(_stones[index], index))
	_update_highlight()


## §3 卡片解剖：stone glyph + 石名 + 遗愿描述 + 底缘蜕皮金色条（传承语义色）
func _make_stone_card(stone: Dictionary, index: int) -> Control:
	var base_unit: float = float(ConfigManager.get_layout_config().get("base_unit", 0))
	var card: Control = _ChoiceCardScript.new()
	card.custom_minimum_size = Vector2(base_unit * 9.0, 0)
	card.set_content({
		"glyph_id": "stone",
		"name": str(stone.get("display_name", "")),
		"desc": str(stone.get("description", "")),
		"tag_color": ConfigManager.get_palette_color("accent_shedskin"),
	})
	card.gui_input.connect(_on_card_gui_input.bind(index))
	return card


func _move_selection(delta: int) -> void:
	if _stones.is_empty():
		return
	_selected_index = (_selected_index + delta + _stones.size()) % _stones.size()
	_update_highlight()


## §3 选中态：外框亮起 + scale 1.05（choice_card 组件态，互斥）
func _update_highlight() -> void:
	if _cards_box == null:
		return
	var card_index: int = 0
	for child in _cards_box.get_children():
		if child.is_queued_for_deletion():
			continue
		if child.has_method("set_selected"):
			child.set_selected(card_index == _selected_index)
		card_index += 1


## 居中停靠（§6 布局：内容驱动最小尺寸居中——unlock_toast 同款停靠模式）
func _snap_center() -> void:
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func _close() -> void:
	_stones = []
	visible = false


func _on_card_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		choose_stone_by_index(index)


func _on_skip_pressed() -> void:
	skip()
