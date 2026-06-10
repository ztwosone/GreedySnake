# Implementation Plan: L5 Meta Growth & Events

**Branch**: `codex/003-l5-meta-growth` | **Date**: 2026-06-05 | **Spec**: `.specify/specs/003-l5-meta-growth/spec.md`

## Summary

Implement cross-run meta growth: knowledge system (unlock heads/tails by achieving feats), legacy stones (per-run highlight bias for next run), and event pickups (elite enemy drops with activation). All meta data persists in `user://meta_save.json`.

## Technical Context

**Language/Version**: Godot 4.6.1 + GDScript 4
**Primary Dependencies**: EventBus, ConfigManager, RunProgressionSystem, EnemyManager, SnakePartsManager, StatusEffectManager
**Storage**: `user://meta_save.json` via ConfigFile or JSON write
**Testing**: Headless Godot runner + strict output scan
**Platform**: Desktop Godot project
**Project Type**: Single Godot game project
**Scale/Scope**: ~5 unlock conditions, 2 pickup types, max 5 legacy stones, ~30 config values

## Constitution Check

- **Design-first**: L5 spec from existing `Designs/General/snake_roguelite_design.md` sections 9, 12.
- **Event-driven**: All meta events via EventBus.
- **Data-driven**: Unlock thresholds, pickup config, legacy stone biases in JSON.
- **TDD**: Tests before implementation.
- **Placeholder-first**: UI for meta uses simple text labels.

## Project Structure

```text
Project/
├── systems/
│   ├── meta_growth/
│   │   ├── meta_save_system.gd       # Persistence to user://
│   │   ├── run_stats_tracker.gd      # Per-run stat tracking
│   │   ├── unlock_system.gd          # Unlock condition checking
│   │   └── legacy_stone_system.gd    # Legacy stone generation
│   └── events/
│       └── pickup_system.gd          # Event pickup drops
├── ui/
│   └── pickup_display.gd             # Pickup HUD icon
└── Test/cases/
    ├── test_l5_meta_save.gd
    ├── test_l5_unlocks.gd
    ├── test_l5_legacy.gd
    └── test_l5_pickups.gd
```

## Architecture

- **MetaSaveSystem**: Loads/saves `MetaSaveData` to `user://`, provides query methods.
- **RunStatsTracker**: Subscribes to relevant events during run, accumulates counts.
- **UnlockSystem**: On `run_ended`, checks all conditions against stats, unlocks qualifying content.
- **LegacyStoneSystem**: On `run_ended`, evaluates highlight, generates stone with bias_config.
- **PickupSystem**: Listens to `enemy_killed` for elite type, spawns pickup fragment, handles activation.

## Events

New EventBus signals:
- `content_unlocked(data: Dictionary)` — {content_type, content_id, display_name}
- `legacy_stone_created(data: Dictionary)` — {description, highlight_type, bias_config}
- `legacy_stone_selected(data: Dictionary)` — {stone_index}
- `pickup_dropped(data: Dictionary)` — {pickup_id, position, display_name}
- `pickup_activated(data: Dictionary)` — {pickup_id}
- `run_ended(data: Dictionary)` — {outcome, stats: Dictionary}