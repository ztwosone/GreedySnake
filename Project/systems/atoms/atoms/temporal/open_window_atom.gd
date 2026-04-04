class_name OpenWindowAtom
extends AtomBase
## 开启效果窗口
## 参数: window_id, duration_ticks, rules, on_expire, cancel_on


func execute(ctx: AtomContext) -> void:
	if not ctx.window_mgr:
		return
	var wid: String = get_param("window_id", "")
	if wid.is_empty():
		return
	var config := {
		"duration_ticks": get_param("duration_ticks", 4),
		"rules": get_param("rules", {}),
		"on_expire": get_param("on_expire", []),
		"cancel_on": get_param("cancel_on", ""),
	}
	ctx.window_mgr.open_window(wid, config, ctx.source)
