extends "res://ui/kit/kit_panel.gd"
## 楼层进度面板（SpecKit 004 T011：L3 占位 → kit 迁移）
## 设计: Designs/Interactive/presentation_design.md §8.2（楼层小地图语义：
## 当前=高亮/完成=暗化/未达=深灰）/§3（房型 glyph）/§6（最小命中目标）。
## 无 class_name：消费方一律按路径加载（ScriptingLeading 附录 C.8）。
## 表现层只听不驱动（§11.1）：Next 仅沿既有契约 emit room_advance_requested。
## 公共契约不变（既有 test_l3_* 依赖）：visible on floor_generated +
## get_progress_text / get_status_text / request_next_room()。

const _GlyphScript := preload("res://ui/kit/glyph.gd")

var _path: Array = []
var _current_room_id: String = ""
var _completed_room_ids: Array = []
var _available_room_ids: Array = []
var _progress_text: String = ""
var _status_text: String = ""
var _progress_label: Label
var _status_label: Label
var _path_row: HBoxContainer
var _next_button: Button
var _block_infos: Array = []
## FR-015（spec 002 T007）：任一 offer 未决时 Next 禁用、request_next_room 拒绝
var _pending_offer_families: Dictionary = {}


func _init() -> void:
	super._init("hud")


func _ready() -> void:
	_build_ui()
	_connect_events()
	visible = false


func _exit_tree() -> void:
	_disconnect_events()


func get_progress_text() -> String:
	return _progress_text


func get_status_text() -> String:
	return _status_text


func request_next_room() -> bool:
	if is_advance_blocked():
		return false
	var room_id: String = _get_next_available_room_id()
	if room_id == "":
		return false
	EventBus.room_advance_requested.emit({"room_id": room_id})
	return true


## FR-015：是否因未决 offer 而禁止推进
func is_advance_blocked() -> bool:
	return not _pending_offer_families.is_empty()


## T011 新增：路径块数量（每房一块）
func get_path_block_count() -> int:
	return _block_infos.size()


## T011 新增：路径块渲染状态（room_id/state/color/glyph_id/highlighted）
func get_path_block_info(index: int) -> Dictionary:
	if index < 0 or index >= _block_infos.size():
		return {}
	return _block_infos[index].duplicate()


## T011 新增：Next 按钮（ui_hit 命中目标，供几何探针与 ui_actor 取用）
func get_next_button() -> Button:
	return _next_button


func _build_ui() -> void:
	var layout: Dictionary = ConfigManager.get_layout_config()
	var base_unit: float = float(layout.get("base_unit", 0))
	var screen_margin: float = float(layout.get("screen_margin", 0))

	# §6 布局：左上小地图区（宽 18 基准单位，顶部让出 8 单位给既有 HUD）；高度随内容
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = screen_margin
	offset_right = screen_margin + base_unit * 18.0
	offset_top = base_unit * 8.0
	offset_bottom = base_unit * 8.0
	mouse_filter = Control.MOUSE_FILTER_STOP

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(base_unit * 0.25))
	add_child(column)

	_progress_label = Label.new()
	_progress_label.theme_type_variation = "HeadingLabel"
	column.add_child(_progress_label)

	_status_label = Label.new()
	_status_label.theme_type_variation = "CaptionLabel"
	column.add_child(_status_label)

	_path_row = HBoxContainer.new()
	_path_row.add_theme_constant_override("separation", int(base_unit * 0.25))
	column.add_child(_path_row)

	_next_button = Button.new()
	_next_button.text = "下一房间"
	_next_button.disabled = true
	_next_button.pressed.connect(_on_next_pressed)
	# §6/§12.1：交互件入 ui_hit 组并保证最小命中目标
	register_hit_target(_next_button)
	column.add_child(_next_button)


