extends RefCounted
## 状态布景器 v1（SpecKit 004 T009，设计文档 §12.1/§12.2 共用 StateStager）
## 只覆盖 T010/T014 所需的 L3 典型状态；按后续 US 增量扩展（设计允许逐步生长）。
## stage() 返回 ctx 字典，teardown(ctx) 镜像还原 —— 清理纪律与 test_l3_smoke_run 一致
## （cleanup + queue_free + 恢复 GameManager + stop_ticking + GridWorld.clear_all）。
## 非套件 harness 文件：不得命名 test_*.gd、不得放进 Test/cases/。

const GAME_WORLD_SCENE_PATH: String = "res://scenes/game_world.tscn"


static func stage(state_name: String, host: Node) -> Dictionary:
	## 已支持状态：
	##   "l3_run_start" / "l3_floor_panel"：run 起始态（FloorProgressPanel 可见，combat_01 进行中）
	##   "l3_reward_pending"：combat_01 完成 + 进奖励房（RewardChoicePanel 可见，选项就绪）
	var ctx: Dictionary = {
		"state_name": state_name,
		"world": null,
		"saved_state": GameManager.current_state,
		"saved_score": GameManager.current_score,
		"saved_best": GameManager.best_score,
	}
	var scene: PackedScene = load(GAME_WORLD_SCENE_PATH) as PackedScene
	if scene == null:
		push_warning("state_stager: game_world scene failed to load")
		return ctx
	var world: Node = scene.instantiate()
	host.add_child(world)
	world.start_game()
	GameManager.start_game()
	ctx["world"] = world
	match state_name:
		"l3_run_start", "l3_floor_panel":
			pass
		"l3_reward_pending":
			var room_flow: Node = world.get_node("RoomFlowSystem")
			var floor_panel: Control = world.get_node("UI/FloorProgressPanel")
			var required: int = int(room_flow.get_objective_progress().get("required", 1))
			room_flow.record_objective_progress(required, {"method": "state_stager"})
			floor_panel.request_next_room()
		_:
			push_warning("state_stager: unknown state '%s', staged bare run" % state_name)
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
