extends RefCounted
## L4 Phase 1+3: Config loading tests (T001-T004) and ScaleRewardSystem tests (T009-T013).

const SCALE_REWARD_PATH: String = "res://systems/growth/scale_reward_system.gd"
const SCALE_CHOICE_PANEL_PATH: String = "res://ui/scale_choice_panel.gd"

var _presented_events: Array = []
var _chosen_events: Array = []

func run(t) -> void:
	_test_l4_config_sections(t)
	_test_l4_shedskin_config(t)
	_test_l4_scale_reward_config(t)
	_test_l4_shop_config(t)
	_test_l4_difficulty_config(t)
	_test_l4_room_modifier_config(t)
	_test_l4_floor_theme_config(t)
	_test_l4_event_contracts(t)
	_test_scale_reward_system_offer_and_choose(t)
	_test_scale_choice_panel(t)
	_test_l4_config_sections(t)
	_test_l4_shedskin_config(t)
	_test_l4_scale_reward_config(t)
	_test_l4_shop_config(t)
	_test_l4_difficulty_config(t)
	_test_l4_room_modifier_config(t)
	_test_l4_floor_theme_config(t)
	_test_l4_event_contracts(t)


func _test_l4_config_sections(t) -> void:
	t.assert_true(ConfigManager.growth is Dictionary, "[L4] growth section is Dictionary")
	t.assert_true(ConfigManager.shop is Dictionary, "[L4] shop section is Dictionary")
	t.assert_true(ConfigManager.difficulty is Dictionary, "[L4] difficulty section is Dictionary")
	t.assert_true(ConfigManager.room_modifiers is Dictionary, "[L4] room_modifiers section is Dictionary")
	t.assert_true(ConfigManager.floor_themes is Dictionary, "[L4] floor_themes section is Dictionary")

	var growth_cfg: Dictionary = ConfigManager.get_growth_config()
	t.assert_true(growth_cfg.get("enabled", false), "[L4] growth config enabled")


func _test_l4_shedskin_config(t) -> void:
	var shedskin: Dictionary = ConfigManager.get_shedskin_config()
	t.assert_true(shedskin is Dictionary, "[L4] shedskin config is Dictionary")
	t.assert_eq(int(shedskin.get("kill_normal", 0)), 1, "[L4] kill_normal = 1")
	t.assert_eq(int(shedskin.get("kill_elite", 0)), 3, "[L4] kill_elite = 3")
	t.assert_eq(int(shedskin.get("scale_discard", 0)), 2, "[L4] scale_discard = 2")


func _test_l4_scale_reward_config(t) -> void:
	var cfg: Dictionary = ConfigManager.get_scale_reward_config()
	t.assert_eq(int(cfg.get("offer_count", 0)), 3, "[L4] scale reward offer_count = 3")
	t.assert_true(cfg.get("trigger_room_types", []).has("combat"), "[L4] combat triggers scale reward")

	var pool_ids: Array = ConfigManager.get_scale_reward_pool_ids()
	t.assert_true(pool_ids.has("l1_basic"), "[L4] l1_basic scale reward pool exists")

	var pool: Array = ConfigManager.get_scale_reward_pool("l1_basic")
	t.assert_true(pool.size() >= 3, "[L4] l1_basic has at least 3 options")
	for option in pool:
		t.assert_true(option is Dictionary, "[L4] scale option is Dictionary")
		t.assert_true(option.has("target_id"), "[L4] scale option has target_id")
		t.assert_true(option.has("target_slot"), "[L4] scale option has target_slot")
		t.assert_true(option.has("reward_type"), "[L4] scale option has reward_type")


func _test_l4_shop_config(t) -> void:
	var cfg: Dictionary = ConfigManager.get_shop_config()
	t.assert_true(cfg.get("enabled", false), "[L4] shop enabled")
	t.assert_true(int(cfg.get("max_items_per_shop", 0)) >= 3, "[L4] shop has at least 3 item slots")

	var categories: Dictionary = cfg.get("item_categories", {})
	t.assert_true(categories.has("scale_l1"), "[L4] shop has scale_l1 category")
	t.assert_true(categories.has("slot_front"), "[L4] shop has slot_front category")
	t.assert_true(categories.has("head_upgrade"), "[L4] shop has head_upgrade category")

	t.assert_eq(ConfigManager.get_shop_item_price("scale_l1"), 2, "[L4] scale_l1 price = 2")
	t.assert_eq(ConfigManager.get_shop_item_category("scale_l1"), "scale", "[L4] scale_l1 category = scale")
	t.assert_eq(ConfigManager.get_shop_item_price("slot_front"), 5, "[L4] slot_front price = 5")


func _test_l4_difficulty_config(t) -> void:
	var cfg: Dictionary = ConfigManager.get_difficulty_config()
	t.assert_true(cfg.get("enabled", false), "[L4] difficulty enabled")
	t.assert_eq(int(cfg.get("baseline_enemy_count", 0)), 3, "[L4] baseline enemy count = 3")
	t.assert_true(float(cfg.get("overperform_threshold", 0)) > 0, "[L4] overperform_threshold > 0")
	t.assert_true(float(cfg.get("underperform_threshold", 0)) > 0, "[L4] underperform_threshold > 0")
	t.assert_true(int(cfg.get("min_enemy_count", 0)) < int(cfg.get("max_enemy_count", 0)), "[L4] min < max enemy count")


