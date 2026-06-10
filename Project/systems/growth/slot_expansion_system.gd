class_name SlotExpansionSystem
extends Node
## 槽位扩展系统（spec 002 T012 重写，2026-06-11 修订版 spec）
## 判决：重写为 ScaleSlotManager.open_slot() 的**薄适配器**——草稿自持 front/middle/back
## 计数、从不调 open_slot（买槽零效果）。本系统不再持有槽位状态，唯一事实源是
## ScaleSlotManager（get_open_slots/get_max_slots，JSON growth.slot_expansion）。
## 职责：unlock_slot 经 open_slot 真开槽 + 发 slot_unlocked；监听 shop_purchase
## （category=slot）走同一通路（FR-011 EventBus-only）；记录解锁史。
## Boss 固定槽位解锁步骤（FR-007，T025 FloorRewardSystem）后续经 unlock_slot(position,
## "boss") 接入——草稿监听 floor_reward_chosen(category=expansion) 属旧模型，已拆除。

var _scale_slot_mgr: Object = null
var _unlock_history: Array = []


func _ready() -> void:
	connect_events()


func _exit_tree() -> void:
	disconnect_events()


func setup(scale_mgr: Object) -> void:
	_scale_slot_mgr = scale_mgr


func connect_events() -> void:
	if not EventBus.shop_purchase.is_connected(_on_shop_purchase):
		EventBus.shop_purchase.connect(_on_shop_purchase)


func disconnect_events() -> void:
	if EventBus.shop_purchase.is_connected(_on_shop_purchase):
		EventBus.shop_purchase.disconnect(_on_shop_purchase)


## 适配器只读视图：开放槽位数 = ScaleSlotManager 事实
func get_slot_count(position: String) -> int:
	if _scale_slot_mgr == null:
		return 0
	return _scale_slot_mgr.get_open_slots(position)


func get_total_slots() -> int:
	var total: int = 0
	for position in ["front", "middle", "back"]:
		total += get_slot_count(position)
	return total


func can_unlock(position: String) -> bool:
	if _scale_slot_mgr == null:
		return false
	return _scale_slot_mgr.get_open_slots(position) < _scale_slot_mgr.get_max_slots(position)


## 解锁 = 真调 open_slot（草稿回归：买槽零效果）；成功才记史/发事件
func unlock_slot(position: String, source: String = "boss") -> bool:
	if _scale_slot_mgr == null or not _scale_slot_mgr.open_slot(position):
		return false

	_unlock_history.append({
		"position": position,
		"source": source,
		"total_slots": get_total_slots(),
	})

	EventBus.slot_unlocked.emit({
		"position": position,
		"total_slots": get_total_slots(),
		"source": source,
	})
	return true


func get_unlock_history() -> Array:
	return _unlock_history.duplicate()


## 只清适配器自身状态（解锁史）；槽位事实归 ScaleSlotManager（init_manager 重建）
func reset() -> void:
	_unlock_history.clear()


func cleanup() -> void:
	reset()
	disconnect_events()


func _on_shop_purchase(data: Dictionary) -> void:
	if data.get("category", "") != "slot":
		return
	var position: String = _slot_position_from_id(str(data.get("item_id", "")))
	if position != "":
		unlock_slot(position, "shop")


func _slot_position_from_id(item_id: String) -> String:
	if item_id.find("front") >= 0:
		return "front"
	if item_id.find("middle") >= 0:
		return "middle"
	if item_id.find("back") >= 0:
		return "back"
	return ""
