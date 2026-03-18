class_name AtomBase
extends RefCounted
## 效果原子基类
## 所有原子继承此类，覆写 execute() 或 evaluate()。

var _params: Dictionary = {}


## 配置原子参数（从 JSON 解析后调用）
func configure(params: Dictionary) -> void:
	_params = params


## 执行原子效果（动作原子覆写）
func execute(ctx: AtomContext) -> void:
	pass


## 评估条件（条件原子覆写）
func evaluate(ctx: AtomContext) -> bool:
	return true


## 是否为条件原子
func is_condition() -> bool:
	return false


## 获取参数值，带默认值
func get_param(key: String, default_value = null):
	return _params.get(key, default_value)
