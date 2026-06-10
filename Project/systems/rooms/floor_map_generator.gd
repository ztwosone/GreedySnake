extends RefCounted
## Extends FloorMapGenerator with PCG room generation for L4.
## Supports multi-floor, themes, varied room types, and branching.

func generate_floor(floor_index: int, seed: int) -> Dictionary:
	var floor_cfg: Dictionary = ConfigManager.get_floor_config()
	var fixed_path: Array = floor_cfg.get("fixed_v1_path", [])
	if fixed_path.size() > 0 and floor_index == 1:
		return _generate_fixed_v1(floor_index, seed, fixed_path)
	return _generate_pcg(floor_index, seed)


func _generate_fixed_v1(floor_index: int, seed: int, path: Array) -> Dictionary:
	var rooms: Array = []
	var room_types: Dictionary = ConfigManager.room_types
	for index in range(path.size()):
		var room_id: String = path[index]
		var room_type: String = _room_type_from_id(room_id)
		var room_cfg: Dictionary = room_types.get(room_type, {})
		var prev_id: String = path[index - 1] if index > 0 else ""
		var next_id: String = path[index + 1] if index < path.size() - 1 else ""
		var exits: Array = [next_id] if next_id != "" else []
		rooms.append({
			"room_id": room_id,
			"room_type": room_type,
			"intent_label": room_cfg.get("intent_label", room_id),
			"primary_intent": room_cfg.get("primary_intent", ""),
			"objective": {
				"objective_type": room_cfg.get("objective_type", "clear_enemies"),
				"required_count": int(room_cfg.get("required_count", 3)),
				"current_count": 0,
				"complete": false,
			},
			"exit_room_ids": exits,
			"placeholder_color": room_cfg.get("placeholder_color", "#FFFFFF"),
			"enabled": true,
			"available": index == 0,
			"completed": false,
			"auto_complete_on_enter": bool(room_cfg.get("auto_complete_on_enter", false)),
			"enemy_count": int(room_cfg.get("enemy_count", 3)),
			"theme_id": "",
		})
	return {
		"floor_id": "floor_%d_%d" % [floor_index, seed],
		"floor_index": floor_index,
		"seed": seed,
		"rooms": rooms,
		"start_room_id": path[0] if path.size() > 0 else "",
		"endpoint_room_id": path[path.size() - 1] if path.size() > 0 else "",
		"theme_id": "",
	}


func _generate_pcg(floor_index: int, seed: int) -> Dictionary:
	var theme_ids: Array = ConfigManager.get_floor_theme_ids()
	var theme_id: String = theme_ids[floor_index % theme_ids.size()] if theme_ids.size() > 0 else ""
	var theme: Dictionary = ConfigManager.get_floor_theme(theme_id)

	var room_count: int = 5 + (floor_index - 1) * 2
	room_count = mini(room_count, 10)

	var rooms: Array = []
	var total: int = room_count

	for i in range(total):
		var room_type: String = "combat"
		if i == 0:
			room_type = "combat"
		elif i == total - 1:
			room_type = "endpoint"
		elif i == total / 2:
			room_type = "reward"

		var room_id: String = "%s_%02d_f%d" % [room_type, i, floor_index]
		var room_cfg: Dictionary = ConfigManager.get_room_type(room_type)

		var next_id: String = ""
		if i < total - 1:
			var next_type: String = "combat"
			if i + 1 == total - 1:
				next_type = "endpoint"
			elif i + 1 == total / 2:
				next_type = "reward"
			next_id = "%s_%02d_f%d" % [next_type, i + 1, floor_index]

		var exits: Array = [next_id] if next_id != "" else []

		rooms.append({
			"room_id": room_id,
			"room_type": room_type,
			"intent_label": room_cfg.get("intent_label", room_type),
			"primary_intent": room_cfg.get("primary_intent", ""),
			"objective": {
				"objective_type": room_cfg.get("objective_type", "clear_enemies"),
				"required_count": int(room_cfg.get("required_count", 3)),
				"current_count": 0,
				"complete": false,
			},
			"exit_room_ids": exits,
			"placeholder_color": room_cfg.get("placeholder_color", "#FFFFFF"),
			"enabled": true,
			"available": i == 0,
			"completed": false,
			"auto_complete_on_enter": bool(room_cfg.get("auto_complete_on_enter", false)),
			"enemy_count": int(room_cfg.get("enemy_count", 3)),
			"theme_id": theme_id,
		})

	return {
		"floor_id": "floor_%d_%d" % [floor_index, seed],
		"floor_index": floor_index,
		"seed": seed,
		"rooms": rooms,
		"start_room_id": rooms[0].get("room_id", "") if rooms.size() > 0 else "",
		"endpoint_room_id": rooms[total - 1].get("room_id", "") if rooms.size() > 0 else "",
		"theme_id": theme_id,
	}


func _room_type_from_id(room_id: String) -> String:
	if room_id.begins_with("combat"):
		return "combat"
	if room_id.begins_with("reward"):
		return "reward"
	if room_id.begins_with("rest"):
		return "rest"
	if room_id.begins_with("endpoint"):
		return "endpoint"
	if room_id.begins_with("shop"):
		return "shop"
	return "combat"