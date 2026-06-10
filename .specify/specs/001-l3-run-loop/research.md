# Research: L3 Run Loop

## Decision: Reuse Build as the first reward depth source

**Rationale**: L2 already implemented snake heads, tails, scales, and resonance. Reusing those systems creates depth without introducing a new resource economy.

**Alternatives considered**:

- Add a new currency: rejected for L3 v1 because it increases cognition and belongs closer to L4/L5.
- Add many new rewards: rejected because content breadth is less important than loop completion.

## Decision: One-room-one-intent pacing

**Rationale**: The player should understand each room immediately. Combat, reward, rest, and endpoint rooms remain distinct in v1.

**Alternatives considered**:

- Multi-objective rooms: rejected for L3 v1 because they increase cognitive load and complicate acceptance.
- Pure linear arenas only: rejected because L3 needs a floor loop, not just one combat scene.

## Decision: Functional placeholders for UI/art

**Rationale**: Final art should not block gameplay validation. Color blocks, labels, and debug panels are enough to test cognition and flow.

**Alternatives considered**:

- Require polished UI before gameplay: rejected because it slows system validation.
- No UI until final art: rejected because room intent and rewards must be readable.

## Decision: Strict output scan as verification gate

**Rationale**: The existing runner can report all assertions passed while Godot prints script errors. A wrapper must scan process output and fail on unallowed errors.

**Alternatives considered**:

- Trust exit code only: rejected because current evidence shows false green.
- Fix every historical test before writing the wrapper: rejected because the wrapper defines the target gate first.

