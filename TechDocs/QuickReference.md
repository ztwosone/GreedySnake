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
| L2-Phase0 | T27A StatusCarrier + ReactionResolver + CollisionHandler | ✅ 完成（1082 测试） |
| L2 | 蛇头/蛇尾/蛇鳞统一 Atom Chain | ✅ 完成 T27A~T33（1518 测试） |
| L3+ | 地图 PCG / 成长 / 元成长 | 🔮 待设计 |

## 核心配置

```
Project/data/json/game_config.json    # 核心配置（grid/tick/snake/food/enemy/status/reactions）
Project/autoloads/event_bus.gd        # 全局事件定义
Project/systems/atoms/atom_registry.gd # T25 原子注册表（68 原子，24 触发器）
Project/ui/build_test_panel.gd        # T33 Build 测试面板（B 键切换）
Project/systems/status/reaction_resolver.gd  # T27A 反应查表引擎
Project/systems/status/collision_handler.gd  # T27A 碰撞统一处理器
```

- CELL_SIZE = 32，网格 40×22
- Tick = 0.25s
- 测试入口：`res://Test/test_runner.tscn`

## L1 战斗循环关键事实

- **吃敌人无消耗** — 蛇头碰敌人 = 直接吞噬，不扣长度；若蛇头与敌人携带异类状态则触发反应、双方状态清除
- **所有击杀方式均掉食物** — 蛇头吞噬、火光环、反应伤害
- **Per-Segment Status** — 每个 SnakeSegment 实现 StatusCarrier 接口，持有 `_statuses: Array[String]`（兼容 `carried_status` getter）
- **段对象持久化** — 蛇移动时所有段对象向前移动一格（不创建/销毁），状态自然跟随段走
- **敌人攻击蛇身** — 敌人 P0 优先级，累计 3 次命中丢 1 段（hits_per_segment_loss=3）
- **双向状态转移** — 敌人攻击蛇段时双方状态互换/触发反应
- **敌人携带状态颜色** — 敌人携带 fire/ice/poison 时显示对应叠层颜色（fire=橙边框闪烁+overlay, ice=蓝overlay, poison=绿脉动overlay）
- **状态格永久存在** — L1 中无持续时间递减
- **同位异类互斥** — 放置状态格时已有不同类型 → 反应 + 双方消除
- **蛇基础颜色白/灰** — HEAD=0.95, BODY=0.78, TAIL=0.6 灰度
- **碾压（crush）已移除** — 蛇身段不再主动攻击敌人

## L2 架构决策

- **StatusCarrier 统一载体 + ReactionResolver 反应引擎（T27A）** ✅ 已实现
  - 蛇段/敌人/状态格统一实现 StatusCarrier 接口（`_statuses: Array[String]` + 兼容 getter）
  - CollisionHandler 统一处理 5 种碰撞类型，JSON `collision_rules` 驱动
  - ReactionResolver JSON 驱动反应规则（替代 3 处 `_get_reaction_id`）
  - `game_config.json` 新增 `collision_rules` 节
  - EventBus 新增 `status_added_to_carrier` / `status_removed_from_carrier` 信号
- **统一 Atom Chain** — 蛇头/蛇尾/蛇鳞三套系统统一使用 T25 Effect Atom System
- 复用 EffectChainResolver → TriggerManager → AtomExecutor 管线
- **EffectWindow 时间窗口框架（T27）** ✅ 已实现 — 为 Atom System 新增"持续 N tick"能力
  - 新增 EffectWindowManager（有状态管理器）+ open_window / if_in_window 原子
  - 窗口期内规则覆写（ignore_hit_counter / block_segment_loss 等）由各系统主动查询
  - 到期执行 on_expire 原子链，cancel_on 条件取消不触发到期链
  - 完全 JSON 配置，零代码扩展；新增 3 个 EventBus 信号
- **新增触发器 7 个（T28A）** ✅ 已实现 — 补全操作维度和资源维度
  - 高：on_length_change（长度增减）、on_turn（转弯）、on_near_death（濒死）
  - 中：on_streak（连杀）、on_enemy_approach（敌人靠近）、on_status_gained（获得状态）、on_tile_placed（状态格放置）
