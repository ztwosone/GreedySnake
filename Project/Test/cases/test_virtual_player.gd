extends RefCounted
## Virtual Player 系统测试


func run(t) -> void:
	# === Phase 2: Foundational ===
	_test_player_brain_base(t)
	_test_input_injector(t)
	_test_human_timing(t)
	_test_game_perception(t)
	# === Phase 3: US1 Deterministic Replay ===
	_test_scripted_brain(t)
	_test_virtual_player_deterministic(t)
	# === Phase 5-8: Smart Brains ===
	_test_survival_brain(t)
	_test_food_seeker_brain(t)
	_test_composite_brain(t)


# --- T003: PlayerBrain base ---

func _test_player_brain_base(t) -> void:
	var PlayerBrainScript: GDScript = load("res://Test/virtual_player/brains/player_brain.gd")
	var brain: RefCounted = PlayerBrainScript.new()
	var result: Dictionary = brain.decide({})
	t.assert_eq(result.get("direction", null), Vector2i.ZERO,
		"PlayerBrain.decide() default returns ZERO direction")


# --- T004: InputInjector ---

func _test_input_injector(t) -> void:
	var InjectorScript: GDScript = load("res://Test/virtual_player/input_injector.gd")

	# Test direction-to-action mapping
	t.assert_eq(InjectorScript._dir_to_action(Vector2i(0, -1)), "move_up",
		"InputInjector maps UP correctly")
	t.assert_eq(InjectorScript._dir_to_action(Vector2i(0, 1)), "move_down",
		"InputInjector maps DOWN correctly")
	t.assert_eq(InjectorScript._dir_to_action(Vector2i(-1, 0)), "move_left",
		"InputInjector maps LEFT correctly")
	t.assert_eq(InjectorScript._dir_to_action(Vector2i(1, 0)), "move_right",
		"InputInjector maps RIGHT correctly")
	t.assert_eq(InjectorScript._dir_to_action(Vector2i.ZERO), "",
		"InputInjector maps ZERO to empty string")


# --- T005: HumanTiming ---

func _test_human_timing(t) -> void:
	var TimingScript: GDScript = load("res://Test/virtual_player/human_timing.gd")

	# Deterministic mode
	var timing: RefCounted = TimingScript.new()
	timing.set_deterministic(42)
	t.assert_true(timing.deterministic, "set_deterministic sets flag")
	t.assert_eq(timing.get_reaction_delay_sec(), 0.0,
		"deterministic mode: reaction delay is 0")
	t.assert_eq(timing.get_key_press_duration_sec(), 0.0,
		"deterministic mode: key press duration is 0")

	# Non-deterministic mode
	var timing2: RefCounted = TimingScript.new()
	t.assert_true(not timing2.deterministic, "default is non-deterministic")
	var delay: float = timing2.get_reaction_delay_sec()
	t.assert_true(delay >= 0.0, "non-deterministic: reaction delay >= 0")
	var dur: float = timing2.get_key_press_duration_sec()
	t.assert_true(dur > 0.0, "non-deterministic: key press duration > 0")


# --- T006: GamePerception ---

