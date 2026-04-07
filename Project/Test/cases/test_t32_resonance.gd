extends RefCounted
## T32 测试：邻接共鸣系统


func run(t) -> void:
	_test_config(t)
	_test_resonance_manager_api(t)
	_test_adjacency_logic(t)
	_test_tag_pair_lookup(t)
	_test_override_lookup(t)
	_test_atom_registration(t)
	_test_new_atoms(t)
	_test_signals(t)
	_test_chain_resolution(t)


func _test_config(t) -> void:
	# --- tag_resonances 加载 ---
	t.assert_true(ConfigManager.tag_resonances.size() >= 11, "tag_resonances has >= 11 entries, got %d" % ConfigManager.tag_resonances.size())

	# 每条有必要字段
	for key in ConfigManager.tag_resonances:
		var cfg: Dictionary = ConfigManager.tag_resonances[key]
		t.assert_true(cfg.has("resonance_id"), "%s has resonance_id" % key)
		t.assert_true(cfg.has("display_name"), "%s has display_name" % key)
		t.assert_true(cfg.has("entity_effects"), "%s has entity_effects" % key)

	# 验证具体共鸣
	t.assert_true(ConfigManager.tag_resonances.has("fire+poison"), "has fire+poison")
	t.assert_true(ConfigManager.tag_resonances.has("fire+ice"), "has fire+ice")
	t.assert_true(ConfigManager.tag_resonances.has("ice+poison"), "has ice+poison")
	t.assert_true(ConfigManager.tag_resonances.has("fire+physical"), "has fire+physical")
	t.assert_true(ConfigManager.tag_resonances.has("ice+physical"), "has ice+physical")
	t.assert_true(ConfigManager.tag_resonances.has("fire+void"), "has fire+void")
	t.assert_true(ConfigManager.tag_resonances.has("poison+void"), "has poison+void")
	t.assert_true(ConfigManager.tag_resonances.has("fire+recovery"), "has fire+recovery")
	t.assert_true(ConfigManager.tag_resonances.has("ice+recovery"), "has ice+recovery")
	t.assert_true(ConfigManager.tag_resonances.has("physical+physical"), "has physical+physical")
	t.assert_true(ConfigManager.tag_resonances.has("physical+poison"), "has physical+poison")

	# scale_resonance_overrides 存在（当前为空）
	t.assert_true(ConfigManager.scale_resonance_overrides is Dictionary, "scale_resonance_overrides is Dict")

	# get_tag_resonance_ids
	t.assert_true(ConfigManager.get_tag_resonance_ids().size() >= 11, "get_tag_resonance_ids >= 11")


func _test_resonance_manager_api(t) -> void:
	# --- ResonanceManager 结构 ---
	var MgrScript: GDScript = load("res://systems/snake_parts/resonance_manager.gd")
	var mgr: Node = MgrScript.new()
	t.assert_true(mgr.has_method("init_manager"), "has init_manager")
	t.assert_true(mgr.has_method("get_active_resonances"), "has get_active_resonances")
	t.assert_true(mgr.has_method("is_resonance_discovered"), "has is_resonance_discovered")
	t.assert_true(mgr.has_method("clear_all"), "has clear_all")
	t.assert_true(mgr.has_method("_recalculate_resonances"), "has _recalculate_resonances")
	t.assert_true(mgr.has_method("_are_adjacent"), "has _are_adjacent")


func _test_adjacency_logic(t) -> void:
	# --- 邻接判断 ---
	var MgrScript: GDScript = load("res://systems/snake_parts/resonance_manager.gd")
	var mgr: Node = MgrScript.new()

	# 位置级邻接
	t.assert_true(mgr._are_adjacent("front", "middle"), "front-middle adjacent")
	t.assert_true(mgr._are_adjacent("middle", "front"), "middle-front adjacent")
	t.assert_true(mgr._are_adjacent("middle", "back"), "middle-back adjacent")
	t.assert_true(mgr._are_adjacent("back", "middle"), "back-middle adjacent")

	# 同位置
	t.assert_true(mgr._are_adjacent("front", "front"), "front-front adjacent")
	t.assert_true(mgr._are_adjacent("middle", "middle"), "middle-middle adjacent")
	t.assert_true(mgr._are_adjacent("back", "back"), "back-back adjacent")

	# 不邻接
	t.assert_true(not mgr._are_adjacent("front", "back"), "front-back NOT adjacent")
	t.assert_true(not mgr._are_adjacent("back", "front"), "back-front NOT adjacent")


