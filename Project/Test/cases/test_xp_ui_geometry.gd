extends RefCounted
## SpecKit 004 T014: 全部 L3 面板典型状态几何探测（presentation_design.md §12.1 几何五项 + 对比度）
## 状态布景共用 state_stager（§12 三层共用 StateStager）；只测沉降态：
## settle_all + 等帧后 probe 断言模式。
## 附带 T013 收口断言：debug UI 默认不创建（§11.7）、HUD 文本收编 kit 面板（§4）、
## 标题/局后屏信号契约保持（main.gd 依赖）、T 验收捷径随 debug_ui 关闭而 no-op（§7）。

const PROBE_PATH: String = "res://Test/experience/ui_geometry_probe.gd"
const SETTLE_PATH: String = "res://Test/experience/ui_settle.gd"
const STAGER_PATH: String = "res://Test/experience/state_stager.gd"

## §12.1：每个典型状态一次沉降态探测（l4_scale_pending = spec 002 T2 鳞片模态 + 蜕皮 chip；
## l4_shop_open = spec 002 T3 商店货架 + 蜕皮 chip；l4_floor_reward_slot/choice =
## spec 002 T5b Boss 结算两段模态；l5_stone_select = spec 003 M3 传承石选择屏，
## 假档 2 石临时路径布景）
const STATES: Array = ["title_screen", "game_over", "l3_run_start", "l3_reward_pending",
	"l4_scale_pending", "l4_shop_open", "l4_floor_reward_slot", "l4_floor_reward_choice",
	"l5_stone_select"]


func run(t) -> void:
	t.assert_file_exists(PROBE_PATH)
	t.assert_file_exists(SETTLE_PATH)
	t.assert_file_exists(STAGER_PATH)
	for path in [PROBE_PATH, SETTLE_PATH, STAGER_PATH]:
		if not FileAccess.file_exists(path):
			return
	t.assert_false(ConfigManager.is_debug_ui_enabled(),
		"[XP-GEO] presentation.debug_ui stays disabled by default")
	for state_name in STATES:
		await _probe_state(t, state_name)


func _probe_state(t, state_name: String) -> void:
	var stager_script: GDScript = load(STAGER_PATH)
	var ctx: Dictionary = stager_script.stage(state_name, t)
	# 布景后立即冻结 tick：几何探测不推进游戏，避免真实 timer 干扰沉降态
	TickManager.stop_ticking()
	var ui_root: Node = ctx.get("ui_root", null)
	t.assert_true(ui_root != null, "[XP-GEO:%s] stager provides a ui_root" % state_name)
	if ui_root == null:
		stager_script.teardown(ctx)
		return

	# 等两帧：冲掉先前布景 queue_free 的残留 + 完成首帧布局，再沉降探测（§12.1）
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	load(SETTLE_PATH).settle_all(t.get_tree())
	await t.get_tree().process_frame

	var probe: RefCounted = load(PROBE_PATH).new()
	probe.probe(t, ui_root, state_name, {})

	match state_name:
		"title_screen":
			_assert_title_extras(t, ctx)
		"game_over":
			_assert_game_over_extras(t, ctx)
		"l3_run_start":
			_assert_run_start_extras(t, ctx)
		"l5_stone_select":
			_assert_stone_select_extras(t, ctx)

	stager_script.teardown(ctx)
	await t.get_tree().process_frame
	await t.get_tree().process_frame


# ── T013: 标题屏 kit 样式 + debug 捷径门 ─────────────────────────────

func _assert_title_extras(t, ctx: Dictionary) -> void:
	var app: Node = ctx.get("world", null)
	var title: Control = app.get_node("UILayer/TitleScreen")
	t.assert_true(title.visible, "[XP-GEO:title] title screen visible at boot")
	t.assert_true(title.has_signal("start_pressed"), "[XP-GEO:title] start_pressed signal kept")
	var start_button: Button = title.get_node("VBoxContainer/StartButton")
	t.assert_true(start_button.is_in_group("ui_hit"),
		"[XP-GEO:title] start button registered as ui_hit target")
	t.assert_true(_has_kit_frame(title),
		"[XP-GEO:title] title menu sits on a kit corner-bracket panel")
	# §7/§11.7：debug_ui 关闭时 T 验收捷径必须 no-op
	var key := InputEventKey.new()
	key.keycode = KEY_T
	key.pressed = true
	title.get_viewport().push_input(key)
	t.assert_eq(app.get_node("GameWorldContainer").get_child_count(), 0,
		"[XP-GEO:title] T acceptance shortcut no-ops while presentation.debug_ui is off")


