extends Node
## 全局视觉效果管理器
## 所有 VFX 调用通过此单例，与游戏逻辑完全解耦

var _vfx_layer: Node2D  # 世界空间 VFX 容器
var _screen_layer: CanvasLayer  # 屏幕空间效果


func _ready() -> void:
	# 世界空间 VFX 层（会随 Camera 移动）
	_vfx_layer = Node2D.new()
	_vfx_layer.name = "VFXLayer"
	_vfx_layer.z_index = 10

	# 屏幕空间层（固定在屏幕上）
	_screen_layer = CanvasLayer.new()
	_screen_layer.name = "ScreenVFXLayer"
	_screen_layer.layer = 5


func setup(game_world: Node2D) -> void:
	## 在 GameWorld._ready() 中调用，挂载 VFX 层
	if _vfx_layer.get_parent():
		_vfx_layer.get_parent().remove_child(_vfx_layer)
	game_world.add_child(_vfx_layer)

	if _screen_layer.get_parent():
		_screen_layer.get_parent().remove_child(_screen_layer)
	game_world.add_child(_screen_layer)


# === Entity Effects ===

func flash_entity(entity: Node2D, color: Color, duration: float = 0.15) -> void:
	## 实体闪烁指定颜色后恢复
	if not is_instance_valid(entity):
		return
	var original: Color = entity.modulate
	entity.modulate = color
	var tw: Tween = entity.create_tween()
	tw.tween_property(entity, "modulate", original, duration)


func scale_bounce(entity: Node2D, peak: float = 1.3, duration: float = 0.15) -> void:
	## 实体缩放弹跳
	if not is_instance_valid(entity):
		return
	var tw: Tween = entity.create_tween()
	tw.tween_property(entity, "scale", Vector2(peak, peak), duration * 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(entity, "scale", Vector2.ONE, duration * 0.6).set_ease(Tween.EASE_IN)


func lunge_toward(entity: Node2D, target_pos: Vector2, distance_ratio: float = 0.3, duration: float = 0.15) -> void:
	## 实体朝目标方向冲撞后弹回（近战攻击动画）
	if not is_instance_valid(entity):
		return
	var origin: Vector2 = entity.global_position
	var dir: Vector2 = (target_pos - origin).normalized()
	var lunge_pos: Vector2 = origin + dir * Constants.CELL_SIZE * distance_ratio
	var tw: Tween = entity.create_tween()
	tw.tween_property(entity, "global_position", lunge_pos, duration * 0.33).set_ease(Tween.EASE_OUT)
	tw.tween_property(entity, "global_position", origin, duration * 0.67).set_ease(Tween.EASE_IN_OUT)


# === Popup Effects ===

func popup_text(text: String, world_pos: Vector2, color: Color = Color.WHITE, duration: float = 0.5, font_size: int = 16) -> void:
	## 浮动文字：从位置上飘 + 淡出
	if not is_instance_valid(_vfx_layer):
		return
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.global_position = world_pos - Vector2(30, 20)
	label.z_index = 15
	_vfx_layer.add_child(label)

	var tw: Tween = label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "global_position:y", world_pos.y - 50, duration).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, duration).set_delay(duration * 0.4)
	tw.chain().tween_callback(label.queue_free)


# === World-Space VFX ===

func burst_at(world_pos: Vector2, color: Color, size: float = 24.0, duration: float = 0.2) -> void:
	## 位置爆裂效果（扩大 + 淡出的色块）
	if not is_instance_valid(_vfx_layer):
		return
	var rect: ColorRect = ColorRect.new()
	rect.color = color
	rect.size = Vector2(size * 0.5, size * 0.5)
	rect.global_position = world_pos - rect.size / 2
	rect.z_index = 10
	_vfx_layer.add_child(rect)

	var tw: Tween = rect.create_tween()
	tw.set_parallel(true)
	tw.tween_property(rect, "size", Vector2(size, size), duration).set_ease(Tween.EASE_OUT)
	tw.tween_property(rect, "global_position", world_pos - Vector2(size / 2, size / 2), duration)
	tw.tween_property(rect, "color:a", 0.0, duration)
	tw.chain().tween_callback(rect.queue_free)


func area_flash(world_pos: Vector2, radius_cells: int, color: Color, duration: float = 0.5) -> void:
	## 区域闪光（反应效果等）
	if not is_instance_valid(_vfx_layer):
		return
	var side: float = (radius_cells * 2 + 1) * Constants.CELL_SIZE
	var rect: ColorRect = ColorRect.new()
	rect.color = Color(color.r, color.g, color.b, 0.6)
	rect.size = Vector2(side, side)
	rect.global_position = world_pos - Vector2(side / 2, side / 2)
	rect.z_index = 10
	_vfx_layer.add_child(rect)

	var tw: Tween = rect.create_tween()
	tw.tween_property(rect, "color:a", 0.0, duration)
	tw.tween_callback(rect.queue_free)


# === Screen Effects ===

func screen_flash(color: Color = Color(1, 1, 1, 0.3), duration: float = 0.1) -> void:
	## 全屏闪白/闪红
	if not is_instance_valid(_screen_layer):
		return
	var rect: ColorRect = ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_layer.add_child(rect)

	var tw: Tween = rect.create_tween()
	tw.tween_property(rect, "color:a", 0.0, duration)
	tw.tween_callback(rect.queue_free)


func screen_shake(intensity: float = 3.0, duration: float = 0.1) -> void:
	## 屏幕震动（委托给已有的 ScreenShake 系统）
	var shake_node: Node = _vfx_layer.get_parent().get_node_or_null("ScreenShake") if is_instance_valid(_vfx_layer) else null
	if shake_node and shake_node.has_method("shake"):
		shake_node.shake(intensity, duration)


func hit_stop(duration: float = 0.02) -> void:
	## 极短暂停（打击感）
	Engine.time_scale = 0.0
	get_tree().create_timer(duration, true, false, true).timeout.connect(func():
		Engine.time_scale = 1.0
	)
