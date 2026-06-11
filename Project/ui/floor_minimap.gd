extends "res://ui/kit/kit_panel.gd"
## 楼层小地图（SpecKit 004 Phase P T104a，presentation_design.md §8.2）
## 左上角：房间 = 意图色小方块沿路径连 1px 线；当前 = 外框高亮（game_feel 开启时
## 正弦脉动）；完成 = 暗化 + 中心点；未达 = frame_line 深灰。
## 纯监听（§11.1 只听不驱动）：floor_generated 重建 / room_entered 跟当前 /
## room_completed 记完成；数据驱动 _draw 零子节点（glyph 同范式）。
## 无 class_name：消费方一律按路径加载（ScriptingLeading 附录 C.8）。

var _rooms: Array = []
var _positions: Dictionary = {}
var _completed: Dictionary = {}
var _current_room_id: String = ""
var _pulse_phase: float = 0.0


func _init() -> void:
	super._init("hud")


func _ready() -> void:
	var layout: Dictionary = ConfigManager.get_layout_config()
	var screen_margin: float = float(layout.get("screen_margin", 0))
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = screen_margin
	offset_top = screen_margin
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	EventBus.floor_generated.connect(_on_floor_generated)
	EventBus.room_entered.connect(_on_room_entered)
	EventBus.room_completed.connect(_on_room_completed)


func _exit_tree() -> void:
	if EventBus.floor_generated.is_connected(_on_floor_generated):
		EventBus.floor_generated.disconnect(_on_floor_generated)
	if EventBus.room_entered.is_connected(_on_room_entered):
		EventBus.room_entered.disconnect(_on_room_entered)
	if EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.disconnect(_on_room_completed)


func _process(delta: float) -> void:
	# §8.2 当前房外框脉动：正弦相位驱动重绘（无 Tween——不进 settle 语义，
	# 几何探测只看静态矩形）；game_feel 关闭时静态高亮
	if visible and not _current_room_id.is_empty() \
			and bool(ConfigManager.get_game_feel().get("enabled", true)):
		_pulse_phase += delta
		queue_redraw()


# === 查询契约（test_xp_minimap） ===

func get_room_count() -> int:
	return _rooms.size()


func get_current_room_id() -> String:
	return _current_room_id


func is_room_completed(room_id: String) -> bool:
	return _completed.get(room_id, false)


# === 事件 ===

func _on_floor_generated(data: Dictionary) -> void:
	_rooms = data.get("rooms", [])
	_completed.clear()
	_current_room_id = ""
	_layout_rooms(str(data.get("start_room_id", "")))
	visible = not _rooms.is_empty()
	queue_redraw()


func _on_room_entered(data: Dictionary) -> void:
	_current_room_id = str(data.get("room_id", ""))
	queue_redraw()


func _on_room_completed(data: Dictionary) -> void:
	_completed[str(data.get("room_id", ""))] = true
	queue_redraw()


# === 布局与绘制 ===

## 主路径横排（exit_room_ids[0] 链），支线房挂父房下一行（生成器契约：
## 支线为死端、主路径 exits[0] 指向下一主房——QuickReference「结构保证」）
func _layout_rooms(start_id: String) -> void:
	_positions.clear()
	var by_id: Dictionary = {}
	for room in _rooms:
		by_id[str(room.get("room_id", ""))] = room
	var col: int = 0
	var visited: Dictionary = {}
	var cursor: String = start_id
	while by_id.has(cursor) and not visited.has(cursor):
		visited[cursor] = true
		_positions[cursor] = Vector2i(col, 0)
		var room: Dictionary = by_id[cursor]
		var exits: Array = room.get("exit_room_ids", [])
		# 支线（exits[1..]）挂在本房正下方，依次右移
		var side_offset: int = 0
		for i in range(1, exits.size()):
			var side_id: String = str(exits[i])
			if by_id.has(side_id) and not _positions.has(side_id):
				_positions[side_id] = Vector2i(col + side_offset, 1)
				visited[side_id] = true
				side_offset += 1
		cursor = str(exits[0]) if exits.size() >= 1 else ""
		col += 1
	# 兜底：图外孤房追加在尾部（不应发生，防御绘制不丢房）
	for room in _rooms:
		var rid: String = str(room.get("room_id", ""))
		if not _positions.has(rid):
			_positions[rid] = Vector2i(col, 0)
			col += 1
	var base_unit: float = float(ConfigManager.get_layout_config().get("base_unit", 16))
	custom_minimum_size = Vector2(
		col * base_unit * 0.75 + base_unit * 0.5,
		2.0 * base_unit * 0.75 + base_unit * 0.5)
	size = custom_minimum_size


func _draw() -> void:
	super._draw()
	if _rooms.is_empty():
		return
	var base_unit: float = float(ConfigManager.get_layout_config().get("base_unit", 16))
	var cell: float = base_unit * 0.5
	var step: float = base_unit * 0.75
	var origin: Vector2 = Vector2(base_unit * 0.25, base_unit * 0.25)
	var line_color: Color = ConfigManager.get_palette_color("frame_line")

	# 连线：父 → exits 全部（1px）
	var by_id: Dictionary = {}
	for room in _rooms:
		by_id[str(room.get("room_id", ""))] = room
	for room in _rooms:
		var rid: String = str(room.get("room_id", ""))
		if not _positions.has(rid):
			continue
		var from: Vector2 = origin + Vector2(_positions[rid]) * step + Vector2(cell, cell) * 0.5
		for exit_id in room.get("exit_room_ids", []):
			if _positions.has(str(exit_id)):
				var to: Vector2 = origin + Vector2(_positions[str(exit_id)]) * step \
					+ Vector2(cell, cell) * 0.5
				draw_line(from, to, line_color, 1.0)

	# 房格
	for room in _rooms:
		var rid: String = str(room.get("room_id", ""))
		if not _positions.has(rid):
			continue
		var rect := Rect2(origin + Vector2(_positions[rid]) * step, Vector2(cell, cell))
		var room_color: Color = _resolve_room_color(room)
		if _completed.get(rid, false):
			# 完成 = 暗化 + 中心点
			draw_rect(rect, room_color.darkened(0.55))
			var dot: float = maxf(cell * 0.25, 2.0)
			draw_rect(Rect2(rect.get_center() - Vector2(dot, dot) * 0.5,
				Vector2(dot, dot)), ConfigManager.get_palette_color("text_primary"))
		elif rid == _current_room_id or bool(room.get("available", false)):
			draw_rect(rect, room_color)
		else:
			# 未达 = 深灰
			draw_rect(rect, line_color)
		# 当前 = 外框高亮（game_feel 开启随 _pulse_phase 脉动）
		if rid == _current_room_id:
			var outline: Color = ConfigManager.get_palette_color("accent_resonance")
			if bool(ConfigManager.get_game_feel().get("enabled", true)):
				outline.a = 0.6 + 0.4 * absf(sin(_pulse_phase * TAU * 0.5))
			draw_rect(rect.grow(2.0), outline, false, 1.0)


## §2.1：room_* palette token 优先；palette 外房型回退房 dict placeholder_color
func _resolve_room_color(room: Dictionary) -> Color:
	var token: String = "room_%s" % str(room.get("room_type", ""))
	var palette: Dictionary = ConfigManager.get_presentation_config().get("palette", {})
	if palette.has(token):
		return ConfigManager.get_palette_color(token)
	var hex: String = str(room.get("placeholder_color", ""))
	if Color.html_is_valid(hex):
		return Color.html(hex)
	return ConfigManager.get_palette_color("text_primary")
