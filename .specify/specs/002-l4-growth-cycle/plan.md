# Implementation Plan: L4 Growth Cycle

**Branch**: `codex/002-l4-growth-cycle` | **Date**: 2026-06-05 | **Spec**: `.specify/specs/002-l4-growth-cycle/spec.md`

## Summary

Implement the single-run growth cycle: scale acquisition with 3-choose-1 UI after combat rooms, shedskin currency economy with shop rooms, scale slot expansion through boss kills and shop purchases, floor rewards at boss completion, multi-floor PCG room generation with themes and modifiers, and dynamic difficulty scaling. All growth feeds into existing Build systems (SnakePartsManager, ScaleSlotManager, ResonanceManager). Keep per-room cognitive load low while enabling Build depth through accumulation over a run.

## Technical Context

**Language/Version**: Godot 4.6.1 + GDScript 4
**Primary Dependencies**: EventBus, ConfigManager, RunProgressionSystem, RoomFlowSystem, RewardFlowSystem, FloorMapGenerator, SnakePartsManager, ScaleSlotManager, ResonanceManager, EnemyManager, TickManager, StatusEffectManager
**Storage**: JSON configuration under `Project/data/json/`
**Testing**: Headless Godot runner plus strict output scan
**Target Platform**: Desktop Godot project
**Project Type**: Single Godot game project
**Performance Goals**: Room generation within 1 frame at current 40x22 grid scale; scale reward UI instant; shop UI instant
**Constraints**: Event-driven systems only; JSON-driven numeric values; functional placeholder UI; extend existing systems, don't replace
**Scale/Scope**: 3-5 floors per run, 12-24 rooms per run, max 7 scale slots, 9 scale types, 4-6 room modifiers, ~50 config values

## Constitution Check

- **Design-first**: L4 spec/plan/tasks created before code. Existing `Designs/General/snake_roguelite_design.md` sections 9-11 provide complete design.
- **Event-driven architecture**: All L4 growth events (currency_changed, scale_presented, slot_unlocked, shop_purchase, floor_reward, difficulty_adjusted) via EventBus.
- **Data-driven configuration**: Shop prices, scale drop weights, floor scaling, modifier chances, difficulty thresholds all in JSON.
- **TDD**: Each task writes failing tests before implementation.
- **GDScript conventions**: snake_case files/functions, PascalCase classes, typed GDScript 4 syntax.
- **Deep Experience, Light Cognition**: All 6 USes add depth through existing Build/resonance/enemy/room systems; scale choices are 3 per screen; shop has at most 5 items.
- **Placeholder-First**: Scale reward UI uses color blocks + text labels; shop uses simple buttons; floor reward UI reuses reward panel pattern.

## Project Structure

```text
.specify/specs/002-l4-growth-cycle/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── tasks.md
└── checklists/

Project/
├── data/json/game_config.json         # Extended: growth, shop, difficulty, floor_themes, room_modifiers
├── autoloads/event_bus.gd              # Extended: L4 signals
├── systems/
│   ├── growth/
│   │   ├── shedskin_system.gd          # Currency tracking
│   │   ├── scale_reward_system.gd      # 3-choose-1 after combat
│   │   ├── shop_system.gd              # Shop room logic
│   │   ├── slot_expansion_system.gd    # Slot unlock tracking
│   │   └── floor_reward_system.gd      # Boss floor rewards
│   ├── difficulty/
│   │   ├── difficulty_scaler.gd        # Dynamic difficulty adjustment
│   │   └── room_modifier_system.gd     # Room modifier application
│   └── rooms/
│       └── floor_map_generator.gd      # Extended: multi-floor PCG
├── ui/
│   ├── scale_choice_panel.gd           # 3-choose-1 scale UI
│   ├── shop_panel.gd                   # Shop UI
│   ├── floor_reward_panel.gd           # Floor reward UI
│   └── shedskin_display.gd             # Currency HUD element
└── Test/cases/
    ├── test_l4_scale_rewards.gd
    ├── test_l4_shedskin.gd
    ├── test_l4_shop.gd
    ├── test_l4_slots.gd
    ├── test_l4_floor_rewards.gd
    ├── test_l4_pcg_rooms.gd
    ├── test_l4_difficulty.gd
    └── test_l4_acceptance.gd
```

