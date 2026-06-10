class_name ShopSystem
extends Node
## 商店系统（spec 002 T014 验证修复，2026-06-11 修订版 spec）
## 判决修复点：
## - 种子 RNG 抽货：rng = hash(run seed + room_id)，同局同店两次进入同货架；
##   草稿 :198 固定取 pool[0]（伪随机）。
## - 容量按**开放槽位**判定（get_open_slots < get_max_slots）；草稿 :130 误用已装数。
## - 退店通路 = `room_entered` 进入下一房间（商店房 auto_complete_on_enter，玩家随时可走，
##   不注册模态门控——否则 FR-015 门控 + 进房退店组合必死锁）；草稿 exit_shop 无调用方。
## - 消费 `shop.price_multiplier_per_floor`（FR-003：蜕皮跨层保留，物价是唯一经济压力阀）。
## - 空货架自动决议（FR-014）：零可上架项不发 shop_entered、不进 active，流程不依赖玩家输入。
## 货架构成走 JSON `shop.shelf_plan`（FR-010）；买槽不直开槽——发 `shop_purchase`，
## SlotExpansionSystem（薄适配器）监听后经 open_slot 真开（FR-011 EventBus-only）。

var _shedskin_system: Node = null
var _scale_slot_mgr: Object = null
var _snake_parts_mgr: Object = null
var _current_inventory: Array = []
var _shop_active: bool = false
var _current_room_id: String = ""
var _run_seed: int = 0
var _floor_index: int = 1


func _ready() -> void:
	connect_events()


func _exit_tree() -> void:
	disconnect_events()


func setup(shedskin: Node, scale_mgr: Object, parts_mgr: Object) -> void:
	_shedskin_system = shedskin
	_scale_slot_mgr = scale_mgr
	_snake_parts_mgr = parts_mgr


func connect_events() -> void:
	if not EventBus.room_entered.is_connected(_on_room_entered):
		EventBus.room_entered.connect(_on_room_entered)
	if not EventBus.run_started.is_connected(_on_run_started):
		EventBus.run_started.connect(_on_run_started)
	if not EventBus.floor_generated.is_connected(_on_floor_generated):
		EventBus.floor_generated.connect(_on_floor_generated)


func disconnect_events() -> void:
	if EventBus.room_entered.is_connected(_on_room_entered):
		EventBus.room_entered.disconnect(_on_room_entered)
	if EventBus.run_started.is_connected(_on_run_started):
		EventBus.run_started.disconnect(_on_run_started)
	if EventBus.floor_generated.is_connected(_on_floor_generated):
		EventBus.floor_generated.disconnect(_on_floor_generated)


## 开店：种子货架；空货架自动决议（FR-014——不发事件、不进 active）
func enter_shop(room_id: String) -> Array:
	var shop_cfg: Dictionary = ConfigManager.get_shop_config()
	if not shop_cfg.get("enabled", false):
		return []
	if _shop_active:
		return get_inventory()

	var items: Array = _generate_inventory(room_id)
	if items.is_empty():
		return []

	_shop_active = true
	_current_room_id = room_id
	_current_inventory = items

	EventBus.shop_entered.emit({
		"room_id": room_id,
		"items": get_inventory(),
	})
	return get_inventory()


func exit_shop() -> void:
	_shop_active = false
	_current_room_id = ""
	_current_inventory.clear()


func purchase(item_id: String) -> bool:
	if not _shop_active or _shedskin_system == null:
		return false

	var item: Dictionary = _find_item(item_id)
	if item.is_empty() or bool(item.get("purchased", false)):
		return false

	var price: int = int(item.get("price", 0))
	if not _shedskin_system.can_afford(price):
		return false

	if not _execute_purchase(item):
		return false

	_shedskin_system.spend(price, item_id)
	item["purchased"] = true
	_refresh_affordability()

	EventBus.shop_purchase.emit({
		"item_id": item_id,
		"category": str(item.get("category", "")),
		"cost": price,
		"currency_remaining": _shedskin_system.get_amount(),
	})
	return true


func get_inventory() -> Array:
	_refresh_affordability()
	return _current_inventory.duplicate(true)


func is_active() -> bool:
	return _shop_active


func get_current_room_id() -> String:
	return _current_room_id


func get_balance() -> int:
	return _shedskin_system.get_amount() if _shedskin_system != null else 0


func cleanup() -> void:
	exit_shop()
	_run_seed = 0
	_floor_index = 1
	disconnect_events()


