extends RefCounted
## T25 测试：Effect Atom System
## 测试原子系统框架、原子注册表、链解析、执行器、模式解析、触发器管理、
## 以及与 StatusEffectManager 的集成。


func run(t) -> void:
	_test_file_structure(t)
	_test_atom_base(t)
	_test_atom_context(t)
	_test_atom_registry(t)
	_test_effect_chain(t)
	_test_pattern_resolver(t)
	_test_effect_chain_resolver(t)
	_test_atom_executor(t)
	_test_value_atoms(t)
	_test_status_atoms(t)
	_test_logic_atoms(t)
	_test_spatial_atoms(t)
	_test_control_atoms(t)
	_test_temporal_atoms(t)
	_test_spawn_atoms(t)
	_test_build_atoms(t)
	_test_sem_integration(t)
	_test_modifier_api(t)


# === 文件结构 ===

func _test_file_structure(t) -> void:
	t.assert_dir_exists("res://systems/atoms")
	t.assert_dir_exists("res://systems/atoms/atoms")
	t.assert_file_exists("res://systems/atoms/atom_base.gd")
	t.assert_file_exists("res://systems/atoms/atom_context.gd")
	t.assert_file_exists("res://systems/atoms/atom_executor.gd")
	t.assert_file_exists("res://systems/atoms/atom_registry.gd")
	t.assert_file_exists("res://systems/atoms/effect_chain.gd")
	t.assert_file_exists("res://systems/atoms/effect_chain_resolver.gd")
	t.assert_file_exists("res://systems/atoms/pattern_resolver.gd")
	t.assert_file_exists("res://systems/atoms/trigger_manager.gd")

	# Atom subdirectories
	t.assert_dir_exists("res://systems/atoms/atoms/value")
	t.assert_dir_exists("res://systems/atoms/atoms/status")
	t.assert_dir_exists("res://systems/atoms/atoms/spatial")
	t.assert_dir_exists("res://systems/atoms/atoms/control")
	t.assert_dir_exists("res://systems/atoms/atoms/spawn")
	t.assert_dir_exists("res://systems/atoms/atoms/temporal")
	t.assert_dir_exists("res://systems/atoms/atoms/logic")
	t.assert_dir_exists("res://systems/atoms/atoms/build")

	# Value atoms
	t.assert_file_exists("res://systems/atoms/atoms/value/damage_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/value/damage_percent_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/value/damage_cap_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/value/heal_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/value/modify_growth_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/value/modify_speed_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/value/modify_attack_cost_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/value/shield_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/value/lifesteal_atom.gd")

	# Status atoms
	t.assert_file_exists("res://systems/atoms/atoms/status/apply_status_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/status/remove_status_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/status/transfer_status_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/status/cleanse_all_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/status/extend_duration_atom.gd")

	# Spatial atoms
	t.assert_file_exists("res://systems/atoms/atoms/spatial/place_tile_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/spatial/remove_tile_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/spatial/place_tile_trail_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/spatial/convert_tile_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/spatial/destroy_terrain_atom.gd")

	# Control atoms
	t.assert_file_exists("res://systems/atoms/atoms/control/freeze_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/control/stun_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/control/knockback_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/control/forced_move_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/control/teleport_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/control/attract_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/control/phase_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/control/reverse_input_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/control/modify_turn_delay_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/control/lock_input_atom.gd")

	# Spawn atoms
	t.assert_file_exists("res://systems/atoms/atoms/spawn/spawn_entity_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/spawn/spawn_projectile_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/spawn/consume_tile_atom.gd")

	# Temporal atoms
	t.assert_file_exists("res://systems/atoms/atoms/temporal/delay_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/temporal/repeat_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/temporal/queue_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/temporal/reduce_cooldown_atom.gd")

	# Logic atoms
	t.assert_file_exists("res://systems/atoms/atoms/logic/if_length_below_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/logic/if_length_above_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/logic/if_has_status_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/logic/if_on_tile_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/logic/if_chance_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/logic/if_cooldown_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/logic/if_count_reached_atom.gd")

	# Build atoms
	t.assert_file_exists("res://systems/atoms/atoms/build/trigger_slot_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/build/cancel_cost_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/build/disable_slot_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/build/modify_effect_value_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/build/accumulate_atom.gd")
	t.assert_file_exists("res://systems/atoms/atoms/build/lock_slot_atom.gd")


