## [L1-T22] 毒沼匍匐者（Bog Crawler）实现

### 元信息

| 字段 | 值 |
|------|-----|
| **阶段** | L1-Combat |
| **优先级** | P2(重要) |
| **前置任务** | L1-T17, L1-T19 |
| **预估粒度** | M(1~3h) |
| **分配职能** | Gameplay 程序 |

### 概述

实现毒沼匍匐者敌人类型。趋向毒液格移动，在毒液格上移速大幅提升，死亡时爆裂留下毒液。

### 上下文

| 文档 | 章节/位置 |
|------|----------|
| `Designs/General/snake_roguelite_design.md` | §7.4 战术级：毒沼匍匐者 Bog Crawler |
| `Project/data/json/game_config.json` | `enemy_types.bog_crawler` |

### 任务详细

1. 创建 `Project/entities/enemies/brains/bog_crawler_brain.gd` — 毒沼匍匐者 AI
2. 实现死亡时爆裂留下毒液格逻辑
3. 在 EnemyManager 中注册 bog_crawler 类型与对应 brain
4. 编写测试 `Project/Test/cases/test_t22_bog_crawler.gd`

**毒沼匍匐者行为规则：**

```
状态响应：attract（趋向型，偏好毒液格）
P1 自保：当前格有火焰格 → 移离（火+毒触发毒爆对自己不利）
P2 威胁：无主动攻击行为
P3 状态响应：搜索最近的毒液格，向其移动
P4 追踪：无
P5 默认：随机移动（类似游荡者）
```

**特殊规则：**
- **毒液格加速：** 在毒液格上时，移速 + `poison_speed_bonus`（每 tick 移动 `speed + poison_speed_bonus` 格）
- **死亡爆裂：** 被击杀时，在死亡位置及周围随机 `death_poison_tiles - 1` 格生成毒液格
- **火焰格交互：** 踩入火焰格时，如果自身有中毒状态，触发毒爆反应（利用反应系统 T18）

**从 config 读取的参数：**

| 参数 | 值 | 说明 |
|------|-----|------|
| `hp` | 2 | 需要碾压/撞击 2 次 |
| `attack_cost` | 1 | 蛇头撞击消耗 |
| `speed` | 1 | 基础移速 |
| `poison_speed_bonus` | 2 | 在毒液格上的额外移速 |
| `death_poison_tiles` | 3 | 死亡时留下的毒液格数量 |
| `color` | "#2D5A27" | 深绿色 |

**需要创建的文件：**
- `Project/entities/enemies/brains/bog_crawler_brain.gd`

**需要修改的文件：**
- `Project/entities/enemies/enemy_manager.gd` — 注册 bog_crawler brain
- `Project/entities/enemies/enemy.gd` — 添加死亡时回调（支持 death_effect）

### 技术约束

- BogCrawlerBrain 继承 EnemyBrain
- 趋向逻辑使用 `pathfinding.get_nearest_tile_of_type(pos, "poison")` 寻找最近毒液格
- 如果没有毒液格，回退到随机移动
- 死亡爆裂通过 `StatusTileManager.place_tile()` 实现
- 死亡爆裂的毒液格位置：死亡位置 + 随机选择的相邻格，不超出地图边界
- HP 为 2 意味着需要追踪每个敌人的当前 HP（Enemy 在 T19 中已添加 `hp` 字段）

### 验收标准

- [ ] 毒沼匍匐者主动向最近的毒液格移动
- [ ] 在毒液格上时移速 +2（每 tick 移动 3 格）
- [ ] 没有毒液格时随机移动
- [ ] 死亡时在周围留下 3 格毒液
- [ ] HP 为 2，需要被撞击/碾压 2 次才会死亡
- [ ] 踩入火焰格时可触发毒爆反应（如果自身有中毒）
- [ ] 颜色为 config 中定义的 `#2D5A27`
- [ ] 所有测试通过

### 备注

- 毒沼匍匐者是第一个"战术级"敌人——它让玩家铺设的毒液格变成双刃剑
- 玩家需要权衡：铺设毒液格可以减缓蛇的恢复，但也会给毒沼匍匐者提供加速跑道
- 死亡爆裂的毒液格可以被火焰格引爆（触发毒爆反应），形成连锁
