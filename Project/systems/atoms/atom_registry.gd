class_name AtomRegistry
extends RefCounted
## 原子注册表
## 将原子名称映射到 GDScript 类，用于从 JSON 配置创建原子实例。
## 添加新原子：1. 创建 .gd 文件  2. 在 _atoms 字典中加一行

var _atoms: Dictionary = {}


func _init() -> void:
	_register_all()


func _register_all() -> void:
	# === Value 原子 ===
	_atoms["damage"] = preload("res://systems/atoms/atoms/value/damage_atom.gd")
	_atoms["damage_percent"] = preload("res://systems/atoms/atoms/value/damage_percent_atom.gd")
	_atoms["damage_cap"] = preload("res://systems/atoms/atoms/value/damage_cap_atom.gd")
	_atoms["heal"] = preload("res://systems/atoms/atoms/value/heal_atom.gd")
	_atoms["modify_growth"] = preload("res://systems/atoms/atoms/value/modify_growth_atom.gd")
	_atoms["modify_speed"] = preload("res://systems/atoms/atoms/value/modify_speed_atom.gd")
	_atoms["modify_attack_cost"] = preload("res://systems/atoms/atoms/value/modify_attack_cost_atom.gd")
	_atoms["shield"] = preload("res://systems/atoms/atoms/value/shield_atom.gd")
	_atoms["lifesteal"] = preload("res://systems/atoms/atoms/value/lifesteal_atom.gd")
	_atoms["modify_food_drop"] = load("res://systems/atoms/atoms/value/modify_food_drop_atom.gd")
	_atoms["direct_grow"] = load("res://systems/atoms/atoms/value/direct_grow_atom.gd")
	_atoms["modify_hit_threshold"] = load("res://systems/atoms/atoms/value/modify_hit_threshold_atom.gd")

	# === Status 原子 ===
	_atoms["apply_status"] = preload("res://systems/atoms/atoms/status/apply_status_atom.gd")
	_atoms["remove_status"] = preload("res://systems/atoms/atoms/status/remove_status_atom.gd")
	_atoms["transfer_status"] = preload("res://systems/atoms/atoms/status/transfer_status_atom.gd")
	_atoms["cleanse_all"] = preload("res://systems/atoms/atoms/status/cleanse_all_atom.gd")
	_atoms["extend_duration"] = preload("res://systems/atoms/atoms/status/extend_duration_atom.gd")
	_atoms["steal_status"] = load("res://systems/atoms/atoms/status/steal_status_atom.gd")

	# === Spatial 原子 ===
	_atoms["place_tile"] = preload("res://systems/atoms/atoms/spatial/place_tile_atom.gd")
	_atoms["remove_tile"] = preload("res://systems/atoms/atoms/spatial/remove_tile_atom.gd")
	_atoms["place_tile_trail"] = preload("res://systems/atoms/atoms/spatial/place_tile_trail_atom.gd")
	_atoms["convert_tile"] = preload("res://systems/atoms/atoms/spatial/convert_tile_atom.gd")
	_atoms["destroy_terrain"] = preload("res://systems/atoms/atoms/spatial/destroy_terrain_atom.gd")

	# === Control 原子 ===
	_atoms["freeze"] = preload("res://systems/atoms/atoms/control/freeze_atom.gd")
	_atoms["stun"] = preload("res://systems/atoms/atoms/control/stun_atom.gd")
	_atoms["knockback"] = preload("res://systems/atoms/atoms/control/knockback_atom.gd")
	_atoms["forced_move"] = preload("res://systems/atoms/atoms/control/forced_move_atom.gd")
	_atoms["teleport"] = preload("res://systems/atoms/atoms/control/teleport_atom.gd")
	_atoms["attract"] = preload("res://systems/atoms/atoms/control/attract_atom.gd")
	_atoms["phase"] = preload("res://systems/atoms/atoms/control/phase_atom.gd")
	_atoms["reverse_input"] = preload("res://systems/atoms/atoms/control/reverse_input_atom.gd")
	_atoms["modify_turn_delay"] = preload("res://systems/atoms/atoms/control/modify_turn_delay_atom.gd")
	_atoms["lock_input"] = preload("res://systems/atoms/atoms/control/lock_input_atom.gd")

	# === Spawn 原子 ===
	_atoms["spawn_entity"] = preload("res://systems/atoms/atoms/spawn/spawn_entity_atom.gd")
	_atoms["spawn_projectile"] = preload("res://systems/atoms/atoms/spawn/spawn_projectile_atom.gd")
	_atoms["consume_tile"] = preload("res://systems/atoms/atoms/spawn/consume_tile_atom.gd")

	# === Temporal 原子 ===
	_atoms["delay"] = preload("res://systems/atoms/atoms/temporal/delay_atom.gd")
	_atoms["repeat"] = preload("res://systems/atoms/atoms/temporal/repeat_atom.gd")
	_atoms["queue"] = preload("res://systems/atoms/atoms/temporal/queue_atom.gd")
	_atoms["reduce_cooldown"] = preload("res://systems/atoms/atoms/temporal/reduce_cooldown_atom.gd")
	_atoms["open_window"] = load("res://systems/atoms/atoms/temporal/open_window_atom.gd")

	# === Logic 原子 ===
	_atoms["if_length_below"] = preload("res://systems/atoms/atoms/logic/if_length_below_atom.gd")
	_atoms["if_length_above"] = preload("res://systems/atoms/atoms/logic/if_length_above_atom.gd")
	_atoms["if_has_status"] = preload("res://systems/atoms/atoms/logic/if_has_status_atom.gd")
	_atoms["if_on_tile"] = preload("res://systems/atoms/atoms/logic/if_on_tile_atom.gd")
	_atoms["if_chance"] = preload("res://systems/atoms/atoms/logic/if_chance_atom.gd")
	_atoms["if_cooldown"] = preload("res://systems/atoms/atoms/logic/if_cooldown_atom.gd")
	_atoms["if_count_reached"] = preload("res://systems/atoms/atoms/logic/if_count_reached_atom.gd")
	_atoms["if_in_window"] = load("res://systems/atoms/atoms/logic/if_in_window_atom.gd")

	# === Build 原子 ===
	_atoms["trigger_slot"] = preload("res://systems/atoms/atoms/build/trigger_slot_atom.gd")
	_atoms["cancel_cost"] = preload("res://systems/atoms/atoms/build/cancel_cost_atom.gd")
	_atoms["disable_slot"] = preload("res://systems/atoms/atoms/build/disable_slot_atom.gd")
	_atoms["modify_effect_value"] = preload("res://systems/atoms/atoms/build/modify_effect_value_atom.gd")
	_atoms["accumulate"] = preload("res://systems/atoms/atoms/build/accumulate_atom.gd")
	_atoms["lock_slot"] = preload("res://systems/atoms/atoms/build/lock_slot_atom.gd")


## 创建原子实例
func create(atom_name: String, params: Dictionary = {}) -> AtomBase:
	var script = _atoms.get(atom_name)
	if script == null:
		push_error("AtomRegistry: unknown atom '%s'" % atom_name)
		return null
	var atom: AtomBase = script.new()
	atom.configure(params)
	return atom


## 检查原子是否存在
func has_atom(atom_name: String) -> bool:
	return _atoms.has(atom_name)


## 获取所有已注册原子名
func get_atom_names() -> Array:
	return _atoms.keys()