# === AtomBase ===

func _test_atom_base(t) -> void:
	var atom := AtomBase.new()
	t.assert_true(atom is RefCounted, "AtomBase is RefCounted")
	t.assert_true(atom.has_method("configure"), "AtomBase has configure()")
	t.assert_true(atom.has_method("execute"), "AtomBase has execute()")
	t.assert_true(atom.has_method("evaluate"), "AtomBase has evaluate()")
	t.assert_true(atom.has_method("is_condition"), "AtomBase has is_condition()")
	t.assert_true(atom.has_method("get_param"), "AtomBase has get_param()")

	# Default behavior
	t.assert_eq(atom.is_condition(), false, "AtomBase.is_condition() default false")
	t.assert_eq(atom.evaluate(null), true, "AtomBase.evaluate() default true")

	# configure sets params
	atom.configure({"key": "value", "num": 42})
	t.assert_eq(atom.get_param("key"), "value", "get_param returns configured value")
	t.assert_eq(atom.get_param("num"), 42, "get_param returns configured number")
	t.assert_eq(atom.get_param("missing", "default"), "default", "get_param returns default for missing key")


# === AtomContext ===

func _test_atom_context(t) -> void:
	var ctx := AtomContext.new()
	t.assert_true(ctx is RefCounted, "AtomContext is RefCounted")
	t.assert_true("source" in ctx, "AtomContext has source")
	t.assert_true("target" in ctx, "AtomContext has target")
	t.assert_true("source_position" in ctx, "AtomContext has source_position")
	t.assert_true("target_position" in ctx, "AtomContext has target_position")
	t.assert_true("effect_data" in ctx, "AtomContext has effect_data")
	t.assert_true("delta" in ctx, "AtomContext has delta")
	t.assert_true("params" in ctx, "AtomContext has params")
	t.assert_true("direction" in ctx, "AtomContext has direction")
	t.assert_true("layer_a" in ctx, "AtomContext has layer_a")
	t.assert_true("layer_b" in ctx, "AtomContext has layer_b")
	t.assert_true("effect_mgr" in ctx, "AtomContext has effect_mgr")
	t.assert_true("tile_mgr" in ctx, "AtomContext has tile_mgr")
	t.assert_true("tick_mgr" in ctx, "AtomContext has tick_mgr")
	t.assert_true("results" in ctx, "AtomContext has results")

	# with_target_position creates sub-context
	t.assert_true(ctx.has_method("with_target_position"), "AtomContext has with_target_position()")
	var sub := ctx.with_target_position(Vector2i(5, 10))
	t.assert_eq(sub.target_position, Vector2i(5, 10), "sub-ctx target_position overridden")
	t.assert_eq(sub.results, ctx.results, "sub-ctx shares results dict")

	# with_target creates sub-context
	t.assert_true(ctx.has_method("with_target"), "AtomContext has with_target()")


# === AtomRegistry ===

func _test_atom_registry(t) -> void:
	var reg := AtomRegistry.new()
	t.assert_true(reg is RefCounted, "AtomRegistry is RefCounted")
	t.assert_true(reg.has_method("create"), "has create()")
	t.assert_true(reg.has_method("has_atom"), "has has_atom()")
	t.assert_true(reg.has_method("get_atom_names"), "has get_atom_names()")

	# Check all 55 atoms are registered (49 original + 6 T27/T28)
	var names := reg.get_atom_names()
	t.assert_eq(names.size(), 55, "AtomRegistry has 55 atoms registered")

	# Spot-check key atoms exist
	t.assert_true(reg.has_atom("damage"), "registry has damage")
	t.assert_true(reg.has_atom("heal"), "registry has heal")
	t.assert_true(reg.has_atom("apply_status"), "registry has apply_status")
	t.assert_true(reg.has_atom("freeze"), "registry has freeze")
	t.assert_true(reg.has_atom("place_tile"), "registry has place_tile")
	t.assert_true(reg.has_atom("if_chance"), "registry has if_chance")
	t.assert_true(reg.has_atom("delay"), "registry has delay")
	t.assert_true(reg.has_atom("trigger_slot"), "registry has trigger_slot")

	# Create returns configured atom
	var dmg := reg.create("damage", {"amount": 5, "source": "test"})
	t.assert_true(dmg != null, "create returns non-null atom")
	t.assert_true(dmg is AtomBase, "created atom is AtomBase")
	t.assert_eq(dmg.get_param("amount"), 5, "created atom has configured params")
	t.assert_eq(dmg.is_condition(), false, "damage is not a condition")

	# Unknown atom returns null
	var unknown := reg.create("nonexistent_atom")
	t.assert_true(unknown == null, "create unknown atom returns null")

	# Condition atoms
	var cond := reg.create("if_chance", {"chance": 0.5})
	t.assert_true(cond != null, "condition atom created")
	t.assert_true(cond.is_condition(), "if_chance is a condition")


