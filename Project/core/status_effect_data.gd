class_name StatusEffectData
extends RefCounted
## 状态效果数据容器（轻量级，不加入场景树）

var type: String = ""            # 状态类型 ID（"fire"/"ice"/"poison"）
var layer: int = 1               # 当前层数（≥1）
var max_layers: int = 1          # 最大层数
var carrier: Object = null       # 载体引用（蛇段/敌人/StatusTile）
var carrier_type: String = ""    # "entity" 或 "spatial"
var duration: float = 0.0        # 剩余持续时间（秒）
var max_duration: float = 0.0    # 完整持续时间（叠层刷新用）
var source: String = ""          # 来源描述
var elapsed: float = 0.0         # 已经过时间
var chains: Array = []           # 运行时 EffectChain 列表（由 SEM 填充）


static func create(p_type: String, p_carrier: Object, p_carrier_type: String, p_source: String) -> StatusEffectData:
	var cfg_node = Engine.get_main_loop().root.get_node_or_null("ConfigManager")
	var cfg_data: Dictionary = {}
	if cfg_node:
		cfg_data = cfg_node.get_status_effect(p_type)

	var effect := StatusEffectData.new()
	effect.type = p_type
	effect.layer = 1
	effect.max_layers = int(cfg_data.get("max_layers", 1))
	effect.carrier = p_carrier
	effect.carrier_type = p_carrier_type
	effect.source = p_source

	var dur: float = float(cfg_data.get("entity_duration", 6.0))
	effect.duration = dur
	effect.max_duration = dur
	effect.elapsed = 0.0

	return effect
