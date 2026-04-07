extends RefCounted
## T31 测试：ScaleSystem 槽位管理 + 9 鳞片


func run(t) -> void:
	_test_config(t)
	_test_scale_slot_manager(t)
	_test_atom_registration(t)
	_test_new_atoms(t)
	_test_signals(t)
	_test_modifier_keys(t)
	_test_segment_effect_system(t)
	_test_enemy_brain_phantom(t)
	_test_snake_part_data_position(t)


func _test_config(t) -> void:
	# --- ConfigManager snake_scales ---
	t.assert_true(ConfigManager.snake_scales.size() >= 9, "snake_scales has >= 9 entries, got %d" % ConfigManager.snake_scales.size())

	# 前段鳞片
	t.assert_true(ConfigManager.snake_scales.has("greedy_scale"), "has greedy_scale")
	t.assert_true(ConfigManager.snake_scales.has("predator_scale"), "has predator_scale")
	# 中段鳞片
	t.assert_true(ConfigManager.snake_scales.has("flame_scale"), "has flame_scale")
	t.assert_true(ConfigManager.snake_scales.has("toxin_scale"), "has toxin_scale")
	t.assert_true(ConfigManager.snake_scales.has("frost_scale"), "has frost_scale")
	t.assert_true(ConfigManager.snake_scales.has("phantom_scale"), "has phantom_scale")
	# 后段鳞片
	t.assert_true(ConfigManager.snake_scales.has("thorn_scale"), "has thorn_scale")
	t.assert_true(ConfigManager.snake_scales.has("regen_scale"), "has regen_scale")
	t.assert_true(ConfigManager.snake_scales.has("retaliation_scale"), "has retaliation_scale")

	# 每片有 3 级
	for scale_id in ConfigManager.snake_scales.keys():
		for lv in [1, 2, 3]:
			var cfg: Dictionary = ConfigManager.get_snake_scale(scale_id, lv)
			t.assert_true(cfg.has("entity_effects"), "%s L%d has entity_effects" % [scale_id, lv])

	var empty: Dictionary = ConfigManager.get_snake_scale("nonexistent", 1)
	t.assert_eq(empty.size(), 0, "nonexistent scale returns empty dict")

	t.assert_true(ConfigManager.get_snake_scale_ids().size() >= 9, "get_snake_scale_ids >= 9")


func _test_scale_slot_manager(t) -> void:
	# --- ScaleSlotManager ---
	var MgrScript: GDScript = load("res://systems/snake_parts/scale_slot_manager.gd")
	var mgr: Node = MgrScript.new()
	t.assert_true(mgr.has_method("equip_scale"), "has equip_scale")
	t.assert_true(mgr.has_method("unequip_scale"), "has unequip_scale")
	t.assert_true(mgr.has_method("upgrade_scale"), "has upgrade_scale")
	t.assert_true(mgr.has_method("get_scales"), "has get_scales")
	t.assert_true(mgr.has_method("get_all_scales"), "has get_all_scales")
	t.assert_true(mgr.has_method("has_open_slot"), "has has_open_slot")
	t.assert_true(mgr.has_method("open_slot"), "has open_slot")
	t.assert_true(mgr.has_method("clear_all"), "has clear_all")


func _test_atom_registration(t) -> void:
	# --- AtomRegistry 新增原子 ---
	var reg: AtomRegistry = AtomRegistry.new()
	t.assert_true(reg.has_atom("modify_system_param"), "modify_system_param registered")
	t.assert_true(reg.has_atom("damage_attacker"), "damage_attacker registered")
	t.assert_true(reg.has_atom("knockback_attacker"), "knockback_attacker registered")
	t.assert_true(reg.has_atom("knockback_with_damage"), "knockback_with_damage registered")
	t.assert_true(reg.has_atom("spread_status_to_segments"), "spread_status_to_segments registered")
	t.assert_true(reg.has_atom("ice_wave"), "ice_wave registered")
	# 保留旧检查
	t.assert_true(reg.has_atom("request_segment_loss"), "request_segment_loss still registered")
	t.assert_true(reg.has_atom("cancel_window"), "cancel_window still registered")
	var names: Array = reg.get_atom_names()
	t.assert_true(names.size() >= 66, "total atoms >= 66, got %d" % names.size())


