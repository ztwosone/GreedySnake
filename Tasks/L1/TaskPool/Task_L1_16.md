## [L1-T16] 冰冻状态实现

### 元信息

| 字段 | 值 |
|------|-----|
| **阶段** | L1-Combat |
| **优先级** | P1(核心) |
| **前置任务** | L1-T12, L1-T13, L1-T14 |
| **预估粒度** | M(1~3h) |
| **分配职能** | Gameplay 程序 |

### 概述

实现冰冻状态效果的完整逻辑，包括实体效果（减速 + 冻结）、空间效果（冰霜格）和转化规则。

### 上下文

| 文档 | 章节/位置 |
|------|----------|
| `Designs/General/snake_roguelite_design.md` | §4.4 冰冻 [冰] |
| `Project/data/json/game_config.json` | `status_effects.ice` |

### 任务详细

1. 创建 `Project/systems/status/effects/ice_effect.gd` — 冰冻效果处理器
2. 在 StatusEffectManager 中注册冰冻效果的 tick 处理逻辑
3. 实现减速逻辑（修改 TickManager 的 `tick_speed_modifier`）
4. 实现冻结逻辑（2 层时完全静止）
5. 编写测试 `Project/Test/cases/test_t16_ice.gd`

**冰冻 — 实体效果：**

| 参数 | 值（从 config 读取） | 说明 |
|------|---------------------|------|
| `speed_modifier` | 0.5 | 移速变为原来的 50% |
| `freeze_at_layer` | 2 | 达到此层数时触发冻结 |
| `freeze_duration` | 2.0 秒 | 冻结持续时间 |
| `entity_duration` | 6.0 秒 | 冰冻持续时间 |
| `max_layers` | 2 | 最大 2 层 |

- 1 层冰冻：蛇移速 -50%（通过 TickManager.tick_speed_modifier 实现）
- 2 层冰冻：触发冻结，蛇完全静止 `freeze_duration` 秒（TickManager 暂停 ticking）
- 冻结结束后层数重置为 1，继续减速效果直到过期
- 敌人冰冻：敌人移动间隔翻倍 / 2 层时完全停止

**冰冻 — 空间效果（冰霜格）：**

| 参数 | 值（从 config 读取） | 说明 |
|------|---------------------|------|
| `tile_duration` | 12.0 秒 | 冰霜格持续时间 |
| `color` | "#ADD8E6" | 蓝白色 |

- 冰霜格不蔓延（与火焰不同）
- 踩入冰霜格的实体获得冰冻状态

**冰冻 — 实体→空间转化：**
- L1 阶段简化：带冰冻的蛇身经过空格时，该格有概率（50%）生成冰霜格
- 设计文档原始规则（冻结敌人击杀时生成 3×3 冰霜区域）在敌人击杀联动中实现

**视觉：**
- 实体冰冻：该段显示蓝白色叠加
- 冰霜格：蓝白色半透明 ColorRect
- 冻结状态：实体闪烁更强烈的蓝白色

**需要创建的文件：**
- `Project/systems/status/effects/ice_effect.gd`

**需要修改的文件：**
- `Project/systems/status/status_effect_manager.gd` — 注册冰冻效果处理器
- `Project/systems/status/status_transfer_system.gd` — 添加冰冻转化条件
- `Project/autoloads/tick_manager.gd` — 可能需要扩展 `tick_speed_modifier` 接口

### 技术约束

- 减速通过修改 TickManager 的 `tick_speed_modifier` 实现，不修改蛇的移动逻辑
- 冻结通过 TickManager 暂停实现（`pause()` / `resume()`）
- 多个减速效果需要能正确叠加（如果未来有多个减速源，使用乘法叠加）
- 冻结结束后需要正确恢复 tick 速度
- 敌人冰冻需要在 T19 敌人 AI 框架完成后才能完整实现，本任务先实现蛇的冰冻

### 验收标准

- [ ] 蛇获得 1 层冰冻后，移动速度降为 50%
- [ ] 蛇获得 2 层冰冻后，触发冻结（完全静止 2 秒）
- [ ] 冻结结束后恢复为 1 层冰冻的减速状态
- [ ] 冰冻 6 秒后自动消失，速度恢复正常
- [ ] 冰霜格持续 12 秒后消失
- [ ] 蛇踩入冰霜格获得冰冻状态
- [ ] 冰霜格视觉为蓝白色半透明
- [ ] 所有测试通过

### 备注

- 冰冻影响的是全局 tick 速度（蛇和敌人都受影响）。如果需要只影响蛇，需要在 TickManager 中增加 per-entity 速度修正——L1 阶段暂时用全局修正简化
- 设计文档提到"蛇头冰冻时转向延迟但蛇尾保持原速"——这是高级交互，L1 不实现
- 设计文档提到"冻结状态下受到攻击附加碎裂（下次伤害 ×2）"——L1 不实现碎裂
