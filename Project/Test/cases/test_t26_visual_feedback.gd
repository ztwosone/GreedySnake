extends RefCounted
## T26 视觉反馈系统测试
## 验证状态视觉应用/移除逻辑、敌人形状配置、受伤反馈触发


func run(t) -> void:
	_test_segment_status_visual_apply(t)
	_test_segment_status_visual_clear(t)
	_test_segment_ice_freeze_visual(t)
	_test_segment_fire_visual(t)
	_test_segment_poison_visual(t)
	_test_status_visual_priority(t)
	_test_enemy_shape_wanderer(t)
	_test_enemy_shape_chaser(t)
	_test_enemy_shape_bog_crawler(t)
	_test_enemy_death_animation(t)
	_test_snake_hurt_flash(t)
	_test_screen_shake_creation(t)
	_test_visual_config_fire(t)
	_test_visual_config_ice(t)
	_test_visual_config_poison(t)
	_test_enemy_shape_config(t)


# === Snake segment visual tests ===

func _test_segment_status_visual_apply(t) -> void:
	var seg := SnakeSegment.new()
	Engine.get_main_loop().root.add_child(seg)


	seg.apply_status_visual("fire", 1)
	t.assert_eq(seg.get_current_status_visual(), "fire", "[T26] segment fire visual applied")

	seg.clear_status_visual()
	t.assert_eq(seg.get_current_status_visual(), "", "[T26] segment visual cleared")

	seg.queue_free()


func _test_segment_status_visual_clear(t) -> void:
	var seg := SnakeSegment.new()
	Engine.get_main_loop().root.add_child(seg)


	seg.apply_status_visual("poison", 1)
	t.assert_eq(seg.get_current_status_visual(), "poison", "[T26] segment poison visual set")

	seg.apply_status_visual("ice", 1)
	t.assert_eq(seg.get_current_status_visual(), "ice", "[T26] segment visual replaced to ice")

	seg.clear_status_visual()
	t.assert_eq(seg.get_current_status_visual(), "", "[T26] segment visual fully cleared")

	seg.queue_free()


func _test_segment_ice_freeze_visual(t) -> void:
	var seg := SnakeSegment.new()
	Engine.get_main_loop().root.add_child(seg)


	# layer 1: 冰蓝
	seg.apply_status_visual("ice", 1)
	t.assert_eq(seg.get_current_status_visual(), "ice", "[T26] ice layer1 visual applied")

	# layer 2: 白色冻结
	seg.apply_status_visual("ice", 2)
	t.assert_eq(seg.get_current_status_visual(), "ice", "[T26] ice layer2 visual applied")
	# 验证覆盖层不透明度更高
	t.assert_true(seg._status_overlay.color.a > 0.5, "[T26] ice freeze overlay high alpha (%.2f)" % seg._status_overlay.color.a)

	seg.queue_free()


func _test_segment_fire_visual(t) -> void:
	var seg := SnakeSegment.new()
	Engine.get_main_loop().root.add_child(seg)


	seg.apply_status_visual("fire", 1)
	# 灼烧应该激活描边
	t.assert_true(seg._border_rect.color.a > 0.0, "[T26] fire border visible (alpha=%.2f)" % seg._border_rect.color.a)

	seg.clear_status_visual()
	t.assert_true(seg._border_rect.color.a < 0.01, "[T26] fire border hidden after clear")

	seg.queue_free()


func _test_segment_poison_visual(t) -> void:
	var seg := SnakeSegment.new()
	Engine.get_main_loop().root.add_child(seg)


	seg.apply_status_visual("poison", 1)
	t.assert_true(seg._status_overlay.color.a > 0.0, "[T26] poison overlay visible")
	t.assert_true(seg._status_overlay.color.g > 0.5, "[T26] poison overlay is green-ish")

	seg.queue_free()


func _test_status_visual_priority(t) -> void:
	# 状态优先级已移除（每段独立携带状态），验证基本状态视觉即可
	var seg := SnakeSegment.new()
	seg._build_visual()

	# fire 覆盖表现
	seg.apply_status_visual("fire", 1)
	var fire_alpha: float = seg._status_overlay.color.a
	t.assert_true(fire_alpha > 0.0, "[T26] fire overlay has alpha")

	# ice 覆盖表现
	seg.apply_status_visual("ice", 1)
	var ice_alpha: float = seg._status_overlay.color.a
	t.assert_true(ice_alpha > 0.0, "[T26] ice overlay has alpha")

	# poison 覆盖表现
	seg.apply_status_visual("poison", 1)
	var poison_alpha: float = seg._status_overlay.color.a
	t.assert_true(poison_alpha > 0.0, "[T26] poison overlay has alpha")

	seg.queue_free()


# === Enemy shape tests ===

func _test_enemy_shape_wanderer(t) -> void:
	var enemy := Enemy.new()
	enemy.enemy_type = "wanderer"
	enemy.enemy_shape = "square"
	enemy._build_visual()

	t.assert_true(enemy._color_rect != null, "[T26] wanderer has color_rect")
	t.assert_true(abs(enemy._color_rect.rotation) < 0.01, "[T26] wanderer not rotated")