func _connect_events() -> void:
	if not EventBus.floor_generated.is_connected(_on_floor_generated):
		EventBus.floor_generated.connect(_on_floor_generated)
	if not EventBus.room_entered.is_connected(_on_room_entered):
		EventBus.room_entered.connect(_on_room_entered)
	if not EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.connect(_on_room_completed)
	if not EventBus.reward_presented.is_connected(_on_reward_presented):
		EventBus.reward_presented.connect(_on_reward_presented)
	if not EventBus.reward_chosen.is_connected(_on_reward_chosen):
		EventBus.reward_chosen.connect(_on_reward_chosen)
	if not EventBus.scale_reward_presented.is_connected(_on_scale_reward_presented):
		EventBus.scale_reward_presented.connect(_on_scale_reward_presented)
	if not EventBus.scale_reward_chosen.is_connected(_on_scale_reward_chosen):
		EventBus.scale_reward_chosen.connect(_on_scale_reward_chosen)
	if not EventBus.scale_option_discarded.is_connected(_on_scale_option_discarded):
		EventBus.scale_option_discarded.connect(_on_scale_option_discarded)
	if not EventBus.floor_reward_presented.is_connected(_on_floor_reward_presented):
		EventBus.floor_reward_presented.connect(_on_floor_reward_presented)
	if not EventBus.floor_reward_chosen.is_connected(_on_floor_reward_chosen):
		EventBus.floor_reward_chosen.connect(_on_floor_reward_chosen)


func _disconnect_events() -> void:
	if EventBus.floor_generated.is_connected(_on_floor_generated):
		EventBus.floor_generated.disconnect(_on_floor_generated)
	if EventBus.room_entered.is_connected(_on_room_entered):
		EventBus.room_entered.disconnect(_on_room_entered)
	if EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.disconnect(_on_room_completed)
	if EventBus.reward_presented.is_connected(_on_reward_presented):
		EventBus.reward_presented.disconnect(_on_reward_presented)
	if EventBus.reward_chosen.is_connected(_on_reward_chosen):
		EventBus.reward_chosen.disconnect(_on_reward_chosen)
	if EventBus.scale_reward_presented.is_connected(_on_scale_reward_presented):
		EventBus.scale_reward_presented.disconnect(_on_scale_reward_presented)
	if EventBus.scale_reward_chosen.is_connected(_on_scale_reward_chosen):
		EventBus.scale_reward_chosen.disconnect(_on_scale_reward_chosen)
	if EventBus.scale_option_discarded.is_connected(_on_scale_option_discarded):
		EventBus.scale_option_discarded.disconnect(_on_scale_option_discarded)
	if EventBus.floor_reward_presented.is_connected(_on_floor_reward_presented):
		EventBus.floor_reward_presented.disconnect(_on_floor_reward_presented)
	if EventBus.floor_reward_chosen.is_connected(_on_floor_reward_chosen):
		EventBus.floor_reward_chosen.disconnect(_on_floor_reward_chosen)


func _set_offer_pending(family: String, pending: bool) -> void:
	if pending:
		_pending_offer_families[family] = true
	else:
		_pending_offer_families.erase(family)
	_refresh_next_button()


func _on_reward_presented(_data: Dictionary) -> void:
	_set_offer_pending("reward", true)


func _on_reward_chosen(_data: Dictionary) -> void:
	_set_offer_pending("reward", false)


func _on_scale_reward_presented(_data: Dictionary) -> void:
	_set_offer_pending("scale_reward", true)


func _on_scale_reward_chosen(_data: Dictionary) -> void:
	_set_offer_pending("scale_reward", false)


func _on_scale_option_discarded(_data: Dictionary) -> void:
	_set_offer_pending("scale_reward", false)


func _on_floor_reward_presented(_data: Dictionary) -> void:
	_set_offer_pending("floor_reward", true)


func _on_floor_reward_chosen(_data: Dictionary) -> void:
	_set_offer_pending("floor_reward", false)


func _on_floor_generated(data: Dictionary) -> void:
	_path.clear()
	for room in data.get("rooms", []):
		if room is Dictionary:
			_path.append(room.duplicate(true))
	_current_room_id = data.get("start_room_id", "")
	_completed_room_ids.clear()
	_available_room_ids = [_current_room_id] if _current_room_id != "" else []
	_status_text = "当前房间"
	_refresh()
	visible = true


func _on_room_entered(data: Dictionary) -> void:
	_current_room_id = data.get("room_id", _current_room_id)
	_available_room_ids.erase(_current_room_id)
	_status_text = data.get("intent_label", data.get("room_type", ""))
	_refresh()


func _on_room_completed(data: Dictionary) -> void:
	var room_id: String = data.get("room_id", "")
	if room_id != "" and not _completed_room_ids.has(room_id):
		_completed_room_ids.append(room_id)
	_available_room_ids.erase(room_id)
	for exit_id in _get_exit_ids(room_id):
		if not _available_room_ids.has(exit_id):
			_available_room_ids.append(exit_id)
	_status_text = "房间完成，可进入下一房间" if _get_exit_ids(room_id).size() > 0 else "房间完成"
	_refresh()


