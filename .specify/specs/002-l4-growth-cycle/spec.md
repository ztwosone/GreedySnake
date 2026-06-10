# Feature Specification: L4 Growth Cycle

**Feature Branch**: `codex/002-l4-growth-cycle`  
**Created**: 2026-06-05  
**Status**: Draft  
**Input**: Implement the growth cycle: scale acquisition with 3-choose-1 UI, shedskin currency economy, shop rooms, slot expansion, floor rewards, multi-floor PCG room generation, dynamic difficulty scaling, and room modifiers within a single run.

## User Scenarios & Testing

### User Story 1 - Gain Scales After Combat (Priority: P1)

After clearing a combat room, the player sees a 3-choose-1 scale reward screen and equips a scale to their available slot, building their Build incrementally.

**Why this priority**: Scales are the core growth mechanic. Without scale acquisition, the Build system has no in-run growth driver.

**Independent Test**: Complete a combat room, verify 3 scale options appear, choose one, verify it equips to the correct slot position.

**Acceptance Scenarios**:

1. **Given** a combat room is completed, **When** the reward step triggers, **Then** the player sees exactly 3 scale options with name, position, and color.
2. **Given** 3 scale options are displayed, **When** the player selects one, **Then** the scale equips to its designated slot position and the Build panel reflects the change.
3. **Given** a slot is already occupied, **When** a new scale for the same position is chosen, **Then** the old scale is replaced, and any resonance is recalculated.

---

### User Story 2 - Earn and Spend Shedskin Currency (Priority: P1)

Throughout a floor, the player accumulates shedskin currency from kills, discarded scale options, and exploration. In shop rooms, they spend it on scales, slot unlocks, or head/tail upgrades.

**Why this priority**: Currency creates meaningful choice between immediate power (scales) and long-term growth (slots), and is the backbone of the economy.

**Independent Test**: Kill enemies to accumulate shedskin, enter a shop room, spend currency on a scale, verify currency deducted and scale equipped.

**Acceptance Scenarios**:

1. **Given** a run is in progress, **When** an enemy is killed, **Then** shedskin currency increases by 1 (normal enemy) or 3 (elite).
2. **Given** a scale reward is presented, **When** the player chooses an option, **Then** the other two options are discarded and each adds +2 shedskin.
3. **Given** the player enters a shop room with enough shedskin, **When** they purchase a scale, **Then** currency is deducted and the scale equips immediately.
4. **Given** a shop room is entered, **When** the player has insufficient shedskin for an item, **Then** that item is visibly disabled.

---

### User Story 3 - Expand Scale Slots (Priority: P2)

The player can unlock additional scale slots through boss kills and shop purchases, growing from 3 initial slots to a maximum of 7.

**Why this priority**: Slot expansion is the primary long-term growth driver. Without it, Build depth is capped at 3 scales.

**Independent Test**: Defeat a boss, receive a slot unlock, choose a position, verify the new slot is available and can accept a scale.

**Acceptance Scenarios**:

1. **Given** a boss fight is completed, **When** the floor reward is presented, **Then** one option is a slot unlock allowing the player to add a slot to front, middle, or back.
2. **Given** a slot is unlocked, **When** the player equips a scale to the new slot, **Then** the scale functions normally and can participate in resonance.
3. **Given** the player has 3 slots, **When** they reach floor 3, **Then** the maximum slot count is 7 (front x2, middle x3, back x2).

---

### User Story 4 - Multi-Floor PCG Room Generation (Priority: P2)

The player progresses through multiple floors, each with procedurally generated room sequences, themes, and hazards instead of the v1 fixed path.

**Why this priority**: The L3 v1 fixed path of 5 rooms is a proof of concept. A real roguelite needs procedural variety across floors.

**Independent Test**: Start a new run, verify the first floor generates a non-trivial room graph with at least one combat room, one reward opportunity, and a boss endpoint.

**Acceptance Scenarios**:

