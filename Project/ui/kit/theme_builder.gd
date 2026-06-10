extends RefCounted
## JSON → Theme 构建器（SpecKit 004 T002，设计文档 presentation_design.md §2/§4/§12.1）
## 无 class_name：消费方一律 preload 本文件（ScriptingLeading 附录 C.8）。
## 纯函数式：build() 每次从 ConfigManager 的 presentation 段构建全新 Theme，可单测。

## §4 字号阶梯：Label 类型变体 → typography 键
const LABEL_VARIANTS: Dictionary = {
	"DisplayLabel": "display",
	"TitleLabel": "title",
	"HeadingLabel": "heading",
	"BodyLabel": "body",
	"CaptionLabel": "caption",
}

## 房间意图横幅前景色选择（§2.1 + §12.1 对比度契约）：
## 亮色房间底（reward 金/rest 绿/shop 蓝）用 bg_deep 深字，
## 暗色房间底（combat/endpoint/elite）用 text_primary 亮字。
## banner 组件（T005+）从此表取横幅文字色，保证 large 阈值（≥3.0）达标。
const ROOM_BANNER_FG: Dictionary = {
	"room_combat": "text_primary",
	"room_reward": "bg_deep",
	"room_rest": "bg_deep",
	"room_endpoint": "text_primary",
	"room_shop": "bg_deep",
	"room_elite": "text_primary",
}


func build() -> Theme:
	var theme := Theme.new()
	var typography: Dictionary = ConfigManager.get_typography()
	var layout: Dictionary = ConfigManager.get_layout_config()
	var text_primary: Color = ConfigManager.get_palette_color("text_primary")
	var text_dim: Color = ConfigManager.get_palette_color("text_dim")
	var bg_panel: Color = ConfigManager.get_palette_color("bg_panel")
	var bg_panel_raised: Color = ConfigManager.get_palette_color("bg_panel_raised")
	var frame_line: Color = ConfigManager.get_palette_color("frame_line")
	var accent: Color = ConfigManager.get_palette_color("accent_resonance")

	# --- Label：默认字色 + 字号阶梯类型变体（§4） ---
	theme.set_color("font_color", "Label", text_primary)
	for variant in LABEL_VARIANTS:
		theme.set_type_variation(variant, "Label")
		theme.set_font_size("font_size", variant, int(typography.get(LABEL_VARIANTS[variant], 0)))

	# --- PanelContainer：bg_panel 底、无边框（角括号由 kit_panel _draw 绘制，§3） ---
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = bg_panel
	panel_sb.set_border_width_all(0)
	panel_sb.set_content_margin_all(float(layout.get("panel_padding", 0)))
	theme.set_stylebox("panel", "PanelContainer", panel_sb)

	# --- Button 四态（bg_panel_raised / frame_line / accent_resonance） ---
	var base_unit: float = float(layout.get("base_unit", 0))
	theme.set_stylebox("normal", "Button", _make_button_stylebox(bg_panel_raised, frame_line, base_unit))
	theme.set_stylebox("hover", "Button", _make_button_stylebox(bg_panel_raised, accent, base_unit))
	theme.set_stylebox("pressed", "Button", _make_button_stylebox(frame_line, accent, base_unit))
	theme.set_stylebox("disabled", "Button", _make_button_stylebox(bg_panel, frame_line, base_unit))
	theme.set_color("font_color", "Button", text_primary)
	theme.set_color("font_hover_color", "Button", text_primary)
	theme.set_color("font_pressed_color", "Button", text_primary)
	theme.set_color("font_focus_color", "Button", text_primary)
	theme.set_color("font_disabled_color", "Button", text_dim)
	return theme


func _make_button_stylebox(bg: Color, border: Color, base_unit: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	# 命中目标基于 §6 基准单位：水平 1 单位、垂直 0.5 单位内边距
	sb.content_margin_left = base_unit
	sb.content_margin_right = base_unit
	sb.content_margin_top = base_unit * 0.5
	sb.content_margin_bottom = base_unit * 0.5
	return sb


## §12.1 对比度契约对（Layer A/theme 静态断言消费）。
## role: "body"（≥ acceptance.contrast_min_body）| "large"（≥ acceptance.contrast_min_large）。
func get_contrast_pairs() -> Array:
	var pairs: Array = []
	pairs.append(_make_pair("text_primary", "bg_panel", "body", "text_primary_on_bg_panel"))
	pairs.append(_make_pair("text_primary", "bg_panel_raised", "body", "text_primary_on_bg_panel_raised"))
	pairs.append(_make_pair("text_dim", "bg_panel", "body", "text_dim_on_bg_panel"))
	# Button pressed 态底色上的文字
	pairs.append(_make_pair("text_primary", "frame_line", "body", "text_primary_on_frame_line"))
	# 房间意图横幅（display/title 级大字 → large 阈值）
	for room_token in ROOM_BANNER_FG:
		pairs.append(_make_pair(ROOM_BANNER_FG[room_token], room_token, "large", "banner_text_on_%s" % room_token))
	return pairs


func _make_pair(fg_token: String, bg_token: String, role: String, pair_name: String) -> Dictionary:
	return {
		"fg": ConfigManager.get_palette_color(fg_token),
		"bg": ConfigManager.get_palette_color(bg_token),
		"role": role,
		"name": pair_name,
	}


## WCAG 对比度（§12.1）：(L_hi + 0.05) / (L_lo + 0.05)
static func contrast_ratio(a: Color, b: Color) -> float:
	var lum_a := _relative_luminance(a)
	var lum_b := _relative_luminance(b)
	var l_hi: float = maxf(lum_a, lum_b)
	var l_lo: float = minf(lum_a, lum_b)
	return (l_hi + 0.05) / (l_lo + 0.05)


## WCAG 相对亮度：sRGB 线性化后 0.2126R + 0.7152G + 0.0722B
static func _relative_luminance(c: Color) -> float:
	return 0.2126 * _linearize(c.r) + 0.7152 * _linearize(c.g) + 0.0722 * _linearize(c.b)


static func _linearize(channel: float) -> float:
	if channel <= 0.03928:
		return channel / 12.92
	return pow((channel + 0.055) / 1.055, 2.4)
