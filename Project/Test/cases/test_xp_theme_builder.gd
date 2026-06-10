extends RefCounted
## SpecKit 004 T002: theme_builder 契约测试
## 设计文档: Designs/Interactive/presentation_design.md §2/§4/§12.1
## JSON→Theme（类型变体字号/面板底色/按钮四态）+ WCAG 对比度对全部达标

const THEME_BUILDER_PATH: String = "res://ui/kit/theme_builder.gd"

## 字号阶梯类型变体 → typography 键（§4）
const LABEL_VARIANTS: Dictionary = {
	"DisplayLabel": "display",
	"TitleLabel": "title",
	"HeadingLabel": "heading",
	"BodyLabel": "body",
	"CaptionLabel": "caption",
}

## get_contrast_pairs() 必须覆盖的对（按 name 断言）
const REQUIRED_PAIR_NAMES: Array = [
	"text_primary_on_bg_panel",
	"text_primary_on_bg_panel_raised",
	"text_dim_on_bg_panel",
	"banner_text_on_room_combat",
	"banner_text_on_room_reward",
	"banner_text_on_room_rest",
	"banner_text_on_room_endpoint",
	"banner_text_on_room_shop",
	"banner_text_on_room_elite",
]


func run(t) -> void:
	t.assert_file_exists(THEME_BUILDER_PATH)
	if not FileAccess.file_exists(THEME_BUILDER_PATH):
		return
	var builder_script = load(THEME_BUILDER_PATH)
	t.assert_true(builder_script is GDScript and builder_script.can_instantiate(), "theme_builder.gd loads and instantiates")
	if not (builder_script is GDScript and builder_script.can_instantiate()):
		return
	var builder = builder_script.new()

	# --- WCAG contrast_ratio 静态数学（§12.1） ---
	var white_black: float = builder_script.contrast_ratio(Color.WHITE, Color.BLACK)
	t.assert_true(absf(white_black - 21.0) < 0.01, "contrast_ratio(white, black) == 21 (got %.4f)" % white_black)
	var black_white: float = builder_script.contrast_ratio(Color.BLACK, Color.WHITE)
	t.assert_true(absf(black_white - 21.0) < 0.01, "contrast_ratio is symmetric (got %.4f)" % black_white)
	var same: float = builder_script.contrast_ratio(Color.WHITE, Color.WHITE)
	t.assert_true(absf(same - 1.0) < 0.001, "contrast_ratio(same, same) == 1 (got %.4f)" % same)

	# --- build() -> Theme ---
	var theme = builder.build()
	t.assert_true(theme is Theme, "build() returns Theme")
	if not theme is Theme:
		return

	# --- Label 类型变体：字号阶梯（§4） ---
	var typo: Dictionary = ConfigManager.get_typography()
	for variant in LABEL_VARIANTS:
		t.assert_eq(String(theme.get_type_variation_base(variant)), "Label", "'%s' is a Label type variation" % variant)
		t.assert_true(theme.has_font_size("font_size", variant), "'%s' has font_size override" % variant)
		var expected_size: int = int(typo.get(LABEL_VARIANTS[variant], 0))
		t.assert_eq(theme.get_font_size("font_size", variant), expected_size, "'%s' font size == typography.%s (%d)" % [variant, LABEL_VARIANTS[variant], expected_size])

	# --- 默认字色 text_primary ---
	t.assert_true(theme.has_color("font_color", "Label"), "Label has default font_color")
	t.assert_eq(theme.get_color("font_color", "Label"), ConfigManager.get_palette_color("text_primary"), "Label font_color == palette text_primary")

	# --- PanelContainer：bg_panel 底、无边框（角括号由 kit_panel 负责） ---
	var panel_sb = theme.get_stylebox("panel", "PanelContainer")
	t.assert_true(panel_sb is StyleBoxFlat, "PanelContainer 'panel' stylebox is StyleBoxFlat")
	if panel_sb is StyleBoxFlat:
		t.assert_eq(panel_sb.bg_color, ConfigManager.get_palette_color("bg_panel"), "panel stylebox bg == palette bg_panel")
		var border_total: int = panel_sb.border_width_left + panel_sb.border_width_top + panel_sb.border_width_right + panel_sb.border_width_bottom
		t.assert_eq(border_total, 0, "panel stylebox has no border")

	# --- Button 四态 ---
	for state in ["normal", "hover", "pressed", "disabled"]:
		t.assert_true(theme.has_stylebox(state, "Button"), "Button has '%s' stylebox" % state)
	var btn_normal = theme.get_stylebox("normal", "Button")
	t.assert_true(btn_normal is StyleBoxFlat, "Button 'normal' stylebox is StyleBoxFlat")
	if btn_normal is StyleBoxFlat:
		t.assert_eq(btn_normal.bg_color, ConfigManager.get_palette_color("bg_panel_raised"), "Button normal bg == palette bg_panel_raised")

	# --- 对比度对：全部达标（§12.1，body 4.5 / large 3.0） ---
	var acceptance: Dictionary = ConfigManager.get_acceptance_config()
	var min_body: float = float(acceptance.get("contrast_min_body", 0.0))
	var min_large: float = float(acceptance.get("contrast_min_large", 0.0))
	t.assert_true(min_body > 0.0 and min_large > 0.0, "acceptance contrast thresholds present")

	var pairs: Array = builder.get_contrast_pairs()
	var pair_names: Array = []
	for pair in pairs:
		pair_names.append(str(pair.get("name", "")))
	for required_name in REQUIRED_PAIR_NAMES:
		t.assert_true(pair_names.has(required_name), "contrast pairs cover '%s'" % required_name)

	for pair in pairs:
		var role: String = str(pair.get("role", ""))
		t.assert_true(role == "body" or role == "large", "pair '%s' role is body|large" % str(pair.get("name", "?")))
		var min_ratio: float = min_large if role == "large" else min_body
		var ratio: float = builder_script.contrast_ratio(pair.get("fg", Color.MAGENTA), pair.get("bg", Color.MAGENTA))
		t.assert_true(ratio >= min_ratio, "contrast '%s' (%s) %.2f >= %.2f" % [str(pair.get("name", "?")), role, ratio, min_ratio])
