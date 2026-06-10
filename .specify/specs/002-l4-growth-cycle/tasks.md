# Tasks: L4 Growth Cycle

**Input**: `.specify/specs/002-l4-growth-cycle/`
**Prerequisites**: `spec.md`, `plan.md`, `research.md`, `data-model.md`, `quickstart.md`
**Tests**: TDD required. Tests must fail before implementation.

## Phase 1: Setup and Governance

- [ ] T001 Add L4 JSON config skeleton (growth, shop, difficulty, floor_themes, room_modifiers) in `Project/data/json/game_config.json`
- [ ] T002 [P] Add failing tests for L4 config loading in `Project/Test/cases/test_l4_scale_rewards.gd`
- [ ] T003 Extend `ConfigManager` accessors for L4 config in `Project/autoloads/config_manager.gd`
- [ ] T004 [P] Add L4 EventBus signal declarations in `Project/autoloads/event_bus.gd`

## Phase 2: Foundational — Shedskin Currency

- [ ] T005 [P] Add failing tests for shedskin currency lifecycle in `Project/Test/cases/test_l4_shedskin.gd`
- [ ] T006 Create ShedskinSystem with earn/spend/reset/per-floor in `Project/systems/growth/shedskin_system.gd`
- [ ] T007 Integrate ShedskinSystem into game_world lifecycle in `Project/scenes/game_world.gd`
- [ ] T008 [P] Add shedskin currency HUD element in `Project/ui/shedskin_display.gd`

## Phase 3: User Story 1 — Gain Scales After Combat (Priority: P1)

**Goal**: Player sees 3 scale choices after combat room completion and equips one.

**Independent Test**: Complete a combat room, verify 3 scale options appear, choose one, verify it equips to correct slot.

- [ ] T009 [US1] Add failing scale reward tests in `Project/Test/cases/test_l4_scale_rewards.gd`
- [ ] T010 [US1] Create ScaleRewardSystem with pool-based 3-choose-1 offers in `Project/systems/growth/scale_reward_system.gd`
- [ ] T011 [US1] Wire ScaleRewardSystem to combat room completion events in `Project/systems/growth/scale_reward_system.gd`
- [ ] T012 [US1] Create scale choice placeholder UI panel in `Project/ui/scale_choice_panel.gd`
- [ ] T013 [US1] Integrate scale choice panel into game_world and wire to ScaleSlotManager in `Project/scenes/game_world.gd`

## Phase 4: User Story 2 — Shedskin Economy and Shop (Priority: P1)

**Goal**: Shedskin accumulates from kills/choices/exploration; spent in shop rooms on scales, slots, or upgrades.

**Independent Test**: Kill enemies → currency increases. Enter shop → see items with prices → purchase → currency deducted and item applied.

- [ ] T014 [US2] Add failing shop and currency tests in `Project/Test/cases/test_l4_shop.gd`
- [ ] T015 [US2] Create ShopSystem with item generation from JSON config in `Project/systems/growth/shop_system.gd`
- [ ] T016 [US2] Wire shedskin earn sources (kill_normal, kill_elite, scale_discard) to ShedskinSystem in `Project/systems/growth/shedskin_system.gd`
- [ ] T017 [US2] Create shop placeholder UI panel in `Project/ui/shop_panel.gd`
- [ ] T018 [US2] Integrate shop into game_world and wire enter/exit flow in `Project/scenes/game_world.gd`

## Phase 5: User Story 3 — Expand Scale Slots (Priority: P2)

**Goal**: Player unlocks additional scale slots through progression and shop purchases, growing from 3 to max 7.

**Independent Test**: Unlock a slot → verify slot count increases → equip scale to new slot → verify resonance activates.

- [ ] T019 [US3] Add failing slot expansion tests in `Project/Test/cases/test_l4_slots.gd`
- [ ] T020 [US3] Create SlotExpansionSystem tracking slot counts and unlock events in `Project/systems/growth/slot_expansion_system.gd`
- [ ] T021 [US3] Wire SlotExpansionSystem to ScaleSlotManager for dynamic slot count in `Project/systems/growth/slot_expansion_system.gd`
- [ ] T022 [US3] Add slot unlock as shop item category in `Project/systems/growth/shop_system.gd`

## Phase 6: User Story 4 — Multi-Floor PCG Room Generation (Priority: P2)

**Goal**: Floors are procedurally generated with varied room types, themes, and graph structures instead of the v1 fixed path.

