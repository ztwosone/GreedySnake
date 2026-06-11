extends RefCounted
## spec 003 M4（T019）：L5 全环冒烟（SC-008）——S3 验收核心。
## 真实 main.tscn AppFlow 全程（test_l5_legacy 模式）+ 临时 save_path：
##   run 1（新档，石碑空 → StoneSelect 整屏跳过直进 RUN）→ 真实事件喂入高光统计
##   → 蛇真实 die() 死亡 → `run_ended` 恰一次 + 铸石入档 + 解锁评估（bai_she）
##   + 存档文件落盘可读回（SC-002 跨进程代理：同路径新 MetaSaveSystem 实例重载）
##   → 「再来一局」→ StoneSelect 首登场（概念第二局，裁定 #12）→ 选石
##   → run 2 bias 双系统生效（FR-015）+ 解锁内容进 offer 池（FR-003）。
## 存档卫生（不可妥协）：壳层入树后立刻 root.boot(临时路径)，测后删除——
## 绝不触碰生产存档 user://meta_save.json。

const MAIN_SCENE_PATH: String = "res://scenes/main.tscn"
const MetaSaveSystemScript := preload("res://systems/meta_growth/meta_save_system.gd")

const TEMP_SAVE_PATH: String = "user://test_l5_full_loop_tmp.json"

var _run_ended_events: Array = []
var _unlocked_events: Array = []
var _stone_created_events: Array = []


func run(t) -> void:
	_remove_temp_save()
	await _test_full_loop(t)
	_remove_temp_save()


