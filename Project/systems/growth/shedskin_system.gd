class_name ShedskinSystem
extends Node

var _amount: int = 0
var _total_earned: int = 0
var _total_spent: int = 0
var _floor_index: int = 0


func _ready() -> void:
	connect_events()


func _exit_tree() -> void:
	disconnect_events()


func connect_events() -> void:
	if not EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.connect(_on_enemy_killed)
	if not EventBus.floor_generated.is_connected(_on_floor_generated):
		EventBus.floor_generated.connect(_on_floor_generated)


func disconnect_events() -> void:
	if EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.disconnect(_on_enemy_killed)
	if EventBus.floor_generated.is_connected(_on_floor_generated):
		EventBus.floor_generated.disconnect(_on_floor_generated)


func get_amount() -> int:
	return _amount


func get_total_earned() -> int:
	return _total_earned


func get_total_spent() -> int:
	return _total_spent


func earn(amount: int, source: String) -> int:
	var cfg: Dictionary = ConfigManager.get_shedskin_config()
	var earned: int = amount
	_amount += earned
	_total_earned += earned
	EventBus.currency_changed.emit({
		"currency": "shedskin",
		"amount": earned,
		"total": _amount,
		"source": source,
	})
	return _amount


func spend(amount: int, item_id: String) -> bool:
	if amount <= 0 or amount > _amount:
		return false
	_amount -= amount
	_total_spent += amount
	EventBus.currency_changed.emit({
		"currency": "shedskin",
		"amount": -amount,
		"total": _amount,
		"source": "shop_purchase_%s" % item_id,
	})
	return true


func can_afford(price: int) -> bool:
	return _amount >= price


func cleanup() -> void:
	_amount = 0
	_total_earned = 0
	_total_spent = 0
	_floor_index = 0
	disconnect_events()


func _on_enemy_killed(data: Dictionary) -> void:
	var cfg: Dictionary = ConfigManager.get_shedskin_config()
	var enemy_type: String = ""
	var enemy_def = data.get("enemy_def")
	if enemy_def is Dictionary:
		enemy_type = enemy_def.get("enemy_type", "")
	elif enemy_def is String:
		enemy_type = enemy_def

	var amount: int = int(cfg.get("kill_normal", 1))
	if enemy_type == "elite" or enemy_type == "boss":
		amount = int(cfg.get("kill_elite", 3))
	earn(amount, "kill_%s" % enemy_type if enemy_type != "" else "kill")


func _on_floor_generated(data: Dictionary) -> void:
	_floor_index = int(data.get("floor_index", _floor_index + 1))
	_amount = 0
	_total_earned = 0
	_total_spent = 0
	EventBus.currency_changed.emit({
		"currency": "shedskin",
		"amount": 0,
		"total": 0,
		"source": "floor_transition",
	})