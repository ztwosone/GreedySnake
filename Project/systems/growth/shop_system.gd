class_name ShopSystem
extends Node

var _shedskin_system: Node = null
var _scale_slot_mgr: Node = null
var _snake_parts_mgr: Node = null
var _shop_panel: Control = null
var _current_inventory: Array = []
var _shop_active: bool = false


func _ready() -> void:
	connect_events()


func _exit_tree() -> void:
	disconnect_events()


func setup(shedskin: Node, scale_mgr: Node, parts_mgr: Node, panel: Control) -> void:
	_shedskin_system = shedskin
	_scale_slot_mgr = scale_mgr
	_snake_parts_mgr = parts_mgr
	_shop_panel = panel


func connect_events() -> void:
	if not EventBus.room_entered.is_connected(_on_room_entered):
		EventBus.room_entered.connect(_on_room_entered)


func disconnect_events() -> void:
	if EventBus.room_entered.is_connected(_on_room_entered):
		EventBus.room_entered.disconnect(_on_room_entered)


func enter_shop(room_id: String) -> void:
	var shop_cfg: Dictionary = ConfigManager.get_shop_config()
	if not shop_cfg.get("enabled", false):
		return

	_shop_active = true
	_current_inventory = _generate_inventory()

	EventBus.shop_entered.emit({
		"room_id": room_id,
		"items": _current_inventory.duplicate(true),
	})


func exit_shop() -> void:
	_shop_active = false
	_current_inventory.clear()


func purchase(item_id: String) -> bool:
	if not _shop_active or _shedskin_system == null:
		return false

	var item: Dictionary = _find_item(item_id)
	if item.is_empty():
		return false
	if bool(item.get("purchased", false)):
		return false

	var price: int = int(item.get("price", 0))
	if not _shedskin_system.can_afford(price):
		return false

	var success: bool = _execute_purchase(item)
	if not success:
		return false

	_shedskin_system.spend(price, item_id)
	item["purchased"] = true
	item["affordable"] = false

	EventBus.shop_purchase.emit({
		"item_id": item_id,
		"category": item.get("category", ""),
		"cost": price,
		"currency_remaining": _shedskin_system.get_amount(),
	})

	return true


func get_inventory() -> Array:
	return _current_inventory.duplicate(true)


func is_active() -> bool:
	return _shop_active


func cleanup() -> void:
	_shop_active = false
	_current_inventory.clear()
	disconnect_events()


func _generate_inventory() -> Array:
	var shop_cfg: Dictionary = ConfigManager.get_shop_config()
	var max_items: int = int(shop_cfg.get("max_items_per_shop", 5))
	var categories: Dictionary = shop_cfg.get("item_categories", {})
	var result: Array = []

	for cat_id in categories:
		if result.size() >= max_items:
			break
		if not _can_generate_item(cat_id, categories[cat_id]):
			continue
		var item: Dictionary = _make_item(cat_id, categories[cat_id])
		result.append(item)

	return result


func _can_generate_item(cat_id: String, cat_cfg: Dictionary) -> bool:
	var category: String = cat_cfg.get("category", "")
	match category:
		"scale":
			return _scale_slot_mgr != null
		"slot":
			if _scale_slot_mgr == null:
				return false
			var slot_cfg: Dictionary = ConfigManager.get_slot_expansion_config()
			var max_slots: Dictionary = slot_cfg.get("max", {})
			var pos: String = _slot_position_from_id(cat_id)
			var current_count: int = 1
			if _scale_slot_mgr.has_method("get_scales"):
				current_count = _scale_slot_mgr.get_scales(pos).size()
			var max_count: int = int(max_slots.get(pos, 1))
			return current_count < max_count
		"head_upgrade", "tail_upgrade":
			return _snake_parts_mgr != null
	return true


func _make_item(cat_id: String, cat_cfg: Dictionary) -> Dictionary:
	var price: int = int(cat_cfg.get("price", 0))
	return {
		"item_id": cat_id,
		"category": cat_cfg.get("category", ""),
		"target_id": cat_id,
		"price": price,
		"level": 1,
		"purchased": false,
		"affordable": _shedskin_system != null and _shedskin_system.can_afford(price),
		"display_name": cat_cfg.get("display_name", cat_id),
		"placeholder_color": _placeholder_color_for(cat_id),
	}


func _execute_purchase(item: Dictionary) -> bool:
	var category: String = item.get("category", "")
	var target_id: String = item.get("target_id", "")
	match category:
		"scale":
			if _scale_slot_mgr == null:
				return false
			var scale_id: String = _random_scale_for_slot()
			var slot: String = "middle"
			return _scale_slot_mgr.equip_scale(slot, scale_id, 1)
		"slot":
			if _scale_slot_mgr == null:
				return false
			var pos: String = _slot_position_from_id(target_id)
			return true
		"head_upgrade":
			if _snake_parts_mgr == null or not _snake_parts_mgr.has_head():
				return false
			return _snake_parts_mgr.upgrade_head()
		"tail_upgrade":
			if _snake_parts_mgr == null or not _snake_parts_mgr.has_tail():
				return false
			return _snake_parts_mgr.upgrade_tail()
	return false


func _find_item(item_id: String) -> Dictionary:
	for item in _current_inventory:
		if item is Dictionary and item.get("item_id", "") == item_id:
			return item
	return {}


func _slot_position_from_id(cat_id: String) -> String:
	if cat_id.find("front") >= 0:
		return "front"
	if cat_id.find("middle") >= 0:
		return "middle"
	if cat_id.find("back") >= 0:
		return "back"
	return "middle"


func _random_scale_for_slot() -> String:
	var pool: Array = ConfigManager.get_scale_reward_pool("l1_basic")
	if pool.size() > 0:
		return pool[0].get("target_id", "flame_scale")
	return "flame_scale"


func _placeholder_color_for(cat_id: String) -> String:
	if cat_id.find("scale") >= 0:
		return "#E4572E"
	if cat_id.find("slot") >= 0:
		return "#4FC3F7"
	if cat_id.find("head") >= 0:
		return "#C85F3D"
	if cat_id.find("tail") >= 0:
		return "#D9823B"
	return "#FFFFFF"


func _on_room_entered(data: Dictionary) -> void:
	if _shop_active:
		return
	var room_type: String = data.get("room_type", "")
	var shop_cfg: Dictionary = ConfigManager.get_shop_config()
	var shop_room_type: String = shop_cfg.get("room_type", "shop")
	if room_type != shop_room_type:
		return
	enter_shop(data.get("room_id", ""))