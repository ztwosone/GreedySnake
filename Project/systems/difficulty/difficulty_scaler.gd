class_name DifficultyScaler
extends Node

var _score: float = 0.5
var _rooms_since_adjust: int = 0
var _metrics: Dictionary = {
	"total_clear_ticks": 0,
	"total_hits_taken": 0,
	"total_status_actions": 0,
	"rooms_completed": 0,
}


func _ready() -> void:
	connect_events()


func _exit_tree() -> void:
	disconnect_events()


func connect_events() -> void:
	if not EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.connect(_on_room_completed)
	if not EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.connect(_on_enemy_killed)


func disconnect_events() -> void:
	if EventBus.room_completed.is_connected(_on_room_completed):
		EventBus.room_completed.disconnect(_on_room_completed)
	if EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.disconnect(_on_enemy_killed)


func get_score() -> float:
	return _score


func get_enemy_count_delta() -> int:
	var cfg: Dictionary = ConfigManager.get_difficulty_config()
	var baseline: int = int(cfg.get("baseline_enemy_count", 3))
	if _score > float(cfg.get("overperform_threshold", 0.7)):
		return int(cfg.get("adjustment_enemy_delta", 1))
	if _score < float(cfg.get("underperform_threshold", 0.3)):
		return -int(cfg.get("adjustment_enemy_delta", 1))
	return 0


func get_food_count_delta() -> int:
	var cfg: Dictionary = ConfigManager.get_difficulty_config()
	if _score > float(cfg.get("overperform_threshold", 0.7)):
		return -int(cfg.get("adjustment_food_delta", 1))
	if _score < float(cfg.get("underperform_threshold", 0.3)):
		return int(cfg.get("adjustment_food_delta", 1))
	return 0


func record_room_completion(clear_ticks: int, hits_taken: int, status_actions: int) -> void:
	var cfg: Dictionary = ConfigManager.get_difficulty_config()
	_metrics["total_clear_ticks"] += clear_ticks
	_metrics["total_hits_taken"] += hits_taken
	_metrics["total_status_actions"] += status_actions
	_metrics["rooms_completed"] += 1
	_rooms_since_adjust += 1

	var rooms_between: int = int(cfg.get("rooms_between_adjustments", 2))
	if _rooms_since_adjust >= rooms_between:
		_recalculate_score()
		_rooms_since_adjust = 0


func cleanup() -> void:
	_score = 0.5
	_rooms_since_adjust = 0
	_metrics = {
		"total_clear_ticks": 0,
		"total_hits_taken": 0,
		"total_status_actions": 0,
		"rooms_completed": 0,
	}
	disconnect_events()


func _recalculate_score() -> void:
	var cfg: Dictionary = ConfigManager.get_difficulty_config()
	var rooms: int = max(1, _metrics.get("rooms_completed", 1))

	var avg_ticks: float = float(_metrics.get("total_clear_ticks", 0)) / rooms
	var avg_hits: float = float(_metrics.get("total_hits_taken", 0)) / rooms
	var avg_status: float = float(_metrics.get("total_status_actions", 0)) / rooms

	var norm_ticks: float = max(0.0, min(1.0, 1.0 - avg_ticks / 100.0))
	var norm_hits: float = max(0.0, min(1.0, 1.0 - avg_hits / 10.0))
	var norm_status: float = max(0.0, min(1.0, avg_status / 5.0))

	var weights: Dictionary = cfg.get("metrics", {})
	var w_ticks: float = float(weights.get("clear_speed_weight", 0.4))
	var w_hits: float = float(weights.get("damage_taken_weight", 0.3))
	var w_status: float = float(weights.get("status_usage_weight", 0.3))

	_score = norm_ticks * w_ticks + norm_hits * w_hits + norm_status * w_status

	EventBus.difficulty_adjusted.emit({
		"reason": "recalculation",
		"adjustment": {
			"score": _score,
			"enemy_delta": get_enemy_count_delta(),
			"food_delta": get_food_count_delta(),
		},
	})


func _on_room_completed(data: Dictionary) -> void:
	record_room_completion(
		TickManager.current_tick,
		0,
		0
	)


func _on_enemy_killed(data: Dictionary) -> void:
	pass