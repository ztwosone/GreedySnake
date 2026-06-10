extends Node
## 全局视觉效果管理器
## 所有 VFX 调用通过此单例，与游戏逻辑完全解耦
##
## 仪表缝（presentation_design.md §11.4）：vfx_invoked(fx_name, args) 在每个公共效果
## 方法解析完默认参数后、任何副作用（含有效性检查）之前发射——命令层可在 headless
## 下断言"意图"而非渲染结果；args 携带最终解析值（含 JSON 默认）。
##
## duration roles per presentation_design.md §5（默认时长一律量化到 tick 三档）:
##   flash_entity / scale_bounce / lunge_toward -> motion.durations.half_tick (0.125) 实体反馈
##   screen_flash / screen_shake                -> motion.durations.half_tick (0.125) 屏幕级反馈
##   burst_at                                   -> motion.durations.one_tick  (0.25)
##   popup_text / area_flash / ring_at          -> motion.durations.two_ticks (0.5)
##   shatter_at 碎片总寿命                       -> motion.durations.two_ticks (0.5) 上限
##   fly_to_hud                                 -> motion.durations.two_ticks (0.5) HUD 飞行
##   hit_stop -> game_feel.hit_stop_sec（触发表 §9 hitstop 列按事件覆写，非 tick 量化）
## 强度/数量类默认值（peak/distance_ratio/size/count/intensity）-> presentation.game_feel

signal vfx_invoked(fx_name: String, args: Dictionary)

var _vfx_layer: Node2D  # 世界空间 VFX 容器
var _screen_layer: CanvasLayer  # 屏幕空间效果


func _ready() -> void:
	_create_layers()


func _create_layers() -> void:
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
	if not is_instance_valid(_vfx_layer) or not is_instance_valid(_screen_layer):
		_create_layers()

	if _vfx_layer.get_parent():
		_vfx_layer.get_parent().remove_child(_vfx_layer)
	game_world.add_child(_vfx_layer)

	if _screen_layer.get_parent():
		_screen_layer.get_parent().remove_child(_screen_layer)
	game_world.add_child(_screen_layer)


# === JSON 默认参数解析（sentinel < 0 表示调用方未覆盖，调用时实时读 ConfigManager） ===

func _motion_duration(role: String) -> float:
	var durations: Dictionary = ConfigManager.get_motion().get("durations", {})
	return float(durations.get(role, 0.0))


func _feel(key: String) -> float:
	return float(ConfigManager.get_game_feel().get(key, 0.0))


# === Entity Effects ===

func flash_entity(entity: Node2D, color: Color, duration: float = -1.0) -> void:
	## 实体闪烁指定颜色后恢复
	if duration < 0.0:
		duration = _motion_duration("half_tick")
	vfx_invoked.emit("flash_entity", {"entity": entity, "color": color, "duration": duration})
	if not is_instance_valid(entity):
		return
	var original: Color = entity.modulate
	entity.modulate = color
	var tw: Tween = entity.create_tween()
	tw.tween_property(entity, "modulate", original, duration)


