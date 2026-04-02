class_name StatusTile
extends GridEntity

## 空间状态格 — 地板上的状态效果区域。
## 实体踩入时触发状态转化（T14），到期自动消失。

## StatusCarrier 内部存储
var _statuses: Array[String] = []
var tile_color: Color = Color.WHITE

## 兼容 getter — 外部读 status_type 仍可用
var status_type: String:
	get: return _statuses[0] if not _statuses.is_empty() else ""

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
	_color_rect.color = Color(tile_color.r, tile_color.g, tile_color.b, 0.4)


func setup(p_type: String, p_color: Color) -> void:
	_statuses.clear()
	if p_type != "":
		_statuses.append(p_type)
	tile_color = p_color
	_update_visual()


# === StatusCarrier 接口 ===

func get_statuses() -> Array[String]:
	return _statuses.duplicate()


func has_status(type: String) -> bool:
	return type in _statuses


func add_status(type: String) -> bool:
	if type in _statuses:
		return false
	_statuses.append(type)
	_update_visual()
	EventBus.status_added_to_carrier.emit({
		"carrier": self, "type": type, "carrier_type": "status_tile"
	})
	return true


func remove_status(type: String) -> void:
	if type not in _statuses:
		return
	_statuses.erase(type)
	_update_visual()
	EventBus.status_removed_from_carrier.emit({
		"carrier": self, "type": type, "carrier_type": "status_tile"
	})


func clear_all_statuses() -> void:
	var old := _statuses.duplicate()
	_statuses.clear()
	_update_visual()
	for type in old:
		EventBus.status_removed_from_carrier.emit({
			"carrier": self, "type": type, "carrier_type": "status_tile"
		})


func get_carrier_type() -> String:
	return "status_tile"


func _on_stepped_on(stepper: Node) -> void:
	EventBus.entity_entered_status_tile.emit({
		"entity": stepper,
		"tile": self,
		"position": grid_position,
		"type": status_type,
	})
