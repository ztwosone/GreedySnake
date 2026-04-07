class_name ModifySystemParamAtom
extends AtomBase
## 通用系统参数修改器
## 参数: param_name (String), value (float)
## 写入 StatusEffectManager 持久修改器，on_removed 用负值恢复。


func execute(ctx: AtomContext) -> void:
	var param_name: String = get_param("param_name", "")
	var value: float = get_param("value", 0.0)
	if param_name.is_empty() or value == 0.0:
		return
	if not ctx.effect_mgr or not ctx.source or not is_instance_valid(ctx.source):
		return
	var old: float = ctx.effect_mgr.get_modifier(param_name, ctx.source, 0.0)
	ctx.effect_mgr.set_modifier(param_name, ctx.source, old + value)
