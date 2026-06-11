extends Node
## spec 003 M1（T003，判决：保留+补）：per-run 统计跟踪。
## - finalize_run(outcome) 是 `run_ended` 的唯一发射点（FR-013），once-guard 防双发射；
##   调用方 = RunProgressionSystem victory/death 双出口（T004）。
## - payload = spec FR-016 冻结契约：{outcome, run_id, floor_index, stats:{十字段}}；
##   run_id 自 run_started 缓存、floor_index 随 floor_generated 跟进；
##   草稿 stats.run_outcome 冗余已删（顶层 outcome 为准）。
## - 度量源补全：damage_taken = snake_hit_boundary + snake_body_attacked；
##   near_death_count = no_body_countdown_started；survival_low_length_ticks =
##   tick_post_process × 长度 < meta_growth.stats.low_length_threshold（JSON，FR-010）；
##   max_length = 长度事件峰值；duration_ticks = run 起算 tick 计数。
## - run_started 重置（FR-013）；finalize 后统计冻结（直到下个 run_started）。

var _stats: Dictionary = {}
var _run_id: String = ""
var _floor_index: int = 0
var _current_length: int = 0
var _finalized: bool = false


func _init() -> void:
	_stats = _zero_stats()


func _ready() -> void:
	connect_events()


func _exit_tree() -> void:
	disconnect_events()


func connect_events() -> void:
	if not EventBus.run_started.is_connected(_on_run_started):
		EventBus.run_started.connect(_on_run_started)
	if not EventBus.floor_generated.is_connected(_on_floor_generated):
		EventBus.floor_generated.connect(_on_floor_generated)
	if not EventBus.snake_turned.is_connected(_on_snake_turned):
		EventBus.snake_turned.connect(_on_snake_turned)
	if not EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.connect(_on_enemy_killed)
	if not EventBus.floor_completed.is_connected(_on_floor_completed):
		EventBus.floor_completed.connect(_on_floor_completed)
	if not EventBus.reaction_triggered.is_connected(_on_reaction_triggered):
		EventBus.reaction_triggered.connect(_on_reaction_triggered)
	if not EventBus.snake_hit_boundary.is_connected(_on_damage_taken):
		EventBus.snake_hit_boundary.connect(_on_damage_taken)
	if not EventBus.snake_body_attacked.is_connected(_on_damage_taken):
		EventBus.snake_body_attacked.connect(_on_damage_taken)
	if not EventBus.no_body_countdown_started.is_connected(_on_no_body_countdown_started):
		EventBus.no_body_countdown_started.connect(_on_no_body_countdown_started)
	if not EventBus.snake_length_increased.is_connected(_on_length_changed):
		EventBus.snake_length_increased.connect(_on_length_changed)
	if not EventBus.snake_length_decreased.is_connected(_on_length_changed):
		EventBus.snake_length_decreased.connect(_on_length_changed)
	if not EventBus.tick_post_process.is_connected(_on_tick_post_process):
		EventBus.tick_post_process.connect(_on_tick_post_process)


func disconnect_events() -> void:
	if EventBus.run_started.is_connected(_on_run_started):
		EventBus.run_started.disconnect(_on_run_started)
	if EventBus.floor_generated.is_connected(_on_floor_generated):
		EventBus.floor_generated.disconnect(_on_floor_generated)
	if EventBus.snake_turned.is_connected(_on_snake_turned):
		EventBus.snake_turned.disconnect(_on_snake_turned)
	if EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.disconnect(_on_enemy_killed)
	if EventBus.floor_completed.is_connected(_on_floor_completed):
		EventBus.floor_completed.disconnect(_on_floor_completed)
	if EventBus.reaction_triggered.is_connected(_on_reaction_triggered):
		EventBus.reaction_triggered.disconnect(_on_reaction_triggered)
	if EventBus.snake_hit_boundary.is_connected(_on_damage_taken):
		EventBus.snake_hit_boundary.disconnect(_on_damage_taken)
	if EventBus.snake_body_attacked.is_connected(_on_damage_taken):
		EventBus.snake_body_attacked.disconnect(_on_damage_taken)
	if EventBus.no_body_countdown_started.is_connected(_on_no_body_countdown_started):
		EventBus.no_body_countdown_started.disconnect(_on_no_body_countdown_started)
	if EventBus.snake_length_increased.is_connected(_on_length_changed):
		EventBus.snake_length_increased.disconnect(_on_length_changed)
	if EventBus.snake_length_decreased.is_connected(_on_length_changed):
		EventBus.snake_length_decreased.disconnect(_on_length_changed)
	if EventBus.tick_post_process.is_connected(_on_tick_post_process):
		EventBus.tick_post_process.disconnect(_on_tick_post_process)


