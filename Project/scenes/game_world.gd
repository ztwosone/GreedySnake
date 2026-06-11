extends Node2D

const _StoneBiasScript := preload("res://systems/meta_growth/stone_bias.gd")

@onready var snake: Snake = $EntityContainer/Snake
@onready var enemy_container: Node2D = $EntityContainer/EnemyContainer
@onready var food_container: Node2D = $EntityContainer/FoodContainer
@onready var length_system: LengthSystem = $LengthSystem
@onready var food_manager: FoodManager = $FoodManager
@onready var enemy_manager: EnemyManager = $EnemyManager
@onready var status_tile_manager: StatusTileManager = $StatusTileManager
@onready var status_transfer_system: StatusTransferSystem = $StatusTransferSystem
@onready var reaction_system: ReactionSystem = $ReactionSystem
@onready var run_progression_system: Node = get_node_or_null("RunProgressionSystem")
@onready var room_flow_system: Node = get_node_or_null("RoomFlowSystem")
@onready var reward_flow_system: Node = get_node_or_null("RewardFlowSystem")
@onready var shedskin_system: Node = get_node_or_null("ShedskinSystem")
@onready var scale_reward_system: Node = get_node_or_null("ScaleRewardSystem")
@onready var shop_system: Node = get_node_or_null("ShopSystem")
@onready var slot_expansion_system: Node = get_node_or_null("SlotExpansionSystem")
@onready var floor_reward_system: Node = get_node_or_null("FloorRewardSystem")
@onready var difficulty_scaler: Node = get_node_or_null("DifficultyScaler")
@onready var room_modifier_system: Node = get_node_or_null("RoomModifierSystem")
@onready var room_director: Node = get_node_or_null("RoomDirector")
@onready var camera: Camera2D = $Camera2D

## spec 002 T022：多层切换跟踪——floor_generated 的楼层号大于当前值且 run 在跑 = 切层，
## 先 reset_for_floor() 再由 RoomDirector 在随后的 room_entered 重新布场。
## 0 = 尚未开局（start_run 的首发 floor_generated 只记录不重置）。
var _active_floor_index: int = 0


