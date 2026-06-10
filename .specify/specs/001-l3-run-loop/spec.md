# Feature Specification: L3 Run Loop

**Feature Branch**: `codex/001-l3-run-loop`  
**Created**: 2026-05-18  
**Status**: Draft  
**Input**: Build the first complete playable run loop for GreedySnake Roguelite while keeping gameplay deep and player cognition light.

## User Scenarios & Testing

### User Story 1 - Enter and Complete a Room (Priority: P1)

A player starts a run, enters a generated room, understands the room's single primary goal, clears it, and receives clear completion feedback.

**Why this priority**: No run loop exists until a room can be entered, resolved, and exited.

**Independent Test**: Start a run in a deterministic room layout, clear all required enemies or objectives, and verify the room transitions to completed state.

**Acceptance Scenarios**:

1. **Given** a new run, **When** the player starts the first room, **Then** the game presents one clear room intent using placeholder visuals.
2. **Given** a combat room with enemies, **When** all required enemies are cleared, **Then** the room is marked complete and emits a completion event.
3. **Given** the room is complete, **When** the player advances, **Then** the next room or reward step becomes available.

---

### User Story 2 - Choose a Reward (Priority: P1)

After reaching a reward step or reward room, the player sees a small reward choice and can apply it to the existing Build system without learning a new resource model.

**Why this priority**: The roguelite loop needs a reward beat, but L3 v1 should reuse existing Build depth.

**Independent Test**: Complete a room, select one placeholder reward, and verify the selected head, tail, scale, or upgrade is applied.

**Acceptance Scenarios**:

1. **Given** a reward room or reward step, **When** rewards are presented, **Then** the player sees no more than three understandable options.
2. **Given** a reward option is selected, **When** it applies, **Then** the Build test panel/state reflects the change.
3. **Given** no final art exists, **When** rewards display, **Then** color blocks and text labels are sufficient for selection and feedback.

---

### User Story 3 - Progress Through a Floor (Priority: P2)

The player moves through a short sequence of rooms and reaches a floor endpoint.

**Why this priority**: A complete run needs pacing beyond one room.

**Independent Test**: Use VirtualPlayer or deterministic inputs to clear a fixed floor path and verify floor progress increments.

**Acceptance Scenarios**:

1. **Given** a floor map, **When** a room is completed, **Then** adjacent available rooms are revealed or selectable.
2. **Given** the player completes the required path, **When** the floor endpoint is reached, **Then** the game transitions to the boss or end condition.
3. **Given** the player restarts a run, **When** the new run begins, **Then** old floor and room state is cleared.

---

### User Story 4 - Finish a Run (Priority: P2)

The player can reach a v1 endpoint, either by defeating a boss placeholder or completing the floor goal, and see a clear run result.

**Why this priority**: L3 v1 is not complete until a run has a beginning, middle, and end.

**Independent Test**: Run through a fixed sequence to endpoint and verify run end state, score/result, cleanup, and restart.

**Acceptance Scenarios**:

1. **Given** the endpoint room starts, **When** its objective is cleared, **Then** the run ends in victory.
2. **Given** the snake dies before the endpoint, **When** death occurs, **Then** the existing game over flow still works.
3. **Given** the run ends, **When** the player restarts, **Then** no room, reward, modifier, or window state leaks into the next run.

### Edge Cases

- Starting a new run after victory or death must clear all L3 run state.
- A room with zero enemies must either auto-complete or be classified as a non-combat room.
- Reward options that cannot be applied must be hidden or disabled.
- Placeholder UI must not block core controls.

## Requirements

### Functional Requirements

- **FR-001**: The system MUST provide a run state that tracks current floor, current room, completed rooms, and run outcome.
- **FR-002**: The system MUST generate a small floor made of rooms with clear room types: combat, reward, rest, and endpoint.
- **FR-003**: Each room MUST expose exactly one primary player-facing intent.
- **FR-004**: Combat rooms MUST complete when their configured objective is satisfied.
- **FR-005**: Reward rooms or reward steps MUST offer no more than three options at once.
- **FR-006**: Rewards MUST reuse existing Build concepts before introducing new resources.
- **FR-007**: Room, reward, floor, and run transitions MUST be observable through events.
- **FR-008**: All new numeric values MUST be configurable through JSON.
- **FR-009**: L3 v1 MUST support functional placeholder visuals and UI.
- **FR-010**: Restarting a run MUST clear L3 state and preserve existing cleanup guarantees.
- **FR-011**: Automated smoke validation MUST be possible through VirtualPlayer or deterministic test helpers.

### Design Requirements

- **DR-001**: New gameplay must add depth through combinations with existing status, enemy, Build, resonance, or room systems.
- **DR-002**: No single task may introduce multiple new player concepts that must be learned simultaneously.
- **DR-003**: New mechanics must be introduced first in low-pressure contexts before mixed combat.
- **DR-004**: Placeholder feedback must communicate state through color, position, label, icon, or debug panel.
- **DR-005**: Complex mechanics must be configurable or disableable for debugging and balance.

### Key Entities

- **RunState**: Tracks floor index, current room id, completed rooms, reward state, and outcome.
- **FloorMap**: A generated list or graph of rooms for one floor.
- **RoomNode**: A room definition with type, intent, objective, exits, and placeholder presentation.
- **RoomObjective**: A completion condition such as clear enemies or reach endpoint.
- **RewardOffer**: A small set of Build-oriented reward options.

## Success Criteria

- **SC-001**: A deterministic smoke run can start, complete at least two rooms, choose a reward, and reach an endpoint.
- **SC-002**: Each room type can be independently tested without depending on final art assets.
- **SC-003**: A player can identify the current room intent from placeholder feedback within one screen.
- **SC-004**: No reward screen presents more than three options.
- **SC-005**: Restarting after victory or death leaves no active L3 room, reward, window, modifier, or GridWorld residue.
- **SC-006**: Full regression and strict Godot output scan pass before L3 v1 is accepted.

## Assumptions

- L3 v1 optimizes for a complete playable loop, not content breadth.
- L4 growth depth and L5 meta-growth remain out of scope.
- Final art and polished UI are out of scope; functional placeholders are acceptable.
- Existing Build, status, enemy, and VirtualPlayer systems remain available as foundations.
