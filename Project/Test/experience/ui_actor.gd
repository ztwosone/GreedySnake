extends RefCounted
## 脚本化 UI 执行器（SpecKit 004 T008）：playbook 驱动，只调用面板公共 API（§11.1 表现层契约）。
## playbook 条目：
##   {on: "reward_presented", node: <Control>, call: "choose_option_by_index", args: [0]}
##   {on: "...", node_path: "UI/RewardChoicePanel", call: "...", args: [...]}（相对 root 解析）
##   {on: "...", call: "callable", fn: Callable, args: [...]}（灵活逃生口）
## 面板 API 显式返回 false 视为失败；void/null 返回视为成功。
## 非套件 harness 文件：不得命名 test_*.gd、不得放进 Test/cases/。

var root: Node = null
var playbook: Array = []
var last_error: String = ""


func respond(pending: Array) -> bool:
	## 找到第一条命中 pending 模态事件名的 playbook 条目并执行
	for pending_entry in pending:
		var event_name: String = str(pending_entry.get("name", ""))
		for entry in playbook:
			if entry is Dictionary and str(entry.get("on", "")) == event_name:
				return _execute(entry)
	last_error = "no playbook entry for pending modals"
	return false


func _execute(entry: Dictionary) -> bool:
	var call_name: String = str(entry.get("call", ""))
	var args: Array = entry.get("args", [])
	if call_name == "callable":
		var fn: Callable = entry.get("fn", Callable())
		if not fn.is_valid():
			last_error = "callable entry missing valid fn"
			return false
		var fn_result: Variant = fn.callv(args)
		return fn_result != false
	var node: Node = entry.get("node", null) as Node
	if node == null and entry.has("node_path") and root != null:
		node = root.get_node_or_null(str(entry.get("node_path")))
	if node == null or not is_instance_valid(node):
		last_error = "playbook target node not found for '%s'" % str(entry.get("on", ""))
		return false
	if not node.has_method(call_name):
		last_error = "target node '%s' lacks method '%s'" % [node.name, call_name]
		return false
	var result: Variant = node.callv(call_name, args)
	return result != false