func _test_game_perception(t) -> void:
	var PerceptionScript: GDScript = load("res://Test/virtual_player/game_perception.gd")

	# Snapshot structure test — requires GridWorld initialized
	GridWorld.init_grid(Constants.GRID_WIDTH, Constants.GRID_HEIGHT)

	# Create a minimal snake for snapshot
	var snake := Snake.new()
	snake.init_snake(Vector2i(5, 5), 3, Vector2i(1, 0))

	var snapshot: Dictionary = PerceptionScript.take_snapshot(snake)

	# Required keys present
	t.assert_true(snapshot.has("snake_head_pos"), "snapshot has snake_head_pos")
	t.assert_true(snapshot.has("snake_body"), "snapshot has snake_body")
	t.assert_true(snapshot.has("snake_direction"), "snapshot has snake_direction")
	t.assert_true(snapshot.has("snake_length"), "snapshot has snake_length")
	t.assert_true(snapshot.has("snake_is_alive"), "snapshot has snake_is_alive")
	t.assert_true(snapshot.has("segment_statuses"), "snapshot has segment_statuses")
	t.assert_true(snapshot.has("enemies"), "snapshot has enemies")
	t.assert_true(snapshot.has("foods"), "snapshot has foods")
	t.assert_true(snapshot.has("status_tiles"), "snapshot has status_tiles")
	t.assert_true(snapshot.has("grid_width"), "snapshot has grid_width")
	t.assert_true(snapshot.has("grid_height"), "snapshot has grid_height")
	t.assert_true(snapshot.has("current_tick"), "snapshot has current_tick")

	# Values correct
	t.assert_eq(snapshot["snake_head_pos"], Vector2i(5, 5), "head pos correct")
	t.assert_eq(snapshot["snake_direction"], Vector2i(1, 0), "direction correct")
	t.assert_eq(snapshot["snake_length"], 3, "length correct")
	t.assert_true(snapshot["snake_is_alive"], "snake alive")
	t.assert_eq(snapshot["grid_width"], Constants.GRID_WIDTH, "grid width correct")
	t.assert_eq(snapshot["grid_height"], Constants.GRID_HEIGHT, "grid height correct")

	# Prohibited keys NOT present (information boundary)
	var prohibited: Array[String] = [
		"move_accumulator", "_move_accumulator",
		"input_buffer", "grow_pending",
		"attack_cooldown", "attack_cooldown_remaining",
		"brain", "enemy_brain",
	]
	for key in prohibited:
		t.assert_true(not snapshot.has(key),
			"snapshot must NOT contain prohibited key: %s" % key)

	# Cleanup
	snake.queue_free()
	GridWorld.init_grid(0, 0)


# --- T012: ScriptedBrain ---

func _test_scripted_brain(t) -> void:
	var ScriptedScript: GDScript = load("res://Test/virtual_player/brains/scripted_brain.gd")
	var brain: RefCounted = ScriptedScript.new()

	# Setup with commands
	brain.setup([
		{"tick": 0, "direction": Vector2i(1, 0)},   # RIGHT at tick 0
		{"tick": 3, "direction": Vector2i(0, -1)},   # UP at tick 3
		{"tick": 7, "direction": Vector2i(-1, 0)},   # LEFT at tick 7
	])

	# Tick 0: should return RIGHT
	var result: Dictionary = brain.decide({"current_tick": 0})
	t.assert_eq(result["direction"], Vector2i(1, 0),
		"ScriptedBrain returns RIGHT at tick 0")

	# Tick 1: no command, should return ZERO
	result = brain.decide({"current_tick": 1})
	t.assert_eq(result["direction"], Vector2i.ZERO,
		"ScriptedBrain returns ZERO between commands (tick 1)")

	# Tick 2: no command
	result = brain.decide({"current_tick": 2})
	t.assert_eq(result["direction"], Vector2i.ZERO,
		"ScriptedBrain returns ZERO between commands (tick 2)")

	# Tick 3: should return UP
	result = brain.decide({"current_tick": 3})
	t.assert_eq(result["direction"], Vector2i(0, -1),
		"ScriptedBrain returns UP at tick 3")

	# Tick 5: no command (between 3 and 7)
	result = brain.decide({"current_tick": 5})
	t.assert_eq(result["direction"], Vector2i.ZERO,
		"ScriptedBrain returns ZERO between commands (tick 5)")

	# Tick 7: should return LEFT
	result = brain.decide({"current_tick": 7})
	t.assert_eq(result["direction"], Vector2i(-1, 0),
		"ScriptedBrain returns LEFT at tick 7")

	# Tick 10: exhausted, should return ZERO
	result = brain.decide({"current_tick": 10})
	t.assert_eq(result["direction"], Vector2i.ZERO,
		"ScriptedBrain returns ZERO when exhausted")


# --- T013: VirtualPlayer deterministic ---

