# Feature Specification: Virtual Player

**Feature Branch**: `000-virtual-player`  
**Created**: 2026-04-11  
**Status**: Draft  
**Input**: L2.5 infrastructure — decoupled automated input system for testing and human gameplay simulation

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Deterministic Test Replay (Priority: P1)

A test author writes a scripted sequence of directions tied to specific ticks. The virtual player executes these directions exactly at those ticks, allowing fully reproducible test scenarios without manual play.

**Why this priority**: Foundation for all automated testing. Without deterministic replay, no other test scenario can be reliably verified.

**Independent Test**: Create a ScriptedBrain with 5 direction commands, attach VirtualPlayer to a game scene, verify snake body positions match expected path after N ticks.

**Acceptance Scenarios**:

1. **Given** a ScriptedBrain with commands [{tick:0, dir:RIGHT}, {tick:3, dir:UP}], **When** VirtualPlayer runs in deterministic mode, **Then** the snake moves RIGHT for ticks 0-2 and turns UP at tick 3.
2. **Given** deterministic mode is enabled, **When** VirtualPlayer processes a tick, **Then** all timing delays are zero and input is injected before the snake's movement phase.
3. **Given** a ScriptedBrain has exhausted all commands, **When** subsequent ticks fire, **Then** no input is injected and the snake continues its last direction.

---

### User Story 2 - Visible-Only Game Perception (Priority: P1)

The virtual player observes the game world through a perception layer that only exposes information a human player can see on screen: entity positions, visual status indicators (colors), grid boundaries. Internal state (cooldown timers, modifier values, AI decisions) is never exposed.

**Why this priority**: The information boundary is the core design constraint. If perception leaks internals, all brain decisions become unrealistic.

**Independent Test**: Take a snapshot during gameplay, verify it contains snake body/direction/enemies/foods/status tiles, and verify it does NOT contain move_accumulator, attack_cooldown, or brain state.

**Acceptance Scenarios**:

1. **Given** a running game with snake, enemies, food, and status tiles, **When** GamePerception takes a snapshot, **Then** the snapshot contains grid positions of all visible entities with their visual type/shape.
2. **Given** a snake segment has a fire status overlay, **When** a snapshot is taken, **Then** `segment_statuses` includes "fire" for that segment index.
3. **Given** an enemy has an internal attack cooldown of 3 ticks, **When** a snapshot is taken, **Then** the cooldown value is NOT present in the snapshot.

---

### User Story 3 - Survival Autopilot (Priority: P2)

The virtual player can autonomously keep the snake alive by avoiding walls and self-collision. It evaluates available directions from the perception snapshot and picks a safe one.

**Why this priority**: Enables automated longevity tests — verify the snake can survive N ticks without human intervention.

**Independent Test**: Attach SurvivalBrain to VirtualPlayer in a standard game world, run for 100 ticks, verify snake is still alive (or died only from unavoidable enemy contact, not wall/self collision).

**Acceptance Scenarios**:

1. **Given** the snake is heading toward a wall, **When** SurvivalBrain decides, **Then** it returns a direction that avoids the wall.
2. **Given** the snake's body blocks two of three possible directions, **When** SurvivalBrain decides, **Then** it returns the one remaining safe direction.
3. **Given** all three non-reversal directions lead to collision, **When** SurvivalBrain decides, **Then** it returns ZERO (no input, accept fate).

---

### User Story 4 - Food-Seeking Navigation (Priority: P2)

The virtual player can pathfind toward the nearest food item using BFS on the perception snapshot. The pathfinding treats snake body and out-of-bounds cells as obstacles.

**Why this priority**: Enables automated gameplay progression tests — verify the snake can grow by finding food.

**Independent Test**: Place food at a known position, attach FoodSeekerBrain, verify the snake reaches the food within a reasonable number of ticks.

**Acceptance Scenarios**:

1. **Given** food is 5 cells to the right with no obstacles, **When** FoodSeekerBrain decides, **Then** it returns the direction toward the food.
2. **Given** food is behind the snake's body requiring a detour, **When** FoodSeekerBrain decides, **Then** it returns the first step of the shortest detour path.
3. **Given** no food exists on the grid, **When** FoodSeekerBrain decides, **Then** it falls back to survival behavior.

---

### User Story 5 - Human-Like Timing Simulation (Priority: P3)

The virtual player can operate with realistic human timing: ~200ms reaction delay (with variance), decision intervals matching the tick rate, and key press duration modeling.

**Why this priority**: Enables realistic gameplay simulation for visual testing and acceptance scene automation, but not required for deterministic unit tests.

**Independent Test**: Configure HumanTiming with 200ms reaction, run VirtualPlayer, measure that input injection occurs with observable delay (not instant).

**Acceptance Scenarios**:

1. **Given** HumanTiming with reaction_time_ms=200 and variance=50, **When** get_reaction_delay_sec() is called 100 times, **Then** results center around 0.2s with standard deviation ~0.05s.
2. **Given** human-like mode is active, **When** the snake faces a wall, **Then** the direction change may arrive 1 tick late (realistic miss).
3. **Given** deterministic mode, **When** HumanTiming is queried, **Then** all delays return 0.

