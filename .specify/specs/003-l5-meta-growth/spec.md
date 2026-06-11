# Feature Specification: L5 Meta Growth & Events

**Feature Branch**: `003-l5-meta-growth`
**Created**: 2026-06-05
**Amended**: 2026-06-11（S3 治理修订：解锁目标对齐 Designs §12.3 附录 v1 内容映射；US3 裁定为 SHOULD + broken_eye only；新增 run_ended 唯一发射点 / 冻结 payload 契约 / 存档 schema_version / 空石碑跳过 / bias 消费口径诸 FR。M3 编排裁定：`GameManager.GameState.STONE_SELECT` 枚举与基础开局分流提前至 S3 落地，SUMMARY 与仪式编排仍归 S4）
**Status**: Amended for S3 re-acceptance
**Input**: Implement cross-run meta growth via knowledge unlocks and legacy stones, plus event encounter pickups that add discovery-based interaction within runs.

> Scope note (2026-06-11): unlock targets MUST exist in the `snake_heads` / `snake_tails` JSON
> content pools (design-first red line, Designs §12.3 附录「v1 内容映射」). Items moved out of
> v1 scope are recorded in `backlog.md` in this directory.

## User Scenarios & Testing

### User Story 1 - Discover and Unlock New Heads/Tails (Priority: P1)

When a player achieves specific feats in a run, new snake head or tail parts become permanently unlocked for future runs. v1 maps unlock conditions onto EXISTING content only, per Designs §12.3 附录:

- `hydra` (head) and `salamander` (tail): unlocked by default (starting content).
- `bai_she` (head): unlocked by achieving ≥ 10 reaction kills in a single run (status-synergy discovery, Medusa-style condition).
- `lag_tail` (tail): unlocked by completing ≥ 2 floors in a single run (sustained-survival condition).
- `ungud` / `medusa` / `taotie` / `styx_tail`: future content, NOT in v1 JSON (see backlog.md).

**Why this priority**: Unlocks create motivation for replay and mastery. Without unlocks, every run offers the same content pool.

**Independent Test**: Simulate a run triggering an unlock condition, verify the head/tail is added to the unlocked pool, verify it persists in the save file (injected temp path).

**Acceptance Scenarios**:

1. **Given** a fresh meta save, **When** content pools are first queried, **Then** only `hydra` and `salamander` are unlocked, and locked parts (`bai_she`, `lag_tail`) never appear in reward/build pools.
2. **Given** a player kills ≥ 10 enemies via status reactions in one run, **When** the run ends, **Then** the `bai_she` head is unlocked permanently (and exactly once — repeated achievement causes no duplicate unlock/event).
3. **Given** a player completes ≥ 2 floors in one run, **When** the run ends, **Then** the `lag_tail` tail is unlocked permanently.
4. **Given** an unlock occurs, **When** the next run starts, **Then** the unlocked head/tail appears in the reward/build pool.

---

### User Story 2 - Legacy Stones from Run Highlights (Priority: P1)

At the end of each run, a "Legacy Stone" is generated based on the run's highlight moment, biasing the next run's starting conditions.

**Why this priority**: Legacy stones give each run consequence and make death feel meaningful rather than purely punitive.

**Independent Test**: End a run with a notable achievement, verify a legacy stone is generated with correct bias config, store via injected temp save path, load in next run.

**Acceptance Scenarios**:

