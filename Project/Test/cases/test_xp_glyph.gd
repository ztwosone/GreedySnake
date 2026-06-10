extends RefCounted
## SpecKit 004 T004: glyph 程序绘制契约测试
## 设计文档: Designs/Interactive/presentation_design.md §3（glyph 词汇表，≤4 矩形程序绘制）
## 数据驱动（presentation.glyphs）+ _draw 直绘（零子节点）+ 未知 id 回退空心方框

const GLYPH_PATH: String = "res://ui/kit/glyph.gd"


func run(t) -> void:
	t.assert_file_exists(GLYPH_PATH)
	if not FileAccess.file_exists(GLYPH_PATH):
		return
	var glyph_script = load(GLYPH_PATH)
	t.assert_true(glyph_script is GDScript and glyph_script.can_instantiate(), "glyph.gd loads and instantiates")
	if not (glyph_script is GDScript and glyph_script.can_instantiate()):
		return

	var glyph = glyph_script.new()
	t.assert_true(glyph is Control, "glyph extends Control")
	t.add_child(glyph)

	# --- set_glyph 存储 id 与颜色（known id） ---
	var combat_color: Color = ConfigManager.get_palette_color("room_combat")
	glyph.set_glyph("combat", combat_color)
	t.assert_eq(glyph.get_glyph_id(), "combat", "set_glyph stores id")
	t.assert_eq(glyph.get_glyph_color(), combat_color, "set_glyph stores color")
	t.assert_true(glyph.has_glyph_def(), "known id resolves a glyph def from presentation.glyphs")

	# --- _draw 直绘：节点数恒为 0（不用子 ColorRect） ---
	t.assert_eq(glyph.get_child_count(), 0, "glyph draws via _draw - zero child nodes")

	# --- 未知 id：push_warning + 回退空心方框，状态仍更新、无脚本错误 ---
	glyph.set_glyph("nonexistent_glyph_xyz", Color.WHITE)
	t.assert_eq(glyph.get_glyph_id(), "nonexistent_glyph_xyz", "unknown id is stored (fallback path)")
	t.assert_false(glyph.has_glyph_def(), "unknown id has no def -> hollow square fallback")
	t.assert_eq(glyph.get_child_count(), 0, "fallback also draws via _draw - zero child nodes")

	# --- 重新设置 known id：状态切换干净（queue_redraw 路径经 set_glyph 触发） ---
	var reward_color: Color = ConfigManager.get_palette_color("room_reward")
	glyph.set_glyph("reward", reward_color)
	t.assert_eq(glyph.get_glyph_id(), "reward", "set_glyph re-targets to new id")
	t.assert_eq(glyph.get_glyph_color(), reward_color, "set_glyph re-targets color")
	t.assert_true(glyph.has_glyph_def(), "new id resolves def again")

	# --- cut 条目挖空色：默认 bg_panel，可被宿主覆盖（endpoint/elite/head 用） ---
	t.assert_eq(glyph.get_cut_color(), ConfigManager.get_palette_color("bg_panel"), "default cut color == palette bg_panel")
	var raised: Color = ConfigManager.get_palette_color("bg_panel_raised")
	glyph.set_cut_color(raised)
	t.assert_eq(glyph.get_cut_color(), raised, "set_cut_color overrides cut color")

	glyph.queue_free()
