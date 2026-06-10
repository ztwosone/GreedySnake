# Feature Specification: L4 Growth Cycle

**Feature Branch**: `002-l4-growth-cycle`  
**Created**: 2026-06-05  
**Status**: Amended for re-acceptance（2026-06-11 治理修订：依设计文档 single-source-of-truth 原则对齐 Designs §10.2/§10.3-10.5/§11.5；逐条修订见各 **Amended 2026-06-11** 注记；范围外内容收容于本目录 `backlog.md`）  
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

1. **Given** a boss fight is completed, **When** boss settlement begins, **Then** the player receives a slot unlock as a FIXED, separate step (not one option competing inside the floor reward): the player picks front, middle, or back, and the new slot opens before the separate 3-choose-1 floor reward (US5) is presented.
2. **Given** a slot is unlocked, **When** the player equips a scale to the new slot, **Then** the scale functions normally and can participate in resonance.
3. **Given** the player has 3 slots, **When** they reach floor 3, **Then** the maximum slot count is 7 (front x2, middle x3, back x2).

> **Amended 2026-06-11**: 槽位解锁从「楼层奖励 3 选 1 的选项之一」修订为「Boss 结算的固定独立步骤（玩家选前/中/后）」。依据 Designs §10.3 奖励对照表「Boss 击败 → 槽位解锁（固定）+ 进层奖励 3 选 1」与 §10.5「第 1 层 Boss → 新增 1 槽（玩家选择加在哪个段：前/中/后）」。

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

When the player defeats a floor boss (on a non-final floor), the fixed slot-unlock step (US3) resolves first, then they receive a separate 3-choose-1 floor reward with exactly one option from each category — Expansion: gain a random advanced scale; Reinforcement: upgrade the lowest-level equipped scale; Correction: replace one equipped scale with a random same-tag scale.

**Why this priority**: Floor rewards create milestone moments that punctuate each floor and provide significant power spikes.

**Independent Test**: Defeat a boss on floor 1, verify the slot-unlock step resolves, then verify 3 floor reward options appear (advanced scale / upgrade lowest / same-tag swap), choose one, verify it applies correctly and only then does the next floor generate.

**Acceptance Scenarios**:

1. **Given** a boss is defeated on a non-final floor, **When** the floor reward screen appears, **Then** the Expansion option offers a random advanced scale.
2. **Given** a boss is defeated on a non-final floor, **When** the floor reward screen appears, **Then** the Reinforcement option offers a free upgrade of the currently lowest-level equipped scale.
3. **Given** a boss is defeated on a non-final floor, **When** the floor reward screen appears, **Then** the Correction option offers replacing one equipped scale with a random scale sharing the same tag.
4. **Given** the boss of the FINAL floor (`run.max_floors`) is defeated, **When** the room completes, **Then** NO floor reward is presented and the run proceeds to the victory path.
5. **Given** a floor reward is presented, **When** the player has not yet chosen, **Then** `advance_floor()` / `floor_generated` MUST NOT fire; the reward resolution strictly precedes floor advancement.

> **Amended 2026-06-11**: 楼层奖励模型对齐 Designs §10.4「进层奖励 3 选 1（每次从三类各抽一个）」：扩展类「随机获得 1 片高级鳞片」、强化类「当前最低等级鳞片免费升一级」、修正类「将一片鳞片替换为同标签的随机鳞片」。诅咒鳞变体（「获得一片『诅咒鳞』+ 强力补偿鳞片」）、槽位重排变体与蛇头/尾升级变体移入 `backlog.md`，不在 v1 范围。槽位解锁不再是奖励选项（见 US3 修订）。终层不弹楼层奖励、奖励决议先于 `floor_generated` 为重验收裁定（防止终层流程悬空与多层推进竞态）。

---

### User Story 6 - Difficulty Scaling and Room Modifiers (Priority: P3)

The game applies static per-floor pressure scaling that the player can feel (MUST), plus an optional reactive dynamic-difficulty adjustment that is designed to be invisible to the player (SHOULD), and introduces room modifiers that create environmental variety and tactical depth.

**Why this priority**: Difficulty scaling and room modifiers ensure replayability and prevent the game from becoming trivially easy or impossibly hard.

**Independent Test**: Generate consecutive floors and assert (in automated tests) that floor N+1 generation parameters are strictly harder than floor N per config; verify room modifiers appear and affect gameplay readably.

**Acceptance Scenarios**:

