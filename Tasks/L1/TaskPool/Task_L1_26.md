## [L1-T26] 第一层视觉反馈系统

### 元信息

| 字段 | 值 |
|------|-----|
| **阶段** | L1-Combat（补充任务，L2 之前必须完成） |
| **优先级** | P1(核心) |
| **前置任务** | L1-T24, L1-T25 |
| **预估粒度** | L(3~6h) |
| **分配职能** | Gameplay 程序 |

### 概述

为纯色块风格的游戏添加最低限度的视觉反馈，使玩家能直观感知状态效果、碾压、受伤等核心事件。这是验证玩法手感的前提条件。

### 上下文

| 文档 | 章节/位置 |
|------|----------|
| `Designs/Interactive/visual_feedback_design.md` | 第一层：最低限度视觉反馈 |
| `Designs/General/snake_roguelite_design.md` | §4.6 视觉需求 |
| `Project/data/json/game_config.json` | 状态效果 / 敌人 / 反应配置 |
| `Project/entities/snake/snake_segment.gd` | 蛇段渲染（ColorRect） |
| `Project/entities/enemies/enemy.gd` | 敌人渲染（ColorRect） |

### 任务详细

#### 1. 蛇身状态视觉指示

蛇段携带状态时叠加对应视觉效果。

- 灼烧：蛇段边缘 2px 红橙描边 + 0.5s 闪烁
- 冰冻 layer1：蛇段颜色混合冰蓝色
- 冰冻 layer2：蛇段覆盖白色高不透明度层
- 中毒：蛇段叠加半透明绿色 + 1s 脉动
- 多状态按优先级显示：冰冻 layer2 > 灼烧 > 冰冻 > 中毒
- 监听 `status_applied` / `status_removed` / `status_layer_changed` / `ice_freeze_started` / `ice_freeze_ended`

**需要修改的文件：**
- `Project/entities/snake/snake_segment.gd` — 添加状态视觉层

#### 2. 碾压视觉反馈

- 碾压命中时：敌人位置白色闪光 (0.3s)
- 屏幕微震：Camera2D offset 抖动 (0.1s, 2px 幅度)
- 敌人死亡：Tween scale 从 1.0 缩小到 0.0 (0.2s)
- 监听 `snake_body_crush` / `enemy_died`

**需要创建的文件：**
- `Project/systems/vfx/screen_shake.gd` — 屏幕震动管理器

**需要修改的文件：**
- `Project/entities/enemies/enemy.gd` — 死亡缩小动画
- `Project/scenes/game_world.gd` — 挂载屏幕震动

#### 3. 敌人类型形状区分

- Wanderer：保持方形（现状）
- Chaser：菱形（rotation = PI/4，缩小至 60% 补偿对角线）
- Bog Crawler：十字形（两个交叉 ColorRect）
- 颜色保持 JSON 配置驱动

**需要修改的文件：**
- `Project/entities/enemies/enemy.gd` — 根据 type_id 切换形状

#### 4. 受伤反馈

- 蛇受伤（长度减少）时全身红闪 1 次 (0.15s)：所有蛇段 `modulate` 变红再恢复
- 蛇长度 ≤3 时持续红色脉动（频率随长度降低加快）
- 监听 `length_decreased`

**需要修改的文件：**
- `Project/entities/snake/snake.gd` — 受伤闪烁 + 危险脉动

#### 5. 视觉配置扩展

在 `game_config.json` 中为状态效果和敌人添加 `visual` 字段，包含颜色、动画参数。

**需要修改的文件：**
- `Project/data/json/game_config.json` — 添加 visual 配置

#### 6. 测试

- 编写 `Project/Test/cases/test_t26_visual_feedback.gd`
- 验证状态视觉应用/移除的正确性
- 验证碾压闪光触发
- 验证敌人形状区分
- 不测试视觉外观本身（无截图对比），只测试逻辑：信号触发后对应节点/属性变化

**需要创建的文件：**
- `Project/Test/cases/test_t26_visual_feedback.gd`

### 技术约束

- 所有动画使用 Tween，不使用 AnimationPlayer
- 颜色/动画参数从 `game_config.json` 读取
- 同屏 Tween 不超过 50 个
- 蛇段状态视觉不影响碰撞/逻辑（纯表现层）
- Z-index 层级遵循设计文档定义（0:背景 → 1:状态格 → 2:食物 → 3:敌人 → 4:蛇 → 10:VFX → 15:HUD popup）

### 验收标准

- [ ] 蛇身段携带灼烧时显示红橙描边闪烁
- [ ] 蛇身段携带冰冻 layer1 时变蓝
- [ ] 蛇身段携带冰冻 layer2 时变白（完全冻结）
- [ ] 蛇身段携带中毒时显示绿色脉动
- [ ] 多状态共存时按优先级显示最高级
- [ ] 碾压命中时有白色闪光 + 屏幕微震
- [ ] 敌人死亡时缩小消失
- [ ] 三种敌人类型形状可区分
- [ ] 蛇受伤时全身红闪
- [ ] 蛇长度 ≤3 时持续红色脉动
- [ ] 所有视觉参数可通过 JSON 配置
- [ ] 新增测试全部通过，零回归

### 备注

- 本任务是 L1 的补充任务，编号 T26（接续 T25 Effect Atom System）
- 设计文档见 `Designs/Interactive/visual_feedback_design.md`
- 第二层（手感提升）和第三层（打磨级）视觉效果留到 L2/L3 阶段
- 反应闪光（蒸腾白色、毒爆黄绿色）已在 T25 期间实现，本任务不重复
- 本任务完成后方可开始 L2 阶段
