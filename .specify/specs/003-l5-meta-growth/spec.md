# Feature Specification: L5 Meta Growth & Events

**Feature Branch**: `codex/003-l5-meta-growth`  
**Created**: 2026-06-05  
**Status**: Draft  
**Input**: Implement cross-run meta growth via knowledge unlocks and legacy stones, plus event encounter pickups that add discovery-based interaction within runs.

## User Scenarios & Testing

### User Story 1 - Discover and Unlock New Heads/Tails (Priority: P1)

When a player achieves specific feats in a run, new snake head or tail parts become permanently unlocked for future runs.

**Why this priority**: Unlocks create motivation for replay and mastery. Without unlocks, every run offers the same content pool.

**Independent Test**: Simulate a run triggering an unlock condition, verify the head/tail is added to the unlocked pool, verify it persists in user:// save file.

**Acceptance Scenarios**:

1. **Given** a player completes a run with >200 turns, **When** the run ends, **Then** "Ungud" head is unlocked permanently.
2. **Given** a player kills >15 enemies via status reactions, **When** the run ends, **Then** "Medusa" head is unlocked.
3. **Given** an unlock occurs, **When** the next run starts, **Then** the unlocked head appears in the reward/build pool.

---

### User Story 2 - Legacy Stones from Run Highlights (Priority: P1)

At the end of each run, a "Legacy Stone" is generated based on the run's highlight moment, biasing the next run's starting conditions.

**Why this priority**: Legacy stones give each run consequence and make death feel meaningful rather than purely punitive.

**Independent Test**: End a run with a notable achievement, verify a legacy stone is generated with correct bias config, store in user://, load in next run.

**Acceptance Scenarios**:

1. **Given** a run ends, **When** the strongest moment is identified, **Then** a legacy stone is created with description and bias_config.
2. **Given** legacy stones exist, **When** starting a new run, **Then** the player can optionally select one to bias starting scale/head/tail pools.
3. **Given** more than 5 legacy stones, **When** a new one is created, **Then** the oldest stone is automatically rotated out.

---

### User Story 3 - Event Pickups from Elite Enemies (Priority: P2)

Elite enemies drop special fragments (pickups) that can be activated later for unique effects, adding discovery-based depth.

**Why this priority**: Pickups create "opt-in depth" — players who want more can engage, others can ignore them.

**Independent Test**: Kill an elite enemy, verify a pickup fragment drops, verify it can be toggled/activated.

**Acceptance Scenarios**:

1. **Given** an elite enemy is killed, **When** the death event fires, **Then** a pickup fragment appears with a visible icon and description.
2. **Given** a pickup is carried, **When** the floor ends, **Then** the pickup disappears if not activated.
3. **Given** a "Broken Eye" pickup is active, **When** an enemy approaches, **Then** the enemy's next move direction is briefly shown.

---

### Edge Cases

- Unlock condition already met in a previous run: no duplicate unlock, no extra event.
- Legacy stone generated from a run with no notable moments: generate a default "survival" stone.
- Pickup fragment dropped on an occupied cell: offset to nearest free cell.
- Meta save file corrupted or missing: reset unlocks to defaults, log warning.

## Requirements

### Functional Requirements

- **FR-001**: System MUST track per-run statistics (turns, kills, reactions, survival time) for unlock condition evaluation.
- **FR-002**: System MUST check unlock conditions on run end and persist unlocked heads/tails to `user://meta_save.json`.
- **FR-003**: System MUST load meta save on game start and make unlocked content available.
- **FR-004**: System MUST generate one legacy stone per run based on the strongest highlight moment.
- **FR-005**: System MUST allow selecting one legacy stone at new run start, biasing pool probabilities.
- **FR-006**: System MUST cap legacy stones at 5, auto-rotating oldest.
- **FR-007**: System MUST drop pickup fragments on elite enemy kills.
- **FR-008**: System MUST clear pickup fragments on floor transition if not activated.
- **FR-009**: All meta data MUST be JSON-serializable and stored in user:// directory.
- **FR-010**: All L5 numeric values MUST be JSON-configurable.
- **FR-011**: All L5 system communication MUST use EventBus signals.

### Key Entities

- **MetaSaveData**: unlocked_heads, unlocked_tails, discovered_scales, legacy_stones (max 5).
- **RunStats**: per-run tracking of turns, kills, reaction_kills, near_death_count, damage_taken, survival_time.
- **LegacyStone**: description, highlight_type, bias_config (probability modifiers for next run pool).
- **UnlockCondition**: condition type, threshold value, target_id, description.
- **PickupFragment**: pickup_id, display_name, description, active state, activate_chains (atom chains).

## Success Criteria

- **SC-001**: At least 2 unlock conditions trigger correctly based on run-end statistics.
- **SC-002**: Meta save persists between game restarts and loads correctly on next start.
- **SC-003**: A legacy stone is generated after every completed run.
- **SC-004**: Legacy stones correctly bias pool probabilities when selected.
- **SC-005**: At least 1 pickup type drops from elite enemies and can be activated.
- **SC-006**: Pickup fragments are cleared on floor transition if not activated.
- **SC-007**: Full regression passes with strict Godot output scan.

## Assumptions

- L4 systems (ShedskinSystem, ScaleRewardSystem, ShopSystem, SlotExpansionSystem) are available.
- L3 systems (RunProgressionSystem, RoomFlowSystem) provide run lifecycle hooks.
- user:// directory is writable on target platforms.
- L5 v1 scopes to unlocks + legacy stones + pickups; full event encounters (buildings, traces) are deferred to L5 v2.