1. **Given** a new run starts, **When** floor 1 is generated, **Then** the room graph contains at least 5 rooms with combat, reward, and a boss endpoint.
2. **Given** a floor is generated, **When** the player enters a room, **Then** the room type and intent are clearly displayed.
3. **Given** the player completes a floor, **When** the next floor starts, **Then** the environment theme may change (cave, marsh, ruins, etc.) and enemy difficulty scales appropriately.

---

### User Story 5 - Floor Rewards at Boss Completion (Priority: P2)

When the player defeats a floor boss, they receive a 3-choose-1 floor reward drawn from three categories: Expansion (advanced/curse scale), Reinforcement (upgrade), and Correction (reorder/swap).

**Why this priority**: Floor rewards create milestone moments that punctuate each floor and provide significant power spikes.

**Independent Test**: Defeat a boss, verify 3 floor reward options appear (one each from expansion, reinforcement, correction), choose one, verify it applies correctly.

**Acceptance Scenarios**:

1. **Given** a boss is defeated, **When** the floor reward screen appears, **Then** one option is from the Expansion category (advanced scale or curse scale + compensation).
2. **Given** a boss is defeated, **When** the floor reward screen appears, **Then** one option is from the Reinforcement category (upgrade lowest-level scale, head, or tail).
3. **Given** a boss is defeated, **When** the floor reward screen appears, **Then** one option is from the Correction category (slot reorder or tag-matched scale swap).

---

### User Story 6 - Dynamic Difficulty and Room Modifiers (Priority: P3)

The game adjusts difficulty based on player performance and introduces room modifiers that create environmental variety and tactical depth.

**Why this priority**: Difficulty scaling and room modifiers ensure replayability and prevent the game from becoming trivially easy or impossibly hard.

**Independent Test**: Complete rooms and observe enemy count/food density changes based on simulated player strength; verify room modifiers appear and affect gameplay.

**Acceptance Scenarios**:

1. **Given** the player is performing well above expected power, **When** the next room is generated, **Then** enemy count or armor chance increases slightly.
2. **Given** the player is struggling, **When** the next room is generated, **Then** food density increases or enemy count decreases slightly.
3. **Given** a room with a modifier (e.g. darkness, speed strips, shield enemies) is generated, **When** the player enters, **Then** the modifier effect is visible and alters gameplay in a readable way.
4. **Given** any difficulty or modifier setting, **When** the config is inspected, **Then** all thresholds and values are in JSON.

---

### Edge Cases

- Scale reward pool is empty: show a message "no scales available" and grant +3 shedskin instead.
- All slots full when choosing a scale: allow replacement, don't force slot purchase.
- Boss room with no boss configured: falls back to elite room with double rewards.
- Shop with no affordable items: display all items disabled, allow exit without purchase.
- Floor reward categories exhausted: show "all categories used" with a generic scale option.
- Dynamic difficulty at min/max bounds: clamp to configured floor and ceiling.
- Room modifier conflicts (e.g. darkness + speed strips): allow stacking, but ensure each modifier's feedback is independently readable.
- Zero shedskin on floor transition: shedskin resets to 0 when entering a new floor.

## Requirements

### Functional Requirements

- **FR-001**: System MUST provide scale rewards after combat room completion, displaying exactly 3 options.
- **FR-002**: System MUST track shedskin currency per floor, incrementing on kills, scale discards, and exploration.
- **FR-003**: System MUST reset shedskin to 0 on floor transition.
- **FR-004**: System MUST provide a shop room where shedskin can be spent on scales, slot unlocks, and head/tail upgrades.
- **FR-005**: System MUST allow slot expansion from 3 initial slots up to a maximum of 7 (front x2, middle x3, back x2).
- **FR-006**: System MUST generate multi-floor room graphs with procedurally varied room types, themes, and connections.
- **FR-007**: System MUST provide floor rewards (3-choose-1) after boss completion, with one option from each of Expansion, Reinforcement, and Correction categories.
- **FR-008**: System MUST implement dynamic difficulty adjustment based on player performance metrics.
- **FR-009**: System MUST support room modifiers (e.g. darkness, speed strips, shield enemies) that are configurable and disableable.
- **FR-010**: All L4 numeric values MUST be JSON-configurable with no hardcoded magic numbers.
- **FR-011**: All L4 system communication MUST use EventBus signals.
- **FR-012**: L4 v1 MUST use placeholder visuals (color blocks, text labels, debug panels) and expose presentation hooks for future art replacement.
- **FR-013**: Restarting a run MUST clear all L4 growth state (shedskin, slots, floor progression, difficulty modifiers).

