## [L0-T09] 静止敌人与基础战斗

### 元信息

| 字段 | 值 |
|------|-----|
| **阶段** | L0-MVP |
| **优先级** | P2(重要) |
| **前置任务** | L0-T02, L0-T04, L0-T05, L0-T07 |
| **预估粒度** | M(1~3h) |
| **分配职能** | Gameplay 程序 |

### 概述

实现最简单的静止敌人和基础战斗判定：蛇头撞击敌人 → 敌人死亡 → 蛇消耗 1 格长度。这是验证「长度 = 战斗资源」核心设计的最小单元。

### 上下文

| 文档 | 章节/位置 |
|------|----------|
| `TechDocs/ScriptingLeading.md` | §3.4 敌人系统 (EnemySystem) |
| `TechDocs/ScriptingLeading.md` | §3.4.4 战斗判定 |
| `Designs/General/snake_roguelite_design.md` | §7 系统六：敌人系统 — 游荡者 Wanderer |

### 任务详细

#### 步骤 1：创建 Enemy 实体

```
Enemy (extends GridEntity):
  entity_type = Constants.EntityType.ENEMY
  blocks_movement = false    # MVP 中设为 false，让蛇可以移入敌人格子
  is_solid = true
  cell_layer = 1

  hp: int = 1               # MVP 中所有敌人 1 HP
  attack_cost: int = 1      # 撞击消耗蛇长度
```

视觉表现：`ColorRect`，大小与食物一致（48×48 居中），颜色紫红色 `Color(0.8, 0.1, 0.3)`。

#### 步骤 2：创建 EnemyManager

```
EnemyManager (extends Node):
  max_enemy_count: int = 3
  current_enemies: Array[Enemy] = []
  enemy_container: Node2D
```

**核心方法：**

| 方法 | 说明 |
|------|------|
| `init_enemies(count: int)` | 初始化时生成指定数量的敌人 |
| `spawn_enemy()` | 在随机空格上生成一个敌人 |
| `_on_snake_hit_enemy(data)` | 响应蛇头撞击敌人事件 |
| `_on_enemy_killed(data)` | 响应敌人死亡，移除并补充 |

**战斗判定逻辑：**

```
func _ready():
    EventBus.snake_hit_enemy.connect(_on_snake_hit_enemy)

func _on_snake_hit_enemy(data: Dictionary):
    var enemy: Enemy = data.get("enemy")
    if enemy == null:
        return

    # 1. 蛇消耗长度
    EventBus.length_decrease_requested.emit({
        "amount": enemy.attack_cost,
        "source": "combat"
    })

    # 2. 敌人受伤
    enemy.hp -= 1
    if enemy.hp <= 0:
        _kill_enemy(enemy, data.get("position", Vector2i.ZERO))

func _kill_enemy(enemy: Enemy, position: Vector2i):
    current_enemies.erase(enemy)
    enemy.remove_from_grid()
    enemy.queue_free()
    EventBus.enemy_killed.emit({
        "enemy_def": null,  # MVP 无 EnemyDef Resource
        "position": position,
        "method": "head_strike"
    })
    # 补充新敌人
    spawn_enemy()
```

**敌人生成逻辑：**

```
func spawn_enemy():
    var empty_cells = GridWorld.get_empty_cells()
    if empty_cells.is_empty():
        return
    # 过滤掉蛇头附近的格子（至少 3 格距离）避免不公平生成
    var safe_cells = empty_cells.filter(func(cell):
        var snake_head = _get_snake_head_pos()
        return abs(cell.x - snake_head.x) + abs(cell.y - snake_head.y) > 3
    )
    if safe_cells.is_empty():
        safe_cells = empty_cells  # fallback
    var pos = safe_cells[randi() % safe_cells.size()]
    var enemy = _create_enemy_instance()
    enemy.place_on_grid(pos)
    enemy_container.add_child(enemy)
    current_enemies.append(enemy)
    EventBus.enemy_spawned.emit({"enemy_def": null, "position": pos})
```

**需要创建的文件：**
- `Project/entities/enemies/enemy.gd` — Enemy GridEntity
- `Project/entities/enemies/enemy.tscn` — Enemy 场景
- `Project/systems/enemy/enemy_manager.gd` — EnemyManager

### 技术约束

- Enemy 继承 `GridEntity`，使用 `class_name Enemy`
- MVP 中敌人是**静止的**，不移动，不需要 AI
- 敌人的 `blocks_movement` 设为 `false`，允许蛇头移入敌人格子（碰撞在 Snake.move() 中通过检测实体类型处理）
- 战斗逻辑在 `EnemyManager` 中处理，不在 Enemy 实体本身
- 敌人生成时避开蛇头附近 3 格（曼哈顿距离），避免不公平的突然死亡
- 敌人被击杀后立即补充新敌人（保持场上数量恒定为 `max_enemy_count`）

### 验收标准

- [ ] Enemy 继承 GridEntity，显示为紫红色方块
- [ ] 初始化后地图上出现 3 个敌人
- [ ] 敌人不生成在蛇身上或其他实体上
- [ ] 敌人不生成在蛇头曼哈顿距离 3 格以内
- [ ] 蛇头移动到敌人格子时，敌人消失
- [ ] 蛇头撞敌人后蛇长度 -1
- [ ] 敌人消失后在新位置生成新敌人
- [ ] `enemy_killed` 事件正确发射
- [ ] 蛇长度为 1 时撞敌人 → 触发死亡（长度归零）

### 备注

- MVP 中只有一种敌人（静止型，HP=1，消耗 1 格），相当于设计文档中「游荡者 Wanderer」的极简版（去掉了随机移动）
- `blocks_movement = false` 是 MVP 的简化处理。后续版本中如果敌人阻挡移动，蛇需要在碰撞时停在敌人旁边而非移入。这会显著增加移动逻辑复杂度，MVP 中不需要
- EnemyManager 需要获取蛇头位置来计算安全距离。可通过 `snake` 引用或通过 GridWorld 查询 `SNAKE_SEGMENT` 类型实体来获取