**Independent Test**: Generate 3 floors → each has a non-trivial room graph with different themes → verify boss endpoint per floor.

- [ ] T023 [US4] Add failing PCG floor generation tests in `Project/Test/cases/test_l4_pcg_rooms.gd`
- [ ] T024 [US4] Extend FloorMapGenerator with PCG: room graph, themes, terrain templates in `Project/systems/rooms/floor_map_generator.gd`
- [ ] T025 [US4] Add floor theme config and theme-driven enemy pools in `Project/data/json/game_config.json`
- [ ] T026 [US4] Wire multi-floor progression into RunProgressionSystem in `Project/systems/run/run_progression_system.gd`

## Phase 7: User Story 5 — Floor Rewards at Boss Completion (Priority: P2)

**Goal**: Boss defeat triggers a 3-choose-1 floor reward from Expansion, Reinforcement, and Correction categories.

**Independent Test**: Spawn and kill a boss → verify 3 floor reward options (one per category) → choose one → verify effect applied.

- [ ] T027 [US5] Add failing floor reward tests in `Project/Test/cases/test_l4_floor_rewards.gd`
- [ ] T028 [US5] Create FloorRewardSystem with 3-category offer generation in `Project/systems/growth/floor_reward_system.gd`
- [ ] T029 [US5] Implement floor reward category effects (expansion/reinforcement/correction) in `Project/systems/growth/floor_reward_system.gd`
- [ ] T030 [US5] Create floor reward placeholder UI panel in `Project/ui/floor_reward_panel.gd`
- [ ] T031 [US5] Wire FloorRewardSystem to boss room completion events in `Project/systems/growth/floor_reward_system.gd`

## Phase 8: User Story 6 — Dynamic Difficulty and Room Modifiers (Priority: P3)

**Goal**: Game adjusts difficulty based on player performance; room modifiers add environmental variety.

**Independent Test**: Simulate overperformance → verify enemy count increases. Generate a room with modifier → verify modifier effect is visible and functional.

- [ ] T032 [US6] Add failing difficulty and modifier tests in `Project/Test/cases/test_l4_difficulty.gd`
- [ ] T033 [US6] Create DifficultyScaler with performance-tracking metrics in `Project/systems/difficulty/difficulty_scaler.gd`
- [ ] T034 [US6] Create RoomModifierSystem with apply/remove atom chains in `Project/systems/difficulty/room_modifier_system.gd`
- [ ] T035 [US6] Add room modifier config (darkness, speed_strips) to `Project/data/json/game_config.json`
- [ ] T036 [US6] Integrate DifficultyScaler and ModifierSystem into game_world in `Project/scenes/game_world.gd`

## Final Phase: Documentation and Validation

- [ ] T037 Create comprehensive L4 acceptance test in `Project/Test/cases/test_l4_acceptance.gd`
- [ ] T038 Update `TechDocs/QuickReference.md` with L4 implementation status
- [ ] T039 Update `AgentOps/CurrentState.md` and handoff state
- [ ] T040 Run strict verification via `Tools/run_tests_strict.ps1`

## Dependencies and Execution Order

- Phase 1 blocks all runtime work.
- Phase 2 (ShedskinSystem) blocks US1, US2, US3, US5.
- US1 and US2 are both P1 and can proceed in parallel after Phase 2.
- US3 depends on ShedskinSystem and ShopSystem (US2 for shop slot purchase).
- US4 (PCG) is foundational for multi-floor but can be built independently; unlocks US5.
- US5 depends on US1 (scale system), US2 (shedskin), and US4 (boss rooms).
- US6 is independent, only needs Phase 1 config and game_world integration.

## Parallel Opportunities

- T002 and T004 can run in parallel after T001.
- T005 and T008 can run in parallel after Phase 1.
- T009 (US1 tests) and T014 (US2 tests) can run in parallel after Phase 2.
- T023 (US4 tests) and T032 (US6 tests) can run in parallel after Phase 1.
- UI placeholder tasks (T008, T012, T017, T030) can run after their system contracts are stable.

## Implementation Strategy

1. Complete setup and shedskin foundation (Phases 1-2).
2. Deliver US1 (scale rewards) as MVP — player gets meaningful Build growth.
3. Add US2 (shop) — economy and choice deepen the growth loop.
4. Add US3 (slots) — long-term growth through slot expansion.
5. Add US4 (PCG) + US5 (floor rewards) — a complete multiple-floor run.
6. Add US6 (difficulty + modifiers) — replayability and balance.
7. Validate with full acceptance test and strict scan.