class_name ReactionVFX
extends Node2D

## 反应视觉效果：监听 reaction_triggered 信号，在反应位置创建闪光淡出效果


func _ready() -> void:
	EventBus.reaction_triggered.connect(_on_reaction_triggered)


func _on_reaction_triggered(data: Dictionary) -> void:
	var reaction_id: String = data.get("reaction_id", "")
	var pos: Vector2i = data.get("position", Vector2i.ZERO)

	var reaction_cfg: Dictionary = ConfigManager.get_reaction(reaction_id)
	if reaction_cfg.is_empty():
		return

	var radius: int = int(reaction_cfg.get("radius", 3))
	var color_hex: String = reaction_cfg.get("vfx_color", "#FFFFFF")
	var duration: float = float(reaction_cfg.get("vfx_duration", 0.5))

	var color: Color = Color.from_string(color_hex, Color.WHITE)
	_create_flash(pos, radius, color, duration)

	# VFX: 反应名称浮动文字 + 屏幕震动
	var world_pos: Vector2 = GridWorld.grid_to_world(pos)
	var display_name: String = reaction_cfg.get("display_name", reaction_id.to_upper())
	VFXManager.popup_text(display_name, world_pos, color, 0.8, 20)
	VFXManager.screen_shake(2.0, 0.08)


func _create_flash(center: Vector2i, radius: int, color: Color, duration: float) -> void:
	var cell_size: int = Constants.CELL_SIZE
	var side: int = radius * 2 + 1

	var rect := ColorRect.new()
	rect.size = Vector2(side * cell_size, side * cell_size)
	rect.position = Vector2((center.x - radius) * cell_size, (center.y - radius) * cell_size)
	rect.color = Color(color.r, color.g, color.b, 0.6)
	rect.z_index = 10
	add_child(rect)

	var tw: Tween = create_tween()
	tw.tween_property(rect, "color:a", 0.0, duration)
	tw.tween_callback(rect.queue_free)