1. **Given** a run ends, **When** the strongest moment is identified (thresholds from JSON), **Then** a legacy stone is created with description and bias_config.
2. **Given** legacy stones exist, **When** starting a new run, **Then** the player can optionally select one on the StoneSelect screen to bias starting scale/reward pools; the selection event carries the FULL stone dictionary.
3. **Given** more than 5 legacy stones, **When** a new one is created, **Then** the oldest stone is automatically rotated out.
4. **Given** the legacy stone list is empty (first run of a fresh save), **When** a new run starts, **Then** the StoneSelect screen is skipped entirely — the concept lands on run 2, with the stone the player just watched being forged (ruling #12).

---

### User Story 3 - Event Pickups from Elite Enemies (Priority: P2, SHOULD)

Elite enemies drop special fragments (pickups) as grid entities. **v1 scope = `broken_eye` ONLY** (`serpent_scale` moved to backlog.md). The carry/activate model is KEPT per Designs §9.4 — no auto-activate simplification:

- **Carry**: the fragment is dropped on the grid (offset to nearest free cell if occupied), picked up by the snake head; while carried, the carry effect is live — for `broken_eye`, enemies' next move direction is shown (DangerIndicator data path reuse).
- **Activate**: the activation model (active state, `activate_pickup` API, `pickup_activated` event) is retained as the system seam; the rich activation routes of Designs §9.4 (A: merchant special trade → full-eye scale; B: fragment merge → twin-eye scale) have no v1 carrier content and live in backlog.md.
- **Expiry**: non-activated pickups are cleared on floor transition (Designs §9.4: 不激活 → 层结束时自动消失).

**Why this priority**: Pickups create "opt-in depth" — players who want more can engage, others can ignore them. SHOULD priority: first item on the cut ladder; if over budget the whole cluster moves to backlog and this spec is marked deferred.

**Independent Test**: Kill an elite enemy (node-typed, `is_elite` from config), verify a `broken_eye` grid entity drops, verify pickup → carry effect → floor-exit clearing.

**Acceptance Scenarios**:

1. **Given** an elite enemy is killed, **When** the death event fires, **Then** a `broken_eye` fragment may drop as a grid entity with a visible icon and description (drop roll happens only after the elite check).
2. **Given** a fragment is carried and not activated, **When** the floor ends, **Then** the fragment disappears.
3. **Given** a `broken_eye` is carried, **When** enemies act, **Then** each enemy's next move direction is shown (DangerIndicator reuse).

---

### Edge Cases

- Unlock condition already met in a previous run: no duplicate unlock, no extra event.
- Legacy stone generated from a run with no notable moments: generate a default "survival" stone.
- Pickup fragment dropped on an occupied cell: offset to nearest free cell.
- Meta save file corrupted, unreadable, or carrying an unknown `schema_version`: tolerant reset to defaults (default unlocks included), log warning, never crash and never load a half-broken state.
- `finalize_run` invoked twice for the same run (double exit-path bug): once-guard rejects the second call; `run_ended` is emitted exactly once.
- StoneSelect with empty stone list: screen never flashes — skipped entirely.

## Requirements

### Functional Requirements

- **FR-001**: System MUST track per-run statistics (turns, kills, reactions, survival metrics, damage) for unlock condition evaluation.
- **FR-002**: System MUST check unlock conditions on run end and persist unlocked heads/tails to the meta save file.
- **FR-003**: System MUST load meta save on game start and make unlocked content available; reward/build pools MUST be filtered by the unlock set (locked content never offered).
- **FR-004**: System MUST generate one legacy stone per run based on the strongest highlight moment; highlight thresholds MUST be JSON-configurable.
- **FR-005**: System MUST allow selecting one legacy stone at new run start, biasing pool probabilities.
- **FR-006**: System MUST cap legacy stones at 5, auto-rotating oldest.
- **FR-007**: System MUST drop pickup fragments on elite enemy kills (v1: `broken_eye` only; elite identified via enemy node + `is_elite` config).
- **FR-008**: System MUST clear pickup fragments on floor transition if not activated.
- **FR-009**: All meta data MUST be JSON-serializable and stored in `user://` (production path `user://meta_save.json`); the save path MUST be injectable so tests use temporary paths and never pollute the production save.
- **FR-010**: All L5 numeric values MUST be JSON-configurable.
- **FR-011**: All L5 system communication MUST use EventBus signals.
- **FR-012**: The StoneSelect screen MUST be skipped entirely when the legacy stone list is empty (first run; the concept lands on run 2 — ruling #12).
- **FR-013**: `run_ended` MUST be emitted exactly once per run, by `RunStatsTracker.finalize_run(outcome)` as the SOLE emitter, called by `RunProgressionSystem` on both the victory and the death exit path, protected by a once-guard.
- **FR-014**: The meta save file MUST carry a `schema_version` field; corrupt/missing/unknown-version files MUST trigger a tolerant reset (see Edge Cases).
- **FR-015**: A selected legacy stone's bias MUST be consumed as `bias_config.scale_tag_weights` weighting in scale/reward sampling (via the existing `ScaleRewardSystem.set_sampling_bias` hook); the bias is valid for exactly one run.
- **FR-016**: The `run_ended` payload contract is FROZEN as follows (verified against the run_stats_tracker draft and test_l5 suites; `max_length` and `duration_ticks` are completed in M1; the draft's `stats.run_outcome` duplication is dropped — top-level `outcome` is canonical):

```text
run_ended: {
  outcome: "victory" | "death",
  run_id: String,
  floor_index: int,
  stats: {
    total_turns: int,
    total_kills: int,
    reaction_kills: int,
    near_death_count: int,
    survival_low_length_ticks: int,
    floors_completed: int,
    max_reaction_chain: int,
    damage_taken: int,
    max_length: int,
    duration_ticks: int
  }
}
```

### Key Entities

- **MetaSaveData**: schema_version, unlocked_heads, unlocked_tails, discovered_scales (reserved, v2), legacy_stones (max 5).
- **RunStats**: per-run tracking per the FR-016 frozen contract.
- **LegacyStone**: description, highlight_type, display_name, bias_config (scale_tag_weights probability modifiers for next run pool), created_at.
- **UnlockCondition**: condition_id, condition_type, threshold, target_type, target_id (MUST exist in content pools), display_name, description.
- **PickupFragment**: pickup_id (v1: `broken_eye`), display_name, description, grid position, carried/active state.

## Success Criteria

- **SC-001**: The two v1 unlock conditions (`bai_she` via reaction kills, `lag_tail` via floors completed) trigger correctly based on run-end statistics; default unlocks (`hydra`, `salamander`) present on fresh save.
- **SC-002**: Meta save persists between game restarts and loads correctly on next start (automated proxy: save → new system instance on same path → state restored; cross-process restart is Gate-H).
- **SC-003**: A legacy stone is generated after every completed run.
- **SC-004**: Legacy stones correctly bias pool probabilities when selected (deterministic-seed distribution shift assertable).
- **SC-005**: `broken_eye` drops from elite enemies as a grid entity and its carry effect is observable via the DangerIndicator data path.
- **SC-006**: Pickup fragments are cleared on floor transition if not activated.
- **SC-007**: Full regression passes with strict Godot output scan.
- **SC-008**: Full-loop smoke (`test_l5_full_loop`, temp save path): run 1 death → `run_ended` exactly once + stone forged + unlocks evaluated + file written → run 2 stone select → bias affects sampling.

## Assumptions

- L4 systems (ShedskinSystem, ScaleRewardSystem, ShopSystem, SlotExpansionSystem) are available (S2 closed, merged to main).
- L3 systems (RunProgressionSystem, RoomFlowSystem) provide run lifecycle hooks.
- user:// directory is writable on target platforms.
- L5 v1 scopes to unlocks + legacy stones + `broken_eye` pickup; full event encounters (buildings, traces), `serpent_scale`, and future heads/tails are deferred (backlog.md).
- S3 builds data paths plus the minimal StoneSelect screen flow: all UI on `Project/ui/kit/`. Per the 2026-06-11 M3 orchestration ruling, `GameManager.GameState.STONE_SELECT` (appended to the enum, existing int values preserved) and the title/restart → stone-select → run branching landed in S3 M3; `SUMMARY` and all ceremony choreography remain S4 (004 Phase P).
