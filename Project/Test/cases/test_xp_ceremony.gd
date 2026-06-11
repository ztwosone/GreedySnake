extends RefCounted
## Phase P T103: 死亡/胜利仪式 + 局后总结编排契约（presentation_design.md §7）
## 死亡：hitstop → 蛇尾到头逐段消散 → 去饱和 → dim → 死因中文一行 → 总结屏；
## 胜利：金色扩散环 → dim → 总结屏。仪式期间总结屏被门控（settle 快进可同步验收）。
## game_feel.enabled=false 时仪式整体旁路（宪法：重特效可禁用）。
## 存档卫生：main.tscn 入树即 boot(临时路径)；本套件不驱动 run_ended。

const MAIN_SCENE_PATH: String = "res://scenes/main.tscn"
const TEMP_SAVE_PATH: String = "user://test_xp_ceremony_tmp.json"


## T104a banner 替身：room_intent_panel 公共 API 的 duck-typed 最小面
class StubIntentPanel:
	extends Node
	var expanded_calls: int = 0
	var collapsed_calls: int = 0
	func show_banner_stage() -> void:
		expanded_calls += 1
	func collapse_banner() -> void:
		collapsed_calls += 1


func run(t) -> void:
	_test_death_cause_mapping(t)
	await _test_ceremony_gates_summary(t)
	await _test_game_feel_disabled_bypass(t)
	await _test_room_banner_two_stage(t)
	await _test_choice_ceremony(t)
	await _test_shedskin_fly(t)
	_remove_temp_save()


# === §8.3 选择仪式（T104b）：presented → pause(&"ceremony")+dim；决议 → resume+收 dim ===
func _test_choice_ceremony(t) -> void:
	var saved_gm: Dictionary = _save_game_manager()
	var app: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	t.add_child(app)
	app.get_node("MetaGrowthRoot").boot(TEMP_SAVE_PATH)
	var ceremony: Node = app.get_node("UILayer/CeremonyLayer")

	TickManager.manual_mode = true
	TickManager.start_ticking()

	# 鳞片 offer：presented 即停拍 + dim
	EventBus.scale_reward_presented.emit({
		"room_id": "combat_01", "options": [], "offer_id": "o1", "pool_id": "l1_basic"})
	t.assert_eq(TickManager.is_ticking, false, "[P104b] presented pauses the tick")
	t.assert_eq(TickManager.get_pause_reasons(), [&"ceremony"],
		"[P104b] pause held by ceremony token")
	ceremony.settle()
	t.assert_true(ceremony.is_dimmed(), "[P104b] presented dims the world")

	# 决议：chosen 恢复；随后的 discarded（余卡入账）不二次扰动
	EventBus.scale_reward_chosen.emit({"offer_id": "o1", "option_id": "x",
		"scale_id": "s", "position": "front", "level": 1, "skipped": false})
	t.assert_eq(TickManager.is_ticking, true, "[P104b] chosen resumes the tick")
	t.assert_eq(TickManager.get_pause_reasons(), [], "[P104b] ceremony token released")
	EventBus.scale_option_discarded.emit({"offer_id": "o1", "discarded_ids": ["y"],
		"shedskin_gained": 2})
	t.assert_eq(TickManager.is_ticking, true, "[P104b] follow-up discard is a no-op")
	ceremony.settle()
	t.assert_false(ceremony.is_dimmed(), "[P104b] dim cleared after resolution")

	# 楼层奖励两段式：两次 presented 单 token 保持，chosen 才恢复
	EventBus.floor_reward_presented.emit({"reward_id": "fr", "floor_index": 1,
		"source_room_id": "boss", "step": "slot_unlock", "slot_options": [], "options": []})
	t.assert_eq(TickManager.is_ticking, false, "[P104b] floor reward stage 1 pauses")
	EventBus.floor_reward_presented.emit({"reward_id": "fr", "floor_index": 1,
		"source_room_id": "boss", "step": "choice", "slot_options": [], "options": []})
	t.assert_eq(TickManager.get_pause_reasons(), [&"ceremony"],
		"[P104b] stage 2 keeps the single token (no stacking)")
	EventBus.floor_reward_chosen.emit({"floor_index": 1, "category": "expansion",
		"option_id": "x", "skipped": false})
	t.assert_eq(TickManager.is_ticking, true, "[P104b] floor reward chosen resumes")

	# FR-014 自动决议（无 presented 的 chosen）不得幻影恢复停拍外的状态
	TickManager.stop_ticking()
	EventBus.reward_chosen.emit({"room_id": "r", "option_id": "", "skipped": true})
	t.assert_eq(TickManager.is_ticking, false,
		"[P104b] auto-resolve without presented never resumes a stopped tick")

	# 商店非模态：不触发仪式（FR-015 商店不门控的对偶）
	TickManager.start_ticking()
	EventBus.shop_entered.emit({"room_id": "shop_01", "items": []})
	t.assert_eq(TickManager.is_ticking, true, "[P104b] shop entry is not a ceremony")

	TickManager.stop_ticking()
	TickManager.manual_mode = false
	await _teardown(t, app, saved_gm)