func _test_new_atoms(t) -> void:
	var reg: AtomRegistry = AtomRegistry.new()

	var msp: AtomBase = reg.create("modify_system_param", { "param_name": "fire_aura_damage", "value": 1 })
	t.assert_true(msp != null, "modify_system_param atom created")
	t.assert_true(msp.has_method("execute"), "modify_system_param has execute()")

	var da: AtomBase = reg.create("damage_attacker", { "amount": 2 })
	t.assert_true(da != null, "damage_attacker atom created")

	var ka: AtomBase = reg.create("knockback_attacker", { "distance": 2 })
	t.assert_true(ka != null, "knockback_attacker atom created")

	var kwd: AtomBase = reg.create("knockback_with_damage", { "distance": 3, "path_damage": 1 })
	t.assert_true(kwd != null, "knockback_with_damage atom created")

	var ssts: AtomBase = reg.create("spread_status_to_segments", { "count": 3 })
	t.assert_true(ssts != null, "spread_status_to_segments atom created")

	var iw: AtomBase = reg.create("ice_wave", { "radius": 1 })
	t.assert_true(iw != null, "ice_wave atom created")


func _test_signals(t) -> void:
	# --- EventBus 新信号 ---
	t.assert_has_signal(EventBus, "snake_scale_equipped")
	t.assert_has_signal(EventBus, "snake_scale_unequipped")


func _test_modifier_keys(t) -> void:
	# --- StatusEffectManager 新 modifier keys ---
	t.assert_true(StatusEffectManager._active_modifiers.has("fire_aura_damage"), "has fire_aura_damage modifier")
	t.assert_true(StatusEffectManager._active_modifiers.has("fire_aura_range"), "has fire_aura_range modifier")
	t.assert_true(StatusEffectManager._active_modifiers.has("poison_spread_bonus"), "has poison_spread_bonus modifier")
	t.assert_true(StatusEffectManager._active_modifiers.has("poison_tile_damage"), "has poison_tile_damage modifier")
	t.assert_true(StatusEffectManager._active_modifiers.has("attack_cooldown_bonus"), "has attack_cooldown_bonus modifier")
	t.assert_true(StatusEffectManager._active_modifiers.has("phantom_tail_count"), "has phantom_tail_count modifier")

	# get_modifier 默认值
	var mock = RefCounted.new()
	t.assert_eq(StatusEffectManager.get_modifier("fire_aura_damage", mock, 0.0), 0.0, "fire_aura_damage default 0")
	t.assert_eq(StatusEffectManager.get_modifier("phantom_tail_count", mock, 0.0), 0.0, "phantom_tail_count default 0")

	# set + get
	StatusEffectManager.set_modifier("fire_aura_damage", mock, 2.0)
	t.assert_eq(StatusEffectManager.get_modifier("fire_aura_damage", mock, 0.0), 2.0, "fire_aura_damage after set = 2.0")
	StatusEffectManager.clear_modifier("fire_aura_damage", mock)
	t.assert_eq(StatusEffectManager.get_modifier("fire_aura_damage", mock, 0.0), 0.0, "fire_aura_damage after clear = 0.0")


func _test_segment_effect_system(t) -> void:
	# --- SegmentEffectSystem 有毒格伤害方法 ---
	var ses: SegmentEffectSystem = SegmentEffectSystem.new()
	t.assert_true(ses.has_method("_process_poison_tile_damage"), "SegmentEffectSystem has _process_poison_tile_damage")


func _test_enemy_brain_phantom(t) -> void:
	# --- EnemyBrain _find_attackable_segment 方法存在 ---
	var BrainScript: GDScript = load("res://entities/enemies/enemy_brain.gd")
	var brain = BrainScript.new()
	t.assert_true(brain.has_method("_find_attackable_segment"), "EnemyBrain has _find_attackable_segment")


func _test_snake_part_data_position(t) -> void:
	# --- SnakePartData position 字段 ---
	var PartScript: GDScript = load("res://systems/snake_parts/snake_part_data.gd")
	var part = PartScript.new()
	part.init_data("scale", "flame_scale", 1, null, [])
	part.position = "middle"
	t.assert_eq(part.part_type, "scale", "part_type == scale")
	t.assert_eq(part.part_id, "flame_scale", "part_id == flame_scale")
	t.assert_eq(part.position, "middle", "position == middle")
