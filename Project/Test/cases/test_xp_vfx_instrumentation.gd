extends RefCounted
## SpecKit 004 T007: VFXManager 仪表信号 + 参数 JSON 化 + shatter/ring/fly 新效果
## 设计文档: Designs/Interactive/presentation_design.md
##   §5（游戏层动效时长量化三档）/§9（触发表 shatter_at/ring_at）/§11.4（仪表缝挂单例）
## headless 安全：只断言节点创建与信号参数，不触渲染

const PUBLIC_EFFECTS: Array = [
	"flash_entity", "scale_bounce", "lunge_toward", "popup_text", "burst_at",
	"area_flash", "screen_flash", "screen_shake", "hit_stop",
	"shatter_at", "ring_at", "fly_to_hud",
]

var _invocations: Array = []


func _assert_last(t, expected_fx: String, expected_count: int) -> Dictionary:
	t.assert_eq(_invocations.size(), expected_count, "exactly one vfx_invoked per call (count %d after %s)" % [expected_count, expected_fx])
	if _invocations.is_empty():
		return {}
	var last: Dictionary = _invocations[-1]
	t.assert_eq(str(last.get("fx")), expected_fx, "vfx_invoked fx_name == %s" % expected_fx)
	return last.get("args", {})


func run(t) -> void:
	# --- 仪表缝存在性（缺失时安全早退，Red 阶段不崩） ---
	t.assert_true(VFXManager.has_signal("vfx_invoked"), "VFXManager has vfx_invoked signal")
	var all_methods := true
	for m in PUBLIC_EFFECTS:
		var has_it: bool = VFXManager.has_method(m)
		t.assert_true(has_it, "VFXManager has %s()" % m)
		if not has_it:
			all_methods = false
	if not (VFXManager.has_signal("vfx_invoked") and all_methods):
		return

	# --- JSON 期望值（§5 时长三档 + game_feel 强度） ---
	var durations: Dictionary = ConfigManager.get_motion().get("durations", {})
	var half_tick: float = float(durations.get("half_tick", 0.0))
	var one_tick: float = float(durations.get("one_tick", 0.0))
	var two_ticks: float = float(durations.get("two_ticks", 0.0))
	var feel: Dictionary = ConfigManager.get_presentation_config().get("game_feel", {})
	var body_size: int = int(ConfigManager.get_typography().get("body", 0))
	t.assert_true(feel.has("shatter_count"), "game_feel.shatter_count present in JSON")

	# --- 仪表信号录制 ---
	var on_vfx := func(fx_name: String, args_in: Dictionary) -> void:
		_invocations.append({"fx": fx_name, "args": args_in})
	VFXManager.vfx_invoked.connect(on_vfx)

	# --- 本地世界 + setup ---
	var world := Node2D.new()
	t.add_child(world)
	VFXManager.setup(world)
	var vfx_layer: Node2D = world.get_node_or_null("VFXLayer")
	var screen_layer: CanvasLayer = world.get_node_or_null("ScreenVFXLayer")
	t.assert_true(vfx_layer != null and screen_layer != null, "setup mounts VFX layers under local world")
	if vfx_layer == null or screen_layer == null:
		VFXManager.vfx_invoked.disconnect(on_vfx)
		return

	var dummy := Node2D.new()
	world.add_child(dummy)

	# 1. flash_entity: duration -> motion half_tick
	VFXManager.flash_entity(dummy, Color.RED)
	var args: Dictionary = _assert_last(t, "flash_entity", 1)
	t.assert_eq(args.get("duration"), half_tick, "flash_entity default duration == motion half_tick")

	# 2. scale_bounce: peak -> game_feel.bounce_peak, duration -> half_tick
	VFXManager.scale_bounce(dummy)
	args = _assert_last(t, "scale_bounce", 2)
	t.assert_eq(args.get("peak"), float(feel.get("bounce_peak", 0.0)), "scale_bounce default peak == game_feel.bounce_peak")
	t.assert_eq(args.get("duration"), half_tick, "scale_bounce default duration == motion half_tick")

	# 3. lunge_toward: distance_ratio -> game_feel, duration -> half_tick
	VFXManager.lunge_toward(dummy, Vector2(64, 0))
	args = _assert_last(t, "lunge_toward", 3)
	t.assert_eq(args.get("distance_ratio"), float(feel.get("lunge_distance_ratio", 0.0)), "lunge default distance_ratio == game_feel.lunge_distance_ratio")
	t.assert_eq(args.get("duration"), half_tick, "lunge default duration == motion half_tick")

	# 4. popup_text: duration -> two_ticks, font_size -> typography.body
	VFXManager.popup_text("+1", Vector2(32, 32))
	args = _assert_last(t, "popup_text", 4)
	t.assert_eq(args.get("duration"), two_ticks, "popup default duration == motion two_ticks")
	t.assert_eq(int(args.get("font_size", -1)), body_size, "popup default font_size == typography.body")

	# 5. burst_at: size -> game_feel.burst_size, duration -> one_tick
	VFXManager.burst_at(Vector2(16, 16), Color.GREEN)
	args = _assert_last(t, "burst_at", 5)
	t.assert_eq(args.get("size"), float(feel.get("burst_size", 0.0)), "burst default size == game_feel.burst_size")
	t.assert_eq(args.get("duration"), one_tick, "burst default duration == motion one_tick")

	# 6. area_flash: duration -> two_ticks
	VFXManager.area_flash(Vector2.ZERO, 1, Color.BLUE)
	args = _assert_last(t, "area_flash", 6)
	t.assert_eq(args.get("duration"), two_ticks, "area_flash default duration == motion two_ticks")

	# 7. screen_flash: duration -> half_tick
	VFXManager.screen_flash()
	args = _assert_last(t, "screen_flash", 7)
	t.assert_eq(args.get("duration"), half_tick, "screen_flash default duration == motion half_tick")

	# 8. screen_shake: intensity -> game_feel.shake_intensity, duration -> half_tick
	VFXManager.screen_shake()
	args = _assert_last(t, "screen_shake", 8)
	t.assert_eq(args.get("intensity"), float(feel.get("shake_intensity", 0.0)), "shake default intensity == game_feel.shake_intensity")
	t.assert_eq(args.get("duration"), half_tick, "shake default duration == motion half_tick")

	# 9. hit_stop: duration -> game_feel.hit_stop_sec
	VFXManager.hit_stop()
	args = _assert_last(t, "hit_stop", 9)
	t.assert_eq(args.get("duration"), float(feel.get("hit_stop_sec", 0.0)), "hit_stop default duration == game_feel.hit_stop_sec")

	# 10. shatter_at: 默认碎片数 = game_feel.shatter_count，全部入 vfx layer，寿命 <= two_ticks
	var before_children: int = vfx_layer.get_child_count()
	VFXManager.shatter_at(Vector2(48, 48), Color.ORANGE)
	args = _assert_last(t, "shatter_at", 10)
	var expected_n: int = int(feel.get("shatter_count", 0))
	t.assert_eq(int(args.get("count", -1)), expected_n, "shatter default count == game_feel.shatter_count")
	t.assert_eq(vfx_layer.get_child_count() - before_children, expected_n, "shatter spawns shatter_count rects under vfx layer")
	t.assert_true(float(args.get("duration", 99.0)) <= two_ticks, "shatter lifetime <= motion two_ticks")

	# 11. ring_at: 默认半径 = game_feel.ring_radius_cells，单个环节点
	before_children = vfx_layer.get_child_count()
	VFXManager.ring_at(Vector2(48, 48), Color.PURPLE)
	args = _assert_last(t, "ring_at", 11)
	t.assert_eq(int(args.get("radius_cells", -1)), int(feel.get("ring_radius_cells", 0)), "ring default radius_cells == game_feel.ring_radius_cells")
	t.assert_eq(vfx_layer.get_child_count() - before_children, 1, "ring spawns one ring node under vfx layer")

	# 12. fly_to_hud: 屏幕层飞行 + 到达信号
	var target := Control.new()
	target.position = Vector2(200, 40)
	target.size = Vector2(32, 32)
	t.add_child(target)
	var before_screen: int = screen_layer.get_child_count()
	VFXManager.fly_to_hud(Vector2(8, 8), target, Color.YELLOW)
	args = _assert_last(t, "fly_to_hud", 12)
	t.assert_eq(args.get("duration"), two_ticks, "fly_to_hud default duration == motion two_ticks")
	t.assert_eq(screen_layer.get_child_count() - before_screen, 1, "fly_to_hud spawns one rect under screen layer")

	# --- 等待 tween 落地：到达信号 + hit_stop 恢复 ---
	# 坑：headless 下 ignore_time_scale 计时器比 Tween 的 scaled 时钟快 ~2x，
	# 必须用默认 scaled 计时器与 tween 共用时钟（hit_stop 的恢复计时器自带
	# ignore_time_scale，保证 time_scale 不会卡 0、scaled 时钟必然恢复推进）
	await t.get_tree().create_timer(0.8).timeout
	var arrived := false
	for inv in _invocations:
		if str(inv.get("fx")) == "fly_to_hud_arrived":
			arrived = true
	t.assert_true(arrived, "fly_to_hud emits fly_to_hud_arrived on arrival")
	t.assert_eq(Engine.time_scale, 1.0, "hit_stop restores Engine.time_scale")

	# cleanup：断开仪表连接，释放本地世界（后续 setup() 会重建层）
	VFXManager.vfx_invoked.disconnect(on_vfx)
	target.queue_free()
	world.queue_free()
