extends Control
## 标题屏（SpecKit 004 T013：kit 样式迁移；完整标题屏重建属 Phase P T102）
## 设计: Designs/Interactive/presentation_design.md §3（角括号框菜单）/§4（display 级标题）/§7。
## 公共契约不变（main.gd 依赖）：start_pressed 信号 + 场景节点路径
## VBoxContainer/TitleLabel、VBoxContainer/StartButton（test_t11 打包结构）。

signal start_pressed

const _KitPanelScript := preload("res://ui/kit/kit_panel.gd")

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var menu_box: VBoxContainer = $VBoxContainer

var _frame_panel: PanelContainer


func _ready() -> void:
	# §2/§4：共享 kit Theme（palette/typography 单一事实源）
	theme = _KitPanelScript._get_shared_theme()
	start_button.pressed.connect(_on_start_pressed)
	_build_frame()


## §3 签名母题：菜单坐在 bg_panel 底 + 四角括号（kit_panel）上，矩形跟随菜单尺寸
func _build_frame() -> void:
	_frame_panel = _KitPanelScript.new()
	_frame_panel.name = "MenuFrame"
	_frame_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame_panel)
	move_child(_frame_panel, 0)
	# §6/§12.1：交互件入 ui_hit 组并保证最小命中目标
	_frame_panel.register_hit_target(start_button)
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