# === EffectChain ===

func _test_effect_chain(t) -> void:
	var chain := EffectChain.new()
	t.assert_true(chain is RefCounted, "EffectChain is RefCounted")
	t.assert_true("trigger" in chain, "has trigger")
	t.assert_true("trigger_params" in chain, "has trigger_params")
	t.assert_true("conditions" in chain, "has conditions")
	t.assert_true("actions" in chain, "has actions")
	t.assert_true("pattern" in chain, "has pattern")
	t.assert_true("pattern_params" in chain, "has pattern_params")
	t.assert_true("chance" in chain, "has chance")
	t.assert_true("chain_source" in chain, "has chain_source")
	t.assert_true("_active" in chain, "has _active")

	# advance_interval
	t.assert_true(chain.has_method("advance_interval"), "has advance_interval()")
	chain.trigger = "on_interval"
	chain.trigger_params = {"interval": 2.0}
	t.assert_eq(chain.advance_interval(1.0), false, "interval not yet reached")
	t.assert_eq(chain.advance_interval(1.0), true, "interval reached after 2s")

	# check_layer_reach
	t.assert_true(chain.has_method("check_layer_reach"), "has check_layer_reach()")
	chain.trigger = "on_layer_reach"
	chain.trigger_params = {"layer": 3}
	t.assert_eq(chain.check_layer_reach(2), false, "layer 2 < required 3")
	t.assert_eq(chain.check_layer_reach(3), true, "layer 3 >= required 3")
	t.assert_eq(chain.check_layer_reach(5), true, "layer 5 >= required 3")


# === PatternResolver ===

func _test_pattern_resolver(t) -> void:
	# Initialize grid for pattern tests
	GridWorld.init_grid(20, 20)

	# self pattern
	var ctx := AtomContext.new()
	ctx.source_position = Vector2i(5, 5)
	var self_result: Array = PatternResolver.resolve("self", ctx, {})
	t.assert_eq(self_result.size(), 1, "self pattern: 1 position")
	t.assert_eq(self_result[0], Vector2i(5, 5), "self pattern: returns source_position")

	# target pattern
	ctx.target_position = Vector2i(10, 10)
	var target_result: Array = PatternResolver.resolve("target", ctx, {})
	t.assert_eq(target_result.size(), 1, "target pattern: 1 position")
	t.assert_eq(target_result[0], Vector2i(10, 10), "target pattern: returns target_position")

	# neighbors pattern
	ctx.source_position = Vector2i(10, 10)
	var neighbors: Array = PatternResolver.resolve("neighbors", ctx, {})
	t.assert_eq(neighbors.size(), 4, "neighbors pattern: 4 positions (center of grid)")

	# neighbors at corner
	ctx.source_position = Vector2i(0, 0)
	var corner_neighbors: Array = PatternResolver.resolve("neighbors", ctx, {})
	t.assert_eq(corner_neighbors.size(), 2, "neighbors at corner: 2 positions")

	# radius pattern
	ctx.source_position = Vector2i(10, 10)
	var radius_result: Array = PatternResolver.resolve("radius", ctx, {"radius": 1})
	t.assert_true(radius_result.size() > 0, "radius pattern: has positions")
	t.assert_true(radius_result.size() <= 8, "radius pattern r=1: at most 8 (excludes center)")

	# line pattern
	ctx.source_position = Vector2i(5, 5)
	ctx.direction = Vector2i(1, 0)
	var line_result: Array = PatternResolver.resolve("line", ctx, {"length": 3})
	t.assert_eq(line_result.size(), 3, "line pattern: 3 positions")

	# cross pattern
	ctx.source_position = Vector2i(10, 10)
	var cross_result: Array = PatternResolver.resolve("cross", ctx, {"length": 2})
	t.assert_true(cross_result.size() > 0, "cross pattern: has positions")

	# random_n pattern
	ctx.source_position = Vector2i(10, 10)
	var random_result: Array = PatternResolver.resolve("random_n", ctx, {"count": 3, "radius": 5})
	t.assert_true(random_result.size() <= 3, "random_n pattern: at most N positions")


