class_name CancelWindowAtom
extends AtomBase
## 取消指定效果窗口
## 参数: window_id (String)
## 用于 Lag Tail on_removed 取消持久窗口。


func execute(ctx: AtomContext) -> void:
	if not ctx.window_mgr:
		return
	var wid: String = get_param("window_id", "")
	if wid.is_empty():
		return
	ctx.window_mgr.cancel_window(wid, "atom")
