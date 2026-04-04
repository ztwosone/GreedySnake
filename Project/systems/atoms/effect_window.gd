extends RefCounted
## 效果窗口数据类
## 持续 N tick 的时间窗口，窗口期间规则覆写可被各系统查询。

var window_id: String = ""
var duration_ticks: int = 0
var remaining_ticks: int = 0
var rules: Dictionary = {}       # { "ignore_hit_counter": true, ... }
var on_expire: Array = []        # 到期执行的原子定义列表
var cancel_on: String = ""       # 取消信号名（空 = 无自动取消）
var owner: Object = null         # 开窗口的实体（弱引用语义）


func init_from_config(wid: String, config: Dictionary, p_owner: Object) -> void:
	window_id = wid
	duration_ticks = int(config.get("duration_ticks", 4))
	remaining_ticks = duration_ticks
	rules = config.get("rules", {})
	on_expire = config.get("on_expire", [])
	cancel_on = config.get("cancel_on", "")
	owner = p_owner