- **新增即时原子 4 个（T28B）** ✅ 已实现：modify_food_drop, direct_grow, steal_status, modify_hit_threshold；Snake.request_grow() 新增
- **SnakePartsManager + 蛇头链（T29）** ✅ 已实现
  - SnakePartsManager 管理蛇头装备/卸载，SnakePartData 兼容 TriggerManager duck typing
  - Hydra（九头蛇）：受击阈值-1、不掉食物、直接增长、窃取状态、L3回声咬
  - Bái Shé（白蛇）：击杀开无敌窗口、L2+反击冰冻、L3到期爆发状态
  - 新增 area_damage + burst_carried_status 原子（总数 57）
  - StatusEffectManager 持久修改器：hit_threshold / food_drop
  - Snake.take_hit() 集成无敌窗口查询
  - ConfigManager 新增 snake_heads 段 + get_snake_head()
- **蛇尾链（T30）** ✅ 已实现
  - Salamander（火蜥蜴尾）：段丢失后恢复窗口，L2+恢复时尾段获火，L3回复量+1
  - Lag Tail（滞后尾）：block_segment_loss 窗口 → 延迟段丢失，L2取消时减 hits_taken，L3蛇尾获冰
  - 新增 request_segment_loss + modify_hits_taken + cancel_window 原子（总数 60）
  - EffectWindow 新增 on_cancel 链：窗口被信号取消时执行
  - LengthSystem 集成 block_segment_loss 窗口规则查询
  - ConfigManager 新增 snake_tails 段 + get_snake_tail()
- **ScaleSystem 蛇鳞槽位（T31）** ✅ 已实现
  - ScaleSlotManager 管理 front/middle/back 三位置（最大 2/3/2 槽，初始 1/1/1）
  - 9 鳞片 × 3 级，全 JSON + Atom Chain 驱动
  - 前段：greedy_scale（食物掉落）、predator_scale（窃取+扩散状态）
  - 中段：flame_scale（火光环增强）、toxin_scale（毒蔓延加速）、frost_scale（攻击冷却）、phantom_scale（幻影尾段）
  - 后段：thorn_scale（击退）、regen_scale（概率增长）、retaliation_scale（反伤）
  - 新增 6 原子（总数 66）：modify_system_param, damage_attacker, knockback_attacker, knockback_with_damage, spread_status_to_segments, ice_wave
  - StatusEffectManager 新增 6 修改器：fire_aura_damage/range, poison_spread_bonus/tile_damage, attack_cooldown_bonus, phantom_tail_count
  - SegmentEffectSystem：曼哈顿距离火光环 + 毒格伤害
  - EnemyBrain：幻影尾段过滤
- 蛇鳞效果也走 Atom Chain，不再有独立的 Condition/Action 系统
- **邻接共鸣系统（T32）** ✅ 已实现
  - Tag-pair 驱动 + scale-pair override 混合架构
  - ResonanceManager 监听鳞片装备/卸载，自动计算邻接共鸣
  - 位置级邻接：front↔middle、middle↔back、同位置互邻；front↔back 不邻接
  - 11 个 tag-pair 共鸣：沸毒(fire+poison)、蒸腾(fire+ice)、冻疫(ice+poison)、炎棘(fire+physical)、冰刺(ice+physical)、毒棘(poison+physical)、幽焰(fire+void)、毒影(poison+void)、焚食(fire+recovery)、寒餐(ice+recovery)、铁壁(physical+physical)
  - 同 tag 不共鸣（physical 除外，铁壁）；多 tag 鳞片可触发多个共鸣
  - 新增 2 原子（总数 68）：apply_status_in_radius, place_tile_at_attacker
  - ConfigManager 新增 tag_resonances + scale_resonance_overrides 双向查找
  - EventBus 新增 resonance_activated / resonance_deactivated 信号
  - 发现机制：首次激活 is_new_discovery=true（预留 UI 提示）
- **全系统联调 + Build 测试面板（T33）** ✅ 已实现
  - Build 测试面板（B 键）：实时显示头/尾/鳞/共鸣/修改器/窗口状态
  - 热键装备：H=蛇头, J=蛇尾, F/G/K=前/中/后鳞, L=升级, 0=清空
  - game_world.cleanup()：修复重开游戏时 TriggerManager/修改器/窗口泄漏
  - main.gd：queue_free 前调用 cleanup 确保跨系统状态清理
  - 集成测试：修改器叠加、共鸣联动、清理正确性、配置一致性

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
| steam | fire+ice | 2 | 1 格 |
| toxic_explosion | fire+poison | 3 | 2 格 |
| frozen_plague | ice+poison | 0 | 0 |
