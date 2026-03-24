class_name DebugPanel
extends PanelContainer

## 按 C 键切换的调试面板，显示蛇和游戏状态概览。

var _label: RichTextLabel
var _visible_flag: bool = false
var _snake: Node2D  # Snake reference
var _update_timer: float = 0.0

const UPDATE_INTERVAL: float = 0.1  # 每 0.1 秒刷新一次


func _ready() -> void:
	# 半透明黑色背景
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.75)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)

	# RichTextLabel 用于多色显示
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.add_theme_font_size_override("normal_font_size", 14)
	_label.add_theme_font_size_override("mono_font_size", 14)
	add_child(_label)

	# 左上角定位（避免与验收清单重叠）
	set_anchors_preset(PRESET_TOP_LEFT)
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = 8
	offset_right = 328
	offset_top = 100
	offset_bottom = 500

	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_C:
		_visible_flag = not _visible_flag
		visible = _visible_flag
		if _visible_flag:
			_refresh()


func _process(delta: float) -> void:
	if not visible:
		return
	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		_refresh()


func set_snake(s: Node2D) -> void:
	_snake = s


func _refresh() -> void:
	if _label == null:
		return

	var lines: Array[String] = []
	lines.append("[b][color=yellow]== DEBUG PANEL ==[/color][/b]")
	lines.append("")

	# Snake info
	_append_snake_info(lines)
	lines.append("")

	# Status effects
	_append_status_info(lines)
	lines.append("")

	# Modifiers
	_append_modifier_info(lines)
	lines.append("")

	# Enemies
	_append_enemy_info(lines)
	lines.append("")

	# Tick info
	_append_tick_info(lines)

	_label.text = "\n".join(lines)


func _append_snake_info(lines: Array[String]) -> void:
	lines.append("[b][color=lime]-- Snake --[/color][/b]")
	if _snake == null or not is_instance_valid(_snake):
		lines.append("  (no snake)")
		return
	var alive: bool = _snake.get("is_alive") if _snake.get("is_alive") != null else false
	var alive_str: String = "[color=lime]ALIVE[/color]" if alive else "[color=red]DEAD[/color]"
	lines.append("  State: %s" % alive_str)
	var body_arr = _snake.get("body")
	if body_arr != null:
		lines.append("  Length: %d" % body_arr.size())
		if body_arr.size() > 0:
			lines.append("  Head: (%d, %d)" % [body_arr[0].x, body_arr[0].y])
	var dir = _snake.get("direction")
	if dir != null:
		lines.append("  Dir: %s" % _dir_name(dir))
	var buf = _snake.get("input_buffer")
	if buf != null and buf != Vector2i.ZERO:
		lines.append("  Buffer: %s" % _dir_name(buf))
	var grow: int = _snake.get("grow_pending") if _snake.get("grow_pending") != null else 0
	if grow > 0:
		lines.append("  Grow pending: %d" % grow)
	var accum = _snake.get("_move_accumulator")
	if accum != null:
		lines.append("  Move accum: %.2f" % accum)


func _append_status_info(lines: Array[String]) -> void:
	lines.append("[b][color=cyan]-- Status Effects --[/color][/b]")
	var sem = StatusEffectManager
	if sem == null or _snake == null or not is_instance_valid(_snake):
		lines.append("  (none)")
		return
	var statuses: Array = sem.get_statuses(_snake)
	if statuses.is_empty():
		lines.append("  (none)")
		return
	for effect in statuses:
		var remaining: float = maxf(effect.duration - effect.elapsed, 0.0)
		var color: String = _status_color(effect.type)
		lines.append("  [color=%s]%s[/color] L%d  %.1fs left  (src: %s)" % [
			color, effect.type.to_upper(), effect.layer, remaining,
			str(effect.get("source_type")) if effect.get("source_type") else "?"
		])


func _append_modifier_info(lines: Array[String]) -> void:
	lines.append("[b][color=orange]-- Modifiers --[/color][/b]")
	var sem = StatusEffectManager
	if sem == null or _snake == null or not is_instance_valid(_snake):
		lines.append("  (none)")
		return
	var speed: float = sem.get_modifier("speed", _snake, 1.0)
	var growth: float = sem.get_modifier("growth", _snake, 1.0)
	var speed_color: String = "lime" if speed == 1.0 else ("cyan" if speed < 1.0 else "red")
	var growth_color: String = "lime" if growth == 1.0 else ("red" if growth < 1.0 else "lime")
	lines.append("  Speed: [color=%s]%.1fx[/color]" % [speed_color, speed])
	lines.append("  Growth: [color=%s]%.1fx[/color]" % [growth_color, growth])


func _append_enemy_info(lines: Array[String]) -> void:
	lines.append("[b][color=red]-- Enemies --[/color][/b]")
	var gw = get_parent().get_parent() if get_parent() else null
	if gw == null:
		# Try scene tree
		gw = get_tree().get_first_node_in_group("game_world") if is_inside_tree() else null
	var em = gw.get_node_or_null("EnemyManager") if gw else null
	if em == null:
		lines.append("  (no manager)")
		return
	var enemies: Array = em.get("current_enemies") if em.get("current_enemies") != null else []
	var alive_count: int = 0
	var type_counts: Dictionary = {}
	for e in enemies:
		if is_instance_valid(e):
			alive_count += 1
			var t: String = e.get("type_id") if e.get("type_id") != null else "unknown"
			type_counts[t] = type_counts.get(t, 0) + 1
	lines.append("  Total: %d" % alive_count)
	for t in type_counts:
		lines.append("    %s: %d" % [t, type_counts[t]])


func _append_tick_info(lines: Array[String]) -> void:
	lines.append("[b][color=white]-- Tick --[/color][/b]")
	if TickManager:
		var ticking: bool = TickManager.get("is_ticking") if TickManager.get("is_ticking") != null else false
		var paused: bool = TickManager.get("is_paused") if TickManager.get("is_paused") != null else false
		var tick_idx: int = TickManager.get("tick_index") if TickManager.get("tick_index") != null else 0
		var interval: float = TickManager.get_effective_interval() if TickManager.has_method("get_effective_interval") else 0.0
		lines.append("  Tick#: %d" % tick_idx)
		lines.append("  Interval: %.3fs" % interval)
		var state: String = "PAUSED" if paused else ("TICKING" if ticking else "STOPPED")
		var state_color: String = "yellow" if paused else ("lime" if ticking else "red")
		lines.append("  State: [color=%s]%s[/color]" % [state_color, state])


func _dir_name(dir: Vector2i) -> String:
	if dir == Vector2i.UP: return "UP"
	if dir == Vector2i.DOWN: return "DOWN"
	if dir == Vector2i.LEFT: return "LEFT"
	if dir == Vector2i.RIGHT: return "RIGHT"
	return "(%d,%d)" % [dir.x, dir.y]


func _status_color(type: String) -> String:
	match type:
		"fire": return "#FF6600"
		"ice": return "#88CCFF"
		"poison": return "#44DD44"
		_: return "white"
