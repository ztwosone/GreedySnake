extends "res://ui/kit/kit_panel.gd"
## 房间意图面板（SpecKit 004 T011：L3 占位 → kit 迁移）
## 设计: Designs/Interactive/presentation_design.md §3（glyph 词汇表）/§4（字号阶梯）/
## §8.1（Phase F 静态版：横幅 + glyph/进度行常驻；两段式横幅→chip 收缩编排属 Phase P）。
## 无 class_name：消费方一律按路径加载（ScriptingLeading 附录 C.8）。
## 表现层只听不驱动（§11.1）：仅监听 EventBus，不改游戏状态。
## 公共契约不变（既有 test_l3_* 依赖）：visible on room_entered +
## get_intent_text / get_progress_text / get_status_text / get_placeholder_color。

const _BannerScript := preload("res://ui/kit/banner.gd")
const _GlyphScript := preload("res://ui/kit/glyph.gd")

var _banner: Control
var _glyph: Control
var _progress_label: Label
var _status_label: Label
var _current_room_id: String = ""
var _intent_text: String = ""
var _display_text: String = ""
var _progress_text: String = ""
var _status_text: String = ""
var _glyph_id: String = ""
var _placeholder_color: Color = Color()
var _intent_color: Color = Color()


func _init() -> void:
	super._init("hud")


func _ready() -> void:
	_placeholder_color = ConfigManager.get_palette_color("text_primary")
	_intent_color = ConfigManager.get_palette_color("text_primary")
	_build_ui()
	_connect_events()
	visible = false


func _exit_tree() -> void:
	_disconnect_events()


func _build_ui() -> void:
	var layout: Dictionary = ConfigManager.get_layout_config()
	var base_unit: float = float(layout.get("base_unit", 0))
	var screen_margin: float = float(layout.get("screen_margin", 0))

	# §6 布局：顶中横幅区（左右各让出 20 基准单位给小地图/蜕皮 chip）；高度随内容
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	offset_left = base_unit * 20.0
	offset_right = -base_unit * 20.0
	offset_top = screen_margin
	offset_bottom = screen_margin
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(base_unit * 0.25))
	add_child(column)

	# §8.1 房间意图横幅（静态版）：房色底 + display_name + intent_label
	_banner = _BannerScript.new()
	column.add_child(_banner)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(base_unit * 0.5))
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)

	# §3 房型 glyph（chip 级 1 基准单位图标）
	_glyph = _GlyphScript.new()
	_glyph.custom_minimum_size = Vector2(base_unit, base_unit)
	row.add_child(_glyph)

	_progress_label = Label.new()
	_progress_label.theme_type_variation = "BodyLabel"
	row.add_child(_progress_label)

	_status_label = Label.new()
	_status_label.theme_type_variation = "CaptionLabel"
	row.add_child(_status_label)


func _connect_events() -> void:
	if not EventBus.room_entered.is_connected(_on_room_entered):
		EventBus.room_entered.connect(_on_room_entered)
	if not EventBus.room_objective_progressed.is_connected(_on_room_objective_progressed):
		EventBus.room_objective_progressed.connect(_on_room_objective_progressed)
	if not EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.connect(_on_room_completed)


func _disconnect_events() -> void:
	if EventBus.room_entered.is_connected(_on_room_entered):
		EventBus.room_entered.disconnect(_on_room_entered)
	if EventBus.room_objective_progressed.is_connected(_on_room_objective_progressed):
		EventBus.room_objective_progressed.disconnect(_on_room_objective_progressed)
	if EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.disconnect(_on_room_completed)


func get_intent_text() -> String:
	return _intent_text


func get_progress_text() -> String:
	return _progress_text


func get_status_text() -> String:
	return _status_text


## 兼容 getter（§2.2 迁移期语义升级，字段名保留）：返回事件数据携带的房间色
func get_placeholder_color() -> Color:
	return _placeholder_color


## T011 新增：当前房型对应的 glyph id（房型→glyph 同名映射，无定义则空串）
func get_glyph_id() -> String:
	return _glyph_id


## T011 新增：渲染所用房间意图色（room_* palette token 优先）
func get_intent_color() -> Color:
	return _intent_color


func _on_room_entered(data: Dictionary) -> void:
	_current_room_id = data.get("room_id", "")
	_intent_text = data.get("intent_label", data.get("room_type", ""))
	_status_text = "进行中"

	var objective: Dictionary = data.get("objective", {})
	var current: int = int(objective.get("current_count", 0))
	var required: int = int(objective.get("required_count", 1))
	_progress_text = "%d/%d" % [current, required]

	var color_text: String = str(data.get("placeholder_color", ""))
	if Color.html_is_valid(color_text):
		_placeholder_color = Color.html(color_text)
	var room_type: String = str(data.get("room_type", ""))
	_display_text = str(ConfigManager.get_room_type(room_type).get("display_name", _intent_text))
	_glyph_id = room_type if not ConfigManager.get_glyph_def(room_type).is_empty() else ""
	_intent_color = _resolve_room_color(room_type)
	_refresh()
	visible = true


func _on_room_objective_progressed(data: Dictionary) -> void:
	if data.get("room_id", "") != _current_room_id:
		return
	_progress_text = "%d/%d" % [int(data.get("current", 0)), int(data.get("required", 1))]
	_status_text = "进行中"
	_refresh()


func _on_room_completed(data: Dictionary) -> void:
	if data.get("room_id", "") != _current_room_id:
		return
	_status_text = "完成"
	_refresh()


## §2.1：room_* palette token 优先；palette 外房型回退事件 placeholder_color（§2.2 迁移期兼容）
func _resolve_room_color(room_type: String) -> Color:
	var token: String = "room_%s" % room_type
	var palette: Dictionary = ConfigManager.get_presentation_config().get("palette", {})
	if palette.has(token):
		return ConfigManager.get_palette_color(token)
	return _placeholder_color


func _refresh() -> void:
	if _banner:
		_banner.set_accent(_intent_color)
		_banner.set_text(_display_text, _intent_text)
	if _glyph:
		_glyph.visible = _glyph_id != ""
		if _glyph_id != "":
			_glyph.set_glyph(_glyph_id, _intent_color)
	if _progress_label:
		_progress_label.text = _progress_text
	if _status_label:
		_status_label.text = _status_text
		# 完成态盖「完成」章（§8.1）：confirm 绿；进行中保持次要文本色
		var status_token: String = "accent_confirm" if _status_text.find("完成") >= 0 else "text_dim"
		_status_label.add_theme_color_override("font_color", ConfigManager.get_palette_color(status_token))
