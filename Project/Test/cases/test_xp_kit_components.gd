extends RefCounted
## SpecKit 004 T005: choice_card / banner / chip 组件契约测试
## 设计文档: Designs/Interactive/presentation_design.md §3（卡片解剖/选中态）/§11.3（零编排，只有组件态）
## 内容 set/getter 往返 + 选中/禁用态 + chip 分组与 bounce + banner 文字与对比度

const CARD_PATH: String = "res://ui/kit/choice_card.gd"
const BANNER_PATH: String = "res://ui/kit/banner.gd"
const CHIP_PATH: String = "res://ui/kit/chip.gd"
const ThemeBuilderScript := preload("res://ui/kit/theme_builder.gd")

## 设计 §3：选中态 scale 1.05
const SELECTED_SCALE: float = 1.05


func run(t) -> void:
	for path in [CARD_PATH, BANNER_PATH, CHIP_PATH]:
		t.assert_file_exists(path)
		if not FileAccess.file_exists(path):
			return
	var card_script = load(CARD_PATH)
	var banner_script = load(BANNER_PATH)
	var chip_script = load(CHIP_PATH)
	for script in [card_script, banner_script, chip_script]:
		t.assert_true(script is GDScript and script.can_instantiate(), "%s loads and instantiates" % script.resource_path.get_file())
		if not (script is GDScript and script.can_instantiate()):
			return

	# ============ choice_card ============
	var card = card_script.new()
	t.add_child(card)

	# --- 内容 set/getter 往返 ---
	var tag_color: Color = ConfigManager.get_palette_color("room_reward")
	card.set_content({"glyph_id": "reward", "name": "测试卡", "desc": "效果说明文本", "tag_color": tag_color})
	var content: Dictionary = card.get_content()
	t.assert_eq(str(content.get("glyph_id")), "reward", "card content glyph_id round-trips")
	t.assert_eq(str(content.get("name")), "测试卡", "card content name round-trips")
	t.assert_eq(str(content.get("desc")), "效果说明文本", "card content desc round-trips")
	t.assert_eq(content.get("tag_color"), tag_color, "card content tag_color round-trips")

	# --- 选中态切换：scale 1.05（追踪 tween，settle 后到终态）+ 可还原 ---
	t.assert_false(card.is_selected(), "card starts unselected")
	card.set_selected(true)
	t.assert_true(card.is_selected(), "set_selected(true) toggles state")
	card.settle()
	t.assert_true(card.scale.is_equal_approx(Vector2(SELECTED_SCALE, SELECTED_SCALE)), "selected card settles at scale 1.05 (got %s)" % card.scale)
	card.set_selected(false)
	t.assert_false(card.is_selected(), "set_selected(false) toggles back")
	card.settle()
	t.assert_true(card.scale.is_equal_approx(Vector2.ONE), "deselected card settles back at scale 1.0 (got %s)" % card.scale)

	# --- 禁用态：modulate 去饱和 + 可还原 ---
	t.assert_false(card.is_disabled(), "card starts enabled")
	card.set_disabled(true)
	t.assert_true(card.is_disabled(), "set_disabled(true) toggles state")
	t.assert_true(card.modulate != Color.WHITE, "disabled card desaturates via modulate")
	card.set_disabled(false)
	t.assert_false(card.is_disabled(), "set_disabled(false) toggles back")
	t.assert_eq(card.modulate, Color.WHITE, "enabled card restores modulate")

	# --- 命中目标：卡片可交互，入 ui_hit 且 ≥ min_hit_target（§6/§12.1） ---
	var min_hit: float = float(ConfigManager.get_layout_config().get("min_hit_target", 0))
	t.assert_true(card.is_in_group("ui_hit"), "choice_card registers itself as ui_hit target")
	t.assert_true(card.custom_minimum_size.x >= min_hit and card.custom_minimum_size.y >= min_hit, "choice_card min size >= min_hit_target")

	# ============ banner ============
	var banner = banner_script.new()
	t.add_child(banner)
	banner.set_text("第 1 层", "战斗")
	t.assert_eq(banner.get_title_text(), "第 1 层", "banner title set")
	t.assert_eq(banner.get_subtitle_text(), "战斗", "banner subtitle set")

	# --- set_accent：底色 + 文字色保大字对比阈值（亮金底必须用深字，§2.1/§12.1） ---
	var min_large: float = float(ConfigManager.get_acceptance_config().get("contrast_min_large", 0.0))
	for room_token in ["room_combat", "room_reward", "room_rest", "room_endpoint", "room_shop", "room_elite"]:
		var accent: Color = ConfigManager.get_palette_color(room_token)
		banner.set_accent(accent)
		t.assert_eq(banner.get_accent_color(), accent, "banner accent stored for %s" % room_token)
		var ratio: float = ThemeBuilderScript.contrast_ratio(banner.get_text_color(), accent)
		t.assert_true(ratio >= min_large, "banner text on %s contrast %.2f >= %.2f" % [room_token, ratio, min_large])

	# ============ chip ============
	var chip = chip_script.new()
	t.add_child(chip)
	t.assert_true(chip.is_in_group("ui_chip"), "chip is additionally in group ui_chip")
	chip.set_content("shedskin", "12")
	t.assert_eq(chip.get_glyph_id(), "shedskin", "chip glyph_id set")
	t.assert_eq(chip.get_text(), "12", "chip text set")

	# --- bounce()：一次性追踪 tween，settle 后回到静止 scale 1.0 ---
	chip.bounce()
	chip.settle()
	t.assert_true(chip.scale.is_equal_approx(Vector2.ONE), "chip bounce settles back to rest scale (got %s)" % chip.scale)

	# ============ 共性：全部组件出生即在 ui_kit 组且带 ui_layer 元数据 ============
	var components: Array = [[card, "choice_card"], [banner, "banner"], [chip, "chip"]]
	for pair in components:
		var comp = pair[0]
		var comp_name: String = pair[1]
		t.assert_true(comp.is_in_group("ui_kit"), "%s is in group ui_kit" % comp_name)
		t.assert_true(comp.has_meta("ui_layer"), "%s has ui_layer meta" % comp_name)

	card.queue_free()
	banner.queue_free()
	chip.queue_free()
