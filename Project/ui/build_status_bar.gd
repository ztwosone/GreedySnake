extends "res://ui/kit/kit_panel.gd"
## Build 状态条（SpecKit 004 Phase P T104c，presentation_design.md §8.6）
## 底中：[头][前…][中…][后…][尾] 槽位格——空槽虚框、装备格实心 + 等级点、
## 共鸣 = 相邻格间 accent_resonance 连线（按活跃对 part_id 定位槽位）、
## 首次发现 caption「共鸣发现：X」停留 discovery_hold_sec 后收起。
## 纯监听 + 注入系统只读查询（§11.1 只听不驱动）；数据驱动 _draw 零槽位子节点。
## 无 class_name：消费方一律按路径加载（ScriptingLeading 附录 C.8）。

const _POSITIONS: Array = ["front", "middle", "back"]

var _parts_mgr = null
var _slot_mgr = null
var _resonance_mgr = null
var _caption_label: Label
## 绘制单元缓存：[{kind: "head"|"scale"|"tail", position, part_id, level, occupied}]
var _cells: Array = []
var _links: Array = []


func _init() -> void:
	super._init("hud")


func _ready() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_apply_geometry()

	# §8.6 首次发现 caption（条上方一行，hud 层内嵌避免与 toast 层互踩）
	_caption_label = Label.new()
	_caption_label.name = "DiscoveryCaption"
	_caption_label.theme_type_variation = "CaptionLabel"
	_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption_label.add_theme_color_override(
		"font_color", ConfigManager.get_palette_color("accent_resonance"))
	_caption_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_caption_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption_label.visible = false
	add_child(_caption_label)

	for sig in [EventBus.snake_head_equipped, EventBus.snake_head_unequipped,
			EventBus.snake_tail_equipped, EventBus.snake_tail_unequipped,
			EventBus.snake_scale_equipped, EventBus.snake_scale_unequipped,
			EventBus.slot_unlocked, EventBus.resonance_activated,
			EventBus.resonance_deactivated]:
		sig.connect(_on_build_changed)
	EventBus.resonance_activated.connect(_on_resonance_activated)
	EventBus.game_started.connect(_refresh)


## 注入只读查询面（game_world 接线真实管理器；测试注入替身）
func setup(parts_mgr, slot_mgr, resonance_mgr) -> void:
	_parts_mgr = parts_mgr
	_slot_mgr = slot_mgr
	_resonance_mgr = resonance_mgr
	visible = true
	_refresh()


# === 查询契约（test_xp_build_bar） ===

func get_cell_count() -> int:
	return _cells.size()


func get_occupied_count() -> int:
	var n: int = 0
	for cell in _cells:
		if cell.get("occupied", false):
			n += 1
	return n


func get_link_count() -> int:
	return _links.size()


func is_caption_visible() -> bool:
	return _caption_label != null and _caption_label.visible


func get_caption_text() -> String:
	return _caption_label.text if _caption_label != null else ""


# === 事件 ===

func _on_build_changed(_data: Dictionary) -> void:
	_refresh()


## §8.6 首次发现横幅：caption 停留 discovery_hold_sec 后收起（Tween 入 settle 语义）
func _on_resonance_activated(data: Dictionary) -> void:
	if not bool(data.get("is_new_discovery", false)):
		return
	_caption_label.text = "共鸣发现：%s" % str(data.get("display_name", ""))
	_caption_label.visible = true
	var tw: Tween = track_tween(create_tween())
	tw.tween_interval(float(
		ConfigManager.get_ceremony_config().get("discovery_hold_sec", 0.0)))
	tw.tween_callback(func() -> void: _caption_label.visible = false)


func _refresh() -> void:
	if _slot_mgr == null:
		return
	_cells.clear()
	var head = _parts_mgr.get_active_head() if _parts_mgr != null else null
	_cells.append(_make_part_cell("head", head))
	for position in _POSITIONS:
		for entry in _slot_mgr.get_slot_layout(position):
			_cells.append({
				"kind": "scale", "position": position,
				"part_id": str(entry.part_id) if entry != null else "",
				"level": int(entry.level) if entry != null else 0,
				"occupied": entry != null,
			})
	var tail = _parts_mgr.get_active_tail() if _parts_mgr != null else null
	_cells.append(_make_part_cell("tail", tail))

	# 共鸣连线：活跃对 part_id → 槽位格索引（同件多槽取首个命中）
	_links.clear()
	if _resonance_mgr != null and _resonance_mgr.has_method("get_active_pairs"):
		for pair in _resonance_mgr.get_active_pairs():
			var a: int = _find_cell(str(pair.get("part_a", "")))
			var b: int = _find_cell(str(pair.get("part_b", "")))
			if a >= 0 and b >= 0 and a != b:
				_links.append([mini(a, b), maxi(a, b)])

	_apply_geometry()
	queue_redraw()


