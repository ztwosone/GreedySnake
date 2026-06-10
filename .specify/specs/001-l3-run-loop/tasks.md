# Tasks: L3 Run Loop

**Input**: `.specify/specs/001-l3-run-loop/`  
**Prerequisites**: `spec.md`, `plan.md`, `research.md`, `data-model.md`, `quickstart.md`  
**Tests**: TDD required. Tests must fail before implementation.

## Phase 1: Setup and Governance

- [x] T001 Add L3 JSON config skeleton for run, room, reward, and endpoint tuning in `Project/data/json/game_config.json`
- [x] T002 [P] Add failing tests for L3 config loading in `Project/Test/cases/test_l3_run_loop.gd`
- [x] T003 Extend `ConfigManager` accessors for L3 config in `Project/autoloads/config_manager.gd`
- [x] T004 Add L3 EventBus signal declarations in `Project/autoloads/event_bus.gd`

## Phase 2: Foundational Runtime

- [x] T005 [P] Add failing tests for RunState lifecycle in `Project/Test/cases/test_l3_run_loop.gd`
- [x] T006 Create RunProgressionSystem with start, victory, death, and cleanup state in `Project/systems/run/run_progression_system.gd`
- [x] T007 [P] Add failing tests for floor map generation in `Project/Test/cases/test_l3_run_loop.gd`
- [x] T008 Create deterministic FloorMap generator for a short v1 path in `Project/systems/rooms/floor_map_generator.gd`

## Phase 3: User Story 1 - Enter and Complete a Room (Priority: P1)

**Goal**: Player enters a room, understands one intent, clears objective, and room completes.

**Independent Test**: Deterministic combat room completes when required enemies are cleared.

- [x] T009 [US1] Add failing room entry/completion tests in `Project/Test/cases/test_l3_room_flow.gd`
- [x] T010 [US1] Implement RoomFlowSystem entry and completion state in `Project/systems/rooms/room_flow_system.gd`
- [x] T011 [US1] Integrate RoomFlowSystem into game world lifecycle in `Project/scenes/game_world.gd`
- [x] T012 [US1] Add placeholder room intent UI in `Project/ui/room_intent_panel.gd`

## Phase 4: User Story 2 - Choose a Reward (Priority: P1)

**Goal**: Player chooses one Build-oriented reward from a small placeholder UI.

**Independent Test**: Reward choice applies to existing head, tail, scale, or upgrade state.

- [x] T013 [US2] Add failing reward offer/application tests in `Project/Test/cases/test_l3_rewards.gd`
- [x] T014 [US2] Implement RewardFlowSystem offer and selection in `Project/systems/rewards/reward_flow_system.gd`
- [x] T015 [US2] Add placeholder reward choice UI in `Project/ui/reward_choice_panel.gd`
- [x] T016 [US2] Connect reward application to existing Build managers in `Project/systems/rewards/reward_flow_system.gd`

## Phase 5: User Story 3 - Progress Through a Floor (Priority: P2)

**Goal**: Player advances through a short sequence of rooms and reaches endpoint.

**Independent Test**: Fixed floor path reveals/advances rooms in order and clears on restart.

- [x] T017 [US3] Add failing floor progression tests in `Project/Test/cases/test_l3_floor_progression.gd`
- [x] T018 [US3] Implement room availability and floor progress in `Project/systems/run/run_progression_system.gd`
- [x] T019 [US3] Add placeholder floor progress UI in `Project/ui/floor_progress_panel.gd`
- [x] T019F [US3-fix] Harden active-room completion, RoomFlow entry sync, rest/endpoint auto-complete, and available-state UI

## Phase 6: User Story 4 - Finish a Run (Priority: P2)

**Goal**: Player reaches endpoint, wins, dies, restarts, and leaves no L3 residue.

**Independent Test**: Fixed endpoint produces victory; death path still works; restart clears all L3 state.

- [x] T020 [US4] Add failing endpoint/victory/restart tests in `Project/Test/cases/test_l3_run_end.gd`
- [x] T021 [US4] Implement endpoint completion and run_victory flow in `Project/systems/run/run_progression_system.gd`
- [x] T022 [US4] Integrate L3 cleanup with game_world cleanup in `Project/scenes/game_world.gd`
- [x] T023 [US4] Add deterministic visual smoke run test in `Project/Test/cases/test_l3_smoke_run.gd`
- [x] T023A [US4] Add visual acceptance advance control using `room_advance_requested`

## Final Phase: Documentation and Validation

- [x] T024 Update `TechDocs/QuickReference.md` with L3 implementation status
- [x] T025 Update `AgentOps/CurrentState.md` and handoff evidence after L3 v1 acceptance
- [x] T026 Run strict verification via `Tools/run_tests_strict.ps1`

## Dependencies and Execution Order

- Phase 1 blocks all runtime work.
- Phase 2 blocks all user stories.
- US1 and US2 are both P1, but US1 should land before US2 so reward timing has a room completion source.
- US3 depends on US1.
- US4 depends on US1 and US3; smoke run also depends on US2.

## Parallel Opportunities

- T002 and T004 can run in parallel after T001 intent is clear.
- T005 and T007 can run in parallel.
- UI placeholder tasks can run after their corresponding system contracts are stable.

## Implementation Strategy

1. Complete setup and foundations.
2. Deliver US1 as the MVP room loop.
3. Add US2 reward beat using existing Build depth.
4. Add US3 floor progression.
5. Add US4 endpoint and smoke validation.
