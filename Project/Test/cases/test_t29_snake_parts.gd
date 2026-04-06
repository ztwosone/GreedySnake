extends RefCounted
## T29 测试：SnakePartsManager + 蛇头链


func run(t) -> void:
	_test_config(t)
	_test_snake_part_data(t)
	_test_atom_registration(t)
	_test_area_damage_atom(t)
	_test_signals(t)
	_test_trigger_on_body_attacked(t)
	_test_snake_take_hit_window(t)
	_test_food_drop_modifier(t)


func _test_config(t) -> void:
	# --- ConfigManager snake_heads ---
	t.assert_true(ConfigManager.snake_heads.size() >= 2, "snake_heads has >= 2 entries")
	t.assert_true(ConfigManager.snake_heads.has("hydra"), "has hydra config")
	t.assert_true(ConfigManager.snake_heads.has("bai_she"), "has bai_she config")

	var h1: Dictionary = ConfigManager.get_snake_head("hydra", 1)
	t.assert_true(h1.has("entity_effects"), "hydra L1 has entity_effects")
	t.assert_true(h1["entity_effects"].size() >= 3, "hydra L1 has >= 3 chains (applied/removed/kill)")

	var h3: Dictionary = ConfigManager.get_snake_head("hydra", 3)
	t.assert_true(h3.has("entity_effects"), "hydra L3 has entity_effects")

	var b1: Dictionary = ConfigManager.get_snake_head("bai_she", 1)
	t.assert_true(b1.has("entity_effects"), "bai_she L1 has entity_effects")

	var b2: Dictionary = ConfigManager.get_snake_head("bai_she", 2)
	t.assert_true(b2["entity_effects"].size() >= 2, "bai_she L2 has >= 2 chains (kill + body_attacked)")

	var empty: Dictionary = ConfigManager.get_snake_head("nonexistent", 1)
	t.assert_eq(empty.size(), 0, "nonexistent head returns empty dict")

	t.assert_true(ConfigManager.get_snake_head_ids().size() >= 2, "get_snake_head_ids >= 2")


func _test_snake_part_data(t) -> void:
	# --- SnakePartData duck typing 兼容 ---
	var PartScript: GDScript = load("res://systems/snake_parts/snake_part_data.gd")
	var part = PartScript.new()
	part.init_data("head", "hydra", 2, null, [])
	t.assert_eq(part.part_type, "head", "part_type == head")
	t.assert_eq(part.part_id, "hydra", "part_id == hydra")
	t.assert_eq(part.level, 2, "level == 2")
	t.assert_eq(part.type, "hydra", "type == part_id (TriggerManager compat)")
	t.assert_eq(part.layer, 1, "layer == 1 (compat)")
	t.assert_eq(part.carrier_type, "entity", "carrier_type == entity")
	# duck typing: .get("carrier"), .get("type"), .get("layer")
	t.assert_eq(part.get("carrier"), null, "get('carrier') works")
	t.assert_eq(part.get("type"), "hydra", "get('type') works")
	t.assert_eq(part.get("layer"), 1, "get('layer') works")


func _test_atom_registration(t) -> void:
	# --- AtomRegistry 新增原子 ---
	var reg: AtomRegistry = AtomRegistry.new()
	t.assert_true(reg.has_atom("area_damage"), "area_damage registered")
	t.assert_true(reg.has_atom("burst_carried_status"), "burst_carried_status registered")
	t.assert_true(reg.has_atom("modify_food_drop"), "modify_food_drop still registered")
	t.assert_true(reg.has_atom("direct_grow"), "direct_grow still registered")
	t.assert_true(reg.has_atom("steal_status"), "steal_status still registered")
	t.assert_true(reg.has_atom("modify_hit_threshold"), "modify_hit_threshold still registered")
	var names: Array = reg.get_atom_names()
	t.assert_true(names.size() >= 57, "total atoms >= 57, got %d" % names.size())


func _test_area_damage_atom(t) -> void:
	# --- area_damage 原子测试 ---
	var reg: AtomRegistry = AtomRegistry.new()
	var atom: AtomBase = reg.create("area_damage", { "amount": 1, "radius": 1 })
	t.assert_true(atom != null, "area_damage atom created")
	t.assert_true(atom.has_method("execute"), "area_damage has execute()")

	# burst_carried_status 原子
	var burst: AtomBase = reg.create("burst_carried_status", { "radius": 1 })
	t.assert_true(burst != null, "burst_carried_status atom created")
	t.assert_true(burst.has_method("execute"), "burst_carried_status has execute()")


func _test_signals(t) -> void:
	# --- EventBus 新信号 ---
	t.assert_has_signal(EventBus, "snake_head_equipped")
	t.assert_has_signal(EventBus, "snake_head_unequipped")
	t.assert_has_signal(EventBus, "snake_body_attacked")


func _test_trigger_on_body_attacked(t) -> void:
	# --- TriggerManager 有 _on_body_attacked 方法 ---
	var TriggerMgrScript: GDScript = load("res://systems/atoms/trigger_manager.gd")
	var tm: Node = TriggerMgrScript.new()
	t.assert_true(tm.has_method("_on_body_attacked"), "TM has _on_body_attacked")


func _test_snake_take_hit_window(t) -> void:
	# --- Snake.take_hit 有 _window_mgr 字段 ---
	var snake = Snake.new()
	t.assert_true("_window_mgr" in snake, "Snake has _window_mgr field")
	# 无 window_mgr 时正常受击
	snake.is_alive = true
	snake.hits_taken = 0
	snake.hits_per_segment_loss = 3
	snake.take_hit(1)
	t.assert_eq(snake.hits_taken, 1, "take_hit increments without window_mgr")


func _test_food_drop_modifier(t) -> void:
	# --- StatusEffectManager 新增 modifier keys ---
	t.assert_true(StatusEffectManager._active_modifiers.has("hit_threshold"), "has hit_threshold modifier")
	t.assert_true(StatusEffectManager._active_modifiers.has("food_drop"), "has food_drop modifier")
	# get_modifier 默认值
	var mock = RefCounted.new()
	var ht: float = StatusEffectManager.get_modifier("hit_threshold", mock, 0.0)
	t.assert_eq(ht, 0.0, "hit_threshold default = 0.0")
	var fd: float = StatusEffectManager.get_modifier("food_drop", mock, 0.0)
	t.assert_eq(fd, 0.0, "food_drop default = 0.0")
	# set + get
	StatusEffectManager.set_modifier("hit_threshold", mock, -1.0)
	t.assert_eq(StatusEffectManager.get_modifier("hit_threshold", mock, 0.0), -1.0, "hit_threshold after set = -1.0")
	# 清理
	StatusEffectManager.clear_modifier("hit_threshold", mock)
	t.assert_eq(StatusEffectManager.get_modifier("hit_threshold", mock, 0.0), 0.0, "hit_threshold after clear = 0.0")