func _refresh() -> void:
	var current_index: int = 0
	for index in range(_path.size()):
		if _path[index].get("room_id", "") == _current_room_id:
			current_index = index + 1
			break
	var total: int = _path.size()
	_progress_text = "%d/%d" % [current_index, total]
	if _progress_label:
		_progress_label.text = _progress_text
	if _status_label:
		_status_label.text = _status_text
		# 完成态反馈 confirm 绿；其余次要文本色
		var status_token: String = "accent_confirm" if _status_text.find("完成") >= 0 else "text_dim"
		_status_label.add_theme_color_override("font_color", ConfigManager.get_palette_color(status_token))
	_refresh_path_row()
	_refresh_next_button()


func _refresh_path_row() -> void:
	if _path_row == null:
		return
	for child in _path_row.get_children():
		_path_row.remove_child(child)
		child.free()
	_block_infos.clear()
	var base_unit: float = float(ConfigManager.get_layout_config().get("base_unit", 0))
	for room in _path:
		var room_id: String = str(room.get("room_id", ""))
		var room_type: String = str(room.get("room_type", ""))
		var state: String = _block_state(room_id)
		var color: Color = _block_color(state, room_type, str(room.get("placeholder_color", "")))
		var glyph_id: String = room_type if not ConfigManager.get_glyph_def(room_type).is_empty() else ""
		var highlighted: bool = state == "current"
		_path_row.add_child(_make_path_block(glyph_id, color, highlighted, base_unit))
		_block_infos.append({
			"room_id": room_id,
			"state": state,
			"color": color,
			"glyph_id": glyph_id,
			"highlighted": highlighted,
		})


## §8.2 路径块：房型 glyph（1 基准单位）+ 当前房高亮下划线（accent_resonance）
func _make_path_block(glyph_id: String, color: Color, highlighted: bool, base_unit: float) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	if glyph_id != "":
		var glyph: Control = _GlyphScript.new()
		glyph.custom_minimum_size = Vector2(base_unit, base_unit)
		glyph.set_glyph(glyph_id, color)
		box.add_child(glyph)
	else:
		# 无 glyph 定义的房型回退色块（§2.2 迁移期兼容）
		var block := ColorRect.new()
		block.custom_minimum_size = Vector2(base_unit, base_unit)
		block.color = color
		box.add_child(block)
	var underline := ColorRect.new()
	underline.custom_minimum_size = Vector2(base_unit, base_unit * 0.125)
	underline.color = ConfigManager.get_palette_color("accent_resonance") if highlighted else Color.TRANSPARENT
	box.add_child(underline)
	return box


func _block_state(room_id: String) -> String:
	if _completed_room_ids.has(room_id):
		return "completed"
	if room_id == _current_room_id:
		return "current"
	if _available_room_ids.has(room_id):
		return "available"
	return "locked"


## §8.2：完成=暗化（text_dim）/未达=深灰（frame_line）/当前与可达=房间意图色
func _block_color(state: String, room_type: String, fallback_hex: String) -> Color:
	match state:
		"completed":
			return ConfigManager.get_palette_color("text_dim")
		"locked":
			return ConfigManager.get_palette_color("frame_line")
		_:
			return _room_color(room_type, fallback_hex)


## §2.1：room_* palette token 优先；palette 外房型回退事件 placeholder_color
func _room_color(room_type: String, fallback_hex: String) -> Color:
	var token: String = "room_%s" % room_type
	var palette: Dictionary = ConfigManager.get_presentation_config().get("palette", {})
	if palette.has(token):
		return ConfigManager.get_palette_color(token)
	if Color.html_is_valid(fallback_hex):
		return Color.html(fallback_hex)
	return ConfigManager.get_palette_color("text_primary")


func _refresh_next_button() -> void:
	if _next_button == null:
		return
	# FR-015：未决 offer 期间禁用（与 request_next_room 的拒绝一致）
	_next_button.disabled = is_advance_blocked() or _get_next_available_room_id() == ""


func _get_exit_ids(room_id: String) -> Array:
	for room in _path:
		if room is Dictionary and room.get("room_id", "") == room_id:
			return room.get("exit_room_ids", []).duplicate()
	return []


func _get_next_available_room_id() -> String:
	for room_id in _available_room_ids:
		if room_id != _current_room_id and not _completed_room_ids.has(room_id):
			return room_id
	return ""


func _on_next_pressed() -> void:
	request_next_room()
