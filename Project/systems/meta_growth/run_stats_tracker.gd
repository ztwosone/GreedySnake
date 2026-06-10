class_name RunStatsTracker
extends Node

var _stats: Dictionary = {
	"total_turns": 0,
	"total_kills": 0,
	"reaction_kills": 0,
	"survival_low_length_ticks": 0,
	"floors_completed": 0,
	"near_death_count": 0,
	"max_reaction_chain": 0,
	"damage_taken": 0,
	"run_outcome": "",
}


func _ready() -> void:
	connect_events()


func _exit_tree() -> void:
	disconnect_events()


func connect_events() -> void:
	if not EventBus.snake_turned.is_connected(_on_snake_turned):
		EventBus.snake_turned.connect(_on_snake_turned)
	if not EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.connect(_on_enemy_killed)
	if not EventBus.floor_completed.is_connected(_on_floor_completed):
		EventBus.floor_completed.connect(_on_floor_completed)
	if not EventBus.reaction_triggered.is_connected(_on_reaction_triggered):
		EventBus.reaction_triggered.connect(_on_reaction_triggered)
	if not EventBus.snake_hit_boundary.is_connected(_on_hit_boundary):
		EventBus.snake_hit_boundary.connect(_on_hit_boundary)


func disconnect_events() -> void:
	if EventBus.snake_turned.is_connected(_on_snake_turned):
		EventBus.snake_turned.disconnect(_on_snake_turned)
	if EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.disconnect(_on_enemy_killed)
	if EventBus.floor_completed.is_connected(_on_floor_completed):
		EventBus.floor_completed.disconnect(_on_floor_completed)
	if EventBus.reaction_triggered.is_connected(_on_reaction_triggered):
		EventBus.reaction_triggered.disconnect(_on_reaction_triggered)
	if EventBus.snake_hit_boundary.is_connected(_on_hit_boundary):
		EventBus.snake_hit_boundary.disconnect(_on_hit_boundary)


func get_stats() -> Dictionary:
	return _stats.duplicate()


func finalize_run(outcome: String) -> Dictionary:
	_stats["run_outcome"] = outcome
	EventBus.run_ended.emit({
		"outcome": outcome,
		"stats": _stats.duplicate(),
	})
	return _stats.duplicate()


func reset() -> void:
	_stats = {
		"total_turns": 0,
		"total_kills": 0,
		"reaction_kills": 0,
		"survival_low_length_ticks": 0,
		"floors_completed": 0,
		"near_death_count": 0,
		"max_reaction_chain": 0,
		"damage_taken": 0,
		"run_outcome": "",
	}


func cleanup() -> void:
	reset()
	disconnect_events()


func _on_snake_turned(data: Dictionary) -> void:
	_stats["total_turns"] = int(_stats.get("total_turns", 0)) + 1


func _on_enemy_killed(data: Dictionary) -> void:
	_stats["total_kills"] = int(_stats.get("total_kills", 0)) + 1
	var method: String = data.get("method", "")
	if method.find("reaction") >= 0:
		_stats["reaction_kills"] = int(_stats.get("reaction_kills", 0)) + 1


func _on_floor_completed(data: Dictionary) -> void:
	_stats["floors_completed"] = int(_stats.get("floors_completed", 0)) + 1


func _on_reaction_triggered(data: Dictionary) -> void:
	var layer_a: int = int(data.get("layer_a", 0))
	var layer_b: int = int(data.get("layer_b", 0))
	var chain: int = layer_a + layer_b
	if chain > int(_stats.get("max_reaction_chain", 0)):
		_stats["max_reaction_chain"] = chain


func _on_hit_boundary(data: Dictionary) -> void:
	_stats["damage_taken"] = int(_stats.get("damage_taken", 0)) + 1