func _test_virtual_player_deterministic(t) -> void:
	var VPScript: GDScript = load("res://Test/virtual_player/virtual_player.gd")
	var ScriptedScript: GDScript = load("res://Test/virtual_player/brains/scripted_brain.gd")

	# Test: VirtualPlayer without brain does nothing (no crash)
	var vp: Node = VPScript.new()
	vp.timing.set_deterministic(0)
	# Calling _decide_and_inject should not crash with null brain
	t.assert_true(vp.brain == null, "VirtualPlayer default brain is null")

	# Test: deterministic flag propagates
	t.assert_true(vp.timing.deterministic, "timing is deterministic")

	# Test: with ScriptedBrain, decide returns correct direction
	var brain: RefCounted = ScriptedScript.new()
	brain.setup([{"tick": 0, "direction": Vector2i(0, -1)}])
	vp.brain = brain

	# Simulate what tick_pre_process would do
	var snapshot: Dictionary = {"current_tick": 0}
	var decision: Dictionary = vp.brain.decide(snapshot)
	t.assert_eq(decision["direction"], Vector2i(0, -1),
		"VirtualPlayer+ScriptedBrain returns UP at tick 0")

	# Test: enabled toggle
	vp.enabled = false
	t.assert_true(not vp.enabled, "VirtualPlayer can be disabled")

	vp.queue_free()


# --- T021: SurvivalBrain ---

func _test_survival_brain(t) -> void:
	var SurvivalScript: GDScript = load("res://Test/virtual_player/brains/survival_brain.gd")
	var brain: RefCounted = SurvivalScript.new()
	brain.set_seed(42)

	# Heading right toward right wall (x=39, grid_width=40)
	var snapshot: Dictionary = {
		"snake_head_pos": Vector2i(39, 10),
		"snake_body": [Vector2i(39, 10), Vector2i(38, 10), Vector2i(37, 10)],
		"snake_direction": Vector2i(1, 0),  # heading RIGHT
		"grid_width": 40,
		"grid_height": 22,
		"current_tick": 0,
	}
	var result: Dictionary = brain.decide(snapshot)
	var dir: Vector2i = result["direction"]
	# Should NOT go RIGHT (wall) or LEFT (reversal)
	t.assert_true(dir != Vector2i(1, 0), "SurvivalBrain avoids wall (not RIGHT)")
	t.assert_true(dir != Vector2i(-1, 0), "SurvivalBrain avoids reversal (not LEFT)")
	t.assert_true(dir == Vector2i(0, -1) or dir == Vector2i(0, 1),
		"SurvivalBrain picks UP or DOWN when facing wall")

	# Body blocks two directions — heading DOWN, body blocks LEFT and RIGHT
	var snapshot2: Dictionary = {
		"snake_head_pos": Vector2i(10, 10),
		"snake_body": [
			Vector2i(10, 10),  # head
			Vector2i(10, 9),   # above (blocks UP = reversal)
			Vector2i(11, 10),  # right (blocks RIGHT)
			Vector2i(9, 10),   # left (blocks LEFT)
		],
		"snake_direction": Vector2i(0, 1),  # heading DOWN
		"grid_width": 40,
		"grid_height": 22,
		"current_tick": 0,
	}
	result = brain.decide(snapshot2)
	dir = result["direction"]
	# Only DOWN is safe (not reversal, and only body-free direction)
	t.assert_eq(dir, Vector2i(0, 1),
		"SurvivalBrain picks only safe direction when body blocks others")

	# All directions blocked (doomed)
	var snapshot3: Dictionary = {
		"snake_head_pos": Vector2i(0, 0),
		"snake_body": [
			Vector2i(0, 0),
			Vector2i(1, 0),  # blocks RIGHT
			Vector2i(0, 1),  # blocks DOWN
		],
		"snake_direction": Vector2i(-1, 0),  # heading LEFT (wall at x=-1)
		"grid_width": 40,
		"grid_height": 22,
		"current_tick": 0,
	}
	result = brain.decide(snapshot3)
	t.assert_eq(result["direction"], Vector2i.ZERO,
		"SurvivalBrain returns ZERO when all directions blocked")


# --- T024: FoodSeekerBrain ---

