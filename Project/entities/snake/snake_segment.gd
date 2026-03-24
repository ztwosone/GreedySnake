class_name SnakeSegment
extends GridEntity

const HEAD := 0
const BODY := 1
const TAIL := 2

const COLOR_HEAD := Color(0.95, 0.95, 0.95)
const COLOR_BODY := Color(0.78, 0.78, 0.78)
const COLOR_TAIL := Color(0.6, 0.6, 0.6)

var segment_index: int = 0
var segment_type: int = BODY
var carried_status: String = ""  # 独立携带的状态类型（fire/ice/poison/""）

var _color_rect: ColorRect
var _status_overlay: ColorRect  # 状态叠加层
var _border_rect: ColorRect  # 灼烧描边
var _status_tween: Tween  # 当前状态动画
var _current_status_visual: String = ""  # 当前显示的状态视觉类型


func _init() -> void:
	entity_type = Constants.EntityType.SNAKE_SEGMENT
	blocks_movement = true
	is_solid = true


func _ready() -> void:
	_color_rect = ColorRect.new()
	_color_rect.size = Vector2(Constants.CELL_SIZE, Constants.CELL_SIZE)
	_color_rect.position = Vector2(-Constants.CELL_SIZE / 2, -Constants.CELL_SIZE / 2)
	add_child(_color_rect)

	# 状态叠加层（半透明覆盖）
	_status_overlay = ColorRect.new()
	_status_overlay.size = Vector2(Constants.CELL_SIZE, Constants.CELL_SIZE)
	_status_overlay.position = Vector2(-Constants.CELL_SIZE / 2, -Constants.CELL_SIZE / 2)
	_status_overlay.color = Color(0, 0, 0, 0)
	_status_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status_overlay)

	# 灼烧描边（外框比 color_rect 大，露出边缘）
	_border_rect = ColorRect.new()
	var border: float = 3.0
	_border_rect.size = Vector2(Constants.CELL_SIZE + border * 2, Constants.CELL_SIZE + border * 2)
	_border_rect.position = Vector2(-Constants.CELL_SIZE / 2 - border, -Constants.CELL_SIZE / 2 - border)
	_border_rect.color = Color(1.0, 0.3, 0.0, 0.0)  # 初始透明
	_border_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_border_rect)
	# border_rect 在底层，color_rect 在上层遮挡中间，露出边缘 = 描边
	_color_rect.z_index = 1
	_status_overlay.z_index = 2
	_border_rect.z_index = 0

	update_visual()


func update_visual() -> void:
	if not _color_rect:
		return
	match segment_type:
		HEAD:
			_color_rect.color = COLOR_HEAD
		BODY:
			_color_rect.color = COLOR_BODY
		TAIL:
			_color_rect.color = COLOR_TAIL


func apply_status_visual(status_type: String, layer: int) -> void:
	## 根据最高优先级状态设置视觉效果
	_clear_status_visual()
	_current_status_visual = status_type

	if not _status_overlay:
		return

	match status_type:
		"ice":
			if layer >= 2:
				_status_overlay.color = Color(0.9, 0.95, 1.0, 0.7)
			else:
				_status_overlay.color = Color(0.4, 0.6, 1.0, 0.55)
		"fire":
			if _border_rect:
				_border_rect.color = Color(1.0, 0.3, 0.0, 0.9)
			_status_overlay.color = Color(1.0, 0.4, 0.1, 0.3)
			if is_inside_tree():
				_status_tween = create_tween().set_loops()
				if _border_rect:
					_status_tween.tween_property(_border_rect, "color:a", 0.3, 0.25)
					_status_tween.tween_property(_border_rect, "color:a", 0.9, 0.25)
		"poison":
			_status_overlay.color = Color(0.2, 0.8, 0.1, 0.45)
			if is_inside_tree():
				_status_tween = create_tween().set_loops()
				_status_tween.tween_property(_status_overlay, "color:a", 0.25, 0.5)
				_status_tween.tween_property(_status_overlay, "color:a", 0.55, 0.5)


func clear_status_visual() -> void:
	_clear_status_visual()
	_current_status_visual = ""


func _clear_status_visual() -> void:
	if _status_tween and _status_tween.is_valid():
		_status_tween.kill()
		_status_tween = null
	if _status_overlay:
		_status_overlay.color = Color(0, 0, 0, 0)
	if _border_rect:
		_border_rect.color = Color(1.0, 0.3, 0.0, 0.0)


func get_current_status_visual() -> String:
	return _current_status_visual


func set_carried_status(type: String) -> void:
	carried_status = type
	if type == "":
		clear_status_visual()
	else:
		apply_status_visual(type, 1)


func clear_carried_status() -> void:
	carried_status = ""
	clear_status_visual()
