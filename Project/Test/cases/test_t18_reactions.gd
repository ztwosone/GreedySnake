extends RefCounted
## T18 测试：状态反应系统（蒸腾/毒爆/冻疫）
## 反应由 StatusTransferSystem / Enemy 发射 reaction_triggered 信号
## ReactionSystem 监听信号执行效果


func run(t) -> void:
	# --- 文件存在性 ---
	t.assert_file_exists("res://systems/status/reaction_system.gd")

	# --- 基本类检查 ---
	var rs := ReactionSystem.new()
	t.assert_true(rs is Node, "ReactionSystem is Node")
	t.assert_true(rs.has_method("_on_reaction_triggered"), "has _on_reaction_triggered")
	rs.queue_free()

	# --- 准备 ---
	GridWorld.init_grid(40, 22)

	var tile_mgr := StatusTileManager.new()
	Engine.get_main_loop().root.add_child(tile_mgr)

	var reaction_sys := ReactionSystem.new()
	reaction_sys.tile_manager = tile_mgr
	Engine.get_main_loop().root.add_child(reaction_sys)

	# === reaction_triggered 信号存在 ===
	t.assert_has_signal(EventBus, "reaction_triggered")

	# === config 读取验证 ===
	var cfg_node = ConfigManager
	if cfg_node:
		var steam_cfg: Dictionary = cfg_node.find_reaction("fire", "ice")
		t.assert_true(steam_cfg.size() > 0, "find_reaction('fire','ice') returns data")
		t.assert_eq(steam_cfg.get("radius"), 3, "steam: radius == 3")
		t.assert_eq(steam_cfg.get("enemy_damage"), 2, "steam: enemy_damage == 2")
		t.assert_eq(steam_cfg.get("self_hit_count"), 1, "steam: self_hit_count == 1")

		var toxic_cfg: Dictionary = cfg_node.find_reaction("fire", "poison")
		t.assert_true(toxic_cfg.size() > 0, "find_reaction('fire','poison') returns data")
		t.assert_eq(toxic_cfg.get("enemy_damage"), 3, "toxic_explosion: enemy_damage == 3")
		t.assert_eq(toxic_cfg.get("self_hit_count"), 2, "toxic_explosion: self_hit_count == 2")

		# 冻疫
		var frozen_cfg: Dictionary = cfg_node.find_reaction("ice", "poison")
		t.assert_true(frozen_cfg.size() > 0, "find_reaction('ice','poison') returns data (frozen_plague)")
		t.assert_eq(frozen_cfg.get("self_hit_count"), 0, "frozen_plague: self_hit_count == 0")

		# 双向查找
		var reverse: Dictionary = cfg_node.find_reaction("ice", "fire")
		t.assert_true(reverse.size() > 0, "find_reaction reverse: ice,fire == fire,ice")

	# === 反应效果：AoE 伤害敌人 ===

	var enemy := Enemy.new()
	enemy.setup_from_config("wanderer")
	enemy.place_on_grid(Vector2i(10, 10))

	# 模拟蒸腾反应在 (10,11)，敌人在 radius=3 内
	reaction_sys._on_reaction_triggered({
		"reaction_id": "steam",
		"position": Vector2i(10, 11),
		"type_a": "fire",
		"type_b": "ice",
	})

	# 敌人 HP=1，enemy_damage=2，应该死了
	t.assert_true(enemy.hp <= 0, "steam: enemy in radius takes damage")

	# === 反应效果：蛇受击 ===

	var mock_snake := Snake.new()
	Engine.get_main_loop().root.add_child(mock_snake)
	mock_snake.init_snake(Vector2i(15, 10), 6, Vector2i(1, 0))
	t.assert_eq(mock_snake.hits_taken, 0, "snake hits_taken starts at 0")

	# 毒爆在 (15,10)，self_hit_count=2
	reaction_sys._on_reaction_triggered({
		"reaction_id": "toxic_explosion",
		"position": Vector2i(15, 10),
		"type_a": "fire",
		"type_b": "poison",
	})

	t.assert_eq(mock_snake.hits_taken, 2, "toxic_explosion: snake takes 2 hits")

	# === 冻疫：敌人获得 ice + poison ===

	var effect_mgr = StatusEffectManager
	effect_mgr.clear_all()

	var enemy2 := Enemy.new()
	enemy2.setup_from_config("chaser")
	enemy2.place_on_grid(Vector2i(16, 10))

	reaction_sys._on_reaction_triggered({
		"reaction_id": "frozen_plague",
		"position": Vector2i(16, 10),
		"type_a": "ice",
		"type_b": "poison",
	})

	t.assert_true(effect_mgr.has_status(enemy2, "ice"), "frozen_plague: enemy gets ice")
	t.assert_true(effect_mgr.has_status(enemy2, "poison"), "frozen_plague: enemy gets poison")

	# === ReactionResolver 反应查表（替代已删除的 Enemy._get_reaction_id） ===
	var ResolverScript: GDScript = preload("res://systems/status/reaction_resolver.gd")
	var resolver: Node = ResolverScript.new()
	resolver._build_reaction_map()
	t.assert_eq(resolver.find_reaction("fire", "ice"), "steam", "ReactionResolver fire+ice == steam")
	t.assert_eq(resolver.find_reaction("ice", "fire"), "steam", "ReactionResolver ice+fire == steam (order-independent)")
	t.assert_eq(resolver.find_reaction("fire", "poison"), "toxic_explosion", "ReactionResolver fire+poison == toxic_explosion")
	t.assert_eq(resolver.find_reaction("ice", "poison"), "frozen_plague", "ReactionResolver ice+poison == frozen_plague")
	t.assert_eq(resolver.find_reaction("fire", "fire"), "", "ReactionResolver same type == empty")
	resolver.queue_free()

	# === 清理 ===
	effect_mgr.clear_all()
	tile_mgr.clear_all()
	GridWorld.clear_all()
	enemy.remove_from_grid()
	enemy2.remove_from_grid()
	mock_snake._clear_segments()
	mock_snake.queue_free()
	tile_mgr.queue_free()
	reaction_sys.queue_free()
