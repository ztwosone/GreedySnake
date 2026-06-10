extends RefCounted
## L4 US2 重验收测试（spec 002 T013/T014，2026-06-11 修订版 spec 对照）：
## 商店——种子 RNG 抽货（草稿 :198 pool[0] 伪随机回归）、货架构成（shelf_plan，≤5 项，
## SC-003 ≥3 项）、容量按**开放槽位**判定（草稿 :130 误用已装数回归）、
## room_entered 退店通路（草稿 exit_shop 无调用方）、`shop.price_multiplier_per_floor`
## 消费（FR-003 经济压力阀）、空货架自动决议（FR-014）、买不起标记禁用（US2 场景 4）。

const SHOP_PATH: String = "res://systems/growth/shop_system.gd"
const SHOP_PANEL_PATH: String = "res://ui/shop_panel.gd"
const SHEDSKIN_PATH: String = "res://systems/growth/shedskin_system.gd"
const SLOT_EXPANSION_PATH: String = "res://systems/growth/slot_expansion_system.gd"
const SCALE_SLOT_MANAGER_PATH: String = "res://systems/snake_parts/scale_slot_manager.gd"
const SNAKE_PARTS_MANAGER_PATH: String = "res://systems/snake_parts/snake_parts_manager.gd"

var _shop_events: Array = []
var _purchase_events: Array = []


func run(t) -> void:
	_test_shop_config(t)
	_test_seeded_inventory_determinism(t)
	_test_inventory_composition(t)
	_test_capacity_uses_open_slots_not_equipped(t)
	_test_price_multiplier_per_floor(t)
	_test_exit_shop_via_room_entered(t)
	_test_empty_shelf_auto_resolves(t)
	_test_purchase_flow(t)
	_test_shop_panel_public_api(t)


# ── T013: 配置（FR-010/SC-003） ──────────────────────────────────────

func _test_shop_config(t) -> void:
	var room_cfg: Dictionary = ConfigManager.get_room_type("shop")
	t.assert_true(not room_cfg.is_empty(), "[L4-US2] room_types.shop exists")
	t.assert_true(bool(room_cfg.get("auto_complete_on_enter", false)),
		"[L4-US2] shop room auto-completes on enter (exit is walking on, no objective gate)")

	var cfg: Dictionary = ConfigManager.get_shop_config()
	t.assert_true(bool(cfg.get("enabled", false)), "[L4-US2] shop enabled")
	t.assert_eq(int(cfg.get("max_items_per_shop", 0)), 5, "[L4-US2] max 5 items per shop (design gate)")
	t.assert_true(float(cfg.get("price_multiplier_per_floor", 0.0)) > 1.0,
		"[L4-US2] price_multiplier_per_floor > 1 (FR-003 pressure valve)")
	t.assert_true(cfg.get("shelf_plan", {}) is Dictionary and not cfg.get("shelf_plan", {}).is_empty(),
		"[L4-US2] shelf plan is JSON data (no hardcoded shelf composition)")
	t.assert_true(str(cfg.get("scale_pool", "")) != "",
		"[L4-US2] shop scale pool id is JSON-configured (draft :199 hardcoded pool id)")

	var categories: Dictionary = cfg.get("item_categories", {})
	var seen_categories: Dictionary = {}
	for cat_id in categories:
		var cat: Dictionary = categories[cat_id]
		seen_categories[str(cat.get("category", ""))] = true
		t.assert_true(int(cat.get("price", 0)) > 0, "[L4-US2] %s has a positive JSON price" % cat_id)
		if str(cat.get("category", "")) == "scale":
			t.assert_true(int(cat.get("level", 0)) >= 1, "[L4-US2] scale tier %s carries its level in JSON" % cat_id)
	for required in ["scale", "slot", "head_upgrade", "tail_upgrade"]:
		t.assert_true(seen_categories.has(required), "[L4-US2] FR-004: shop sells %s" % required)


# ── T014: 种子 RNG 抽货（草稿 :198 pool[0] 回归） ────────────────────

