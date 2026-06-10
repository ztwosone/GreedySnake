# Implementation Plan: L4 Growth Cycle

**Branch**: `002-l4-growth-cycle` | **Date**: 2026-06-05（Amended 2026-06-11 重验收治理：架构/门禁/重验收策略对齐修订版 spec） | **Spec**: `.specify/specs/002-l4-growth-cycle/spec.md`

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
├── backlog.md          # Amended 2026-06-11: 范围外收容（诅咒鳞/darkness/speed_strips/富愿景）
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
│       ├── floor_map_generator.gd      # Rewritten: seeded PCG + fixed_v1 switch
│       └── room_director.gd            # New: room population orchestrator
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

- **ShedskinSystem** owns run-scoped currency that CARRIES OVER across floors (**Amended 2026-06-11** per Designs §10.2; FR-003). Listens to `enemy_killed`, `scale_option_discarded`, `room_explored` for gains. Emits `currency_changed`. Resets only on run restart (FR-013).
- **ScaleRewardSystem** presents 3-choose-1 after combat room completion. Reuses ScaleSlotManager.equip_scale() for application. Pools drawn from JSON `growth.scale_reward_pools`, filtered by open slots; full-slot choice = replacement; empty pool auto-resolves (FR-014); discards grant shedskin; never emits synthetic `room_completed` (FR-018); exposes injectable sampling-bias hook for L5 legacy stones.
- **ShopSystem** presents purchasable items when entering shop rooms. Item categories: scale (2-4 shedskin), slot unlock (5 shedskin), head/tail upgrade (4 shedskin); prices scale by `shop.price_multiplier_per_floor`. Emits `shop_purchase`; exits via `room_entered` of the next room.
- **SlotExpansionSystem** is a THIN ADAPTER over ScaleSlotManager.open_slot() (**Amended 2026-06-11**: 草稿从不调 open_slot，买槽零效果). Initial: front=1, middle=1, back=1. Max: front=2, middle=3, back=2. Unlocks via boss fixed slot-unlock step and shop. Persists across floors within a run. Emits `slot_unlocked`.
- **FloorRewardSystem** runs boss settlement on NON-final floors only: fixed slot-unlock step (player picks front/middle/back) then 3-choose-1 — random advanced scale / upgrade lowest-level scale / same-tag swap (**Amended 2026-06-11** per Designs §10.3-10.5; FR-007). Emits `floor_reward_chosen`; resolution precedes `advance_floor()`.
- **FloorMapGenerator** PCG path REWRITTEN: seeded room-graph generation with config weights/branching, guaranteed shop after >=2 combat rooms, endpoint=boss; fixed v1 path retained behind `floor.generator` switch (**Amended 2026-06-11**). Supports floor themes (environment x pressure tags) and room modifier injection.
- **DifficultyScaler** MUST: static per-floor pressure scaling from the JSON floor table. SHOULD: reactive adjustment from per-room performance metrics (per-room clear time, damage taken, status usage), designed-invisible per Designs §11.5, clamped, sole consumer = RoomDirector (**Amended 2026-06-11**).
- **RoomModifierSystem** applies v1 modifiers when entering a room: `shield_enemies` (extra HP), `preset_status_tiles` (pre-placed status tiles per Designs §11.5). Each modifier has on_apply/on_remove atom chains and an individual JSON disable switch (**Amended 2026-06-11**: darkness/speed_strips → backlog.md).
- **RoomDirector**（新增）: listens `room_entered`/`floor_generated`, clears the field, populates enemies/food by room type + theme weights + difficulty modifiers. Prerequisite: EnemyManager incremental retrofit (`respawn_policy` default `maintain` keeps L1/L2 behavior and tests green, injected weight table, spawn_budget).

## Public Interfaces and Events

New EventBus signals:

- `currency_changed(data: Dictionary)` — {currency: "shedskin", amount: int, total: int, source: String}
- `scale_reward_presented(data: Dictionary)` — {room_id: String, options: Array, offer_id: String}
- `scale_reward_chosen(data: Dictionary)` — {option_id: String, scale_id: String, position: String, level: int, skipped: bool}
- `scale_option_discarded(data: Dictionary)` — {offer_id: String, discarded_ids: Array, shedskin_gained: int}（**Amended 2026-06-11**：FR-018 拆除合成 room_completed 后的显式决议信号）
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
- Boss settlement = fixed slot-unlock step + separate 3-choose-1 floor reward (one option per category); none on the final floor. **Amended 2026-06-11** per Designs §10.3-10.5.
- Slot unlocks are scarce (starting slots: 3, boss kills: +2~3, shop: +1, max: 7).
- Shedskin carries over across floors; later-floor pressure = shop price multiplier. **Amended 2026-06-11** per Designs §10.2「蜕皮不跨层清零，但下层商人物价略有上涨」.
- Static per-floor scaling is MUST; reactive DDA is SHOULD and designed-invisible with configurable min/max clamps. **Amended 2026-06-11** per Designs §11.5.
- All room modifiers are individually disableable via JSON; v1 set = `shield_enemies` + `preset_status_tiles`.
- No offer system may deadlock: zero eligible options auto-resolve; run progression ignores advance while an offer is pending (FR-014/FR-015).
- All panels built on S1 `ui/kit/` (theme_builder/kit_panel/glyph/choice_card/banner/chip); zero in-kit orchestration (S4 scope).

## 重验收策略（Amended 2026-06-11）

