## [L1-T19] 敌人 AI 行为框架

### 元信息

| 字段 | 值 |
|------|-----|
| **阶段** | L1-Combat |
| **优先级** | P0(阻塞) |
| **前置任务** | L0 全部 |
| **预估粒度** | L(3~6h) |
| **分配职能** | 引擎程序 |

### 概述

创建敌人 AI 行为框架，包括行为优先级栈、状态响应类型系统和寻路辅助。为游荡者/追踪者/毒沼匍匐者提供统一的行为基础。

### 上下文

| 文档 | 章节/位置 |
|------|----------|
| `Designs/General/snake_roguelite_design.md` | §7.1~7.3 敌人系统 |
| `Designs/General/snake_roguelite_design.md` | §7.4 敌人分级设计 |
| `Project/data/json/game_config.json` | `enemy_types` 配置区段 |
| `Project/entities/enemies/enemy.gd` | 当前 L0 敌人实现 |

### 任务详细

1. 创建 `Project/entities/enemies/enemy_brain.gd` — AI 行为基类
2. 重构 `Project/entities/enemies/enemy.gd` — 集成 EnemyBrain，支持类型化
3. 创建 `Project/core/helpers/pathfinding.gd` — 寻路辅助工具
4. 扩展 EnemyManager 支持多种敌人类型
5. 在 EventBus 中添加敌人 AI 相关信号
6. 编写测试 `Project/Test/cases/test_t19_enemy_ai.gd`

**行为优先级栈（每 tick 按顺序检查，第一个命中的行为执行）：**

```
P1  自我保护 → 当前格是危险状态格？→ 移离
P2  威胁响应 → 蛇头在攻击范围内？→ 进入攻击逻辑
P3  状态响应 → 战场上有状态格？→ 按本敌人的响应类型决策
P4  目标追踪 → 向主要目标移动
P5  默认行为 → 无条件触发的兜底行为
```

**EnemyBrain 基类设计：**

```gdscript
class_name EnemyBrain extends RefCounted

# 子类覆写这些方法来定义行为
func evaluate_self_preservation(enemy, context) -> Dictionary  # 返回 { action, direction } 或 {}
func evaluate_threat_response(enemy, context) -> Dictionary
func evaluate_status_response(enemy, context) -> Dictionary
func evaluate_tracking(enemy, context) -> Dictionary
func evaluate_default(enemy, context) -> Dictionary

# 主决策方法（按优先级依次调用上述方法）
func decide(enemy, context) -> Dictionary
```

**状态响应类型枚举：**

| 类型 | 行为 | 对应值 |
|------|------|--------|
| `ignore` | 完全忽略状态格 | 从 config `status_response` 读取 |
| `avoid` | 计算避开状态格的路径 | |
| `attract` | 主动向特定类型状态格移动 | |
| `exploit` | 经过特定状态格以获得有利状态 | |
| `fear` | 特定状态格使其停止移动 | |

**Enemy 重构：**
- 添加 `enemy_type: String` 字段（"wanderer"/"chaser"/"bog_crawler"）
- 添加 `brain: EnemyBrain` 引用
- 添加 `hp: int` 字段（从 config 读取）
- 在 tick_post_process 时调用 `brain.decide()` 执行移动
- 视觉颜色从 config `color` 字段读取

**寻路辅助（pathfinding.gd）：**

| 方法 | 说明 |
|------|------|
| `manhattan_distance(a, b) -> int` | Manhattan 距离 |
| `get_direction_towards(from, to) -> Vector2i` | 向目标的最优方向 |
| `get_direction_away(from, threat) -> Vector2i` | 远离威胁的方向 |
| `get_valid_moves(pos) -> Array[Vector2i]` | 获取合法移动方向（不越界、不撞墙） |
| `get_nearest_tile_of_type(pos, type) -> Vector2i` | 找到最近的指定类型状态格 |

**需要创建的文件：**
- `Project/entities/enemies/enemy_brain.gd`
- `Project/core/helpers/pathfinding.gd`

**需要修改的文件：**
- `Project/entities/enemies/enemy.gd` — 添加类型化和 brain 集成
- `Project/entities/enemies/enemy_manager.gd` — 支持多类型生成
- `Project/autoloads/event_bus.gd` — 添加 AI 相关信号

### EventBus 新增信号

```gdscript
# === Enemy AI ===
signal enemy_action_decided(data: Dictionary)  # { enemy, action, direction }
```

### 技术约束

- EnemyBrain 使用 `RefCounted`（不加入场景树），由 Enemy 实例持有
- 敌人每 tick 只执行一次决策（tick_post_process 阶段）
- 敌人类型参数全部从 `ConfigManager.get_enemy_type(type_id)` 读取
- 寻路辅助不实现完整 A*（L1 只需 Manhattan + 简单方向选择），但接口预留扩展
- 重构 Enemy 时不能破坏现有 L0 测试（L0 敌人变为 "wanderer" 类型的静止变体）
- 敌人移动需要正确更新 GridWorld 占位

### 验收标准

- [ ] `enemy_brain.gd` 存在，包含完整的行为优先级栈
- [ ] `pathfinding.gd` 存在，Manhattan 距离和方向计算正确
- [ ] Enemy 支持 `enemy_type` 字段和对应的 brain
- [ ] EnemyManager 支持按类型生成不同敌人
- [ ] 敌人颜色从 config 读取
- [ ] 敌人在 tick_post_process 时调用 brain 进行决策
- [ ] 现有 L0 测试仍然全部通过（向后兼容）
- [ ] 所有新测试通过

### 备注

- 本任务只建立框架，具体的 Wanderer/Chaser/BogCrawler 行为在 T20~T22 中实现
- L0 的敌人是静止的，T19 重构后敌人默认仍然静止（P5 默认行为 = 不移动），直到 T20 实现随机移动
- EnemyBrain 的 `context` 参数应包含：蛇位置、周围状态格、周围敌人等战场信息