1. **Given** the run advances from floor N to floor N+1, **When** rooms are generated, **Then** generation pressure parameters (enemy weights/counts, elite chance) scale up per the JSON floor-scaling table — this static scaling is a MUST and is what the player is expected to feel.
2. **(SHOULD)** **Given** the player's tracked performance deviates strongly from expectation, **When** the next room is generated, **Then** generation parameters are micro-adjusted within configured clamps. Verification is by automated test on generation parameters ONLY — no acceptance criterion may require the player to perceive the reactive adjustment.
3. **Given** a room with a v1 modifier (`shield_enemies` or `preset_status_tiles`) is generated, **When** the player enters, **Then** the modifier effect is visible and alters gameplay in a readable way.
4. **Given** any difficulty or modifier setting, **When** the config is inspected, **Then** all thresholds and values are in JSON.

> **Amended 2026-06-11**: ① 难度拆为两层：层间静态压力递增 = MUST（玩家可感），反应式 DDA = SHOULD。依据 Designs §11.5「动态难度调整（隐性）：PCG 在生成下一房间时，根据玩家当前状态微调（**对玩家不可见**）」——验收措辞不得要求玩家感知 DDA，只允许测试在生成参数层验证。② 修饰符 v1 定为 `shield_enemies` + `preset_status_tiles`；后者直接来自 §11.5「追加『状态格已预置』修饰，引导接触状态效果」（复用状态格视觉，顺带教学状态系统）。darkness 主动降低可读性，与宪法可读性条款冲突，移入 `backlog.md`（speed_strips 一并入 backlog 作候选修饰符 #2 之后的扩展）。

---

### Edge Cases

- Scale reward pool is empty (or no eligible options after open-slot filtering): the offer MUST auto-resolve per FR-014 — emit `scale_option_discarded`-equivalent resolution with discard shedskin compensation per config; run progression continues without player input.
- All slots full when choosing a scale: allow replacement, don't force slot purchase.
- Boss room with no boss configured: falls back to elite room with double rewards.
- Shop with no purchasable items at all (empty inventory): auto-resolve per FR-014; with items but no affordable ones: display all items disabled, allow exit without purchase.
- Floor reward with zero eligible options in every category: auto-resolve per FR-014 (emit chosen with `skipped: true`); a category with no eligible target (e.g. no equipped scale to upgrade) substitutes a random advanced scale option so 3 options remain when possible.
- Reactive difficulty at min/max bounds: clamp to configured floor and ceiling.
- Room modifier stacking (`shield_enemies` + `preset_status_tiles`): allow stacking, but ensure each modifier's feedback is independently readable.
- Floor transition with accumulated shedskin: shedskin CARRIES OVER to the next floor; the pressure valve is rising shop prices (`shop.price_multiplier_per_floor`), not confiscation.

> **Amended 2026-06-11**: 空池/空选项边界从「显示提示文案」改为「自动决议」（依重验收裁定：`_get_visible_options` 可返回空 → pending 永不解除 → 死锁；见 FR-014）。蜕皮跨层条目依 Designs §10.2「蜕皮不跨层清零，但下层商人物价略有上涨」修订。darkness 相关条目随 US6 修订替换。

## Requirements

### Functional Requirements

