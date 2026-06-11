extends Control
## 标题屏（Phase P T102：§7 菜单重建——开始/退出，有石碑时多一项「传承石」）
## 设计: Designs/Interactive/presentation_design.md §3（角括号框菜单）/§4（display 级标题）/§7。
## 公共契约不变（main.gd 依赖）：start_pressed 信号 + 场景节点路径
## VBoxContainer/TitleLabel、VBoxContainer/StartButton（test_t11 打包结构）。
## 石碑源 duck-typed 注入（get_available_stones），未注入 = 无石碑项；
## 退出/传承石按钮运行时构建（QuitButton/StoneEntryButton，test_xp_appflow 契约）。

signal start_pressed
signal stones_pressed
signal quit_pressed

const _KitPanelScript := preload("res://ui/kit/kit_panel.gd")

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var menu_box: VBoxContainer = $VBoxContainer

var _frame_panel: PanelContainer
var _stone_entry_button: Button
var _quit_button: Button
## §7 标题行：石碑源（duck-typed get_available_stones；未注入零行为）
var _stone_source = null


func _ready() -> void:
	# §2/§4：共享 kit Theme（palette/typography 单一事实源）
	theme = _KitPanelScript._get_shared_theme()
	start_button.pressed.connect(_on_start_pressed)
	_build_menu_entries()
	_build_frame()
	# 局后回标题时石碑可能新铸——重显时刷新菜单项
	visibility_changed.connect(_refresh_stone_entry)


## §7：菜单 = 开始 /（有石碑）传承石 / 退出；运行时构建保持打包结构契约
func _build_menu_entries() -> void:
	_stone_entry_button = Button.new()
	_stone_entry_button.name = "StoneEntryButton"
	_stone_entry_button.text = "传承石"
	_stone_entry_button.visible = false
	_stone_entry_button.pressed.connect(func() -> void: stones_pressed.emit())
	menu_box.add_child(_stone_entry_button)

	_quit_button = Button.new()
	_quit_button.name = "QuitButton"
	_quit_button.text = "退出"
	_quit_button.pressed.connect(func() -> void: quit_pressed.emit())
	menu_box.add_child(_quit_button)


## 石碑源注入（main.gd 接 LegacyStoneSystem；测试可注入替身）
func set_stone_source(source) -> void:
	_stone_source = source
	_refresh_stone_entry()


func _refresh_stone_entry() -> void:
	if _stone_entry_button == null:
		return
	var has_stones: bool = false
	if _stone_source != null and _stone_source.has_method("get_available_stones"):
		has_stones = not (_stone_source.get_available_stones() as Array).is_empty()
	_stone_entry_button.visible = has_stones


## §3 签名母题：菜单坐在 bg_panel 底 + 四角括号（kit_panel）上，矩形跟随菜单尺寸
func _build_frame() -> void:
	_frame_panel = _KitPanelScript.new()
	_frame_panel.name = "MenuFrame"
	_frame_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame_panel)
	move_child(_frame_panel, 0)
	# §6/§12.1：交互件入 ui_hit 组并保证最小命中目标
	_frame_panel.register_hit_target(start_button)
	_frame_panel.register_hit_target(_stone_entry_button)
	_frame_panel.register_hit_target(_quit_button)
	menu_box.item_rect_changed.connect(_sync_frame)
	_sync_frame()


func _sync_frame() -> void:
	if _frame_panel == null:
		return
	var pad: float = float(ConfigManager.get_layout_config().get("panel_padding", 0))
	_frame_panel.position = menu_box.position - Vector2(pad, pad)
	_frame_panel.size = menu_box.size + Vector2(pad, pad) * 2.0


func _on_start_pressed() -> void:
	start_pressed.emit()
