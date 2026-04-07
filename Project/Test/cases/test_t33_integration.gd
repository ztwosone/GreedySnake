extends RefCounted
## T33 测试：全系统联调 + Build 测试面板


func run(t) -> void:
	_test_modifier_stacking(t)
	_test_resonance_integration(t)
	_test_cleanup_correctness(t)
	_test_config_consistency(t)
	_test_build_panel_api(t)


# === A 组：修改器叠加 ===

func _test_modifier_stacking(t) -> void:
	var sem = StatusEffectManager
	var chain_resolver = sem._chain_resolver
	var trigger_mgr = sem._trigger_manager

	# 创建 mock snake
	var mock_snake := Node2D.new()
	mock_snake.name = "MockSnake"

	# 创建管理器
	var PartsMgrScript: GDScript = load("res://systems/snake_parts/snake_parts_manager.gd")
	var parts_mgr: Node = PartsMgrScript.new()
	parts_mgr.init_manager(mock_snake, trigger_mgr, chain_resolver)

	var ScaleMgrScript: GDScript = load("res://systems/snake_parts/scale_slot_manager.gd")
	var scale_mgr: Node = ScaleMgrScript.new()
	scale_mgr.init_manager(mock_snake, trigger_mgr, chain_resolver)

	# --- 单头装备：hit_threshold ---
	parts_mgr.equip_head("hydra", 1)
	var ht: float = sem.get_modifier("hit_threshold", mock_snake, 0.0)
	t.assert_eq(ht, -1.0, "[stack] hydra L1 hit_threshold = -1")

	# --- 头+鳞不同参数共存 ---
	scale_mgr.equip_scale("middle", "flame_scale", 1)
	var fad: float = sem.get_modifier("fire_aura_damage", mock_snake, 0.0)
	t.assert_true(fad >= 1.0, "[stack] flame_scale L1 fire_aura_damage >= 1, got %.1f" % fad)
	# 头的 hit_threshold 不受影响
	ht = sem.get_modifier("hit_threshold", mock_snake, 0.0)
	t.assert_eq(ht, -1.0, "[stack] hit_threshold still -1 after scale equip")

	# --- 双鳞同参数叠加 ---
	scale_mgr.open_slot("middle")  # 开放第二个中段槽位
	scale_mgr.equip_scale("middle", "flame_scale", 1)
	fad = sem.get_modifier("fire_aura_damage", mock_snake, 0.0)
	t.assert_true(fad >= 2.0, "[stack] 2x flame_scale fire_aura_damage >= 2, got %.1f" % fad)

	# --- 卸载后归零 ---
	scale_mgr.clear_all()
	fad = sem.get_modifier("fire_aura_damage", mock_snake, 0.0)
	t.assert_true(abs(fad) < 0.01, "[stack] after scale clear fire_aura_damage ~= 0, got %.1f" % fad)

	parts_mgr.unequip_head()
	ht = sem.get_modifier("hit_threshold", mock_snake, 0.0)
	t.assert_true(abs(ht) < 0.01, "[stack] after head unequip hit_threshold ~= 0, got %.1f" % ht)

	# --- 头+尾+鳞三源 food_drop ---
	parts_mgr.equip_head("hydra", 1)
	scale_mgr.equip_scale("front", "greedy_scale", 1)
	var fd_hydra: float = sem.get_modifier("food_drop", mock_snake, 0.0)
	# hydra L1 food_drop = -99, greedy_scale L1 food_drop = +1 → 合计 -98
	t.assert_true(fd_hydra < 0, "[stack] hydra+greedy food_drop < 0, got %.1f" % fd_hydra)

	# --- 重装备不幽灵叠加 ---
	parts_mgr.unequip_head()
	parts_mgr.equip_head("hydra", 1)
	var fd_after: float = sem.get_modifier("food_drop", mock_snake, 0.0)
	t.assert_eq(fd_after, fd_hydra, "[stack] re-equip same food_drop = %.1f" % fd_after)

	# 清理
	parts_mgr.unequip_head()
	scale_mgr.clear_all()
	sem.clear_all()
	parts_mgr.free()
	scale_mgr.free()
	mock_snake.free()