func _test_seeded_inventory_determinism(t) -> void:
	t.assert_file_exists(SHOP_PATH)
	if not FileAccess.file_exists(SHOP_PATH):
		return

	var first: Array = _inventory_for_seed(t, 4242)
	var second: Array = _inventory_for_seed(t, 4242)
	t.assert_true(first.size() > 0, "[L4-US2] seeded shop generates items")
	t.assert_eq(_inventory_signature(first), _inventory_signature(second),
		"[L4-US2] same run seed + room -> identical inventory (deterministic)")

	var distinct_targets: Dictionary = {}
	for seed_value in range(1, 13):
		for item in _inventory_for_seed(t, seed_value):
			if str(item.get("category", "")) == "scale":
				distinct_targets[str(item.get("target_id", ""))] = true
	t.assert_true(distinct_targets.size() >= 2,
		"[L4-US2] scale draws vary across seeds (draft regression: always pool[0])")


# ── T013: 货架构成（shelf_plan + SC-003） ────────────────────────────

func _test_inventory_composition(t) -> void:
	var setup: Dictionary = _make_shop_setup(t, true)
	var shop: Node = setup["shop"]
	_connect_recorders()

	EventBus.run_started.emit({"run_id": "shop_test", "floor_index": 1, "seed": 777})
	EventBus.room_entered.emit({"room_id": "shop_01", "room_type": "shop"})

	t.assert_eq(_shop_events.size(), 1, "[L4-US2] entering a shop room emits shop_entered")
	t.assert_true(shop.is_active(), "[L4-US2] shop active after room entry")
	var items: Array = shop.get_inventory()
	t.assert_true(items.size() >= 3, "[L4-US2] SC-003: shop displays at least 3 items")
	t.assert_true(items.size() <= int(ConfigManager.get_shop_config().get("max_items_per_shop", 5)),
		"[L4-US2] shop respects max_items_per_shop")

	var plan: Dictionary = ConfigManager.get_shop_config().get("shelf_plan", {})
	var counts: Dictionary = {}
	var item_ids: Dictionary = {}
	var pool_targets: Dictionary = {}
	for option in ConfigManager.get_scale_reward_pool(str(ConfigManager.get_shop_config().get("scale_pool", ""))):
		pool_targets[str(option.get("target_id", ""))] = true
	for item in items:
		var category: String = str(item.get("category", ""))
		counts[category] = int(counts.get(category, 0)) + 1
		t.assert_true(int(item.get("price", 0)) > 0, "[L4-US2] item has a visible price")
		t.assert_true(str(item.get("display_name", "")) != "", "[L4-US2] item has a readable name")
		t.assert_false(item_ids.has(str(item.get("item_id", ""))), "[L4-US2] item ids unique on the shelf")
		item_ids[str(item.get("item_id", ""))] = true
		if category == "scale":
			t.assert_true(pool_targets.has(str(item.get("target_id", ""))),
				"[L4-US2] scale item target drawn from the configured pool")
			t.assert_true(int(item.get("level", 0)) >= 1, "[L4-US2] scale item carries its tier level")
	for category in plan:
		t.assert_eq(int(counts.get(str(category), 0)), int(plan[category]),
			"[L4-US2] shelf follows JSON shelf_plan for %s" % category)

	_disconnect_recorders()
	_teardown_shop_setup(setup)


# ── T014: 容量按开放槽位（草稿 :130 误用已装数回归） ─────────────────

func _test_capacity_uses_open_slots_not_equipped(t) -> void:
	var setup: Dictionary = _make_shop_setup(t, true)
	var shop: Node = setup["shop"]
	var scale_mgr: Node = setup["scale_mgr"]

	# 全部位置开满、零装备：按"已装数"判会继续上架槽位（草稿缺陷），按"开放数"判则不上架
	for position in ["front", "middle", "back"]:
		while scale_mgr.open_slot(position):
			pass
	t.assert_eq(scale_mgr.get_open_slots("middle"), scale_mgr.get_max_slots("middle"),
		"[L4-US2] precondition: all slots open, none equipped")

	EventBus.run_started.emit({"run_id": "cap_test", "floor_index": 1, "seed": 99})
	var items: Array = shop.enter_shop("shop_cap")
	for item in items:
		t.assert_true(str(item.get("category", "")) != "slot",
			"[L4-US2] no slot items shelved when open slots are at max (draft :130 regression)")

	_teardown_shop_setup(setup)


# ── T014: 物价乘数（FR-003/SC-002） ──────────────────────────────────

