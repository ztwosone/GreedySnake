extends RefCounted
## T03 测试：TickManager 节拍管理器
## SpecKit 004 T006: manual_mode + step_once() 仪表缝（presentation_design.md §11.4）


func run(t) -> void:
	t.assert_file_exists("res://autoloads/tick_manager.gd")

	# --- Method existence ---
	t.assert_true(TickManager.has_method("start_ticking"), "has start_ticking()")
	t.assert_true(TickManager.has_method("stop_ticking"), "has stop_ticking()")
	t.assert_true(TickManager.has_method("pause"), "has pause()")
	t.assert_true(TickManager.has_method("resume"), "has resume()")
	t.assert_true(TickManager.has_method("get_effective_interval"), "has get_effective_interval()")

	# --- Default property values ---
	t.assert_eq(TickManager.base_tick_interval, 0.25, "base_tick_interval == 0.25")
	t.assert_eq(TickManager.tick_speed_modifier, 1.0, "tick_speed_modifier == 1.0")
	t.assert_eq(TickManager.is_ticking, false, "is_ticking default == false")

	# --- Effective interval calculation ---
	t.assert_eq(TickManager.get_effective_interval(), 0.25, "effective interval at 1x == 0.25")
	TickManager.tick_speed_modifier = 2.0
	t.assert_eq(TickManager.get_effective_interval(), 0.125, "effective interval at 2x == 0.125")
	TickManager.tick_speed_modifier = 1.0  # reset

	# --- Tick event emission (quick sync test) ---
	var ticks_received := []
	var on_post := func(tick_index: int) -> void:
		ticks_received.append(tick_index)
	EventBus.tick_post_process.connect(on_post)

	TickManager.start_ticking()
	t.assert_eq(TickManager.is_ticking, true, "is_ticking == true after start")
	t.assert_eq(TickManager.current_tick, 0, "current_tick reset to 0 on start")

	TickManager.stop_ticking()
	t.assert_eq(TickManager.is_ticking, false, "is_ticking == false after stop")

	EventBus.tick_post_process.disconnect(on_post)

	# --- T006: manual_mode + step_once() 仪表缝（§11.4：挂单例，不挂 EventBus） ---
	t.assert_true("manual_mode" in TickManager, "has manual_mode property")
	t.assert_true(TickManager.has_method("step_once"), "has step_once()")
	if not (("manual_mode" in TickManager) and TickManager.has_method("step_once")):
		return

	t.assert_eq(TickManager.manual_mode, false, "manual_mode default == false")

	var pre_ticks: Array = []
	var post_ticks: Array = []
	var on_pre := func(tick_index: int) -> void:
		pre_ticks.append(tick_index)
	var on_post_manual := func(tick_index: int) -> void:
		post_ticks.append(tick_index)
	EventBus.tick_pre_process.connect(on_pre)
	EventBus.tick_post_process.connect(on_post_manual)

	# manual_mode 下 start_ticking 不启动 Timer（不自走拍），但 is_ticking 照常置位
	TickManager.manual_mode = true
	TickManager.start_ticking()
	t.assert_eq(TickManager.is_ticking, true, "manual start: is_ticking == true")
	t.assert_eq(TickManager.current_tick, 0, "manual start: current_tick reset to 0")
	t.assert_true(TickManager._timer.is_stopped(), "manual start: Timer NOT started (no auto-tick)")
	t.assert_eq(post_ticks.size(), 0, "manual start: no tick emitted before step_once")

	# step_once 推进一拍并发完整 tick 信号序列
	t.assert_eq(TickManager.step_once(), true, "step_once returns true while ticking")
	t.assert_eq(TickManager.current_tick, 1, "step_once advances current_tick to 1")
	t.assert_eq(pre_ticks, [0], "step_once emits tick_pre_process(0)")
	t.assert_eq(post_ticks, [0], "step_once emits tick_post_process(0)")

	# pause 期间 step_once 无效（暂停语义：is_ticking == false 时步进被拒绝）
	TickManager.pause()
	t.assert_eq(TickManager.step_once(), false, "step_once returns false while paused")
	t.assert_eq(TickManager.current_tick, 1, "paused step does not advance current_tick")
	t.assert_eq(post_ticks.size(), 1, "paused step emits no tick signals")

	# resume 后步进恢复
	TickManager.resume()
	t.assert_eq(TickManager.step_once(), true, "step_once works after resume")
	t.assert_eq(TickManager.current_tick, 2, "resumed step advances current_tick to 2")
	t.assert_eq(post_ticks, [0, 1], "resumed step emits tick_post_process(1)")

	# 非 manual_mode 时 step_once 拒绝（仪表缝不干扰正常运行）
	TickManager.manual_mode = false
	t.assert_eq(TickManager.step_once(), false, "step_once returns false when manual_mode off")
	t.assert_eq(TickManager.current_tick, 2, "non-manual step does not advance")

	# cleanup：恢复单例默认态
	TickManager.stop_ticking()
	TickManager.manual_mode = false
	EventBus.tick_pre_process.disconnect(on_pre)
	EventBus.tick_post_process.disconnect(on_post_manual)