func get_stats() -> Dictionary:
	return _stats.duplicate()


## `run_ended` 唯一发射点（FR-013）。once-guard：同一 run 第二次调用零发射，
## 返回已冻结的统计；下个 run_started 解除 guard。
func finalize_run(outcome: String) -> Dictionary:
	if _finalized:
		return _stats.duplicate()
	_finalized = true
	EventBus.run_ended.emit({
		"outcome": outcome,
		"run_id": _run_id,
		"floor_index": _floor_index,
		"stats": _stats.duplicate(),
	})
	return _stats.duplicate()


func reset() -> void:
	_stats = _zero_stats()
	_run_id = ""
	_floor_index = 0
	_current_length = 0
	_finalized = false


func cleanup() -> void:
	reset()
	disconnect_events()


func _zero_stats() -> Dictionary:
	return {
		"total_turns": 0,
		"total_kills": 0,
		"reaction_kills": 0,
		"near_death_count": 0,
		"survival_low_length_ticks": 0,
		"floors_completed": 0,
		"max_reaction_chain": 0,
		"damage_taken": 0,
		"max_length": 0,
		"duration_ticks": 0,
	}


func _low_length_threshold() -> int:
	return int(ConfigManager.get_meta_stats_config().get("low_length_threshold", 0))


func _on_run_started(data: Dictionary) -> void:
	reset()
	_run_id = str(data.get("run_id", ""))
	_floor_index = int(data.get("floor_index", 0))


func _on_floor_generated(data: Dictionary) -> void:
	if _finalized:
		return
	_floor_index = int(data.get("floor_index", _floor_index))


func _on_snake_turned(_data: Dictionary) -> void:
	if _finalized:
		return
	_stats["total_turns"] = int(_stats.get("total_turns", 0)) + 1


func _on_enemy_killed(data: Dictionary) -> void:
	if _finalized:
		return
	_stats["total_kills"] = int(_stats.get("total_kills", 0)) + 1
	var method: String = data.get("method", "")
	if method.find("reaction") >= 0:
		_stats["reaction_kills"] = int(_stats.get("reaction_kills", 0)) + 1


func _on_floor_completed(_data: Dictionary) -> void:
	if _finalized:
		return
	_stats["floors_completed"] = int(_stats.get("floors_completed", 0)) + 1


func _on_reaction_triggered(data: Dictionary) -> void:
	if _finalized:
		return
	var layer_a: int = int(data.get("layer_a", 0))
	var layer_b: int = int(data.get("layer_b", 0))
	var chain: int = layer_a + layer_b
	if chain > int(_stats.get("max_reaction_chain", 0)):
		_stats["max_reaction_chain"] = chain


func _on_damage_taken(_data: Dictionary) -> void:
	if _finalized:
		return
	_stats["damage_taken"] = int(_stats.get("damage_taken", 0)) + 1


func _on_no_body_countdown_started(_data: Dictionary) -> void:
	if _finalized:
		return
	_stats["near_death_count"] = int(_stats.get("near_death_count", 0)) + 1


func _on_length_changed(data: Dictionary) -> void:
	if _finalized:
		return
	_current_length = int(data.get("new_length", _current_length))
	if _current_length > int(_stats.get("max_length", 0)):
		_stats["max_length"] = _current_length


func _on_tick_post_process(_tick_index: int) -> void:
	if _finalized:
		return
	_stats["duration_ticks"] = int(_stats.get("duration_ticks", 0)) + 1
	if _current_length > 0 and _current_length < _low_length_threshold():
		_stats["survival_low_length_ticks"] = int(_stats.get("survival_low_length_ticks", 0)) + 1
