extends RefCounted
## 虚拟玩家决策基类
## 子类重写 decide() 实现不同策略


func decide(snapshot: Dictionary) -> Dictionary:
	return {"direction": Vector2i.ZERO}