func _test_price_multiplier_per_floor(t) -> void:
	var multiplier: float = ConfigManager.get_shop_price_multiplier_per_floor()

	var floor1: Array = _inventory_for_seed(t, 555, 1)
	var floor2: Array = _inventory_for_seed(t, 555, 2)
	t.assert_eq(floor1.size(), floor2.size(), "[L4-US2] same seed -> same shelf across floors")
	for index in range(floor1.size()):
		var base_price: int = int(floor1[index].get("price", 0))
		var floor2_price: int = int(floor2[index].get("price", 0))
		t.assert_eq(floor2_price, int(ceil(base_price * multiplier)),
			"[L4-US2] floor 2 price = ceil(base x multiplier) for %s" % floor1[index].get("item_id", ""))
		t.assert_true(floor2_price > base_price, "[L4-US2] later floor strictly pricier (pressure valve)")

	# floor 1 物价 = 基准价（item_categories.price 原值）
	var categories: Dictionary = ConfigManager.get_shop_config().get("item_categories", {})
	for item in floor1:
		var cat: Dictionary = categories.get(str(item.get("item_id", "")), {})
		if not cat.is_empty():
			t.assert_eq(int(item.get("price", 0)), int(cat.get("price", 0)),
				"[L4-US2] floor 1 price equals JSON base price for %s" % item.get("item_id", ""))


# ── T014: room_entered 退店（草稿 exit_shop 无调用方） ───────────────

func _test_exit_shop_via_room_entered(t) -> void:
	var setup: Dictionary = _make_shop_setup(t, true)
	var shop: Node = setup["shop"]
	var shedskin: Node = setup["shedskin"]
	shedskin.earn(20, "test_bankroll")

	EventBus.run_started.emit({"run_id": "exit_test", "floor_index": 1, "seed": 31})
	EventBus.room_entered.emit({"room_id": "shop_01", "room_type": "shop"})
	t.assert_true(shop.is_active(), "[L4-US2] shop opens on shop room entry")
	var first_item_id: String = str(shop.get_inventory()[0].get("item_id", ""))

	EventBus.room_entered.emit({"room_id": "shop_01", "room_type": "shop"})
	t.assert_true(shop.is_active(), "[L4-US2] duplicate shop room entry is idempotent")

	EventBus.room_entered.emit({"room_id": "rest_01", "room_type": "rest"})
	t.assert_false(shop.is_active(), "[L4-US2] entering another room exits the shop (room_entered pathway)")
	t.assert_eq(shop.get_inventory().size(), 0, "[L4-US2] inventory cleared on exit")
	t.assert_false(shop.purchase(first_item_id), "[L4-US2] purchase refused after exit")

	_disconnect_recorders()
	_teardown_shop_setup(setup)


# ── T014: 空货架自动决议（FR-014/SC-012） ────────────────────────────

func _test_empty_shelf_auto_resolves(t) -> void:
	var shop: Node = load(SHOP_PATH).new()
	shop.setup(null, null, null)  # 无 Build 系统 = 零可上架项
	t.add_child(shop)
	_connect_recorders()

	var items: Array = shop.enter_shop("shop_empty")
	t.assert_eq(items.size(), 0, "[L4-FR014] zero eligible items -> empty shelf")
	t.assert_eq(_shop_events.size(), 0, "[L4-FR014] empty shelf presents NO shop_entered (auto-resolve)")
	t.assert_false(shop.is_active(), "[L4-FR014] shop never goes active on empty shelf")

	_disconnect_recorders()
	shop.cleanup()
	shop.queue_free()


# ── T014: 购买流（US2 场景 3/4 + SC-002 扣款） ───────────────────────

