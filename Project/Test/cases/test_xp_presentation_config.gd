extends RefCounted
## SpecKit 004 T001: presentation 配置段 + ConfigManager accessor 契约测试
## 设计文档: Designs/Interactive/presentation_design.md §2.1/§4/§5/§6/§3/§12.1/§14

## §2.1 语义角色表全部 token
const PALETTE_TOKENS: Array = [
	"bg_deep", "bg_panel", "bg_panel_raised", "wall",
	"text_primary", "text_dim", "frame_line",
	"status_fire", "status_ice", "status_poison",
	"room_combat", "room_reward", "room_rest", "room_endpoint", "room_shop", "room_elite",
	"accent_shedskin", "accent_resonance", "accent_danger", "accent_confirm",
]

## §3 glyph 基础集
const GLYPH_IDS: Array = [
	"combat", "reward", "rest", "endpoint", "shop", "elite",
	"shedskin", "scale", "head", "tail", "slot_empty",
]

const ACCESSOR_METHODS: Array = [
	"get_presentation_config", "get_palette_color", "get_typography", "get_motion",
	"get_layout_config", "get_acceptance_config", "get_glyph_def", "is_debug_ui_enabled",
]


func run(t) -> void:
	var cfg = ConfigManager
	t.assert_true(cfg != null, "ConfigManager autoload exists")
	if cfg == null:
		return

	# --- accessor 存在性（duck typing，避免缺方法时脚本崩溃） ---
	var all_methods_present := true
	for method_name in ACCESSOR_METHODS:
		var has_it: bool = cfg.has_method(method_name)
		t.assert_true(has_it, "ConfigManager has accessor '%s'" % method_name)
		if not has_it:
			all_methods_present = false
	if not all_methods_present:
		return

	# --- presentation 段存在 ---
	var pres: Dictionary = cfg.get_presentation_config()
	t.assert_true(pres is Dictionary and pres.size() > 0, "presentation section present and non-empty")

	# --- palette: §2.1 全部 token 存在且可解析为合法 Color ---
	var palette: Dictionary = pres.get("palette", {})
	for token in PALETTE_TOKENS:
		t.assert_true(palette.has(token), "palette has token '%s'" % token)
		var hex: String = str(palette.get(token, ""))
		t.assert_true(Color.html_is_valid(hex), "palette '%s' value '%s' is valid html color" % [token, hex])
		var parsed: Color = cfg.get_palette_color(token)
		t.assert_true(parsed != Color.MAGENTA, "palette '%s' does not hit magenta fallback" % token)

	# --- palette 抽查精确值（§2.1） ---
	t.assert_eq(cfg.get_palette_color("bg_deep"), Color.html("#0B0E11"), "bg_deep == #0B0E11")
	t.assert_eq(cfg.get_palette_color("bg_panel"), Color.html("#12161C"), "bg_panel == #12161C")
	t.assert_eq(cfg.get_palette_color("text_primary"), Color.html("#E8ECEF"), "text_primary == #E8ECEF")
	t.assert_eq(cfg.get_palette_color("status_fire"), Color.html("#FF6B35"), "status_fire == #FF6B35 (提亮校正)")
	t.assert_eq(cfg.get_palette_color("room_elite"), Color.html("#C2185B"), "room_elite == #C2185B")

	# --- 未知 token: push_warning + magenta 回退 ---
	var fallback: Color = cfg.get_palette_color("nonexistent_token_xyz")
	t.assert_eq(fallback, Color.MAGENTA, "unknown palette token falls back to magenta")

	# --- typography: §4 字号阶梯 ---
	var typo: Dictionary = cfg.get_typography()
	t.assert_eq(typo.get("display"), 48, "typography.display == 48")
	t.assert_eq(typo.get("title"), 32, "typography.title == 32")
	t.assert_eq(typo.get("heading"), 20, "typography.heading == 20")
	t.assert_eq(typo.get("body"), 16, "typography.body == 16")
	t.assert_eq(typo.get("caption"), 13, "typography.caption == 13")

	# --- motion: §5 tick 量化时长 + 缓动表 ---
	var motion: Dictionary = cfg.get_motion()
	var durations: Dictionary = motion.get("durations", {})
	t.assert_eq(durations.get("half_tick"), 0.125, "motion.durations.half_tick == 0.125")
	t.assert_eq(durations.get("one_tick"), 0.25, "motion.durations.one_tick == 0.25")
	t.assert_eq(durations.get("two_ticks"), 0.5, "motion.durations.two_ticks == 0.5")
	t.assert_eq(motion.get("stagger_per_item"), 0.04, "motion.stagger_per_item == 0.04")
	var ceremony_range: Array = motion.get("ceremony_range_sec", [])
	t.assert_eq(ceremony_range.size(), 2, "motion.ceremony_range_sec has 2 entries")
	var easing: Dictionary = motion.get("easing", {})
	t.assert_eq(easing.get("enter"), "quint_out", "easing.enter == quint_out")
	t.assert_eq(easing.get("exit"), "cubic_in", "easing.exit == cubic_in")
	t.assert_eq(easing.get("feedback"), "cubic_out", "easing.feedback == cubic_out")
	t.assert_eq(easing.get("acquire"), "back_out", "easing.acquire == back_out")

	# --- layout: §6 空间基准 ---
	var layout: Dictionary = cfg.get_layout_config()
	t.assert_eq(layout.get("base_unit"), 16, "layout.base_unit == 16")
	t.assert_eq(layout.get("screen_margin"), 16, "layout.screen_margin == 16")
	t.assert_eq(layout.get("panel_padding"), 16, "layout.panel_padding == 16")
	t.assert_eq(layout.get("min_hit_target"), 32, "layout.min_hit_target == 32")

	# --- ceremony: §7/§8 仪式编排参数（Phase P T102 增量） ---
	var ceremony: Dictionary = cfg.get_ceremony_config()
	var dim_alpha: float = float(ceremony.get("dim_alpha", 0.0))
	t.assert_true(dim_alpha > 0.0 and dim_alpha <= 1.0,
		"ceremony.dim_alpha in (0,1] (got %s)" % str(dim_alpha))
	var dim_sec: float = float(ceremony.get("dim_sec", 0.0))
	t.assert_true(dim_sec > 0.0, "ceremony.dim_sec > 0")
	t.assert_true(ceremony_range.size() == 2 \
		and dim_sec >= float(ceremony_range[0]) and dim_sec <= float(ceremony_range[1]),
		"ceremony.dim_sec within motion.ceremony_range_sec bounds")

	# --- glyphs: §3 基础集，每个 id 1..4 个矩形定义 ---
	for glyph_id in GLYPH_IDS:
		var def: Array = cfg.get_glyph_def(glyph_id)
		t.assert_true(def.size() >= 1 and def.size() <= 4, "glyph '%s' has 1..4 rects (got %d)" % [glyph_id, def.size()])
		for entry in def:
			var rect: Array = entry.get("rect", []) if entry is Dictionary else []
			t.assert_eq(rect.size(), 4, "glyph '%s' rect entry has 4 components" % glyph_id)
	t.assert_eq(cfg.get_glyph_def("nonexistent_glyph").size(), 0, "unknown glyph id returns empty Array")

	# --- acceptance: §12.1 阈值 ---
	var acceptance: Dictionary = cfg.get_acceptance_config()
	t.assert_eq(acceptance.get("feedback_window_ticks"), 1, "acceptance.feedback_window_ticks == 1")
	t.assert_eq(acceptance.get("max_pending_modals"), 1, "acceptance.max_pending_modals == 1")
	t.assert_eq(acceptance.get("time_to_first_choice_max_ticks"), 120, "acceptance.time_to_first_choice_max_ticks == 120")
	t.assert_eq(acceptance.get("dead_air_max_ticks"), 12, "acceptance.dead_air_max_ticks == 12")
	t.assert_eq(acceptance.get("contrast_min_body"), 4.5, "acceptance.contrast_min_body == 4.5")
	t.assert_eq(acceptance.get("contrast_min_large"), 3.0, "acceptance.contrast_min_large == 3.0")
	t.assert_eq(acceptance.get("overlap_tolerance_px2"), 4, "acceptance.overlap_tolerance_px2 == 4")
	t.assert_eq(acceptance.get("opaque_alpha"), 0.5, "acceptance.opaque_alpha == 0.5")

	# --- Phase P 占位段（§9/§10/§8.8/§7） ---
	var game_feel: Dictionary = pres.get("game_feel", {})
	t.assert_eq(game_feel.get("enabled"), true, "game_feel.enabled == true")
	t.assert_true(game_feel.get("triggers") is Dictionary, "game_feel.triggers is Dictionary placeholder")
	var audio: Dictionary = pres.get("audio", {})
	t.assert_eq(audio.get("enabled"), true, "audio.enabled == true")
	t.assert_eq(audio.get("dedup_ms"), 50, "audio.dedup_ms == 50")
	t.assert_true(audio.get("sfx") is Dictionary, "audio.sfx is Dictionary placeholder")
	t.assert_true(pres.get("hints") is Dictionary, "hints is Dictionary placeholder")
	t.assert_true(pres.get("death_causes") is Dictionary, "death_causes is Dictionary placeholder")

	# --- debug_ui 开关默认关闭（§11.7） ---
	t.assert_eq(cfg.is_debug_ui_enabled(), false, "is_debug_ui_enabled() == false by default")
