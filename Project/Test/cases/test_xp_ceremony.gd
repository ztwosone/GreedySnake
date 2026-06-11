extends RefCounted
## Phase P T103: 死亡/胜利仪式 + 局后总结编排契约（presentation_design.md §7）
## 死亡：hitstop → 蛇尾到头逐段消散 → 去饱和 → dim → 死因中文一行 → 总结屏；
## 胜利：金色扩散环 → dim → 总结屏。仪式期间总结屏被门控（settle 快进可同步验收）。
## game_feel.enabled=false 时仪式整体旁路（宪法：重特效可禁用）。
## 存档卫生：main.tscn 入树即 boot(临时路径)；本套件不驱动 run_ended。

const MAIN_SCENE_PATH: String = "res://scenes/main.tscn"
const TEMP_SAVE_PATH: String = "user://test_xp_ceremony_tmp.json"


func run(t) -> void:
	_test_death_cause_mapping(t)
	await _test_ceremony_gates_summary(t)
	await _test_game_feel_disabled_bypass(t)
	_remove_temp_save()


# === §7 死因 cause→中文映射（presentation.death_causes，缺键回退原文） ===
func _test_death_cause_mapping(t) -> void:
	t.assert_true(ConfigManager.has_method("get_death_cause_text"),
		"[P103] has get_death_cause_text()")
	if not ConfigManager.has_method("get_death_cause_text"):
		return
	# 真实死因全集（length_system hit_boundary/hit_self/no_body_timeout + victory）
	for cause in ["hit_boundary", "hit_self", "no_body_timeout", "victory"]:
		var text: String = ConfigManager.get_death_cause_text(cause)
		t.assert_true(not text.is_empty() and text != cause,
			"[P103] death_causes maps '%s' to Chinese (got '%s')" % [cause, text])
	t.assert_eq(ConfigManager.get_death_cause_text("some_test_cause"), "some_test_cause",
		"[P103] unmapped cause falls back to raw string")


# === 死亡/胜利仪式门控总结屏（settle 快进 = 机器可验收） ===
func _test_ceremony_gates_summary(t) -> void:
	var saved_gm: Dictionary = _save_game_manager()
	var app: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	t.add_child(app)
	app.get_node("MetaGrowthRoot").boot(TEMP_SAVE_PATH)

	var ceremony: Node = app.get_node("UILayer/CeremonyLayer")
	var summary_screen: Control = app.get_node("UILayer/GameOverScreen")
	t.assert_true(ceremony.has_method("play_end_ceremony"),
		"[P103] ceremony has play_end_ceremony()")
	t.assert_true(ceremony.has_method("reset"), "[P103] ceremony has reset()")
	if not ceremony.has_method("play_end_ceremony"):
		_teardown(t, app, saved_gm)
		return

	# --- 死亡路径：仪式期间总结屏不可见，settle 后可见 + SUMMARY ---
	GameManager.current_state = GameManager.GameState.PLAYING
	EventBus.game_over.emit({
		"cause": "hit_self", "final_length": 0, "score": 0, "best_score": 0})
	t.assert_false(summary_screen.visible,
		"[P103] summary gated while death ceremony pending")
	t.assert_true(GameManager.current_state != GameManager.GameState.SUMMARY,
		"[P103] not SUMMARY while ceremony pending")
	ceremony.settle()
	t.assert_true(summary_screen.visible, "[P103] settle -> summary visible")
	t.assert_eq(GameManager.current_state, GameManager.GameState.SUMMARY,
		"[P103] settle -> SUMMARY state")
	var mapped: String = ConfigManager.get_death_cause_text("hit_self")
	t.assert_true(str(summary_screen.cause_label.text).contains(mapped),
		"[P103] summary cause line uses JSON Chinese mapping")
	# 仪式残留：死因一行/灰罩/dim 不得叠在总结屏上（settle 后全部收场）
	t.assert_false(ceremony.is_dimmed(), "[P103] dim cleared when summary opens")
	var cause_label: Node = ceremony.get_node_or_null("CauseLabel")
	t.assert_true(cause_label == null or not cause_label.visible,
		"[P103] ceremony cause line cleared when summary opens")

	# --- 总结编排：stagger 滚入沉降后全行不透明（与 run_ended.stats 一致性由
	#     l5 套件覆盖；此处验编排不留半透明残留） ---
	await t.get_tree().process_frame
	var frame_panel: Node = summary_screen.get_node_or_null("MenuFrame")
	if frame_panel != null and frame_panel.has_method("settle"):
		frame_panel.settle()
	t.assert_true(summary_screen.score_label.modulate.a >= 0.999,
		"[P103] summary rows fully opaque after settle (stagger done)")

	# --- 胜利路径：扩散环 + dim → 总结（无蛇时跳环不崩） ---
	summary_screen.hide()
	GameManager.current_state = GameManager.GameState.PLAYING
	EventBus.game_over.emit({
		"cause": "victory", "final_length": 0, "score": 9, "best_score": 9})
	t.assert_false(summary_screen.visible,
		"[P103] summary gated while victory ceremony pending")
	ceremony.settle()
	t.assert_true(summary_screen.visible, "[P103] victory settle -> summary visible")
	t.assert_eq(GameManager.current_state, GameManager.GameState.SUMMARY,
		"[P103] victory settle -> SUMMARY state")
	t.assert_true(str(summary_screen.cause_label.text).contains(
		ConfigManager.get_death_cause_text("victory")),
		"[P103] victory line uses JSON mapping (no 死因 prefix semantics)")

	# --- reset()：进行中仪式被打断不留残留（重开局/回标题路径） ---
	summary_screen.hide()
	GameManager.current_state = GameManager.GameState.PLAYING
	EventBus.game_over.emit({
		"cause": "hit_boundary", "final_length": 0, "score": 0, "best_score": 0})
	ceremony.reset()
	t.assert_false(summary_screen.visible,
		"[P103] reset kills pending ceremony (no late summary callback)")
	t.assert_false(ceremony.is_dimmed(), "[P103] reset clears dim")
	ceremony.settle()
	t.assert_false(summary_screen.visible,
		"[P103] settle after reset is a no-op (chain killed)")

	_teardown(t, app, saved_gm)


