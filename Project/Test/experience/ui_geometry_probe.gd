extends RefCounted
## 几何探针（SpecKit 004 T009，设计文档 presentation_design.md §12.1 几何五项 + 对比度合成）
## probe()：断言模式，真实套件用；dry_run()：返回违规清单，自测断言"违规被发现"。
## 全部阈值来自 presentation.acceptance / presentation.layout / 项目视口设置（cfg 可逐键覆盖）。
## 只测沉降态：调用方先 ui_settle.settle_all() + 等一帧再探测。
## 非套件 harness 文件：不得命名 test_*.gd、不得放进 Test/cases/。

const _ThemeBuilderScript := preload("res://ui/kit/theme_builder.gd")

## 视口外/尺寸比较的浮点容差（像素）
const EDGE_EPSILON: float = 0.5
const SIZE_EPSILON: float = 0.1


func probe(t, ui_root: Node, state_name: String, cfg: Dictionary = {}) -> void:
	## 断言模式：每条违规一条 FAIL，外加一条"零违规"总断言（干净时输出 PASS 证据）
	var violations: Array = dry_run(ui_root, cfg)
	for violation in violations:
		t.assert_true(false, "[geometry:%s] %s" % [state_name, violation.get("detail", str(violation))])
	t.assert_true(violations.is_empty(),
		"[geometry:%s] zero violations (%d found)" % [state_name, violations.size()])


func dry_run(ui_root: Node, cfg: Dictionary = {}) -> Array:
	## ui_root 接受任意 Node（Control 容器或 CanvasLayer UI 层根，T014 跨面板整层扫描）
	## 违规清单：[{check, node, detail, ...}]；check ∈
	## overlap | label_fit | viewport | hit_target | modal_count | contrast
	var resolved: Dictionary = _resolve_cfg(cfg)
	var violations: Array = []
	var opaque_controls: Array = []
	_collect_opaque(ui_root, resolved, opaque_controls)
	var labels: Array = []
	_collect_labels(ui_root, labels)
	_check_overlap(opaque_controls, resolved, violations)
	_check_label_fit(labels, violations)
	_check_viewport(opaque_controls, labels, resolved, violations)
	_check_hit_targets(ui_root, resolved, violations)
	_check_modal_count(ui_root, resolved, violations)
	_check_contrast(labels, ui_root, resolved, violations)
	return violations


# ── 配置解析 ─────────────────────────────────────────────────────────

func _resolve_cfg(cfg: Dictionary) -> Dictionary:
	var acceptance: Dictionary = ConfigManager.get_acceptance_config()
	var layout: Dictionary = ConfigManager.get_layout_config()
	var resolved: Dictionary = {
		"overlap_tolerance_px2": float(acceptance.get("overlap_tolerance_px2", 0.0)),
		"opaque_alpha": float(acceptance.get("opaque_alpha", 1.0)),
		"contrast_min_body": float(acceptance.get("contrast_min_body", 0.0)),
		"contrast_min_large": float(acceptance.get("contrast_min_large", 0.0)),
		"max_visible_modals": int(acceptance.get("max_pending_modals", 1)),
		"min_hit_target": float(layout.get("min_hit_target", 0.0)),
		"viewport": Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 0)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 0))
		),
	}
	for key in cfg:
		resolved[key] = cfg[key]
	return resolved


# ── 收集 ─────────────────────────────────────────────────────────────

func _collect_opaque(node: Node, cfg: Dictionary, out: Array) -> void:
	## §12.1 不透明判定（显式助手）：ColorRect 看 color.a；PanelContainer 看
	## panel stylebox 底色 a；不透明节点即收集叶（内部组合不再下探）；
	## 其余视为透明容器，继续向下收集。
	if node is Control and not (node as Control).visible:
		return
	if node is Control and _is_opaque(node, cfg):
		out.append(node)
		return
	for child in node.get_children():
		_collect_opaque(child, cfg, out)


func _collect_labels(node: Node, out: Array) -> void:
	if node is Control and not (node as Control).visible:
		return
	if node is Label and not (node as Label).text.is_empty():
		out.append(node)
	for child in node.get_children():
		_collect_labels(child, out)


