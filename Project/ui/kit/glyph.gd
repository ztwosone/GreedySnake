extends Control
## 程序绘制 glyph（SpecKit 004 T004，设计文档 presentation_design.md §3 glyph 词汇表）
## 无 class_name：消费方一律 preload 本文件（ScriptingLeading 附录 C.8）。
## presentation.glyphs[id] 数据驱动：≤4 矩形组合在 _canvas_units 逻辑画布内，
## 经 _draw 直绘缩放到控件尺寸（不用子 ColorRect，节点数恒为 0）。
## 条目字段：rect [x,y,w,h]（画布单位）、rotation（度，绕矩形中心）、
## color_role（可选 palette token 覆盖）、cut: true（用底色挖空：终点同心框/精英中心点/蛇头缺口）。

var _glyph_id: String = ""
var _glyph_color: Color = Color.WHITE
var _cut_color: Color = Color.TRANSPARENT
var _has_custom_cut_color: bool = false


func set_glyph(glyph_id: String, color: Color) -> void:
	_glyph_id = glyph_id
	_glyph_color = color
	if ConfigManager.get_glyph_def(glyph_id).is_empty():
		push_warning("glyph: unknown id '%s', drawing fallback hollow square" % glyph_id)
	queue_redraw()


func get_glyph_id() -> String:
	return _glyph_id


func get_glyph_color() -> Color:
	return _glyph_color


func has_glyph_def() -> bool:
	return not ConfigManager.get_glyph_def(_glyph_id).is_empty()


## "cut" 条目的挖空色 = glyph 所在底色；默认 bg_panel，卡片等浮起底由宿主覆盖
func set_cut_color(color: Color) -> void:
	_cut_color = color
	_has_custom_cut_color = true
	queue_redraw()


func get_cut_color() -> Color:
	if _has_custom_cut_color:
		return _cut_color
	return ConfigManager.get_palette_color("bg_panel")


func _draw() -> void:
	if _glyph_id.is_empty():
		return
	var glyphs: Dictionary = ConfigManager.get_presentation_config().get("glyphs", {})
	var canvas_units: float = float(glyphs.get("_canvas_units", 0))
	if canvas_units <= 0.0:
		return
	# 逻辑画布：取控件短边的正方形居中
	var box: float = minf(size.x, size.y)
	var unit: float = box / canvas_units
	var origin: Vector2 = (size - Vector2(box, box)) * 0.5
	var def: Array = ConfigManager.get_glyph_def(_glyph_id)
	if def.is_empty():
		_draw_fallback(origin, box, unit)
		return
	for entry in def:
		if not entry is Dictionary:
			continue
		var rect_arr: Array = entry.get("rect", [])
		if rect_arr.size() != 4:
			continue
		var rect_pos: Vector2 = Vector2(float(rect_arr[0]), float(rect_arr[1])) * unit + origin
		var rect_size: Vector2 = Vector2(float(rect_arr[2]), float(rect_arr[3])) * unit
		var color: Color = _glyph_color
		if bool(entry.get("cut", false)):
			color = get_cut_color()
		elif entry.has("color_role"):
			color = ConfigManager.get_palette_color(str(entry.get("color_role")))
		var rotation_deg: float = float(entry.get("rotation", 0.0))
		var center: Vector2 = rect_pos + rect_size * 0.5
		draw_set_transform(center, deg_to_rad(rotation_deg), Vector2.ONE)
		draw_rect(Rect2(-rect_size * 0.5, rect_size), color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 未知 id 回退：空心方框（内缩 2 画布单位，线宽 1 画布单位）
func _draw_fallback(origin: Vector2, box: float, unit: float) -> void:
	var inset: float = unit * 2.0
	var rect := Rect2(origin + Vector2(inset, inset), Vector2(box - inset * 2.0, box - inset * 2.0))
	draw_rect(rect, _glyph_color, false, unit)