func _test_purchase_flow(t) -> void:
	var setup: Dictionary = _make_shop_setup(t, true)
	var shop: Node = setup["shop"]
	var shedskin: Node = setup["shedskin"]
	var scale_mgr: Node = setup["scale_mgr"]
	var parts_mgr: Node = setup["parts_mgr"]
	var slot_adapter: Node = load(SLOT_EXPANSION_PATH).new()
	slot_adapter.setup(scale_mgr)
	t.add_child(slot_adapter)
	_connect_recorders()

	EventBus.run_started.emit({"run_id": "buy_test", "floor_index": 1, "seed": 777})
	EventBus.room_entered.emit({"room_id": "shop_01", "room_type": "shop"})
	var items: Array = shop.get_inventory()
	t.assert_true(items.size() >= 3, "[L4-US2] precondition: stocked shelf")

	# 余额 0：全部禁用、购买被拒、不扣款（US2 场景 4）
	for item in items:
		t.assert_false(bool(item.get("affordable", true)),
			"[L4-US2] item %s marked unaffordable at 0 shedskin" % item.get("item_id", ""))
	t.assert_false(shop.purchase(str(items[0].get("item_id", ""))), "[L4-US2] purchase refused when broke")
	t.assert_eq(_purchase_events.size(), 0, "[L4-US2] refused purchase emits nothing")

	shedskin.earn(40, "test_bankroll")
	items = shop.get_inventory()
	for item in items:
		t.assert_true(bool(item.get("affordable", false)),
			"[L4-US2] affordability refreshes once funded")

	# 鳞片：装备到对应位置、按 tier 等级（US2 场景 3）
	var scale_item: Dictionary = _find_by_category(items, "scale")
	t.assert_true(not scale_item.is_empty(), "[L4-US2] shelf carries a scale item")
	if not scale_item.is_empty():
		var balance_before: int = shedskin.get_amount()
		t.assert_true(shop.purchase(str(scale_item.get("item_id", ""))), "[L4-US2] scale purchase succeeds")
		t.assert_eq(shedskin.get_amount(), balance_before - int(scale_item.get("price", 0)),
			"[L4-US2] SC-002: currency deducted by item price")
		var equipped: Array = scale_mgr.get_scales(str(scale_item.get("target_slot", "")))
		t.assert_true(equipped.size() >= 1, "[L4-US2] purchased scale equips immediately")
		if equipped.size() >= 1:
			t.assert_eq(equipped[0].part_id, str(scale_item.get("target_id", "")),
				"[L4-US2] equipped scale matches the purchased target")
			t.assert_eq(equipped[0].level, int(scale_item.get("level", 0)),
				"[L4-US2] equipped scale carries the tier level")
		t.assert_eq(_purchase_events.size(), 1, "[L4-US2] shop_purchase emitted")
		if _purchase_events.size() > 0:
			t.assert_eq(_purchase_events[0].get("item_id", ""), scale_item.get("item_id", ""),
				"[L4-US2] payload item_id")
			t.assert_eq(int(_purchase_events[0].get("cost", 0)), int(scale_item.get("price", 0)),
				"[L4-US2] payload cost")
			t.assert_eq(int(_purchase_events[0].get("currency_remaining", -1)), shedskin.get_amount(),
				"[L4-US2] payload currency_remaining")
		t.assert_false(shop.purchase(str(scale_item.get("item_id", ""))), "[L4-US2] re-buying a sold item refused")

	# 槽位：购买经 shop_purchase 事件链由适配器真开槽（T012 接缝）
	var slot_item: Dictionary = _find_by_category(shop.get_inventory(), "slot")
	t.assert_true(not slot_item.is_empty(), "[L4-US2] shelf carries a slot item")
	if not slot_item.is_empty():
		var position: String = str(slot_item.get("target_slot", ""))
		var open_before: int = scale_mgr.get_open_slots(position)
		t.assert_true(shop.purchase(str(slot_item.get("item_id", ""))), "[L4-US3] slot purchase succeeds")
		t.assert_eq(scale_mgr.get_open_slots(position), open_before + 1,
			"[L4-US3] slot purchase REALLY opens the slot (draft regression: zero effect)")

	# 蛇头/蛇尾升级：等级 +1
	var head_item: Dictionary = _find_by_category(shop.get_inventory(), "head_upgrade")
	t.assert_true(not head_item.is_empty(), "[L4-US2] shelf carries a head upgrade")
	if not head_item.is_empty():
		t.assert_true(shop.purchase(str(head_item.get("item_id", ""))), "[L4-US2] head upgrade purchase succeeds")
		t.assert_eq(parts_mgr.get_active_head().level, 2, "[L4-US2] head upgraded to level 2")
	var tail_item: Dictionary = _find_by_category(shop.get_inventory(), "tail_upgrade")
	t.assert_true(not tail_item.is_empty(), "[L4-US2] shelf carries a tail upgrade")
	if not tail_item.is_empty():
		t.assert_true(shop.purchase(str(tail_item.get("item_id", ""))), "[L4-US2] tail upgrade purchase succeeds")
		t.assert_eq(parts_mgr.get_active_tail().level, 2, "[L4-US2] tail upgraded to level 2")

	_disconnect_recorders()
	slot_adapter.cleanup()
	slot_adapter.queue_free()
	_teardown_shop_setup(setup)


# ── T015: 商店面板（ui/kit 重建，货架行 + 价格 chip + 禁用去饱和） ───