## 底中定位：锚点 (0.5, 1.0)，按格数回写 offsets 保持水平居中、底缘留边
func _apply_geometry() -> void:
	var layout: Dictionary = ConfigManager.get_layout_config()
	var base_unit: float = float(layout.get("base_unit", 16))
	var screen_margin: float = float(layout.get("screen_margin", 0))
	var w: float = maxf(_cells.size(), 1) * base_unit * 1.25 + base_unit * 0.5
	var h: float = base_unit * 1.75
	offset_left = -w * 0.5
	offset_right = w * 0.5
	offset_top = -(h + screen_margin)
	offset_bottom = -screen_margin


func _make_part_cell(kind: String, part) -> Dictionary:
	return {
		"kind": kind, "position": kind,
		"part_id": str(part.part_id) if part != null else "",
		"level": int(part.level) if part != null else 0,
		"occupied": part != null,
	}


func _find_cell(part_id: String) -> int:
	if part_id.is_empty():
		return -1
	for i in _cells.size():
		if str(_cells[i].get("part_id", "")) == part_id:
			return i
	return -1


func _draw() -> void:
	super._draw()
	if _cells.is_empty():
		return
	var base_unit: float = float(ConfigManager.get_layout_config().get("base_unit", 16))
	var cell: float = base_unit
	var step: float = base_unit * 1.25
	var origin: Vector2 = Vector2(base_unit * 0.25, base_unit * 0.375)
	var frame_color: Color = ConfigManager.get_palette_color("frame_line")
	var fill_color: Color = ConfigManager.get_palette_color("text_primary")
	var accent: Color = ConfigManager.get_palette_color("accent_resonance")
	var dot_color: Color = ConfigManager.get_palette_color("accent_shedskin")

	# §8.6 共鸣连线（格中心间，画在格之下）
	for link in _links:
		var from: Vector2 = origin + Vector2(link[0] * step + cell * 0.5, cell * 0.5)
		var to: Vector2 = origin + Vector2(link[1] * step + cell * 0.5, cell * 0.5)
		draw_line(from, to, accent, 2.0)

	for i in _cells.size():
		var c: Dictionary = _cells[i]
		var rect := Rect2(origin + Vector2(i * step, 0), Vector2(cell, cell))
		if c.get("occupied", false):
			var color: Color = accent if c.get("kind") != "scale" else fill_color
			draw_rect(rect, color)
			# 等级点（底缘，≤3 个）
			var level: int = clampi(int(c.get("level", 0)), 0, 3)
			for d in level:
				draw_rect(Rect2(rect.position + Vector2(
					2.0 + d * 4.0, cell - 3.0), Vector2(2.0, 2.0)), dot_color)
		else:
			# 空槽 = 虚框（四角短刻，§8.6）
			var arm: float = cell * 0.25
			draw_rect(Rect2(rect.position, Vector2(arm, 1)), frame_color)
			draw_rect(Rect2(rect.position, Vector2(1, arm)), frame_color)
			draw_rect(Rect2(rect.position + Vector2(cell - arm, 0),
				Vector2(arm, 1)), frame_color)
			draw_rect(Rect2(rect.position + Vector2(cell - 1, 0),
				Vector2(1, arm)), frame_color)
			draw_rect(Rect2(rect.position + Vector2(0, cell - 1),
				Vector2(arm, 1)), frame_color)
			draw_rect(Rect2(rect.position + Vector2(0, cell - arm),
				Vector2(1, arm)), frame_color)
			draw_rect(Rect2(rect.position + Vector2(cell - arm, cell - 1),
				Vector2(arm, 1)), frame_color)
			draw_rect(Rect2(rect.position + Vector2(cell - 1, cell - arm),
				Vector2(1, arm)), frame_color)