# ── T013: 局后屏 kit 样式 + show_results 契约 + 测试按钮门 ───────────

func _assert_game_over_extras(t, ctx: Dictionary) -> void:
	var app: Node = ctx.get("world", null)
	var screen: Control = app.get_node("UILayer/GameOverScreen")
	t.assert_true(screen.visible, "[XP-GEO:game_over] show_results makes screen visible")
	t.assert_true(screen.has_signal("restart_pressed"),
		"[XP-GEO:game_over] restart_pressed signal kept")
	t.assert_true(screen.has_signal("test_mode_pressed"),
		"[XP-GEO:game_over] test_mode_pressed signal kept")
	var restart: Button = screen.get_node("VBoxContainer/RestartButton")
	t.assert_true(restart.is_in_group("ui_hit"),
		"[XP-GEO:game_over] restart button registered as ui_hit target")
	t.assert_true(_has_kit_frame(screen),
		"[XP-GEO:game_over] game-over menu sits on a kit corner-bracket panel")
	# §11.7：测试模式按钮属 debug UI，开关关闭时不创建（信号契约保留）
	var buttons: int = 0
	for child in screen.get_node("VBoxContainer").get_children():
		if child is Button:
			buttons += 1
	t.assert_eq(buttons, 1,
		"[XP-GEO:game_over] test-mode button gated behind presentation.debug_ui")
	var score_label: Label = screen.get_node("VBoxContainer/ScoreLabel")
	t.assert_true(score_label.text.contains("3"),
		"[XP-GEO:game_over] show_results renders staged score")


# ── T013: HUD 收编 kit 面板 + debug UI 创建门 ────────────────────────

func _assert_run_start_extras(t, ctx: Dictionary) -> void:
	var world: Node = ctx.get("world", null)
	# §11.7 debug UI 默认不创建
	for debug_name in ["DebugPanel", "BuildTestPanel", "EventLogPanel", "KillFeed"]:
		t.assert_false(world.has_node("UI/%s" % debug_name),
			"[XP-GEO:run] debug node %s not created while debug_ui is off" % debug_name)
	# §4：HUD 文本必须坐在 bg_panel 底上（kit 面板），不裸落战场
	var hud = world.get_node("UI/HUD")
	t.assert_true(_has_kit_panel_ancestor(hud.length_label),
		"[XP-GEO:run] length label re-homed onto a kit panel")
	t.assert_true(_has_kit_panel_ancestor(hud.status_label),
		"[XP-GEO:run] status label re-homed onto a kit panel")


# ── M3: 传承石选择屏布景（spec 003 T015：kit modal + 假档 2 石 + 标题让位） ────

func _assert_stone_select_extras(t, ctx: Dictionary) -> void:
	var app: Node = ctx.get("world", null)
	var screen: Control = app.get_node("UILayer/StoneSelectScreen")
	t.assert_true(screen.visible, "[XP-GEO:stone] stone select screen staged visible")
	t.assert_true(screen.is_in_group("ui_modal"), "[XP-GEO:stone] screen in ui_modal group")
	t.assert_eq(screen.get_visible_stone_count(), 2,
		"[XP-GEO:stone] staged fake save renders 2 stone cards")
	t.assert_false(app.get_node("UILayer/TitleScreen").visible,
		"[XP-GEO:stone] title yields to stone select")
	var skip_in_hit: bool = false
	for node in t.get_tree().get_nodes_in_group("ui_hit"):
		if node is Button and node.text.contains("轻装上阵"):
			skip_in_hit = true
	t.assert_true(skip_in_hit, "[XP-GEO:stone] skip entry registered as ui_hit target")


func _has_kit_frame(screen: Control) -> bool:
	for child in screen.get_children():
		if child is PanelContainer and child.is_in_group("ui_kit"):
			return true
	return false


func _has_kit_panel_ancestor(node: Node) -> bool:
	var current: Node = node.get_parent()
	while current != null:
		if current is PanelContainer and current.is_in_group("ui_kit"):
			return true
		current = current.get_parent()
	return false
