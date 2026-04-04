class_name ModifyFoodDropAtom
extends AtomBase
## 修改击杀后食物掉落数量
## 参数: amount (int, 叠加到 ctx.results["food_drop_modifier"])


func execute(ctx: AtomContext) -> void:
	var amount: int = get_param("amount", 0)
	var current: int = int(ctx.results.get("food_drop_modifier", 0))
	ctx.results["food_drop_modifier"] = current + amount
