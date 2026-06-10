class_name DifficultyScaler
extends Node
## 难度缩放器（spec 002 T030 重写，2026-06-11 重验收）。FR-008 两层结构：
## - 静态层（MUST，玩家可感）：difficulty.floor_table 层表 → 敌人数 delta
##   （floor_table[层].enemy_count - baseline_enemy_count）+ enemy_hp_bonus；
##   楼层号经 floor_generated 事件跟踪（FR-011 EventBus-only）。
## - 反应式层（SHOULD，设计不可见——Designs §11.5「对玩家不可见」，验证只允许
##   生成参数级断言）：单房口径度量（草稿 :114 把全局累计 tick 当单房用时已修）——
##   room_entered 记起算 tick / room_completed 计差；命中源 = snake_body_attacked +
##   snake_hit_boundary；状态源 = reaction_triggered + status_added_to_carrier
##   (carrier_type=="enemy")；每 rooms_between_adjustments 房按 metrics 权重重算分数
##   （归一化分母全部出自 difficulty.reactive.normalization，草稿 :93 硬编码已修），
##   过强 → 敌 +/食 -，过弱 → 敌 -/食 +，幅度 = adjustment_*_delta 并钳入
##   difficulty.reactive.clamp；reactive.enabled = false 整层归零（砍单阶梯首位）。
## - difficulty.enabled 总开关 false → 全部 delta 归零（调试用）。
## - run_started 重置全部状态（FR-013）。
## 唯一消费者 = RoomDirector（duck-typed 钩子 get_enemy_count_delta /
## get_food_count_delta / get_enemy_hp_bonus；契约见 plan.md「重验收策略」）。
## 注意：食物的静态层基数由 RoomDirector 直接读 floor_table[层].food_count，
## 因此 get_food_count_delta() 只含反应式分量（避免双重计入）。

const NEUTRAL_SCORE: float = 0.5

var _floor_index: int = 1
var _score: float = NEUTRAL_SCORE
var _room_active: bool = false
var _room_start_tick: int = 0
var _room_hits: int = 0
var _room_status_usage: int = 0
var _window: Array = []
var _last_room_metrics: Dictionary = {}


func _ready() -> void:
	connect_events()


func _exit_tree() -> void:
	disconnect_events()


func connect_events() -> void:
	if not EventBus.run_started.is_connected(_on_run_started):
		EventBus.run_started.connect(_on_run_started)
	if not EventBus.floor_generated.is_connected(_on_floor_generated):
		EventBus.floor_generated.connect(_on_floor_generated)
	if not EventBus.room_entered.is_connected(_on_room_entered):
		EventBus.room_entered.connect(_on_room_entered)
	if not EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.connect(_on_room_completed)
	if not EventBus.snake_body_attacked.is_connected(_on_snake_body_attacked):
		EventBus.snake_body_attacked.connect(_on_snake_body_attacked)
	if not EventBus.snake_hit_boundary.is_connected(_on_snake_hit_boundary):
		EventBus.snake_hit_boundary.connect(_on_snake_hit_boundary)
	if not EventBus.reaction_triggered.is_connected(_on_reaction_triggered):
		EventBus.reaction_triggered.connect(_on_reaction_triggered)
	if not EventBus.status_added_to_carrier.is_connected(_on_status_added_to_carrier):
		EventBus.status_added_to_carrier.connect(_on_status_added_to_carrier)


