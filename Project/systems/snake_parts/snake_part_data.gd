extends RefCounted
## 蛇部件数据类
## 兼容 TriggerManager._build_context 的 duck typing：carrier, type, layer

var part_type: String = "head"        # "head" / "tail"
var part_id: String = ""              # "hydra" / "bai_she"
var level: int = 1
var carrier: Object = null            # Snake 节点引用
var carrier_type: String = "entity"
var type: String = ""                 # = part_id（TriggerManager 兼容）
var layer: int = 1                    # 兼容字段
var chains: Array = []                # 解析后的 EffectChain 列表


func init_data(p_part_type: String, p_part_id: String, p_level: int, p_carrier: Object, p_chains: Array) -> void:
	part_type = p_part_type
	part_id = p_part_id
	level = p_level
	carrier = p_carrier
	carrier_type = "entity"
	type = p_part_id
	layer = 1
	chains = p_chains
