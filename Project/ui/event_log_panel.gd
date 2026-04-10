extends PanelContainer

## 通用事件日志面板（V 键切换）
## 实时记录 Build/窗口/共鸣/战斗等 L2 事件 + 世界空间 VFX 提示
## 在 game_world.gd 中创建，所有场景自动可用

const MAX_LINES: int = 80
const UPDATE_INTERVAL: float = 0.1

# Colors
const C_EQUIP := "#FFD700"       # 装备 — 黄
const C_UNEQUIP := "#B8860B"     # 卸载 — 暗黄
const C_RESONANCE := "#FF69B4"   # 共鸣 — 品红
const C_RES_OFF := "#8B4567"     # 共鸣消失 — 暗品红
const C_WINDOW := "#6495ED"      # 窗口开启 — 蓝
const C_WIN_EXPIRE := "#AAAAAA"  # 窗口到期 — 灰
const C_WIN_CANCEL := "#777777"  # 窗口取消 — 暗灰
const C_KILL := "#7CFC00"        # 击杀 — 绿
const C_HIT := "#FF4444"         # 受击 — 红
const C_GROW := "#90EE90"        # 增长 — 浅绿
const C_SHRINK := "#FF6347"      # 缩短 — 橙红
const C_DEFER := "#87CEEB"       # 延迟 — 天蓝
const C_MODIFIER := "#FFA500"    # 修改器 — 橙

var _label: RichTextLabel
var _visible_flag: bool = false
var _line_count: int = 0
var _snake: Node2D
var _update_timer: float = 0.0

# Modifier tracking for change detection
var _last_modifiers: Dictionary = {}


func setup(p_snake: Node2D) -> void:
	_snake = p_snake


func _ready() -> void:
	# Semi-transparent dark background
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)

	# Scrollable RichTextLabel
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = false
	_label.scroll_active = true
	_label.scroll_following = true
	_label.add_theme_font_size_override("normal_font_size", 13)
	add_child(_label)

	# Left-side positioning
	set_anchors_preset(PRESET_TOP_LEFT)
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = 8
	offset_right = 340
	offset_top = 100
	offset_bottom = 600

	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Connect all EventBus signals
	_connect_signals()

	# Initial header
	_label.append_text("[b][color=#CCCCCC]事件日志[/color][/b] [color=#666666](V 键切换)[/color]\n\n")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_V:
		_visible_flag = not _visible_flag
		visible = _visible_flag


# ═══════════════════════════════════════════
# Signal Connections
# ═══════════════════════════════════════════

func _connect_signals() -> void:
	# Equipment
	EventBus.snake_head_equipped.connect(_on_head_equipped)
	EventBus.snake_head_unequipped.connect(_on_head_unequipped)
	EventBus.snake_tail_equipped.connect(_on_tail_equipped)
	EventBus.snake_tail_unequipped.connect(_on_tail_unequipped)
	EventBus.snake_scale_equipped.connect(_on_scale_equipped)
	EventBus.snake_scale_unequipped.connect(_on_scale_unequipped)

	# Resonance
	EventBus.resonance_activated.connect(_on_resonance_activated)
	EventBus.resonance_deactivated.connect(_on_resonance_deactivated)

	# Windows
	EventBus.window_opened.connect(_on_window_opened)
	EventBus.window_expired.connect(_on_window_expired)
	EventBus.window_cancelled.connect(_on_window_cancelled)

	# Combat
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.snake_body_attacked.connect(_on_body_attacked)

	# Length changes
	EventBus.snake_length_increased.connect(_on_length_increased)
	EventBus.snake_length_decreased.connect(_on_length_decreased)
	EventBus.segment_loss_deferred.connect(_on_segment_deferred)


# ═══════════════════════════════════════════
# Equipment Handlers
# ═══════════════════════════════════════════

func _on_head_equipped(data: Dictionary) -> void:
	var id: String = data.get("head_id", "?")
	var level: int = data.get("level", 1)
	var name: String = _head_name(id)
	_log_event(C_EQUIP, "装备 蛇头: %s L%d" % [name, level])
	_vfx_popup("装备: %s" % name, Color(1, 0.84, 0))


func _on_head_unequipped(data: Dictionary) -> void:
	var id: String = data.get("head_id", "?")
	_log_event(C_UNEQUIP, "卸载 蛇头: %s" % _head_name(id))