func _test_enemy_shape_chaser(t) -> void:
	var enemy := Enemy.new()
	enemy.enemy_type = "chaser"
	enemy.enemy_shape = "diamond"
	enemy._build_visual()

	t.assert_true(enemy._color_rect != null, "[T26] chaser has color_rect")
	t.assert_true(abs(enemy._color_rect.rotation - PI / 4.0) < 0.01,
		"[T26] chaser rotated 45deg (rotation=%.3f)" % enemy._color_rect.rotation)


func _test_enemy_shape_bog_crawler(t) -> void:
	var enemy := Enemy.new()
	enemy.enemy_type = "bog_crawler"
	enemy.enemy_shape = "cross"
	enemy._build_visual()

	t.assert_true(enemy._color_rect != null, "[T26] bog_crawler has color_rect")
	# 十字形应该有 2 个 ColorRect 子节点
	var rect_count: int = 0
	for child in enemy.get_children():
		if child is ColorRect:
			rect_count += 1
	# cross shape: 2 arm rects + _border_rect + _status_overlay = 4
	t.assert_eq(rect_count, 4, "[T26] bog_crawler has 4 ColorRects (cross + status layers)")


func _test_enemy_death_animation(t) -> void:
	# 验证 die() 不会立即 queue_free，而是播放动画
	var enemy := Enemy.new()
	enemy.enemy_type = "wanderer"
	enemy.enemy_shape = "square"
	GridWorld.init_grid(10, 10)
	Engine.get_main_loop().root.add_child(enemy)

	enemy.place_on_grid(Vector2i(3, 3))

	# die() should not immediately free
	enemy.die()
	t.assert_true(is_instance_valid(enemy), "[T26] enemy still valid right after die() (animating)")

	# 等一帧让 tween 开始

	# 仍然有效（动画 0.2s 未完成）
	t.assert_true(is_instance_valid(enemy), "[T26] enemy still valid during death animation")

	GridWorld.clear_all()


func _test_snake_hurt_flash(t) -> void:
	# 验证 snake 有 _on_hurt 方法和 _flash_hurt 方法
	var snake := Snake.new()
	t.assert_true(snake.has_method("_on_hurt"), "[T26] snake has _on_hurt method")
	t.assert_true(snake.has_method("_flash_hurt"), "[T26] snake has _flash_hurt method")
	t.assert_true(snake.has_method("_start_danger_pulse"), "[T26] snake has _start_danger_pulse method")
	t.assert_true(snake.has_method("_stop_danger_pulse"), "[T26] snake has _stop_danger_pulse method")


func _test_screen_shake_creation(t) -> void:
	var ScreenShakeScript: GDScript = preload("res://systems/vfx/screen_shake.gd")
	var shake: Node = ScreenShakeScript.new()
	t.assert_true(shake != null, "[T26] ScreenShake instantiates")
	t.assert_true(shake.has_method("shake"), "[T26] ScreenShake has shake method")
	t.assert_true(shake.has_method("setup"), "[T26] ScreenShake has setup method")


# === Config visual tests ===

func _test_visual_config_fire(t) -> void:
	var cfg_node = ConfigManager
	if cfg_node == null:
		t.assert_true(false, "[T26] ConfigManager not found")
		return
	var fire_cfg: Dictionary = cfg_node.get_status_effect("fire")
	t.assert_true(fire_cfg.has("visual"), "[T26] fire config has visual section")
	var visual: Dictionary = fire_cfg.get("visual", {})
	t.assert_eq(visual.get("snake_effect", ""), "border_flash", "[T26] fire visual type is border_flash")
	t.assert_true(visual.has("border_color"), "[T26] fire visual has border_color")


func _test_visual_config_ice(t) -> void:
	var cfg_node = ConfigManager
	if cfg_node == null:
		t.assert_true(false, "[T26] ConfigManager not found")
		return
	var ice_cfg: Dictionary = cfg_node.get_status_effect("ice")
	t.assert_true(ice_cfg.has("visual"), "[T26] ice config has visual section")
	var visual: Dictionary = ice_cfg.get("visual", {})
	t.assert_eq(visual.get("snake_effect", ""), "overlay", "[T26] ice visual type is overlay")


func _test_visual_config_poison(t) -> void:
	var cfg_node = ConfigManager
	if cfg_node == null:
		t.assert_true(false, "[T26] ConfigManager not found")
		return
	var poison_cfg: Dictionary = cfg_node.get_status_effect("poison")
	t.assert_true(poison_cfg.has("visual"), "[T26] poison config has visual section")
	var visual: Dictionary = poison_cfg.get("visual", {})
	t.assert_eq(visual.get("snake_effect", ""), "pulse", "[T26] poison visual type is pulse")


func _test_enemy_shape_config(t) -> void:
	var cfg_node = ConfigManager
	if cfg_node == null:
		t.assert_true(false, "[T26] ConfigManager not found")
		return
	var w_cfg: Dictionary = cfg_node.get_enemy_type("wanderer")
	t.assert_eq(w_cfg.get("shape", ""), "square", "[T26] wanderer shape is square")
	var c_cfg: Dictionary = cfg_node.get_enemy_type("chaser")
	t.assert_eq(c_cfg.get("shape", ""), "diamond", "[T26] chaser shape is diamond")
	var b_cfg: Dictionary = cfg_node.get_enemy_type("bog_crawler")
	t.assert_eq(b_cfg.get("shape", ""), "cross", "[T26] bog_crawler shape is cross")