# ── 货架生成（种子 RNG + shelf_plan，全部 JSON） ─────────────────────

func _generate_inventory(room_id: String) -> Array:
	var shop_cfg: Dictionary = ConfigManager.get_shop_config()
	var max_items: int = int(shop_cfg.get("max_items_per_shop", 5))
	var plan: Dictionary = shop_cfg.get("shelf_plan", {})
	var categories: Dictionary = shop_cfg.get("item_categories", {})

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%s" % [_run_seed, room_id])

	var items: Array = []
	items += _make_scale_items(rng, int(plan.get("scale", 0)), shop_cfg, categories)
	items += _make_slot_items(rng, int(plan.get("slot", 0)), categories)
	items += _make_part_upgrade_items(int(plan.get("head_upgrade", 0)), "head_upgrade", categories)
	items += _make_part_upgrade_items(int(plan.get("tail_upgrade", 0)), "tail_upgrade", categories)

	if items.size() > max_items:
		items = items.slice(0, max_items)
	return items


## 鳞片货：rng 选 tier（不重复）+ rng 从配置池抽可承载目标
func _make_scale_items(rng: RandomNumberGenerator, count: int, shop_cfg: Dictionary, categories: Dictionary) -> Array:
	var items: Array = []
	if _scale_slot_mgr == null or count <= 0:
		return items

	var tier_ids: Array = []
	for cat_id in categories:
		if str(categories[cat_id].get("category", "")) == "scale":
			tier_ids.append(cat_id)
	tier_ids.sort()

	var pool: Array = ConfigManager.get_scale_reward_pool(str(shop_cfg.get("scale_pool", "")))
	for i in range(mini(count, tier_ids.size())):
		var tier_id: String = tier_ids.pop_at(rng.randi_range(0, tier_ids.size() - 1))
		var cat: Dictionary = categories.get(tier_id, {})
		var level: int = maxi(1, int(cat.get("level", 1)))
		var eligible: Array = []
		for option in pool:
			if option is Dictionary and _is_scale_target_eligible(option, level):
				eligible.append(option)
		if eligible.is_empty():
			continue
		var target: Dictionary = eligible[rng.randi_range(0, eligible.size() - 1)]
		items.append({
			"item_id": tier_id,
			"category": "scale",
			"target_id": str(target.get("target_id", "")),
			"target_slot": str(target.get("target_slot", "")),
			"level": level,
			"price": _price_for(int(cat.get("price", 0))),
			"purchased": false,
			"affordable": false,
			"display_name": "%s L%d" % [str(target.get("display_name", target.get("target_id", ""))), level],
			"placeholder_color": str(target.get("placeholder_color", "")),
		})
	return items


## 合格鳞片目标：scale 类型 + 该等级配置存在 + 位置可承载（有空开放槽或可替换）
func _is_scale_target_eligible(option: Dictionary, level: int) -> bool:
	if str(option.get("reward_type", "")) != "scale":
		return false
	var slot: String = str(option.get("target_slot", ""))
	var can_host: bool = _scale_slot_mgr.has_open_slot(slot) \
		or not _scale_slot_mgr.get_scales(slot).is_empty()
	if not can_host:
		return false
	return not ConfigManager.get_snake_scale(str(option.get("target_id", "")), level).is_empty()


## 槽位货：容量按**开放槽位数**判定（草稿 :130 误用已装数）
func _make_slot_items(rng: RandomNumberGenerator, count: int, categories: Dictionary) -> Array:
	var items: Array = []
	if _scale_slot_mgr == null or count <= 0:
		return items

	var open_positions: Array = []
	for position in ["front", "middle", "back"]:
		if _scale_slot_mgr.get_open_slots(position) < _scale_slot_mgr.get_max_slots(position):
			open_positions.append(position)

	for i in range(mini(count, open_positions.size())):
		var position: String = open_positions.pop_at(rng.randi_range(0, open_positions.size() - 1))
		var cat_id: String = "slot_%s" % position
		var cat: Dictionary = categories.get(cat_id, {})
		if cat.is_empty():
			continue
		items.append({
			"item_id": cat_id,
			"category": "slot",
			"target_id": position,
			"target_slot": position,
			"level": 1,
			"price": _price_for(int(cat.get("price", 0))),
			"purchased": false,
			"affordable": false,
			"display_name": str(cat.get("display_name", cat_id)),
			"placeholder_color": "",
		})
	return items


