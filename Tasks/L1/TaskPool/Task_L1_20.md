## [L1-T20] 游荡者（Wanderer）实现

### 元信息

| 字段 | 值 |
|------|-----|
| **阶段** | L1-Combat |
| **优先级** | P1(核心) |
| **前置任务** | L1-T19 |
| **预估粒度** | M(1~3h) |
| **分配职能** | Gameplay 程序 |

### 概述

实现游荡者敌人类型，替换 L0 的静止敌人。游荡者随机移动，碰壁反弹，完全无视状态格。

### 上下文

| 文档 | 章节/位置 |
|------|----------|
| `Designs/General/snake_roguelite_design.md` | §7.4 基础级：游荡者 Wanderer |
| `Project/data/json/game_config.json` | `enemy_types.wanderer` |

### 任务详细

1. 创建 `Project/entities/enemies/brains/wanderer_brain.gd` — 游荡者 AI
2. 在 EnemyManager 中注册 wanderer 类型与对应 brain
3. 编写测试 `Project/Test/cases/test_t20_wanderer.gd`

**游荡者行为规则：**

```
状态响应：ignore（无视型）
P1 自保：无（无视状态格）
P2 威胁：无
P3 状态响应：无（ignore）
P4 追踪：无
P5 默认：随机选择一个合法方向移动
```

**随机移动规则：**
- 每 tick 从合法方向（不越界、不撞蛇身）中随机选一个移动
- 碰壁（边界）时反弹：当前方向不可用时换方向
- 优先保持上一次的移动方向（70% 概率），其余方向均分剩余概率
- 如果所有方向都不可用，原地不动

**从 config 读取的参数：**

| 参数 | 值 | 说明 |
|------|-----|------|
| `hp` | 1 | 被碾压/撞击 1 次即死 |
| `attack_cost` | 1 | 蛇头撞击消耗 1 格长度 |
| `speed` | 1 | 每 tick 移动 1 格 |
| `color` | "#CC1A4D" | 视觉颜色 |

**需要创建的目录：**
- `Project/entities/enemies/brains/`

**需要创建的文件：**
- `Project/entities/enemies/brains/wanderer_brain.gd`

**需要修改的文件：**
- `Project/entities/enemies/enemy_manager.gd` — 注册 wanderer brain

### 技术约束

- WandererBrain 继承 EnemyBrain
- 只覆写 `evaluate_default()` 方法（其他优先级行为全部返回空）
- 移动方向选择使用 `pathfinding.get_valid_moves()` 获取合法方向
- 随机种子不需要固定（非确定性即可）

### 验收标准

- [ ] 游荡者每 tick 向随机方向移动 1 格
- [ ] 游荡者碰到边界时反弹（改变方向）
- [ ] 游荡者不会移动到蛇身占据的格子
- [ ] 游荡者颜色为 config 中定义的 `#CC1A4D`
- [ ] 游荡者被蛇头撞击时消耗 1 格长度并死亡
- [ ] 游荡者 HP 为 1，被碾压 1 次即死
- [ ] 游荡者完全无视状态格（不回避也不趋向）
- [ ] 现有 L0 测试仍然通过
- [ ] 所有新测试通过

### 备注

- 游荡者是最简单的敌人类型，用于验证 AI 框架的基本功能
- 设计意图：游荡者是"战场上的随机触发器"——它们随机走过状态格时会产生不可预测的状态转化
- L0 的静止敌人应被替换为游荡者（EnemyManager 默认生成 wanderer 类型）
