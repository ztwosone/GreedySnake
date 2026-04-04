class_name ModifyHitThresholdAtom
extends AtomBase
## 修改 hits_per_segment_loss 阈值
## 参数: value (int, 叠加到 ctx.results["hit_threshold_modifier"])


func execute(ctx: AtomContext) -> void:
	var value: int = get_param("value", 0)
	var current: int = int(ctx.results.get("hit_threshold_modifier", 0))
	ctx.results["hit_threshold_modifier"] = current + value