func _ready() -> void:
	# Camera centers on the grid
	var cx: float = Constants.GRID_WIDTH * Constants.CELL_SIZE / 2.0
	var cy: float = Constants.GRID_HEIGHT * Constants.CELL_SIZE / 2.0
	camera.position = Vector2(cx, cy)

	# T27A: ReactionResolver + CollisionHandler
	var reaction_resolver: Node = load("res://systems/status/reaction_resolver.gd").new()
	reaction_resolver.name = "ReactionResolver"
	add_child(reaction_resolver)

	var collision_handler: Node = load("res://systems/status/collision_handler.gd").new()
	collision_handler.name = "CollisionHandler"
	collision_handler.reaction_resolver = reaction_resolver
	collision_handler.tile_manager = status_tile_manager
	add_child(collision_handler)

	# Wire up references
	length_system.snake = snake
	food_manager.food_container = food_container
	enemy_manager.enemy_container = enemy_container
	enemy_manager.snake = snake
	enemy_manager.food_manager = food_manager
	enemy_manager.collision_handler = collision_handler
	status_transfer_system.tile_manager = status_tile_manager
	status_transfer_system.snake = snake
	status_transfer_system.collision_handler = collision_handler
	status_tile_manager.reaction_resolver = reaction_resolver
	reaction_system.tile_manager = status_tile_manager
	food_manager.tile_manager = status_tile_manager
	# StatusEffectManager 需要 tile_manager 用于火焰蔓延
	StatusEffectManager.tile_manager = status_tile_manager
	# T27: EffectWindowManager
	var WindowMgrScript: GDScript = load("res://systems/atoms/effect_window_manager.gd")
	var window_mgr: Node = WindowMgrScript.new()
	window_mgr.name = "EffectWindowManager"
	window_mgr.atom_executor = StatusEffectManager._trigger_manager.atom_executor if StatusEffectManager._trigger_manager else null
	window_mgr.atom_registry = StatusEffectManager._atom_registry
	add_child(window_mgr)

	# 补全 EffectWindowManager 系统引用
	window_mgr.effect_mgr = StatusEffectManager
	window_mgr.enemy_mgr = enemy_manager
	# Snake 无敌窗口引用
	snake._window_mgr = window_mgr
	# T30: LengthSystem 段丢失拦截引用
	length_system.window_mgr = window_mgr

	if StatusEffectManager._trigger_manager:
		StatusEffectManager._trigger_manager.enemy_mgr = enemy_manager
		StatusEffectManager._trigger_manager.food_mgr = food_manager
		StatusEffectManager._trigger_manager.window_mgr = window_mgr

	# T29: SnakePartsManager
	var SnakePartsMgrScript: GDScript = load("res://systems/snake_parts/snake_parts_manager.gd")
	var snake_parts_mgr: Node = SnakePartsMgrScript.new()
	snake_parts_mgr.name = "SnakePartsManager"
	snake_parts_mgr.init_manager(snake, StatusEffectManager._trigger_manager, StatusEffectManager._chain_resolver)
	add_child(snake_parts_mgr)

	# T31: ScaleSlotManager
	var ScaleSlotMgrScript: GDScript = load("res://systems/snake_parts/scale_slot_manager.gd")
	var scale_slot_mgr: Node = ScaleSlotMgrScript.new()
	scale_slot_mgr.name = "ScaleSlotManager"
	scale_slot_mgr.init_manager(snake, StatusEffectManager._trigger_manager, StatusEffectManager._chain_resolver)
	add_child(scale_slot_mgr)

	# T32: ResonanceManager
	var ResonanceMgrScript: GDScript = load("res://systems/snake_parts/resonance_manager.gd")
	var resonance_mgr: Node = ResonanceMgrScript.new()
	resonance_mgr.name = "ResonanceManager"
	resonance_mgr.init_manager(snake, StatusEffectManager._trigger_manager, StatusEffectManager._chain_resolver, scale_slot_mgr)
	add_child(resonance_mgr)

	if reward_flow_system and reward_flow_system.has_method("setup"):
		reward_flow_system.setup(snake_parts_mgr, scale_slot_mgr)

	# spec 002 T010: 鳞片奖励链（战斗房 room_completed → offer → 决议，FR-018 无合成 room_completed）
	if scale_reward_system and scale_reward_system.has_method("setup"):
		scale_reward_system.setup(scale_slot_mgr)

	# spec 002 T016: 商店进出流 + 买槽端到端（shop_purchase → SlotExpansionSystem → open_slot）
	if shop_system and shop_system.has_method("setup"):
		shop_system.setup(shedskin_system, scale_slot_mgr, snake_parts_mgr)
	if slot_expansion_system and slot_expansion_system.has_method("setup"):
		slot_expansion_system.setup(scale_slot_mgr)

	# spec 002 T027: Boss 结算（固定槽位解锁 + 楼层奖励 3 选 1，决议先于切层——FR-007）
	if floor_reward_system and floor_reward_system.has_method("setup"):
		floor_reward_system.setup(scale_slot_mgr, slot_expansion_system)

	# spec 002 T021/T022: RoomDirector 按房型布场；切层重置经 floor_generated 触发
	# （L1/L2 验收场景无 RoomDirector/RunProgressionSystem 节点，保持原行为）
	if room_director and room_director.has_method("setup"):
		room_director.setup(enemy_manager, food_manager)

	# spec 002 T030/T031: 难度缩放唯一消费者 = RoomDirector；修饰符经注入点
	# 在布场后应用（先布怪后修饰——护盾需要已生成的敌人，FR-008/FR-009）
	if room_modifier_system and room_modifier_system.has_method("setup"):
		room_modifier_system.setup(enemy_manager, status_tile_manager, snake)
	if room_director:
		if difficulty_scaler and room_director.has_method("set_difficulty_scaler"):
			room_director.set_difficulty_scaler(difficulty_scaler)
		if room_modifier_system and room_director.has_method("set_modifier_system"):
			room_director.set_modifier_system(room_modifier_system)
	if run_progression_system and not EventBus.floor_generated.is_connected(_on_world_floor_generated):
		EventBus.floor_generated.connect(_on_world_floor_generated)

	# 蛇段增益效果系统
	var seg_effect_system := SegmentEffectSystem.new()
	seg_effect_system.name = "SegmentEffectSystem"
	seg_effect_system.snake = snake
	seg_effect_system.enemy_manager = enemy_manager
	seg_effect_system.tile_manager = status_tile_manager
	seg_effect_system.reaction_resolver = reaction_resolver
	add_child(seg_effect_system)

	# 反应视觉效果
	var reaction_vfx := ReactionVFX.new()
	reaction_vfx.name = "ReactionVFX"
	add_child(reaction_vfx)

	# VFX 层挂载
	VFXManager.setup(self)

	# 屏幕震动
	var ScreenShakeScript: GDScript = preload("res://systems/vfx/screen_shake.gd")
	var screen_shake: Node = ScreenShakeScript.new()
	screen_shake.name = "ScreenShake"
	screen_shake.setup(camera)
	add_child(screen_shake)

	# 火光环范围指示器
	var AuraIndicatorScript: GDScript = preload("res://systems/vfx/aura_indicator.gd")
	var aura_indicator: Node2D = AuraIndicatorScript.new()
	aura_indicator.name = "AuraIndicator"
	aura_indicator.snake = snake
	add_child(aura_indicator)

	# 敌人攻击范围指示器
	var DangerIndicatorScript: GDScript = preload("res://systems/vfx/danger_indicator.gd")
	var danger_indicator: Node2D = DangerIndicatorScript.new()
	danger_indicator.name = "DangerIndicator"
	danger_indicator.enemy_manager = enemy_manager
	danger_indicator.snake = snake
	add_child(danger_indicator)

	# 无身体倒计时全屏效果
	var CountdownOverlayScript: GDScript = preload("res://ui/countdown_overlay.gd")
	var countdown_overlay: CanvasLayer = CountdownOverlayScript.new()
	countdown_overlay.name = "CountdownOverlay"
	add_child(countdown_overlay)

	# 游戏开始/结束过渡效果
	var GameTransitionScript: GDScript = preload("res://systems/vfx/game_transition.gd")
	var game_transition: CanvasLayer = GameTransitionScript.new()
	game_transition.name = "GameTransition"
	add_child(game_transition)

	# debug UI（§11.7）：kill feed / debug 面板 / build 测试面板 / 事件日志
	# 统一收进 presentation.debug_ui 开关（默认关闭）；不创建即热键 (C/B/V) no-op
	if ConfigManager.is_debug_ui_enabled():
		# 击杀/事件简讯
		var KillFeedScript: GDScript = preload("res://ui/kill_feed.gd")
		var kill_feed: VBoxContainer = KillFeedScript.new()
		kill_feed.name = "KillFeed"
		$UI.add_child(kill_feed)

		# Debug 面板（按 C 切换）
		var DebugPanelScript: GDScript = preload("res://ui/debug_panel.gd")
		var debug_panel: PanelContainer = DebugPanelScript.new()
		debug_panel.name = "DebugPanel"
		debug_panel.set_snake(snake)
		$UI.add_child(debug_panel)

		# T33: Build 测试面板（按 B 切换）
		var BuildPanelScript: GDScript = preload("res://ui/build_test_panel.gd")
		var build_panel: PanelContainer = BuildPanelScript.new()
		build_panel.name = "BuildTestPanel"
		build_panel.setup(snake, snake_parts_mgr, scale_slot_mgr, resonance_mgr, window_mgr)
		$UI.add_child(build_panel)

		# 事件日志面板（按 V 切换）
		var EventLogScript: GDScript = preload("res://ui/event_log_panel.gd")
		var event_log: PanelContainer = EventLogScript.new()
		event_log.name = "EventLogPanel"
		event_log.setup(snake)
		$UI.add_child(event_log)

	var reward_panel: Node = $UI.get_node_or_null("RewardChoicePanel")
	if reward_panel and reward_panel.has_method("setup"):
		reward_panel.setup(reward_flow_system)

	var scale_choice_panel: Node = $UI.get_node_or_null("ScaleChoicePanel")
	if scale_choice_panel and scale_choice_panel.has_method("setup"):
		scale_choice_panel.setup(scale_reward_system)

	var shop_panel: Node = $UI.get_node_or_null("ShopPanel")
	if shop_panel and shop_panel.has_method("setup"):
		shop_panel.setup(shop_system)

	var floor_reward_panel: Node = $UI.get_node_or_null("FloorRewardPanel")
	if floor_reward_panel and floor_reward_panel.has_method("setup"):
		floor_reward_panel.setup(floor_reward_system)


