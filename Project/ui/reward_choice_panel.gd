extends "res://ui/kit/kit_panel.gd"
## 奖励选择面板（SpecKit 004 T012：L3 占位 → kit choice_card 迁移）
## 设计: Designs/Interactive/presentation_design.md §3（卡片解剖：glyph/名称/说明/标签色条）/
## §11.1（面板只调注入 flow 的 choose_* 公共方法）/§11.3（零编排：dim/stagger 选择仪式属 Phase P）。
## 无 class_name：消费方一律按路径加载（ScriptingLeading 附录 C.8）。
## 公共契约不变（既有 test_l3_* 与 experience 基建依赖）：setup /
## get_visible_option_count / get_option_labels / get_status_text / choose_option_by_index。

const _ChoiceCardScript := preload("res://ui/kit/choice_card.gd")

## §3 词汇表：reward_type → glyph id（head/tail Build 件、scale 鳞片）；未知类型回退 reward 菱形
const _REWARD_TYPE_GLYPHS: Dictionary = {
	"head": "head",
	"tail": "tail",
	"scale": "scale",
}

## 选项缺 description 字段时的类型说明回退文案
const _REWARD_TYPE_DESCS: Dictionary = {
	"head": "蛇头部件",
	"tail": "蛇尾部件",
	"scale": "鳞片",
}

var _reward_flow: Node = null
var _title_label: Label
var _status_label: Label
var _options_box: VBoxContainer
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


func setup(reward_flow: Node) -> void:
	_reward_flow = reward_flow


func get_visible_option_count() -> int:
	return _options.size()


func get_option_labels() -> Array:
	var labels: Array = []
	for option in _options:
		if option is Dictionary:
			labels.append(option.get("display_name", option.get("option_id", "")))
	return labels


## T012 新增：当前在列的 choice_card（与 _options 同序；不含待释放节点）
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


## T012 新增：选中态反馈（§3 外框亮起 + scale 1.05，互斥；Phase P 键鼠选择仪式复用）
func highlight_option(index: int) -> void:
	var cards: Array = get_option_cards()
	for card_index in range(cards.size()):
		cards[card_index].set_selected(card_index == index)


func choose_option_by_index(index: int) -> bool:
	if index < 0 or index >= _options.size() or _reward_flow == null:
		return false
	highlight_option(index)
	var option: Dictionary = _options[index]
	return _reward_flow.choose_reward(option.get("option_id", ""))


func _build_ui() -> void:
	var layout: Dictionary = ConfigManager.get_layout_config()
	var base_unit: float = float(layout.get("base_unit", 0))
	var screen_margin: float = float(layout.get("screen_margin", 0))

	# §6 布局：右上选择栏（宽 18 基准单位；全屏 dim 选择仪式属 Phase P）；高度随内容
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -(screen_margin + base_unit * 18.0)
	offset_right = -screen_margin
	offset_top = base_unit * 11.0
	offset_bottom = base_unit * 11.0
	mouse_filter = Control.MOUSE_FILTER_STOP

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(base_unit * 0.25))
	add_child(column)

	_title_label = Label.new()
	_title_label.text = "选择奖励"
	_title_label.theme_type_variation = "HeadingLabel"
	column.add_child(_title_label)

	_status_label = Label.new()
	_status_label.theme_type_variation = "CaptionLabel"
	column.add_child(_status_label)

	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", int(base_unit * 0.5))
	column.add_child(_options_box)


func _connect_events() -> void:
	if not EventBus.reward_presented.is_connected(_on_reward_presented):
		EventBus.reward_presented.connect(_on_reward_presented)
	if not EventBus.reward_chosen.is_connected(_on_reward_chosen):
		EventBus.reward_chosen.connect(_on_reward_chosen)


func _disconnect_events() -> void:
	if EventBus.reward_presented.is_connected(_on_reward_presented):
		EventBus.reward_presented.disconnect(_on_reward_presented)
	if EventBus.reward_chosen.is_connected(_on_reward_chosen):
		EventBus.reward_chosen.disconnect(_on_reward_chosen)


func _on_reward_presented(data: Dictionary) -> void:
	_options = data.get("options", []).duplicate(true)
	_status_text = "选择 1 个"
	_refresh()
	visible = true


func _on_reward_chosen(data: Dictionary) -> void:
	var option: Dictionary = data.get("option", {})
	_status_text = "已选择: %s" % option.get("display_name", data.get("chosen_option_id", ""))
	_options.clear()
	_refresh()


func _refresh() -> void:
	if _status_label:
		_status_label.text = _status_text
		# 已选择反馈 confirm 绿；其余次要文本色
		var status_token: String = "accent_confirm" if _status_text.find("已选择") >= 0 else "text_dim"
		_status_label.add_theme_color_override("font_color", ConfigManager.get_palette_color(status_token))
	if _options_box == null:
		return

	for child in _options_box.get_children():
		child.queue_free()

	for index in range(_options.size()):
		_options_box.add_child(_make_option_card(_options[index], index))


## §3 卡片解剖：glyph（reward_type 映射）+ 名称 + 说明 + 底缘标签色条（选项 JSON 色）
func _make_option_card(option: Dictionary, index: int) -> Control:
	var card: Control = _ChoiceCardScript.new()
	var reward_type: String = str(option.get("reward_type", ""))
	var color_text: String = str(option.get("placeholder_color", ""))
	var tag_color: Color = Color.html(color_text) if Color.html_is_valid(color_text) \
			else ConfigManager.get_palette_color("text_primary")
	var desc: String = str(option.get("description", ""))
	if desc.is_empty():
		desc = str(_REWARD_TYPE_DESCS.get(reward_type, ""))
	card.set_content({
		"glyph_id": str(_REWARD_TYPE_GLYPHS.get(reward_type, "reward")),
		"name": option.get("display_name", option.get("option_id", "")),
		"desc": desc,
		"tag_color": tag_color,
	})
	card.gui_input.connect(_on_card_gui_input.bind(index))
	return card


func _on_card_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		choose_option_by_index(index)
