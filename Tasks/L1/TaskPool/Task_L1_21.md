## [L1-T21] 追踪者（Chaser）实现

### 元信息

| 字段 | 值 |
|------|-----|
| **阶段** | L1-Combat |
| **优先级** | P1(核心) |
| **前置任务** | L1-T19 |
| **预估粒度** | M(1~3h) |
| **分配职能** | Gameplay 程序 |

### 概述

实现追踪者敌人类型。追踪者每 tick 向蛇头移动 1 格，回避状态格，蛇头进入 3 格范围内时加速。

### 上下文

| 文档 | 章节/位置 |
|------|----------|
| `Designs/General/snake_roguelite_design.md` | §7.4 基础级：追踪者 Chaser |
| `Project/data/json/game_config.json` | `enemy_types.chaser` |

### 任务详细

1. 创建 `Project/entities/enemies/brains/chaser_brain.gd` — 追踪者 AI
2. 在 EnemyManager 中注册 chaser 类型与对应 brain
3. 编写测试 `Project/Test/cases/test_t21_chaser.gd`

**追踪者行为规则：**

```
状态响应：avoid（回避型）
P1 自保：当前格有危险状态格 → 向远离状态格的方向移动
P2 威胁：蛇头在 threat_range 内 → 移速 +threat_speed_bonus
P3 状态响应：计算避开所有状态格的路径
P4 追踪：每 tick 向蛇头当前位置移动 1 格（Manhattan 最近方向）
P5 默认：如果无法追踪（被堵住），随机移动
```

**追踪逻辑：**
- 使用 `pathfinding.get_direction_towards(enemy_pos, snake_head_pos)` 获取方向
- 如果最优方向被占据（蛇身/其他敌人），尝试次优方向
- 回避状态格：如果最优方向有状态格，尝试绕行（选择次优且无状态格的方向）

**威胁响应：**
- 当蛇头与追踪者的 Manhattan 距离 ≤ `threat_range` 时
- 该 tick 内追踪者额外移动 `threat_speed_bonus` 格（即总共移动 `speed + threat_speed_bonus` 格）
- 额外移动遵循相同的追踪逻辑

**从 config 读取的参数：**

| 参数 | 值 | 说明 |
|------|-----|------|
| `hp` | 1 | HP |
| `attack_cost` | 1 | 蛇头撞击消耗 |
| `speed` | 1 | 基础移速（格/tick） |
| `threat_range` | 3 | 威胁感知距离 |
| `threat_speed_bonus` | 1 | 威胁时额外移速 |
| `color` | "#FF3366" | 视觉颜色 |

**需要创建的文件：**
- `Project/entities/enemies/brains/chaser_brain.gd`

**需要修改的文件：**
- `Project/entities/enemies/enemy_manager.gd` — 注册 chaser brain

### 技术约束

- ChaserBrain 继承 EnemyBrain
- 覆写 `evaluate_self_preservation()`、`evaluate_threat_response()`、`evaluate_status_response()`、`evaluate_tracking()`、`evaluate_default()`
- 追踪方向使用 pathfinding 辅助，不硬编码方向逻辑
- 回避状态格时，需要查询 StatusTileManager 检查目标格是否有状态格
- 威胁加速时的多步移动，每步都需要独立计算方向和碰撞

### 验收标准

- [ ] 追踪者每 tick 向蛇头方向移动 1 格
- [ ] 蛇头进入 3 格范围内时，追踪者移速 +1（每 tick 移动 2 格）
- [ ] 追踪者回避状态格（优先选择无状态格的方向）
- [ ] 追踪者在自保优先级下会逃离危险状态格
- [ ] 追踪者被堵住时回退到随机移动
- [ ] 追踪者颜色为 config 中定义的 `#FF3366`
- [ ] 追踪者 HP 和攻击消耗正确
- [ ] 所有测试通过

### 备注

- 设计意图：追踪者可以被"状态格墙"阻挡——玩家铺设状态格可以引导追踪者的路径
- 追踪者的回避行为使状态系统产生战术意义
- 威胁加速给玩家"被追上"的紧迫感，鼓励玩家主动出击而非消极逃跑