func _is_opaque(control: Control, cfg: Dictionary) -> bool:
	var threshold: float = float(cfg.get("opaque_alpha", 1.0))
	if control is ColorRect:
		return (control as ColorRect).color.a >= threshold
	if control is PanelContainer:
		var sb: StyleBox = control.get_theme_stylebox("panel")
		if sb is StyleBoxFlat:
			return (sb as StyleBoxFlat).bg_color.a >= threshold
	return false


# ── (1) 同层不透明重叠（ui_layer 矩阵豁免） ──────────────────────────

func _check_overlap(opaque_controls: Array, cfg: Dictionary, violations: Array) -> void:
	var tolerance: float = float(cfg.get("overlap_tolerance_px2", 0.0))
	for i in range(opaque_controls.size()):
		for j in range(i + 1, opaque_controls.size()):
			var a: Control = opaque_controls[i]
			var b: Control = opaque_controls[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue
			var layer_a: String = _ui_layer_of(a)
			var layer_b: String = _ui_layer_of(b)
			if _overlap_exempt(layer_a, layer_b):
				continue
			var area: float = a.get_global_rect().intersection(b.get_global_rect()).get_area()
			if area > tolerance:
				violations.append({
					"check": "overlap",
					"node": str(a.get_path()),
					"other": str(b.get_path()),
					"area": area,
					"detail": "opaque overlap %.0fpx2: %s [%s] x %s [%s]" % [
						area, a.name, layer_a, b.name, layer_b],
				})


func _ui_layer_of(control: Control) -> String:
	## 自下而上找最近的 ui_layer 元数据；缺省按 hud（kit 组件出生即带，§11.5）
	var node: Node = control
	while node != null:
		if node.has_meta("ui_layer"):
			return str(node.get_meta("ui_layer"))
		node = node.get_parent()
	return "hud"


func _overlap_exempt(layer_a: String, layer_b: String) -> bool:
	## §12.1 层矩阵：dim 与任何层可叠；modal 可压 dim/hud；toast 可压 hud；
	## 同层不豁免；矩阵外组合（如 modal x toast）也按违规查
	if layer_a == layer_b:
		return false
	if layer_a == "dim" or layer_b == "dim":
		return true
	var layers: Array = [layer_a, layer_b]
	if layers.has("modal") and layers.has("hud"):
		return true
	if layers.has("toast") and layers.has("hud"):
		return true
	return false


# ── (2) Label 文字适配（未声明截断即违规） ───────────────────────────

func _check_label_fit(labels: Array, violations: Array) -> void:
	for label_node in labels:
		var label: Label = label_node
		if bool(label.get_meta("ui_allow_truncate", false)):
			continue
		if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
			# autowrap：可见行数必须等于总行数（高度裁切 = 未声明截断）
			if label.get_visible_line_count() != label.get_line_count():
				violations.append({
					"check": "label_fit",
					"node": str(label.get_path()),
					"detail": "label '%s…' clipped: %d/%d lines visible" % [
						label.text.left(8), label.get_visible_line_count(), label.get_line_count()],
				})
		else:
			var min_size: Vector2 = label.get_combined_minimum_size()
			if label.size.x + SIZE_EPSILON < min_size.x or label.size.y + SIZE_EPSILON < min_size.y:
				violations.append({
					"check": "label_fit",
					"node": str(label.get_path()),
					"detail": "label '%s…' size %s < min %s" % [
						label.text.left(8), label.size, min_size],
				})


# ── (3) 视口内 ───────────────────────────────────────────────────────

func _check_viewport(opaque_controls: Array, labels: Array, cfg: Dictionary, violations: Array) -> void:
	var viewport_size: Vector2 = cfg.get("viewport", Vector2.ZERO)
	var seen: Array = []
	for node in opaque_controls + labels:
		if seen.has(node):
			continue
		seen.append(node)
		var rect: Rect2 = (node as Control).get_global_rect()
		if rect.position.x < -EDGE_EPSILON or rect.position.y < -EDGE_EPSILON \
				or rect.end.x > viewport_size.x + EDGE_EPSILON \
				or rect.end.y > viewport_size.y + EDGE_EPSILON:
			violations.append({
				"check": "viewport",
				"node": str((node as Control).get_path()),
				"detail": "control %s rect %s exceeds viewport %s" % [
					(node as Control).name, rect, viewport_size],
			})


# ── (4) 命中目标 ≥ min_hit_target（ui_hit 组） ───────────────────────

func _check_hit_targets(ui_root: Node, cfg: Dictionary, violations: Array) -> void:
	if not ui_root.is_inside_tree():
		return
	var min_hit: float = float(cfg.get("min_hit_target", 0.0))
	for node in ui_root.get_tree().get_nodes_in_group("ui_hit"):
		if not (node is Control):
			continue
		var control: Control = node
		if control != ui_root and not ui_root.is_ancestor_of(control):
			continue
		if not control.is_visible_in_tree():
			continue
		if control.size.x + SIZE_EPSILON < min_hit or control.size.y + SIZE_EPSILON < min_hit:
			violations.append({
				"check": "hit_target",
				"node": str(control.get_path()),
				"detail": "hit target %s is %.0fx%.0f (< %.0f)" % [
					control.name, control.size.x, control.size.y, min_hit],
			})


# ── (5) 可见模态计数 ─────────────────────────────────────────────────

func _check_modal_count(ui_root: Node, cfg: Dictionary, violations: Array) -> void:
	if not ui_root.is_inside_tree():
		return
	var max_visible: int = int(cfg.get("max_visible_modals", 1))
	var visible_count: int = 0
	for node in ui_root.get_tree().get_nodes_in_group("ui_modal"):
		if not (node is Control):
			continue
		var control: Control = node
		if control != ui_root and not ui_root.is_ancestor_of(control):
			continue
		if control.is_visible_in_tree():
			visible_count += 1
	if visible_count > max_visible:
		violations.append({
			"check": "modal_count",
			"node": str(ui_root.get_path()),
			"detail": "%d visible modals (max %d)" % [visible_count, max_visible],
		})


# ── 对比度：有效底色合成（§12.1 运行时对） ───────────────────────────

func _check_contrast(labels: Array, ui_root: Node, cfg: Dictionary, violations: Array) -> void:
	var heading_size: int = int(ConfigManager.get_typography().get("heading", 0))
	var min_body: float = float(cfg.get("contrast_min_body", 0.0))
	var min_large: float = float(cfg.get("contrast_min_large", 0.0))
	for label_node in labels:
		var label: Label = label_node
		var font_color: Color = label.get_theme_color("font_color")
		var bg: Color = _effective_background(label, ui_root)
		var ratio: float = _ThemeBuilderScript.contrast_ratio(font_color, bg)
		var font_size: int = label.get_theme_font_size("font_size")
		var threshold: float = min_body
		if heading_size > 0 and font_size >= heading_size:
			threshold = min_large
		if ratio < threshold:
			violations.append({
				"check": "contrast",
				"node": str(label.get_path()),
				"ratio": ratio,
				"detail": "label '%s…' contrast %.2f < %.2f (font %dpx on composited bg)" % [
					label.text.left(8), ratio, threshold, font_size],
			})


func _effective_background(label: Label, ui_root: Node) -> Color:
	## 从 ui_root 向内逐层把 ColorRect/PanelContainer 底色按 α 合成到 palette bg_deep 上
	var chain: Array = []
	var node: Node = label.get_parent()
	while node != null:
		if node is Control:
			chain.append(node)
		if node == ui_root:
			break
		node = node.get_parent()
	chain.reverse()
	var bg: Color = ConfigManager.get_palette_color("bg_deep")
	for ancestor in chain:
		var surface: Color = _surface_color(ancestor)
		if surface.a > 0.0:
			bg = _composite(bg, surface)
	return bg


func _surface_color(control: Control) -> Color:
	if control is ColorRect:
		return (control as ColorRect).color
	if control is PanelContainer:
		var sb: StyleBox = control.get_theme_stylebox("panel")
		if sb is StyleBoxFlat:
			return (sb as StyleBoxFlat).bg_color
	return Color(0, 0, 0, 0)


func _composite(dst: Color, src: Color) -> Color:
	var alpha: float = clampf(src.a, 0.0, 1.0)
	return Color(
		src.r * alpha + dst.r * (1.0 - alpha),
		src.g * alpha + dst.g * (1.0 - alpha),
		src.b * alpha + dst.b * (1.0 - alpha),
		1.0
	)
