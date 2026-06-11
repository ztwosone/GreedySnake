extends RefCounted
## spec 003 M3（T014）：传承石抽样偏置——把选中石的 bias_config.scale_tag_weights
## 变成「合格选项 Array → 加权重排 Array」的 Callable，喂给既有抽样缝
## （ScaleRewardSystem.set_sampling_bias，S2 T005 预留；RewardFlowSystem 同口径，M3 增）。
## - 权重语义（FR-015）：scale 选项按 target_id 查 ConfigManager.get_scale_tags，
##   命中的 tag 乘数连乘（多 tag 鳞片叠乘）；非 scale 选项（head/tail）恒 1.0
##   ——v1 bias 只偏置鳞片池（Designs §12.4 概率偏置语义）。
## - 重排 = 按权重不放回抽样（首位被高权项命中的概率按权重占比上移），输出是输入的置换：
##   消费方取前 offer_count 个即得偏置后的 offer。
## - 确定性：构造时注入 RNG 种子（game_world 按 run seed 派生）——同 weights + 同 seed
##   全等输出，定种子分布偏移可断言（SC-004）。
## - 无 class_name：消费方一律按路径 preload（ScriptingLeading C.8）。


## 构造偏置 Callable：收合格选项 Array → 返回加权重排后的 Array（contract 同 set_sampling_bias）
static func make_bias(scale_tag_weights: Dictionary, rng_seed: int) -> Callable:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var weights: Dictionary = scale_tag_weights.duplicate(true)
	return func(options: Array) -> Array:
		return weighted_reorder(options, weights, rng)


## 单选项权重：scale 选项 tag 乘数连乘（缺省 1.0），非 scale 恒 1.0
static func option_weight(option: Dictionary, scale_tag_weights: Dictionary) -> float:
	if str(option.get("reward_type", "")) != "scale":
		return 1.0
	var weight: float = 1.0
	for tag in ConfigManager.get_scale_tags(str(option.get("target_id", ""))):
		var multiplier: float = float(scale_tag_weights.get(str(tag), 1.0))
		if multiplier > 0.0:
			weight *= multiplier
	return weight


## 按权重不放回抽样重排（输出为输入的置换；权重和为 0 时按原序回退）
static func weighted_reorder(options: Array, scale_tag_weights: Dictionary,
		rng: RandomNumberGenerator) -> Array:
	var remaining: Array = []
	for option in options:
		remaining.append(option)
	var result: Array = []
	while not remaining.is_empty():
		var weights: Array = []
		var total: float = 0.0
		for option in remaining:
			var w: float = 1.0
			if option is Dictionary:
				w = option_weight(option, scale_tag_weights)
			weights.append(w)
			total += w
		var picked: int = remaining.size() - 1
		if total > 0.0:
			var roll: float = rng.randf() * total
			var acc: float = 0.0
			for i in range(remaining.size()):
				acc += weights[i]
				if roll < acc:
					picked = i
					break
		else:
			picked = 0
		result.append(remaining[picked])
		remaining.remove_at(picked)
	return result