func _test_food_seeker_brain(t) -> void:
	var FoodScript: GDScript = load("res://Test/virtual_player/brains/food_seeker_brain.gd")
	var brain: RefCounted = FoodScript.new()
	brain.set_seed(42)

	# Food directly to the right, clear path
	var snapshot: Dictionary = {
		"snake_head_pos": Vector2i(5, 5),
		"snake_body": [Vector2i(5, 5), Vector2i(4, 5), Vector2i(3, 5)],
		"snake_direction": Vector2i(1, 0),
		"foods": [{"pos": Vector2i(10, 5)}],
		"grid_width": 40,
		"grid_height": 22,
		"current_tick": 0,
	}
	var result: Dictionary = brain.decide(snapshot)
	t.assert_eq(result["direction"], Vector2i(1, 0),
		"FoodSeekerBrain goes RIGHT toward food at (10,5)")

	# Food above, need to go UP
	var snapshot2: Dictionary = {
		"snake_head_pos": Vector2i(10, 10),
		"snake_body": [Vector2i(10, 10), Vector2i(10, 11), Vector2i(10, 12)],
		"snake_direction": Vector2i(0, -1),
		"foods": [{"pos": Vector2i(10, 3)}],
		"grid_width": 40,
		"grid_height": 22,
		"current_tick": 0,
	}
	result = brain.decide(snapshot2)
	t.assert_eq(result["direction"], Vector2i(0, -1),
		"FoodSeekerBrain goes UP toward food at (10,3)")

	# No food — fallback to survival
	var snapshot3: Dictionary = {
		"snake_head_pos": Vector2i(10, 10),
		"snake_body": [Vector2i(10, 10), Vector2i(9, 10), Vector2i(8, 10)],
		"snake_direction": Vector2i(1, 0),
		"foods": [],
		"grid_width": 40,
		"grid_height": 22,
		"current_tick": 0,
	}
	result = brain.decide(snapshot3)
	t.assert_true(result["direction"] != Vector2i(-1, 0),
		"FoodSeekerBrain fallback: no reversal when no food")


# --- T030: CompositeBrain ---

func _test_composite_brain(t) -> void:
	var CompositeScript: GDScript = load("res://Test/virtual_player/brains/composite_brain.gd")
	var brain: RefCounted = CompositeScript.new()
	brain.set_seed(42)

	# Enemy adjacent — danger avoidance should take priority
	var snapshot_danger: Dictionary = {
		"snake_head_pos": Vector2i(10, 10),
		"snake_body": [Vector2i(10, 10), Vector2i(9, 10), Vector2i(8, 10)],
		"snake_direction": Vector2i(1, 0),
		"enemies": [{"pos": Vector2i(11, 10), "type": "chaser", "shape": "diamond"}],
		"foods": [{"pos": Vector2i(12, 10)}],  # food beyond enemy
		"grid_width": 40,
		"grid_height": 22,
		"current_tick": 0,
	}
	var result: Dictionary = brain.decide(snapshot_danger)
	t.assert_true(result["direction"] != Vector2i(1, 0),
		"CompositeBrain avoids enemy ahead (not RIGHT)")
	t.assert_true(result["direction"] != Vector2i(-1, 0),
		"CompositeBrain avoids reversal")

	# No danger, food available — food seeking
	var snapshot_food: Dictionary = {
		"snake_head_pos": Vector2i(10, 10),
		"snake_body": [Vector2i(10, 10), Vector2i(9, 10), Vector2i(8, 10)],
		"snake_direction": Vector2i(1, 0),
		"enemies": [],
		"foods": [{"pos": Vector2i(15, 10)}],
		"grid_width": 40,
		"grid_height": 22,
		"current_tick": 0,
	}
	result = brain.decide(snapshot_food)
	t.assert_eq(result["direction"], Vector2i(1, 0),
		"CompositeBrain seeks food when no danger")

	# No danger, no food — survival fallback
	var snapshot_empty: Dictionary = {
		"snake_head_pos": Vector2i(10, 10),
		"snake_body": [Vector2i(10, 10), Vector2i(9, 10), Vector2i(8, 10)],
		"snake_direction": Vector2i(1, 0),
		"enemies": [],
		"foods": [],
		"grid_width": 40,
		"grid_height": 22,
		"current_tick": 0,
	}
	result = brain.decide(snapshot_empty)
	t.assert_true(result["direction"] != Vector2i.ZERO,
		"CompositeBrain survival fallback returns a direction")
	t.assert_true(result["direction"] != Vector2i(-1, 0),
		"CompositeBrain survival fallback: no reversal")