func scale_bounce(entity: Node2D, peak: float = -1.0, duration: float = -1.0) -> void:
	## 实体缩放弹跳
	if peak < 0.0:
		peak = _feel("bounce_peak")
	if duration < 0.0:
		duration = _motion_duration("half_tick")
	vfx_invoked.emit("scale_bounce", {"entity": entity, "peak": peak, "duration": duration})
	if not is_instance_valid(entity):
		return
	var tw: Tween = entity.create_tween()
	tw.tween_property(entity, "scale", Vector2(peak, peak), duration * 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(entity, "scale", Vector2.ONE, duration * 0.6).set_ease(Tween.EASE_IN)


func lunge_toward(entity: Node2D, target_pos: Vector2, distance_ratio: float = -1.0, duration: float = -1.0) -> void:
	## 实体朝目标方向冲撞后弹回（近战攻击动画）
	if distance_ratio < 0.0:
		distance_ratio = _feel("lunge_distance_ratio")
	if duration < 0.0:
		duration = _motion_duration("half_tick")
	vfx_invoked.emit("lunge_toward", {"entity": entity, "target_pos": target_pos, "distance_ratio": distance_ratio, "duration": duration})
	if not is_instance_valid(entity):
		return
	var origin: Vector2 = entity.global_position
	var dir: Vector2 = (target_pos - origin).normalized()
	var lunge_pos: Vector2 = origin + dir * Constants.CELL_SIZE * distance_ratio
	var tw: Tween = entity.create_tween()
	tw.tween_property(entity, "global_position", lunge_pos, duration * 0.33).set_ease(Tween.EASE_OUT)
	tw.tween_property(entity, "global_position", origin, duration * 0.67).set_ease(Tween.EASE_IN_OUT)


# === Popup Effects ===

func popup_text(text: String, world_pos: Vector2, color: Color = Color.WHITE, duration: float = -1.0, font_size: int = -1) -> void:
	## 浮动文字：从位置上飘 + 淡出
	if duration < 0.0:
		duration = _motion_duration("two_ticks")
	if font_size < 0:
		font_size = int(ConfigManager.get_typography().get("body", 0))
	vfx_invoked.emit("popup_text", {"text": text, "world_pos": world_pos, "color": color, "duration": duration, "font_size": font_size})
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

func burst_at(world_pos: Vector2, color: Color, size: float = -1.0, duration: float = -1.0) -> void:
	## 位置爆裂效果（扩大 + 淡出的色块）
	if size < 0.0:
		size = _feel("burst_size")
	if duration < 0.0:
		duration = _motion_duration("one_tick")
	vfx_invoked.emit("burst_at", {"world_pos": world_pos, "color": color, "size": size, "duration": duration})
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


func area_flash(world_pos: Vector2, radius_cells: int, color: Color, duration: float = -1.0) -> void:
	## 区域闪光（反应效果等）
	if duration < 0.0:
		duration = _motion_duration("two_ticks")
	vfx_invoked.emit("area_flash", {"world_pos": world_pos, "radius_cells": radius_cells, "color": color, "duration": duration})
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


func shatter_at(world_pos: Vector2, color: Color, n: int = -1) -> void:
	## 色块碎片爆散（§9 #2 击杀 / #4 丢段）：n 个小矩形向外飞 + 重力感下坠 + 淡出
	## 碎片总寿命 <= motion.durations.two_ticks（§5 量化上限）
	if n < 0:
		n = int(_feel("shatter_count"))
	var lifetime: float = _motion_duration("two_ticks")
	vfx_invoked.emit("shatter_at", {"world_pos": world_pos, "color": color, "count": n, "duration": lifetime})
	if not is_instance_valid(_vfx_layer):
		return
	var size: float = _feel("shatter_size")
	var distance: float = _feel("shatter_distance")
	var fall: float = _feel("shatter_fall")
	for i in range(n):
		var rect: ColorRect = ColorRect.new()
		rect.color = color
		rect.size = Vector2(size, size)
		rect.global_position = world_pos - rect.size / 2
		rect.z_index = 10
		_vfx_layer.add_child(rect)
		# 均匀散射角（确定性，半步偏移避免轴对齐）；x 减速外抛 + y 加速下坠 = 重力感
		var dir: Vector2 = Vector2.RIGHT.rotated(TAU * (float(i) + 0.5) / float(n))
		var start: Vector2 = rect.position
		var tw: Tween = rect.create_tween()
		tw.set_parallel(true)
		tw.tween_property(rect, "position:x", start.x + dir.x * distance, lifetime).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(rect, "position:y", start.y + dir.y * distance + fall, lifetime).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(rect, "modulate:a", 0.0, lifetime)
		tw.chain().tween_callback(rect.queue_free)


func ring_at(world_pos: Vector2, color: Color, radius_cells: int = -1) -> void:
	## 扩散空心环（§9 #5 反应标记）：四条细矩形拼方环，从中心放大 + 淡出
	if radius_cells < 0:
		radius_cells = int(_feel("ring_radius_cells"))
	var duration: float = _motion_duration("two_ticks")
	vfx_invoked.emit("ring_at", {"world_pos": world_pos, "color": color, "radius_cells": radius_cells, "duration": duration})
	if not is_instance_valid(_vfx_layer):
		return
	var side: float = (radius_cells * 2 + 1) * Constants.CELL_SIZE
	var width: float = _feel("ring_width")
	var half: float = side / 2
	var ring: Node2D = Node2D.new()
	ring.z_index = 10
	_vfx_layer.add_child(ring)
	ring.global_position = world_pos
	var edges: Array = [
		[Vector2(-half, -half), Vector2(side, width)],
		[Vector2(-half, half - width), Vector2(side, width)],
		[Vector2(-half, -half), Vector2(width, side)],
		[Vector2(half - width, -half), Vector2(width, side)],
	]
	for edge in edges:
		var rect: ColorRect = ColorRect.new()
		rect.color = color
		rect.position = edge[0]
		rect.size = edge[1]
		ring.add_child(rect)
	ring.scale = Vector2.ONE * _feel("ring_start_scale")

	var tw: Tween = ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, duration)
	tw.chain().tween_callback(ring.queue_free)