func _exit_tree() -> void:
	if EventBus.floor_generated.is_connected(_on_world_floor_generated):
		EventBus.floor_generated.disconnect(_on_world_floor_generated)


## spec 002 T022：楼层切换监听——本世界的 run 推进到新楼层时清场重建
func _on_world_floor_generated(data: Dictionary) -> void:
	if run_progression_system == null or not run_progression_system.is_running():
		return
	var floor_index: int = int(data.get("floor_index", 0))
	# 只认本世界 run state 当前楼层的发射（其他套件/系统的 mock 发射不触发重置）
	if int(run_progression_system.get_state().get("floor_index", 0)) != floor_index:
		return
	if _active_floor_index >= 1 and floor_index > _active_floor_index:
		reset_for_floor()
	_active_floor_index = floor_index


## spec 002 T022：楼层切换清场——组合既有原语（clear_enemies/clear_foods/
## status_tile clear_all/effect window clear_all），蛇重建保长度；管理器存续
## （SnakePartsManager/ScaleSlotManager/ResonanceManager/ShedskinSystem 不动，
## Build 与蜕皮跨层存续是 FR-003/FR-013 边界，专项测试 = test_l4_slots T023）。
## 随后的 room_entered 由 RoomDirector 重新布怪布食。
func reset_for_floor() -> void:
	var preserved_length: int = snake.body.size()
	if preserved_length <= 0:
		preserved_length = Constants.INITIAL_SNAKE_LENGTH

	# 旧蛇段即将销毁：先按 target 注销其状态（不可用 StatusEffectManager.clear_all——
	# 那会连 TriggerManager 原子链一起清掉，杀死已装备 Build 的触发器）
	StatusEffectManager.remove_all_statuses(snake)
	for seg in snake.segments:
		if is_instance_valid(seg):
			StatusEffectManager.remove_all_statuses(seg)

	enemy_manager.clear_enemies()
	food_manager.clear_foods()
	status_tile_manager.clear_all()
	var win_mgr = get_node_or_null("EffectWindowManager")
	if win_mgr:
		win_mgr.clear_all()

	var start_pos := Vector2i(Constants.GRID_WIDTH / 2, Constants.GRID_HEIGHT / 2)
	snake.init_snake(start_pos, preserved_length, Constants.DIR_VECTORS[Constants.Direction.RIGHT])


