# 事实摘要 — 当前实现状态速查

> 本文件是设计文档的精简索引。修改设计文档或代码后必须同步更新。
> 完整设计见 `Designs/General/snake_roguelite_design.md` 和 `TechDocs/ScriptingLeading.md`。

## 项目概述

Godot 4.6 + GDScript 贪吃蛇 Roguelite。Grid-based、Tick-driven、Event-driven、Data-driven。

## 里程碑进度

| 里程碑 | 内容 | 状态 |
|--------|------|------|
| L0 | 基础移动 + 长度 + 食物 | ✅ 完成 |
| L1 | 战斗循环 + per-segment status + T25 Atom System | ✅ 完成（1030 测试） |
| L2 | 蛇头/蛇尾/蛇鳞统一 Atom Chain | 🟡 设计完成，待实现 |
| L3+ | 地图 PCG / 成长 / 元成长 | 🔮 待设计 |

## 核心配置

```
Project/data/json/game_config.json    # 核心配置（grid/tick/snake/food/enemy/status/reactions）
Project/autoloads/event_bus.gd        # 全局事件定义
Project/systems/atoms/atom_registry.gd # T25 原子注册表（49 原子，17 触发器）
```

- CELL_SIZE = 32，网格 40×22
- Tick = 0.25s
- 测试入口：`res://Test/test_runner.tscn`

## L1 战斗循环关键事实

- **吃敌人无消耗** — 蛇头碰敌人 = 直接吞噬，不扣长度；若蛇头与敌人携带异类状态则触发反应、双方状态清除
- **所有击杀方式均掉食物** — 蛇头吞噬、火光环、反应伤害
- **Per-Segment Status** — 每个 SnakeSegment 独立携带 `carried_status: String`（fire/ice/poison/""）
- **段对象持久化** — 蛇移动时所有段对象向前移动一格（不创建/销毁），状态自然跟随段走
- **敌人攻击蛇身** — 敌人 P0 优先级，累计 3 次命中丢 1 段（hits_per_segment_loss=3）
- **双向状态转移** — 敌人攻击蛇段时双方状态互换/触发反应
- **敌人携带状态颜色** — 敌人携带 fire/ice/poison 时显示对应叠层颜色（fire=橙边框闪烁+overlay, ice=蓝overlay, poison=绿脉动overlay）
- **状态格永久存在** — L1 中无持续时间递减
- **同位异类互斥** — 放置状态格时已有不同类型 → 反应 + 双方消除
- **蛇基础颜色白/灰** — HEAD=0.95, BODY=0.78, TAIL=0.6 灰度
- **碾压（crush）已移除** — 蛇身段不再主动攻击敌人

## L2 架构决策

- **统一 Atom Chain** — 蛇头/蛇尾/蛇鳞三套系统统一使用 T25 Effect Atom System
- 复用 EffectChainResolver → TriggerManager → AtomExecutor 管线
- 新增 ~6 个原子：modify_food_drop, direct_grow, steal_status, modify_hit_threshold, delay_loss, grant_invincibility
- 蛇鳞效果也走 Atom Chain，不再有独立的 Condition/Action 系统

## 敌人类型（L1）

| 类型 | 行为 | 攻击冷却 | 掉落食物 |
|------|------|----------|----------|
| wanderer | 随机移动，无视状态格 | 3 ticks | 2 |
| chaser | 追踪蛇身段，回避状态格 | 2 ticks | 3 |
| bog_crawler | 趋向毒液格，死亡留毒 | 4 ticks | 4 |

## 状态效果（L1，仅 fire/ice/poison）

| 状态 | 蛇段效果 | 状态格效果 |
|------|----------|-----------|
| fire | 火光环：相邻格敌人受火属性伤害（异类状态触发反应） | 踩入获火，蔓延 |
| poison | 毒蔓延：每个毒段每 3 tick 向随机邻格蔓延一格毒 | 踩入获毒 |
| ice | 冰防御：被攻击时攻击者获冰 | 踩入获冰 |

## 反应（L1，仅 3 种）

| 反应 | 组合 | 敌伤 | 蛇自伤 |
|------|------|------|--------|
| steam | fire+ice | 2 | 1 hit |
| toxic_explosion | fire+poison | 3 | 2 hits |
| frozen_plague | ice+poison | 0 | 0 |