# === §8.5 蜕皮 chip 飞行粒子（T104b）：有世界坐标才飞，无坐标只 bounce ===
func _test_shedskin_fly(t) -> void:
	# ShedskinSystem 击杀入账带格坐标透传（payload 增量 position）
	var system: Node = (load("res://systems/growth/shedskin_system.gd") as GDScript).new()
	t.add_child(system)
	var currency_events: Array = []
	var on_currency := func(data: Dictionary) -> void:
		currency_events.append(data)
	EventBus.currency_changed.connect(on_currency)
	EventBus.enemy_killed.emit({"enemy_def": null, "position": Vector2i(3, 4),
		"method": "test"})
	t.assert_true(currency_events.size() >= 1, "[P104b] kill income emitted")
	if currency_events.size() >= 1:
		t.assert_eq(currency_events[0].get("position"), Vector2i(3, 4),
			"[P104b] kill income carries the grid position through")
	EventBus.currency_changed.disconnect(on_currency)

	# 显示组件：带坐标入账 → fly_to_hud；无坐标入账 → 不飞
	var display: Control = (load("res://ui/shedskin_display.gd") as GDScript).new()
	t.add_child(display)
	var fly_count: Array = [0]
	var on_vfx := func(fx_name: String, _args: Dictionary) -> void:
		if fx_name == "fly_to_hud":
			fly_count[0] += 1
	VFXManager.vfx_invoked.connect(on_vfx)
	EventBus.currency_changed.emit({"currency": "shedskin", "amount": 2, "total": 2,
		"source": "kill_wanderer", "position": Vector2i(5, 5)})
	t.assert_eq(fly_count[0], 1, "[P104b] positioned income flies to the chip")
	EventBus.currency_changed.emit({"currency": "shedskin", "amount": 3, "total": 5,
		"source": "scale_discard"})
	t.assert_eq(fly_count[0], 1, "[P104b] positionless income does not fly (bounce only)")
	VFXManager.vfx_invoked.disconnect(on_vfx)

	system.queue_free()
	display.queue_free()
	await t.get_tree().process_frame


# === §8.1 房间意图两段式：进房横幅展开 0.9s 后收缩为 chip（T104a） ===
func _test_room_banner_two_stage(t) -> void:
	var cfg: Dictionary = ConfigManager.get_ceremony_config()
	t.assert_true(float(cfg.get("room_banner_sec", 0.0)) > 0.0,
		"[P104a] ceremony.room_banner_sec > 0 (JSON)")

	var saved_gm: Dictionary = _save_game_manager()
	var app: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	t.add_child(app)
	app.get_node("MetaGrowthRoot").boot(TEMP_SAVE_PATH)
	var ceremony: Node = app.get_node("UILayer/CeremonyLayer")

	var panel := StubIntentPanel.new()
	panel.add_to_group("room_intent_panel")
	t.add_child(panel)

	EventBus.room_entered.emit({"room_id": "combat_01", "room_type": "combat",
		"intent_label": "战斗"})
	t.assert_eq(panel.expanded_calls, 1, "[P104a] room_entered expands the banner stage")
	t.assert_eq(panel.collapsed_calls, 0, "[P104a] collapse deferred by room_banner_sec")
	ceremony.settle()
	t.assert_eq(panel.collapsed_calls, 1, "[P104a] settle -> banner collapsed to chip")

	# game_feel 关闭：直接收缩态（无停留编排）
	var game_feel: Dictionary = ConfigManager.presentation.get("game_feel", {})
	var saved_enabled: bool = bool(game_feel.get("enabled", true))
	game_feel["enabled"] = false
	EventBus.room_entered.emit({"room_id": "reward_01", "room_type": "reward",
		"intent_label": "奖励"})
	t.assert_eq(panel.collapsed_calls, 2, "[P104a] game_feel off: straight to chip stage")
	game_feel["enabled"] = saved_enabled

	panel.queue_free()
	await _teardown(t, app, saved_gm)


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
		await _teardown(t, app, saved_gm)
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

	await _teardown(t, app, saved_gm)


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
	await _teardown(t, app, saved_gm)


func _teardown(t, app: Node, saved_gm: Dictionary) -> void:
	var container: Node = app.get_node_or_null("GameWorldContainer")
	if container != null:
		for child in container.get_children():
			if child.has_method("cleanup"):
				child.cleanup()
	app.queue_free()
	# 冲一帧让 queue_free 真释放——否则下个子测试里旧壳 CeremonyLayer 仍连着
	# EventBus（room_entered 一发多收，计数断言翻车）
	await t.get_tree().process_frame
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