func _on_tail_equipped(data: Dictionary) -> void:
	var id: String = data.get("tail_id", "?")
	var level: int = data.get("level", 1)
	var name: String = _tail_name(id)
	_log_event(C_EQUIP, "装备 蛇尾: %s L%d" % [name, level])
	_vfx_popup("装备: %s" % name, Color(1, 0.84, 0))


func _on_tail_unequipped(data: Dictionary) -> void:
	var id: String = data.get("tail_id", "?")
	_log_event(C_UNEQUIP, "卸载 蛇尾: %s" % _tail_name(id))


func _on_scale_equipped(data: Dictionary) -> void:
	var id: String = data.get("scale_id", "?")
	var level: int = data.get("level", 1)
	var pos: String = data.get("position", "?")
	var name: String = _scale_name(id)
	_log_event(C_EQUIP, "装备 鳞片: %s L%d (%s)" % [name, level, pos])
	_vfx_popup("装备: %s" % name, Color(1, 0.84, 0))


func _on_scale_unequipped(data: Dictionary) -> void:
	var id: String = data.get("scale_id", "?")
	var pos: String = data.get("position", "?")
	_log_event(C_UNEQUIP, "卸载 鳞片: %s (%s)" % [_scale_name(id), pos])


# ═══════════════════════════════════════════
# Resonance Handlers
# ═══════════════════════════════════════════

func _on_resonance_activated(data: Dictionary) -> void:
	var name: String = data.get("display_name", data.get("resonance_id", "?"))
	_log_event(C_RESONANCE, "共鸣激活: %s" % name)
	_vfx_popup("共鸣: %s" % name, Color(1, 0.41, 0.71))
	if _visible_flag:
		VFXManager.screen_flash(Color(1, 0.41, 0.71, 0.15), 0.2)


func _on_resonance_deactivated(data: Dictionary) -> void:
	var id: String = data.get("resonance_id", "?")
	_log_event(C_RES_OFF, "共鸣消失: %s" % id)


# ═══════════════════════════════════════════
# Window Handlers
# ═══════════════════════════════════════════

func _on_window_opened(data: Dictionary) -> void:
	var wid: String = data.get("window_id", "?")
	var dur: int = data.get("duration_ticks", 0)
	_log_event(C_WINDOW, "窗口开启: %s (%dT)" % [wid, dur])
	_vfx_popup("窗口: %s %dT" % [wid, dur], Color(0.39, 0.58, 0.93))
	if _visible_flag:
		var pos: Vector2 = _snake_world_pos()
		if pos != Vector2.ZERO:
			VFXManager.area_flash(pos, 1, Color(0.39, 0.58, 0.93, 0.4), 0.3)


func _on_window_expired(data: Dictionary) -> void:
	var wid: String = data.get("window_id", "?")
	_log_event(C_WIN_EXPIRE, "窗口到期: %s" % wid)
	if _visible_flag:
		var pos: Vector2 = _snake_world_pos()
		if pos != Vector2.ZERO:
			VFXManager.burst_at(pos, Color(0.67, 0.67, 0.67, 0.5), 20.0, 0.3)


func _on_window_cancelled(data: Dictionary) -> void:
	var wid: String = data.get("window_id", "?")
	var reason: String = data.get("reason", "")
	_log_event(C_WIN_CANCEL, "窗口取消: %s (%s)" % [wid, reason])


# ═══════════════════════════════════════════
# Combat Handlers
# ═══════════════════════════════════════════

func _on_enemy_killed(data: Dictionary) -> void:
	var enemy_def: Dictionary = data.get("enemy_def", {})
	var etype: String = enemy_def.get("type", data.get("type", "?"))
	var pos: Vector2i = data.get("position", Vector2i(-1, -1))
	var cfg: Dictionary = ConfigManager.get_enemy_type(etype)
	var ename: String = cfg.get("display_name", etype)
	_log_event(C_KILL, "击杀 %s @ (%d,%d)" % [ename, pos.x, pos.y])
	if _visible_flag and pos != Vector2i(-1, -1):
		var wpos := Vector2(pos.x * Constants.CELL_SIZE, pos.y * Constants.CELL_SIZE)
		VFXManager.burst_at(wpos, Color(0.49, 0.99, 0), 24.0, 0.25)


