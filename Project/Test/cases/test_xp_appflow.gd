extends RefCounted
## Phase P T102: AppFlow 四态收口契约（presentation_design.md §7 屏幕流）
## TITLE → (STONE_SELECT) → RUN → run_ended → SUMMARY → 再来/回标题。
## 存档卫生（不可妥协）：main.tscn 入树后立刻 root.boot(临时路径)；
## 本套件不驱动 run_ended（game_over 事件直发），但红线照守。

const MAIN_SCENE_PATH: String = "res://scenes/main.tscn"
const TEMP_SAVE_PATH: String = "user://test_xp_appflow_tmp.json"


## 石碑源替身：title_screen.set_stone_source 的 duck-typed 契约
class StubStoneSource:
	var stones: Array = []
	func get_available_stones() -> Array:
		return stones


func run(t) -> void:
	_test_game_state_summary(t)
	await _test_shell_flow(t)
	_remove_temp_save()


# === GameState.SUMMARY（尾部追加，既有 int 值不变） ===
func _test_game_state_summary(t) -> void:
	t.assert_eq(GameManager.GameState.TITLE, 0, "[P102] GameState.TITLE == 0")
	t.assert_eq(GameManager.GameState.PLAYING, 1, "[P102] GameState.PLAYING == 1")
	t.assert_eq(GameManager.GameState.GAME_OVER, 2, "[P102] GameState.GAME_OVER == 2")
	t.assert_eq(GameManager.GameState.STONE_SELECT, 3, "[P102] GameState.STONE_SELECT == 3")
	t.assert_true("SUMMARY" in GameManager.GameState, "[P102] GameState has SUMMARY")
	if not ("SUMMARY" in GameManager.GameState):
		return
	t.assert_eq(GameManager.GameState.SUMMARY, 4, "[P102] SUMMARY appended at tail (int 4)")
	t.assert_true(GameManager.has_method("enter_summary"), "[P102] has enter_summary()")

	var saved_state: int = GameManager.current_state
	GameManager.enter_summary()
	t.assert_eq(GameManager.current_state, GameManager.GameState.SUMMARY,
		"[P102] enter_summary -> SUMMARY")
	GameManager.current_state = saved_state