**Structure Decision**: New systems go under `systems/growth/` and `systems/difficulty/`, matching the design doc. FloorMapGenerator is extended in-place rather than replaced. UI panels follow existing L3 patterns (PanelContainer with _build_ui/_connect_events/_refresh).

## Architecture Plan

- **ShedskinSystem** owns per-floor currency. Listens to `enemy_killed`, `scale_option_discarded`, `room_explored` for gains. Emits `currency_changed`. Resets on `floor_generated`.
- **ScaleRewardSystem** presents 3-choose-1 after combat room completion. Reuses ScaleSlotManager.equip_scale() for application. Pools drawn from JSON `growth.scale_reward_pools`.
- **ShopSystem** presents purchasable items when entering shop rooms. Item categories: scale (2-4 shedskin), slot unlock (5 shedskin), head/tail upgrade (4 shedskin). Emits `shop_purchase`.
- **SlotExpansionSystem** tracks slot counts. Initial: front=1, middle=1, back=1. Max: front=2, middle=3, back=2. Unlocks via floor_reward (boss) and shop. Persists across floors within a run. Emits `slot_unlocked`.
- **FloorRewardSystem** presents 3-choose-1 after boss defeat. Categories: Expansion (advanced/curse scale + compensation), Reinforcement (upgrade lowest scale/head/tail), Correction (reorder/same-tag swap). Emits `floor_reward_chosen`.
- **FloorMapGenerator** extended with PCG: generates room graph instead of fixed v1 path. Supports floor themes (environment x pressure tags), terrain templates (open/corridor/island/spiral), and room modifier injection.
- **DifficultyScaler** evaluates player performance metrics (clear speed, damage taken, status usage) at room boundaries and adjusts next room params (enemy count, armor chance, food density). All thresholds and deltas in JSON.
- **RoomModifierSystem** applies modifier effects when entering a room (darkness vision reduction, speed strips movement bonus, shield enemies extra HP). Each modifier has on_apply/on_remove atom chains.

## Public Interfaces and Events

New EventBus signals:

- `currency_changed(data: Dictionary)` — {currency: "shedskin", amount: int, total: int, source: String}
- `scale_reward_presented(data: Dictionary)` — {room_id: String, options: Array, offer_id: String}
- `scale_reward_chosen(data: Dictionary)` — {option_id: String, scale_id: String, position: String, level: int}
- `shop_entered(data: Dictionary)` — {room_id: String, items: Array}
- `shop_purchase(data: Dictionary)` — {item_id: String, category: String, cost: int, currency_remaining: int}
- `slot_unlocked(data: Dictionary)` — {position: String, total_slots: int, source: String}
- `floor_reward_presented(data: Dictionary)` — {floor_index: int, options: Array}
- `floor_reward_chosen(data: Dictionary)` — {category: String, option_id: String}
- `difficulty_adjusted(data: Dictionary)` — {reason: String, adjustment: Dictionary}
- `room_modifier_applied(data: Dictionary)` — {room_id: String, modifier_id: String}
- `floor_theme_set(data: Dictionary)` — {theme: String, pressure: String, floor_index: int}

## Design Gates

- Each scale reward screen shows exactly 3 options.
- Shop items are capped at 5 visible items per visit.
- Floor reward uses one option from each of 3 categories.
- Slot unlocks are scarce (starting slots: 3, boss kills: +2, shop: +1, max: 7).
- Shedskin resets per floor; no carry-over.
- Dynamic difficulty has configurable min/max bounds.
- All room modifiers are individually disableable via JSON.
- Placeholder UI uses existing patterns (labels, color blocks, buttons).