## T33: 生命周期清理（在 queue_free 前调用）
func cleanup() -> void:
	_active_floor_index = 0
	if room_director and room_director.has_method("cleanup"):
		room_director.cleanup()
	if room_modifier_system and room_modifier_system.has_method("cleanup"):
		room_modifier_system.cleanup()
	if difficulty_scaler and difficulty_scaler.has_method("cleanup"):
		difficulty_scaler.cleanup()
	if floor_reward_system and floor_reward_system.has_method("cleanup"):
		floor_reward_system.cleanup()
	if shop_system and shop_system.has_method("cleanup"):
		shop_system.cleanup()
	if slot_expansion_system and slot_expansion_system.has_method("cleanup"):
		slot_expansion_system.cleanup()
	if scale_reward_system and scale_reward_system.has_method("cleanup"):
		scale_reward_system.cleanup()
	if shedskin_system and shedskin_system.has_method("cleanup"):
		shedskin_system.cleanup()
	if reward_flow_system and reward_flow_system.has_method("cleanup"):
		reward_flow_system.cleanup()
	if room_flow_system and room_flow_system.has_method("cleanup"):
		room_flow_system.cleanup()
	if run_progression_system and run_progression_system.has_method("cleanup"):
		run_progression_system.cleanup()
	var res_mgr = get_node_or_null("ResonanceManager")
	if res_mgr:
		res_mgr.clear_all()
	var scale_mgr = get_node_or_null("ScaleSlotManager")
	if scale_mgr:
		scale_mgr.clear_all()
	var parts_mgr = get_node_or_null("SnakePartsManager")
	if parts_mgr:
		parts_mgr.unequip_head()
		parts_mgr.unequip_tail()
	var win_mgr = get_node_or_null("EffectWindowManager")
	if win_mgr:
		win_mgr.clear_all()
	if StatusEffectManager._trigger_manager:
		StatusEffectManager._trigger_manager.enemy_mgr = null
		StatusEffectManager._trigger_manager.food_mgr = null
		StatusEffectManager._trigger_manager.window_mgr = null
	StatusEffectManager.clear_all()
	TickManager.stop_ticking()
	GridWorld.clear_all()


