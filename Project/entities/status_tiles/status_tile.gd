class_name StatusTile
extends GridEntity

## 空间状态格 — 地板上的状态效果区域。
## 实体踩入时触发状态转化（T14），到期自动消失。

var status_type: String = ""
var layer: int = 1
var duration: float = 0.0
var max_duration: float = 0.0
var tile_color: Color = Color.WHITE

var _color_rect: ColorRect


func _init() -> void:
	entity_type = Constants.EntityType.STATUS_TILE
	blocks_movement = false
	is_solid = false
	cell_layer = 0  # 地板层，低于实体


func _ready() -> void:
	_setup_visual()


func _setup_visual() -> void:
	_color_rect = ColorRect.new()
	_color_rect.size = Vector2(Constants.cell_size, Constants.cell_size)
	_color_rect.position = -Vector2(Constants.cell_size, Constants.cell_size) / 2.0
	_update_visual()
	add_child(_color_rect)


func _update_visual() -> void:
	if _color_rect == null:
		return
	var alpha: float = clampf(0.3 + 0.1 * layer, 0.3, 0.6)
	_color_rect.color = Color(tile_color.r, tile_color.g, tile_color.b, alpha)


func setup(p_type: String, p_layer: int, p_duration: float, p_color: Color) -> void:
	status_type = p_type
	layer = p_layer
	duration = p_duration
	max_duration = p_duration
	tile_color = p_color
	_update_visual()


func add_layer() -> void:
	layer += 1
	duration = max_duration
	_update_visual()


func tick_duration(delta: float) -> bool:
	## 返回 true 表示已过期
	duration -= delta
	return duration <= 0.0


func _on_stepped_on(stepper: Node) -> void:
	EventBus.entity_entered_status_tile.emit({
		"entity": stepper,
		"tile": self,
		"position": grid_position,
		"type": status_type,
	})
