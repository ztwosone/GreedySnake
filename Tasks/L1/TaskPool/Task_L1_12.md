## [L1-T12] StatusEffect 数据模型与管理器

### 元信息

| 字段 | 值 |
|------|-----|
| **阶段** | L1-Combat |
| **优先级** | P0(阻塞) |
| **前置任务** | L0 全部, L1-T12a |
| **预估粒度** | L(3~6h) |
| **分配职能** | 引擎程序 |

### 概述

创建状态效果的核心数据模型和管理器，为火/冰/毒三种状态的具体实现提供统一的基础框架。这是 L1 状态效果系统的根基。

### 上下文

| 文档 | 章节/位置 |
|------|----------|
| `Designs/General/snake_roguelite_design.md` | §4.1~4.3 状态效果系统 |
| `Designs/General/snake_roguelite_design.md` | §4.4 六种基础状态 |
| `Project/data/json/game_config.json` | `status_effects` 配置区段 |
| `Project/autoloads/config_manager.gd` | `get_status_effect()` API |

### 任务详细

1. 创建 `Project/core/status_effect_data.gd` — StatusEffect 数据类（Resource 或 RefCounted）
2. 创建 `Project/systems/status/status_effect_manager.gd` — 全局管理器
3. 在 `EventBus` 中添加状态效果相关信号
4. 在 `project.godot` 中将 StatusEffectManager 注册为 Autoload（在 GridWorld 之后）
5. 编写测试 `Project/Test/cases/test_t12_status_effect.gd`

**StatusEffect 数据类字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `type` | `String` | 状态类型 ID（"fire"/"ice"/"poison"） |
| `layer` | `int` | 当前层数（≥1） |
| `max_layers` | `int` | 最大层数（从 ConfigManager 读取） |
| `carrier` | `Object` | 载体引用（蛇段/敌人/StatusTile） |
| `carrier_type` | `String` | "entity" 或 "spatial" |
| `duration` | `float` | 剩余持续时间（秒） |
| `source` | `String` | 来源描述 |
| `elapsed` | `float` | 已经过时间 |

**StatusEffectManager 核心方法：**

| 方法 | 说明 |
|------|------|
| `apply_status(target, type, source) -> StatusEffect` | 给目标施加状态（已有则叠层） |
| `remove_status(target, type)` | 移除目标上的指定状态 |
| `remove_all_statuses(target)` | 移除目标上的全部状态 |
| `get_statuses(target) -> Array` | 获取目标身上的所有状态 |
| `get_status(target, type) -> StatusEffect` | 获取目标身上的指定状态（null 表示无） |
| `has_status(target, type) -> bool` | 目标是否有指定状态 |
| `tick_update(delta: float)` | 每帧更新所有状态的计时，处理过期 |

**叠层规则：**
- 同类状态施加给已有该状态的目标时，`layer += 1`（不超过 `max_layers`）
- 叠层时刷新 `duration` 为该状态的完整持续时间
- `layer` 达到 `max_layers` 后继续施加只刷新时间，不增加层数

**需要创建的目录：**
- `Project/systems/status/`

**需要创建的文件：**
- `Project/core/status_effect_data.gd`
- `Project/systems/status/status_effect_manager.gd`

**需要修改的文件：**
- `Project/autoloads/event_bus.gd` — 添加状态信号
- `Project/project.godot` — 添加 StatusEffectManager Autoload

### EventBus 新增信号

```gdscript
# === Status Effects ===
signal status_applied(data: Dictionary)        # { target, type, layer, source }
signal status_removed(data: Dictionary)        # { target, type, source }
signal status_layer_changed(data: Dictionary)  # { target, type, old_layer, new_layer }
signal status_expired(data: Dictionary)        # { target, type }
```

### 技术约束

- StatusEffect 数据类使用 `RefCounted`（不需要加入场景树）
- StatusEffectManager 使用 `Node`（extends Node）作为 Autoload
- 所有数值参数（duration、max_layers 等）从 `ConfigManager.get_status_effect(type)` 读取，不硬编码
- `tick_update()` 连接到 `_process(delta)` 或 TickManager，每帧/每 tick 调用
- 状态管理器内部使用 `Dictionary[Object, Dictionary[String, StatusEffect]]` 结构存储
- 必须正确处理载体被销毁的情况（WeakRef 或连接 `tree_exiting` 信号清理）

### 验收标准

- [ ] `status_effect_data.gd` 存在且包含所有列出的字段
- [ ] `status_effect_manager.gd` 存在且已注册为 Autoload
- [ ] `apply_status` 能正确施加新状态并发射 `status_applied` 信号
- [ ] 对已有状态再次 `apply_status` 能正确叠层并发射 `status_layer_changed`
- [ ] 叠层不超过 `max_layers`
- [ ] 状态持续时间到期后自动移除并发射 `status_expired`
- [ ] `remove_status` 能手动移除状态并发射 `status_removed`
- [ ] 载体被销毁时，其身上的状态自动清理
- [ ] 所有测试通过

### 备注

- 本任务只建立框架，不实现具体状态类型的效果逻辑（火烧伤、冰减速等在 T15~T17 中实现）
- StatusEffectManager 的 `tick_update` 在 MVP 中用 `_process(delta)` 驱动即可，后续可改为 TickManager 驱动
- 设计文档中有 6 种状态（火/冰/毒/酸/电/虚），L1 阶段只实现前 3 种，但框架要支持扩展
