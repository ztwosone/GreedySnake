# GreedySnake Constitution

## Core Principles

### I. Design-First (NON-NEGOTIABLE)

Any code change that deviates from the current design documents must follow this workflow:
1. Identify the conflict with the design document
2. Pause coding - do NOT write code directly
3. Confirm with the user which design changes are needed
4. Update the design document first
5. Then implement the code
6. Sync `TechDocs/QuickReference.md` after both are done

Design documents (`Designs/`) are the single source of truth. Code must never be ahead of design.

### II. Event-Driven Architecture

- All inter-system communication goes through `EventBus` (autoload singleton)
- Systems must NOT hold direct references to each other
- All game events use signal-based pub/sub pattern
- Grid-based world with tick-driven game loop (`TickManager`)

### III. Data-Driven Configuration

- All numeric values and game parameters go in JSON config files (`data/json/`)
- No hardcoded magic numbers in game logic
- `ConfigManager` autoload provides typed access to all config data
- Enemy types, status effects, reactions, snake parts all defined in JSON

### IV. Test-First / TDD (NON-NEGOTIABLE)

Every feature implementation follows Red-Green-Refactor:
1. **Red** - Write failing tests based on the spec/task requirements
2. **Green** - Write the minimum code to make tests pass
3. **Refactor** - Clean up while keeping tests green
4. **Regression** - Run full test suite, all must pass before committing

- Test runner: headless Godot via `test_runner.tscn`
- Test framework: GUT (Godot Unit Testing)
- Tests are written BEFORE implementation code, not after

### V. GDScript Conventions

- Variables and functions: `snake_case`
- Classes and type names: `PascalCase`
- Constants: `UPPER_SNAKE_CASE`
- Signals: past tense (`enemy_killed`, `food_eaten`)
- Private members prefixed with `_`

### VI. Deep Experience, Light Cognition

- New gameplay must create depth through combinations with existing snake status, enemies, Build parts, resonances, or room flow
- A single task must not introduce multiple new player-facing concepts at once
- New rules must be introduced in low-pressure contexts before mixed combat
- Feedback must be readable through color, position, icon, text label, or simple UI
- Complex mechanics must be configurable, disableable, or degradable through data for debugging and balance

### VII. Placeholder-First Presentation

- Art and UI polish must not block gameplay validation
- Functional placeholders are acceptable for L3 v1: color blocks, text labels, simple icons, and debug panels
- New systems must preserve presentation hooks so final art/UI can replace placeholders later
- Acceptance criteria check clarity and usability, not final visual quality

## Technology Stack

- **Engine**: Godot 4.6.1 (GDScript 4)
- **Architecture**: Grid-based + Tick-driven + Event-driven + Data-driven
- **Key Autoloads**: EventBus, TickManager, GridWorld, StatusEffectManager, ConfigManager, GameManager, VFXManager, Constants
- **Test Framework**: GUT via headless runner

## Document Hierarchy

| Layer | Path | Purpose |
|-------|------|---------|
| Design docs (source of truth) | `Designs/` | Full system design and tech architecture |
| Quick reference | `TechDocs/QuickReference.md` | Current implementation state index |
| Agent control plane | `AgentOps/` | Session-independent orchestration, verification, and handoff state |
| Daily logs | `DailyLogs/` | Daily development records |
| Task tracking | `Tasks/` (L0-L2), `.specify/specs/` (L3+) | Milestone task breakdown |
| Spec-driven features | `.specify/specs/NNN-feature/` | SpecKit workflow artifacts |

## Development Workflow (L3+)

New features follow the SpecKit six-phase workflow:
1. `/speckit-specify` - Define requirements specification
2. `/speckit-clarify` - Clarify ambiguous areas (optional)
3. `/speckit-plan` - Technical design
4. `/speckit-tasks` - Task breakdown
5. `/speckit-implement` - Execute tasks
6. `/speckit-checklist` - Quality validation (optional)

L0-L2 historical artifacts in `Designs/` and `Tasks/` remain as-is.

## Governance

- Constitution supersedes default practices
- Design documents supersede code
- Amendments require user confirmation
- SpecKit specs live alongside (not replacing) existing design docs

**Version**: 1.1.0 | **Ratified**: 2026-04-10 | **Amended**: 2026-05-18