### Key Entities

- **ShedskinCurrency**: Per-floor integer tracking currency earned and spent. Reset on floor transition.
- **ScaleReward**: A set of 3 scale options presented after combat. Contains scale_id, position, level, placeholder_color.
- **ShopInventory**: A set of purchasable items determined by the shop room config. Each item has a price in shedskin, a category (scale/slot/head-tail), and a target.
- **SlotExpansion**: Tracks current slot counts per position, max slots, and unlock history.
- **FloorReward**: A 3-choose-1 reward presented after boss completion, with one option each from Expansion, Reinforcement, and Correction.
- **FloorTheme**: An environment tag (cave/marsh/ruins/machine/void) and pressure tag (hunting/wasteland/maze/speedrun/siege) that influence room generation.
- **RoomModifier**: A gameplay-altering rule applied to a room (darkness, speed strips, shield enemies, etc.). Each has a visible effect and JSON config.
- **DifficultyState**: Tracks current difficulty parameters (enemy count, armor chance, food density) and player performance metrics (clear speed, damage taken, status usage).

## Success Criteria

- **SC-001**: A player can complete a combat room, see 3 scale options, choose one, and verify it equips correctly — all within one screen of placeholder UI.
- **SC-002**: Shedskin currency accumulates correctly: +1 per normal kill, +3 per elite, +2 per discarded scale option. Currency resets to 0 on floor transition.
- **SC-003**: A shop room displays at least 3 purchasable items, each with a visible price. The player can purchase at least one item and verify currency deduction.
- **SC-004**: A boss kill presents a 3-choose-1 floor reward with one option from each of Expansion, Reinforcement, and Correction categories.
- **SC-005**: A multi-floor run generates at least 3 distinct floors, each with a procedurally different room layout and theme.
- **SC-006**: Dynamic difficulty adjusts enemy count or food density by at least 1 unit when the player is clearly over-performing or under-performing.
- **SC-007**: At least 2 room modifier types are implemented and visually distinguishable during gameplay.
- **SC-008**: Full regression (existing + new L4 tests) passes with strict Godot output scan.
- **SC-009**: All L4 config values are in JSON and verifiable by automated tests.

## Assumptions

- L3 v1 systems (RunProgressionSystem, RoomFlowSystem, RewardFlowSystem, FloorMapGenerator) are available as foundations and will be extended, not replaced.
- L2 Build systems (SnakePartsManager, ScaleSlotManager, ResonanceManager) are production-ready and L4 rewards integrate through their existing APIs.
- L4 v1 uses placeholder UI (color blocks, text labels, buttons) — final art is out of scope.
- L4's scope is single-run growth (within one run). Cross-run meta growth (unlocks, legacy stones) is L5 scope.
- Boss enemies for L4 v1 use the existing enemy system with increased HP parts and a "boss" flag; full boss mechanics (phase transitions, unique behaviors) are deferred.
- Shedskin currency is per-floor only; cross-floor currency is out of scope.
- The existing `game_config.json` will be extended with new L4 sections (`growth`, `shop`, `difficulty`, `floor_themes`, `room_modifiers`).
- L5 Event Encounters and Meta Growth are separate milestones and will not be implemented in L4.