# === game_feel.enabled=false：仪式旁路，game_over 直达总结（重特效可禁用） ===
func _test_game_feel_disabled_bypass(t) -> void:
	var saved_gm: Dictionary = _save_game_manager()
	var app: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	t.add_child(app)
	app.get_node("MetaGrowthRoot").boot(TEMP_SAVE_PATH)
	var summary_screen: Control = app.get_node("UILayer/GameOverScreen")

	var game_feel: Dictionary = ConfigManager.presentation.get("game_feel", {})
	var saved_enabled: bool = bool(game_feel.get("enabled", true))
	game_feel["enabled"] = false

	GameManager.current_state = GameManager.GameState.PLAYING
	EventBus.game_over.emit({
		"cause": "hit_self", "final_length": 0, "score": 0, "best_score": 0})
	t.assert_true(summary_screen.visible,
		"[P103] game_feel off: summary shows immediately (ceremony bypassed)")
	t.assert_eq(GameManager.current_state, GameManager.GameState.SUMMARY,
		"[P103] game_feel off: straight to SUMMARY")

	game_feel["enabled"] = saved_enabled
	_teardown(t, app, saved_gm)


func _teardown(t, app: Node, saved_gm: Dictionary) -> void:
	var container: Node = app.get_node_or_null("GameWorldContainer")
	if container != null:
		for child in container.get_children():
			if child.has_method("cleanup"):
				child.cleanup()
	app.queue_free()
	TickManager.stop_ticking()
	GridWorld.clear_all()
	GameManager.current_state = int(saved_gm.get("state", GameManager.GameState.TITLE))
	GameManager.current_score = int(saved_gm.get("score", 0))
	GameManager.best_score = int(saved_gm.get("best", 0))


func _save_game_manager() -> Dictionary:
	return {
		"state": GameManager.current_state,
		"score": GameManager.current_score,
		"best": GameManager.best_score,
	}


func _remove_temp_save() -> void:
	if FileAccess.file_exists(TEMP_SAVE_PATH):
		DirAccess.remove_absolute(TEMP_SAVE_PATH)
