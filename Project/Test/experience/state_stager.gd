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
	##   "l4_shop_open"：走完两战斗一奖励进商店房（ShopPanel 可见 + 蜕皮 chip，spec 002 T3）
	##   "l4_floor_reward_slot"：Boss 结算第一段（FloorRewardPanel 槽位定位选择，spec 002 T5b）
	##   "l4_floor_reward_choice"：Boss 结算第二段（FloorRewardPanel choice_card×3，spec 002 T5b）
	##   "l5_stone_select"：传承石选择屏（main.tscn 壳层 + 假档 2 石临时路径，spec 003 M3；
	##   teardown 删临时档——存档卫生：root 先 boot(临时路径) 再开屏，生产存档零写入）
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
	if state_name == "l5_stone_select":
		return _stage_stone_select(host, ctx)
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
		"l4_shop_open":
			# spec 002 T3：固定路径走到 shop_01（ShopPanel 货架可见，蜕皮余额来自两次放弃）
			var shop_room_flow: Node = world.get_node("RoomFlowSystem")
			var shop_floor_panel: Control = world.get_node("UI/FloorProgressPanel")
			var shop_scale_panel: Node = world.get_node_or_null("UI/ScaleChoicePanel")
			var shop_reward_panel: Node = world.get_node_or_null("UI/RewardChoicePanel")
			var shop_required: int = int(shop_room_flow.get_objective_progress().get("required", 1))
			shop_room_flow.record_objective_progress(shop_required, {"method": "state_stager"})
			if shop_scale_panel != null and shop_scale_panel.has_method("discard_offer"):
				shop_scale_panel.discard_offer()
			shop_floor_panel.request_next_room()  # reward_01
			if shop_reward_panel != null and shop_reward_panel.has_method("choose_option_by_index"):
				shop_reward_panel.choose_option_by_index(0)
			shop_floor_panel.request_next_room()  # combat_02
			shop_room_flow.record_objective_progress(shop_required, {"method": "state_stager"})
			if shop_scale_panel != null and shop_scale_panel.has_method("discard_offer"):
				shop_scale_panel.discard_offer()
			shop_floor_panel.request_next_room()  # shop_01
		"l4_floor_reward_slot", "l4_floor_reward_choice":
			# spec 002 T5b：Boss 结算两段式（系统公共 API 直驱呈现，面板随事件展示；
			# 第二段在槽位选择后呈现 choice_card×3）
			var floor_reward_system: Node = world.get_node_or_null("FloorRewardSystem")
			var floor_reward_panel: Node = world.get_node_or_null("UI/FloorRewardPanel")
			if floor_reward_system != null and floor_reward_system.has_method("present_settlement"):
				floor_reward_system.present_settlement(1, "state_stager")
				if state_name == "l4_floor_reward_choice" and floor_reward_panel != null:
					floor_reward_panel.choose_slot_by_index(0)
		_:
			push_warning("state_stager: unknown state '%s', staged bare run" % state_name)
	return ctx


## 传承石选择屏布景（spec 003 M3）：临时档写 2 块假石 → 壳层入树 → root 换临时档 →
## 隐标题 + open()。存档卫生：屏幕流不发 run_ended，但 boot(临时路径) 仍前置——
## 布景期间任何意外落盘都打在临时档上；teardown 按 ctx["temp_save_path"] 删档。
static func _stage_stone_select(host: Node, ctx: Dictionary) -> Dictionary:
	var temp_path: String = "user://stager_stone_select_tmp.json"
	var MetaSaveScript: GDScript = load("res://systems/meta_growth/meta_save_system.gd")
	var meta = MetaSaveScript.new(temp_path)
	meta.reset()
	meta.add_legacy_stone({
		"description": "上一局大杀四方",
		"highlight_type": "high_kills",
		"display_name": "杀戮传承",
		"bias_config": {"scale_tag_weights": {"fire": 1.3}},
		"created_at": 1,
	})
	meta.add_legacy_stone({
		"description": "稳健存活到了最后",
		"highlight_type": "long_survival",
		"display_name": "生存传承",
		"bias_config": {"scale_tag_weights": {"recovery": 1.5}},
		"created_at": 2,
	})
	meta.save_to_disk()
	ctx["temp_save_path"] = temp_path

	var scene: PackedScene = load(MAIN_SCENE_PATH) as PackedScene
	if scene == null:
		push_warning("state_stager: main scene failed to load")
		return ctx
	var app: Node = scene.instantiate()
	host.add_child(app)
	ctx["world"] = app
	ctx["ui_root"] = app.get_node("UILayer")
	var root: Node = app.get_node_or_null("MetaGrowthRoot")
	if root != null and root.has_method("boot"):
		root.boot(temp_path)
	app.get_node("UILayer/TitleScreen").hide()
	var screen: Node = app.get_node_or_null("UILayer/StoneSelectScreen")
	if screen != null and screen.has_method("open"):
		screen.open()
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
			"cause": "hit_self",
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
	# 存档卫生：布景用临时档随布景一起清理
	var temp_save_path: String = str(ctx.get("temp_save_path", ""))
	if temp_save_path != "" and FileAccess.file_exists(temp_save_path):
		DirAccess.remove_absolute(temp_save_path)
