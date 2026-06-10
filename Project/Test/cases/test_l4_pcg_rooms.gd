extends RefCounted
## L4 Phase 6: PCG floor generation tests (T023).

const FLOOR_MAP_PATH: String = "res://systems/rooms/floor_map_generator.gd"


func run(t) -> void:
	_test_pcg_multi_floor(t)
	_test_pcg_theme_assignment(t)
	_test_pcg_graph_structure(t)


func _test_pcg_multi_floor(t) -> void:
	t.assert_file_exists(FLOOR_MAP_PATH)
	if not FileAccess.file_exists(FLOOR_MAP_PATH):
		return

	var gen = load(FLOOR_MAP_PATH).new()

	for floor_index in range(1, 4):
		var floor_map: Dictionary = gen.generate_floor(floor_index, 2000 + floor_index)
		var rooms: Array = floor_map.get("rooms", [])
		t.assert_true(rooms.size() >= 5, "[L4-US4] floor %d has ≥5 rooms" % floor_index)
		t.assert_eq(floor_map.get("floor_index", 0), floor_index, "[L4-US4] floor %d index correct" % floor_index)
		t.assert_true(len(floor_map.get("start_room_id", "")) > 0, "[L4-US4] floor %d has start room" % floor_index)
		t.assert_true(len(floor_map.get("endpoint_room_id", "")) > 0, "[L4-US4] floor %d has endpoint" % floor_index)

		var first_room: Dictionary = rooms[0]
		t.assert_eq(first_room.get("room_type", ""), "combat", "[L4-US4] first room is combat")
		var last_room: Dictionary = rooms[rooms.size() - 1]
		t.assert_eq(last_room.get("room_type", ""), "endpoint", "[L4-US4] last room is endpoint")


func _test_pcg_theme_assignment(t) -> void:
	t.assert_file_exists(FLOOR_MAP_PATH)
	if not FileAccess.file_exists(FLOOR_MAP_PATH):
		return

	var gen = load(FLOOR_MAP_PATH).new()

	for floor_index in range(2, 5):
		var floor_map: Dictionary = gen.generate_floor(floor_index, 3000 + floor_index)
		var theme_id: String = floor_map.get("theme_id", "")
		t.assert_true(len(theme_id) > 0, "[L4-US4] floor %d has theme" % floor_index)


func _test_pcg_graph_structure(t) -> void:
	t.assert_file_exists(FLOOR_MAP_PATH)
	if not FileAccess.file_exists(FLOOR_MAP_PATH):
		return

	var gen = load(FLOOR_MAP_PATH).new()

	for seed in range(4001, 4004):
		var floor_map: Dictionary = gen.generate_floor(2, seed)
		var rooms: Array = floor_map.get("rooms", [])

		var combat_count: int = 0
		var endpoint_count: int = 0
		for room in rooms:
			if not (room is Dictionary):
				continue
			var rt: String = room.get("room_type", "")
			if rt == "combat":
				combat_count += 1
			elif rt == "endpoint":
				endpoint_count += 1
			t.assert_true(room.has("intent_label"), "[L4-US4] room has intent_label")
			t.assert_true(room.has("objective"), "[L4-US4] room has objective")

		t.assert_true(combat_count >= 2, "[L4-US4] at least 2 combat rooms")
		t.assert_eq(endpoint_count, 1, "[L4-US4] exactly 1 endpoint")

		for i in range(rooms.size() - 1):
			if rooms[i] is Dictionary:
				var exits: Array = rooms[i].get("exit_room_ids", [])
				t.assert_true(exits.size() > 0, "[L4-US4] non-endpoint room has exit")