extends RefCounted
## SpecKit 004 T003: kit_panel 基类契约测试
## 设计文档: Designs/Interactive/presentation_design.md §3（角括号框）/§11.5（出生即带验收钩子）
## 出生分组 ui_kit + ui_layer 元数据 + 共享缓存 Theme + settle() 快进 + ui_allow_truncate 声明

const KIT_PANEL_PATH: String = "res://ui/kit/kit_panel.gd"


func run(t) -> void:
	t.assert_file_exists(KIT_PANEL_PATH)
	if not FileAccess.file_exists(KIT_PANEL_PATH):
		return
	var panel_script = load(KIT_PANEL_PATH)
	t.assert_true(panel_script is GDScript and panel_script.can_instantiate(), "kit_panel.gd loads and instantiates")
	if not (panel_script is GDScript and panel_script.can_instantiate()):
		return

	# --- 出生即带：分组 + ui_layer 元数据（§11.5，入树前即生效） ---
	var panel = panel_script.new()
	t.assert_true(panel is PanelContainer, "kit_panel extends PanelContainer")
	t.assert_true(panel.is_in_group("ui_kit"), "panel is in group ui_kit at birth")
	t.assert_true(panel.has_meta("ui_layer"), "panel has ui_layer meta at birth")
	t.assert_eq(str(panel.get_meta("ui_layer")), "hud", "default ui_layer == hud")

	# --- 构造参数 + setter 覆盖 ui_layer ---
	var modal_panel = panel_script.new("modal")
	t.assert_eq(str(modal_panel.get_meta("ui_layer")), "modal", "constructor overrides ui_layer to modal")
	modal_panel.set_ui_layer("dim")
	t.assert_eq(str(modal_panel.get_meta("ui_layer")), "dim", "set_ui_layer overrides meta to dim")
	t.assert_eq(modal_panel.get_ui_layer(), "dim", "get_ui_layer mirrors meta")
	modal_panel.set_ui_layer("not_a_layer")
	t.assert_eq(str(modal_panel.get_meta("ui_layer")), "hud", "unknown ui_layer falls back to hud")

	# --- 共享缓存 Theme（preload theme_builder, build once, cache static） ---
	t.assert_true(panel.theme is Theme, "kit panel has theme applied at birth")
	t.assert_true(panel.theme == modal_panel.theme, "theme is one shared cached instance across panels")

	# --- settle()：追踪 Tween 快进到终态（§11.5） ---
	t.add_child(panel)
	panel.position = Vector2.ZERO
	var tw: Tween = panel.create_tween()
	tw.tween_property(panel, "position", Vector2(100, 0), 10.0)
	panel.track_tween(tw)
	panel.settle()
	t.assert_eq(panel.position, Vector2(100, 0), "settle() fast-forwards tracked tween to final value")
	t.assert_false(tw.is_running(), "tracked tween no longer running after settle()")

	# --- settle() 对空列表/已完成 Tween 安全可重入 ---
	panel.settle()
	t.assert_eq(panel.position, Vector2(100, 0), "settle() is safely re-entrant")

	# --- ui_allow_truncate 显式声明助手（§12.1 刻意截断须声明） ---
	var label := Label.new()
	panel.set_allow_truncate(label)
	t.assert_true(label.has_meta("ui_allow_truncate"), "set_allow_truncate sets meta on label")
	t.assert_eq(bool(label.get_meta("ui_allow_truncate")), true, "ui_allow_truncate meta is true")
	label.free()

	# --- register_hit_target：最小命中目标 + ui_hit 分组（§6/§12.1） ---
	var min_hit: float = float(ConfigManager.get_layout_config().get("min_hit_target", 0))
	t.assert_true(min_hit > 0.0, "layout.min_hit_target present")
	var button := Button.new()
	panel.register_hit_target(button)
	t.assert_true(button.is_in_group("ui_hit"), "registered button is in group ui_hit")
	t.assert_true(button.custom_minimum_size.x >= min_hit and button.custom_minimum_size.y >= min_hit, "registered button min size >= min_hit_target")
	button.free()

	panel.queue_free()
	modal_panel.free()
