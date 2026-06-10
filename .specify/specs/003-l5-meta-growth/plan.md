# Implementation Plan: L5 Meta Growth & Events

**Branch**: `003-l5-meta-growth` | **Date**: 2026-06-05（Amended 2026-06-11, S3 re-acceptance） | **Spec**: `.specify/specs/003-l5-meta-growth/spec.md`

## Summary

Implement cross-run meta growth: knowledge system (unlock heads/tails by achieving feats), legacy stones (per-run highlight bias for next run), and event pickups (elite enemy drops with activation). All meta data persists in `user://meta_save.json` (path injectable for tests).

## 重验收策略（2026-06-11）

6-5 草稿五文件判决（经 file:line 实证，详见总体计划判决表）；任务语义 = 「对照修订后 spec 验证/修复/重写」：

| 文件 | 判决 | 要点 |
|---|---|---|
| meta_save_system.gd | 保留+微修 | 注入 save_path、容错重置、schema_version、默认解锁集 |
| run_stats_tracker.gd | 保留+补 | 补 near_death/low_length/damage 源 + max_length/duration_ticks；finalize_run 为 `run_ended` 唯一发射点，调用方 = RunProgressionSystem（victory/death 双出口，once-guard） |
| unlock_system.gd | 保留+修 | 先补 Designs §12.3 v1 映射附录（已落，2026-06-11）；gate 现有内容；RewardFlow 按解锁集过滤 |
| legacy_stone_system.gd | 保留+修 | 阈值 JSON 化；bias 消费端 = 奖励抽样 scale_tag_weights 加权（ScaleRewardSystem.set_sampling_bias 既有钩子）；selected payload 带完整 stone |
| pickup_system.gd | 修+补实体层（SHOULD） | 节点判型 bug、elite 查 is_elite、网格实体化（仿 food）、randf 顺序修正；v1 仅 broken_eye |

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
├── scenes/
│   └── main.tscn                     # + MetaGrowthRoot 常驻节点（GameWorldContainer 外）
├── systems/
│   ├── meta_growth/
│   │   ├── meta_growth_root.gd       # 常驻根：boot 加载 MetaSaveSystem，托管子系统（M2 新建）
│   │   ├── meta_save_system.gd       # Persistence（注入 save_path + schema_version + 容错重置）
│   │   ├── run_stats_tracker.gd      # Per-run stat tracking（run_ended 唯一发射点）
│   │   ├── unlock_system.gd          # Unlock condition checking（v1 映射）
│   │   └── legacy_stone_system.gd    # Legacy stone generation（阈值 JSON 化）
│   └── events/
│       └── pickup_system.gd          # Event pickup drops（broken_eye 网格实体）
├── ui/
│   ├── unlock_toast.gd               # 解锁 toast（kit chip/banner，数据通路，M2 新建）
│   └── stone_select_screen.gd        # 石碑选择屏（kit，空列表跳过，M3 新建）
└── Test/cases/
    ├── test_l5_meta_save.gd
    ├── test_l5_unlocks.gd
    ├── test_l5_legacy.gd
    ├── test_l5_pickups.gd
    ├── test_l5_full_loop.gd          # 全环冒烟（M4 新建）
    └── test_l5_acceptance.gd
```

## Architecture

- **MetaGrowthRoot**（M2 新建，main.tscn 常驻节点，game_world 外）: boot 加载 MetaSaveSystem（生产路径，可注入）；子节点 UnlockSystem / LegacyStoneSystem / RunStatsTracker `setup(meta_save)`；跨 run 存续，世界重建不清；暴露 `get_last_run_summary()` 结算数据缓存（统计 + 新铸石 + 新解锁，视觉编排归 S4）。
- **MetaSaveSystem**: Loads/saves `MetaSaveData`, provides query methods; save_path injectable; schema_version + tolerant reset; 默认解锁集 hydra/salamander.
- **RunStatsTracker**: Subscribes to relevant events during run, accumulates counts; `finalize_run(outcome)` is the SOLE `run_ended` emitter (once-guard), called by RunProgressionSystem on victory/death exits.
- **UnlockSystem**: On `run_ended`, checks v1 conditions (Designs §12.3 附录) against stats, unlocks qualifying content; RewardFlow/SnakeParts pools filtered by unlock set.
- **LegacyStoneSystem**: On `run_ended`, evaluates highlight (JSON thresholds), generates stone with bias_config; selected stone's `scale_tag_weights` consumed via `ScaleRewardSystem.set_sampling_bias`.
- **PickupSystem**: Listens to `enemy_killed` (Enemy node + `is_elite` config), spawns `broken_eye` grid entity, carry effect via DangerIndicator data path, floor-exit clearing; SHOULD（砍单阶梯首位）.

## Events

New EventBus signals (frozen per spec FR-016 where noted):
- `content_unlocked(data: Dictionary)` — {content_type, content_id, display_name}
- `legacy_stone_created(data: Dictionary)` — {description, highlight_type, display_name, bias_config, created_at}
- `legacy_stone_selected(data: Dictionary)` — {stone_index, stone: Dictionary}（完整 stone，2026-06-11 修订）
- `pickup_dropped(data: Dictionary)` — {pickup_id, position, display_name}
- `pickup_activated(data: Dictionary)` — {pickup_id}
- `run_ended(data: Dictionary)` — FROZEN 契约见 spec FR-016：{outcome, run_id, floor_index, stats:{total_turns, total_kills, reaction_kills, near_death_count, survival_low_length_ticks, floors_completed, max_reaction_chain, damage_taken, max_length, duration_ticks}}