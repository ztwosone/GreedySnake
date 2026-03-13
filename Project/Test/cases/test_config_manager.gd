extends RefCounted
## ConfigManager 测试：JSON 配置加载与访问接口


func run(t) -> void:
	# --- ConfigManager autoload 存在 ---
	var cfg = Engine.get_main_loop().root.get_node_or_null("ConfigManager")
	t.assert_true(cfg != null, "ConfigManager autoload exists")
	if cfg == null:
		return

	# --- 基础 section 已加载 ---
	t.assert_true(cfg.grid is Dictionary, "grid section is Dictionary")
	t.assert_true(cfg.tick is Dictionary, "tick section is Dictionary")
	t.assert_true(cfg.snake is Dictionary, "snake section is Dictionary")
	t.assert_true(cfg.food is Dictionary, "food section is Dictionary")
	t.assert_true(cfg.enemy is Dictionary, "enemy section is Dictionary")
	t.assert_true(cfg.status_effects is Dictionary, "status_effects section is Dictionary")
	t.assert_true(cfg.reactions is Dictionary, "reactions section is Dictionary")
	t.assert_true(cfg.enemy_types is Dictionary, "enemy_types section is Dictionary")
	t.assert_true(cfg.length_thresholds is Dictionary, "length_thresholds section is Dictionary")

	# --- grid 值校验 ---
	t.assert_eq(cfg.grid.get("cell_size"), 32, "grid.cell_size == 32")
	t.assert_eq(cfg.grid.get("width"), 40, "grid.width == 40")
	t.assert_eq(cfg.grid.get("height"), 22, "grid.height == 22")
	t.assert_eq(cfg.grid.get("window_scale"), 1, "grid.window_scale == 1")

	# --- tick ---
	t.assert_eq(cfg.tick.get("base_interval"), 0.25, "tick.base_interval == 0.25")

	# --- snake ---
	t.assert_eq(cfg.snake.get("initial_length"), 6, "snake.initial_length == 6")
	t.assert_eq(cfg.snake.get("min_length"), 1, "snake.min_length == 1")

	# --- status effect API ---
	var fire: Dictionary = cfg.get_status_effect("fire")
	t.assert_true(fire.size() > 0, "get_status_effect('fire') returns data")
	t.assert_eq(fire.get("display_name"), "灼烧", "fire display_name")
	t.assert_true(fire.has("entity_damage_interval"), "fire has entity_damage_interval")
	t.assert_true(fire.has("color"), "fire has color")

	var ice: Dictionary = cfg.get_status_effect("ice")
	t.assert_true(ice.size() > 0, "get_status_effect('ice') returns data")
	t.assert_eq(ice.get("display_name"), "冰冻", "ice display_name")

	var poison: Dictionary = cfg.get_status_effect("poison")
	t.assert_true(poison.size() > 0, "get_status_effect('poison') returns data")
	t.assert_eq(poison.get("display_name"), "中毒", "poison display_name")

	# --- 不存在的 status effect 返回空 ---
	var none_effect: Dictionary = cfg.get_status_effect("nonexistent")
	t.assert_eq(none_effect.size(), 0, "get_status_effect('nonexistent') returns empty dict")

	# --- enemy type API ---
	var wanderer: Dictionary = cfg.get_enemy_type("wanderer")
	t.assert_true(wanderer.size() > 0, "get_enemy_type('wanderer') returns data")
	t.assert_eq(wanderer.get("behavior"), "random_move", "wanderer behavior")

	var chaser: Dictionary = cfg.get_enemy_type("chaser")
	t.assert_true(chaser.size() > 0, "get_enemy_type('chaser') returns data")
	t.assert_eq(chaser.get("behavior"), "track_head", "chaser behavior")

	var bog: Dictionary = cfg.get_enemy_type("bog_crawler")
	t.assert_true(bog.size() > 0, "get_enemy_type('bog_crawler') returns data")
	t.assert_eq(bog.get("behavior"), "seek_status", "bog_crawler behavior")

	# --- reaction API ---
	var steam: Dictionary = cfg.get_reaction("steam")
	t.assert_true(steam.size() > 0, "get_reaction('steam') returns data")
	t.assert_eq(steam.get("type_a"), "fire", "steam type_a == fire")
	t.assert_eq(steam.get("type_b"), "ice", "steam type_b == ice")

	# --- find_reaction 双向查找 ---
	var r1: Dictionary = cfg.find_reaction("fire", "ice")
	t.assert_true(r1.size() > 0, "find_reaction('fire','ice') returns data")
	t.assert_eq(r1.get("display_name"), "蒸腾", "fire+ice = 蒸腾")

	var r2: Dictionary = cfg.find_reaction("ice", "fire")
	t.assert_true(r2.size() > 0, "find_reaction('ice','fire') returns data (reverse)")
	t.assert_eq(r2.get("display_name"), "蒸腾", "ice+fire = 蒸腾 (reverse)")

	var r3: Dictionary = cfg.find_reaction("fire", "poison")
	t.assert_eq(r3.get("display_name"), "毒爆", "fire+poison = 毒爆")

	# --- 不存在的 reaction ---
	var r_none: Dictionary = cfg.find_reaction("ice", "poison")
	t.assert_eq(r_none.size(), 0, "ice+poison has no reaction")

	# --- ID 列表 ---
	var se_ids: Array = cfg.get_status_effect_ids()
	t.assert_true(se_ids.has("fire"), "status_effect_ids has fire")
	t.assert_true(se_ids.has("ice"), "status_effect_ids has ice")
	t.assert_true(se_ids.has("poison"), "status_effect_ids has poison")

	var et_ids: Array = cfg.get_enemy_type_ids()
	t.assert_true(et_ids.has("wanderer"), "enemy_type_ids has wanderer")
	t.assert_true(et_ids.has("chaser"), "enemy_type_ids has chaser")
	t.assert_true(et_ids.has("bog_crawler"), "enemy_type_ids has bog_crawler")

	# --- Constants var aliases 从 ConfigManager 读取 ---
	t.assert_eq(Constants.cell_size, 32, "Constants.cell_size var alias == 32")
	t.assert_eq(Constants.grid_width, 40, "Constants.grid_width var alias == 40")
	t.assert_eq(Constants.grid_height, 22, "Constants.grid_height var alias == 22")
	t.assert_eq(Constants.viewport_width, 40 * 32, "Constants.viewport_width derived")
	t.assert_eq(Constants.viewport_height, 22 * 32, "Constants.viewport_height derived")
	t.assert_eq(Constants.base_tick_interval, 0.25, "Constants.base_tick_interval var alias")
	t.assert_eq(Constants.initial_snake_length, 6, "Constants.initial_snake_length var alias")