func _test_full_loop(t) -> void:
	var saved_gm: Dictionary = _save_game_manager()
	_connect_recorders()

	var app: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	t.add_child(app)
	var root: Node = app.get_node("MetaGrowthRoot")
	root.boot(TEMP_SAVE_PATH)  # 存档卫生：入树 + 将驱动 run_ended，必先换临时档

	# ── run 1：新档开始——石碑空，StoneSelect 整屏跳过（FR-012）直进 RUN ──
	app.get_node("UILayer/TitleScreen").start_pressed.emit()
	t.assert_eq(GameManager.current_state, GameManager.GameState.PLAYING,
		"[L5-LOOP] fresh save: run 1 starts straight into PLAYING")
	t.assert_false(app.get_node("UILayer/StoneSelectScreen").visible,
		"[L5-LOOP] fresh save: stone select never flashes (ruling #12)")
	var container: Node = app.get_node("GameWorldContainer")
	t.assert_eq(container.get_child_count(), 1, "[L5-LOOP] run 1 world created")
	var world1: Node = container.get_child(0)
	t.assert_false(world1.scale_reward_system.has_sampling_bias(),
		"[L5-LOOP] run 1 carries no stone bias (nothing forged yet)")

	# 真实事件喂入本局高光：30 次反应击杀 → total_kills 30（high_kills 石阈值）
	# 且 reaction_kills 30 ≥ 10（bai_she 解锁条件，Designs §12.3 v1 映射）
	var kills_needed: int = maxi(
		int(ConfigManager.get_legacy_stone_thresholds().get("high_kills", 30)), 10)
	for _i in range(kills_needed):
		EventBus.enemy_killed.emit(
			{"enemy_def": null, "position": Vector2i.ZERO, "method": "reaction_steam"})

	# 蛇真实死亡出口（snake.die → snake_died → GameManager game_over +
	# RunProgression.mark_death → finalize_run → run_ended 链路）
	world1.snake.die("full_loop_death")

	t.assert_eq(_run_ended_events.size(), 1, "[L5-LOOP] run_ended emitted EXACTLY once")
	if _run_ended_events.size() >= 1:
		var payload: Dictionary = _run_ended_events[0]
		t.assert_eq(str(payload.get("outcome", "")), "death", "[L5-LOOP] outcome = death")
		t.assert_eq(int(payload.get("stats", {}).get("total_kills", 0)), kills_needed,
			"[L5-LOOP] frozen stats carry this run's kills")

	# 解锁评估已跑：bai_she 入档 + content_unlocked 恰一次
	t.assert_eq(_unlocked_events.size(), 1, "[L5-LOOP] exactly one unlock this run")
	t.assert_true(root.get_meta_save().is_head_unlocked("bai_she"),
		"[L5-LOOP] reaction kills unlocked bai_she (v1 mapping)")
	t.assert_false(root.get_meta_save().is_tail_unlocked("lag_tail"),
		"[L5-LOOP] floors condition not met: lag_tail stays locked")

	# 铸石入档（high_kills 高光 → 杀戮传承，带 fire bias）
	t.assert_eq(_stone_created_events.size(), 1, "[L5-LOOP] exactly one stone forged")
	var stones: Array = root.get_meta_save().get_legacy_stones()
	t.assert_eq(stones.size(), 1, "[L5-LOOP] forged stone persisted in the meta save")
	if stones.size() >= 1:
		t.assert_eq(str(stones[0].get("highlight_type", "")), "high_kills",
			"[L5-LOOP] stone highlight evaluated from this run's stats")
		t.assert_false(
			stones[0].get("bias_config", {}).get("scale_tag_weights", {}).is_empty(),
			"[L5-LOOP] forged stone carries a usable bias_config")

	# 存档文件落盘 + 跨进程代理（SC-002）：同路径新实例重载，状态完整还原
	t.assert_true(FileAccess.file_exists(TEMP_SAVE_PATH),
		"[L5-LOOP] save file written to disk")
	var reloaded = MetaSaveSystemScript.new(TEMP_SAVE_PATH)
	t.assert_true(reloaded.load_from_disk(), "[L5-LOOP] fresh instance reloads the save")
	t.assert_true(reloaded.is_head_unlocked("bai_she"),
		"[L5-LOOP] unlock survives the reload (cross-process proxy)")
	t.assert_eq(reloaded.get_legacy_stones().size(), 1,
		"[L5-LOOP] stone survives the reload (cross-process proxy)")

	# 结算数据通路（game_over 屏数据可达性，呈现编排归 S4）
	var summary: Dictionary = root.get_last_run_summary()
	t.assert_eq(str(summary.get("outcome", "")), "death", "[L5-LOOP] summary cached at run end")
	t.assert_eq(summary.get("unlocks", []).size(), 1, "[L5-LOOP] summary carries the unlock")
	t.assert_false(summary.get("stone", {}).is_empty(), "[L5-LOOP] summary carries the stone")
	# 004 T103：死亡仪式门控总结屏——settle 快进仪式链到 show_results
	app.get_node("UILayer/CeremonyLayer").settle()
	await t.get_tree().process_frame
	t.assert_true(app.get_node("UILayer/GameOverScreen").get_summary_lines().size() > 0,
		"[L5-LOOP] game over screen renders settlement lines (M2 contract)")

	# ── run 2：「再来一局」→ StoneSelect 首登场（概念第二局）→ 选石 ──
	app.get_node("UILayer/GameOverScreen").restart_pressed.emit()
	await t.get_tree().process_frame
	var stone_screen: Control = app.get_node("UILayer/StoneSelectScreen")
	t.assert_eq(GameManager.current_state, GameManager.GameState.STONE_SELECT,
		"[L5-LOOP] restart with stones enters STONE_SELECT")
	t.assert_true(stone_screen.visible, "[L5-LOOP] stone select shown on run 2 (ruling #12)")
	t.assert_eq(container.get_child_count(), 0,
		"[L5-LOOP] run 2 does not start while stone select pending")
	t.assert_eq(stone_screen.get_visible_stone_count(), 1,
		"[L5-LOOP] the freshly forged stone is offered")

	t.assert_true(stone_screen.choose_stone_by_index(0),
		"[L5-LOOP] stone chosen via public API")
	t.assert_eq(GameManager.current_state, GameManager.GameState.PLAYING,
		"[L5-LOOP] choosing the stone starts run 2")
	t.assert_eq(container.get_child_count(), 1, "[L5-LOOP] run 2 world created")
	var world2: Node = container.get_child(0)

	# bias 双系统生效（FR-015 恰一局）+ 选中即消耗
	t.assert_true(world2.scale_reward_system.has_sampling_bias(),
		"[L5-LOOP] stone bias wired into run 2 scale sampling")
	t.assert_true(world2.reward_flow_system.has_sampling_bias(),
		"[L5-LOOP] stone bias wired into run 2 reward sampling")
	t.assert_eq(root.get_meta_save().get_legacy_stones().size(), 0,
		"[L5-LOOP] chosen stone consumed from the save")

	# 解锁内容进 offer 池（FR-003）：布景 3 选项池（恰 offer_count，bias 置换不影响成员）
	var saved_pool: Array = _stage_starter_pool([
		_pool_option("head", "bai_she", "白蛇"),
		_pool_option("head", "hydra", "九头蛇"),
		_pool_option("tail", "salamander", "火蜥蜴尾"),
	])
	var offer: Dictionary = world2.reward_flow_system.present_offer(
		{"room_id": "loop_pool_check", "room_type": "reward"})
	var ids: Array = []
	for option in offer.get("options", []):
		ids.append(str(option.get("target_id", "")))
	t.assert_true(ids.has("bai_she"),
		"[L5-LOOP] freshly unlocked bai_she appears in run 2 offers")
	# 选中白蛇头：真实装备 + 决议清门控（同时反证解锁内容可被实际消费）
	var bai_she_option_id: String = ""
	for option in offer.get("options", []):
		if str(option.get("target_id", "")) == "bai_she":
			bai_she_option_id = str(option.get("option_id", ""))
	t.assert_true(world2.reward_flow_system.choose_reward(bai_she_option_id),
		"[L5-LOOP] unlocked head is actually equippable from the offer")
	_restore_starter_pool(saved_pool)

	t.assert_eq(_run_ended_events.size(), 1,
		"[L5-LOOP] still exactly one run_ended across the whole loop")

	_teardown_app(app)
	_disconnect_recorders()
	_restore_game_manager(saved_gm)
	_remove_temp_save()
	await t.get_tree().process_frame
	await t.get_tree().process_frame