- **FR-001**: System MUST provide scale rewards after combat room completion, displaying exactly 3 options.
- **FR-002**: System MUST track shedskin currency per RUN, incrementing on kills, scale discards, and exploration. **Amended 2026-06-11**: 原「per floor」依 Designs §10.2 修订为局内贯通（见 FR-003）。
- **FR-003**: Shedskin MUST carry over across floor transitions (NO reset). Economic pressure on later floors comes from rising shop prices via a single config knob `shop.price_multiplier_per_floor`. **Amended 2026-06-11**: 原「reset to 0 on floor transition」与 Designs §10.2 冲突，设计文档为 source of truth：「蜕皮不跨层清零，但下层商人物价略有上涨。」物价缩放仅以一个乘数配置实现，保持最小。
- **FR-004**: System MUST provide a shop room where shedskin can be spent on scales, slot unlocks, and head/tail upgrades.
- **FR-005**: System MUST allow slot expansion from 3 initial slots up to a maximum of 7 (front x2, middle x3, back x2).
- **FR-006**: System MUST generate multi-floor room graphs with procedurally varied room types, themes, and connections.
- **FR-007**: On boss completion of a NON-final floor, system MUST first resolve a fixed slot-unlock step (player picks front/middle/back), then present a separate 3-choose-1 floor reward with exactly: random advanced scale (Expansion), upgrade lowest-level equipped scale (Reinforcement), same-tag scale swap (Correction). On the final floor (`run.max_floors`), no floor reward is presented; the run enters the victory path. Floor reward resolution MUST precede `advance_floor()` / `floor_generated`. **Amended 2026-06-11**: 依 Designs §10.3「Boss 击败 → 槽位解锁（固定）+ 进层奖励 3 选 1」、§10.4 三类各一与 §10.5 选位规则；诅咒鳞等变体入 backlog.md。
- **FR-008**: System MUST implement static per-floor pressure scaling (floor N+1 generation strictly harder than floor N per JSON table). System SHOULD implement reactive dynamic difficulty adjustment based on player performance metrics; the reactive layer is designed-invisible and is verified only at the generation-parameter level by automated tests. **Amended 2026-06-11**: 依 Designs §11.5「（对玩家不可见）」拆分 MUST/SHOULD；玩家可感的难度来自层间静态缩放。
- **FR-009**: System MUST support room modifiers that are configurable and individually disableable. v1 modifier set: `shield_enemies`, `preset_status_tiles`. **Amended 2026-06-11**: darkness/speed_strips 移入 backlog.md；`preset_status_tiles` 依 Designs §11.5「追加『状态格已预置』修饰」。
- **FR-010**: All L4 numeric values MUST be JSON-configurable with no hardcoded magic numbers.
- **FR-011**: All L4 system communication MUST use EventBus signals.
- **FR-012**: L4 v1 MUST build all panels on the S1 presentation kernel (`Project/ui/kit/`) and expose presentation hooks for ceremony orchestration in S4. **Amended 2026-06-11**: S1 已交付统一表现内核，原「placeholder visuals」措辞过时。
- **FR-013**: Restarting a run MUST clear all L4 growth state (shedskin, slots, floor progression, difficulty modifiers).
- **FR-014**: Any offer system (L3 reward flow, scale reward, floor reward, shop) presenting ZERO eligible options MUST auto-resolve — emitting its chosen event with `skipped: true` or its discarded event — so that run progression can never deadlock on an empty offer. **Amended 2026-06-11**: 重验收裁定——空选项 + 模态门控组合否则必死锁。
- **FR-015**: While any offer is pending (a `*_presented` without its matching chosen/discarded), run progression MUST ignore advance requests and the room-advance UI MUST be disabled. **Amended 2026-06-11**: 模态门控成文，与 FR-014 配对。
- **FR-016**: Config MUST expose `run.max_floors` (explicitly superseding and REMOVING the old `max_floors_v1` key — accessor and all callers migrate in the same change) and a `floor.generator` switch with values `"fixed_v1" | "pcg"`. **Amended 2026-06-11**: 重验收配置基线；fixed_v1 保留为回退/MDE 路径。
- **FR-017**: Concept pacing MUST be expressed as config data, not code: `floor.modifier_weights` and elite spawn weights are 0 on floor 1; each floor's generation guarantees a shop room placed after at least 2 combat rooms. **Amended 2026-06-11**: 概念节奏入配置（首层零修饰/零精英、商店保底），使 S2 验收可纯数据验证。
- **FR-018**: ScaleRewardSystem contract — combat room completion triggers an offer of exactly 3 options; choosing equips via `ScaleSlotManager`; discarding grants shedskin; choosing MUST NOT emit a synthetic `room_completed`. Scope note: removal of synthetic `room_completed` applies to ScaleRewardSystem ONLY; RewardFlowSystem's synthetic `room_completed` for L3 reward rooms is the sole completion pathway for those rooms (load-bearing) and REMAINS as a documented contract in QuickReference. **Amended 2026-06-11**: 草稿的合成发射为缺陷（幻影二次 offer 根因之一）；拆除范围精确限定，防止误伤 L3 奖励房通路。

### Key Entities

- **ShedskinCurrency**: Run-scoped integer tracking currency earned and spent. Carries over across floors (**Amended 2026-06-11** per Designs §10.2; see FR-003).
- **ScaleReward**: A set of 3 scale options presented after combat. Contains scale_id, position, level, placeholder_color.
- **ShopInventory**: A set of purchasable items determined by the shop room config. Each item has a price in shedskin, a category (scale/slot/head-tail), and a target.
- **SlotExpansion**: Tracks current slot counts per position, max slots, and unlock history.
- **SlotUnlockStep**: The fixed boss-settlement step where the player picks front/middle/back for the new slot. Separate from and preceding FloorReward (**Amended 2026-06-11** per Designs §10.3/§10.5).
- **FloorReward**: A 3-choose-1 reward presented after the slot-unlock step on non-final floors: random advanced scale / upgrade lowest-level scale / same-tag swap (**Amended 2026-06-11** per Designs §10.4).
- **FloorTheme**: An environment tag (cave/marsh/ruins/machine/void) and pressure tag (hunting/wasteland/maze/speedrun/siege) that influence room generation.
- **RoomModifier**: A gameplay-altering rule applied to a room. v1 set: `shield_enemies`, `preset_status_tiles` (**Amended 2026-06-11**: darkness/speed_strips → backlog.md). Each has a visible effect and JSON config.
- **DifficultyState**: Tracks current difficulty parameters (enemy count, armor chance, food density) and player performance metrics (clear speed, damage taken, status usage).

