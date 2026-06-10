extends RefCounted
## L4 Phase 4: Shop and currency tests (T014-T018).

const SHEDSKIN_PATH: String = "res://systems/growth/shedskin_system.gd"
const SHOP_PATH: String = "res://systems/growth/shop_system.gd"
const SHOP_PANEL_PATH: String = "res://ui/shop_panel.gd"

var _shop_events: Array = []
var _purchase_events: Array = []


func run(t) -> void:
	_test_shop_enter_and_purchase(t)
	_test_shop_panel(t)


func _test_shop_enter_and_purchase(t) -> void:
	t.assert_file_exists(SHOP_PATH)
	t.assert_file_exists(SHEDSKIN_PATH)
	if not FileAccess.file_exists(SHOP_PATH) or not FileAccess.file_exists(SHEDSKIN_PATH):
		return

	var mock_snake := Node2D.new()
	mock_snake.name = "ShopMockSnake"

	var scale_mgr: Node = load("res://systems/snake_parts/scale_slot_manager.gd").new()
	scale_mgr.init_manager(mock_snake, StatusEffectManager._trigger_manager, StatusEffectManager._chain_resolver)

	var parts_mgr: Node = load("res://systems/snake_parts/snake_parts_manager.gd").new()
	parts_mgr.init_manager(mock_snake, StatusEffectManager._trigger_manager, StatusEffectManager._chain_resolver)

	var shedskin: Node = load(SHEDSKIN_PATH).new()
	t.add_child(shedskin)

	var shop: Node = load(SHOP_PATH).new()
	shop.setup(shedskin, scale_mgr, parts_mgr, null)
	t.add_child(shop)

	_shop_events.clear()
	_purchase_events.clear()
	EventBus.shop_entered.connect(_on_shop_entered)
	EventBus.shop_purchase.connect(_on_shop_purchase)

	shop.enter_shop("shop_test")
	t.assert_eq(_shop_events.size(), 1, "[L4-US2] shop_entered emitted")
	var items: Array = _shop_events[0].get("items", [])
	t.assert_true(items.size() > 0, "[L4-US2] shop has items")
	t.assert_true(items.size() <= 5, "[L4-US2] shop has ≤5 items")

	shedskin.earn(10, "test")
	t.assert_true(shop.purchase(items[0].get("item_id", "")), "[L4-US2] purchase succeeds with enough currency")
	t.assert_eq(_purchase_events.size(), 1, "[L4-US2] shop_purchase emitted")

	EventBus.shop_entered.disconnect(_on_shop_entered)
	EventBus.shop_purchase.disconnect(_on_shop_purchase)

	shop.cleanup()
	shedskin.cleanup()
	scale_mgr.clear_all()
	parts_mgr.unequip_head()
	parts_mgr.unequip_tail()
	scale_mgr.free()
	parts_mgr.free()
	mock_snake.free()
	shedskin.free()
	shop.free()


func _test_shop_panel(t) -> void:
	t.assert_file_exists(SHOP_PANEL_PATH)
	if not FileAccess.file_exists(SHOP_PANEL_PATH):
		return

	var panel: Control = load(SHOP_PANEL_PATH).new()
	t.add_child(panel)

	var test_items: Array = []
	for i in range(3):
		test_items.append({
			"item_id": "test_item_%d" % i,
			"display_name": "测试商品 %d" % i,
			"price": 2 + i,
			"purchased": false,
			"affordable": true,
			"category": "scale",
			"placeholder_color": "#FF5722",
		})
	EventBus.shop_entered.emit({"room_id": "test", "items": test_items})

	t.assert_true(panel.visible, "[L4-US2] shop panel visible")
	t.assert_eq(panel.get_visible_item_count(), 3, "[L4-US2] 3 items visible")
	t.assert_true(panel.get_item_labels().has("测试商品 0"), "[L4-US2] item labels readable")

	panel.queue_free()


func _on_shop_entered(data: Dictionary) -> void:
	_shop_events.append(data)


func _on_shop_purchase(data: Dictionary) -> void:
	_purchase_events.append(data)