func disconnect_events() -> void:
	if EventBus.run_started.is_connected(_on_run_started):
		EventBus.run_started.disconnect(_on_run_started)
	if EventBus.floor_generated.is_connected(_on_floor_generated):
		EventBus.floor_generated.disconnect(_on_floor_generated)
	if EventBus.room_entered.is_connected(_on_room_entered):
		EventBus.room_entered.disconnect(_on_room_entered)
	if EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.disconnect(_on_room_completed)
	if EventBus.snake_body_attacked.is_connected(_on_snake_body_attacked):
		EventBus.snake_body_attacked.disconnect(_on_snake_body_attacked)
	if EventBus.snake_hit_boundary.is_connected(_on_snake_hit_boundary):
		EventBus.snake_hit_boundary.disconnect(_on_snake_hit_boundary)
	if EventBus.reaction_triggered.is_connected(_on_reaction_triggered):
		EventBus.reaction_triggered.disconnect(_on_reaction_triggered)
	if EventBus.status_added_to_carrier.is_connected(_on_status_added_to_carrier):
		EventBus.status_added_to_carrier.disconnect(_on_status_added_to_carrier)


func cleanup() -> void:
	_reset_state()
	disconnect_events()


# ═══ RoomDirector 消费钩子（唯一消费者契约） ═══════════════════════════════════

func get_enemy_count_delta() -> int:
	## 敌人数总修正 = 静态层 + 反应式层（总开关 off → 0）
	if not _is_enabled():
		return 0
	return get_static_enemy_delta() + get_reactive_enemy_delta()


func get_food_count_delta() -> int:
	## 食物数修正 = 反应式层（静态基数由 RoomDirector 直接读 floor_table.food_count）
	if not _is_enabled():
		return 0
	return get_reactive_food_delta()


func get_enemy_hp_bonus() -> int:
	## 静态层 HP 压力：floor_table[层].enemy_hp_bonus（落点 EnemyManager.spawn_hp_bonus）
	if not _is_enabled():
		return 0
	return maxi(0, int(ConfigManager.get_difficulty_floor_params(_floor_index).get("enemy_hp_bonus", 0)))


# ═══ 分层读数（测试/调试介观接口） ════════════════════════════════════════════

func get_static_enemy_delta() -> int:
	var cfg: Dictionary = ConfigManager.get_difficulty_config()
	var floor_params: Dictionary = ConfigManager.get_difficulty_floor_params(_floor_index)
	return int(floor_params.get("enemy_count", 0)) - int(cfg.get("baseline_enemy_count", 0))


func get_reactive_enemy_delta() -> int:
	if not _is_reactive_enabled():
		return 0
	var cfg: Dictionary = ConfigManager.get_difficulty_config()
	var clamp_cfg: Dictionary = _reactive_clamp()
	var delta: int = 0
	if _score > float(cfg.get("overperform_threshold", 1.0)):
		delta = int(cfg.get("adjustment_enemy_delta", 0))
	elif _score < float(cfg.get("underperform_threshold", 0.0)):
		delta = -int(cfg.get("adjustment_enemy_delta", 0))
	return clampi(delta, int(clamp_cfg.get("enemy_delta_min", 0)), int(clamp_cfg.get("enemy_delta_max", 0)))


func get_reactive_food_delta() -> int:
	if not _is_reactive_enabled():
		return 0
	var cfg: Dictionary = ConfigManager.get_difficulty_config()
	var clamp_cfg: Dictionary = _reactive_clamp()
	var delta: int = 0
	if _score > float(cfg.get("overperform_threshold", 1.0)):
		delta = -int(cfg.get("adjustment_food_delta", 0))
	elif _score < float(cfg.get("underperform_threshold", 0.0)):
		delta = int(cfg.get("adjustment_food_delta", 0))
	return clampi(delta, int(clamp_cfg.get("food_delta_min", 0)), int(clamp_cfg.get("food_delta_max", 0)))


func get_score() -> float:
	return _score


func get_last_room_metrics() -> Dictionary:
	return _last_room_metrics.duplicate(true)


# ═══ 事件度量（单房口径） ═════════════════════════════════════════════════════

func _on_run_started(_data: Dictionary) -> void:
	_reset_state()


func _on_floor_generated(data: Dictionary) -> void:
	_floor_index = int(data.get("floor_index", _floor_index))


func _on_room_entered(data: Dictionary) -> void:
	if str(data.get("room_id", "")) == "":
		return
	_room_active = true
	_room_start_tick = TickManager.current_tick
	_room_hits = 0
	_room_status_usage = 0


