class_name CollisionHandler
extends Node

## 载体碰撞统一处理器（T27A）
## 替代 StatusTransferSystem、EnemyManager、Enemy._attack_segment 中的硬编码碰撞逻辑
## 根据 collision_rules JSON 配置决定碰撞行为

var reaction_resolver: Node = null  ## ReactionResolver
var tile_manager: StatusTileManager = null

var _collision_rules: Dictionary = {}

## 默认碰撞规则（fallback）
const DEFAULT_RULES: Dictionary = {
	"empty_carrier": "transfer",
	"same_type": "ignore",
	"diff_type": "add_and_check",
}


func _ready() -> void:
	_collision_rules = ConfigManager._data.get("collision_rules", {})


func handle_collision(collision_type: String, carrier_a: Object, carrier_b: Object) -> Dictionary:
	## 处理两个载体之间的碰撞，返回结果信息
	## carrier_a 是主动方（蛇段/敌人），carrier_b 是被动方（格子/敌人/段）
	var rules: Dictionary = _collision_rules.get(collision_type, DEFAULT_RULES)
	var statuses_a: Array = carrier_a.get_statuses() if carrier_a.has_method("get_statuses") else []
	var statuses_b: Array = carrier_b.get_statuses() if carrier_b.has_method("get_statuses") else []

	var result: Dictionary = {"action": "none", "reaction_id": ""}

	if statuses_a.is_empty() and statuses_b.is_empty():
		# 双方都无状态 → 无事发生
		return result

	if statuses_a.is_empty() and not statuses_b.is_empty():
		# A 无状态，B 有状态
		var action: String = rules.get("empty_carrier", "transfer")
		result = _execute_action(action, carrier_a, carrier_b, statuses_b[0], collision_type)
	elif not statuses_a.is_empty() and statuses_b.is_empty():
		# A 有状态，B 无状态
		var action: String = rules.get("empty_carrier", "transfer")
		result = _execute_action(action, carrier_b, carrier_a, statuses_a[0], collision_type)
	else:
		# 双方都有状态
		if statuses_a[0] == statuses_b[0]:
			var action: String = rules.get("same_type", "ignore")
			result = _execute_action_same(action, carrier_a, carrier_b, statuses_a[0])
		else:
			var action: String = rules.get("diff_type", "add_and_check")
			result = _execute_action_diff(action, carrier_a, carrier_b, statuses_a[0], statuses_b[0], collision_type)

	return result


func _execute_action(action: String, receiver: Object, source: Object, status_type: String, _collision_type: String) -> Dictionary:
	## 处理 empty_carrier 情况：将 status_type 转移给 receiver
	var result: Dictionary = {"action": action, "reaction_id": ""}
	match action:
		"transfer":
			_transfer_status(receiver, status_type)
		"place":
			_transfer_status(receiver, status_type)
		"ignore":
			pass
	return result


func _execute_action_same(action: String, carrier_a: Object, carrier_b: Object, _status_type: String) -> Dictionary:
	## 同类状态碰撞
	var result: Dictionary = {"action": action, "reaction_id": ""}
	match action:
		"ignore":
			pass
		"swap":
			# enemy_hit_segment 同类时交换（实际上同类交换无变化，但保留语义）
			pass
	return result


func _execute_action_diff(action: String, carrier_a: Object, carrier_b: Object, type_a: String, type_b: String, collision_type: String) -> Dictionary:
	## 异类状态碰撞
	var result: Dictionary = {"action": action, "reaction_id": ""}
	match action:
		"add_and_check":
			# 触发反应，双方状态清除
			var reaction_id: String = ""
			if reaction_resolver:
				reaction_id = reaction_resolver.find_reaction(type_a, type_b)
			if reaction_id != "":
				# 获取反应位置（优先使用有 grid_position 的载体）
				var pos: Vector2i = _get_position(carrier_a, carrier_b)
				EventBus.reaction_triggered.emit({
					"reaction_id": reaction_id,
					"position": pos,
					"type_a": type_a,
					"type_b": type_b,
				})
			# 清除双方状态
			_clear_carrier(carrier_a)
			_clear_carrier(carrier_b)
			# 如果 carrier_b 是状态格，还需从 tile_manager 移除
			if tile_manager and carrier_b.has_method("get_carrier_type") and carrier_b.get_carrier_type() == "status_tile":
				var tile_pos: Vector2i = carrier_b.grid_position
				var tile_type: String = type_b
				tile_manager.remove_tile(tile_pos, tile_type)
			result["reaction_id"] = reaction_id
	return result


func _transfer_status(receiver: Object, status_type: String) -> void:
	## 将状态转移给接收方
	if receiver.has_method("set_carried_status"):
		receiver.set_carried_status(status_type)
	elif receiver.has_method("add_status"):
		receiver.add_status(status_type)


func _clear_carrier(carrier: Object) -> void:
	## 清除载体状态
	if carrier.has_method("clear_carried_status"):
		carrier.clear_carried_status()
	elif carrier.has_method("clear_all_statuses"):
		carrier.clear_all_statuses()


func _get_position(carrier_a: Object, carrier_b: Object) -> Vector2i:
	if "grid_position" in carrier_a:
		return carrier_a.grid_position
	if "grid_position" in carrier_b:
		return carrier_b.grid_position
	return Vector2i.ZERO
