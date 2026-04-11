# Data Model: Virtual Player

## Entities

### VirtualPlayer
- **Type**: Node (scene tree participant)
- **Fields**: brain (PlayerBrain), timing (HumanTiming), enabled (bool)
- **State**: _decision_accumulator (float), _pending_direction (Vector2i), _reaction_timer (float), _has_pending_decision (bool)
- **Relationships**: Owns one PlayerBrain, one HumanTiming. Reads from GamePerception (stateless). Delegates to InputInjector (stateless).

### GamePerception
- **Type**: RefCounted (stateless utility)
- **Output**: Dictionary snapshot (see plan.md for schema)
- **Data Sources**: GridWorld.cell_map, snake.body/segments, TickManager.current_tick, Constants.GRID_WIDTH/HEIGHT
- **Boundary**: NEVER reads internal state (move_accumulator, enemy brain, cooldowns, config internals)

### InputInjector
- **Type**: RefCounted (stateless utility)
- **Input**: Vector2i direction
- **Output**: InputEventAction injected via Input.parse_input_event(), or direct _buffer_direction() fallback
- **State**: None (all static methods)

### HumanTiming
- **Type**: RefCounted (configuration object)
- **Fields**: reaction_time_ms (float, default 200), reaction_variance_ms (float, default 50), decision_interval_ms (float, default 250), key_press_duration_ms (float, default 80), deterministic (bool, default false)
- **State**: _rng (RandomNumberGenerator)
- **Transitions**: set_deterministic(seed) → zeroes all delays, sets RNG seed

### PlayerBrain (base)
- **Type**: RefCounted (abstract)
- **Method**: decide(snapshot: Dictionary) -> Dictionary {direction: Vector2i}
- **Subclasses**: ScriptedBrain, SurvivalBrain, FoodSeekerBrain, CompositeBrain

### ScriptedBrain
- **Fields**: _commands (Array[Dictionary] of {tick: int, direction: Vector2i}), _index (int)
- **Behavior**: Returns direction when current_tick >= next command's tick, advances index

### SurvivalBrain
- **Fields**: _rng (RandomNumberGenerator)
- **Behavior**: Evaluates 3 non-reversal directions, filters safe ones (no wall, no self-body), random pick from safe set

### FoodSeekerBrain
- **Fields**: _rng (RandomNumberGenerator)
- **Behavior**: BFS from head to nearest food avoiding body and walls, returns first step direction. Falls back to SurvivalBrain logic if no path.

### CompositeBrain
- **Fields**: _rng (RandomNumberGenerator)
- **Behavior**: Priority evaluation: (1) danger avoidance if enemy adjacent, (2) food seeking if reachable, (3) survival fallback
