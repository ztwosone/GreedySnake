class_name DirectGrowAtom
extends AtomBase
## 直接增长蛇身 N 段（跳过食物流程）
## 参数: amount (int, default 1)


func execute(ctx: AtomContext) -> void:
	var amount: int = get_param("amount", 1)
	if amount <= 0:
		return
	var snake = ctx.source
	if snake and snake.has_method("request_grow"):
		snake.request_grow(amount)
