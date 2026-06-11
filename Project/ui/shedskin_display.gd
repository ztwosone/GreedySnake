extends "res://ui/kit/chip.gd"
## 蜕皮 HUD chip（spec 002 T009：ui/kit chip 重建，presentation_design.md §6 右上蜕皮 chip）
## 渐进披露（概念节奏）：首次蜕皮入账（amount > 0）才出现；归零/重置事件不触发披露。
## 余额变化时 bounce 组件反馈（§8.5）；局终隐藏。
## 无 class_name：消费方一律按路径加载（ScriptingLeading 附录 C.8）。
## 公共契约：get_amount_text（既有测试依赖）+ chip 的 get_glyph_id/get_text。

var _amount: int = 0


func _ready() -> void:
	var layout: Dictionary = ConfigManager.get_layout_config()
	var base_unit: float = float(layout.get("base_unit", 0))
	var screen_margin: float = float(layout.get("screen_margin", 0))
	# §6：右上角持久 HUD chip（宽 6 基准单位槽位，内容超宽向左生长）
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_left = -(screen_margin + base_unit * 6.0)
	offset_right = -screen_margin
	offset_top = screen_margin
	offset_bottom = screen_margin
	_refresh()
	_connect_events()
	visible = false


func _exit_tree() -> void:
	_disconnect_events()


func get_amount_text() -> String:
	return str(_amount)


func _connect_events() -> void:
	if not EventBus.currency_changed.is_connected(_on_currency_changed):
		EventBus.currency_changed.connect(_on_currency_changed)
	if not EventBus.game_over.is_connected(_on_game_over):
		EventBus.game_over.connect(_on_game_over)


func _disconnect_events() -> void:
	if EventBus.currency_changed.is_connected(_on_currency_changed):
		EventBus.currency_changed.disconnect(_on_currency_changed)
	if EventBus.game_over.is_connected(_on_game_over):
		EventBus.game_over.disconnect(_on_game_over)


func _refresh() -> void:
	set_content("shedskin", str(_amount), ConfigManager.get_palette_color("accent_shedskin"))


func _on_currency_changed(data: Dictionary) -> void:
	if str(data.get("currency", "")) != "shedskin":
		return
	_amount = int(data.get("total", 0))
	_refresh()
	var delta: int = int(data.get("amount", 0))
	# 渐进披露：只有真实入账（delta > 0）才首次出现
	if delta > 0 and not visible:
		visible = true
	if visible and delta != 0:
		bounce()
	# §8.5（T104b）：带事发格坐标的入账 → 金色粒子从世界坐标飞到 chip；
	# 无坐标来源（discard/商店退款等）只 bounce 不飞
	if delta > 0 and data.get("position") is Vector2i:
		var grid: Vector2i = data.get("position")
		var world: Vector2 = Vector2(grid) * Constants.CELL_SIZE \
			+ Vector2.ONE * (Constants.CELL_SIZE * 0.5)
		VFXManager.fly_to_hud(world, self,
			ConfigManager.get_palette_color("accent_shedskin"))


func _on_game_over(_data: Dictionary) -> void:
	visible = false
