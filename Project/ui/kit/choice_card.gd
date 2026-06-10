extends "res://ui/kit/kit_panel.gd"
## 选择卡组件（SpecKit 004 T005，设计文档 presentation_design.md §3 卡片解剖）
## 无 class_name：消费方一律 preload 本文件。
## 解剖：上 glyph 区（48px = 3 基准单位）/ 中名称（HeadingLabel）/
## 下效果说明（BodyLabel，自动换行 ≤2 行，显式声明截断）/ 底缘 4px 标签色条。
## 零编排（§11.3）：只有 selected/disabled 组件态，选择仪式编排属 Phase P。

const _GlyphScript := preload("res://ui/kit/glyph.gd")

var _glyph: Control
var _name_label: Label
var _desc_label: Label
var _tag_strip: ColorRect
var _content: Dictionary = {}
var _selected: bool = false
var _disabled: bool = false


func _init() -> void:
	super._init("modal")
	_build_ui()
	# 卡片本身即交互命中目标（选择仪式 ←→/1-3/鼠标，§8.3）
	register_hit_target(self)


func _build_ui() -> void:
	var layout: Dictionary = ConfigManager.get_layout_config()
	var base_unit: float = float(layout.get("base_unit", 0))
	var column := VBoxContainer.new()
	add_child(column)

	_glyph = _GlyphScript.new()
	# §3 glyph 区 48px = 3 基准单位
	_glyph.custom_minimum_size = Vector2(base_unit * 3.0, base_unit * 3.0)
	column.add_child(_glyph)

	_name_label = Label.new()
	_name_label.theme_type_variation = "HeadingLabel"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_name_label)

	_desc_label = Label.new()
	_desc_label.theme_type_variation = "BodyLabel"
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.max_lines_visible = 2
	_desc_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# §12.1：≤2 行是刻意截断，显式声明豁免几何探针
	set_allow_truncate(_desc_label)
	column.add_child(_desc_label)

	_tag_strip = ColorRect.new()
	# §3 底缘 4px 色条 = 0.25 基准单位
	_tag_strip.custom_minimum_size = Vector2(0, base_unit * 0.25)
	column.add_child(_tag_strip)


## content: {glyph_id: String, name: String, desc: String, tag_color: Color}
func set_content(content: Dictionary) -> void:
	_content = content.duplicate()
	var tag_color_value: Variant = content.get("tag_color")
	var has_tag_color: bool = tag_color_value is Color
	var glyph_color: Color = tag_color_value if has_tag_color else ConfigManager.get_palette_color("text_primary")
	_glyph.set_glyph(str(content.get("glyph_id", "")), glyph_color)
	_glyph.set_cut_color(ConfigManager.get_palette_color("bg_panel"))
	_name_label.text = str(content.get("name", ""))
	_desc_label.text = str(content.get("desc", ""))
	_tag_strip.color = tag_color_value if has_tag_color else Color.TRANSPARENT


func get_content() -> Dictionary:
	return _content.duplicate()


## §3 选中态：外框亮起 + scale 1.05（FEEDBACK_SCALE，追踪 tween 供 settle 快进）
func set_selected(selected: bool) -> void:
	if _selected == selected:
		return
	_selected = selected
	set_frame_highlighted(selected)
	var target: float = FEEDBACK_SCALE if selected else 1.0
	if not is_inside_tree():
		scale = Vector2(target, target)
		return
	var durations: Dictionary = ConfigManager.get_motion().get("durations", {})
	var duration: float = float(durations.get("half_tick", 0.0))
	var easing: Dictionary = get_easing("feedback")
	var tw: Tween = create_tween()
	tw.tween_property(self, "scale", Vector2(target, target), duration) \
		.set_trans(easing.trans).set_ease(easing.ease)
	track_tween(tw)


func is_selected() -> bool:
	return _selected


## 禁用态：modulate 染 text_dim 去饱和（余额不足等，§8.4）
func set_disabled(disabled: bool) -> void:
	_disabled = disabled
	if disabled:
		var dim: Color = ConfigManager.get_palette_color("text_dim")
		modulate = Color(dim.r, dim.g, dim.b, 1.0)
	else:
		modulate = Color.WHITE


func is_disabled() -> bool:
	return _disabled
