extends RefCounted
## Phase P T107: 3 局 soak（presentation_design.md §12.1 机器层最后一项）
## 连续三局全循环（开始/选石跳过 → 局内事件 → 死亡仪式 → 总结 → 再来一局）
## 无报错（严格门禁扫 stderr）、无残留 UI（模态全收、dim 清、世界唯一）；
## 第三局后走「回标题」分支收尾（§7 流程图右下）。
## 存档卫生：boot 临时档，测后删除。

const MAIN_SCENE_PATH: String = "res://scenes/main.tscn"
const TEMP_SAVE_PATH: String = "user://test_xp_soak_tmp.json"

var _run_ended_count: int = 0


func run(t) -> void:
	_remove_temp_save()
	await _soak(t)
	_remove_temp_save()


func _soak(t) -> void:
	var saved_gm: Dictionary = {
		"state": GameManager.current_state, "score": GameManager.current_score,
		"best": GameManager.best_score,
	}
	EventBus.run_ended.connect(_on_run_ended)
	_run_ended_count = 0

	var app: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	t.add_child(app)
	app.get_node("MetaGrowthRoot").boot(TEMP_SAVE_PATH)
	var container: Node = app.get_node("GameWorldContainer")
	var ceremony: Node = app.get_node("UILayer/CeremonyLayer")
	var summary_screen: Control = app.get_node("UILayer/GameOverScreen")
	var stone_screen: Control = app.get_node("UILayer/StoneSelectScreen")

	app.get_node("UILayer/TitleScreen").start_pressed.emit()

	for run_index in 3:
		# 第 2+ 局：上局铸石 → 选石屏拦路，轻装上阵跳过（裁定 #12 路径回归）
		if GameManager.current_state == GameManager.GameState.STONE_SELECT:
			t.assert_true(run_index > 0, "[SOAK] stone select never blocks run 1")
			stone_screen.skip()
		t.assert_eq(GameManager.current_state, GameManager.GameState.PLAYING,
			"[SOAK] run %d starts into PLAYING" % (run_index + 1))
		await t.get_tree().process_frame
		t.assert_eq(container.get_child_count(), 1,
			"[SOAK] run %d has exactly one world" % (run_index + 1))
		var world: Node = container.get_child(0)

		# 局内事件采样（音频/引导/统计路径都过一遍；2 杀不触发房间完成模态）
		for _i in 2:
			EventBus.enemy_killed.emit({"enemy_def": null,
				"position": Vector2i(run_index + 2, 3), "method": "reaction_steam"})
		world.snake.die("soak_death_%d" % (run_index + 1))

		# 死亡仪式 → 总结屏
		ceremony.settle()
		t.assert_true(summary_screen.visible,
			"[SOAK] run %d ends on the summary screen" % (run_index + 1))
		t.assert_eq(GameManager.current_state, GameManager.GameState.SUMMARY,
			"[SOAK] run %d state SUMMARY" % (run_index + 1))
		t.assert_eq(_run_ended_count, run_index + 1,
			"[SOAK] exactly one run_ended per run")
		await t.get_tree().process_frame

		# 残留 UI 检查：模态全收、dim 清、仪式视觉清
		for modal in t.get_tree().get_nodes_in_group("ui_modal"):
			if is_instance_valid(modal) and modal is CanvasItem:
				t.assert_false(modal.visible,
					"[SOAK] no lingering modal after run %d (%s)" % [
						run_index + 1, modal.name])
		t.assert_false(ceremony.is_dimmed(),
			"[SOAK] dim cleared after run %d" % (run_index + 1))

		if run_index < 2:
			summary_screen.restart_pressed.emit()
			await t.get_tree().process_frame

	# 三局后回标题分支（§7 右下）：世界清空、标题可见、状态 TITLE
	summary_screen.title_pressed.emit()
	await t.get_tree().process_frame
	t.assert_eq(GameManager.current_state, GameManager.GameState.TITLE,
		"[SOAK] back-to-title lands on TITLE")
	t.assert_eq(container.get_child_count(), 0, "[SOAK] world cleaned up at title")
	t.assert_true(app.get_node("UILayer/TitleScreen").visible,
		"[SOAK] title screen visible again")
	t.assert_false(summary_screen.visible, "[SOAK] summary closed at title")
	t.assert_eq(_run_ended_count, 3, "[SOAK] three runs, three run_ended, no extras")

	app.queue_free()
	await t.get_tree().process_frame
	EventBus.run_ended.disconnect(_on_run_ended)
	TickManager.stop_ticking()
	GridWorld.clear_all()
	GameManager.current_state = int(saved_gm.get("state", GameManager.GameState.TITLE))
	GameManager.current_score = int(saved_gm.get("score", 0))
	GameManager.best_score = int(saved_gm.get("best", 0))


func _on_run_ended(_data: Dictionary) -> void:
	_run_ended_count += 1


func _remove_temp_save() -> void:
	if FileAccess.file_exists(TEMP_SAVE_PATH):
		DirAccess.remove_absolute(TEMP_SAVE_PATH)
