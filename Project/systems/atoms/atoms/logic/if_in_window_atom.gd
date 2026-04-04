class_name IfInWindowAtom
extends AtomBase
## 条件原子：检查指定窗口是否活跃
## 参数: window_id


func is_condition() -> bool:
	return true


func evaluate(ctx: AtomContext) -> bool:
	if not ctx.window_mgr:
		return false
	var wid: String = get_param("window_id", "")
	if wid.is_empty():
		return false
	return ctx.window_mgr.is_active(wid)
