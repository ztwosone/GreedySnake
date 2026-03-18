class_name EffectChain
extends RefCounted
## 运行时效果链
## 表示一个 trigger + conditions + atoms + pattern 的组合。

# === 触发器 ===
var trigger: String = ""              # on_interval, on_applied, on_layer_reach 等
var trigger_params: Dictionary = {}   # interval, layer 阈值等

# === 条件与动作 ===
var conditions: Array = []            # Array[AtomBase] — if_* 条件原子
var actions: Array = []               # Array[AtomBase] — 动作原子

# === 范围 ===
var pattern: String = "self"          # self, target, radius, neighbors 等
var pattern_params: Dictionary = {}   # radius, count, segment 等

# === 概率 ===
var chance: float = 1.0               # 触发概率 (0.0~1.0)

# === 来源标记 ===
var chain_source: String = ""         # "entity_effect", "tile_effect", "trail_effect", "reaction"

# === 运行时状态（per-instance） ===
var _elapsed: float = 0.0            # on_interval 的计时器
var _counter: int = 0                # accumulate / if_count_reached 用
var _active: bool = true             # 是否启用
var _owner_effect = null             # 关联的 StatusEffectData（弱引用概念）


## 重置运行时状态
func reset_state() -> void:
	_elapsed = 0.0
	_counter = 0
	_active = true


## 推进 interval 计时器，返回是否应该触发
func advance_interval(delta: float) -> bool:
	if trigger != "on_interval":
		return false
	var interval: float = trigger_params.get("interval", 1.0)
	_elapsed += delta
	if _elapsed >= interval:
		_elapsed -= interval
		return true
	return false


## 检查 layer_reach 是否匹配
func check_layer_reach(new_layer: int) -> bool:
	if trigger != "on_layer_reach":
		return false
	var threshold: int = int(trigger_params.get("layer", 1))
	return new_layer >= threshold
