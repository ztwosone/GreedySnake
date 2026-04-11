# Implementation Plan: Virtual Player

**Branch**: `000-virtual-player` | **Date**: 2026-04-11 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `.specify/specs/000-virtual-player/spec.md`

## Summary

Build a decoupled virtual player system for automated testing that simulates human gameplay. Five-layer architecture: GamePerception (visible-only snapshot), InputInjector (Godot input pipeline + headless fallback), HumanTiming (reaction delay model), PlayerBrain (pluggable RefCounted strategies), VirtualPlayer (Node orchestrator). All code under Test/virtual_player/, zero game code modifications.

## Technical Context

**Language/Version**: GDScript 4 (Godot 4.6.1)
**Primary Dependencies**: Godot autoloads (EventBus, GridWorld, TickManager, StatusEffectManager, ConfigManager)
**Storage**: N/A (stateless system, no persistence)
**Testing**: Custom lightweight test framework (Test/test_runner.gd, extends RefCounted, func run(t))
**Target Platform**: Windows (headless for CI, windowed for visual testing)
**Project Type**: Test infrastructure module within Godot game project
**Performance Goals**: BFS on 880-cell grid in <1ms per decision
**Constraints**: Must not modify any existing game code; must work in both headless and windowed mode
**Scale/Scope**: 10 new GDScript files, ~30+ new unit tests

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Design-First | PASS | spec.md written before any code |
| II. Event-Driven Architecture | PASS | VirtualPlayer connects to EventBus.tick_pre_process, does not directly call game systems |
| III. Data-Driven Configuration | PASS | HumanTiming params are configurable, brain strategies are pluggable |
| IV. Test-First / TDD | PASS | Each component gets tests before implementation (Red→Green→Refactor) |
| V. GDScript Conventions | PASS | snake_case methods, PascalCase class_name, RefCounted brains |

No constitution violations. Gate passed.

## Project Structure

### Documentation (this feature)

```text
.specify/specs/000-virtual-player/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0: technical decisions
├── data-model.md        # Phase 1: entity/data model
├── tasks.md             # Phase 2: task breakdown (by /speckit-tasks)
└── checklists/
    └── requirements.md  # Spec quality checklist
```

### Source Code

```text
Project/Test/virtual_player/
├── virtual_player.gd          # VirtualPlayer Node orchestrator
├── game_perception.gd         # GamePerception snapshot builder
├── input_injector.gd          # InputInjector direction→InputEvent
├── human_timing.gd            # HumanTiming delay model
└── brains/
    ├── player_brain.gd        # PlayerBrain base class (RefCounted)
    ├── scripted_brain.gd      # ScriptedBrain tick→direction replay
    ├── survival_brain.gd      # SurvivalBrain wall/self avoidance
    ├── food_seeker_brain.gd   # FoodSeekerBrain BFS pathfinding
    └── composite_brain.gd     # CompositeBrain priority stack

Project/Test/cases/
    test_virtual_player.gd     # Unit tests for all components
```

**Structure Decision**: All VirtualPlayer code lives under `Test/virtual_player/` to keep it separate from game code. Tests follow existing pattern in `Test/cases/test_*.gd`.

## Data Model

### GamePerception Snapshot (Dictionary)

```
{
  "snake_head_pos": Vector2i,       # body[0]
  "snake_body": Array[Vector2i],    # full body array
  "snake_direction": Vector2i,      # current facing
  "snake_length": int,              # segments.size()
  "snake_is_alive": bool,
  "segment_statuses": Array[String], # carried_status per segment

  "enemies": Array[Dictionary],     # [{pos, type, shape}]
  "foods": Array[Dictionary],       # [{pos}]
  "status_tiles": Array[Dictionary], # [{pos, type}]

  "grid_width": int,                # Constants.GRID_WIDTH
  "grid_height": int,               # Constants.GRID_HEIGHT
  "current_tick": int,              # TickManager.current_tick
}
```

### Brain Decision (Dictionary)

```
{
  "direction": Vector2i   # UP/DOWN/LEFT/RIGHT or ZERO for no-op
}
```

## Key Technical Decisions

### D1: InputEventAction over InputEventKey

Use `InputEventAction` for input injection. Snake's `_unhandled_input()` checks `event.is_action_pressed("move_up")` which matches InputEventAction directly. Avoids keycode hardcoding, works with key rebinding.

### D2: tick_pre_process hook for deterministic mode

In deterministic mode, VirtualPlayer connects to `EventBus.tick_pre_process`. Signal emission order in `TickManager._on_timer_timeout()`:
1. `tick_pre_process.emit()` ← VirtualPlayer injects here
2. `tick_input_collected.emit()` ← Snake consumes buffer here
3. `tick_post_process.emit()`

This guarantees the injected direction is in the buffer before the snake moves.

### D3: Headless fallback via direct _buffer_direction()

`Input.parse_input_event()` may not propagate to `_unhandled_input()` in headless mode (no viewport focus). InputInjector provides a fallback method that directly calls `snake._buffer_direction(dir)`. The VirtualPlayer detects headless mode and chooses the appropriate path.

### D4: BFS on snapshot data, not GridWorld

FoodSeekerBrain runs BFS on the perception snapshot's data, not by querying GridWorld directly. This enforces the information boundary and ensures the brain only uses visible information.

### D5: Seeded RNG for reproducibility

SurvivalBrain and CompositeBrain use `RandomNumberGenerator` with configurable seed. This allows non-scripted brains to still produce deterministic results when a seed is set.

## Component Interaction Diagram

```
[Game Scene]
    │
    ├── Snake (existing, unmodified)
    │     └── _unhandled_input() ← InputEventAction from InputInjector
    │     └── _on_tick() ← tick_input_collected (consumes buffer)
    │
    └── VirtualPlayer (new Node, added at runtime)
          │
          ├── tick_pre_process signal (deterministic mode)
          │   └── GamePerception.take_snapshot()
          │       └── brain.decide(snapshot)
          │           └── InputInjector.inject_direction(dir)
          │
          └── _process(delta) (human-like mode)
              └── accumulate → decide → delay → inject
```

## Complexity Tracking

No constitution violations. No complexity justifications needed.