func _on_room_completed(data: Dictionary) -> void:
	if not _room_active:
		return
	_room_active = false
	_last_room_metrics = {
		"room_id": str(data.get("room_id", "")),
		"clear_ticks": maxi(0, TickManager.current_tick - _room_start_tick),
		"hits_taken": _room_hits,
		"status_usage": _room_status_usage,
	}
	_window.append(_last_room_metrics.duplicate(true))

	var rooms_between: int = int(ConfigManager.get_difficulty_config().get("rooms_between_adjustments", 2))
	if _window.size() >= maxi(1, rooms_between):
		_recalculate_score()
		_window.clear()


func _on_snake_body_attacked(_data: Dictionary) -> void:
	if _room_active:
		_room_hits += 1


func _on_snake_hit_boundary(_data: Dictionary) -> void:
	if _room_active:
		_room_hits += 1


func _on_reaction_triggered(_data: Dictionary) -> void:
	if _room_active:
		_room_status_usage += 1


func _on_status_added_to_carrier(data: Dictionary) -> void:
	if _room_active and str(data.get("carrier_type", "")) == "enemy":
		_room_status_usage += 1


# ═══ 内部 ════════════════════════════════════════════════════════════════════

func _recalculate_score() -> void:
	var cfg: Dictionary = ConfigManager.get_difficulty_config()
	var normalization: Dictionary = ConfigManager.get_difficulty_reactive_config().get("normalization", {})
	var rooms: int = maxi(1, _window.size())

	var total_ticks: float = 0.0
	var total_hits: float = 0.0
	var total_status: float = 0.0
	for metrics in _window:
		total_ticks += float(metrics.get("clear_ticks", 0))
		total_hits += float(metrics.get("hits_taken", 0))
		total_status += float(metrics.get("status_usage", 0))

	var norm_ticks: float = maxf(1.0, float(normalization.get("room_clear_ticks", 1)))
	var norm_hits: float = maxf(1.0, float(normalization.get("damage_taken_per_room", 1)))
	var norm_status: float = maxf(1.0, float(normalization.get("status_usage_per_room", 1)))

	var ticks_credit: float = clampf(1.0 - (total_ticks / rooms) / norm_ticks, 0.0, 1.0)
	var hits_credit: float = clampf(1.0 - (total_hits / rooms) / norm_hits, 0.0, 1.0)
	var status_credit: float = clampf((total_status / rooms) / norm_status, 0.0, 1.0)

	var weights: Dictionary = cfg.get("metrics", {})
	_score = ticks_credit * float(weights.get("clear_speed_weight", 0.0)) \
		+ hits_credit * float(weights.get("damage_taken_weight", 0.0)) \
		+ status_credit * float(weights.get("status_usage_weight", 0.0))

	EventBus.difficulty_adjusted.emit({
		"reason": "recalculation",
		"adjustment": {
			"score": _score,
			"floor_index": _floor_index,
			"enemy_delta": get_enemy_count_delta(),
			"food_delta": get_food_count_delta(),
			"reactive_enemy_delta": get_reactive_enemy_delta(),
			"reactive_food_delta": get_reactive_food_delta(),
		},
	})


func _reset_state() -> void:
	_floor_index = 1
	_score = NEUTRAL_SCORE
	_room_active = false
	_room_start_tick = 0
	_room_hits = 0
	_room_status_usage = 0
	_window.clear()
	_last_room_metrics = {}


func _is_enabled() -> bool:
	return bool(ConfigManager.get_difficulty_config().get("enabled", false))


func _is_reactive_enabled() -> bool:
	if not _is_enabled():
		return false
	return bool(ConfigManager.get_difficulty_reactive_config().get("enabled", false))


func _reactive_clamp() -> Dictionary:
	return ConfigManager.get_difficulty_reactive_config().get("clamp", {})
