extends RefCounted

const PICKUP_PATH: String = "res://systems/events/pickup_system.gd"


func run(t) -> void:
	_test_pickup_drop_and_activation(t)


func _test_pickup_drop_and_activation(t) -> void:
	t.assert_file_exists(PICKUP_PATH)
	if not FileAccess.file_exists(PICKUP_PATH):
		return

	var system: Node = load(PICKUP_PATH).new()
	t.add_child(system)

	# drop_chance < 1.0 是概率行为：重试至掉落（200 次全空概率 ~2^-200），消除单次掷骰的随机失败
	var pickup_id: String = ""
	for _attempt in range(200):
		pickup_id = system.try_drop_pickup("elite", Vector2i(10, 10))
		if pickup_id != "":
			break
	t.assert_true(pickup_id != "", "[L5-US3] elite drops a pickup within 200 attempts")

	t.assert_true(system.has_pickup(pickup_id), "[L5-US3] pickup tracked")
	t.assert_true(system.activate_pickup(pickup_id), "[L5-US3] pickup activated")
	t.assert_false(system.activate_pickup(pickup_id), "[L5-US3] already activated, returns false")

	var non_elite: String = system.try_drop_pickup("wanderer", Vector2i.ZERO)
	t.assert_eq(non_elite, "", "[L5-US3] non-elite does not drop pickup")

	EventBus.floor_completed.emit({"floor_index": 1})
	t.assert_eq(system.get_active_pickups().size(), 0, "[L5-US3] pickups cleared on floor transition")

	system.cleanup()
	system.queue_free()