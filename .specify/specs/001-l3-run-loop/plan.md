# Implementation Plan: L3 Run Loop

**Branch**: `codex/001-l3-run-loop` | **Date**: 2026-05-18 | **Spec**: `.specify/specs/001-l3-run-loop/spec.md`

## Summary

Implement the first complete playable run loop: generated floor rooms, room objectives, reward selection using existing Build systems, floor endpoint, victory/death outcomes, and cleanup-safe restart. Keep gameplay depth through existing systems while keeping each room's cognitive load low.

## Technical Context

**Language/Version**: Godot 4.6.1 + GDScript 4  
**Primary Dependencies**: Existing EventBus, GridWorld, GameManager, ConfigManager, EnemyManager, SnakePartsManager, ScaleSlotManager, VirtualPlayer  
**Storage**: JSON configuration under `Project/data/json/`  
**Testing**: Headless Godot runner plus strict output scan  
**Target Platform**: Desktop Godot project  
**Project Type**: Single Godot game project  
**Performance Goals**: L3 room generation and transitions complete instantly at current 40x22 grid scale  
**Constraints**: Event-driven systems only; JSON-driven numeric values; functional placeholder UI allowed  
**Scale/Scope**: One floor v1 with a short room sequence and one endpoint

## Constitution Check

- **Design-first**: L3 spec/plan/tasks are created before code tasks. Any divergence updates design first.
- **Event-driven architecture**: Run, room, reward, and endpoint transitions must emit/listen through EventBus.
- **Data-driven configuration**: Room counts, room types, reward counts, endpoint rules, and tuning values live in JSON.
- **TDD**: Each task writes failing tests before implementation.
- **GDScript conventions**: snake_case files/functions, PascalCase classes, typed GDScript 4 syntax.

## Project Structure

```text
.specify/specs/001-l3-run-loop/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── tasks.md
└── checklists/

Project/
├── data/json/game_config.json
├── autoloads/event_bus.gd
├── scenes/game_world.gd
├── systems/
│   ├── run/
│   ├── rooms/
│   └── rewards/
├── ui/
└── Test/cases/
```

**Structure Decision**: Add L3 gameplay systems under `Project/systems/run`, `Project/systems/rooms`, and `Project/systems/rewards`, with JSON config extending the existing `game_config.json` unless the config becomes too large.

## Architecture Plan

- **RunProgressionSystem** owns run/floor state, accepts completion only for the active room, and emits high-level run events.
- **RoomFlowSystem** owns current room lifecycle, listens to room entry events so objective state follows floor progression, and emits objective progress/completion.
- **RewardFlowSystem** presents and applies Build-oriented reward choices from configured reward room sources.
- **Rest and endpoint v1 rooms** may auto-complete on entry through JSON `auto_complete_on_enter`; this keeps the fixed path playable without adding a second resource or shop concept.
- **Placeholder UI** displays current room intent, completed/current/available room states, and reward choices through simple labels/color blocks.
- **Floor progression UI** may request the next available room through EventBus `room_advance_requested`; RunProgression remains the only owner of room availability.
- **VirtualPlayer smoke tests** validate deterministic run progression after core stories are implemented.

## Public Interfaces and Events

New EventBus signals should be added only when used by at least one system or test:

- `run_started(data: Dictionary)`
- `floor_generated(data: Dictionary)`
- `room_entered(data: Dictionary)`
- `room_advance_requested(data: Dictionary)`
- `room_objective_progressed(data: Dictionary)`
- `room_completed(data: Dictionary)`
- `reward_presented(data: Dictionary)`
- `reward_chosen(data: Dictionary)`
- `floor_completed(data: Dictionary)`
- `run_victory(data: Dictionary)`

## Design Gates

- Each room type has one primary intent.
- Reward choices are capped at three visible options.
- Reward presentation sources are data-driven; L3 v1 starts with reward room entry as the reward source.
- Any new room rule must combine with existing status, enemy, Build, or room systems.
- Placeholder visuals must communicate state without final art.
- Any complex L3 rule must be configurable or disableable.