func fly_to_hud(from_world: Vector2, to_node: Control, color: Color) -> void:
	## 世界 → HUD 飞行（§8.5 货币/拾取入账）：world→screen 投影后在屏幕层 tween，
	## 到达时发 vfx_invoked("fly_to_hud_arrived") 并 queue_free
	var duration: float = _motion_duration("two_ticks")
	var size: float = _feel("fly_size")
	vfx_invoked.emit("fly_to_hud", {"from_world": from_world, "to_node": to_node, "color": color, "duration": duration, "size": size})
	if not is_instance_valid(_screen_layer) or not is_instance_valid(to_node):
		return
	if not _screen_layer.is_inside_tree() or not to_node.is_inside_tree():
		return
	var from_screen: Vector2 = from_world
	if is_instance_valid(_vfx_layer) and _vfx_layer.is_inside_tree():
		from_screen = _vfx_layer.get_viewport().get_canvas_transform() * from_world
	var rect: ColorRect = ColorRect.new()
	rect.color = color
	rect.size = Vector2(size, size)
	rect.position = from_screen - rect.size / 2
	_screen_layer.add_child(rect)
	var to_screen: Vector2 = to_node.get_global_rect().get_center()

	var tw: Tween = rect.create_tween()
	tw.tween_property(rect, "position", to_screen - rect.size / 2, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		vfx_invoked.emit("fly_to_hud_arrived", {"to_node": to_node, "color": color})
		rect.queue_free()
	)


# === Screen Effects ===

func screen_flash(color: Color = Color(1, 1, 1, 0.3), duration: float = -1.0) -> void:
	## 全屏闪白/闪红
	if duration < 0.0:
		duration = _motion_duration("half_tick")
	vfx_invoked.emit("screen_flash", {"color": color, "duration": duration})
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


func screen_shake(intensity: float = -1.0, duration: float = -1.0) -> void:
	## 屏幕震动（委托给已有的 ScreenShake 系统）
	if intensity < 0.0:
		intensity = _feel("shake_intensity")
	if duration < 0.0:
		duration = _motion_duration("half_tick")
	vfx_invoked.emit("screen_shake", {"intensity": intensity, "duration": duration})
	if not is_instance_valid(_vfx_layer):
		return
	var vfx_parent: Node = _vfx_layer.get_parent()
	if vfx_parent == null:
		return
	var shake_node: Node = vfx_parent.get_node_or_null("ScreenShake")
	if shake_node and shake_node.has_method("shake"):
		shake_node.shake(intensity, duration)


func hit_stop(duration: float = -1.0) -> void:
	## 极短暂停（打击感）
	if duration < 0.0:
		duration = _feel("hit_stop_sec")
	vfx_invoked.emit("hit_stop", {"duration": duration})
	Engine.time_scale = 0.0
	get_tree().create_timer(duration, true, false, true).timeout.connect(func():
		Engine.time_scale = 1.0
	)
