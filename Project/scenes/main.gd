extends Node

const _UnlockToastScript := preload("res://ui/unlock_toast.gd")

@onready var title_screen: Control = $UILayer/TitleScreen
@onready var game_over_screen: Control = $UILayer/GameOverScreen
@onready var stone_select_screen: Control = get_node_or_null("UILayer/StoneSelectScreen")
@onready var game_world_container: Node = $GameWorldContainer
@onready var meta_growth_root: Node = get_node_or_null("MetaGrowthRoot")

var _game_world_scene: PackedScene = preload("res://scenes/game_world.tscn")
var _acceptance_scene: PackedScene = preload("res://scenes/l1_acceptance.tscn")
var _l2_acceptance_scene: PackedScene = preload("res://scenes/l2_acceptance.tscn")
var _current_game_world: Node2D
var _unlock_toast: Control
var _is_acceptance_mode: bool = false
var _acceptance_level: int = 1  # 1 = L1, 2 = L2


func _ready() -> void:
	# §2.1：bg_deep 即屏幕底色（palette 单一事实源，标题屏等无战场屏幕的窗口底色）
	RenderingServer.set_default_clear_color(ConfigManager.get_palette_color("bg_deep"))
	title_screen.start_pressed.connect(_on_start_pressed)
	game_over_screen.restart_pressed.connect(_on_restart_pressed)
	game_over_screen.test_mode_pressed.connect(_on_test_mode_pressed)
	EventBus.game_over.connect(_on_game_over)

	# spec 003 M2（T011）：解锁 toast 挂壳层 UILayer（跨 run UI，toast 层 ≤1）
	_unlock_toast = _UnlockToastScript.new()
	_unlock_toast.name = "UnlockToast"
	$UILayer.add_child(_unlock_toast)

	# spec 003 M2：game_over 结算数据通路（统计/解锁/铸石文本行，编排归 S4）
	if meta_growth_root and game_over_screen.has_method("set_summary_source"):
		game_over_screen.set_summary_source(meta_growth_root)

	# spec 003 M3（T015）：传承石选择屏接线（§7 屏幕流——开始/再来一局先经选石分流；
	# 空石碑整屏跳过 FR-012；选中石经 finished 信号注入新局）
	if stone_select_screen:
		stone_select_screen.stone_select_finished.connect(_on_stone_select_finished)
		if meta_growth_root and meta_growth_root.has_method("get_legacy_stone_system"):
			stone_select_screen.setup(meta_growth_root.get_legacy_stone_system())

	# Initial state: show title only
	title_screen.show()
	game_over_screen.hide()


func _unhandled_input(event: InputEvent) -> void:
	# §7/§11.7：T/Y 验收捷径属 debug UI，presentation.debug_ui 关闭时 no-op
	if not ConfigManager.is_debug_ui_enabled():
		return
	if not (title_screen.visible and event is InputEventKey and event.pressed):
		return
	# Press T on title screen to launch L1 acceptance test
	if event.keycode == KEY_T:
		title_screen.hide()
		_start_acceptance_test(1)
	# Press Y on title screen to launch L2 acceptance test
	elif event.keycode == KEY_Y:
		title_screen.hide()
		_start_acceptance_test(2)


func _on_start_pressed() -> void:
	title_screen.hide()
	_begin_run_flow()


func _on_restart_pressed() -> void:
	game_over_screen.hide()
	_cleanup_game_world()
	if _is_acceptance_mode:
		_start_acceptance_test(_acceptance_level)
	else:
		# §7 屏幕流：「再来一局」同样先经选石分流（刚铸成的石头下一局即登场）
		_begin_run_flow()


## spec 003 M3：开局分流——有传承石先进 STONE_SELECT，空石碑列表整屏跳过直进 RUN
## （FR-012：open() 返回 false 时屏幕绝不闪现）
func _begin_run_flow() -> void:
	if stone_select_screen and stone_select_screen.has_method("open") \
			and stone_select_screen.open():
		GameManager.enter_stone_select()
		return
	_start_new_game()


func _on_stone_select_finished(stone: Dictionary) -> void:
	_start_new_game(stone)


func _on_test_mode_pressed() -> void:
	game_over_screen.hide()
	_cleanup_game_world()
	_start_acceptance_test(_acceptance_level)


func _on_game_over(data: Dictionary) -> void:
	game_over_screen.show_results(data)


## legacy_stone（spec 003 M3）：StoneSelectScreen 选中的完整 stone dict（空 = 无石开局），
## 经 game_world.start_game(run_options) 注入本局抽样偏置（FR-015 恰一局有效）
func _start_new_game(legacy_stone: Dictionary = {}) -> void:
	_is_acceptance_mode = false
	_current_game_world = _game_world_scene.instantiate()
	game_world_container.add_child(_current_game_world)
	# spec 003 M2（T009/T010）：常驻 meta 根对新世界接线——tracker 注入（run_ended 链路）
	# + RewardFlow 解锁过滤（须先于 start_game：首个 room_entered 可能即触发 offer）
	if meta_growth_root and meta_growth_root.has_method("attach_world"):
		meta_growth_root.attach_world(_current_game_world)
	_current_game_world.start_game({"legacy_stone": legacy_stone})
	GameManager.start_game()


func _start_acceptance_test(level: int = 1) -> void:
	_is_acceptance_mode = true
	_acceptance_level = level
	_cleanup_game_world()
	var scene: PackedScene = _acceptance_scene if level == 1 else _l2_acceptance_scene
	_current_game_world = scene.instantiate()
	game_world_container.add_child(_current_game_world)
	_current_game_world.start_game()
	GameManager.start_game()


func _cleanup_game_world() -> void:
	if _current_game_world and is_instance_valid(_current_game_world):
		# T33: 先清理跨系统状态（TriggerManager/修改器/窗口），再释放节点
		if _current_game_world.has_method("cleanup"):
			_current_game_world.cleanup()
		_current_game_world.queue_free()
		_current_game_world = null
	GridWorld.clear_all()
