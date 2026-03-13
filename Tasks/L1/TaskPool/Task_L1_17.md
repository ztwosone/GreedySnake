## [L1-T17] 中毒状态实现

### 元信息

| 字段 | 值 |
|------|-----|
| **阶段** | L1-Combat |
| **优先级** | P1(核心) |
| **前置任务** | L1-T12, L1-T13, L1-T14 |
| **预估粒度** | M(1~3h) |
| **分配职能** | Gameplay 程序 |

### 概述

实现中毒状态效果的完整逻辑，包括实体效果（食物增长量减半 + 毒化）、空间效果（毒液格阻止食物生成）和转化规则（每 3 格留 1 格毒液）。

### 上下文

| 文档 | 章节/位置 |
|------|----------|
| `Designs/General/snake_roguelite_design.md` | §4.4 中毒 [毒] |
| `Project/data/json/game_config.json` | `status_effects.poison` |

### 任务详细

1. 创建 `Project/systems/status/effects/poison_effect.gd` — 中毒效果处理器
2. 在 StatusEffectManager 中注册中毒效果的 tick 处理逻辑
3. 实现食物增长量减半逻辑（拦截 `length_grow_requested` 信号）
4. 实现毒化逻辑（3 层时临时减少长度上限）
5. 实现毒液留痕（每 3 格移动留下 1 格毒液格）
6. 编写测试 `Project/Test/cases/test_t17_poison.gd`

**中毒 — 实体效果：**

| 参数 | 值（从 config 读取） | 说明 |
|------|---------------------|------|
| `food_growth_modifier` | 0.5 | 食物增长量变为 50% |
| `entity_duration` | 8.0 秒 | 中毒持续时间 |
| `toxify_at_layer` | 3 | 达到此层数时触发毒化 |
| `toxify_length_penalty` | 3 | 毒化时临时减少的长度 |
| `max_layers` | 3 | 最大 3 层 |

- 中毒时吃食物的增长量减半（+1 变为 +0，+2 变为 +1，向下取整）
- 叠加 3 层触发毒化：立即减少 `toxify_length_penalty` 格长度，然后清除所有毒层
- 敌人中毒：移动时留下毒液格轨迹

**中毒 — 空间效果（毒液格）：**

| 参数 | 值（从 config 读取） | 说明 |
|------|---------------------|------|
| `tile_duration` | 10.0 秒 | 毒液格持续时间 |
| `trail_interval` | 3 | 每移动 N 格留 1 格毒液 |
| `color` | "#006400" | 深绿色 |

- 毒液格不蔓延
- 毒液格上不能生成新食物（FoodManager 需检查）
- 踩入毒液格的实体获得中毒状态

**中毒 — 实体→空间转化：**
- 中毒的实体每移动 `trail_interval` 格，在经过的格子留下 1 格毒液格
- 需要为每个中毒实体维护一个移动计数器

**视觉：**
- 实体中毒：该段显示深绿色叠加
- 毒液格：深绿色半透明 ColorRect

**需要创建的文件：**
- `Project/systems/status/effects/poison_effect.gd`

**需要修改的文件：**
- `Project/systems/status/status_effect_manager.gd` — 注册中毒效果处理器
- `Project/systems/status/status_transfer_system.gd` — 添加中毒转化条件（每 3 格）
- `Project/systems/length/length_system.gd` — 支持增长量修正（food_growth_modifier）
- `Project/scenes/food_manager.gd`（或等效文件） — 检查毒液格上不生成食物

### 技术约束

- 食物增长量减半通过拦截/修改 `length_grow_requested` 信号的 `amount` 实现
- 毒化触发（3 层）后应立即清除毒层并发射 `length_decrease_requested`
- 毒液留痕计数器需要绑定到具体实体实例，实体死亡时清理
- FoodManager 的随机位置选择需排除有毒液格的位置
- 所有数值从 ConfigManager 读取

### 验收标准

- [ ] 蛇中毒后，吃食物增长量减半（+1 → +0）
- [ ] 中毒叠到 3 层时触发毒化，立即扣除 3 格长度
- [ ] 毒化触发后毒层清零
- [ ] 中毒 8 秒后自动消失
- [ ] 毒液格持续 10 秒后消失
- [ ] 蛇踩入毒液格获得中毒状态
- [ ] 中毒的蛇每 3 格移动留下 1 格毒液格
- [ ] 毒液格上不会生成新食物
- [ ] 毒液格视觉为深绿色半透明
- [ ] 所有测试通过

### 备注

- 中毒是唯一不直接扣血的状态——它通过减少食物增长来间接削弱玩家
- 毒化（3 层爆发）是高风险惩罚机制，给玩家"及时清除毒层"的紧迫感
- 设计文档的"长度上限临时 -3"在 L1 简化为"直接扣 3 格长度"（因为 L0 没有长度上限系统）