# === B 组：共鸣联动 ===

func _test_resonance_integration(t) -> void:
	var sem = StatusEffectManager
	var chain_resolver = sem._chain_resolver
	var trigger_mgr = sem._trigger_manager

	var mock_snake := Node2D.new()
	mock_snake.name = "MockSnake2"

	var ScaleMgrScript: GDScript = load("res://systems/snake_parts/scale_slot_manager.gd")
	var scale_mgr: Node = ScaleMgrScript.new()
	scale_mgr.init_manager(mock_snake, trigger_mgr, chain_resolver)

	var ResMgrScript: GDScript = load("res://systems/snake_parts/resonance_manager.gd")
	var res_mgr: Node = ResMgrScript.new()
	res_mgr.init_manager(mock_snake, trigger_mgr, chain_resolver, scale_mgr)

	# --- 邻接鳞片触发共鸣 ---
	# flame_scale(middle, fire) + thorn_scale(back, physical) → fire+physical = 炎棘
	scale_mgr.equip_scale("middle", "flame_scale", 1)
	scale_mgr.equip_scale("back", "thorn_scale", 1)

	var active: Array = res_mgr.get_active_resonances()
	t.assert_true(active.has("flame_thorn"), "[res] flame+thorn → flame_thorn active, got %s" % str(active))

	# --- 共鸣 SnakePartData 有链 ---
	var has_chains: bool = false
	for key in res_mgr._active_resonances:
		var pd = res_mgr._active_resonances[key]
		if pd.chains.size() > 0:
			has_chains = true
			break
	t.assert_true(has_chains, "[res] active resonance has non-empty chains")

	# --- 非邻接无共鸣 ---
	scale_mgr.clear_all()
	res_mgr.clear_all()
	# front + back 不邻接
	scale_mgr.equip_scale("front", "predator_scale", 1)
	scale_mgr.equip_scale("back", "thorn_scale", 1)
	active = res_mgr.get_active_resonances()
	t.assert_true(active.is_empty(), "[res] front+back not adjacent → no resonance, got %s" % str(active))

	# --- 同位置可共鸣 ---
	scale_mgr.clear_all()
	res_mgr.clear_all()
	scale_mgr.open_slot("back")
	scale_mgr.equip_scale("back", "thorn_scale", 1)
	scale_mgr.equip_scale("back", "retaliation_scale", 1)
	active = res_mgr.get_active_resonances()
	# thorn(physical) + retaliation(physical) → physical+physical = iron_wall
	t.assert_true(active.has("iron_wall"), "[res] thorn+retaliation same-pos → iron_wall, got %s" % str(active))

	# --- 卸载后共鸣消失 ---
	scale_mgr.unequip_scale("back", 0)
	active = res_mgr.get_active_resonances()
	t.assert_false(active.has("iron_wall"), "[res] after unequip one → iron_wall gone, got %s" % str(active))

	# --- 多 tag 鳞片多共鸣 ---
	scale_mgr.clear_all()
	res_mgr.clear_all()
	# predator(front, fire+ice+poison) + toxin(middle, poison) → fire+poison=沸毒, ice+poison=冻疫
	scale_mgr.equip_scale("front", "predator_scale", 1)
	scale_mgr.equip_scale("middle", "toxin_scale", 1)
	active = res_mgr.get_active_resonances()
	t.assert_true(active.has("boiling_toxin"), "[res] predator+toxin → boiling_toxin, got %s" % str(active))
	t.assert_true(active.has("frozen_plague_res"), "[res] predator+toxin → frozen_plague_res, got %s" % str(active))

	# 清理
	scale_mgr.clear_all()
	res_mgr.clear_all()
	sem.clear_all()
	res_mgr.free()
	scale_mgr.free()
	mock_snake.free()


# === C 组：清理正确性 ===