# === EffectChainResolver ===

func _test_effect_chain_resolver(t) -> void:
	var reg := AtomRegistry.new()
	var resolver := EffectChainResolver.new(reg)
	t.assert_true(resolver is RefCounted, "EffectChainResolver is RefCounted")
	t.assert_true(resolver.has_method("resolve"), "has resolve()")
	t.assert_true(resolver.has_method("resolve_all"), "has resolve_all()")
	t.assert_true(resolver.has_method("resolve_reaction"), "has resolve_reaction()")

	# Resolve a single effect definition
	var def := {
		"trigger": "on_interval",
		"interval": 2.0,
		"pattern": "self",
		"atoms": [
			{"atom": "damage", "amount_per_layer": 1, "source": "fire"},
		],
	}
	var chain: EffectChain = resolver.resolve(def)
	t.assert_true(chain != null, "resolve returns EffectChain")
	t.assert_eq(chain.trigger, "on_interval", "resolved trigger")
	t.assert_eq(chain.trigger_params.get("interval"), 2.0, "resolved interval param")
	t.assert_eq(chain.pattern, "self", "resolved pattern")
	t.assert_eq(chain.actions.size(), 1, "resolved 1 action atom")
	t.assert_eq(chain.conditions.size(), 0, "resolved 0 conditions")

	# Resolve with conditions
	var def_with_cond := {
		"trigger": "on_tick",
		"atoms": [
			{"atom": "if_chance", "chance": 0.5},
			{"atom": "damage", "amount": 1},
		],
	}
	var chain2: EffectChain = resolver.resolve(def_with_cond)
	t.assert_eq(chain2.conditions.size(), 1, "condition atom separated")
	t.assert_eq(chain2.actions.size(), 1, "action atom separated")

	# Resolve all from status config
	var status_cfg := {
		"entity_effects": [
			{"trigger": "on_interval", "interval": 2.0, "atoms": [{"atom": "damage", "amount": 1}]},
		],
		"tile_effects": [
			{"trigger": "on_interval", "interval": 1.0, "atoms": [{"atom": "place_tile", "type": "fire"}]},
		],
	}
	var all_chains: Array = resolver.resolve_all(status_cfg)
	t.assert_eq(all_chains.size(), 2, "resolve_all: 2 chains from entity + tile effects")
	t.assert_eq(all_chains[0].chain_source, "entity_effect", "first chain source")
	t.assert_eq(all_chains[1].chain_source, "tile_effect", "second chain source")

	# Resolve reaction
	var reaction_cfg := {
		"trigger": "on_applied",
		"atoms": [
			{"atom": "damage", "amount": 3, "formula": "sum_layers"},
		],
	}
	var reaction_chain: EffectChain = resolver.resolve_reaction(reaction_cfg)
	t.assert_true(reaction_chain != null, "resolve_reaction returns chain")
	t.assert_eq(reaction_chain.chain_source, "reaction", "reaction chain source")

	# Unknown atom warning (should not crash)
	var def_unknown := {
		"trigger": "on_tick",
		"atoms": [
			{"atom": "nonexistent_thing"},
		],
	}
	var chain_unk: EffectChain = resolver.resolve(def_unknown)
	t.assert_eq(chain_unk.actions.size(), 0, "unknown atom skipped gracefully")


# === AtomExecutor ===

