## [L1-T23] 蛇身碾压系统

### 元信息

| 字段 | 值 |
|------|-----|
| **阶段** | L1-Combat |
| **优先级** | P1(核心) |
| **前置任务** | L0 全部, L1-T12 |
| **预估粒度** | M(1~3h) |
| **分配职能** | Gameplay 程序 |

### 概述

实现蛇身碾压判定：蛇移动时，身体段经过的格子如果有敌人则触发碾压，消耗长度并对敌人造成伤害。带状态的蛇身段碾压时可附加状态。

### 上下文

| 文档 | 章节/位置 |
|------|----------|
| `Designs/General/snake_roguelite_design.md` | §2.4 蛇身碰敌人 → 触发碾压判定 |
| `Designs/General/snake_roguelite_design.md` | §4.4 灼烧：蛇身某段有灼烧时，碾压可附加灼烧 |
| `Project/data/json/game_config.json` | `enemy.default_attack_cost` |

### 任务详细

1. 创建 `Project/systems/combat/crush_system.gd` — 碾压系统
2. 监听 `EventBus.snake_moved` 信号
3. 检查蛇身各段当前位置是否有敌人
4. 有敌人时触发碾压判定
5. 在 EventBus 中添加碾压信号
6. 编写测试 `Project/Test/cases/test_t23_crush.gd`

**碾压触发条件：**
- 蛇移动后，遍历蛇身所有段（不含蛇头，蛇头碰撞在 MovementSystem 中处理）
- 每段检查 GridWorld 中该格是否有敌人实体
- 如果有敌人 → 触发碾压

**碾压判定流程：**

```
1. 蛇身段位于敌人所在格
2. 碾压消耗：default_attack_cost（默认 1 格长度）
   → 发射 length_decrease_requested { amount: cost, source: "crush" }
3. 敌人受伤：enemy.hp -= 1
   → 如果 enemy.hp <= 0 → 敌人死亡
   → 发射 enemy_killed { method: "crush" }
4. 状态附加（如果蛇身段带有状态）：
   → 将该段的状态施加给敌人
   → StatusEffectManager.apply_status(enemy, status_type, "crush")
```

**CrushSystem 核心方法：**

| 方法 | 说明 |
|------|------|
| `_on_snake_moved(data)` | 蛇移动后检查碾压 |
| `_check_crush(segment_pos, segment_index)` | 检查单个身体段是否碾压敌人 |
| `_execute_crush(enemy, segment_index)` | 执行碾压判定 |
| `_transfer_status_on_crush(enemy, segment)` | 碾压时转移状态 |

**需要创建的目录：**
- `Project/systems/combat/`

**需要创建的文件：**
- `Project/systems/combat/crush_system.gd`

**需要修改的文件：**
- `Project/autoloads/event_bus.gd` — 添加碾压信号
- `Project/scenes/game_world.tscn` — 添加 CrushSystem 节点
- `Project/scenes/game_world.gd` — 初始化 CrushSystem

### EventBus 新增信号

```gdscript
# === Combat ===
signal snake_body_crush(data: Dictionary)  # { enemy, position, segment_index, cost, status_transferred }
```

### 技术约束

- CrushSystem 作为场景节点加入 GameWorld
- 碾压检查在蛇移动后立即执行（`snake_moved` 信号处理中）
- 一次移动中多个身体段可以碾压多个不同的敌人
- 一次移动中同一敌人只被碾压一次（防止多段同时压到同一敌人重复判定）
- 碾压消耗通过 EventBus 请求，不直接修改蛇长度
- 如果蛇长度不足以支付碾压消耗，仍然执行碾压（消耗会导致蛇死亡）
- 蛇头碰撞仍由 MovementSystem 处理，碾压只处理身体段

### 验收标准

- [ ] 蛇身体段移动到有敌人的格子时触发碾压
- [ ] 碾压消耗 1 格长度（通过 `length_decrease_requested` 请求）
- [ ] 敌人 HP 减少 1
- [ ] 敌人 HP 归零时死亡并发射 `enemy_killed` 信号
- [ ] 蛇身段带灼烧时碾压附加灼烧给敌人
- [ ] 蛇身段带冰冻时碾压附加冰冻给敌人
- [ ] 蛇身段带中毒时碾压附加中毒给敌人
- [ ] 蛇头碰撞判定不受碾压系统影响（两套独立系统）
- [ ] 同一 tick 同一敌人不被重复碾压
- [ ] `snake_body_crush` 信号正确发射
- [ ] 所有测试通过

### 备注

- 碾压是蛇的"被动攻击"——移动路径本身就是武器
- 状态附加让碾压与状态系统产生联动：带火的蛇身碾压过的敌人会着火
- 碾压消耗长度意味着"长蛇碾压更多敌人但也缩短更快"——核心的风险权衡
- 蛇头碰撞和蛇身碾压是两套独立系统：蛇头碰敌人 → 战斗判定（消耗长度+杀敌），蛇身碰敌人 → 碾压判定（消耗长度+伤害）
