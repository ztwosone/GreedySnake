class_name BuildTestPanel
extends PanelContainer

## Build 测试面板 — B 键切换显示/隐藏
## 显示当前装备（头/尾/鳞/共鸣/修改器/窗口），并提供热键快速换装。
## 热键仅在面板可见时生效。

var _label: RichTextLabel
var _visible_flag: bool = false
var _update_timer: float = 0.0

const UPDATE_INTERVAL: float = 0.1

# 管理器引用（由 setup() 注入）
var _snake: Node = null
var _snake_parts_mgr: Node = null
var _scale_slot_mgr: Node = null
var _resonance_mgr: Node = null
var _window_mgr: Node = null

# 循环列表
const HEAD_LIST: Array = ["hydra", "bai_she"]
const TAIL_LIST: Array = ["salamander", "lag_tail"]
const FRONT_SCALE_LIST: Array = ["greedy_scale", "predator_scale"]
const MIDDLE_SCALE_LIST: Array = ["flame_scale", "toxin_scale", "frost_scale", "phantom_scale"]
const BACK_SCALE_LIST: Array = ["thorn_scale", "regen_scale", "retaliation_scale"]


func _ready() -> void:
	# 半透明黑色背景
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)

	# RichTextLabel
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.add_theme_font_size_override("normal_font_size", 13)
	_label.add_theme_font_size_override("mono_font_size", 13)
	add_child(_label)

	# 右侧定位
	set_anchors_preset(PRESET_TOP_RIGHT)
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -348
	offset_right = -8
	offset_top = 100
	offset_bottom = 560

	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(p_snake: Node, p_parts_mgr: Node, p_scale_mgr: Node, p_res_mgr: Node, p_win_mgr: Node) -> void:
	_snake = p_snake
	_snake_parts_mgr = p_parts_mgr
	_scale_slot_mgr = p_scale_mgr
	_resonance_mgr = p_res_mgr
	_window_mgr = p_win_mgr


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return

	# B 键切换面板
	if event.keycode == KEY_B:
		_visible_flag = not _visible_flag
		visible = _visible_flag
		if _visible_flag:
			_refresh()
		return

	# 热键仅在面板可见时生效
	if not _visible_flag:
		return

	match event.keycode:
		KEY_H:
			_cycle_head()
		KEY_J:
			_cycle_tail()
		KEY_F:
			_cycle_scale("front", FRONT_SCALE_LIST)
		KEY_G:
			_cycle_scale("middle", MIDDLE_SCALE_LIST)
		KEY_K:
			_cycle_scale("back", BACK_SCALE_LIST)
		KEY_L:
			_upgrade_all()
		KEY_0:
			_clear_all()


func _process(delta: float) -> void:
	if not visible:
		return
	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		_refresh()


# === 显示刷新 ===

func _refresh() -> void:
	if _label == null:
		return

	var lines: Array[String] = []
	lines.append("[b][color=white]--- BUILD ---[/color][/b]")
	lines.append("[color=gray]B:toggle  H:head  J:tail[/color]")
	lines.append("[color=gray]F:front  G:mid  K:back  L:up  0:clear[/color]")
	lines.append("")

	_append_head_tail(lines)
	lines.append("")
	_append_scales(lines)
	lines.append("")
	_append_resonances(lines)
	lines.append("")
	_append_modifiers(lines)
	lines.append("")
	_append_windows(lines)

	_label.text = "\n".join(lines)


func _append_head_tail(lines: Array[String]) -> void:
	# Head
	var head_text: String = "(none)"
	if _snake_parts_mgr and _snake_parts_mgr.has_head():
		var hd = _snake_parts_mgr.get_active_head()
		var dn: String = _get_display_name("snake_heads", hd.part_id)
		head_text = "%s L%d" % [dn, hd.level]
	lines.append("[color=yellow][b]HEAD[/b]  %s[/color]" % head_text)

	# Tail
	var tail_text: String = "(none)"
	if _snake_parts_mgr and _snake_parts_mgr.has_tail():
		var tl = _snake_parts_mgr.get_active_tail()
		var dn: String = _get_display_name("snake_tails", tl.part_id)
		tail_text = "%s L%d" % [dn, tl.level]
	lines.append("[color=cyan][b]TAIL[/b]  %s[/color]" % tail_text)