func _test_l4_room_modifier_config(t) -> void:
	var ids: Array = ConfigManager.get_room_modifier_ids()
	t.assert_true(ids.size() >= 2, "[L4] at least 2 room modifiers exist")

	for modifier_id in ["darkness", "speed_strips"]:
		t.assert_true(ids.has(modifier_id), "[L4] %s modifier exists" % modifier_id)
		var mod: Dictionary = ConfigManager.get_room_modifier(modifier_id)
		t.assert_true(mod.has("display_name"), "[L4] %s has display_name" % modifier_id)
		t.assert_true(mod.has("enabled"), "[L4] %s has enabled flag" % modifier_id)
		t.assert_true(mod.get("enabled", false), "[L4] %s is enabled" % modifier_id)


func _test_l4_floor_theme_config(t) -> void:
	var ids: Array = ConfigManager.get_floor_theme_ids()
	t.assert_true(ids.size() >= 3, "[L4] at least 3 floor themes exist")

	for theme_id in ["cave", "marsh", "ruins"]:
		t.assert_true(ids.has(theme_id), "[L4] %s theme exists" % theme_id)
		var theme: Dictionary = ConfigManager.get_floor_theme(theme_id)
		t.assert_true(theme.has("environment"), "[L4] %s has environment" % theme_id)
		t.assert_true(theme.has("terrain_templates"), "[L4] %s has terrain_templates" % theme_id)
		t.assert_true(theme.has("enemy_pool_weights"), "[L4] %s has enemy_pool_weights" % theme_id)


func _test_l4_event_contracts(t) -> void:
	for signal_name in [
		"currency_changed",
		"scale_reward_presented",
		"scale_reward_chosen",
		"shop_entered",
		"shop_purchase",
		"slot_unlocked",
		"floor_reward_presented",
		"floor_reward_chosen",
		"difficulty_adjusted",
		"room_modifier_applied",
	]:
		t.assert_has_signal(EventBus, signal_name)


func _test_scale_reward_system_offer_and_choose(t) -> void:
	t.assert_file_exists(SCALE_REWARD_PATH)
	if not FileAccess.file_exists(SCALE_REWARD_PATH):
		return

	var mock_snake := Node2D.new()
	mock_snake.name = "ScaleMockSnake"

	var scale_mgr: Node = load("res://systems/snake_parts/scale_slot_manager.gd").new()
	scale_mgr.init_manager(mock_snake, StatusEffectManager._trigger_manager, StatusEffectManager._chain_resolver)

	var system: Node = load(SCALE_REWARD_PATH).new()
	system.setup(scale_mgr, null)
	t.add_child(system)

	_presented_events.clear()
	_chosen_events.clear()
	EventBus.scale_reward_presented.connect(_on_scale_presented)
	EventBus.scale_reward_chosen.connect(_on_scale_chosen)

	system.present_offer({"room_id": "combat_test", "room_type": "combat"})
	t.assert_eq(_presented_events.size(), 1, "[L4-US1] scale reward presented on combat completion")
	var offer: Dictionary = _presented_events[0]
	var options: Array = offer.get("options", [])
	t.assert_eq(options.size(), 3, "[L4-US1] scale offer has exactly 3 options")
	t.assert_true(system.has_pending_offer(), "[L4-US1] pending offer tracked")

	var chosen: bool = system.choose_scale(0)
	t.assert_true(chosen, "[L4-US1] choosing first scale succeeds")
	t.assert_eq(_chosen_events.size(), 1, "[L4-US1] scale_reward_chosen emitted")
	t.assert_false(system.has_pending_offer(), "[L4-US1] pending offer cleared after choice")

	EventBus.scale_reward_presented.disconnect(_on_scale_presented)
	EventBus.scale_reward_chosen.disconnect(_on_scale_chosen)

	system.cleanup()
	scale_mgr.clear_all()
	scale_mgr.free()
	mock_snake.free()
	system.queue_free()


func _test_scale_choice_panel(t) -> void:
	t.assert_file_exists(SCALE_CHOICE_PANEL_PATH)
	if not FileAccess.file_exists(SCALE_CHOICE_PANEL_PATH):
		return

	var panel: Control = load(SCALE_CHOICE_PANEL_PATH).new()
	t.add_child(panel)

	var options: Array = []
	for i in range(3):
		options.append({
			"option_id": "test_%d" % i,
			"display_name": "测试鳞片 %d" % i,
			"target_id": "flame_scale",
			"target_slot": "middle",
			"level": 1,
			"placeholder_color": "#FF5722",
		})
	EventBus.scale_reward_presented.emit({"source_room_id": "test", "options": options})

	t.assert_true(panel.visible, "[L4-US1] scale panel visible on reward presented")
	t.assert_eq(panel.get_visible_option_count(), 3, "[L4-US1] 3 options visible")
	t.assert_true(panel.get_option_labels().has("测试鳞片 0"), "[L4-US1] option labels readable")

	panel.queue_free()


func _on_scale_presented(data: Dictionary) -> void:
	_presented_events.append(data)


func _on_scale_chosen(data: Dictionary) -> void:
	_chosen_events.append(data)