## run_options（spec 003 M3）：{ legacy_stone: Dictionary }——选中的传承石（main.gd 经
## StoneSelectScreen 注入；空/缺省 = 无石开局）。缺省参数保持全部既有调用方零改动。
func start_game(run_options: Dictionary = {}) -> void:
	# 1. Initialize Grid
	GridWorld.init_grid(Constants.GRID_WIDTH, Constants.GRID_HEIGHT)

	# 2. Initialize snake at center-left
	var start_pos := Vector2i(Constants.GRID_WIDTH / 2, Constants.GRID_HEIGHT / 2)
	snake.init_snake(start_pos, Constants.INITIAL_SNAKE_LENGTH, Constants.DIR_VECTORS[Constants.Direction.RIGHT])

	# 3. Initialize food
	food_manager.init_foods(3)

	# 3.5 spec 003 M3（T014）：传承石 bias 注入——每局显式 set-or-clear，
	# bias 生命周期恰一局（FR-015：下局未带石即清除）
	_apply_legacy_stone_bias(run_options.get("legacy_stone", {}))

	# 4. Initialize L3 run and current room
	var current_room: Dictionary = {}
	_active_floor_index = 0
	if ConfigManager.get_run_config().get("enabled", false) and run_progression_system and run_progression_system.has_method("start_run"):
		run_progression_system.start_run()
		current_room = run_progression_system.get_current_room()
		if room_flow_system and room_flow_system.has_method("enter_room"):
			room_flow_system.enter_room(current_room)

	# 5. Initialize enemies（spec 002 T021：有 RoomDirector 时由其在 room_entered
	# 按房型/主题/难度接管布怪布食；L1/L2 验收场景无该节点，保持原行为）
	if room_director == null:
		var enemy_count: int = 3
		if ConfigManager.get_run_config().get("enabled", false):
			var room_type: String = current_room.get("room_type", "combat")
			var room_cfg: Dictionary = ConfigManager.get_room_type(room_type)
			enemy_count = int(room_cfg.get("enemy_count", enemy_count))
		enemy_manager.init_enemies(enemy_count)

	# 6. Start Tick
	TickManager.start_ticking()

	# 7. Notify game started
	EventBus.game_started.emit()


## spec 003 M3（T014）：选中石的 bias_config.scale_tag_weights → stone_bias 加权重排
## Callable，注入 ScaleRewardSystem（S2 T005 既有钩子）+ RewardFlowSystem（同口径）。
## 石为空/无权重 → 注入空 Callable 清除（FR-015 恰一局有效）。
## bias RNG 种子按 run seed 派生（与 start_run 的 default_seed 解析一致，定种子可复现）。
func _apply_legacy_stone_bias(stone: Variant) -> void:
	var weights: Dictionary = {}
	if stone is Dictionary:
		weights = stone.get("bias_config", {}).get("scale_tag_weights", {})
	var bias: Callable = Callable()
	if not weights.is_empty():
		var run_seed: int = int(ConfigManager.get_floor_config().get("default_seed", 0))
		bias = _StoneBiasScript.make_bias(weights, hash("%d:stone_bias" % run_seed))
	if scale_reward_system and scale_reward_system.has_method("set_sampling_bias"):
		scale_reward_system.set_sampling_bias(bias)
	if reward_flow_system and reward_flow_system.has_method("set_sampling_bias"):
		reward_flow_system.set_sampling_bias(bias)
