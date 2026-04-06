class_name ModifyHitsTakenAtom
extends AtomBase
## 修改蛇的 hits_taken 计数器
## 参数: value (int, default -1)
## 用于 Lag Tail L2 取消丢段时额外减少受击计数。


func execute(ctx: AtomContext) -> void:
	var value: int = get_param("value", -1)
	var snake = ctx.source
	if snake and "hits_taken" in snake:
		snake.hits_taken = max(0, snake.hits_taken + value)
