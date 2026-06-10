extends RefCounted
## 状态布景器 v1（SpecKit 004 T009，设计文档 §12.1/§12.2 共用 StateStager）
## 只覆盖 T010/T014 所需的 L3 典型状态；按后续 US 增量扩展（设计允许逐步生长）。
## stage() 返回 ctx 字典，teardown(ctx) 镜像还原 —— 清理纪律与 test_l3_smoke_run 一致
## （cleanup + queue_free + 恢复 GameManager + stop_ticking + GridWorld.clear_all）。
## 非套件 harness 文件：不得命名 test_*.gd、不得放进 Test/cases/。

const GAME_WORLD_SCENE_PATH: String = "res://scenes/game_world.tscn"
const MAIN_SCENE_PATH: String = "res://scenes/main.tscn"


static func stage(state_name: String, host: Node) -> Dictionary:
	## 已支持状态：
	##   "title_screen" / "game_over"：App 壳层屏幕（main.tscn，不开局；T014）
	##   "l3_run_start" / "l3_floor_panel"：run 起始态（FloorProgressPanel 可见，combat_01 进行中）
	##   "l3_reward_pending"：combat_01 完成 + 鳞片 offer 决议 + 进奖励房（RewardChoicePanel 可见）
	##   "l4_scale_pending"：combat_01 完成（ScaleChoicePanel 可见 + 蜕皮 chip 已披露，spec 002 T2）
	## ctx["ui_root"]：几何探针扫描根（壳层屏 = UILayer，局内 = game_world 的 UI 层）
	var ctx: Dictionary = {
		"state_name": state_name,
		"world": null,
		"ui_root": null,
		"saved_state": GameManager.current_state,
		"saved_score": GameManager.current_score,
		"saved_best": GameManager.best_score,
	}
	if state_name == "title_screen" or state_name == "game_over":
		return _stage_app_screen(state_name, host, ctx)
	var scene: PackedScene = load(GAME_WORLD_SCENE_PATH) as PackedScene
	if scene == null:
		push_warning("state_stager: game_world scene failed to load")
		return ctx
	var world: Node = scene.instantiate()
	host.add_child(world)
	world.start_game()
	GameManager.start_game()
	ctx["world"] = world
	ctx["ui_root"] = world.get_node("UI")
	match state_name:
		"l3_run_start", "l3_floor_panel":
			pass
		"l3_reward_pending":
			var room_flow: Node = world.get_node("RoomFlowSystem")
			var floor_panel: Control = world.get_node("UI/FloorProgressPanel")
			var required: int = int(room_flow.get_objective_progress().get("required", 1))
			room_flow.record_objective_progress(required, {"method": "state_stager"})
			# spec 002 T2：战斗完成弹鳞片 offer（FR-015 门控），决议后才能进奖励房
			var scale_panel: Node = world.get_node_or_null("UI/ScaleChoicePanel")
			if scale_panel != null and scale_panel.has_method("discard_offer"):
				scale_panel.discard_offer()
			floor_panel.request_next_room()
		"l4_scale_pending":
			# spec 002 T2：鳞片三选一模态 + 蜕皮 chip（先入账触发渐进披露）
			var shedskin: Node = world.get_node_or_null("ShedskinSystem")
			if shedskin != null and shedskin.has_method("earn"):
				shedskin.earn(3, "state_stager")
			var l4_room_flow: Node = world.get_node("RoomFlowSystem")
			var l4_required: int = int(l4_room_flow.get_objective_progress().get("required", 1))
			l4_room_flow.record_objective_progress(l4_required, {"method": "state_stager"})
		_:
			push_warning("state_stager: unknown state '%s', staged bare run" % state_name)
	return ctx


## 壳层屏幕布景：标题屏原样；game_over = 隐标题 + show_results 既有契约
static func _stage_app_screen(state_name: String, host: Node, ctx: Dictionary) -> Dictionary:
	var scene: PackedScene = load(MAIN_SCENE_PATH) as PackedScene
	if scene == null:
		push_warning("state_stager: main scene failed to load")
		return ctx
	var app: Node = scene.instantiate()
	host.add_child(app)
	ctx["world"] = app
	ctx["ui_root"] = app.get_node("UILayer")
	if state_name == "game_over":
		app.get_node("UILayer/TitleScreen").hide()
		app.get_node("UILayer/GameOverScreen").show_results({
			"score": 3,
			"best_score": 5,
			"cause": "self_collision",
		})
	return ctx


static func teardown(ctx: Dictionary) -> void:
	var world: Node = ctx.get("world", null)
	if world != null and is_instance_valid(world):
		if world.has_method("cleanup"):
			world.cleanup()
		world.queue_free()
	GameManager.current_state = int(ctx.get("saved_state", GameManager.GameState.TITLE))
	GameManager.current_score = int(ctx.get("saved_score", 0))
	GameManager.best_score = int(ctx.get("saved_best", 0))
	TickManager.stop_ticking()
	GridWorld.clear_all()
