extends RefCounted
## T27 测试：EffectWindow 时间窗口框架


func run(t) -> void:
	# --- 文件存在性 ---
	t.assert_file_exists("res://systems/atoms/effect_window.gd")
	t.assert_file_exists("res://systems/atoms/effect_window_manager.gd")
	t.assert_file_exists("res://systems/atoms/atoms/temporal/open_window_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/logic/if_in_window_atom.gd")

	# --- EventBus 信号 ---
	t.assert_has_signal(EventBus, "window_opened")
	t.assert_has_signal(EventBus, "window_expired")
	t.assert_has_signal(EventBus, "window_cancelled")

	# --- EffectWindow 数据类 ---
	var config := {
		"duration_ticks": 5,
		"rules": { "ignore_hit": true, "damage_mult": 2.0 },
		"on_expire": [],
		"cancel_on": "",
	}
	var WindowScript: GDScript = load("res://systems/atoms/effect_window.gd")
	var window = WindowScript.new()
	window.window_id = "test_window"
	window.duration_ticks = 5
	window.remaining_ticks = 5
	window.rules = config.get("rules", {})
	window.on_expire = config.get("on_expire", [])
	window.cancel_on = config.get("cancel_on", "")
	t.assert_eq(window.window_id, "test_window", "window_id correct")
	t.assert_eq(window.duration_ticks, 5, "duration_ticks == 5")
	t.assert_eq(window.remaining_ticks, 5, "remaining_ticks == 5")
	t.assert_eq(window.rules.get("ignore_hit"), true, "rules.ignore_hit == true")
	t.assert_eq(window.rules.get("damage_mult"), 2.0, "rules.damage_mult == 2.0")

	# --- EffectWindowManager 基本 API ---
	var MgrScript: GDScript = load("res://systems/atoms/effect_window_manager.gd")
	var mgr: Node = MgrScript.new()
	Engine.get_main_loop().root.add_child(mgr)

	t.assert_true(mgr.has_method("open_window"), "has open_window()")
	t.assert_true(mgr.has_method("cancel_window"), "has cancel_window()")
	t.assert_true(mgr.has_method("is_active"), "has is_active()")
	t.assert_true(mgr.has_method("get_rule"), "has get_rule()")
	t.assert_true(mgr.has_method("clear_all"), "has clear_all()")

	# --- open_window + is_active ---
	var opened_events: Array = []
	var _on_opened := func(data: Dictionary) -> void:
		opened_events.append(data)
	EventBus.window_opened.connect(_on_opened)

	mgr.open_window("invuln", { "duration_ticks": 3, "rules": { "block_damage": true } }, null)
	t.assert_true(mgr.is_active("invuln"), "invuln is active after open")
	t.assert_true(not mgr.is_active("nonexistent"), "nonexistent is not active")
	t.assert_eq(opened_events.size(), 1, "window_opened emitted")

	# --- get_rule ---
	t.assert_eq(mgr.get_rule("block_damage", false), true, "get_rule block_damage == true")
	t.assert_eq(mgr.get_rule("nonexistent", 42), 42, "get_rule nonexistent returns default")

	# --- 重复开窗口 → 刷新 remaining ---
	mgr.open_window("invuln", { "duration_ticks": 10 }, null)
	t.assert_true(mgr.is_active("invuln"), "invuln still active after refresh")
	t.assert_eq(opened_events.size(), 1, "refresh does not emit window_opened again")

	# --- 多窗口并存 ---
	mgr.open_window("speed_boost", { "duration_ticks": 5, "rules": { "speed_mult": 1.5 } }, null)
	t.assert_true(mgr.is_active("invuln"), "invuln still active")
	t.assert_true(mgr.is_active("speed_boost"), "speed_boost active")
	t.assert_eq(mgr.get_rule("speed_mult", 1.0), 1.5, "speed_mult from speed_boost")

	# --- cancel_window ---
	var cancelled_events: Array = []
	var _on_cancelled := func(data: Dictionary) -> void:
		cancelled_events.append(data)
	EventBus.window_cancelled.connect(_on_cancelled)

	mgr.cancel_window("invuln", "test")
	t.assert_true(not mgr.is_active("invuln"), "invuln cancelled")
	t.assert_true(mgr.is_active("speed_boost"), "speed_boost unaffected")
	t.assert_eq(cancelled_events.size(), 1, "window_cancelled emitted")
	if cancelled_events.size() > 0:
		t.assert_eq(cancelled_events[0].get("reason"), "test", "cancel reason correct")

	# --- tick 递减 + 到期 ---
	var expired_events: Array = []
	var _on_expired := func(data: Dictionary) -> void:
		expired_events.append(data)
	EventBus.window_expired.connect(_on_expired)

	mgr.clear_all()
	mgr.open_window("short", { "duration_ticks": 2, "rules": { "test_rule": true } }, null)
	t.assert_true(mgr.is_active("short"), "short window active")

	# tick 1
	mgr._on_tick(1)
	t.assert_true(mgr.is_active("short"), "short still active after tick 1")

	# tick 2 → 到期
	mgr._on_tick(2)
	t.assert_true(not mgr.is_active("short"), "short expired after tick 2")
	t.assert_eq(expired_events.size(), 1, "window_expired emitted")
	if expired_events.size() > 0:
		t.assert_eq(expired_events[0].get("window_id"), "short", "expired window_id == short")

	# --- cancel_on 信号取消 ---
	mgr.clear_all()
	cancelled_events.clear()
	mgr.open_window("cancel_test", {
		"duration_ticks": 100,
		"cancel_on": "snake_turned",
	}, null)
	t.assert_true(mgr.is_active("cancel_test"), "cancel_test active")

	# 触发 cancel_on 信号
	EventBus.snake_turned.emit({ "old_dir": Vector2i.RIGHT, "new_dir": Vector2i.UP })
	t.assert_true(not mgr.is_active("cancel_test"), "cancel_test cancelled by snake_turned")
	t.assert_eq(cancelled_events.size(), 1, "cancelled by signal")

	# --- clear_all ---
	mgr.open_window("a", { "duration_ticks": 10 }, null)
	mgr.open_window("b", { "duration_ticks": 10 }, null)
	mgr.clear_all()
	t.assert_true(not mgr.is_active("a"), "a cleared")
	t.assert_true(not mgr.is_active("b"), "b cleared")

	# --- open_window_atom ---
	var registry := AtomRegistry.new()
	t.assert_true(registry.has_atom("open_window"), "open_window atom registered")
	t.assert_true(registry.has_atom("if_in_window"), "if_in_window atom registered")

	var atom = registry.create("open_window", {
		"window_id": "atom_test",
		"duration_ticks": 3,
		"rules": { "atom_rule": true },
	})
	var ctx := AtomContext.new()
	ctx.window_mgr = mgr
	atom.execute(ctx)
	t.assert_true(mgr.is_active("atom_test"), "open_window atom opens window")
	t.assert_eq(mgr.get_rule("atom_rule", false), true, "atom_rule queryable")

	# --- if_in_window_atom ---
	var cond_atom = registry.create("if_in_window", { "window_id": "atom_test" })
	t.assert_true(cond_atom.is_condition(), "if_in_window is condition")
	t.assert_true(cond_atom.evaluate(ctx), "if_in_window returns true when active")

	var cond_atom2 = registry.create("if_in_window", { "window_id": "nonexistent" })
	t.assert_true(not cond_atom2.evaluate(ctx), "if_in_window returns false when inactive")

	# --- 清理 ---
	EventBus.window_opened.disconnect(_on_opened)
	EventBus.window_cancelled.disconnect(_on_cancelled)
	EventBus.window_expired.disconnect(_on_expired)
	mgr.clear_all()
	mgr.queue_free()
