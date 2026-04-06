extends RefCounted
## T30 测试：蛇尾链（再生尾 Salamander + 时滞尾 Lag Tail）


func run(t) -> void:
	_test_config(t)
	_test_snake_parts_manager_tail(t)
	_test_atom_registration(t)
	_test_new_atoms(t)
	_test_signals(t)
	_test_trigger_on_segment_loss_deferred(t)
	_test_effect_window_on_cancel(t)
	_test_length_system_block(t)
	_test_apply_status_tail_segment(t)


func _test_config(t) -> void:
	# --- ConfigManager snake_tails ---
	t.assert_true(ConfigManager.snake_tails.size() >= 2, "snake_tails has >= 2 entries")
	t.assert_true(ConfigManager.snake_tails.has("salamander"), "has salamander config")
	t.assert_true(ConfigManager.snake_tails.has("lag_tail"), "has lag_tail config")

	var s1: Dictionary = ConfigManager.get_snake_tail("salamander", 1)
	t.assert_true(s1.has("entity_effects"), "salamander L1 has entity_effects")
	t.assert_true(s1["entity_effects"].size() >= 1, "salamander L1 has >= 1 chain")

	var s2: Dictionary = ConfigManager.get_snake_tail("salamander", 2)
	t.assert_true(s2.has("entity_effects"), "salamander L2 has entity_effects")

	var s3: Dictionary = ConfigManager.get_snake_tail("salamander", 3)
	t.assert_true(s3.has("entity_effects"), "salamander L3 has entity_effects")

	var l1: Dictionary = ConfigManager.get_snake_tail("lag_tail", 1)
	t.assert_true(l1.has("entity_effects"), "lag_tail L1 has entity_effects")
	t.assert_true(l1["entity_effects"].size() >= 3, "lag_tail L1 has >= 3 chains (applied/removed/deferred)")

	var l2: Dictionary = ConfigManager.get_snake_tail("lag_tail", 2)
	t.assert_true(l2["entity_effects"].size() >= 3, "lag_tail L2 has >= 3 chains")

	var l3: Dictionary = ConfigManager.get_snake_tail("lag_tail", 3)
	t.assert_true(l3["entity_effects"].size() >= 3, "lag_tail L3 has >= 3 chains")

	var empty: Dictionary = ConfigManager.get_snake_tail("nonexistent", 1)
	t.assert_eq(empty.size(), 0, "nonexistent tail returns empty dict")

	t.assert_true(ConfigManager.get_snake_tail_ids().size() >= 2, "get_snake_tail_ids >= 2")


func _test_snake_parts_manager_tail(t) -> void:
	# --- SnakePartsManager tail equip/unequip methods ---
	var MgrScript: GDScript = load("res://systems/snake_parts/snake_parts_manager.gd")
	var mgr: Node = MgrScript.new()
	t.assert_true(mgr.has_method("equip_tail"), "has equip_tail method")
	t.assert_true(mgr.has_method("unequip_tail"), "has unequip_tail method")
	t.assert_true(mgr.has_method("get_active_tail"), "has get_active_tail method")
	t.assert_true(mgr.has_method("has_tail"), "has has_tail method")
	t.assert_eq(mgr.has_tail(), false, "no tail initially")
	t.assert_eq(mgr.get_active_tail(), null, "active tail is null initially")


func _test_atom_registration(t) -> void:
	# --- AtomRegistry 新增原子 ---
	var reg: AtomRegistry = AtomRegistry.new()
	t.assert_true(reg.has_atom("request_segment_loss"), "request_segment_loss registered")
	t.assert_true(reg.has_atom("modify_hits_taken"), "modify_hits_taken registered")
	t.assert_true(reg.has_atom("cancel_window"), "cancel_window registered")
	# 保留旧原子检查
	t.assert_true(reg.has_atom("area_damage"), "area_damage still registered")
	t.assert_true(reg.has_atom("burst_carried_status"), "burst_carried_status still registered")
	t.assert_true(reg.has_atom("open_window"), "open_window still registered")
	var names: Array = reg.get_atom_names()
	t.assert_true(names.size() >= 60, "total atoms >= 60, got %d" % names.size())


func _test_new_atoms(t) -> void:
	# --- 新原子基本创建测试 ---
	var reg: AtomRegistry = AtomRegistry.new()

	var rsl: AtomBase = reg.create("request_segment_loss", { "amount": 1 })
	t.assert_true(rsl != null, "request_segment_loss atom created")
	t.assert_true(rsl.has_method("execute"), "request_segment_loss has execute()")

	var mht: AtomBase = reg.create("modify_hits_taken", { "value": -1 })
	t.assert_true(mht != null, "modify_hits_taken atom created")
	t.assert_true(mht.has_method("execute"), "modify_hits_taken has execute()")

	var cw: AtomBase = reg.create("cancel_window", { "window_id": "test" })
	t.assert_true(cw != null, "cancel_window atom created")
	t.assert_true(cw.has_method("execute"), "cancel_window has execute()")


func _test_signals(t) -> void:
	# --- EventBus 新信号 ---
	t.assert_has_signal(EventBus, "segment_loss_deferred")
	t.assert_has_signal(EventBus, "snake_tail_equipped")
	t.assert_has_signal(EventBus, "snake_tail_unequipped")


func _test_trigger_on_segment_loss_deferred(t) -> void:
	# --- TriggerManager 有 _on_segment_loss_deferred 方法 ---
	var TriggerMgrScript: GDScript = load("res://systems/atoms/trigger_manager.gd")
	var tm: Node = TriggerMgrScript.new()
	t.assert_true(tm.has_method("_on_segment_loss_deferred"), "TM has _on_segment_loss_deferred")


func _test_effect_window_on_cancel(t) -> void:
	# --- EffectWindow on_cancel 字段 ---
	var WindowScript: GDScript = load("res://systems/atoms/effect_window.gd")
	var window: RefCounted = WindowScript.new()
	window.init_from_config("test_cancel", {
		"duration_ticks": 5,
		"rules": {},
		"on_expire": [],
		"on_cancel": [{ "atom": "modify_hits_taken", "value": -1 }],
		"cancel_on": "snake_hit_enemy",
	}, null)
	t.assert_eq(window.window_id, "test_cancel", "window_id set")
	t.assert_eq(window.on_cancel.size(), 1, "on_cancel has 1 atom def")
	t.assert_eq(window.on_cancel[0]["atom"], "modify_hits_taken", "on_cancel atom is modify_hits_taken")
	t.assert_eq(window.cancel_on, "snake_hit_enemy", "cancel_on set")


func _test_length_system_block(t) -> void:
	# --- LengthSystem 有 window_mgr 字段 ---
	var ls: LengthSystem = LengthSystem.new()
	t.assert_true("window_mgr" in ls, "LengthSystem has window_mgr field")
	t.assert_eq(ls.window_mgr, null, "window_mgr initially null")


func _test_apply_status_tail_segment(t) -> void:
	# --- ApplyStatusAtom 支持 tail_segment ---
	var reg: AtomRegistry = AtomRegistry.new()
	var atom: AtomBase = reg.create("apply_status", { "status_type": "ice", "apply_to": "tail_segment" })
	t.assert_true(atom != null, "apply_status with tail_segment created")