## 蛇头/蛇尾升级货：已装备且下一等级配置存在才上架
func _make_part_upgrade_items(count: int, category: String, categories: Dictionary) -> Array:
	var items: Array = []
	if _snake_parts_mgr == null or count <= 0:
		return items
	var cat: Dictionary = categories.get(category, {})
	if cat.is_empty():
		return items

	var part: RefCounted = null
	if category == "head_upgrade" and _snake_parts_mgr.has_head():
		part = _snake_parts_mgr.get_active_head()
	elif category == "tail_upgrade" and _snake_parts_mgr.has_tail():
		part = _snake_parts_mgr.get_active_tail()
	if part == null:
		return items

	var next_level: int = int(part.level) + 1
	var next_cfg: Dictionary = ConfigManager.get_snake_head(part.part_id, next_level) \
		if category == "head_upgrade" else ConfigManager.get_snake_tail(part.part_id, next_level)
	if next_cfg.is_empty():
		return items

	items.append({
		"item_id": category,
		"category": category,
		"target_id": str(part.part_id),
		"target_slot": "head" if category == "head_upgrade" else "tail",
		"level": next_level,
		"price": _price_for(int(cat.get("price", 0))),
		"purchased": false,
		"affordable": false,
		"display_name": str(cat.get("display_name", category)),
		"placeholder_color": "",
	})
	return items


## FR-003：floor N 物价 = ceil(基准价 × multiplier^(N-1))
func _price_for(base_price: int) -> int:
	var multiplier: float = ConfigManager.get_shop_price_multiplier_per_floor()
	return int(ceil(base_price * pow(multiplier, _floor_index - 1)))


func _refresh_affordability() -> void:
	for item in _current_inventory:
		if item is Dictionary:
			item["affordable"] = not bool(item.get("purchased", false)) \
				and _shedskin_system != null \
				and _shedskin_system.can_afford(int(item.get("price", 0)))


# ── 购买执行 ─────────────────────────────────────────────────────────

func _execute_purchase(item: Dictionary) -> bool:
	match str(item.get("category", "")):
		"scale":
			if _scale_slot_mgr == null:
				return false
			return _equip_with_replacement(str(item.get("target_slot", "")),
				str(item.get("target_id", "")), int(item.get("level", 1)))
		"slot":
			# 真开槽走 shop_purchase → SlotExpansionSystem 事件链（FR-011）；此处只验容量
			if _scale_slot_mgr == null:
				return false
			var position: String = str(item.get("target_slot", ""))
			return _scale_slot_mgr.get_open_slots(position) < _scale_slot_mgr.get_max_slots(position)
		"head_upgrade":
			if _snake_parts_mgr == null or not _snake_parts_mgr.has_head():
				return false
			return _snake_parts_mgr.equip_head(str(item.get("target_id", "")), int(item.get("level", 2)))
		"tail_upgrade":
			if _snake_parts_mgr == null or not _snake_parts_mgr.has_tail():
				return false
			return _snake_parts_mgr.equip_tail(str(item.get("target_id", "")), int(item.get("level", 2)))
	return false


## 满槽替换（与 ScaleRewardSystem 同语义）：无空开放槽时卸下首槽旧鳞再装新鳞
func _equip_with_replacement(slot: String, scale_id: String, level: int) -> bool:
	if not _scale_slot_mgr.has_open_slot(slot):
		if _scale_slot_mgr.get_scales(slot).is_empty():
			return false
		_scale_slot_mgr.unequip_scale(slot, 0)
	return _scale_slot_mgr.equip_scale(slot, scale_id, level)


func _find_item(item_id: String) -> Dictionary:
	for item in _current_inventory:
		if item is Dictionary and str(item.get("item_id", "")) == item_id:
			return item
	return {}


# ── 事件 ─────────────────────────────────────────────────────────────

## 退店通路：进商店房开店；进任何其他房间关店（plan.md「exits via room_entered」）
func _on_room_entered(data: Dictionary) -> void:
	var shop_room_type: String = str(ConfigManager.get_shop_config().get("room_type", "shop"))
	if str(data.get("room_type", "")) == shop_room_type:
		enter_shop(str(data.get("room_id", "")))
	elif _shop_active:
		exit_shop()


func _on_run_started(data: Dictionary) -> void:
	_run_seed = int(data.get("seed", 0))
	_floor_index = int(data.get("floor_index", 1))
	exit_shop()


func _on_floor_generated(data: Dictionary) -> void:
	_floor_index = int(data.get("floor_index", _floor_index))
