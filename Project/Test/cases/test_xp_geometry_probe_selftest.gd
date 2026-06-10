extends RefCounted
## SpecKit 004 T009: 几何探针自测 + ui_settle + state_stager
## 设计文档: Designs/Interactive/presentation_design.md §12.1（几何五项 + 对比度合成）
## 探针必须支持 dry_run（自测断言"违规被发现"而不让本套件变红）；真实套件用 probe 断言模式。

const PROBE_PATH: String = "res://Test/experience/ui_geometry_probe.gd"
const SETTLE_PATH: String = "res://Test/experience/ui_settle.gd"
const STAGER_PATH: String = "res://Test/experience/state_stager.gd"
const CHIP_PATH: String = "res://ui/kit/chip.gd"


func run(t) -> void:
	t.assert_file_exists(PROBE_PATH)
	t.assert_file_exists(SETTLE_PATH)
	t.assert_file_exists(STAGER_PATH)
	for path in [PROBE_PATH, SETTLE_PATH, STAGER_PATH]:
		if not FileAccess.file_exists(path):
			return
	await _test_probe_detects_violations(t)
	await _test_probe_clean_fixture_green(t)
	_test_ui_settle(t)
	_test_state_stager(t)


func _viewport_size() -> Vector2:
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 0)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 0))
	)


func _count_checks(violations: Array, check: String) -> int:
	var count: int = 0
	for violation in violations:
		if str(violation.get("check", "")) == check:
			count += 1
	return count


# ── 探针自测: 构造违规场景，dry_run 必须逐项发现 ─────────────────────

func _test_probe_detects_violations(t) -> void:
	var probe: RefCounted = load(PROBE_PATH).new()
	var vp: Vector2 = _viewport_size()
	var root := Control.new()
	root.name = "XpViolationFixture"
	root.size = vp
	t.add_child(root)

	# (1) 同层（默认 hud）不透明重叠对
	var rect_a := ColorRect.new()
	rect_a.color = Color(0.1, 0.1, 0.12, 1.0)
	rect_a.position = Vector2(vp.x * 0.25, vp.y * 0.4)
	rect_a.size = Vector2(100, 100)
	root.add_child(rect_a)
	var rect_b := ColorRect.new()
	rect_b.color = Color(0.12, 0.1, 0.1, 1.0)
	rect_b.position = rect_a.position + Vector2(50, 50)
	rect_b.size = Vector2(100, 100)
	root.add_child(rect_b)
	# dim 层与 a/b 都重叠，但层矩阵豁免：不得计入违规
	var rect_dim := ColorRect.new()
	rect_dim.color = Color(0, 0, 0, 0.7)
	rect_dim.position = rect_a.position
	rect_dim.size = Vector2(200, 200)
	rect_dim.set_meta("ui_layer", "dim")
	root.add_child(rect_dim)

	# (2) autowrap 高度裁切 Label（未声明 ui_allow_truncate）
	# clip_text=true 才允许 size 低于全文高度（否则引擎把 size 钳到最小尺寸 = 全文高）
	var clipped := Label.new()
	clipped.text = "网格信号验收基建需要在违规场景里被探针发现，这段文本刻意足够长以触发多行换行进而被高度裁切掉后续行"
	clipped.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	clipped.clip_text = true
	clipped.position = Vector2(40, vp.y * 0.75)
	clipped.custom_minimum_size = Vector2(80, 0)
	clipped.size = Vector2(80, 30)
	root.add_child(clipped)

	# (3) 视口溢出
	var off_screen := ColorRect.new()
	off_screen.color = Color(0.1, 0.12, 0.1, 1.0)
	off_screen.position = vp - Vector2(50, 50)
	off_screen.size = Vector2(200, 100)
	root.add_child(off_screen)

	# (4) 命中目标过小
	var tiny_hit := Control.new()
	tiny_hit.position = Vector2(vp.x * 0.7, vp.y * 0.2)
	tiny_hit.size = Vector2(10, 10)
	tiny_hit.add_to_group("ui_hit")
	root.add_child(tiny_hit)

	# (5) 双模态可见
	var modal_a := Control.new()
	modal_a.add_to_group("ui_modal")
	root.add_child(modal_a)
	var modal_b := Control.new()
	modal_b.add_to_group("ui_modal")
	root.add_child(modal_b)

	# (6) 低对比 Label（深字落在 bg_deep 合成底上）
	var dim_label := Label.new()
	dim_label.text = "low contrast"
	dim_label.position = Vector2(vp.x * 0.55, vp.y * 0.8)
	dim_label.add_theme_color_override("font_color", Color(0.12, 0.14, 0.16))
	root.add_child(dim_label)

	await t.get_tree().process_frame
	await t.get_tree().process_frame

	var violations: Array = probe.dry_run(root, {})
	t.assert_eq(_count_checks(violations, "overlap"), 1,
		"[XP-G] overlapping opaque pair detected exactly once (dim layer exempt)")
	t.assert_true(_count_checks(violations, "label_fit") >= 1,
		"[XP-G] clipped autowrap label detected")
	t.assert_true(_count_checks(violations, "viewport") >= 1,
		"[XP-G] off-viewport control detected")
	t.assert_eq(_count_checks(violations, "hit_target"), 1,
		"[XP-G] undersized ui_hit target detected")
	t.assert_eq(_count_checks(violations, "modal_count"), 1,
		"[XP-G] more than one visible modal detected")
	t.assert_true(_count_checks(violations, "contrast") >= 1,
		"[XP-G] low contrast label detected")

	# 显式声明截断后豁免（§12.1）
	clipped.set_meta("ui_allow_truncate", true)
	var relaxed: Array = probe.dry_run(root, {})
	t.assert_eq(_count_checks(relaxed, "label_fit"), 0,
		"[XP-G] declared ui_allow_truncate is exempt from label fit")

	root.free()