# === 壳层 e2e：CeremonyLayer 骨架 + 标题屏菜单 + game_over→SUMMARY→回标题 ===
func _test_shell_flow(t) -> void:
	var saved_gm: Dictionary = {
		"state": GameManager.current_state,
		"score": GameManager.current_score,
		"best": GameManager.best_score,
	}

	var app: Node = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	t.add_child(app)
	var root: Node = app.get_node("MetaGrowthRoot")
	root.boot(TEMP_SAVE_PATH)

	# --- CeremonyLayer 骨架（编排宿主，kit 零编排红线的解除处） ---
	var ceremony: Node = app.get_node_or_null("UILayer/CeremonyLayer")
	t.assert_true(ceremony != null, "[P102] CeremonyLayer resident in UILayer")
	if ceremony != null:
		t.assert_eq(ceremony.get_index(), 0,
			"[P102] CeremonyLayer below sibling screens (UILayer index 0)")
		t.assert_true(ceremony.is_in_group("ui_dim"), "[P102] ceremony in ui_dim group")
		t.assert_eq(str(ceremony.get_meta("ui_layer", "")), "dim",
			"[P102] ceremony ui_layer metadata == dim")
		for m in ["dim_in", "dim_out", "is_dimmed", "settle"]:
			t.assert_true(ceremony.has_method(m), "[P102] ceremony has %s()" % m)
		# dim 原语：入 → 可见且目标 alpha 来自 JSON；出 → 收场不可见（沉降后断言）
		var dim_alpha: float = float(
			ConfigManager.get_ceremony_config().get("dim_alpha", 0.0))
		t.assert_true(dim_alpha > 0.0, "[P102] presentation.ceremony.dim_alpha > 0 (JSON)")
		ceremony.dim_in()
		ceremony.settle()
		t.assert_true(ceremony.is_dimmed(), "[P102] dim_in+settle -> dimmed")
		ceremony.dim_out()
		ceremony.settle()
		t.assert_false(ceremony.is_dimmed(), "[P102] dim_out+settle -> not dimmed")

	# --- 标题屏菜单重建：开始/退出；有石碑时多一项（§7 标题行） ---
	var title: Control = app.get_node("UILayer/TitleScreen")
	var quit_btn: Node = title.get_node_or_null("VBoxContainer/QuitButton")
	t.assert_true(quit_btn != null, "[P102] title menu has QuitButton")
	if quit_btn != null:
		t.assert_eq(quit_btn.text, "退出", "[P102] quit button labeled 退出")
		t.assert_true(quit_btn.pressed.get_connections().size() >= 1,
			"[P102] quit button wired (never pressed in tests)")
	t.assert_true(title.has_method("set_stone_source"), "[P102] title has set_stone_source()")
	t.assert_true(title.has_signal("stones_pressed"), "[P102] title has stones_pressed signal")
	if title.has_method("set_stone_source"):
		# main._ready 注入的是 boot(TEMP) 前的生产档读数——重注入临时档石碑源去环境依赖
		title.set_stone_source(root.get_legacy_stone_system())
		var stone_entry: Node = title.get_node_or_null("VBoxContainer/StoneEntryButton")
		t.assert_true(stone_entry == null or not stone_entry.visible,
			"[P102] no stone entry without stones (fresh save)")
		var stub := StubStoneSource.new()
		stub.stones = [{"display_name": "测试石"}]
		title.set_stone_source(stub)
		stone_entry = title.get_node_or_null("VBoxContainer/StoneEntryButton")
		t.assert_true(stone_entry != null and stone_entry.visible,
			"[P102] stone entry appears when stones exist")
		t.assert_true(title.stones_pressed.get_connections().size() >= 1,
			"[P102] stones_pressed wired into main run flow")
		stub.stones = []
		title.set_stone_source(stub)
		stone_entry = title.get_node_or_null("VBoxContainer/StoneEntryButton")
		t.assert_true(stone_entry == null or not stone_entry.visible,
			"[P102] stone entry hides again when stones drained")

	# --- game_over → 总结屏可见 + SUMMARY 状态（§7：局后总结屏） ---
	var summary_screen: Control = app.get_node("UILayer/GameOverScreen")
	t.assert_true(summary_screen.has_signal("title_pressed"),
		"[P102] summary screen has title_pressed signal")
	GameManager.current_state = GameManager.GameState.PLAYING
	EventBus.game_over.emit({
		"cause": "p102_probe", "final_length": 0, "score": 0, "best_score": 0})
	if ceremony != null and ceremony.has_method("settle"):
		ceremony.settle()  # T103 起死亡仪式门控总结屏；settle 快进到总结
	t.assert_true(summary_screen.visible, "[P102] game_over shows summary screen")
	if "SUMMARY" in GameManager.GameState:
		t.assert_eq(GameManager.current_state, GameManager.GameState.SUMMARY,
			"[P102] summary screen visible -> state SUMMARY")

	# --- 回标题：SUMMARY ──回标题──> TITLE（§7 流程图右下分支） ---
	var title_btn: Node = summary_screen.get_node_or_null("VBoxContainer/TitleButton")
	t.assert_true(title_btn != null, "[P102] summary menu has TitleButton (回标题)")
	if title_btn != null:
		summary_screen.title_pressed.emit()
		t.assert_eq(GameManager.current_state, GameManager.GameState.TITLE,
			"[P102] 回标题 -> TITLE")
		t.assert_true(title.visible, "[P102] 回标题 -> title screen visible")
		t.assert_false(summary_screen.visible, "[P102] 回标题 -> summary hidden")
		t.assert_eq(app.get_node("GameWorldContainer").get_child_count(), 0,
			"[P102] 回标题 -> game world cleaned up")

	# 收尾：壳层释放 + 还原 GameManager
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


func _remove_temp_save() -> void:
	if FileAccess.file_exists(TEMP_SAVE_PATH):
		DirAccess.remove_absolute(TEMP_SAVE_PATH)
