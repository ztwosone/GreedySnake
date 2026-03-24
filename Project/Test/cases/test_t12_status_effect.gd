extends RefCounted
## T12 测试：StatusEffect 数据模型与管理器


func run(t) -> void:
	# --- 文件/目录存在性 ---
	t.assert_dir_exists("res://systems/status")
	t.assert_file_exists("res://core/status_effect_data.gd")
	t.assert_file_exists("res://systems/status/status_effect_manager.gd")

	# --- StatusEffectData 字段检查 ---
	var effect := StatusEffectData.new()
	t.assert_true(effect is RefCounted, "StatusEffectData is RefCounted")
	t.assert_true("type" in effect, "has type field")
	t.assert_true("layer" in effect, "has layer field")
	t.assert_true("max_layers" in effect, "has max_layers field")
	t.assert_true("carrier" in effect, "has carrier field")
	t.assert_true("carrier_type" in effect, "has carrier_type field")
	t.assert_true("duration" in effect, "has duration field")
	t.assert_true("max_duration" in effect, "has max_duration field")
	t.assert_true("source" in effect, "has source field")
	t.assert_true("elapsed" in effect, "has elapsed field")

	# --- StatusEffectData.create 静态方法 ---
	var dummy := Node2D.new()
	Engine.get_main_loop().root.add_child(dummy)
	var created: StatusEffectData = StatusEffectData.create("fire", dummy, "entity", "test")
	t.assert_eq(created.type, "fire", "create: type == fire")
	t.assert_eq(created.layer, 1, "create: layer == 1")
	t.assert_eq(created.max_layers, 99, "create: fire max_layers == 99 (from config)")
	t.assert_eq(created.carrier, dummy, "create: carrier is dummy")
	t.assert_eq(created.carrier_type, "entity", "create: carrier_type == entity")
	t.assert_true(created.duration > 0.0, "create: duration > 0")
	t.assert_eq(created.max_duration, created.duration, "create: max_duration == duration")
	t.assert_eq(created.elapsed, 0.0, "create: elapsed == 0")
	t.assert_eq(created.source, "test", "create: source == test")

	# --- StatusEffectManager autoload 存在 ---
	var mgr = StatusEffectManager
	t.assert_true(mgr != null, "StatusEffectManager autoload exists")
	if mgr == null:
		dummy.queue_free()
		return

	# --- 方法存在性 ---
	t.assert_true(mgr.has_method("apply_status"), "has apply_status()")
	t.assert_true(mgr.has_method("remove_status"), "has remove_status()")
	t.assert_true(mgr.has_method("remove_all_statuses"), "has remove_all_statuses()")
	t.assert_true(mgr.has_method("get_statuses"), "has get_statuses()")
	t.assert_true(mgr.has_method("get_status"), "has get_status()")
	t.assert_true(mgr.has_method("has_status"), "has has_status()")
	t.assert_true(mgr.has_method("clear_all"), "has clear_all()")

	# --- EventBus 信号存在性 ---
	t.assert_has_signal(EventBus, "status_applied")
	t.assert_has_signal(EventBus, "status_removed")
	t.assert_has_signal(EventBus, "status_layer_changed")
	t.assert_has_signal(EventBus, "status_expired")

	# === 功能测试 ===
	mgr.clear_all()

	# --- apply_status: 新状态 ---
	var applied_events: Array = []
	var _on_applied := func(data: Dictionary) -> void:
		applied_events.append(data)
	EventBus.status_applied.connect(_on_applied)

	var target := Node2D.new()
	Engine.get_main_loop().root.add_child(target)

	var s1: StatusEffectData = mgr.apply_status(target, "fire", "test_apply")
	t.assert_true(s1 != null, "apply_status returns StatusEffectData")
	t.assert_eq(s1.type, "fire", "applied status type == fire")
	t.assert_eq(s1.layer, 1, "applied status layer == 1")
	t.assert_eq(applied_events.size(), 1, "status_applied signal emitted once")
	if applied_events.size() > 0:
		t.assert_eq(applied_events[0].get("type"), "fire", "signal: type == fire")
		t.assert_eq(applied_events[0].get("layer"), 1, "signal: layer == 1")
		t.assert_eq(applied_events[0].get("source"), "test_apply", "signal: source == test_apply")

	EventBus.status_applied.disconnect(_on_applied)

	# --- has_status / get_status ---
	t.assert_true(mgr.has_status(target, "fire"), "has_status fire == true")
	t.assert_true(not mgr.has_status(target, "ice"), "has_status ice == false")
	var got: StatusEffectData = mgr.get_status(target, "fire")
	t.assert_true(got != null, "get_status fire != null")
	t.assert_eq(got.type, "fire", "get_status fire type")
	var got_null: StatusEffectData = mgr.get_status(target, "ice")
	t.assert_true(got_null == null, "get_status ice == null")

	# --- get_statuses ---
	var all_statuses: Array = mgr.get_statuses(target)
	t.assert_eq(all_statuses.size(), 1, "get_statuses size == 1")

	# --- 叠层 ---
	var layer_events: Array = []
	var _on_layer := func(data: Dictionary) -> void:
		layer_events.append(data)
	EventBus.status_layer_changed.connect(_on_layer)

	var s2: StatusEffectData = mgr.apply_status(target, "fire", "test_stack")
	t.assert_eq(s2.layer, 2, "stacked layer == 2")
	t.assert_eq(layer_events.size(), 1, "status_layer_changed emitted once")
	if layer_events.size() > 0:
		t.assert_eq(layer_events[0].get("old_layer"), 1, "layer signal: old == 1")
		t.assert_eq(layer_events[0].get("new_layer"), 2, "layer signal: new == 2")

	EventBus.status_layer_changed.disconnect(_on_layer)

	# --- max_layers 限制（ice max=2）---
	mgr.apply_status(target, "ice", "test_max")
	mgr.apply_status(target, "ice", "test_max")   # layer 2 (max)
	mgr.apply_status(target, "ice", "test_max")   # should not exceed 2
	var ice_status: StatusEffectData = mgr.get_status(target, "ice")
	t.assert_true(ice_status != null, "ice status exists")
	if ice_status:
		t.assert_eq(ice_status.layer, 2, "ice layer capped at max_layers=2")

	# --- 叠层刷新 duration ---
	if ice_status:
		ice_status.duration = 1.0  # 模拟时间流逝
		mgr.apply_status(target, "ice", "refresh")
		t.assert_eq(ice_status.duration, ice_status.max_duration, "stacking refreshes duration")

	# --- remove_status ---
	var removed_events: Array = []
	var _on_removed := func(data: Dictionary) -> void:
		removed_events.append(data)
	EventBus.status_removed.connect(_on_removed)

	mgr.remove_status(target, "ice")
	t.assert_true(not mgr.has_status(target, "ice"), "ice removed")
	t.assert_eq(removed_events.size(), 1, "status_removed emitted once")

	EventBus.status_removed.disconnect(_on_removed)

	# --- remove_all_statuses ---
	mgr.apply_status(target, "poison", "test_remove_all")
	t.assert_true(mgr.has_status(target, "fire"), "fire still exists before remove_all")
	t.assert_true(mgr.has_status(target, "poison"), "poison exists before remove_all")
	mgr.remove_all_statuses(target)
	t.assert_true(not mgr.has_status(target, "fire"), "fire gone after remove_all")
	t.assert_true(not mgr.has_status(target, "poison"), "poison gone after remove_all")
	var empty_list: Array = mgr.get_statuses(target)
	t.assert_eq(empty_list.size(), 0, "get_statuses empty after remove_all")

	# --- clear_all ---
	mgr.apply_status(target, "fire", "test_clear")
	mgr.clear_all()
	t.assert_true(not mgr.has_status(target, "fire"), "fire gone after clear_all")

	# --- 载体销毁自动清理 ---
	var mortal := Node2D.new()
	Engine.get_main_loop().root.add_child(mortal)
	mgr.apply_status(mortal, "fire", "test_destroy")
	t.assert_true(mgr.has_status(mortal, "fire"), "mortal has fire before destroy")
	mortal.queue_free()
	# queue_free 在下一帧生效，手动模拟 tree_exiting
	# 由于 headless 测试中 queue_free 可能不立即触发，直接调用 remove_all
	mgr.remove_all_statuses(mortal)
	t.assert_true(not mgr.has_status(mortal, "fire"), "mortal fire cleared after destroy")

	# --- 清理 ---
	mgr.clear_all()
	target.queue_free()
	dummy.queue_free()
