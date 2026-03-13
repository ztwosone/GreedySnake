## [L1-T14] 实体↔空间状态转化系统

### 元信息

| 字段 | 值 |
|------|-----|
| **阶段** | L1-Combat |
| **优先级** | P1(核心) |
| **前置任务** | L1-T12, L1-T13 |
| **预估粒度** | L(3~6h) |
| **分配职能** | Gameplay 程序 |

### 概述

实现状态效果在实体（蛇身/敌人）与空间（地板格子）之间的双向转化逻辑。蛇身带状态经过空格时留下状态格（实体→空间），实体移入状态格时获得状态（空间→实体）。

### 上下文

| 文档 | 章节/位置 |
|------|----------|
| `Designs/General/snake_roguelite_design.md` | §4.3 转化规则 |
| `Designs/General/snake_roguelite_design.md` | §4.4 各状态的实体→空间/空间→实体规则 |
| `Project/data/json/game_config.json` | `status_effects` 各状态配置 |

### 任务详细

1. 创建 `Project/systems/status/status_transfer_system.gd` — 转化系统
2. 监听 `EventBus.snake_moved` 和 `EventBus.entity_moved` 信号
3. 实现空间→实体转化：实体移动到有 StatusTile 的格子时，给实体施加对应状态
4. 实现实体→空间转化：带状态的蛇身段经过空格时，在该格生成 StatusTile
5. 转化规则由各状态类型的配置驱动（通过 ConfigManager 读取）
6. 编写测试 `Project/Test/cases/test_t14_status_transfer.gd`

**转化规则框架：**

```
空间→实体：
  实体移动到 StatusTile 所在格
  → StatusEffectManager.apply_status(entity, tile.status_type, "tile")
  → tile.layer -= 1（可选，取决于状态类型配置）

实体→空间（蛇身专用）：
  蛇移动后，蛇身旧尾位置（刚离开的格子）
  → 检查该段蛇身是否携带状态
  → 若有，StatusTileManager.place_tile(old_pos, status_type, 1)
  → 转移条件由各状态类型定义（如毒：每 3 格留 1 格）
```

**StatusTransferSystem 核心方法：**

| 方法 | 说明 |
|------|------|
| `_on_entity_moved(data)` | 监听实体移动，检查新位置是否有 StatusTile |
| `_on_snake_moved(data)` | 监听蛇移动，处理蛇身实体→空间转化 |
| `_transfer_spatial_to_entity(entity, tile)` | 空间→实体转化 |
| `_transfer_entity_to_spatial(entity, pos, type)` | 实体→空间转化 |
| `_should_transfer_to_spatial(type, context) -> bool` | 判断是否满足实体→空间转化条件 |

**需要创建的文件：**
- `Project/systems/status/status_transfer_system.gd`

**需要修改的文件：**
- `Project/scenes/game_world.tscn` — 添加 StatusTransferSystem 节点
- `Project/scenes/game_world.gd` — 初始化 StatusTransferSystem 引用

### 技术约束

- StatusTransferSystem 作为场景节点加入 GameWorld（非 Autoload）
- 空间→实体转化在 `tick_input_collected` 阶段处理（蛇移动后立即检查）
- 实体→空间转化规则可配置：每种状态类型可以有不同的"转移间隔"（如毒每 3 格才转化一次）
- 通过 ConfigManager 读取转化参数，不硬编码
- 空间→实体转化时，不应无限叠层（受 max_layers 约束）
- 实体→空间转化时，转化不消耗实体身上的状态层数（设计文档：火焰"转移 1 层"）

### 验收标准

- [ ] 实体移动到 StatusTile 所在格时，自动获得对应状态
- [ ] 带状态的蛇身经过空格时，按规则留下 StatusTile
- [ ] 空间→实体转化发射 `status_applied` 信号
- [ ] 实体→空间转化发射 `status_tile_placed` 信号
- [ ] 转化参数从 ConfigManager 读取，可通过 JSON 修改
- [ ] 转化不会导致无限循环（蛇留下火焰格→蛇尾踩火焰格→又留下火焰格…需有冷却或条件判断）
- [ ] 所有测试通过

### 备注

- 各状态类型的具体转化条件在 T15~T17 中细化，本任务只建立框架和通用逻辑
- 设计文档中火焰是"转移 1 层"，冰冻是"击杀时生成 3×3 区域"，毒是"每 3 格留 1 格"——转化条件差异很大，需要可扩展的规则接口
- 防止无限循环的关键：蛇身刚踩入状态格获得状态后，该段在同一 tick 内不应触发实体→空间转化
