class_name SegmentEffectSystem
extends Node

## 蛇段状态增益系统
## 火：光环伤敌（tick 时检测火段周围敌人）
## 毒：尾迹（蛇移动时检查离开的尾段是否有毒状态）
## 冰：防御效果在 Enemy._attack_segment 中处理

var snake: Snake = null
var enemy_manager: EnemyManager = null
var tile_manager: StatusTileManager = null

var _aura_damage: int = 1
var _trail_counter: int = 0
var _trail_interval: int = 3


func _ready() -> void:
	EventBus.tick_post_process.connect(_on_tick_post_process)
	EventBus.snake_moved.connect(_on_snake_moved)
	# 从 config 读取火光环伤害
	var fire_cfg: Dictionary = ConfigManager.get_status_effect("fire")
	_aura_damage = int(fire_cfg.get("aura_damage", 1))
	# 从 config 读取毒尾迹间隔
	var poison_cfg: Dictionary = ConfigManager.get_status_effect("poison")
	_trail_interval = int(poison_cfg.get("trail_interval", 3))


func _on_tick_post_process(_tick_index: int) -> void:
	if snake == null or enemy_manager == null:
		return
	_process_fire_aura()


func _process_fire_aura() -> void:
	## 火光环：火段四邻格有敌人则造成伤害
	for seg in snake.segments:
		if not is_instance_valid(seg):
			continue
		if seg.carried_status != "fire":
			continue
		var pos: Vector2i = seg.grid_position
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var adj: Vector2i = pos + dir
			var entities: Array = GridWorld.get_entities_at(adj)
			for e in entities:
				if is_instance_valid(e) and e is Enemy and e.hp > 0:
					e.take_damage(_aura_damage)


func _on_snake_moved(data: Dictionary) -> void:
	if snake == null or tile_manager == null:
		return
	_process_poison_trail(data)


func _process_poison_trail(data: Dictionary) -> void:
	## 毒尾迹：蛇移动时，如果被移除的旧尾段携带毒状态，按间隔留毒格
	var vacated_pos: Vector2i = data.get("vacated_pos", Vector2i(-1, -1))
	if vacated_pos == Vector2i(-1, -1):
		return  # 蛇在生长，没有离开的格子

	var vacated_status: String = data.get("vacated_status", "")
	if vacated_status != "poison":
		# 旧尾段没有毒，不留尾迹（但重置计数器）
		return

	_trail_counter += 1
	if _trail_counter >= _trail_interval:
		_trail_counter = 0
		tile_manager.place_tile(vacated_pos, "poison")
