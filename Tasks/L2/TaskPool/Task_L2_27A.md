## [L2-T27A] StatusCarrier 统一载体 + ReactionResolver 反应规则引擎

### 元信息

| 字段 | 值 |
|------|-----|
| **阶段** | L2-Phase 0（基础设施） |
| **优先级** | P0(前置) |
| **前置任务** | T25 (Atom System) |
| **预估粒度** | L(3~6h) |
| **分配职能** | 系统程序 |

### 概述

统一蛇段/敌人/状态格的状态数据模型和交互规则。当前 5 处硬编码的碰撞逻辑 + 3 处重复的反应查表，重构为 1 个通用 StatusCarrier 接口 + 1 个 JSON 驱动的 ReactionResolver。

### 设计动机

当前问题：
1. 蛇段/敌人用 `carried_status: String`（单值），状态格用 `status_type + layer`，三种不同数据模型
2. "异类碰撞→反应+清除" 规则在 5 个文件中重复实现，行为有微妙差异
3. `_get_reaction_id()` 硬编码在 3 个文件中
4. 状态格 layer 有数据但 L1 无游戏性逻辑
5. 载体只能持有单状态，无法支持多状态共存和条件反应

### 三层架构

```
数据层：StatusCarrier（纯存储）
    蛇段/敌人/状态格统一实现此接口
    每个载体持有 statuses: Array[String]（每种类型最多一个，无叠层）
    ↓
规则层：ReactionResolver（JSON 驱动）
    监听事件 → 检查载体上的状态组合 → 按规则决定是否触发反应
    反应时机可配置（immediate / stable / on_trigger）
    ↓
执行层：Atom Chain（已有 T25）
    反应具体效果由 game_config.json 中的反应链执行
```

### StatusCarrier 接口

```gdscript
## 所有状态载体实现此接口（蛇段、敌人、状态格）
## 不使用 class 继承，而是 duck typing（has_method 检查）

func get_statuses() -> Array[String]
    # 返回当前所有状态，如 ["fire", "poison"]

func has_status(type: String) -> bool

func add_status(type: String) -> bool
    # 添加成功返回 true，已存在返回 false
    # 不判断反应，纯数据操作

func remove_status(type: String) -> void

func clear_all_statuses() -> void

func get_carrier_type() -> String
    # "snake_segment" / "enemy" / "status_tile"
```

### 载体改造

| 载体 | 当前 | 改为 |
|------|------|------|
| SnakeSegment | `carried_status: String` | `_statuses: Array[String]`，实现 StatusCarrier 接口 |
| Enemy | `carried_status: String` | `_statuses: Array[String]`，实现 StatusCarrier 接口 |
| StatusTile | `status_type: String` + `layer: int` | `_statuses: Array[String]`，移除 layer |

向后兼容：保留 `carried_status` 属性作为只读 getter，返回 `_statuses[0]` 或 ""，避免大面积改调用方。

### ReactionResolver

```gdscript
class_name ReactionResolver
extends Node

## JSON 驱动的反应规则引擎
## 监听事件 → 检查载体状态组合 → 触发反应

var _rules: Dictionary = {}  # 从 game_config.json 加载

func _ready() -> void:
    _load_rules()
    EventBus.status_added_to_carrier.connect(_on_status_added)
    EventBus.entity_entered_status_tile.connect(_on_entity_enter_tile)
    EventBus.snake_hit_enemy.connect(_on_head_hit)
    EventBus.enemy_attacked_segment.connect(_on_enemy_attack)
    # ...按需连接更多事件

func check_and_resolve(carrier: Object, trigger: String) -> void:
    var statuses: Array[String] = carrier.get_statuses()
    if statuses.size() < 2:
        return
    # 检查所有两两组合
    for i in range(statuses.size()):
        for j in range(i + 1, statuses.size()):
            var rule = _find_rule(statuses[i], statuses[j])
            if rule and trigger in rule["triggers"]:
                _execute_reaction(carrier, rule, statuses[i], statuses[j])
                return  # 一次只触发一个反应
```

### JSON 配置

```json
{
  "reaction_rules": {
    "steam": {
      "types": ["fire", "ice"],
      "triggers": ["on_status_added", "on_entity_enter"],
      "policy": "immediate",
      "clear_statuses": true,
      "reaction_chain": "steam"
    },
    "toxic_explosion": {
      "types": ["fire", "poison"],
      "triggers": ["on_status_added", "on_entity_enter"],
      "policy": "immediate",
      "clear_statuses": true,
      "reaction_chain": "toxic_explosion"
    },
    "frozen_plague": {
      "types": ["ice", "poison"],
      "triggers": ["on_status_added", "on_entity_enter"],
      "policy": "immediate",
      "clear_statuses": true,
      "reaction_chain": "frozen_plague"
    }
  }
}
```

