extends "res://ui/kit/kit_panel.gd"
## 鳞片三选一面板（spec 002 T008：ui/kit 重建，presentation_design.md §3 卡片解剖/§6 布局）
## choice_card×3 + 放弃入口（标注 +N 蜕皮，N = 选项数 × growth.shedskin.scale_discard，JSON）。
## 表现层只听不驱动（§11.1）：选择/放弃一律走注入系统的 choose_scale/discard_offer 公共方法。
## 无 class_name：消费方一律按路径加载（ScriptingLeading 附录 C.8）。
## 公共契约：setup / get_visible_option_count / get_option_labels / get_option_cards /
## get_status_text / get_discard_label_text / choose_option_by_index / discard_offer。

const _ChoiceCardScript := preload("res://ui/kit/choice_card.gd")

## §3 词汇表：front/middle/back → 可读位置名
const _SLOT_NAMES: Dictionary = {
	"front": "前段",
	"middle": "中段",
	"back": "后段",
}

var _scale_reward_system: Node = null
var _title_label: Label
var _status_label: Label
var _options_box: VBoxContainer
var _discard_button: Button
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
	_scale_reward_system = system


func get_visible_option_count() -> int:
	return _options.size()


func get_option_labels() -> Array:
	var labels: Array = []
	for option in _options:
		if option is Dictionary:
			labels.append(option.get("display_name", option.get("option_id", "")))
	return labels


## 当前在列的 choice_card（与 _options 同序；不含待释放节点）
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


func get_discard_label_text() -> String:
	return _discard_button.text if _discard_button else ""


## 选中态反馈（§3 外框亮起 + scale 1.05，互斥）
func highlight_option(index: int) -> void:
	var cards: Array = get_option_cards()
	for card_index in range(cards.size()):
		cards[card_index].set_selected(card_index == index)


func choose_option_by_index(index: int) -> bool:
	if index < 0 or index >= _options.size() or _scale_reward_system == null:
		return false
	highlight_option(index)
	return _scale_reward_system.choose_scale(index)


func discard_offer() -> bool:
	if _scale_reward_system == null:
		return false
	return _scale_reward_system.discard_offer()


func _build_ui() -> void:
	var layout: Dictionary = ConfigManager.get_layout_config()
	var base_unit: float = float(layout.get("base_unit", 0))
	var screen_margin: float = float(layout.get("screen_margin", 0))

	# §6 布局：右上选择栏（宽 18 基准单位；FR-015 保证与奖励面板模态互斥）
	# 顶部 7 基准单位：3 卡 + 放弃入口比奖励面板高，需提前起笔以收进视口
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
	_title_label.text = "选择鳞片"
	_title_label.theme_type_variation = "HeadingLabel"
	column.add_child(_title_label)

	_status_label = Label.new()
	_status_label.theme_type_variation = "CaptionLabel"
	column.add_child(_status_label)

	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", int(base_unit * 0.5))
	column.add_child(_options_box)

	_discard_button = Button.new()
	_discard_button.pressed.connect(_on_discard_pressed)
	# §6/§12.1：交互件入 ui_hit 组并保证最小命中目标
	register_hit_target(_discard_button)
	column.add_child(_discard_button)


func _connect_events() -> void:
	if not EventBus.scale_reward_presented.is_connected(_on_scale_reward_presented):
		EventBus.scale_reward_presented.connect(_on_scale_reward_presented)
	if not EventBus.scale_reward_chosen.is_connected(_on_scale_reward_chosen):
		EventBus.scale_reward_chosen.connect(_on_scale_reward_chosen)
	if not EventBus.scale_option_discarded.is_connected(_on_scale_option_discarded):
		EventBus.scale_option_discarded.connect(_on_scale_option_discarded)
	if not EventBus.game_over.is_connected(_on_game_over):
		EventBus.game_over.connect(_on_game_over)


func _disconnect_events() -> void:
	if EventBus.scale_reward_presented.is_connected(_on_scale_reward_presented):
		EventBus.scale_reward_presented.disconnect(_on_scale_reward_presented)
	if EventBus.scale_reward_chosen.is_connected(_on_scale_reward_chosen):
		EventBus.scale_reward_chosen.disconnect(_on_scale_reward_chosen)
	if EventBus.scale_option_discarded.is_connected(_on_scale_option_discarded):
		EventBus.scale_option_discarded.disconnect(_on_scale_option_discarded)
	if EventBus.game_over.is_connected(_on_game_over):
		EventBus.game_over.disconnect(_on_game_over)


func _on_scale_reward_presented(data: Dictionary) -> void:
	_options = data.get("options", []).duplicate(true)
	_status_text = "选择 1 个鳞片"
	_refresh()
	visible = true


func _on_scale_reward_chosen(data: Dictionary) -> void:
	if _options.is_empty():
		return  # 空池自动决议（skipped）：面板从未展示，不接管状态
	_status_text = "已选择: %s" % data.get("scale_id", "")
	_options.clear()
	_refresh()
	visible = false


func _on_scale_option_discarded(data: Dictionary) -> void:
	if _options.is_empty():
		return  # 选择路径的伴随放弃事件：面板已由 chosen 处理
	_status_text = "已放弃 +%d 蜕皮" % int(data.get("shedskin_gained", 0))
	_options.clear()
	_refresh()
	visible = false


func _on_game_over(_data: Dictionary) -> void:
	_options.clear()
	visible = false


func _refresh() -> void:
	if _status_label:
		_status_label.text = _status_text
		# 决议反馈 confirm 绿；其余次要文本色
		var resolved: bool = _status_text.find("已选择") >= 0 or _status_text.find("已放弃") >= 0
		var status_token: String = "accent_confirm" if resolved else "text_dim"
		_status_label.add_theme_color_override("font_color", ConfigManager.get_palette_color(status_token))
	if _options_box == null:
		return

	for child in _options_box.get_children():
		child.queue_free()
	for index in range(_options.size()):
		_options_box.add_child(_make_option_card(_options[index], index))

	if _discard_button:
		var discard_reward: int = _options.size() * int(ConfigManager.get_shedskin_config().get("scale_discard", 0))
		_discard_button.text = "放弃全部 +%d 蜕皮" % discard_reward
		_discard_button.visible = not _options.is_empty()


## §3 卡片解剖：scale glyph + 名称 + 位置/等级说明 + 底缘标签色条（选项 JSON 色）
func _make_option_card(option: Dictionary, index: int) -> Control:
	var card: Control = _ChoiceCardScript.new()
	var color_text: String = str(option.get("placeholder_color", ""))
	var tag_color: Color = Color.html(color_text) if Color.html_is_valid(color_text) \
			else ConfigManager.get_palette_color("text_primary")
	var slot: String = str(option.get("target_slot", ""))
	var level: int = maxi(1, int(option.get("level", 1)) + int(option.get("level_delta", 0)))
	var desc: String = str(option.get("description", ""))
	if desc.is_empty():
		desc = "位置: %s Lv.%d" % [str(_SLOT_NAMES.get(slot, slot)), level]
	card.set_content({
		"glyph_id": "scale",
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


func _on_discard_pressed() -> void:
	discard_offer()