func _test_shop_panel_public_api(t) -> void:
	t.assert_file_exists(SHOP_PANEL_PATH)
	if not FileAccess.file_exists(SHOP_PANEL_PATH):
		return

	var setup: Dictionary = _make_shop_setup(t, true)
	var shop: Node = setup["shop"]
	var shedskin: Node = setup["shedskin"]
	var panel: Control = load(SHOP_PANEL_PATH).new()
	panel.setup(shop)
	t.add_child(panel)

	t.assert_false(panel.visible, "[L4-US2] panel starts hidden")
	t.assert_true(panel.is_in_group("ui_kit"), "[L4-US2] panel born on ui/kit base")
	t.assert_true(panel.is_in_group("ui_modal"), "[L4-US2] panel joins ui_modal group (geometry probe)")
	t.assert_eq(str(panel.get_meta("ui_layer", "")), "modal", "[L4-US2] panel carries modal ui_layer meta")

	EventBus.run_started.emit({"run_id": "panel_test", "floor_index": 1, "seed": 777})
	shedskin.earn(4, "panel_bankroll")  # 鳞片/头尾(≤4)可买、槽位(5)买不起 → 禁用态混排
	EventBus.room_entered.emit({"room_id": "shop_01", "room_type": "shop"})

	t.assert_true(panel.visible, "[L4-US2] panel visible on shop_entered")
	var items: Array = shop.get_inventory()
	t.assert_eq(panel.get_visible_item_count(), items.size(), "[L4-US2] panel mirrors inventory size")
	t.assert_true(panel.get_visible_item_count() <= 5, "[L4-US2] at most 5 shelf rows")
	t.assert_eq(panel.get_item_rows().size(), items.size(), "[L4-US2] one shelf row per item")
	t.assert_eq(panel.get_balance_text(), str(shedskin.get_amount()), "[L4-US2] balance chip shows shedskin")

	for index in range(items.size()):
		var item: Dictionary = items[index]
		t.assert_true(panel.get_item_labels().has(str(item.get("display_name", ""))),
			"[L4-US2] item label readable: %s" % item.get("display_name", ""))
		var row: Control = panel.get_item_rows()[index]
		t.assert_true(row.is_in_group("ui_hit"), "[L4-US2] shelf row registered as hit target")
		t.assert_true(panel.get_row_price_text(index).find(str(int(item.get("price", 0)))) >= 0,
			"[L4-US2] price chip shows the price for %s" % item.get("item_id", ""))
		t.assert_eq(panel.is_item_disabled(index), not bool(item.get("affordable", false)),
			"[L4-US2] US2 scenario 4: unaffordable item visibly disabled (%s)" % item.get("item_id", ""))

	# 买不起的行：点击购买被拒
	var slot_index: int = _index_by_category(items, "slot")
	t.assert_true(slot_index >= 0, "[L4-US2] shelf carries a slot row")
	if slot_index >= 0:
		t.assert_true(panel.is_item_disabled(slot_index), "[L4-US2] 5-cost slot disabled at 4 shedskin")
		t.assert_false(panel.purchase_by_index(slot_index), "[L4-US2] disabled row refuses purchase")

	# 买得起的行：购买成功 → 已购禁用 + 余额刷新
	var head_index: int = _index_by_category(items, "head_upgrade")
	t.assert_true(head_index >= 0, "[L4-US2] shelf carries a head upgrade row")
	if head_index >= 0:
		t.assert_true(panel.purchase_by_index(head_index), "[L4-US2] purchase via panel public API")
		t.assert_eq(panel.get_balance_text(), str(shedskin.get_amount()),
			"[L4-US2] balance chip refreshes after purchase")
		t.assert_true(panel.is_item_disabled(head_index), "[L4-US2] sold row goes disabled (已购)")
		t.assert_false(panel.purchase_by_index(head_index), "[L4-US2] sold row refuses re-purchase")

	# 入账触发可买性刷新（货币变化重渲染）
	shedskin.earn(20, "panel_topup")
	if slot_index >= 0:
		t.assert_false(panel.is_item_disabled(slot_index), "[L4-US2] funding re-enables the slot row")

	# 退店通路：进入其他房间隐藏面板
	EventBus.room_entered.emit({"room_id": "rest_01", "room_type": "rest"})
	t.assert_false(panel.visible, "[L4-US2] panel hides when leaving via room_entered")
	t.assert_eq(panel.get_visible_item_count(), 0, "[L4-US2] rows cleared on exit")

	EventBus.room_entered.emit({"room_id": "shop_01", "room_type": "shop"})
	t.assert_true(panel.visible, "[L4-US2] panel reopens on next shop visit")
	EventBus.game_over.emit({"cause": "test"})
	t.assert_false(panel.visible, "[L4-US2] panel hides on game over")

	panel.queue_free()
	_teardown_shop_setup(setup)


