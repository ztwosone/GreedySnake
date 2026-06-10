extends "res://ui/kit/kit_panel.gd"
## 楼层奖励面板（spec 002 T026：ui/kit 重建，presentation_design.md §3 卡片解剖/§6 布局）
## 两段式 Boss 结算（FR-007/US3/US5）：① 槽位定位选择（前/中/后 choice_card，新槽先开）
## → ② 楼层奖励 choice_card×3（扩展/强化/修正）。两段都由 floor_reward_presented 驱动
## （step 字段），floor_reward_chosen 收面板。
## 表现层只听不驱动（§11.1）：决议一律走注入系统的 choose_slot_position/choose_floor_reward。
## 无 class_name：消费方一律按路径加载（ScriptingLeading 附录 C.8）。
## 公共契约：setup / get_step / get_visible_option_count / get_option_labels / get_slot_labels /
## get_option_cards / get_status_text / choose_slot_by_index / choose_slot_position /
## choose_option_by_index。

const _ChoiceCardScript := preload("res://ui/kit/choice_card.gd")

## §3 词汇表：front/middle/back → 可读位置名
const _SLOT_NAMES: Dictionary = {
	"front": "前段",
	"middle": "中段",
	"back": "后段",
}

var _floor_reward_system: Node = null
var _title_label: Label
var _status_label: Label
var _options_box: VBoxContainer
var _step: String = ""
var _slot_options: Array = []
var _options: Array = []
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
	_floor_reward_system = system


func get_step() -> String:
	return _step


func get_visible_option_count() -> int:
	return get_option_cards().size()


func get_slot_labels() -> Array:
	var labels: Array = []
	for position in _slot_options:
		labels.append(str(_SLOT_NAMES.get(position, position)))
	return labels


func get_option_labels() -> Array:
	var labels: Array = []
	for option in _options:
		if option is Dictionary:
			labels.append(str(option.get("display_name", option.get("option_id", ""))))
	return labels


## 当前在列的 choice_card（与本段选项同序；不含待释放节点）
func get_option_cards() -> Array:
	var cards: Array = []
	if _options_box == null:
		return cards
	for child in _options_box.get_children():
		if not child.is_queued_for_deletion():
			cards.append(child)
	return cards


func get_status_text() -> String:
	return _status_text


## 选中态反馈（§3 外框亮起 + scale 1.05，互斥）
func highlight_option(index: int) -> void:
	var cards: Array = get_option_cards()
	for card_index in range(cards.size()):
		cards[card_index].set_selected(card_index == index)


func choose_slot_by_index(index: int) -> bool:
	if index < 0 or index >= _slot_options.size():
		return false
	return choose_slot_position(str(_slot_options[index]))


func choose_slot_position(position: String) -> bool:
	if _floor_reward_system == null:
		return false
	return _floor_reward_system.choose_slot_position(position)


func choose_option_by_index(index: int) -> bool:
	if index < 0 or index >= _options.size() or _floor_reward_system == null:
		return false
	highlight_option(index)
	return _floor_reward_system.choose_floor_reward(index)


func _build_ui() -> void:
	var layout: Dictionary = ConfigManager.get_layout_config()
	var base_unit: float = float(layout.get("base_unit", 0))
	var screen_margin: float = float(layout.get("screen_margin", 0))

	# §6 布局：右上选择栏（宽 18 基准单位，顶部 7 单位起笔——与鳞片/商店面板同槽位；
	# FR-015 模态在时间上互斥：Boss 结算时不存在其他待决 offer）
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -(screen_margin + base_unit * 18.0)
	offset_right = -screen_margin
	offset_top = base_unit * 7.0
	offset_bottom = base_unit * 7.0
	mouse_filter = Control.MOUSE_FILTER_STOP

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(base_unit * 0.25))
	add_child(column)

	_title_label = Label.new()
	_title_label.text = "Boss 结算"
	_title_label.theme_type_variation = "HeadingLabel"
	column.add_child(_title_label)

	_status_label = Label.new()
	_status_label.theme_type_variation = "CaptionLabel"
	column.add_child(_status_label)

	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", int(base_unit * 0.5))
	column.add_child(_options_box)