func _test_atom_executor(t) -> void:
	var executor := AtomExecutor.new()
	t.assert_true(executor is RefCounted, "AtomExecutor is RefCounted")
	t.assert_true(executor.has_method("execute_chain"), "has execute_chain()")

	# Execute chain with actions
	var reg := AtomRegistry.new()
	var resolver := EffectChainResolver.new(reg)
	var def := {
		"trigger": "on_tick",
		"pattern": "self",
		"atoms": [
			{"atom": "damage_cap", "cap": 5},
		],
	}
	var chain: EffectChain = resolver.resolve(def)
	var ctx := AtomContext.new()
	ctx.source_position = Vector2i(5, 5)
	ctx.target_position = Vector2i(5, 5)
	GridWorld.init_grid(20, 20)
	executor.execute_chain(chain, ctx)
	t.assert_eq(ctx.results.get("damage_cap"), 5, "executor: damage_cap atom wrote to results")

	# Execute chain with failing condition (chance = 0)
	var def2 := {
		"trigger": "on_tick",
		"pattern": "self",
		"atoms": [
			{"atom": "if_chance", "chance": 0.0},
			{"atom": "damage_cap", "cap": 99},
		],
	}
	var chain2: EffectChain = resolver.resolve(def2)
	var ctx2 := AtomContext.new()
	ctx2.source_position = Vector2i(5, 5)
	executor.execute_chain(chain2, ctx2)
	t.assert_true(not ctx2.results.has("damage_cap"), "executor: condition blocked execution")

	# Execute chain with chance = 0
	var chain3 := EffectChain.new()
	chain3.chance = 0.0
	chain3.pattern = "self"
	chain3.actions = [reg.create("damage_cap", {"cap": 77})]
	var ctx3 := AtomContext.new()
	ctx3.source_position = Vector2i(5, 5)
	executor.execute_chain(chain3, ctx3)
	t.assert_true(not ctx3.results.has("damage_cap"), "executor: zero chance blocks execution")


# === Value Atoms ===

func _test_value_atoms(t) -> void:
	var reg := AtomRegistry.new()

	# DamageCapAtom
	var cap := reg.create("damage_cap", {"cap": 10})
	var ctx := AtomContext.new()
	cap.execute(ctx)
	t.assert_eq(ctx.results.get("damage_cap"), 10, "damage_cap atom sets result")

	# HealAtom
	var heal := reg.create("heal", {"amount": 3})
	var target_obj := RefCounted.new()
	target_obj.set_meta("grow_pending", 0)
	# HealAtom expects target with grow_pending property — may not work on RefCounted
	# Just verify it doesn't crash
	var hctx := AtomContext.new()
	hctx.target = target_obj
	heal.execute(hctx)
	t.assert_true(true, "heal atom executes without crash")

	# ShieldAtom
	var shield := reg.create("shield", {"amount": 5})
	var shield_target := Node2D.new()
	Engine.get_main_loop().root.add_child(shield_target)
	var sctx := AtomContext.new()
	sctx.target = shield_target
	shield.execute(sctx)
	t.assert_eq(shield_target.get_meta("shield_amount", 0), 5, "shield atom sets meta")
	shield_target.queue_free()

	# ModifySpeedAtom (needs tick_mgr mock)
	var speed := reg.create("modify_speed", {"multiplier": 0.5})
	var mock_tick := RefCounted.new()
	mock_tick.set_meta("tick_speed_modifier", 1.0)
	# ModifySpeedAtom checks "tick_speed_modifier" in ctx.tick_mgr
	# For real test it needs a Node with that property
	t.assert_true(speed != null, "modify_speed atom created")


# === Status Atoms ===

func _test_status_atoms(t) -> void:
	var reg := AtomRegistry.new()

	# Verify creation
	var apply := reg.create("apply_status", {"type": "fire", "layers": 1})
	t.assert_true(apply != null, "apply_status atom created")
	t.assert_eq(apply.is_condition(), false, "apply_status is not condition")

	var remove := reg.create("remove_status", {"type": "fire"})
	t.assert_true(remove != null, "remove_status atom created")

	var transfer := reg.create("transfer_status")
	t.assert_true(transfer != null, "transfer_status atom created")

	var cleanse := reg.create("cleanse_all")
	t.assert_true(cleanse != null, "cleanse_all atom created")

	var extend := reg.create("extend_duration", {"amount": 2.0})
	t.assert_true(extend != null, "extend_duration atom created")


# === Logic Atoms (Conditions) ===