## Success Criteria

- **SC-001**: A player can complete a combat room, see 3 scale options, choose one, and verify it equips correctly — all within one screen of placeholder UI.
- **SC-002**: Shedskin currency accumulates correctly: +1 per normal kill, +3 per elite, +2 per discarded scale option. Currency carries over across floor transitions; shop prices on floor N reflect `shop.price_multiplier_per_floor`. **Amended 2026-06-11** per Designs §10.2.
- **SC-003**: A shop room displays at least 3 purchasable items, each with a visible price. The player can purchase at least one item and verify currency deduction.
- **SC-004**: A boss kill on a non-final floor resolves the fixed slot-unlock step (player picks position), then presents the 3-choose-1 floor reward (advanced scale / upgrade lowest / same-tag swap). A final-floor boss kill presents no floor reward and reaches the victory path. **Amended 2026-06-11** per Designs §10.3-10.5.
- **SC-005**: A multi-floor run generates at least 3 distinct floors, each with a procedurally different room layout and theme.
- **SC-006**: Static scaling (MUST): automated tests verify floor N+1 generation parameters are strictly harder than floor N per the JSON table. Reactive DDA (SHOULD): automated tests verify generation parameters shift within clamps under simulated over/under-performance; no criterion requires player-perceivable change. **Amended 2026-06-11** per Designs §11.5（隐性）.
- **SC-007**: Both v1 room modifiers (`shield_enemies`, `preset_status_tiles`) are implemented and visually distinguishable during gameplay. **Amended 2026-06-11**.
- **SC-008**: Full regression (existing + new L4 tests) passes with strict Godot output scan.
- **SC-009**: All L4 config values are in JSON and verifiable by automated tests; `max_floors_v1` no longer exists anywhere (superseded by `run.max_floors`). **Amended 2026-06-11**.
- **SC-010**: Concept pacing is verifiable from config data alone: floor-1 modifier and elite weights are 0; every generated floor contains a shop placed after at least 2 combat rooms (seeded property test). **Amended 2026-06-11** (new, per FR-017).
- **SC-011**: `floor.generator` switches between `fixed_v1` and `pcg`; with a fixed seed, `pcg` output is deterministic (same graph twice). **Amended 2026-06-11** (new, per FR-016).
- **SC-012**: No offer deadlock: automated tests drive each of the four offer systems into a zero-eligible-options state and verify auto-resolution plus continued run progression; advance requests during a pending offer are ignored. **Amended 2026-06-11** (new, per FR-014/FR-015).

## Assumptions

- L3 v1 systems (RunProgressionSystem, RoomFlowSystem, RewardFlowSystem) are available as foundations and will be extended, not replaced. FloorMapGenerator's PCG path is REWRITTEN (seeded, config-weighted); its fixed v1 path is retained behind the `floor.generator` switch. **Amended 2026-06-11**: 草稿 PCG 不可保（不用 seed、纯线性、无 shop/elite、魔数），见 plan.md 判决表。
- L2 Build systems (SnakePartsManager, ScaleSlotManager, ResonanceManager) are production-ready and L4 rewards integrate through their existing APIs.
- L4 v1 builds all UI on the S1 presentation kernel (`ui/kit/`); ceremony orchestration (pause/dim/stagger/flight) is S4 scope. **Amended 2026-06-11**: 取代原 placeholder UI 假设。
- L4's scope is single-run growth (within one run). Cross-run meta growth (unlocks, legacy stones) is L5 scope; ScaleRewardSystem exposes an injectable sampling-bias hook so L5 legacy stones can plug in without rework.
- Boss enemies for L4 v1 use the existing enemy system with increased HP parts and a "boss" flag; full boss mechanics (phase transitions, unique behaviors) are deferred.
- Shedskin currency is run-scoped and carries across floors. **Amended 2026-06-11** per Designs §10.2.
- The existing `game_config.json` will be extended with new L4 sections (`growth`, `shop`, `difficulty`, `floor_themes`, `room_modifiers`) plus the re-acceptance keys of FR-016/FR-017 (`run.max_floors`, `floor.generator`, `floor.modifier_weights`, `shop.price_multiplier_per_floor`).
- L5 Event Encounters and Meta Growth are separate milestones and will not be implemented in L4.