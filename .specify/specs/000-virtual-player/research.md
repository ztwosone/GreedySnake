# Research: Virtual Player

## R1: Input Injection in Headless Mode

**Decision**: Dual-path injection — prefer Input.parse_input_event(), fallback to snake._buffer_direction()
**Rationale**: Godot's headless mode may not process _unhandled_input() without a focused viewport. The fallback ensures tests work in all environments.
**Alternatives considered**: (a) Only InputEventAction — rejected because headless CI would break. (b) Only _buffer_direction() — rejected because it bypasses the real input pipeline, losing coverage of the input path.

## R2: Brain Architecture Pattern

**Decision**: RefCounted base class with decide(snapshot) -> Dictionary interface, matching existing EnemyBrain pattern
**Rationale**: The project already uses RefCounted strategy objects for EnemyBrain (WandererBrain, ChaserBrain, BogCrawlerBrain). Following the same pattern maintains codebase consistency.
**Alternatives considered**: (a) Node-based brains — rejected because brains are pure logic with no scene tree needs. (b) Callable/lambda — rejected because it loses type safety and IDE support.

## R3: Perception Snapshot Format

**Decision**: Frozen Dictionary returned by static method, not live object references
**Rationale**: Prevents brains from accidentally modifying game state. Enforces information boundary by construction. Cheap to create on a small grid (880 cells).
**Alternatives considered**: (a) Live reference wrapper with getters — rejected because it's harder to enforce the boundary and risks stale references. (b) Custom Resource — rejected as overkill for a transient data structure.

## R4: BFS Implementation Location

**Decision**: FoodSeekerBrain implements its own BFS on snapshot data
**Rationale**: The existing Pathfinding helper (core/helpers/pathfinding.gd) queries GridWorld directly, violating the information boundary. A self-contained BFS on snapshot data is simple (≤30 lines) and correct by construction.
**Alternatives considered**: Wrapping Pathfinding helper with snapshot adapter — rejected because it adds complexity for no benefit on an 880-cell grid.

## R5: Tick Alignment for Deterministic Mode

**Decision**: Connect to tick_pre_process signal, inject before tick_input_collected
**Rationale**: TickManager emits signals in order: pre_process → input_collected → post_process. Snake consumes input_buffer during input_collected. Injecting during pre_process guarantees the buffer is populated in time.
**Alternatives considered**: (a) Inject during _process() even in deterministic mode — rejected because frame timing is unreliable relative to tick boundaries. (b) Inject during tick_input_collected before snake's handler — rejected because signal handler ordering is not guaranteed in Godot.