func _append_scales(lines: Array[String]) -> void:
	lines.append("[color=lime][b]SCALES[/b][/color]")
	if not _scale_slot_mgr:
		lines.append("  (no manager)")
		return

	for pos in ["front", "middle", "back"]:
		var scales: Array = _scale_slot_mgr.get_scales(pos)
		var open: int = _scale_slot_mgr._open_slots.get(pos, 0)
		var max_s: int = _scale_slot_mgr.MAX_SLOTS.get(pos, 0)
		if scales.is_empty():
			lines.append("  [color=gray]%s (%d/%d): --[/color]" % [pos, 0, max_s])
		else:
			for s in scales:
				var dn: String = _get_display_name("snake_scales", s.part_id)
				var tags: Array = ConfigManager.get_scale_tags(s.part_id)
				var tag_str: String = ",".join(tags) if not tags.is_empty() else ""
				lines.append("  %s (%d/%d): [color=lime]%s L%d[/color] [color=gray][%s][/color]" % [
					pos, scales.size(), max_s, dn, s.level, tag_str
				])


func _append_resonances(lines: Array[String]) -> void:
	lines.append("[color=#FF66FF][b]RESONANCES[/b][/color]")
	if not _resonance_mgr:
		lines.append("  (no manager)")
		return

	var active: Array = _resonance_mgr.get_active_resonances()
	if active.is_empty():
		lines.append("  [color=gray](none)[/color]")
		return

	for res_id in active:
		var cfg: Dictionary = _find_resonance_config(res_id)
		var dn: String = cfg.get("display_name", res_id)
		var desc: String = cfg.get("description", "")
		var new_mark: String = " [color=yellow]NEW![/color]" if _resonance_mgr.is_resonance_discovered(res_id) else ""
		lines.append("  [color=#FF66FF]%s[/color] %s" % [dn, new_mark])
		if not desc.is_empty():
			lines.append("    [color=gray]%s[/color]" % desc)


func _append_modifiers(lines: Array[String]) -> void:
	lines.append("[color=orange][b]MODIFIERS[/b][/color]")
	if not _snake or not is_instance_valid(_snake):
		lines.append("  (no snake)")
		return

	var has_any: bool = false
	# 遍历所有已知修改器 key
	var all_keys: Array = StatusEffectManager._active_modifiers.keys()
	for key in all_keys:
		var val: float = StatusEffectManager.get_modifier(key, _snake, 0.0)
		if abs(val) > 0.001:
			var val_str: String = "+%.1f" % val if val > 0 else "%.1f" % val
			var color: String = "lime" if val > 0 else "red"
			lines.append("  %s: [color=%s]%s[/color]" % [key, color, val_str])
			has_any = true

	if not has_any:
		lines.append("  [color=gray](none)[/color]")


func _append_windows(lines: Array[String]) -> void:
	lines.append("[color=#6699FF][b]WINDOWS[/b][/color]")
	if not _window_mgr:
		lines.append("  (no manager)")
		return

	var windows: Dictionary = _window_mgr._active_windows
	if windows.is_empty():
		lines.append("  [color=gray](none)[/color]")
		return

	for wid in windows:
		var w = windows[wid]
		var remaining: int = w.remaining_ticks if w.get("remaining_ticks") != null else 0
		var duration: int = w.duration_ticks if w.get("duration_ticks") != null else 0
		var rules_str: String = ""
		if w.get("rules") and not w.rules.is_empty():
			var parts: Array = []
			for rk in w.rules:
				parts.append("%s=%s" % [rk, str(w.rules[rk])])
			rules_str = " [%s]" % ", ".join(parts)
		lines.append("  [color=#6699FF]%s[/color] %d/%d tick%s" % [wid, remaining, duration, rules_str])


# === 热键装备逻辑 ===

