extends "res://ui/kit/kit_panel.gd"
## 浮层 chip 组件（SpecKit 004 T005，设计文档 presentation_design.md §6/§8.5）
## 无 class_name：消费方一律 preload 本文件。
## 紧凑 icon+text：glyph（1 基准单位）+ 文本（BodyLabel）；额外入 ui_chip 组。
## bounce()：一次性组件反馈 tween（允许：组件态反馈，非仪式编排，§11.3）。

const _GlyphScript := preload("res://ui/kit/glyph.gd")

var _glyph: Control
var _text_label: Label


func _init() -> void:
	super._init("hud")
	add_to_group("ui_chip")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()


func _build_ui() -> void:
	var layout: Dictionary = ConfigManager.get_layout_config()
	var base_unit: float = float(layout.get("base_unit", 0))
	var row := HBoxContainer.new()
	add_child(row)

	_glyph = _GlyphScript.new()
	# 紧凑图标：1 基准单位（16px）
	_glyph.custom_minimum_size = Vector2(base_unit, base_unit)
	row.add_child(_glyph)

	_text_label = Label.new()
	_text_label.theme_type_variation = "BodyLabel"
	row.add_child(_text_label)


## glyph_color 省略时取 text_primary（蜕皮 chip 等传 accent_shedskin）
func set_content(glyph_id: String, text: String, glyph_color: Color = Color.TRANSPARENT) -> void:
	var color: Color = glyph_color
	if color == Color.TRANSPARENT:
		color = ConfigManager.get_palette_color("text_primary")
	_glyph.set_glyph(glyph_id, color)
	_text_label.text = text


func get_glyph_id() -> String:
	return _glyph.get_glyph_id()


func get_text() -> String:
	return _text_label.text


## 一次性弹跳反馈（货币变化等，§8.5）：acquire 上冲 + feedback 回落，追踪供 settle 快进
func bounce() -> void:
	if not is_inside_tree():
		return
	var durations: Dictionary = ConfigManager.get_motion().get("durations", {})
	var duration: float = float(durations.get("half_tick", 0.0))
	var acquire: Dictionary = get_easing("acquire")
	var feedback: Dictionary = get_easing("feedback")
	var tw: Tween = create_tween()
	tw.tween_property(self, "scale", Vector2(FEEDBACK_SCALE, FEEDBACK_SCALE), duration) \
		.set_trans(acquire.trans).set_ease(acquire.ease)
	tw.tween_property(self, "scale", Vector2.ONE, duration) \
		.set_trans(feedback.trans).set_ease(feedback.ease)
	track_tween(tw)