func _connect_events() -> void:
	if not EventBus.floor_reward_presented.is_connected(_on_reward_presented):
		EventBus.floor_reward_presented.connect(_on_reward_presented)
	if not EventBus.floor_reward_chosen.is_connected(_on_reward_chosen):
		EventBus.floor_reward_chosen.connect(_on_reward_chosen)
	if not EventBus.game_over.is_connected(_on_game_over):
		EventBus.game_over.connect(_on_game_over)


func _disconnect_events() -> void:
	if EventBus.floor_reward_presented.is_connected(_on_reward_presented):
		EventBus.floor_reward_presented.disconnect(_on_reward_presented)
	if EventBus.floor_reward_chosen.is_connected(_on_reward_chosen):
		EventBus.floor_reward_chosen.disconnect(_on_reward_chosen)
	if EventBus.game_over.is_connected(_on_game_over):
		EventBus.game_over.disconnect(_on_game_over)


func _on_reward_presented(data: Dictionary) -> void:
	_step = str(data.get("step", "choice"))
	_slot_options = data.get("slot_options", []).duplicate(true)
	_options = data.get("options", []).duplicate(true)
	var floor_index: int = int(data.get("floor_index", 1))
	if _step == "slot_unlock":
		_title_label.text = "Boss 结算"
		_status_text = "选择新槽位位置"
	else:
		_title_label.text = "楼层 %d 奖励" % floor_index
		_status_text = "三选一"
	_refresh()
	visible = true


func _on_reward_chosen(_data: Dictionary) -> void:
	if _step == "":
		return  # 空选项自动决议（skipped）：面板从未展示，不接管状态
	_step = ""
	_slot_options.clear()
	_options.clear()
	_status_text = ""
	_refresh()
	visible = false


func _on_game_over(_data: Dictionary) -> void:
	_step = ""
	_slot_options.clear()
	_options.clear()
	visible = false


func _refresh() -> void:
	if _status_label:
		_status_label.text = _status_text
	if _options_box == null:
		return
	for child in _options_box.get_children():
		child.queue_free()
	if _step == "slot_unlock":
		for index in range(_slot_options.size()):
			_options_box.add_child(_make_slot_card(str(_slot_options[index]), index))
	else:
		for index in range(_options.size()):
			_options_box.add_child(_make_option_card(_options[index], index))


## ① 槽位卡：slot_empty glyph + 可读位置名（§3 词汇表）
func _make_slot_card(position: String, index: int) -> Control:
	var card: Control = _ChoiceCardScript.new()
	card.set_content({
		"glyph_id": "slot_empty",
		"name": str(_SLOT_NAMES.get(position, position)),
		"desc": "新增 1 个鳞片槽位",
		"tag_color": ConfigManager.get_palette_color("accent_confirm"),
	})
	card.gui_input.connect(_on_slot_card_gui_input.bind(index))
	return card


## ② 奖励卡：类别名 + 具体效果（detail）+ 底缘标签色条（扩展类取鳞片 JSON 色）
func _make_option_card(option: Dictionary, index: int) -> Control:
	var card: Control = _ChoiceCardScript.new()
	var color_text: String = str(option.get("placeholder_color", ""))
	var tag_color: Color = Color.html(color_text) if Color.html_is_valid(color_text) \
			else ConfigManager.get_palette_color("text_primary")
	var desc: String = str(option.get("detail", ""))
	if desc.is_empty():
		desc = str(option.get("description", ""))
	card.set_content({
		"glyph_id": "scale",
		"name": option.get("display_name", option.get("option_id", "")),
		"desc": desc,
		"tag_color": tag_color,
	})
	card.gui_input.connect(_on_option_card_gui_input.bind(index))
	return card


func _on_slot_card_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		choose_slot_by_index(index)


func _on_option_card_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		choose_option_by_index(index)
