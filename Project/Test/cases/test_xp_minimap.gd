extends RefCounted
## Phase P T104a: 楼层小地图契约（presentation_design.md §8.2）
## 左上角；房间 = 意图色小方块沿路径连线；当前 = 外框高亮（脉动属 game_feel）；
## 完成 = 暗化 + 中心点；未达 = 深灰。纯监听（FR-002）：floor_generated 重建、
## room_entered 跟当前、room_completed 记完成；数据驱动 _draw 零编排。

const MINIMAP_PATH: String = "res://ui/floor_minimap.gd"


func run(t) -> void:
	t.assert_file_exists(MINIMAP_PATH)
	var script = load(MINIMAP_PATH)
	if script == null:
		return
	var minimap: Control = script.new()
	t.add_child(minimap)

	# 出生即带验收钩子（kit 基座）：ui_kit 组 + hud 层
	t.assert_true(minimap.is_in_group("ui_kit"), "[P104a] minimap in ui_kit group")
	t.assert_eq(str(minimap.get_meta("ui_layer", "")), "hud", "[P104a] minimap on hud layer")
	t.assert_false(minimap.visible, "[P104a] hidden before any floor exists (渐进披露)")

	# floor_generated 重建
	EventBus.floor_generated.emit({
		"floor_id": "floor_1",
		"rooms": [
			_room("combat_01", "combat", ["reward_01"]),
			_room("reward_01", "reward", ["endpoint_01"]),
			_room("endpoint_01", "endpoint", []),
		],
		"start_room_id": "combat_01",
		"endpoint_room_id": "endpoint_01",
	})
	t.assert_true(minimap.visible, "[P104a] visible after floor_generated")
	t.assert_eq(minimap.get_room_count(), 3, "[P104a] one square per room")
	t.assert_eq(minimap.get_current_room_id(), "", "[P104a] no current room before entry")

	# room_entered 跟当前；room_completed 记完成
	EventBus.room_entered.emit({"room_id": "combat_01", "room_type": "combat",
		"intent_label": "战斗"})
	t.assert_eq(minimap.get_current_room_id(), "combat_01", "[P104a] current follows entry")
	EventBus.room_completed.emit({"room_id": "combat_01", "room_type": "combat"})
	t.assert_true(minimap.is_room_completed("combat_01"), "[P104a] completion recorded")
	t.assert_false(minimap.is_room_completed("reward_01"), "[P104a] others untouched")
	EventBus.room_entered.emit({"room_id": "reward_01", "room_type": "reward",
		"intent_label": "奖励"})
	t.assert_eq(minimap.get_current_room_id(), "reward_01", "[P104a] current moves on")

	# 下一层重建：旧状态清空
	EventBus.floor_generated.emit({
		"floor_id": "floor_2",
		"rooms": [_room("combat_01", "combat", [])],
		"start_room_id": "combat_01",
		"endpoint_room_id": "combat_01",
	})
	t.assert_eq(minimap.get_room_count(), 1, "[P104a] floor change rebuilds map")
	t.assert_false(minimap.is_room_completed("combat_01"),
		"[P104a] completion reset across floors (room ids are floor-scoped)")

	minimap.queue_free()


func _room(id: String, type: String, exits: Array) -> Dictionary:
	return {
		"room_id": id, "room_type": type, "exit_room_ids": exits,
		"intent_label": id, "placeholder_color": "#888888",
		"available": true, "completed": false,
	}
