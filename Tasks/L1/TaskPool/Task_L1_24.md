## [L1-T24] 战斗场景集成与平衡调试

### 元信息

| 字段 | 值 |
|------|-----|
| **阶段** | L1-Combat |
| **优先级** | P1(核心) |
| **前置任务** | L1-T15, L1-T16, L1-T17, L1-T18, L1-T20, L1-T21, L1-T22, L1-T23 |
| **预估粒度** | L(3~6h) |
| **分配职能** | Gameplay 程序 |

### 概述

将 L1 所有系统集成到战斗场景中，实现多种敌人类型混合生成、状态格视觉层级、HUD 状态显示，并进行初步数值平衡。

### 上下文

| 文档 | 章节/位置 |
|------|----------|
| `Designs/General/snake_roguelite_design.md` | §7.2 同一房间内敌人类型不超过 3 种 |
| `Designs/General/snake_roguelite_design.md` | §4.6 视觉需求 |
| `Project/data/json/game_config.json` | 全部配置 |
| `Project/scenes/game_world.tscn` | 当前游戏场景 |

### 任务详细

1. **场景集成：** 在 game_world.tscn 中添加所有 L1 系统节点
   - StatusTileManager（StatusTile 容器）
   - StatusTransferSystem
   - ReactionSystem
   - CrushSystem
   - 确保节点初始化顺序正确

2. **多类型敌人混合生成：**
   - EnemyManager 按配置的比例生成不同类型敌人
   - 默认比例：wanderer 50%、chaser 30%、bog_crawler 20%
   - 每房间敌人类型 ≤ 3 种

3. **状态格视觉层级：**
   - 渲染顺序：GridBackground → StatusTile → Food → Enemy → Snake
   - StatusTile 的 z_index 设为低于实体
   - 多层状态格在同一格子时能视觉区分（颜色叠加或闪烁交替）

4. **HUD 扩展：**
   - 显示蛇当前携带的状态效果（类型 + 层数 + 剩余时间）
   - 使用简单的文本标签或颜色图标
   - 在现有 LengthLabel 旁边添加 StatusLabel

5. **初步数值平衡：**
   - 调整 `game_config.json` 中的数值确保游戏可玩
   - 确保单次反应伤害不超过 4 格（设计文档要求）
   - 确保食物生成率与长度消耗率大致平衡
   - 火焰蔓延速度不会覆盖整个地图

6. **集成测试：**
   - 编写 `Project/Test/cases/test_t24_integration.gd`
   - 验证所有系统协同工作
   - 验证无异常崩溃

**需要创建的文件：**
- `Project/Test/cases/test_t24_integration.gd`

**需要修改的文件：**
- `Project/scenes/game_world.tscn` — 添加所有 L1 系统节点
- `Project/scenes/game_world.gd` — 初始化所有 L1 系统引用
- `Project/entities/enemies/enemy_manager.gd` — 多类型混合生成
- `Project/ui/hud.gd` — 添加状态显示
- `Project/data/json/game_config.json` — 数值调整

### 技术约束

- 所有 L1 系统节点的初始化顺序必须正确（StatusEffectManager → StatusTileManager → TransferSystem → ReactionSystem → CrushSystem）
- game_world.gd 的 `start_game()` 需要初始化所有新系统
- 敌人类型比例应可通过 config 配置
- 性能：状态格总数不应超过 100 个（如果超过，最早的自动消失）
- HUD 状态显示不应遮挡游戏区域

### 验收标准

- [ ] 游戏场景包含所有 L1 系统节点
- [ ] 蛇身段可以携带状态效果（火/冰/毒），有视觉提示
- [ ] 地板上出现状态格（火焰格/冰霜格/毒液格），有对应颜色
- [ ] 蛇经过状态格 → 获得状态；带状态的蛇经过空格 → 留下状态格
- [ ] 火+冰同时存在 → 触发蒸腾反应
- [ ] 火+毒同时存在 → 触发毒爆反应
- [ ] 游荡者在地图上随机移动，碰壁反弹
- [ ] 追踪者向蛇头移动，接近时加速
- [ ] 毒沼匍匐者偏好毒液格，死亡时留下毒液
- [ ] 蛇身经过敌人 → 触发碾压（消耗长度，敌人受伤）
- [ ] 不同敌人类型混合出现
- [ ] HUD 显示当前蛇身状态
- [ ] 反复游玩无异常崩溃
- [ ] 状态效果正确过期清除
- [ ] 所有测试通过（包括 L0 的 338 项）

### 备注

- 这是 L1 阶段的最终集成任务，需要等待所有前置任务完成
- 数值平衡是初步的——精确平衡需要大量 playtest，L1 只需确保"能玩且不会立刻死"
- 如果性能有问题，优先优化状态格数量上限和蔓延频率
- 本任务完成后，L1-Combat 阶段即视为完成
