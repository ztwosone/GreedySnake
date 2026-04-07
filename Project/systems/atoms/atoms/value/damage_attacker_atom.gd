class_name DamageAttackerAtom
extends AtomBase
## 对攻击者造成伤害
## 参数: amount (int, default 1)
## 从 ctx.params["enemy"] 获取攻击者


func execute(ctx: AtomContext) -> void:
	var amount: int = get_param("amount", 1)
	if amount <= 0:
		return
	var enemy = ctx.params.get("enemy", null)
	if enemy == null:
		enemy = ctx.params.get("enemy_def", null)
	if enemy and is_instance_valid(enemy) and enemy.has_method("take_damage"):
		enemy.take_damage(amount)
