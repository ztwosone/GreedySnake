class_name ReactionSystem
extends Node

## 状态反应执行系统（重写版）
## 监听 reaction_triggered 信号，执行反应效果：
## - steam (火+冰): AoE 伤敌 + 蛇受击
## - toxic_explosion (火+毒): 高 AoE 伤敌 + 蛇受击
## - frozen_plague (冰+毒): 冻结+中毒敌人，蛇无伤害

var tile_manager: StatusTileManager = null


func _ready() -> void:
	EventBus.reaction_triggered.connect(_on_reaction_triggered)


func _on_reaction_triggered(data: Dictionary) -> void:
	var reaction_id: String = data.get("reaction_id", "")
	var pos: Vector2i = data.get("position", Vector2i(0, 0))
	if reaction_id == "":
		return

	var reaction_cfg: Dictionary = ConfigManager.get_reaction(reaction_id)
	if reaction_cfg.is_empty():
		return

	var radius: int = int(reaction_cfg.get("radius", 3))
	var enemy_damage: int = int(reaction_cfg.get("enemy_damage", 1))
	var self_hit_count: int = int(reaction_cfg.get("self_hit_count", 0))

	# AoE 伤害范围内敌人
	_damage_enemies_in_radius(pos, radius, enemy_damage)

	# 对蛇造成受击
	if self_hit_count > 0:
		_hit_snake_in_radius(pos, radius, self_hit_count)

	# 冻疫特殊效果：范围内敌人获得 ice + poison
	if reaction_id == "frozen_plague":
		_apply_status_to_enemies_in_radius(pos, radius, "ice")
		_apply_status_to_enemies_in_radius(pos, radius, "poison")


func _damage_enemies_in_radius(center: Vector2i, radius: int, damage: int) -> void:
	if damage <= 0:
		return
	for x in range(center.x - radius, center.x + radius + 1):
		for y in range(center.y - radius, center.y + radius + 1):
			var check_pos := Vector2i(x, y)
			var dist: int = abs(x - center.x) + abs(y - center.y)
			if dist > radius:
				continue
			if not GridWorld.is_within_bounds(check_pos):
				continue
			var entities: Array = GridWorld.get_entities_at(check_pos)
			for e in entities:
				if e is Enemy and is_instance_valid(e) and e.hp > 0:
					e.take_damage(damage)


func _hit_snake_in_radius(center: Vector2i, radius: int, hit_count: int) -> void:
	# 找蛇节点
	for pos in GridWorld.cell_map:
		var entities: Array = GridWorld.cell_map[pos]
		for e in entities:
			if not is_instance_valid(e):
				continue
			if e is SnakeSegment and e.segment_type == SnakeSegment.HEAD:
				var snake_node: Snake = e.get_parent() as Snake
				if snake_node and snake_node.is_alive:
					# 检查蛇是否有段在范围内
					var segs: Array = snake_node.get_segments_in_radius(center, radius)
					if not segs.is_empty():
						for i in range(hit_count):
							snake_node.take_hit(1)
				return


func _apply_status_to_enemies_in_radius(center: Vector2i, radius: int, status_type: String) -> void:
	for x in range(center.x - radius, center.x + radius + 1):
		for y in range(center.y - radius, center.y + radius + 1):
			var check_pos := Vector2i(x, y)
			var dist: int = abs(x - center.x) + abs(y - center.y)
			if dist > radius:
				continue
			if not GridWorld.is_within_bounds(check_pos):
				continue
			var entities: Array = GridWorld.get_entities_at(check_pos)
			for e in entities:
				if e is Enemy and is_instance_valid(e) and e.hp > 0:
					StatusEffectManager.apply_status(e, status_type, "reaction")
