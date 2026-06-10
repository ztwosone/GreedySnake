extends "res://ui/kit/kit_panel.gd"
## 横幅组件（SpecKit 004 T005，设计文档 presentation_design.md §7/§8.1）
## 无 class_name：消费方一律 preload 本文件。
## 全宽色带：标题（TitleLabel）+ 副标题（BodyLabel），set_accent 设房色底。
## 文字色按对比度自动选 text_primary / bg_deep（theme_builder ROOM_BANNER_FG 的泛化，
## 亮底如 reward 金必须用深字才达 §12.1 large 阈值）。
## 零编排（§11.3）：appear()/collapse() 扫入收缩属 Phase P，本层只有静态态。

var _title_label: Label
var _subtitle_label: Label
var _accent_color: Color = Color.TRANSPARENT
var _text_color: Color = Color.TRANSPARENT


func _init() -> void:
	super._init("toast")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_ui()


func _build_ui() -> void:
	var column := VBoxContainer.new()
	add_child(column)

	_title_label = Label.new()
	_title_label.theme_type_variation = "TitleLabel"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.theme_type_variation = "BodyLabel"
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_subtitle_label)


func set_text(title: String, subtitle: String) -> void:
	_title_label.text = title
	_subtitle_label.text = subtitle


## 横幅底色（房间意图色等）+ 文字色对比度自适应（§2.1/§12.1）
func set_accent(color: Color) -> void:
	_accent_color = color
	var light_text: Color = ConfigManager.get_palette_color("text_primary")
	var dark_text: Color = ConfigManager.get_palette_color("bg_deep")
	var light_ratio: float = _ThemeBuilderScript.contrast_ratio(light_text, color)
	var dark_ratio: float = _ThemeBuilderScript.contrast_ratio(dark_text, color)
	_text_color = light_text if light_ratio >= dark_ratio else dark_text

	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_border_width_all(0)
	sb.set_content_margin_all(float(ConfigManager.get_layout_config().get("panel_padding", 0)))
	add_theme_stylebox_override("panel", sb)
	_title_label.add_theme_color_override("font_color", _text_color)
	_subtitle_label.add_theme_color_override("font_color", _text_color)


func get_title_text() -> String:
	return _title_label.text


func get_subtitle_text() -> String:
	return _subtitle_label.text


func get_accent_color() -> Color:
	return _accent_color


func get_text_color() -> Color:
	return _text_color