func _index_by_category(items: Array, category: String) -> int:
	for index in range(items.size()):
		if items[index] is Dictionary and str(items[index].get("category", "")) == category:
			return index
	return -1


# ── Helpers ──────────────────────────────────────────────────────────

## 完整商店搭台：真实 ScaleSlotManager/SnakePartsManager（带头尾）+ ShedskinSystem
func _make_shop_setup(t, with_parts: bool) -> Dictionary:
	var mock_snake := Node2D.new()
	mock_snake.name = "ShopMockSnake"

	var scale_mgr: Node = load(SCALE_SLOT_MANAGER_PATH).new()
	scale_mgr.init_manager(mock_snake, StatusEffectManager._trigger_manager, StatusEffectManager._chain_resolver)

	var parts_mgr: Node = load(SNAKE_PARTS_MANAGER_PATH).new()
	parts_mgr.init_manager(mock_snake, StatusEffectManager._trigger_manager, StatusEffectManager._chain_resolver)
	if with_parts:
		parts_mgr.equip_head("hydra", 1)
		parts_mgr.equip_tail("salamander", 1)

	var shedskin: Node = load(SHEDSKIN_PATH).new()
	t.add_child(shedskin)

	var shop: Node = load(SHOP_PATH).new()
	shop.setup(shedskin, scale_mgr, parts_mgr)
	t.add_child(shop)

	return {"snake": mock_snake, "scale_mgr": scale_mgr, "parts_mgr": parts_mgr,
		"shedskin": shedskin, "shop": shop}


func _teardown_shop_setup(setup: Dictionary) -> void:
	setup["shop"].cleanup()
	setup["shedskin"].cleanup()
	setup["scale_mgr"].clear_all()
	setup["parts_mgr"].unequip_head()
	setup["parts_mgr"].unequip_tail()
	setup["shop"].queue_free()
	setup["shedskin"].queue_free()
	setup["scale_mgr"].free()
	setup["parts_mgr"].free()
	setup["snake"].free()


## 给定 run seed（与楼层）生成一次 shop_01 货架并拆台
func _inventory_for_seed(t, seed_value: int, floor_index: int = 1) -> Array:
	var setup: Dictionary = _make_shop_setup(t, true)
	EventBus.run_started.emit({"run_id": "seed_probe", "floor_index": 1, "seed": seed_value})
	if floor_index != 1:
		EventBus.floor_generated.emit({"floor_index": floor_index, "rooms": []})
	var items: Array = setup["shop"].enter_shop("shop_01")
	_teardown_shop_setup(setup)
	return items


func _inventory_signature(items: Array) -> String:
	var parts: Array = []
	for item in items:
		parts.append("%s/%s/%d/%d" % [item.get("item_id", ""), item.get("target_id", ""),
			int(item.get("level", 0)), int(item.get("price", 0))])
	return "|".join(parts)


func _find_by_category(items: Array, category: String) -> Dictionary:
	for item in items:
		if item is Dictionary and str(item.get("category", "")) == category:
			return item.duplicate(true)
	return {}


func _connect_recorders() -> void:
	_shop_events.clear()
	_purchase_events.clear()
	if not EventBus.shop_entered.is_connected(_on_shop_entered):
		EventBus.shop_entered.connect(_on_shop_entered)
	if not EventBus.shop_purchase.is_connected(_on_shop_purchase):
		EventBus.shop_purchase.connect(_on_shop_purchase)


func _disconnect_recorders() -> void:
	if EventBus.shop_entered.is_connected(_on_shop_entered):
		EventBus.shop_entered.disconnect(_on_shop_entered)
	if EventBus.shop_purchase.is_connected(_on_shop_purchase):
		EventBus.shop_purchase.disconnect(_on_shop_purchase)


func _on_shop_entered(data: Dictionary) -> void:
	_shop_events.append(data)


func _on_shop_purchase(data: Dictionary) -> void:
	_purchase_events.append(data)
