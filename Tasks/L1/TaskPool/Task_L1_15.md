## [L1-T15] 火焰状态实现

### 元信息

| 字段 | 值 |
|------|-----|
| **阶段** | L1-Combat |
| **优先级** | P1(核心) |
| **前置任务** | L1-T12, L1-T13, L1-T14 |
| **预估粒度** | M(1~3h) |
| **分配职能** | Gameplay 程序 |

### 概述

实现灼烧（火）状态效果的完整逻辑，包括实体效果（周期扣血）、空间效果（火焰格蔓延）和转化规则。

### 上下文

| 文档 | 章节/位置 |
|------|----------|
| `Designs/General/snake_roguelite_design.md` | §4.4 灼烧 [火] |
| `Project/data/json/game_config.json` | `status_effects.fire` |

### 任务详细

1. 创建 `Project/systems/status/effects/fire_effect.gd` — 火焰效果处理器
2. 在 StatusEffectManager 中注册火焰效果的 tick 处理逻辑
3. 实现火焰格蔓延逻辑
4. 实现火焰的实体→空间转化条件
5. 编写测试 `Project/Test/cases/test_t15_fire.gd`

**火焰 — 实体效果（灼烧）：**

| 参数 | 值（从 config 读取） | 说明 |
|------|---------------------|------|
| `entity_damage_interval` | 2.0 秒 | 每隔多久扣一次 |
| `entity_damage_amount` | 1 格 | 每次扣多少 |
| `entity_duration` | 6.0 秒 | 持续时间 |
| `max_layers` | 99 | 可无限叠层 |

- 蛇身灼烧：每 `entity_damage_interval` 秒，发射 `length_decrease_requested { amount: entity_damage_amount * layer, source: "fire" }`
- 敌人灼烧：每 `entity_damage_interval` 秒，对敌人造成 1 次伤害
- 叠层增加伤害频率或伤害量（建议：伤害量 × 层数）

**火焰 — 空间效果（火焰格）：**

| 参数 | 值（从 config 读取） | 说明 |
|------|---------------------|------|
| `tile_duration` | 8.0 秒 | 火焰格持续时间 |
| `spread_chance` | 0.2 (20%) | 每次蔓延检查的概率 |
| `spread_interval` | 1.0 秒 | 蔓延检查间隔 |
| `color` | "#FF4500" | 橙红色 |

- 火焰格每 `spread_interval` 秒检查相邻 4 格，每格有 `spread_chance` 概率蔓延（生成新火焰格）
- 蔓延不会覆盖已有同类状态格
- 蔓延生成的火焰格独立计时

**火焰 — 实体→空间转化：**
- 带灼烧的蛇身经过某格时，该格生成 1 层火焰格
- 转移条件：每次移动都可转化（无间隔限制）

**视觉：**
- 实体灼烧：该段闪烁橙红色（通过 ColorRect 颜色调制或叠加层）
- 火焰格：橙红色半透明 ColorRect，可选简单透明度闪烁动画

**需要创建的目录：**
- `Project/systems/status/effects/`

**需要创建的文件：**
- `Project/systems/status/effects/fire_effect.gd`

**需要修改的文件：**
- `Project/systems/status/status_effect_manager.gd` — 注册火焰效果处理器
- `Project/systems/status/status_transfer_system.gd` — 添加火焰转化条件

### 技术约束

- 所有数值从 `ConfigManager.get_status_effect("fire")` 读取
- 蔓延不能蔓延到 GridWorld 边界外
- 蔓延不能蔓延到有障碍物（蛇身、地形）的格子
- 伤害通过 EventBus 信号请求（`length_decrease_requested`），不直接修改蛇数据
- 火焰效果处理器应是可插拔的（支持未来新增状态类型使用相同模式）

### 验收标准

- [ ] 蛇获得灼烧后，每 2 秒自动减少 1 格长度
- [ ] 灼烧叠层后，伤害按层数倍增
- [ ] 灼烧 6 秒后自动消失
- [ ] 火焰格持续 8 秒后消失
- [ ] 火焰格以 20% 概率向相邻格蔓延
- [ ] 蛇踩入火焰格获得灼烧状态
- [ ] 带灼烧的蛇身经过空格时留下火焰格
- [ ] 火焰格视觉为橙红色半透明
- [ ] 所有测试通过

### 备注

- 火焰是最基础的伤害型状态，适合作为第一个实现并验证整个状态框架
- 蔓延是火焰独有的机制，其他状态不一定有蔓延
- 设计文档还提到"灼烧的蛇身碾压敌人可附加灼烧"——这在 T23 蛇身碾压中实现