func _test_cleanup_correctness(t) -> void:
	var sem = StatusEffectManager
	var chain_resolver = sem._chain_resolver
	var trigger_mgr = sem._trigger_manager

	var mock_snake := Node2D.new()
	mock_snake.name = "MockSnake3"

	var PartsMgrScript: GDScript = load("res://systems/snake_parts/snake_parts_manager.gd")
	var parts_mgr: Node = PartsMgrScript.new()
	parts_mgr.init_manager(mock_snake, trigger_mgr, chain_resolver)

	var ScaleMgrScript: GDScript = load("res://systems/snake_parts/scale_slot_manager.gd")
	var scale_mgr: Node = ScaleMgrScript.new()
	scale_mgr.init_manager(mock_snake, trigger_mgr, chain_resolver)

	var ResMgrScript: GDScript = load("res://systems/snake_parts/resonance_manager.gd")
	var res_mgr: Node = ResMgrScript.new()
	res_mgr.init_manager(mock_snake, trigger_mgr, chain_resolver, scale_mgr)

	# 装备全套
	parts_mgr.equip_head("hydra", 1)
	parts_mgr.equip_tail("salamander", 1)
	scale_mgr.equip_scale("middle", "flame_scale", 1)
	scale_mgr.equip_scale("back", "thorn_scale", 1)

	# 验证有东西
	t.assert_true(parts_mgr.has_head(), "[cleanup] has head before cleanup")
	t.assert_true(parts_mgr.has_tail(), "[cleanup] has tail before cleanup")
	t.assert_true(scale_mgr.get_all_scales().size() > 0, "[cleanup] has scales before cleanup")

	# 执行清理序列（模拟 game_world.cleanup）
	res_mgr.clear_all()
	scale_mgr.clear_all()
	parts_mgr.unequip_head()
	parts_mgr.unequip_tail()
	sem.clear_all()

	# 全部归零
	t.assert_false(parts_mgr.has_head(), "[cleanup] no head after cleanup")
	t.assert_false(parts_mgr.has_tail(), "[cleanup] no tail after cleanup")
	t.assert_eq(scale_mgr.get_all_scales().size(), 0, "[cleanup] no scales after cleanup")
	t.assert_eq(res_mgr.get_active_resonances().size(), 0, "[cleanup] no resonances after cleanup")

	# 修改器归零
	var ht: float = sem.get_modifier("hit_threshold", mock_snake, 0.0)
	var fd: float = sem.get_modifier("food_drop", mock_snake, 0.0)
	var fad: float = sem.get_modifier("fire_aura_damage", mock_snake, 0.0)
	t.assert_true(abs(ht) < 0.01, "[cleanup] hit_threshold ~= 0 after cleanup, got %.1f" % ht)
	t.assert_true(abs(fd) < 0.01, "[cleanup] food_drop ~= 0 after cleanup, got %.1f" % fd)
	t.assert_true(abs(fad) < 0.01, "[cleanup] fire_aura_damage ~= 0 after cleanup, got %.1f" % fad)

	# --- 重装备后无幽灵叠加 ---
	parts_mgr.equip_head("hydra", 1)
	ht = sem.get_modifier("hit_threshold", mock_snake, 0.0)
	t.assert_eq(ht, -1.0, "[cleanup] re-equip hydra after cleanup → ht = -1, got %.1f" % ht)

	# 最终清理
	parts_mgr.unequip_head()
	sem.clear_all()
	res_mgr.free()
	scale_mgr.free()
	parts_mgr.free()
	mock_snake.free()


# === D 组：配置一致性 ===

