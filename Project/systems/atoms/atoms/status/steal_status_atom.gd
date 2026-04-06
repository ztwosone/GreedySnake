class_name StealStatusAtom
extends AtomBase
## 从 target 偷取所有状态到 source（StatusCarrier 接口）
## on_kill 场景: ctx.target = carrier（蛇），实际偷窃对象在 ctx.params["enemy_def"]
## 如果 source 是 Snake（有 segments），用 segments[0] 作为状态接收者


func execute(ctx: AtomContext) -> void:
	if not ctx.source:
		return

	# 确定偷窃目标：优先从 params 取被杀敌人
	var steal_target = ctx.params.get("enemy_def", ctx.target)
	if not is_instance_valid(steal_target):
		return
	if not steal_target.has_method("get_statuses"):
		return

	# 确定接收者：Snake → 用 segments[0]（蛇头段）
	var receiver = ctx.source
	if receiver.get("segments") != null and receiver.segments.size() > 0:
		var head_seg = receiver.segments[0]
		if head_seg.has_method("add_status"):
			receiver = head_seg
	if not receiver.has_method("add_status"):
		return

	var statuses: Array = steal_target.get_statuses()
	for status_type in statuses:
		receiver.add_status(status_type)
		steal_target.remove_status(status_type)
