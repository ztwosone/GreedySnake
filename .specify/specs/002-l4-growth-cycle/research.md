# Research: L4 Growth Cycle

## Decision: Per-floor shedskin economy, not persistent

**Rationale**: The design document specifies shedskin as per-floor currency that resets on floor transition. This creates tight decision windows per floor without the complexity of cross-floor carryover. Matches roguelite conventions (Slay the Spire gold, etc.).

**Alternatives considered**:
- Persistent shedskin: rejected because it creates snowball dynamics where a strong floor 1 assures victory.
- No currency at all: rejected because it removes the meaningful choice between immediate power (scales) and long-term growth (slots).

## Decision: Extend RewardFlowSystem pattern for scale rewards

**Rationale**: L3 RewardFlowSystem already handles "present options → choose one → apply to Build." Scale rewards follow the same flow but with:
- Different trigger (combat room completion, not reward room entry)
- Different option pool (scales from JSON config)
- Application via ScaleSlotManager.equip_scale() instead of equip_head/equip_tail

**Alternatives considered**:
- Separate scale reward code path: rejected because duplication of the present/choose/apply pattern.
- Extend RewardFlowSystem to handle both: considered but adds complexity to a system with clean single responsibility. A new ScaleRewardSystem reusing the same pattern is preferred.

## Decision: PCG floor generation as FloorMapGenerator extension

**Rationale**: L3 v1 FloorMapGenerator reads `fixed_v1_path` from JSON. L4 extends it with procedural generation modes:
- Room count: 5-8 per floor
- Room graph: branching with 2-3 endpoint candidates
- Room types: combat (50%), elite (15%), shop (10%), relic (5%), rest (10%), hidden (5%), boss (5%)
- Floor theme: selected from JSON floor_themes, influences enemy pools and terrain templates

**Alternatives considered**:
- Replace FloorMapGenerator entirely: rejected because the existing interface (generate_floor → rooms array) is clean and extensible.
- External graph library: rejected for dependency weight; the room graph is small enough for manual construction.

## Decision: Dynamic difficulty as invisible adjustment, not visible player choice

**Rationale**: The design doc specifies DDA as "invisible to player" - the game adjusts based on performance metrics without the player choosing a difficulty level. Metrics: clear speed (tick count per room), damage taken (hits per room), status usage rate (status actions per room).

**Alternatives considered**:
- Player-selectable difficulty: rejected because the design explicitly calls for invisible DDA.
- No difficulty scaling: rejected because replayability requires challenge adaptation.

## Decision: Room modifiers as JSON-configured atom chains

**Rationale**: Following the existing T25 Atom System pattern, each modifier has:
- `apply_chains`: atom chains executed when the room is entered
- `remove_chains`: atom chains executed when the room is exited
- `visual_config`: presentation parameters for the placeholder visual
- `enabled: bool`: individually disableable

This allows modifiers to be data-driven without new code for each one.

**Alternatives considered**:
- Hardcoded modifier logic per type: rejected because it violates the data-driven principle and prevents easy balancing.
- Separate modifier script per type: rejected because atoms already cover the effect space (modify_speed, apply_status, etc.).

## Decision: Shop UI as simple button list extending RewardChoicePanel pattern

**Rationale**: The shop is conceptually similar to the reward choice panel: display items, let player pick one. Differences: items have prices and stock, multiple items can be bought per visit.

**Alternatives considered**:
- Full shop with grid layout: rejected for L4 v1 placeholder scope.
- Reusing RewardChoicePanel directly: rejected because shop needs different interactions (multiple purchases, price display, disable when unaffordable).