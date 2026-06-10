class_name ShedskinSystem
extends Node
## 蜕皮货币系统（spec 002 T006 验证修复，2026-06-11 修订版 spec）
## FR-002/FR-003：run 内贯通账本——跨层保留（floor_generated 不再清零，Designs §10.2），
## 仅 run 重启清零（FR-013，监听 run_started）。
## 收入源：击杀（普通/精英分型——enemy_def 是 Enemy 节点，草稿 :87 把节点当 Dictionary
## 判型导致精英分支死代码，现走 ConfigManager enemy_types 的 is_elite）、
## 鳞片放弃补偿（消费 scale_option_discarded.shedskin_gained，发射方 ScaleRewardSystem）。

var _amount: int = 0
var _total_earned: int = 0
var _total_spent: int = 0


func _ready() -> void:
	connect_events()


func _exit_tree() -> void:
	disconnect_events()


func connect_events() -> void:
	if not EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.connect(_on_enemy_killed)
	if not EventBus.scale_option_discarded.is_connected(_on_scale_option_discarded):
		EventBus.scale_option_discarded.connect(_on_scale_option_discarded)
	if not EventBus.run_started.is_connected(_on_run_started):
		EventBus.run_started.connect(_on_run_started)


func disconnect_events() -> void:
	if EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.disconnect(_on_enemy_killed)
	if EventBus.scale_option_discarded.is_connected(_on_scale_option_discarded):
		EventBus.scale_option_discarded.disconnect(_on_scale_option_discarded)
	if EventBus.run_started.is_connected(_on_run_started):
		EventBus.run_started.disconnect(_on_run_started)


func get_amount() -> int:
	return _amount


func get_total_earned() -> int:
	return _total_earned


func get_total_spent() -> int:
	return _total_spent


func earn(amount: int, source: String) -> int:
	if amount <= 0:
		return _amount
	_amount += amount
	_total_earned += amount
	EventBus.currency_changed.emit({
		"currency": "shedskin",
		"amount": amount,
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


## FR-013：run 重启清零（带事件，HUD 可观测）；跨层不走此路径
func reset(source: String = "run_reset") -> void:
	if _amount == 0 and _total_earned == 0 and _total_spent == 0:
		return
	_amount = 0
	_total_earned = 0
	_total_spent = 0
	EventBus.currency_changed.emit({
		"currency": "shedskin",
		"amount": 0,
		"total": 0,
		"source": source,
	})


func cleanup() -> void:
	_amount = 0
	_total_earned = 0
	_total_spent = 0
	disconnect_events()


func _on_enemy_killed(data: Dictionary) -> void:
	var enemy_type: String = _resolve_enemy_type(data.get("enemy_def"))
	var cfg: Dictionary = ConfigManager.get_shedskin_config()
	var amount: int = int(cfg.get("kill_normal", 0))
	if bool(ConfigManager.get_enemy_type(enemy_type).get("is_elite", false)):
		amount = int(cfg.get("kill_elite", 0))
	var source: String = ("kill_%s" % enemy_type) if enemy_type != "" else "kill"
	earn(amount, source)


## enemy_killed 的 enemy_def 是 Enemy 节点（兼容 String/Dictionary 形态的测试 payload）
func _resolve_enemy_type(enemy_def: Variant) -> String:
	if enemy_def is String:
		return enemy_def
	if enemy_def is Dictionary:
		return str(enemy_def.get("enemy_type", ""))
	if enemy_def is Object and is_instance_valid(enemy_def) and "enemy_type" in enemy_def:
		return str(enemy_def.enemy_type)
	return ""


func _on_scale_option_discarded(data: Dictionary) -> void:
	earn(int(data.get("shedskin_gained", 0)), "scale_discard")


func _on_run_started(_data: Dictionary) -> void:
	reset("run_reset")
