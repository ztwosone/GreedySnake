extends RefCounted
## 人类时序模型
## 模拟反应时间、按键时长等人类输入特征


var reaction_time_ms: float = 200.0
var reaction_variance_ms: float = 50.0
var decision_interval_ms: float = 250.0
var key_press_duration_ms: float = 80.0
var deterministic: bool = false

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func set_deterministic(seed_value: int = 0) -> void:
	deterministic = true
	reaction_time_ms = 0.0
	reaction_variance_ms = 0.0
	key_press_duration_ms = 0.0
	_rng.seed = seed_value


func get_reaction_delay_sec() -> float:
	if deterministic:
		return 0.0
	var delay_ms: float = reaction_time_ms + _rng.randfn(0.0, reaction_variance_ms)
	return maxf(0.0, delay_ms) / 1000.0


func get_key_press_duration_sec() -> float:
	if deterministic:
		return 0.0
	return key_press_duration_ms / 1000.0


func should_decide_this_frame(delta_accumulator: float) -> bool:
	if deterministic:
		return true
	return delta_accumulator >= decision_interval_ms / 1000.0