func _test_config_consistency(t) -> void:
	# --- 所有鳞片有 tags 且非空 ---
	var scale_ids: Array = [
		"greedy_scale", "predator_scale", "flame_scale", "toxin_scale",
		"frost_scale", "phantom_scale", "thorn_scale", "regen_scale", "retaliation_scale"
	]
	for sid in scale_ids:
		var tags: Array = ConfigManager.get_scale_tags(sid)
		t.assert_true(tags.size() > 0, "[config] %s has tags, got %s" % [sid, str(tags)])

	# --- 所有鳞片有 position（顶层字段，不在 levels 内） ---
	for sid in scale_ids:
		var raw: Dictionary = ConfigManager.snake_scales.get(sid, {})
		t.assert_true(raw.has("position"), "[config] %s has position" % sid)
		var pos: String = raw.get("position", "")
		t.assert_true(pos in ["front", "middle", "back"], "[config] %s position valid: %s" % [sid, pos])

	# --- 所有鳞片有 display_name（顶层字段） ---
	for sid in scale_ids:
		var raw: Dictionary = ConfigManager.snake_scales.get(sid, {})
		t.assert_true(raw.has("display_name"), "[config] %s has display_name" % sid)

	# --- 等级渐进：L2 效果 >= L1（检查 modify_system_param 的 value） ---
	var param_scales: Array = [
		["flame_scale", "fire_aura_damage"],
		["toxin_scale", "poison_spread_bonus"],
		["frost_scale", "attack_cooldown_bonus"],
		["phantom_scale", "phantom_tail_count"],
	]
	for pair in param_scales:
		var sid: String = pair[0]
		var param: String = pair[1]
		var v1: float = _extract_modify_value(sid, 1, param)
		var v2: float = _extract_modify_value(sid, 2, param)
		t.assert_true(v2 >= v1, "[config] %s L2(%s=%.1f) >= L1(%.1f)" % [sid, param, v2, v1])

	# --- 所有共鸣有 resonance_id + display_name + entity_effects ---
	for key in ConfigManager.tag_resonances:
		var cfg: Dictionary = ConfigManager.tag_resonances[key]
		t.assert_true(cfg.has("resonance_id"), "[config] resonance %s has id" % key)
		t.assert_true(cfg.has("display_name"), "[config] resonance %s has display_name" % key)
		t.assert_true(cfg.has("entity_effects"), "[config] resonance %s has entity_effects" % key)

	# --- 头/尾有 display_name（顶层字段） ---
	for hid in ["hydra", "bai_she"]:
		var raw: Dictionary = ConfigManager.snake_heads.get(hid, {})
		t.assert_true(raw.has("display_name"), "[config] head %s has display_name" % hid)
	for tid in ["salamander", "lag_tail"]:
		var raw: Dictionary = ConfigManager.snake_tails.get(tid, {})
		t.assert_true(raw.has("display_name"), "[config] tail %s has display_name" % tid)


# === E 组：Build 面板 API ===

func _test_build_panel_api(t) -> void:
	var PanelScript: GDScript = load("res://ui/build_test_panel.gd")
	var panel: PanelContainer = PanelScript.new()

	t.assert_true(panel.has_method("setup"), "[panel] has setup()")
	t.assert_true(panel.has_method("_cycle_head"), "[panel] has _cycle_head()")
	t.assert_true(panel.has_method("_cycle_tail"), "[panel] has _cycle_tail()")
	t.assert_true(panel.has_method("_cycle_scale"), "[panel] has _cycle_scale()")
	t.assert_true(panel.has_method("_upgrade_all"), "[panel] has _upgrade_all()")
	t.assert_true(panel.has_method("_clear_all"), "[panel] has _clear_all()")
	t.assert_true(panel.has_method("_refresh"), "[panel] has _refresh()")

	# 常量列表正确
	t.assert_eq(panel.HEAD_LIST.size(), 2, "[panel] HEAD_LIST has 2 entries")
	t.assert_eq(panel.TAIL_LIST.size(), 2, "[panel] TAIL_LIST has 2 entries")
	t.assert_eq(panel.FRONT_SCALE_LIST.size(), 2, "[panel] FRONT_SCALE_LIST has 2 entries")
	t.assert_eq(panel.MIDDLE_SCALE_LIST.size(), 4, "[panel] MIDDLE_SCALE_LIST has 4 entries")
	t.assert_eq(panel.BACK_SCALE_LIST.size(), 3, "[panel] BACK_SCALE_LIST has 3 entries")

	panel.free()


# === 辅助方法 ===

func _extract_modify_value(scale_id: String, level: int, param_name: String) -> float:
	var cfg: Dictionary = ConfigManager.get_snake_scale(scale_id, level)
	if not cfg.has("entity_effects"):
		return 0.0
	for effect in cfg.get("entity_effects", []):
		if effect.get("trigger", "") != "on_applied":
			continue
		for atom in effect.get("atoms", []):
			if atom.get("atom", "") == "modify_system_param" and atom.get("param_name", "") == param_name:
				return atom.get("value", 0.0)
	return 0.0
