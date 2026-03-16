class_name CrushSystem
extends Node

## 蛇身碾压系统
## 蛇移动后，检查蛇身（不含蛇头）是否与敌人重叠，触发碾压判定

var snake: Snake = null


func _ready() -> void:
	EventBus.snake_moved.connect(_on_snake_moved)


func _on_snake_moved(_data: Dictionary) -> void:
	if snake == null or not snake.is_alive:
		return
	# 同一 tick 同一敌人只被碾压一次
	var crushed_enemies: Array = []

	# 遍历蛇身段（跳过蛇头 index 0）
	for i in range(1, snake.body.size()):
		var seg_pos: Vector2i = snake.body[i]
		var entities: Array = GridWorld.get_entities_at(seg_pos)
		for entity in entities:
			if entity is Enemy and is_instance_valid(entity) and entity not in crushed_enemies:
				_execute_crush(entity, i)
				crushed_enemies.append(entity)


func _execute_crush(enemy: Enemy, segment_index: int) -> void:
	var cost: int = enemy.attack_cost if enemy.attack_cost else 1

	# 碾压消耗长度
	EventBus.length_decrease_requested.emit({
		"amount": cost,
		"source": "crush",
	})

	# 状态转移：蛇身带的状态附加给敌人
	_transfer_status_on_crush(enemy)

	# 对敌人造成伤害
	enemy.take_damage(1)

	# 发射碾压信号
	EventBus.snake_body_crush.emit({
		"enemy": enemy,
		"position": enemy.grid_position,
		"segment_index": segment_index,
		"cost": cost,
		"status_transferred": _get_snake_status_types(),
	})


func _transfer_status_on_crush(enemy: Enemy) -> void:
	## 将蛇身上的状态施加给敌人
	var sem = Engine.get_main_loop().root.get_node_or_null("StatusEffectManager")
	if sem == null or snake == null:
		return
	var statuses: Array = sem.get_statuses(snake)
	for effect in statuses:
		sem.apply_status(enemy, effect.type, "crush")


func _get_snake_status_types() -> Array:
	var sem = Engine.get_main_loop().root.get_node_or_null("StatusEffectManager")
	if sem == null or snake == null:
		return []
	var result: Array = []
	var statuses: Array = sem.get_statuses(snake)
	for effect in statuses:
		result.append(effect.type)
	return result