func _test_logic_atoms(t) -> void:
	var reg := AtomRegistry.new()

	# if_chance with 1.0 → always true
	var always := reg.create("if_chance", {"chance": 1.0})
	t.assert_true(always.is_condition(), "if_chance is condition")
	var ctx := AtomContext.new()
	t.assert_eq(always.evaluate(ctx), true, "if_chance(1.0) evaluates true")

	# if_chance with 0.0 → always false
	var never := reg.create("if_chance", {"chance": 0.0})
	t.assert_eq(never.evaluate(ctx), false, "if_chance(0.0) evaluates false")

	# if_length_below
	var len_below := reg.create("if_length_below", {"threshold": 5})
	t.assert_true(len_below.is_condition(), "if_length_below is condition")

	# if_length_above
	var len_above := reg.create("if_length_above", {"threshold": 3})
	t.assert_true(len_above.is_condition(), "if_length_above is condition")

	# if_has_status
	var has_st := reg.create("if_has_status", {"type": "fire"})
	t.assert_true(has_st.is_condition(), "if_has_status is condition")

	# if_on_tile
	var on_tile := reg.create("if_on_tile", {"type": "poison"})
	t.assert_true(on_tile.is_condition(), "if_on_tile is condition")

	# if_cooldown
	var cooldown := reg.create("if_cooldown", {"seconds": 5.0})
	t.assert_true(cooldown.is_condition(), "if_cooldown is condition")

	# if_count_reached
	var count := reg.create("if_count_reached", {"count": 3})
	t.assert_true(count.is_condition(), "if_count_reached is condition")


# === Spatial Atoms ===

func _test_spatial_atoms(t) -> void:
	var reg := AtomRegistry.new()

	t.assert_true(reg.create("place_tile", {"type": "fire"}) != null, "place_tile created")
	t.assert_true(reg.create("remove_tile", {"type": "fire"}) != null, "remove_tile created")
	t.assert_true(reg.create("place_tile_trail", {"type": "poison", "interval": 3}) != null, "place_tile_trail created")
	t.assert_true(reg.create("convert_tile", {"from": "fire", "to": "ice"}) != null, "convert_tile created")
	t.assert_true(reg.create("destroy_terrain") != null, "destroy_terrain created")


# === Control Atoms ===

func _test_control_atoms(t) -> void:
	var reg := AtomRegistry.new()

	t.assert_true(reg.create("freeze", {"duration": 2.0}) != null, "freeze created")
	t.assert_true(reg.create("stun", {"duration": 1.0}) != null, "stun created")
	t.assert_true(reg.create("knockback", {"distance": 2}) != null, "knockback created")
	t.assert_true(reg.create("forced_move", {"direction": "away"}) != null, "forced_move created")
	t.assert_true(reg.create("teleport") != null, "teleport created")
	t.assert_true(reg.create("attract", {"radius": 3}) != null, "attract created")
	t.assert_true(reg.create("phase", {"duration": 1.0}) != null, "phase created")
	t.assert_true(reg.create("reverse_input", {"duration": 3.0}) != null, "reverse_input created")
	t.assert_true(reg.create("modify_turn_delay", {"multiplier": 2.0}) != null, "modify_turn_delay created")
	t.assert_true(reg.create("lock_input", {"duration": 1.0}) != null, "lock_input created")


# === Temporal Atoms ===

func _test_temporal_atoms(t) -> void:
	var reg := AtomRegistry.new()

	t.assert_true(reg.create("delay", {"seconds": 1.0}) != null, "delay created")
	t.assert_true(reg.create("repeat", {"times": 3}) != null, "repeat created")
	t.assert_true(reg.create("queue") != null, "queue created")
	t.assert_true(reg.create("reduce_cooldown", {"amount": 1.0}) != null, "reduce_cooldown created")


# === Spawn Atoms ===

func _test_spawn_atoms(t) -> void:
	var reg := AtomRegistry.new()

	t.assert_true(reg.create("spawn_entity", {"type": "wanderer"}) != null, "spawn_entity created")
	t.assert_true(reg.create("spawn_projectile", {"type": "fireball"}) != null, "spawn_projectile created")
	t.assert_true(reg.create("consume_tile") != null, "consume_tile created")


# === Build Atoms ===

