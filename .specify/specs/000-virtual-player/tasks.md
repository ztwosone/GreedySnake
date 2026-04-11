# Tasks: Virtual Player

**Input**: Design documents from `.specify/specs/000-virtual-player/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md
**Tests**: TDD required — write failing tests FIRST for each component

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1-US6)

---

## Phase 1: Setup

**Purpose**: Create directory structure and base files

- [ ] T001 Create directory structure: `Project/Test/virtual_player/` and `Project/Test/virtual_player/brains/`
- [ ] T002 Create test file skeleton in `Project/Test/cases/test_virtual_player.gd`

**Checkpoint**: Directory and test skeleton ready

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core components that ALL user stories depend on

- [ ] T003 [P] Tests for PlayerBrain base class — test that default decide() returns ZERO direction — in `Project/Test/cases/test_virtual_player.gd`
- [ ] T004 [P] Tests for InputInjector — test _dir_to_action mapping and inject_direction method — in `Project/Test/cases/test_virtual_player.gd`
- [ ] T005 [P] Tests for HumanTiming — test deterministic mode returns 0 delay, test non-deterministic returns positive values, test set_deterministic — in `Project/Test/cases/test_virtual_player.gd`
- [ ] T006 [P] Tests for GamePerception — test take_snapshot returns correct keys, test snapshot contains visible data, test snapshot does NOT contain internal state keys — in `Project/Test/cases/test_virtual_player.gd`
- [ ] T007 [P] Implement PlayerBrain base class in `Project/Test/virtual_player/brains/player_brain.gd`
- [ ] T008 [P] Implement InputInjector in `Project/Test/virtual_player/input_injector.gd`
- [ ] T009 [P] Implement HumanTiming in `Project/Test/virtual_player/human_timing.gd`
- [ ] T010 Implement GamePerception in `Project/Test/virtual_player/game_perception.gd`
- [ ] T011 Run full test suite — verify foundational tests pass AND existing 1533+ tests unaffected

**Checkpoint**: Foundation ready — all 4 core components implemented and tested

---

## Phase 3: User Story 1 - Deterministic Test Replay (Priority: P1)

**Goal**: ScriptedBrain + VirtualPlayer deterministic orchestration — the MVP for automated testing

**Independent Test**: ScriptedBrain with 5 commands replays exactly; VirtualPlayer in deterministic mode injects input before snake movement

### Tests for US1

- [ ] T012 [P] [US1] Tests for ScriptedBrain — test setup with command array, test decide returns correct direction at matching tick, test decide returns ZERO when no command matches, test exhausted commands return ZERO — in `Project/Test/cases/test_virtual_player.gd`
- [ ] T013 [US1] Tests for VirtualPlayer deterministic mode — test tick_pre_process injection, test enabled/disabled toggle, test brain-less VirtualPlayer does nothing — in `Project/Test/cases/test_virtual_player.gd`

### Implementation for US1

- [ ] T014 [P] [US1] Implement ScriptedBrain in `Project/Test/virtual_player/brains/scripted_brain.gd`
- [ ] T015 [US1] Implement VirtualPlayer orchestrator (deterministic mode only) in `Project/Test/virtual_player/virtual_player.gd`
- [ ] T016 [US1] Integration test: attach VirtualPlayer+ScriptedBrain to game scene, verify snake follows scripted path over 10 ticks — in `Project/Test/cases/test_virtual_player.gd`
- [ ] T017 [US1] Run full test suite — verify all pass

**Checkpoint**: Deterministic replay works end-to-end. MVP complete.

---

## Phase 4: User Story 2 - Visible-Only Game Perception (Priority: P1)

**Goal**: Validate information boundary — snapshot exposes ONLY visible state

**Independent Test**: Snapshot during gameplay has correct entities and zero internal state leaks

### Tests for US2

- [ ] T018 [US2] Tests for information boundary — assert snapshot does NOT contain keys like "move_accumulator", "attack_cooldown", "brain", "grow_pending", "input_buffer" — in `Project/Test/cases/test_virtual_player.gd`

### Implementation for US2

- [ ] T019 [US2] Add boundary validation assertions to GamePerception.take_snapshot() — defensive check that returned dict has no prohibited keys — in `Project/Test/virtual_player/game_perception.gd`
- [ ] T020 [US2] Run full test suite — verify all pass

**Checkpoint**: Information boundary validated with explicit test assertions

---

## Phase 5: User Story 3 - Survival Autopilot (Priority: P2)

**Goal**: SurvivalBrain keeps snake alive by avoiding walls and self-collision

**Independent Test**: Snake survives 100+ ticks in empty grid without wall/self collision death

### Tests for US3

- [ ] T021 [US3] Tests for SurvivalBrain — test avoids wall when heading toward boundary, test avoids self-body, test returns ZERO when all directions blocked, test seeded RNG produces deterministic results — in `Project/Test/cases/test_virtual_player.gd`

### Implementation for US3

- [ ] T022 [US3] Implement SurvivalBrain in `Project/Test/virtual_player/brains/survival_brain.gd`
- [ ] T023 [US3] Run full test suite — verify all pass

**Checkpoint**: SurvivalBrain independently functional

---

## Phase 6: User Story 4 - Food-Seeking Navigation (Priority: P2)

**Goal**: FoodSeekerBrain pathfinds to nearest food via BFS on snapshot data

**Independent Test**: Snake eats 3 food items within 60 ticks

### Tests for US4

- [ ] T024 [US4] Tests for FoodSeekerBrain — test BFS finds shortest path to food, test BFS avoids body cells as obstacles, test fallback to survival when no food exists, test fallback when food is unreachable — in `Project/Test/cases/test_virtual_player.gd`

### Implementation for US4

- [ ] T025 [US4] Implement FoodSeekerBrain with BFS in `Project/Test/virtual_player/brains/food_seeker_brain.gd`
- [ ] T026 [US4] Run full test suite — verify all pass

**Checkpoint**: FoodSeekerBrain independently functional

---

## Phase 7: User Story 5 - Human-Like Timing (Priority: P3)

**Goal**: VirtualPlayer human-like mode with reaction delays and _process-based timing

**Independent Test**: Input injection occurs with observable delay in human-like mode

### Tests for US5

- [ ] T027 [US5] Tests for VirtualPlayer human-like mode — test _process accumulation, test reaction delay applied before injection, test decision interval throttling — in `Project/Test/cases/test_virtual_player.gd`

### Implementation for US5

- [ ] T028 [US5] Extend VirtualPlayer with _process-based human-like mode in `Project/Test/virtual_player/virtual_player.gd`
- [ ] T029 [US5] Run full test suite — verify all pass

**Checkpoint**: Both deterministic and human-like modes working

---

## Phase 8: User Story 6 - Composite Strategy (Priority: P3)

**Goal**: CompositeBrain combines danger avoidance > food seeking > survival in priority stack

**Independent Test**: Snake eats food and survives 50+ ticks with enemies present

### Tests for US6

- [ ] T030 [US6] Tests for CompositeBrain — test enemy adjacent triggers avoidance, test food reachable triggers seeking, test no danger no food triggers survival, test priority ordering (avoidance > seeking > survival) — in `Project/Test/cases/test_virtual_player.gd`

### Implementation for US6

- [ ] T031 [US6] Implement CompositeBrain in `Project/Test/virtual_player/brains/composite_brain.gd`
- [ ] T032 [US6] Integration test: CompositeBrain survives 50+ ticks in standard game — in `Project/Test/cases/test_virtual_player.gd`
- [ ] T033 [US6] Run full test suite — verify all pass

**Checkpoint**: CompositeBrain independently functional

---

## Phase 9: Polish & Cross-Cutting

**Purpose**: Final validation and documentation

- [ ] T034 Run full test suite — final regression check, all 1533+ original tests + ~30 new tests pass
- [ ] T035 Create `Tasks/L2.5/L2.5_Overview.md` milestone document
- [ ] T036 Commit all Virtual Player files with descriptive message

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies
- **Phase 2 (Foundational)**: Depends on Phase 1
- **Phase 3 (US1 Deterministic)**: Depends on Phase 2 — MVP
- **Phase 4 (US2 Boundary)**: Depends on Phase 2 (GamePerception)
- **Phase 5 (US3 Survival)**: Depends on Phase 2 (PlayerBrain base)
- **Phase 6 (US4 Food)**: Depends on Phase 5 (SurvivalBrain for fallback)
- **Phase 7 (US5 Timing)**: Depends on Phase 3 (VirtualPlayer base)
- **Phase 8 (US6 Composite)**: Depends on Phase 5 + Phase 6 (Survival + Food brains)
- **Phase 9 (Polish)**: Depends on all desired phases complete

### Parallel Opportunities

- T003, T004, T005, T006 (foundational tests) can all run in parallel
- T007, T008, T009 (foundational implementations) can all run in parallel
- T012, T014 (ScriptedBrain test + impl) are independent of T018-T019 (boundary tests)
- Phase 3 (US1) and Phase 4 (US2) can run in parallel after Phase 2
- Phase 5 (US3) and Phase 7 (US5) can run in parallel

---

## Implementation Strategy

### MVP First (Phase 1-3)

1. Setup directory → Foundational components → ScriptedBrain + VirtualPlayer deterministic
2. **VALIDATE**: Run scripted replay test, verify snake follows exact path
3. This alone enables deterministic automated testing for all future features

### Incremental Delivery

1. MVP (US1) → automated test replay capability
2. + US2 → validated information boundary
3. + US3 → survival autopilot for longevity tests
4. + US4 → food-seeking for progression tests
5. + US5 → human-like timing for simulation
6. + US6 → composite strategy for acceptance automation

---

## Summary

- **Total tasks**: 36
- **US1 (Deterministic Replay)**: 6 tasks — MVP
- **US2 (Perception Boundary)**: 3 tasks
- **US3 (Survival)**: 3 tasks
- **US4 (Food Seeking)**: 3 tasks
- **US5 (Human Timing)**: 3 tasks
- **US6 (Composite)**: 4 tasks
- **Setup + Foundational + Polish**: 14 tasks
- **New test count target**: ~30+ tests across all components
