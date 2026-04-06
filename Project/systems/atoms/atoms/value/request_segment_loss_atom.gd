class_name RequestSegmentLossAtom
extends AtomBase
## 请求段丢失（绕过 block_segment_loss 拦截）
## 参数: amount (int, default 1)
## 用于 Lag Tail 延迟窗口到期后真正执行段移除。


func execute(ctx: AtomContext) -> void:
	var amount: int = get_param("amount", 1)
	if amount <= 0:
		return
	EventBus.length_decrease_requested.emit({
		"amount": amount,
		"source": "lag_tail_expire",
		"bypass_block": true,
	})