func _cycle_head() -> void:
	if not _snake_parts_mgr:
		return
	var current_id: String = ""
	if _snake_parts_mgr.has_head():
		current_id = _snake_parts_mgr.get_active_head().part_id
	var next_id: String = _get_next_in_list(current_id, HEAD_LIST)
	_snake_parts_mgr.unequip_head()
	if not next_id.is_empty():
		_snake_parts_mgr.equip_head(next_id, 1)
	_refresh()


func _cycle_tail() -> void:
	if not _snake_parts_mgr:
		return
	var current_id: String = ""
	if _snake_parts_mgr.has_tail():
		current_id = _snake_parts_mgr.get_active_tail().part_id
	var next_id: String = _get_next_in_list(current_id, TAIL_LIST)
	_snake_parts_mgr.unequip_tail()
	if not next_id.is_empty():
		_snake_parts_mgr.equip_tail(next_id, 1)
	_refresh()


func _cycle_scale(position: String, scale_list: Array) -> void:
	if not _scale_slot_mgr:
		return
	var scales: Array = _scale_slot_mgr.get_scales(position)
	var current_id: String = ""
	if not scales.is_empty():
		current_id = scales[0].part_id

	var next_id: String = _get_next_in_list(current_id, scale_list)

	# 卸载当前
	if not scales.is_empty():
		_scale_slot_mgr.unequip_scale(position, 0)

	# 装备新的
	if not next_id.is_empty():
		_scale_slot_mgr.equip_scale(position, next_id, 1)
	_refresh()


func _upgrade_all() -> void:
	if not _snake_parts_mgr or not _scale_slot_mgr:
		return

	# 升级蛇头
	if _snake_parts_mgr.has_head():
		var hd = _snake_parts_mgr.get_active_head()
		if hd.level < 3:
			var hid: String = hd.part_id
			var new_level: int = hd.level + 1
			_snake_parts_mgr.unequip_head()
			_snake_parts_mgr.equip_head(hid, new_level)

	# 升级蛇尾
	if _snake_parts_mgr.has_tail():
		var tl = _snake_parts_mgr.get_active_tail()
		if tl.level < 3:
			var tid: String = tl.part_id
			var new_level: int = tl.level + 1
			_snake_parts_mgr.unequip_tail()
			_snake_parts_mgr.equip_tail(tid, new_level)

	# 升级所有鳞片
	for pos in ["front", "middle", "back"]:
		var all_slots: Array = _scale_slot_mgr._slots.get(pos, [])
		for i in range(all_slots.size()):
			var part = all_slots[i]
			if part != null and part.level < 3:
				_scale_slot_mgr.upgrade_scale(pos, i, part.level + 1)
	_refresh()


func _clear_all() -> void:
	if _resonance_mgr:
		_resonance_mgr.clear_all()
	if _scale_slot_mgr:
		_scale_slot_mgr.clear_all()
	if _snake_parts_mgr:
		_snake_parts_mgr.unequip_head()
		_snake_parts_mgr.unequip_tail()
	_refresh()


# === 辅助方法 ===

func _get_next_in_list(current_id: String, list: Array) -> String:
	if current_id.is_empty():
		return list[0] if not list.is_empty() else ""
	var idx: int = list.find(current_id)
	if idx < 0 or idx >= list.size() - 1:
		return ""  # 到末尾了，回到 none
	return list[idx + 1]


func _get_display_name(section: String, part_id: String) -> String:
	# display_name 在顶层配置中，不在 levels 内
	var raw: Dictionary = {}
	if section == "snake_heads":
		raw = ConfigManager.snake_heads.get(part_id, {})
	elif section == "snake_tails":
		raw = ConfigManager.snake_tails.get(part_id, {})
	elif section == "snake_scales":
		raw = ConfigManager.snake_scales.get(part_id, {})
	return raw.get("display_name", part_id)


func _find_resonance_config(res_id: String) -> Dictionary:
	# 遍历 tag_resonances 查找匹配的 resonance_id
	var all_ids: Array = ConfigManager.get_tag_resonance_ids()
	for key in all_ids:
		var cfg: Dictionary = ConfigManager.tag_resonances.get(key, {})
		if cfg.get("resonance_id", "") == res_id:
			return cfg
	return {}