# ── 探针断言模式: 干净场景必须全绿 ───────────────────────────────────

func _test_probe_clean_fixture_green(t) -> void:
	var probe: RefCounted = load(PROBE_PATH).new()
	var vp: Vector2 = _viewport_size()
	var root := Control.new()
	root.name = "XpCleanFixture"
	root.size = vp
	t.add_child(root)

	var panel := ColorRect.new()
	panel.color = ConfigManager.get_palette_color("bg_panel")
	panel.position = Vector2(vp.x * 0.1, vp.y * 0.15)
	panel.size = Vector2(240, 80)
	root.add_child(panel)

	var label := Label.new()
	label.text = "网格信号"
	label.position = Vector2(16, 16)
	label.add_theme_color_override("font_color", ConfigManager.get_palette_color("text_primary"))
	panel.add_child(label)

	var hit_ok := Control.new()
	hit_ok.position = Vector2(vp.x * 0.5, vp.y * 0.15)
	hit_ok.size = Vector2(40, 40)
	hit_ok.add_to_group("ui_hit")
	root.add_child(hit_ok)

	var modal_ok := Control.new()
	modal_ok.add_to_group("ui_modal")
	root.add_child(modal_ok)

	await t.get_tree().process_frame
	probe.probe(t, root, "selftest_clean", {})
	root.free()


# ── ui_settle: 追踪 Tween 快进到终态 ─────────────────────────────────

func _test_ui_settle(t) -> void:
	var settle_script: GDScript = load(SETTLE_PATH)
	var chip: Control = load(CHIP_PATH).new()
	chip.name = "XpSettleChip"
	t.add_child(chip)
	chip.set_content("shedskin", "+3", ConfigManager.get_palette_color("accent_shedskin"))
	chip.bounce()
	var settled: int = settle_script.settle_all(t.get_tree())
	t.assert_true(settled >= 1, "[XP-G] settle_all visits ui_kit nodes")
	t.assert_eq(chip.scale, Vector2.ONE, "[XP-G] tracked tween fast-forwarded to end state")
	chip.queue_free()


# ── state_stager: l3_reward_pending 布景 + 镜像还原 ─────────────────

func _test_state_stager(t) -> void:
	var stager_script: GDScript = load(STAGER_PATH)
	var ctx: Dictionary = stager_script.stage("l3_reward_pending", t)
	var world: Node = ctx.get("world", null)
	t.assert_true(world != null, "[XP-G] stager instantiates game_world")
	if world == null:
		return
	var reward_panel: Control = world.get_node("UI/RewardChoicePanel")
	t.assert_true(reward_panel.visible, "[XP-G] l3_reward_pending stages a visible reward panel")
	t.assert_true(reward_panel.get_visible_option_count() > 0, "[XP-G] staged state has reward options")
	stager_script.teardown(ctx)
	t.assert_false(TickManager.is_ticking, "[XP-G] teardown stops ticking")