> 本 feature 不是绿地开发：6-5 草稿的 13 个系统文件 + 4 个面板 + 13 个测试文件已存在（零场景集成，缺陷逐文件实证）。
> 任务语义统一为「对照修订后 spec 验证/修复/重写」，判决如下。

### 13 文件判决表（file:line 实证，前 8 个属本 spec，后 5 个属 spec 003 / S3，列出供全景）

| 文件 | 判决 | 要点 |
|---|---|---|
| `systems/growth/shedskin_system.gd` | 保留+修 | Enemy 节点被当 Dictionary 判型（:87）→ elite 分支死代码；跨层清零改为保留（FR-003 修订后）；补 discard 收入 |
| `systems/growth/scale_reward_system.gd` | 重写逻辑 | 幻影二次 offer + 状态互踩软锁（:85,:98）；拆除合成 `room_completed`（**仅此系统**，FR-018）；改发 `scale_reward_chosen`/`scale_option_discarded`；满槽替换/空池自动决议/按开放槽过滤/传承石偏置钩子 |
| `systems/growth/slot_expansion_system.gd` | 重写为薄适配器 | 从不调 `open_slot()`（买槽零效果，shop:165 return true 什么也不做）；ScaleSlotManager MAX_SLOTS JSON 化 + accessor 并**同卡迁移 build_test_panel.gd:161 的直读** |
| `systems/growth/shop_system.gd` | 修 | pool[0] 伪随机（:198）、容量误用已装数（:130）、exit_shop 无调用方（接 room_entered 退店）；补 room_types.shop；接 price_multiplier_per_floor |
| `systems/growth/floor_reward_system.gd` | 重写逻辑 | 假实现（expansion 硬编码 equip、correction 是 pass）；改为 §10.3-10.5 模型：固定槽位解锁（选位）+ 3 选 1（高级鳞/升级最低级件/同 tag 换鳞）；**终层不弹**（floor_index < max_floors 才呈现） |
| `systems/rooms/floor_map_generator.gd` | PCG 重写，fixed_v1 留作 `floor.generator` 开关 | 现 PCG 完全不用 seed、纯线性、无 shop/elite、魔数（:54-84）；重写为 seeded + config 权重/分支 + 每层保底 shop（≥2 战斗房后）+ endpoint=boss |
| `systems/difficulty/difficulty_scaler.gd` | 重写 | 全局 tick 当单房用时（:114）、分母硬编码（:93）、无消费者；重写度量 + JSON 化 + 唯一消费者 RoomDirector；**层间静态缩放为 MUST，反应式 DDA 为 SHOULD** |
| `systems/difficulty/room_modifier_system.gd` | 重写-扩展 | 从不被应用；v1 = `shield_enemies` + `preset_status_tiles`（darkness 入 backlog.md，可读性冲突） |
| `systems/meta_growth/meta_save_system.gd` | 保留+微修（S3） | 注入 save_path、容错重置、schema 版本 |
| `systems/meta_growth/run_stats_tracker.gd` | 保留+补（S3） | 补 near_death/low_length/damage_taken 源；finalize_run 为 run_ended 唯一发射点，调用方 = RunProgressionSystem |
| `systems/meta_growth/unlock_system.gd` | 保留+修（S3） | 先补 Designs §12.3 v1 映射附录；gate 现有内容；RewardFlow 按解锁集过滤 |
| `systems/meta_growth/legacy_stone_system.gd` | 保留+修（S3） | 阈值 JSON 化；bias 消费端落在奖励抽样加权；selected payload 带完整 stone |
| `systems/meta_growth/pickup_system.gd` | 修+补实体层（S3 Should） | 节点判型 bug、elite 查 is_elite、网格实体化（仿 food）、randf 先于 elite 判定的顺序修正；v1 仅 broken_eye |

### 集成架构摘要

- **RoomDirector**（新节点）：监听 `room_entered`/`floor_generated` → 清场 → 按房型+主题权重+难度修正布怪布食。**前置契约变更：EnemyManager 增量改造**——新增 `respawn_policy`（默认 `maintain`，保 L1/L2「击杀即补怪、永续维持 max_enemy_count」行为与既有测试绿）+ 注入式权重表 + spawn_budget。
- **多层切换**：`run.max_floors: 3`（显式取代 `max_floors_v1`，accessor 同卡更新全部调用方）；新增 `game_world.reset_for_floor()`（组合既有 clear_enemies/clear_foods/clear_all 原语）；蛇重建后 Build 装备存续有专门测试卡；楼层奖励决议**先于** `advance_floor()` 发 `floor_generated`；终层 `floor_completed` → 胜利路径（不弹楼层奖励）。
- **模态门控**：任一 `*_presented` 未决时 RunProgression 忽略推进、Next 禁用；四 offer 系统（RewardFlow/Scale/FloorReward/Shop）空选项自动决议（FR-014/FR-015）。
- **合入节奏**：每 US（任务簇）完成即严格门禁 + 合 main——针对本仓库两次「长分支搁浅」失败模式。
- **MDE 存活检查点**：T3 簇完成后打 tag `mde-checkpoint`（F5 → S1 设计语言 → fixed_v1 单层 → 战斗 → 鳞片三选一 → 蜕皮 → 商店买槽 → Boss → 死亡结算）。此后任何中断，项目仍是可交付的最小体验。砍单阶梯（绝不低于 MDE）：反应式 DDA → 主题敌池 → 修饰符扩展。