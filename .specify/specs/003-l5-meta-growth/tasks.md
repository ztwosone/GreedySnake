# Tasks: L5 Meta Growth & Events

**Input**: `.specify/specs/003-l5-meta-growth/`
**Prerequisites**: `spec.md`, `plan.md`
**Tests**: TDD required.

## Phase 1: Setup and Governance

- [ ] T001 Add L5 JSON config skeleton (unlock_conditions, pickups, legacy_stone_templates) in `Project/data/json/game_config.json`
- [ ] T002 [P] Add L5 EventBus signal declarations in `Project/autoloads/event_bus.gd`
- [ ] T003 Extend `ConfigManager` accessors for L5 in `Project/autoloads/config_manager.gd`

## Phase 2: Foundational — Meta Save + Run Stats

- [ ] T004 Create MetaSaveSystem (load/save to user://) in `Project/systems/meta_growth/meta_save_system.gd`
- [ ] T005 [P] Create RunStatsTracker (per-run event accumulation) in `Project/systems/meta_growth/run_stats_tracker.gd`
- [ ] T006 [P] Add failing tests for meta save and run stats in `Project/Test/cases/test_l5_meta_save.gd`

## Phase 3: User Story 1 — Content Unlocks (Priority: P1)

- [ ] T007 [US1] Add failing unlock tests in `Project/Test/cases/test_l5_unlocks.gd`
- [ ] T008 [US1] Create UnlockSystem with condition checking in `Project/systems/meta_growth/unlock_system.gd`
- [ ] T009 [US1] Wire UnlockSystem to run_ended event in `Project/systems/meta_growth/unlock_system.gd`

## Phase 4: User Story 2 — Legacy Stones (Priority: P1)

- [ ] T010 [US2] Add failing legacy stone tests in `Project/Test/cases/test_l5_legacy.gd`
- [ ] T011 [US2] Create LegacyStoneSystem with highlight evaluation in `Project/systems/meta_growth/legacy_stone_system.gd`
- [ ] T012 [US2] Wire legacy stone selection to run start pool biasing in `Project/systems/meta_growth/legacy_stone_system.gd`

## Phase 5: User Story 3 — Pickup Fragments (Priority: P2)

- [ ] T013 [US3] Add failing pickup tests in `Project/Test/cases/test_l5_pickups.gd`
- [ ] T014 [US3] Create PickupSystem with drop and activation in `Project/systems/events/pickup_system.gd`
- [ ] T015 [US3] Create pickup display HUD in `Project/ui/pickup_display.gd`

## Final Phase: Documentation and Validation

- [ ] T016 Create L5 acceptance test in `Project/Test/cases/test_l5_acceptance.gd`
- [ ] T017 Run strict verification via `Tools/run_tests_strict.ps1`