# === helpers ===

func _pool_option(reward_type: String, target_id: String, display: String) -> Dictionary:
	return {
		"option_id": "loop_%s" % target_id,
		"display_name": display,
		"reward_type": reward_type,
		"target_id": target_id,
		"target_slot": reward_type,
		"level_delta": 0,
	}


func _stage_starter_pool(staged: Array) -> Array:
	var pools: Dictionary = ConfigManager.rewards.get("pools", {})
	var saved: Array = pools.get("starter_build", [])
	pools["starter_build"] = staged
	return saved


func _restore_starter_pool(saved: Array) -> void:
	var pools: Dictionary = ConfigManager.rewards.get("pools", {})
	pools["starter_build"] = saved


## 壳层 app 收尾：先 cleanup 局内世界（停 tick/清网格），再整壳释放
func _teardown_app(app: Node) -> void:
	var container: Node = app.get_node_or_null("GameWorldContainer")
	if container != null:
		for child in container.get_children():
			if child.has_method("cleanup"):
				child.cleanup()
	app.queue_free()
	TickManager.stop_ticking()
	GridWorld.clear_all()


func _save_game_manager() -> Dictionary:
	return {
		"state": GameManager.current_state,
		"score": GameManager.current_score,
		"best": GameManager.best_score,
	}


func _restore_game_manager(saved: Dictionary) -> void:
	GameManager.current_state = int(saved.get("state", GameManager.GameState.TITLE))
	GameManager.current_score = int(saved.get("score", 0))
	GameManager.best_score = int(saved.get("best", 0))


func _connect_recorders() -> void:
	_run_ended_events.clear()
	_unlocked_events.clear()
	_stone_created_events.clear()
	EventBus.run_ended.connect(_on_run_ended)
	EventBus.content_unlocked.connect(_on_content_unlocked)
	EventBus.legacy_stone_created.connect(_on_stone_created)


func _disconnect_recorders() -> void:
	EventBus.run_ended.disconnect(_on_run_ended)
	EventBus.content_unlocked.disconnect(_on_content_unlocked)
	EventBus.legacy_stone_created.disconnect(_on_stone_created)


func _on_run_ended(data: Dictionary) -> void:
	_run_ended_events.append(data)


func _on_content_unlocked(data: Dictionary) -> void:
	_unlocked_events.append(data)


func _on_stone_created(data: Dictionary) -> void:
	_stone_created_events.append(data)


func _remove_temp_save() -> void:
	if FileAccess.file_exists(TEMP_SAVE_PATH):
		DirAccess.remove_absolute(TEMP_SAVE_PATH)
