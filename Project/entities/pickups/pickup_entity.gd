extends "res://core/grid_entity.gd"
## 遗物碎片网格实体（spec 003 M4 T018，Designs §9.4 掉落物）。
## 仿 food 口径：地面层（cell_layer 0）、非实体（is_solid false）、不阻挡移动——
## 蛇头进入该格即被 PickupSystem 拾取（snake_moved 事件路径）。
## 视觉：菱形色块（颜色出自 event_pickups.pickups.<id>.placeholder_color，FR-010）+
## 内核小方块 + 世界内闪烁标记（presentation §8.7 前半，T104c：正弦 alpha 脉动，
## game_feel.pickup_blink_hz 驱动；game_feel 关闭恒亮）。
## 无 class_name：消费方一律 preload 本文件（ScriptingLeading 附录 C.8）。

var pickup_id: String = ""
var display_name: String = ""
var _color: Color = Color(0.81, 0.58, 0.85)
var _blink_phase: float = 0.0


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


## §8.7 闪烁曲线（纯函数，可测）：|sin| 脉动钳在 [0.55, 1.0] 保持可读
static func blink_alpha(phase: float) -> float:
	var hz: float = float(ConfigManager.get_game_feel().get("pickup_blink_hz", 0.0))
	return 0.55 + 0.45 * absf(sin(phase * TAU * hz))


func _process(delta: float) -> void:
	# §8.7 世界内闪烁标记：game_feel 关闭恒亮（宪法：重特效可禁用）
	if not bool(ConfigManager.get_game_feel().get("enabled", true)):
		modulate.a = 1.0
		return
	_blink_phase += delta
	modulate.a = blink_alpha(_blink_phase)