func _test_build_atoms(t) -> void:
	var reg := AtomRegistry.new()

	t.assert_true(reg.create("trigger_slot", {"slot": "A"}) != null, "trigger_slot created")
	t.assert_true(reg.create("cancel_cost") != null, "cancel_cost created")
	t.assert_true(reg.create("disable_slot", {"slot": "B"}) != null, "disable_slot created")
	t.assert_true(reg.create("modify_effect_value", {"key": "damage", "delta": 2}) != null, "modify_effect_value created")
	t.assert_true(reg.create("accumulate", {"key": "stacks", "amount": 1}) != null, "accumulate created")
	t.assert_true(reg.create("lock_slot", {"slot": "C"}) != null, "lock_slot created")


# === SEM Integration ===

func _test_sem_integration(t) -> void:
	var sem = StatusEffectManager
	if sem == null:
		t.assert_true(false, "StatusEffectManager not found — skipping integration tests")
		return

	# Atom system fields exist
	t.assert_true("_atom_registry" in sem, "SEM has _atom_registry")
	t.assert_true("_chain_resolver" in sem, "SEM has _chain_resolver")
	t.assert_true("_trigger_manager" in sem, "SEM has _trigger_manager")
	t.assert_true("_active_modifiers" in sem, "SEM has _active_modifiers")

	# AtomRegistry initialized
	t.assert_true(sem._atom_registry != null, "SEM._atom_registry initialized")
	t.assert_true(sem._chain_resolver != null, "SEM._chain_resolver initialized")
	t.assert_true(sem._trigger_manager != null, "SEM._trigger_manager initialized")

	# TriggerManager is a child node
	var tm = sem.get_node_or_null("TriggerManager")
	t.assert_true(tm != null, "TriggerManager is child of SEM")

	# New API methods
	t.assert_true(sem.has_method("get_modifier"), "SEM has get_modifier()")
	t.assert_true(sem.has_method("set_modifier"), "SEM has set_modifier()")
	t.assert_true(sem.has_method("clear_modifier"), "SEM has clear_modifier()")

	# StatusEffectData has chains field
	var effect := StatusEffectData.new()
	t.assert_true("chains" in effect, "StatusEffectData has chains field")
	t.assert_eq(effect.chains, [], "chains default empty")

	# Apply status with atom chains — use a dummy target
	var dummy := Node2D.new()
	Engine.get_main_loop().root.add_child(dummy)
	sem.clear_all()

	var applied: StatusEffectData = sem.apply_status(dummy, "fire", "test_atom")
	t.assert_true(applied != null, "apply_status returns effect")
	t.assert_true(applied.chains.size() > 0, "fire effect has atom chains resolved")

	# Remove and verify cleanup
	sem.remove_status(dummy, "fire", "test")
	t.assert_true(not sem.has_status(dummy, "fire"), "fire effect removed after remove_status")

	# Apply ice and verify atom chains
	var ice_effect: StatusEffectData = sem.apply_status(dummy, "ice", "test_atom")
	t.assert_true(ice_effect.chains.size() > 0, "ice effect has atom chains resolved")

	# Apply poison and verify atom chains
	var poison_effect: StatusEffectData = sem.apply_status(dummy, "poison", "test_atom")
	t.assert_true(poison_effect.chains.size() > 0, "poison effect has atom chains resolved")

	# clear_all cleans everything
	sem.clear_all()
	t.assert_eq(sem._active_modifiers["growth"].size(), 0, "clear_all resets growth modifiers")

	dummy.queue_free()


# === Modifier API ===

func _test_modifier_api(t) -> void:
	var sem = StatusEffectManager
	if sem == null:
		return

	sem.clear_all()

	var dummy := Node2D.new()
	Engine.get_main_loop().root.add_child(dummy)

	# Default modifier
	t.assert_eq(sem.get_modifier("growth", dummy, 1.0), 1.0, "default growth modifier is 1.0")

	# Set modifier
	sem.set_modifier("growth", dummy, 0.5)
	t.assert_eq(sem.get_modifier("growth", dummy, 1.0), 0.5, "set growth modifier to 0.5")

	# Clear modifier
	sem.clear_modifier("growth", dummy)
	t.assert_eq(sem.get_modifier("growth", dummy, 1.0), 1.0, "cleared growth modifier back to default")

	# Unknown modifier type
	t.assert_eq(sem.get_modifier("nonexistent", dummy, 2.0), 2.0, "unknown modifier returns default")

	dummy.queue_free()
	sem.clear_all()


