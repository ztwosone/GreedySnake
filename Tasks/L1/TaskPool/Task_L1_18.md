## [L1-T18] 状态反应系统 + 蒸腾/毒爆

### 元信息

| 字段 | 值 |
|------|-----|
| **阶段** | L1-Combat |
| **优先级** | P1(核心) |
| **前置任务** | L1-T15, L1-T16, L1-T17 |
| **预估粒度** | L(3~6h) |
| **分配职能** | Gameplay 程序 |

### 概述

实现状态反应检测框架，以及两种核心反应：蒸腾（火+冰）和毒爆（火+毒）。当同一实体/相邻格存在两种不同状态时触发反应。

### 上下文

| 文档 | 章节/位置 |
|------|----------|
| `Designs/General/snake_roguelite_design.md` | §4.5 状态反应系统 |
| `Project/data/json/game_config.json` | `reactions` 配置区段 |
| `Project/autoloads/config_manager.gd` | `find_reaction()` API |

### 任务详细

1. 创建 `Project/systems/status/reaction_system.gd` — 反应检测与执行系统
2. 创建 `Project/systems/status/reactions/steam_reaction.gd` — 蒸腾反应
3. 创建 `Project/systems/status/reactions/toxic_explosion_reaction.gd` — 毒爆反应
4. 在 EventBus 中添加反应相关信号
5. 监听 `status_applied` 和 `status_tile_placed` 信号进行反应检测
6. 编写测试 `Project/Test/cases/test_t18_reactions.gd`

**反应检测规则（3 种触发条件）：**

```
1. 同一实体身上存在两种不同状态 → 触发反应
   检测时机：status_applied 时检查目标是否已有其他类型状态

2. 地板上两种不同 StatusTile 相邻 → 触发反应
   检测时机：status_tile_placed 时检查相邻格是否有不同类型 StatusTile

3. 带状态的实体进入不同类型的 StatusTile → 触发反应
   检测时机：entity_entered_status_tile 时检查实体是否带有不同类型状态
```

**反应伤害公式：**
```
反应伤害 = (状态A层数 + 状态B层数) × 伤害系数
```

**蒸腾反应（火+冰）：**

| 参数 | 值（从 config 读取） | 说明 |
|------|---------------------|------|
| `damage_coefficient` | 0.5 | 伤害系数 |
| `radius` | 3 格 | 蒸汽云范围 |
| `cloud_duration` | 5.0 秒 | 蒸汽云持续时间 |

- 触发位置周围 `radius` 格生成"蒸汽云"标记
- 蒸汽云内的实体视野归零（L1 阶段简化：不实现视野系统，仅造成伤害）
- L1 简化效果：消耗参与反应的两种状态，对触发位置周围实体造成 `(layerA + layerB) * 0.5` 格伤害

**毒爆反应（火+毒）：**

| 参数 | 值（从 config 读取） | 说明 |
|------|---------------------|------|
| `damage_coefficient` | 1.0 | 伤害系数 |
| `radius` | 3 格 | 爆炸范围 |
| `apply_burn_layers` | 2 | 附加灼烧层数 |
| `apply_poison_layers` | 1 | 附加中毒层数 |

- 范围 `radius` 格内所有实体附加灼烧 × `apply_burn_layers` + 中毒 × `apply_poison_layers`
- 造成 `(layerA + layerB) * 1.0` 格伤害
- 消耗参与反应的两种状态

**ReactionSystem 核心方法：**

| 方法 | 说明 |
|------|------|
| `_check_entity_reaction(target, new_type)` | 检查实体是否触发反应 |
| `_check_spatial_reaction(pos, new_type)` | 检查空间是否触发反应 |
| `_execute_reaction(reaction_def, pos, layer_a, layer_b)` | 执行反应 |
| `_get_entities_in_radius(pos, radius) -> Array` | 获取范围内实体 |

**需要创建的目录：**
- `Project/systems/status/reactions/`

**需要创建的文件：**
- `Project/systems/status/reaction_system.gd`
- `Project/systems/status/reactions/steam_reaction.gd`
- `Project/systems/status/reactions/toxic_explosion_reaction.gd`

**需要修改的文件：**
- `Project/autoloads/event_bus.gd` — 添加反应信号
- `Project/scenes/game_world.tscn` — 添加 ReactionSystem 节点

### EventBus 新增信号

```gdscript
# === Reactions ===
signal reaction_triggered(data: Dictionary)  # { reaction_id, position, type_a, type_b, layer_a, layer_b, damage }
```

### 技术约束

- 反应查找使用 `ConfigManager.find_reaction(type_a, type_b)`，支持双向匹配
- 反应触发后必须消耗参与反应的两种状态（从实体/StatusTile 上移除）
- 同一 tick 内不应连锁触发反应（反应产生的状态不在本 tick 内再次触发反应检查）
- 反应伤害通过 `length_decrease_requested` 信号请求
- 范围效果需要正确处理 GridWorld 边界
- 反应处理器应是可注册/可扩展的（未来添加新反应只需注册新处理器）

### 验收标准

- [ ] 实体同时拥有火和冰状态时触发蒸腾反应
- [ ] 火焰格相邻冰霜格时触发蒸腾反应
- [ ] 带灼烧的实体踩入冰霜格时触发蒸腾反应
- [ ] 蒸腾反应消耗参与的两种状态
- [ ] 蒸腾反应对范围内实体造成正确伤害
- [ ] 实体同时拥有火和毒状态时触发毒爆反应
- [ ] 毒爆反应对范围内实体附加灼烧和中毒
- [ ] 反应触发发射 `reaction_triggered` 信号
- [ ] 反应不会在同一 tick 内连锁触发
- [ ] 所有测试通过

### 备注

- 设计文档有 21 种反应组合（6×6 矩阵），L1 只实现 2 种（蒸腾/毒爆），但框架要支持扩展
- 蒸汽云的"视野归零"效果在 L1 简化为纯伤害——视野系统是后续 L2+ 的内容
- 反应是状态系统的"终极花活"，需要三个状态类型都稳定后才能实现