---

### User Story 6 - Composite Strategy for Acceptance Testing (Priority: P3)

A composite brain combines danger avoidance, food seeking, and survival into a priority-stacked strategy that can autonomously play through game scenarios, suitable for automating L1/L2 acceptance checklists.

**Why this priority**: High-level integration goal. Requires all lower-priority brains to be working first.

**Independent Test**: Attach CompositeBrain to VirtualPlayer in a standard game, verify the snake eats food and survives for 50+ ticks.

**Acceptance Scenarios**:

1. **Given** an enemy is adjacent to the snake, **When** CompositeBrain decides, **Then** danger avoidance takes priority and steers away from the enemy.
2. **Given** no immediate danger and food is reachable, **When** CompositeBrain decides, **Then** food-seeking takes priority.
3. **Given** no danger and no food, **When** CompositeBrain decides, **Then** survival fallback picks a safe direction.

---

### Edge Cases

- What happens when the game is paused (TickManager.is_ticking == false)? VirtualPlayer should not inject input.
- What happens when the snake is dead (is_alive == false)? VirtualPlayer should stop deciding.
- What happens when Input.parse_input_event() does not trigger _unhandled_input() in headless mode? InputInjector falls back to direct snake._buffer_direction() call.
- What happens when multiple VirtualPlayers are attached? Only one should be active at a time (enforced by the caller, not the system itself).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST observe game state ONLY through a perception snapshot that contains exclusively player-visible information (entity positions, visual status indicators, grid boundaries).
- **FR-002**: System MUST inject input through Godot's standard input pipeline (Input.parse_input_event with InputEventAction), falling back to direct snake._buffer_direction() only when the pipeline is unavailable (headless mode).
- **FR-003**: System MUST support deterministic mode where all timing delays are zero and decisions are injected before the snake's movement phase within the same tick.
- **FR-004**: System MUST support human-like timing mode with configurable reaction delay (~200ms default), Gaussian variance, and decision intervals.
- **FR-005**: System MUST provide a pluggable brain interface (PlayerBrain) that accepts a perception snapshot and returns a direction decision.
- **FR-006**: System MUST include a ScriptedBrain that replays pre-defined direction sequences tied to specific tick numbers.
- **FR-007**: System MUST include a SurvivalBrain that avoids wall and self-body collisions.
- **FR-008**: System MUST include a FoodSeekerBrain that uses BFS pathfinding on snapshot data to navigate toward the nearest food.
- **FR-009**: System MUST include a CompositeBrain that stacks danger avoidance > food seeking > survival in priority order.
- **FR-010**: System MUST attach to the scene tree as a Node without modifying any existing game code files.
- **FR-011**: System MUST reside under the Test/ directory, separate from game source code.
- **FR-012**: System MUST support seeded random number generation for reproducible brain decisions in non-scripted modes.

### Key Entities

- **VirtualPlayer**: Orchestrator Node that wires perception, brain, timing, and injection together. Hooks into tick lifecycle or _process depending on mode.
- **GamePerception**: Stateless snapshot builder. Reads autoloads (GridWorld, TickManager) and scene entities to produce a frozen Dictionary of visible state.
- **InputInjector**: Stateless input factory. Converts Vector2i direction to InputEventAction and feeds it into Input.parse_input_event() or fallback.
- **HumanTiming**: Configuration object for reaction delay, variance, and deterministic mode toggle. Uses RandomNumberGenerator with optional seed.
- **PlayerBrain**: Abstract RefCounted base class. Concrete implementations: ScriptedBrain, SurvivalBrain, FoodSeekerBrain, CompositeBrain.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All VirtualPlayer component unit tests pass (target: 30+ new tests covering all brains and modes).
- **SC-002**: Existing 1533+ game tests remain unaffected (zero regressions).
- **SC-003**: ScriptedBrain replays a 10-step direction sequence with 100% accuracy in deterministic mode.
- **SC-004**: SurvivalBrain keeps the snake alive for 100+ ticks in an empty 40x22 grid (no enemies, no food).
- **SC-005**: FoodSeekerBrain guides the snake to eat 3 food items within 60 ticks in a standard game setup.
- **SC-006**: CompositeBrain sustains the snake for 50+ ticks while eating food and avoiding enemies in a standard game.
- **SC-007**: GamePerception snapshot contains zero internal-state fields (verified by test assertion checking for absence of prohibited keys).

## Assumptions

- The VirtualPlayer system is test infrastructure, not shipped with the game.
- Godot's Input.parse_input_event() propagates to _unhandled_input() in non-headless mode. Headless mode may require the fallback path.
- Grid size remains 40x22 with 0.25s tick interval for the foreseeable future.
- Only one VirtualPlayer instance is active per scene (multi-player testing is out of scope).
- Enemy behavior (brain AI) is unchanged — VirtualPlayer only controls the snake.
- BFS on an 880-cell grid is computationally trivial and does not need optimization.
