extends "res://core/grid_entity.gd"
## 遗物碎片网格实体（spec 003 M4 T018，Designs §9.4 掉落物）。
## 仿 food 口径：地面层（cell_layer 0）、非实体（is_solid false）、不阻挡移动——
## 蛇头进入该格即被 PickupSystem 拾取（snake_moved 事件路径）。
## 视觉：菱形色块（颜色出自 event_pickups.pickups.<id>.placeholder_color，FR-010）+
## 内核小方块；正式表现归 S4（presentation §8.7 世界内闪烁标记）。
## 无 class_name：消费方一律 preload 本文件（ScriptingLeading 附录 C.8）。

var pickup_id: String = ""
var display_name: String = ""
var _color: Color = Color(0.81, 0.58, 0.85)


func _init() -> void:
	entity_type = Constants.EntityType.PICKUP
	blocks_movement = false
	is_solid = false
	cell_layer = 0


## def = event_pickups.pickups.<pickup_id> 配置段
func setup(id: String, def: Dictionary) -> void:
	pickup_id = id
	display_name = str(def.get("display_name", ""))
	_color = Color.from_string(str(def.get("placeholder_color", "")), _color)


func _ready() -> void:
	var s: float = Constants.CELL_SIZE * 0.55
	var diamond := ColorRect.new()
	diamond.size = Vector2(s, s)
	diamond.position = Vector2(-s / 2, -s / 2)
	diamond.color = _color
	diamond.rotation = PI / 4.0
	diamond.pivot_offset = Vector2(s / 2, s / 2)
	add_child(diamond)

	var core_s: float = s * 0.35
	var core := ColorRect.new()
	core.size = Vector2(core_s, core_s)
	core.position = Vector2(-core_s / 2, -core_s / 2)
	core.color = Color(1.0, 1.0, 1.0, 0.85)
	add_child(core)