func _test_tag_pair_lookup(t) -> void:
	# --- 双向 tag pair 查找 ---
	var res1: Dictionary = ConfigManager.find_tag_resonance("fire", "poison")
	t.assert_true(not res1.is_empty(), "find fire+poison")
	t.assert_eq(res1.get("resonance_id", ""), "boiling_toxin", "fire+poison = boiling_toxin")

	var res1r: Dictionary = ConfigManager.find_tag_resonance("poison", "fire")
	t.assert_true(not res1r.is_empty(), "find poison+fire (reverse)")
	t.assert_eq(res1r.get("resonance_id", ""), "boiling_toxin", "poison+fire = boiling_toxin (reverse)")

	var res2: Dictionary = ConfigManager.find_tag_resonance("fire", "ice")
	t.assert_eq(res2.get("resonance_id", ""), "steam_burst", "fire+ice = steam_burst")

	var res3: Dictionary = ConfigManager.find_tag_resonance("physical", "physical")
	t.assert_eq(res3.get("resonance_id", ""), "iron_wall", "physical+physical = iron_wall")

	# 不存在的组合
	var res_none: Dictionary = ConfigManager.find_tag_resonance("void", "recovery")
	t.assert_true(res_none.is_empty(), "void+recovery returns empty")

	# get_scale_tags
	var flame_tags: Array = ConfigManager.get_scale_tags("flame_scale")
	t.assert_true(flame_tags.has("fire"), "flame_scale has fire tag")
	var predator_tags: Array = ConfigManager.get_scale_tags("predator_scale")
	t.assert_true(predator_tags.size() >= 3, "predator_scale has >= 3 tags")
	t.assert_true(predator_tags.has("fire"), "predator has fire")
	t.assert_true(predator_tags.has("ice"), "predator has ice")
	t.assert_true(predator_tags.has("poison"), "predator has poison")


func _test_override_lookup(t) -> void:
	# --- Override 查找（当前为空） ---
	var res: Dictionary = ConfigManager.find_scale_resonance_override("flame_scale", "toxin_scale")
	t.assert_true(res.is_empty(), "no override for flame+toxin")


func _test_atom_registration(t) -> void:
	# --- AtomRegistry 新增原子 ---
	var reg: AtomRegistry = AtomRegistry.new()
	t.assert_true(reg.has_atom("apply_status_in_radius"), "apply_status_in_radius registered")
	t.assert_true(reg.has_atom("place_tile_at_attacker"), "place_tile_at_attacker registered")
	# 保留旧检查
	t.assert_true(reg.has_atom("modify_system_param"), "modify_system_param still registered")
	t.assert_true(reg.has_atom("ice_wave"), "ice_wave still registered")
	var names: Array = reg.get_atom_names()
	t.assert_true(names.size() >= 68, "total atoms >= 68, got %d" % names.size())


func _test_new_atoms(t) -> void:
	var reg: AtomRegistry = AtomRegistry.new()

	var asir: AtomBase = reg.create("apply_status_in_radius", { "type": "ice", "radius": 3, "count": 1 })
	t.assert_true(asir != null, "apply_status_in_radius atom created")
	t.assert_true(asir.has_method("execute"), "apply_status_in_radius has execute()")

	var ptaa: AtomBase = reg.create("place_tile_at_attacker", { "type": "fire", "layer": 1 })
	t.assert_true(ptaa != null, "place_tile_at_attacker atom created")
	t.assert_true(ptaa.has_method("execute"), "place_tile_at_attacker has execute()")


func _test_signals(t) -> void:
	# --- EventBus 新信号 ---
	t.assert_has_signal(EventBus, "resonance_activated")
	t.assert_has_signal(EventBus, "resonance_deactivated")


func _test_chain_resolution(t) -> void:
	# --- 每个共鸣 config 能被 EffectChainResolver 解析 ---
	var reg: AtomRegistry = AtomRegistry.new()
	var resolver := EffectChainResolver.new(reg)

	for key in ConfigManager.tag_resonances:
		var cfg: Dictionary = ConfigManager.tag_resonances[key]
		var chains: Array = resolver.resolve_all(cfg)
		t.assert_true(chains.size() > 0, "resonance %s resolves to non-empty chains" % key)