**policy 说明：**
- `immediate`：status_added 事件时立即检查，有异类组合就反应（当前 L1 行为）
- `stable`：status_added 时不检查，等指定 trigger 才反应（多状态共存）
- 未来可扩展：`on_expire`（窗口到期时）、`on_manual`（玩家主动触发）

### 碰撞规则配置

两个载体相遇时的状态转移规则：

```json
{
  "collision_rules": {
    "segment_on_tile": {
      "empty_carrier": "transfer",
      "same_type": "ignore",
      "diff_type": "add_and_check"
    },
    "enemy_on_tile": {
      "empty_carrier": "transfer",
      "same_type": "ignore",
      "diff_type": "add_and_check"
    },
    "tile_on_tile": {
      "empty_carrier": "place",
      "same_type": "ignore",
      "diff_type": "add_and_check"
    },
    "head_eat_enemy": {
      "empty_carrier": "transfer",
      "same_type": "ignore",
      "diff_type": "add_and_check"
    },
    "enemy_hit_segment": {
      "empty_carrier": "transfer",
      "same_type": "swap",
      "diff_type": "add_and_check"
    }
  }
}
```

`add_and_check`：先把状态加到载体上，然后 ReactionResolver 根据 policy 决定是否立即反应。

### EventBus 新增/修改信号

```gdscript
# 新增：载体状态变化
signal status_added_to_carrier(data: Dictionary)
    # { carrier: Object, type: String, carrier_type: String }
signal status_removed_from_carrier(data: Dictionary)
    # { carrier: Object, type: String, carrier_type: String }

# 可选改名（语义更清晰）
signal enemy_attacked_segment(data: Dictionary)
    # 替代现有分散在 enemy.gd 中的攻击逻辑
```

### 删除/替代的代码

| 删除 | 替代 |
|------|------|
| `SnakeSegment.carried_status: String` | `_statuses: Array[String]` + StatusCarrier 接口 |
| `Enemy.carried_status: String` | 同上 |
| `StatusTile.layer: int` + `add_layer()` | 移除，同类型格子同位置忽略 |
| `StatusTileManager._get_reaction_id()` | ReactionResolver |
| `Enemy._get_reaction_id()` | ReactionResolver |
| `StatusTransferSystem._check_segment_tile()` 硬编码 | CollisionHandler + ReactionResolver |
| `StatusTransferSystem._try_spatial_to_entity()` 硬编码 | 同上 |
| `EnemyManager` 中的反应检查 | 同上 |
| `Enemy._attack_segment` 中的状态互换 | 同上 |

### 新增文件

| 文件 | 职责 |
|------|------|
| `systems/status/reaction_resolver.gd` | 反应规则引擎 |
| `systems/status/collision_handler.gd` | 载体碰撞统一处理器 |

### 修改文件

| 文件 | 改动 |
|------|------|
| `entities/snake/snake_segment.gd` | 实现 StatusCarrier 接口 |
| `entities/enemies/enemy.gd` | 实现 StatusCarrier 接口，删除 `_get_reaction_id` |
| `entities/status_tiles/status_tile.gd` | 实现 StatusCarrier 接口，移除 layer |
| `entities/status_tiles/status_tile_manager.gd` | 删除 `_get_reaction_id`，委托 CollisionHandler |
| `systems/status/status_transfer_system.gd` | 大幅简化，委托 CollisionHandler |
| `systems/enemy/enemy_manager.gd` | 删除反应检查，委托 CollisionHandler |
| `systems/combat/segment_effect_system.gd` | 适配新接口 |
| `data/json/game_config.json` | 新增 reaction_rules + collision_rules |
| `autoloads/event_bus.gd` | 新增信号 |
| `scenes/game_world.gd` | 实例化 ReactionResolver + CollisionHandler |

### 测试清单

- [ ] StatusCarrier: add_status / remove_status / has_status / get_statuses
- [ ] StatusCarrier: 同类型 add 两次 → 只存一个
- [ ] StatusCarrier: carried_status 兼容 getter 返回 _statuses[0]
- [ ] CollisionHandler: 段无状态踩格子 → 获得格子状态
- [ ] CollisionHandler: 段有状态踩同类格子 → 无视
- [ ] CollisionHandler: 段有状态踩异类格子 → add_and_check → immediate 反应
- [ ] CollisionHandler: 敌人踩格子 → 同逻辑
- [ ] CollisionHandler: 敌人打段 → swap 规则
- [ ] CollisionHandler: 格子放到异类格子 → add_and_check → 反应
- [ ] ReactionResolver: immediate policy → status_added 时立即反应
- [ ] ReactionResolver: stable policy → status_added 不反应，指定 trigger 才反应
- [ ] ReactionResolver: 反应后 clear_statuses=true → 双方状态清除
- [ ] ReactionResolver: JSON 新增反应规则 → 零代码生效
- [ ] 多状态共存：段携带 [fire, poison] stable → 不反应
- [ ] 多状态触发：段携带 [fire, poison] + on_attack 触发 → 反应
- [ ] 全部现有 L1 测试回归通过