func _on_body_attacked(data: Dictionary) -> void:
	var pos: Vector2i = data.get("position", Vector2i(-1, -1))
	_log_event(C_HIT, "受击! @ (%d,%d)" % [pos.x, pos.y])
	if _visible_flag and pos != Vector2i(-1, -1):
		var wpos := Vector2(pos.x * Constants.CELL_SIZE, pos.y * Constants.CELL_SIZE)
		VFXManager.popup_text("受击!", wpos, Color(1, 0.27, 0.27), 0.6, 18)


# ═══════════════════════════════════════════
# Length Change Handlers
# ═══════════════════════════════════════════

func _on_length_increased(data: Dictionary) -> void:
	var amount: int = data.get("amount", 1)
	var source: String = data.get("source", "")
	_log_event(C_GROW, "+%d段 (%s)" % [amount, source if source else "grow"])
	if _visible_flag:
		_vfx_popup("+%d" % amount, Color(0.56, 0.93, 0.56))


func _on_length_decreased(data: Dictionary) -> void:
	var amount: int = data.get("amount", 1)
	var source: String = data.get("source", "")
	_log_event(C_SHRINK, "-%d段 (%s)" % [amount, source if source else "shrink"])


func _on_segment_deferred(data: Dictionary) -> void:
	_log_event(C_DEFER, "段丢失延迟!")
	_vfx_popup("延迟!", Color(0.53, 0.81, 0.92))


# ═══════════════════════════════════════════
# Modifier Tracking (polled in _process)
# ═══════════════════════════════════════════

const TRACKED_MODIFIERS: Array = [
	"hit_threshold", "fire_aura_damage", "fire_aura_range",
	"food_drop", "poison_spread_bonus", "poison_tile_damage",
	"attack_cooldown_bonus", "phantom_tail_count",
]

func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer < UPDATE_INTERVAL:
		return
	_update_timer = 0.0

	if not _snake or not is_instance_valid(_snake):
		return

	# Check modifier changes
	for key in TRACKED_MODIFIERS:
		var val: float = StatusEffectManager.get_modifier(key, _snake, 0.0)
		var old_val: float = _last_modifiers.get(key, 0.0)
		if abs(val - old_val) > 0.001:
			_last_modifiers[key] = val
			if abs(val) > 0.001:
				_log_event(C_MODIFIER, "+修改器 %s = %s" % [key, _format_modifier(val)])
			else:
				_log_event(C_MODIFIER, "-修改器 %s (归零)" % key)
			if _visible_flag:
				var sign: String = "+" if val > 0 else ""
				_vfx_popup("%s%s" % [key, sign + str(int(val))], Color(1, 0.65, 0), 0.8)


# ═══════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════

func _log_event(color: String, text: String) -> void:
	var tick: int = TickManager.current_tick
	var line := "[color=#666666][T%d][/color] [color=%s]%s[/color]\n" % [tick, color, text]
	_label.append_text(line)
	_line_count += 1
	if _line_count > MAX_LINES:
		# Clear and re-add header — simplest trim approach
		_label.clear()
		_label.append_text("[color=#666666]... (旧日志已清除) ...[/color]\n")
		_line_count = 1


func _vfx_popup(text: String, color: Color, duration: float = 0.6) -> void:
	if not _visible_flag:
		return
	var pos: Vector2 = _snake_world_pos()
	if pos == Vector2.ZERO:
		return
	VFXManager.popup_text(text, pos, color, duration, 16)


func _snake_world_pos() -> Vector2:
	if not _snake or not is_instance_valid(_snake):
		return Vector2.ZERO
	if _snake.segments.is_empty():
		return Vector2.ZERO
	var head = _snake.segments[0]
	if not is_instance_valid(head):
		return Vector2.ZERO
	return head.global_position


func _format_modifier(val: float) -> String:
	if val == int(val):
		return "%+d" % int(val)
	return "%+.1f" % val


func _head_name(id: String) -> String:
	return ConfigManager.snake_heads.get(id, {}).get("display_name", id)


func _tail_name(id: String) -> String:
	return ConfigManager.snake_tails.get(id, {}).get("display_name", id)


func _scale_name(id: String) -> String:
	return ConfigManager.snake_scales.get(id, {}).get("display_name", id)
